---@type string, SkillUpNamespace
local _, ns = ...
local L = ns.L

-- The crafted gear view's listing rule: for each equipment slot, the newest items this character
-- can equip, ready for UI/Gear.lua to draw. Newness is the item's required level, nothing else,
-- so there are no stat weights and no best-in-slot claim.

-- Equipment slots the view lists, in order. Several inventory types share one slot: a robe is a
-- chest, a main-hand item is a one-hand weapon, a shield, held item and off-hand weapon are all
-- the off hand.
---@type {name: string, types: integer[]}[]
local GROUPS = {
	{ name = L["Head"], types = { 1 } },
	{ name = L["Neck"], types = { 2 } },
	{ name = L["Shoulder"], types = { 3 } },
	{ name = L["Back"], types = { 16 } },
	{ name = L["Chest"], types = { 5, 20 } },
	{ name = L["Wrist"], types = { 9 } },
	{ name = L["Hands"], types = { 10 } },
	{ name = L["Waist"], types = { 6 } },
	{ name = L["Legs"], types = { 7 } },
	{ name = L["Feet"], types = { 8 } },
	{ name = L["Finger"], types = { 11 } },
	{ name = L["Trinket"], types = { 12 } },
	{ name = L["Main hand"], types = { 13, 21 } },
	{ name = L["Two-handed"], types = { 17 } },
	{ name = L["Off hand"], types = { 14, 22, 23 } },
	{ name = L["Ranged"], types = { 15, 26 } },
	{ name = L["Thrown"], types = { 25 } },
	{ name = L["Relic"], types = { 28 } },
}

---@type table<integer, integer>
local GROUP_OF = {}
for index, group in ipairs(GROUPS) do
	for _, inventoryType in ipairs(group.types) do
		GROUP_OF[inventoryType] = index
	end
end

-- What each class can equip, and from which level, as the client's SkillRaceClassInfo expresses it
-- (wago.tools/db2/SkillRaceClassInfo and SkillLine, wow_classic_beta 1.60.1.70205): a row names one
-- skill line (a type), the class mask it covers and the level it starts at. Armour subclasses are 1
-- cloth, 2 leather, 3 mail, 4 plate and 6 shield; weapon subclasses are 0 one-hand axe, 1 two-hand
-- axe, 2 bow, 3 gun, 4 one-hand mace, 5 two-hand mace, 6 polearm, 7 one-hand sword, 8 two-hand sword,
-- 10 staff, 13 fist weapon, 15 dagger, 16 thrown, 18 crossbow and 19 wand.
-- The number is the level that type needs; a type absent for a class is one it can never use.
---@type table<integer, table<integer, integer>>
local ARMOUR = {
	[1] = { [1] = 0, [2] = 0, [3] = 0, [4] = 40, [6] = 0 }, -- Warrior
	[2] = { [1] = 0, [2] = 0, [3] = 0, [4] = 40, [6] = 0 }, -- Paladin
	[3] = { [1] = 0, [2] = 0, [3] = 40 }, -- Hunter
	[4] = { [1] = 0, [2] = 0 }, -- Rogue
	[5] = { [1] = 0 }, -- Priest
	[7] = { [1] = 0, [2] = 0, [3] = 40, [6] = 0 }, -- Shaman
	[8] = { [1] = 0 }, -- Mage
	[9] = { [1] = 0 }, -- Warlock
	[11] = { [1] = 0, [2] = 0 }, -- Druid
}
---@type table<integer, table<integer, integer>>
local WEAPON = {
	[1] = {
		[0] = 0,
		[1] = 0,
		[2] = 0,
		[3] = 0,
		[4] = 0,
		[5] = 0,
		[6] = 20,
		[7] = 0,
		[8] = 0,
		[10] = 0,
		[13] = 0,
		[15] = 0,
		[16] = 0,
		[18] = 0,
	}, -- Warrior
	[2] = { [0] = 0, [1] = 0, [4] = 0, [5] = 0, [6] = 20, [7] = 0, [8] = 0 }, -- Paladin
	[3] = {
		[0] = 0,
		[1] = 0,
		[2] = 0,
		[3] = 0,
		[6] = 20,
		[7] = 0,
		[8] = 0,
		[10] = 0,
		[13] = 0,
		[15] = 0,
		[16] = 0,
		[18] = 0,
	}, -- Hunter
	[4] = { [0] = 0, [2] = 0, [3] = 0, [4] = 0, [7] = 0, [13] = 0, [15] = 0, [16] = 0, [18] = 0 }, -- Rogue
	[5] = { [4] = 0, [10] = 0, [15] = 0, [19] = 0 }, -- Priest
	[7] = { [0] = 0, [1] = 0, [4] = 0, [5] = 0, [10] = 0, [13] = 0, [15] = 0 }, -- Shaman
	[8] = { [7] = 0, [10] = 0, [15] = 0, [19] = 0 }, -- Mage
	[9] = { [7] = 0, [10] = 0, [15] = 0, [19] = 0 }, -- Warlock
	[11] = { [4] = 0, [5] = 0, [6] = 20, [10] = 0, [13] = 0, [15] = 0 }, -- Druid
}
---@type table<integer, table<integer, table<integer, integer>>>
local PROFICIENCY = { [2] = WEAPON, [4] = ARMOUR }

