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

-- { required level, item class (2 weapon, 4 armour), subclass, inventory type, allowable class mask }.
local facts = {
	[1001] = { 20, 4, 2, 1, -1 }, -- leather head, level 20
	[1002] = { 40, 4, 3, 1, -1 }, -- mail head, level 40
	[1003] = { 20, 4, 3, 1, -1 }, -- mail head, level 20
	[1004] = { 40, 4, 4, 1, -1 }, -- plate head, level 40
	[1005] = { 20, 2, 7, 13, -1 }, -- one-hand sword
	[1006] = { 20, 2, 10, 17, -1 }, -- staff
	[1007] = { 20, 4, 1, 20, -1 }, -- cloth robe, level 20
	[1008] = { 15, 4, 1, 5, -1 }, -- cloth chest, level 15
	[1009] = { 20, 4, 0, 11, -1 }, -- ring
	[1010] = { 20, 2, 7, 13, 1 }, -- one-hand sword, warriors only
	[1011] = { 20, 4, 2, 1, -1 }, -- leather head, level 20
	[1012] = { 22, 4, 2, 1, -1 }, -- leather head, level 22
	[1013] = { 24, 4, 2, 1, -1 }, -- leather head, level 24
	[1014] = { 26, 4, 2, 1, -1 }, -- leather head, level 26
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
}

local SKILLS = { [2001] = 30, [2007] = 95 }

---@param level number
---@param classID integer
---@param learned table<integer, boolean>?
---@param professions table<integer, SkillUpProfession>?
---@return SkillUpGearSlot[]
local function Slots(level, classID, learned, professions)
	return Gear.List(recipes, facts, {
		level = level,
		classID = classID,
		learned = function(recipeID)
			return (learned or {})[recipeID] == true
		end,
		professions = professions or {},
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

local SHAMAN, WARRIOR, PRIEST = 7, 1, 5

-- Required level: an item at the character's level is in, one above it is out.
equal(Items(Slots(19, SHAMAN), "Head"), "", "level 19 leaves the level 20 heads out")
equal(Items(Slots(20, SHAMAN), "Head"), "1001 1011", "level 20 takes them")

-- Class armour: mail at 40 for a shaman, plate never; leather all along.
equal(Items(Slots(40, SHAMAN), "Head"), "1002 1014 1013", "at 40 the shaman wears mail, newest first, no plate")
equal(Items(Slots(40, WARRIOR), "Head"), "1002 1004 1014", "a warrior takes mail and plate at 40")

-- Class weapons: a shaman uses staves, not swords; a priest has neither sword nor a sword slot.
equal(Items(Slots(20, SHAMAN), "Two-handed"), "1006", "a shaman takes the staff")
equal(Items(Slots(20, SHAMAN), "Main hand"), "", "and has no sword")
equal(Items(Slots(20, PRIEST), "Two-handed"), "1006", "a priest takes the staff too")
equal(Items(Slots(20, PRIEST), "Main hand"), "", "and has no sword")

-- AllowableClass still has the last word.
equal(Items(Slots(20, WARRIOR), "Main hand"), "1005 1010", "a warrior-only sword shows for the warrior")
equal(Items(Slots(20, PRIEST), "Main hand"), "", "and not for the priest")

-- Slot grouping: a robe and a chest are one slot, and an ungated ring is everyone's.
equal(Items(Slots(20, SHAMAN), "Chest"), "1007 1008", "a robe and a chest share the Chest slot")
equal(Items(Slots(20, SHAMAN), "Finger"), "1009", "a ring is open to all")

-- At most three rows a slot.
local head = Slot(Slots(40, SHAMAN), "Head")
equal(#head.items, 3, "at most three heads")
equal(Items(Slots(40, SHAMAN), "Head"), "1002 1014 1013", "the newest three, highest level first")

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
equal(Find(Slots(20, SHAMAN), "Two-handed", 1006).profession, "Blacksmithing", "a bundled profession name")

print("gear_spec: " .. checks .. " checks passed")
