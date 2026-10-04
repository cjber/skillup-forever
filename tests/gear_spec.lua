-- Run from the repository root: luajit tests/gear_spec.lua
-- The crafted gear listing rule: which items a character can equip now, one list a slot, newest first.
local ns = { L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
}) }
ns.ProfessionSkillLines = { Leatherworking = 165, Blacksmithing = 164, Tailoring = 197, Engineering = 202 }
setfenv(assert(loadfile("Core/Gear.lua")), setmetatable({}, { __index = _G }))("SkillUpForever", ns)
local Gear = ns.Gear
local checks = 0

local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

-- { required level, item class (2 weapon, 4 armour), subclass, inventory type, allowable class mask,
-- required skill, its rank, consumed }.
local facts = {
	[1001] = { 20, 4, 2, 1, -1, 0, 0, 0 }, -- leather head, level 20
	[1002] = { 40, 4, 3, 1, -1, 0, 0, 0 }, -- mail head, level 40
	[1003] = { 20, 4, 3, 1, -1, 0, 0, 0 }, -- mail head, level 20
	[1004] = { 40, 4, 4, 1, -1, 0, 0, 0 }, -- plate head, level 40
	[1005] = { 20, 2, 7, 13, -1, 0, 0, 0 }, -- one-hand sword
	[1006] = { 20, 2, 10, 17, -1, 0, 0, 0 }, -- staff
	[1007] = { 20, 4, 1, 20, -1, 0, 0, 0 }, -- cloth robe, level 20
	[1008] = { 15, 4, 1, 5, -1, 0, 0, 0 }, -- cloth chest, level 15
	[1009] = { 20, 4, 0, 11, -1, 0, 0, 0 }, -- ring
	[1010] = { 20, 2, 7, 13, 1, 0, 0, 0 }, -- one-hand sword, warriors only
	[1011] = { 20, 4, 2, 1, -1, 0, 0, 0 }, -- leather head, level 20
	[1012] = { 22, 4, 2, 1, -1, 0, 0, 0 }, -- leather head, level 22
	[1013] = { 24, 4, 2, 1, -1, 0, 0, 0 }, -- leather head, level 24
	[1014] = { 26, 4, 2, 1, -1, 0, 0, 0 }, -- leather head, level 26
	[1015] = { 0, 4, 2, 1, -1, 202, 100, 0 }, -- leather head, needs Engineering 100
	[1016] = { 0, 2, 14, 21, -1, 202, 50, 0 }, -- misc main hand, needs Engineering 50
	[1017] = { 20, 4, 1, 5, -1, 0, 0, 1 }, -- consumed cloth chest
	[1018] = { 20, 4, 1, 9, -1, 0, 0, 0 }, -- cloth wrist, skill 50, name Bravo
	[1019] = { 20, 4, 1, 9, -1, 0, 0, 0 }, -- cloth wrist, skill 50, name Alpha
	[1020] = { 20, 4, 1, 9, -1, 0, 0, 0 }, -- cloth wrist, skill 80, name Charlie
	[1021] = { 19, 4, 1, 9, -1, 0, 0, 0 }, -- cloth wrist level 19, skill 90, name Zulu
}

local NAMES = {
	[1018] = "Bravo",
	[1019] = "Alpha",
	[1020] = "Charlie",
	[1021] = "Zulu",
}

---@param skillLine integer
---@param itemID integer
---@return SkillUpRecipe
local function recipe(skillLine, itemID)
	return { skillLine = skillLine, reagents = {}, output = { itemID = itemID, quantity = 1 } }
end

local recipes = {
	[2001] = recipe(165, 1001),
	[2002] = recipe(165, 1002),
	[2003] = recipe(165, 1003),
	[2004] = recipe(164, 1004),
	[2005] = recipe(164, 1005),
	[2006] = recipe(164, 1006),
	[2007] = recipe(197, 1007),
	[2008] = recipe(197, 1008),
	[2009] = recipe(202, 1009),
	[2010] = recipe(164, 1010),
	[2011] = recipe(165, 1011),
	[2012] = recipe(165, 1012),
	[2013] = recipe(165, 1013),
	[2014] = recipe(165, 1014),
	[2015] = recipe(165, 1011),
	[2016] = recipe(165, 1015),
	[2017] = recipe(202, 1016),
	[2018] = recipe(197, 1017),
	[2019] = recipe(197, 1018),
	[2020] = recipe(197, 1019),
	[2021] = recipe(197, 1020),
	[2022] = recipe(197, 1021),
}

