-- Run from the repository root: luajit tests/unlearned_spec.lua
-- The bundled list of recipes this character has not learned: only the open profession, only ones a trainer
-- or recipe item teaches, available ones first in effective skill, and never one already known.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local LEATHERWORKING, TAILORING = 165, 197
local MODIFIER = 5
local TRAINER, SCROLL, AHEAD_TRAINER, AHEAD_SCROLL = 7001, 7002, 7003, 7004
local KNOWN, UNPLACED, OTHER, NO_DATA = 7005, 7006, 7007, 7008

local recipes, thresholds, names = {}, {}, {}
for recipeID in pairs({
	[TRAINER] = true,
	[SCROLL] = true,
	[AHEAD_TRAINER] = true,
	[AHEAD_SCROLL] = true,
	[KNOWN] = true,
	[UNPLACED] = true,
	[NO_DATA] = true,
}) do
	recipes[recipeID] = { skillLine = LEATHERWORKING, reagents = {} }
	thresholds[recipeID] = { 1, 25, 50, 75 }
	names[recipeID] = "Recipe " .. recipeID
end
recipes[OTHER] = { skillLine = TAILORING, reagents = {} }
thresholds[OTHER] = { 1, 25, 50, 75 }
names[OTHER] = "Other profession"

local c = Client.load({
	boot = false,
	data = {
		RecipeData = recipes,
		Thresholds = thresholds,
		TrainerFees = {
			[TRAINER] = { 10, 20 },
			[AHEAD_TRAINER] = { 100, 75 },
			[OTHER] = { 10, 1 },
		},
		RecipeScrolls = {
			[SCROLL] = { 9002, 30 },
			[AHEAD_SCROLL] = { 9004, 75 },
		},
		TrainerRanks = {},
	},
})
local ns = c.ns
for recipeID, name in pairs(names) do
	c.spells[recipeID] = name
end
c.known[KNOWN] = true
c.Boot()

local profession = {
	skillLine = LEATHERWORKING,
	skill = 50,
	base = 45,
	modifier = MODIFIER,
}

local found = ns.UnlearnedRecipes(profession)
equal(#found, 4, "four unlearned recipes the bundle can place")
equal(found[1].recipeID, TRAINER, "the first available trainer recipe")
equal(found[1].kind, "trainer", "a trainer's recipe")
equal(found[1].skill, 25, "a trainer requirement is in effective skill")
equal(found[2].recipeID, SCROLL, "then the available recipe item")
equal(found[2].kind, "scroll", "a recipe item's recipe")
equal(found[2].itemID, 9002, "with the item that teaches it")
equal(found[2].skill, 35, "a recipe item's requirement is in effective skill")
equal(found[3].recipeID, AHEAD_TRAINER, "a trainer's recipe ahead still comes before a recipe item's")
equal(found[3].skill, 80, "at the skill ahead")
equal(found[4].recipeID, AHEAD_SCROLL, "and the recipe item ahead is last")
equal(found[4].skill, 80, "at the same skill ahead")
for _, entry in ipairs(found) do
	equal(entry.name, "Recipe " .. entry.recipeID, "the client names each recipe")
	equal(#entry.thresholds, 4, "and its difficulty bands come from the bundle")
end

-- A recipe the client's spellbook knows, one the bundle cannot place, and one of another profession are
-- not in the list.
local listed = {}
for _, entry in ipairs(found) do
	listed[entry.recipeID] = true
end
equal(listed[KNOWN], nil, "a learned recipe stays out")
equal(listed[UNPLACED], nil, "a recipe with no trainer or item stays out")
equal(listed[NO_DATA], nil, "a recipe with no thresholds stays out")
equal(listed[OTHER], nil, "another profession's recipe stays out")

-- A requirement the trainer showed replaces the bundled one on the next read.
c.ns.db.trainer[LEATHERWORKING] = { [AHEAD_TRAINER] = { 100, 60 } }
found = ns.UnlearnedRecipes(profession)
local byID = {}
for index, entry in ipairs(found) do
	byID[entry.recipeID] = { index = index, skill = entry.skill }
end
equal(byID[AHEAD_TRAINER].skill, 65, "the requirement seen at a trainer wins")
equal(byID[AHEAD_TRAINER].index < byID[AHEAD_SCROLL].index, true, "and moves it ahead of the recipe item")

equal(ns.LearnSource(profession, UNPLACED), nil, "a recipe the bundle cannot place has no source")
equal(ns.LearnSkill(profession, TRAINER), 25, "LearnSkill keeps its trainer answer")
print("unlearned_spec: sources, effective skill, availability order, learned and unknown recipes: ok")
