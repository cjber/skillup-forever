-- Run from the repository root: luajit tests/model_spec.lua
local ns = {}
assert(loadfile("Model.lua"))("SkillUpForever", ns)
local Model = ns.Model
local checks = 0

local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function near(actual, expected, label)
	checks = checks + 1
	assert(
		type(actual) == "number" and math.abs(actual - expected) < 1e-12,
		label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)
	)
end

equal(Model.Get(2152), nil, "lookup before data loads")
equal(Model.Color(nil, 48), nil, "unknown color")
equal(Model.Chance(nil, 48), nil, "unknown chance")

local cloak = { 1, 40, 55, 70 }
local boundaries = {
	{ -1, "red" },
	{ 0, "red" },
	{ 1, "orange", 1 },
	{ 2, "orange", 1 },
	{ 39, "orange", 1 },
	{ 40, "yellow", 1 },
	{ 41, "yellow", 29 / 30 },
	{ 48, "yellow", 22 / 30 },
	{ 54, "yellow", 16 / 30 },
	{ 55, "green", 0.5 },
	{ 56, "green", 14 / 30 },
	{ 69, "green", 1 / 30 },
	{ 70, "grey", 0 },
	{ 71, "grey", 0 },
	{ 300, "grey", 0 },
}
for _, case in ipairs(boundaries) do
	local skill, color, chance = case[1], case[2], case[3]
	local label = "Handstitched Leather Cloak at " .. skill
	equal(Model.Color(cloak, skill), color, label .. " color")
	if chance == nil then
		equal(Model.Chance(cloak, skill), nil, label .. " chance")
	else
		near(Model.Chance(cloak, skill), chance, label .. " chance")
	end
end

for _, invalid in ipairs({ { 1, 40, 40, 40 }, { 1, 40, 35, 30 } }) do
	for _, skill in ipairs({ 0, 1, 29, 30, 39, 40, 70 }) do
		equal(Model.Chance(invalid, skill), nil, "grey<=yellow at " .. skill)
	end
end

local tiny = { 1, 10, 10, 11 }
equal(Model.Color(tiny, 9), "orange", "tiny range before yellow")
equal(Model.Color(tiny, 10), "green", "green equals yellow")
near(Model.Chance(tiny, 10), 1, "tiny range chance at yellow")
equal(Model.Color(tiny, 11), "grey", "tiny range grey boundary")
near(Model.Chance(tiny, 11), 0, "tiny range grey chance")
equal(Model.Color({ 10, 10, 15, 20 }, 9), "red", "orange equals yellow: red")
equal(Model.Color({ 10, 10, 15, 20 }, 10), "yellow", "orange equals yellow: yellow")
near(Model.Chance({ 10, 10, 15, 20 }, 10), 1, "orange equals yellow chance")

assert(loadfile("Data/Thresholds.lua"))("SkillUpForever", ns)
equal(type(ns.Thresholds), "table", "generated namespace table")
equal(Model.Get(-1), nil, "unknown recipe")
equal(Model.Get(2152), ns.Thresholds[2152], "lookup uses recipe spell ID")
-- These are spell IDs, not the output item IDs used by Skillet SkillLevels.
-- Sample every profession, including the new gathering-profession recipes.
local samples = {
	2152,
	9058,
	2331,
	7418,
	2660,
	2963,
	3918,
	2540,
	2657,
	3275,
	1229705,
	1229745,
	1229517,
}
for _, recipeID in ipairs(samples) do
	local t = Model.Get(recipeID)
	local label = "sample recipe " .. recipeID
	equal(type(t), "table", label .. " exists")
	for index = 2, 4 do
		equal(t[index - 1] <= t[index], true, label .. " ascending thresholds")
	end
	equal(Model.Color(t, t[1] - 1), "red", label .. " below required skill")
	equal(Model.Chance(t, t[1] - 1), nil, label .. " red chance")
	near(Model.Chance(t, t[2]), 1, label .. " chance at yellow")
	near(Model.Chance(t, t[4]), 0, label .. " chance at grey")
	local chance = Model.Chance(t, t[3])
	equal(chance >= 0 and chance <= 1, true, label .. " chance range")
end
near(Model.Chance(Model.Get(9058), 48), 22 / 30, "generated cloak matches mockup")

-- These two raw DB2 rows have contradictory requirements. Preserve their data
-- for a live audit instead of inventing an orange threshold to make it sorted.
equal(Model.Get(2665)[1], 75, "Coarse Sharpening Stone retains DB2 orange")
equal(Model.Get(2665)[2], 40, "Coarse Sharpening Stone retains DB2 yellow")
equal(Model.Get(2674)[1], 125, "Heavy Sharpening Stone retains DB2 orange")
equal(Model.Get(2674)[2], 100, "Heavy Sharpening Stone retains DB2 yellow")

local rows = 0
for recipeID, t in pairs(ns.Thresholds) do
	rows = rows + 1
	local label = "recipe " .. tostring(recipeID)
	equal(type(recipeID), "number", label .. " key type")
	equal(recipeID > 0 and recipeID % 1 == 0, true, label .. " positive integer key")
	equal(type(t), "table", label .. " row type")
	equal(#t, 4, label .. " four thresholds")
	for index = 1, 4 do
		equal(type(t[index]), "number", label .. " numeric threshold")
		equal(t[index] >= 0 and t[index] % 1 == 0, true, label .. " nonnegative integer threshold")
		if index > 2 then
			equal(t[index - 1] <= t[index], true, label .. " ascending thresholds")
		end
	end
	equal(t[4] > t[2], true, label .. " positive chance denominator")
	equal(t[3], math.floor((t[2] + t[4]) / 2), label .. " green midpoint")
end
equal(rows > 0, true, "generated table is not empty")

-- Reagent cost is all-or-nothing, and per-skill-up cost scales by 1/chance.
local prices = { [2589] = 10, [2320] = 25 }
local function price(itemID)
	return prices[itemID]
end
equal(Model.RecipeCost({ { itemID = 2589, quantity = 2 }, { itemID = 2320, quantity = 1 } }, price), 45, "recipe cost")
equal(Model.RecipeCost({ { itemID = 2589, quantity = 2 }, { itemID = 1, quantity = 1 } }, price), nil, "unpriced")
equal(Model.RecipeCost({}, price), 0, "no reagents costs nothing")
equal(Model.RecipeCost(nil, price), nil, "unknown reagents")
equal(Model.CostPerSkillUp(45, 0.5), 90, "half chance doubles cost")
equal(Model.CostPerSkillUp(45, 0), nil, "no skill-up has no cost")
equal(Model.CostPerSkillUp(nil, 1), nil, "unpriced has no cost")
equal(Model.RoundMoney(80.4), 80, "copper stays copper")
equal(Model.RoundMoney(0.2), 1, "never rounds to nothing")
equal(Model.RoundMoney(4549), 4500, "silver drops copper")
equal(Model.RoundMoney(12345), 12300, "gold keeps silver")
equal(Model.RoundMoney(1234567), 1230000, "100g+ keeps whole gold")

print("model_spec: " .. checks .. " checks passed; " .. rows .. " generated recipes validated")