local SKILLS = {
	[2001] = 30,
	[2007] = 95,
	[2019] = 50,
	[2020] = 50,
	[2021] = 80,
	[2022] = 90,
}

---@param level number
---@param classID integer
---@param learned table<integer, boolean>?
---@param professions table<integer, SkillUpProfession>?
---@param weaponSkills table<integer, number>?
---@return SkillUpGearSlot[]
local function Slots(level, classID, learned, professions, weaponSkills)
	return Gear.List(recipes, facts, {
		level = level,
		classID = classID,
		learned = function(recipeID)
			return (learned or {})[recipeID] == true
		end,
		professions = professions or {},
		weaponSkills = weaponSkills,
		name = function(itemID)
			return NAMES[itemID]
		end,
		skill = function(recipeID)
			return SKILLS[recipeID] or 1
		end,
		professionName = Gear.ProfessionName,
	})
end

---@param slots SkillUpGearSlot[]
---@param name string
---@return SkillUpGearSlot?
local function Slot(slots, name)
	for _, slot in ipairs(slots) do
		if slot.name == name then
			return slot
		end
	end
end

---@param slots SkillUpGearSlot[]
---@param name string
---@return string
local function Items(slots, name)
	local ids = {}
	local slot = Slot(slots, name)
	for _, item in ipairs(slot and slot.items or {}) do
		ids[#ids + 1] = item.itemID
	end
	return table.concat(ids, " ")
end

---@param slots SkillUpGearSlot[]
---@param name string
---@param itemID integer
---@return SkillUpGearItem?
local function Find(slots, name, itemID)
	local slot = Slot(slots, name)
	for _, item in ipairs(slot and slot.items or {}) do
		if item.itemID == itemID then
			return item
		end
	end
end

local function Engineering(skill)
	return { skillLine = 202, name = "Engineering", skill = skill }
end

local SHAMAN, WARRIOR, PRIEST, MAGE = 7, 1, 5, 8

-- Required level: an item at the character's level is in, one above it is out.
equal(Items(Slots(19, SHAMAN), "Head"), "", "level 19 leaves the level 20 heads out")
equal(Items(Slots(20, SHAMAN), "Head"), "1001 1011", "level 20 takes them")

-- Class armour: mail at 40 for a shaman, plate never; leather all along.
equal(Items(Slots(40, SHAMAN), "Head"), "1002 1014 1013", "at 40 the shaman wears mail, newest first, no plate")
equal(Items(Slots(40, WARRIOR), "Head"), "1002 1004 1014", "a warrior takes mail and plate at 40")

-- Class weapons with no client skill list: only what the class knows from creation.
equal(Items(Slots(20, SHAMAN), "Two-handed"), "1006", "a shaman starts with staves")
equal(Items(Slots(20, SHAMAN), "Main hand"), "", "and not with swords")
equal(Items(Slots(20, PRIEST), "Two-handed"), "", "a priest does not start with staves")
equal(Items(Slots(20, PRIEST), "Main hand"), "", "nor with swords")
equal(Items(Slots(20, WARRIOR), "Main hand"), "1005 1010", "a warrior starts with swords")
equal(Items(Slots(20, MAGE), "Two-handed"), "1006", "a mage starts with staves")
equal(Items(Slots(20, MAGE), "Main hand"), "", "and not with swords")

-- With the client's own skill lines, a trained type counts however the class table reads.
equal(Items(Slots(20, MAGE, nil, nil, { [43] = 1 }), "Main hand"), "1005", "a mage who trained swords sees them")
equal(Items(Slots(20, PRIEST, nil, nil, { [136] = 1 }), "Two-handed"), "1006", "a priest who trained staves sees them")
equal(Items(Slots(20, SHAMAN, nil, nil, {}), "Two-handed"), "", "a client skill list without staves leaves them out")
equal(Items(Slots(20, SHAMAN, nil, nil, {}), "Main hand"), "", "and without swords leaves them out")

-- The client's own skill lines are what Gear.WeaponSkills reads for the answer above.
_G.C_SkillInfo = {
	GetNumSkillLines = function()
		return 3
	end,
	GetSkillLineInfo = function(index)
		return ({
			{ skillID = 95, isHeader = false, rank = 1 }, -- Defense, not a weapon
			{ skillID = 43, isHeader = false, rank = 5 }, -- One-Handed Swords
			{ skillID = 43, isHeader = true },
		})[index]
	end,
}
local known = Gear.WeaponSkills()
equal(known ~= nil and known[43] == 5, true, "the client's sword skill line is read")
equal(known[95], nil, "a non-weapon skill line is left out")
_G.C_SkillInfo = {
	GetNumSkillLines = function()
		return 0
	end,
	GetSkillLineInfo = function() end,
}
equal(Gear.WeaponSkills(), nil, "an empty client skill list is no answer, so the class table stands")
_G.C_SkillInfo = nil

-- AllowableClass still has the last word.
equal(Items(Slots(20, WARRIOR), "Main hand"), "1005 1010", "a warrior-only sword shows for the warrior")
equal(
	Items(Slots(20, PRIEST, nil, nil, { [43] = 1 }), "Main hand"),
	"1005",
	"a priest who trained swords sees the open sword but not the warrior-only one"
)

-- Slot grouping: a robe and a chest are one slot, and an ungated ring is everyone's.
equal(Items(Slots(20, SHAMAN), "Chest"), "1007 1008", "a robe and a chest share the Chest slot")
equal(Items(Slots(20, SHAMAN), "Finger"), "1009", "a ring is open to all")

-- An item's own skill requirement: below its rank the item is out, at it the item is in.
equal(Find(Slots(20, SHAMAN), "Head", 1015), nil, "Engineering 100 keeps the goggles out")
equal(Find(Slots(20, SHAMAN, nil, { [202] = Engineering(99) }), "Head", 1015), nil, "Engineering 99 is short")
equal(
	Find(Slots(20, SHAMAN, nil, { [202] = Engineering(100) }), "Head", 1015) ~= nil,
	true,
	"Engineering 100 lists the goggles"
)
equal(Find(Slots(20, SHAMAN), "Main hand", 1016), nil, "Engineering 50 keeps the spanner out")
equal(
	Find(Slots(20, SHAMAN, nil, { [202] = Engineering(50) }), "Main hand", 1016) ~= nil,
	true,
	"Engineering 50 lists the spanner"
)

-- An item consumed on use is not gear.
equal(Find(Slots(20, SHAMAN), "Chest", 1017), nil, "a charged, consumed robe is left out")
equal(Items(Slots(20, SHAMAN), "Chest"), "1007 1008", "the chest keeps only the robes that stay worn")

-- At most three rows a slot.
local head = Slot(Slots(40, SHAMAN), "Head")
equal(#head.items, 3, "at most three heads")
equal(Items(Slots(40, SHAMAN), "Head"), "1002 1014 1013", "the newest three, highest level first")

-- Within a slot: required level descending, then the recipe's skill descending, then name.
equal(Items(Slots(20, SHAMAN), "Wrist"), "1020 1019 1018", "level, then skill, then name")

-- Learned state. Two recipes make the leather head; the learned one owns the item.
local own = { [165] = { skillLine = 165, name = "Leatherworking" } }
local learned = Slots(20, SHAMAN, { [2015] = true, [2007] = true }, own)
local owned = Find(learned, "Head", 1011)
equal(owned.recipeID, 2015, "the learned recipe of two keeps the item")
equal(owned.learned, true, "a known recipe reads as known")
equal(owned.learnable, true, "and its profession is the character's")
equal(owned.profession, "Leatherworking", "the row names the character's profession")
local robe = Find(learned, "Chest", 1007)
equal(robe.learned, true, "a tailoring robe the character knows")
equal(robe.learnable, false, "is not learnable without tailoring")

local item = Find(Slots(20, SHAMAN), "Chest", 1007)
equal(item.skill, 95, "the row carries the recipe's required skill")
equal(item.level, 20, "and the item's required level")
equal(item.name, nil, "a name the client has not loaded is left nil")
equal(Find(Slots(20, SHAMAN), "Two-handed", 1006).profession, "Blacksmithing", "a bundled profession name")

print("gear_spec: " .. checks .. " checks passed")