-- The subclasses gated by PROFICIENCY. Every other type, such as a ring, trinket or fishing pole,
-- is open to every class; its own AllowableClass still has the last word.
---@type table<integer, table<integer, true>>
local GATED = {
	[2] = {
		[0] = true,
		[1] = true,
		[2] = true,
		[3] = true,
		[4] = true,
		[5] = true,
		[6] = true,
		[7] = true,
		[8] = true,
		[10] = true,
		[13] = true,
		[15] = true,
		[16] = true,
		[18] = true,
		[19] = true,
	},
	[4] = { [1] = true, [2] = true, [3] = true, [4] = true, [6] = true },
}

-- The fields of an ns.ItemGear row.
local LEVEL, ITEM_CLASS, SUBCLASS, SLOT, CLASSES = 1, 2, 3, 4, 5

-- The layout fits a few rows a slot without turning the view into a wall of names.
local MAX_PER_SLOT = 3

---@class SkillUpGear
local Gear = {}
ns.Gear = Gear
---@param facts number[]
---@param level number
---@param classID integer
---@return boolean
local function Usable(facts, level, classID)
	if bit.band(facts[CLASSES], bit.lshift(1, classID - 1)) == 0 then
		return false
	end
	local itemClass = facts[ITEM_CLASS]
	local gated = GATED[itemClass]
	if not gated or not gated[facts[SUBCLASS]] then
		return true
	end
	local byClass = PROFICIENCY[itemClass][classID]
	local from = byClass and byClass[facts[SUBCLASS]]
	return from ~= nil and level >= from
end

-- One profession's name, from the bundled ones; the character's own name wins in List.
---@param skillLine integer
---@return string
function Gear.ProfessionName(skillLine)
	for name, id in pairs(ns.ProfessionSkillLines or {}) do
		if id == skillLine then
			return name
		end
	end
	return string.format(L["profession %d"], skillLine)
end

-- The newest craftable items for the character's level and class, one list a slot, newest first.
-- The item's slot and type come from `facts`, its recipe and profession from `recipes`.
---@param recipes table<integer, SkillUpRecipe>
---@param facts table<integer, number[]>
---@param query SkillUpGearQuery
---@return SkillUpGearSlot[]
function Gear.List(recipes, facts, query)
	local found = {}
	for recipeID, recipe in pairs(recipes) do
		local output = recipe.output
		local itemID = output and output.itemID or nil
		local info = itemID and facts[itemID] or nil
		local group = info and GROUP_OF[info[SLOT]] or nil
		if itemID and info and group and info[LEVEL] <= query.level and Usable(info, query.level, query.classID) then
			local bucket = found[group]
			if not bucket then
				bucket = {}
				found[group] = bucket
			end
			local known = query.learned(recipeID) == true
			local held = bucket[itemID]
			if not held or (known and not held.learned) then
				local profession = query.professions[recipe.skillLine]
				bucket[itemID] = {
					recipeID = recipeID,
					itemID = itemID,
					skillLine = recipe.skillLine,
					skill = query.skill(recipeID),
					level = info[LEVEL],
					profession = profession and profession.name or query.professionName(recipe.skillLine),
					learned = known,
					learnable = profession ~= nil,
				}
			end
		end
	end
	local slots = {}
	for index, group in ipairs(GROUPS) do
		local bucket = found[index]
		if bucket then
			local items = {}
			for _, item in pairs(bucket) do
				items[#items + 1] = item
			end
			table.sort(items, function(a, b)
				return a.level > b.level or (a.level == b.level and a.itemID < b.itemID)
			end)
			while #items > MAX_PER_SLOT do
				items[#items] = nil
			end
			slots[#slots + 1] = { slot = index, name = group.name, items = items }
		end
	end
	return slots
end

-- The crafted gear for the character now, from the bundled data and the character's professions.
---@param level number
---@param classID integer
---@return SkillUpGearSlot[]
function ns.CraftedGear(level, classID)
	return Gear.List(ns.RecipeData, ns.ItemGear, {
		level = level,
		classID = classID,
		learned = ns.IsLearned,
		professions = ns.PlayerProfessions(),
		skill = function(recipeID)
			local thresholds = ns.Model.Get(recipeID)
			return thresholds and thresholds[1] or 0
		end,
		professionName = Gear.ProfessionName,
	})
end
