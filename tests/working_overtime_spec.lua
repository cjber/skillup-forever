-- Run from the repository root: luajit tests/working_overtime_spec.lua
-- The Legacy talent Working Overtime adds 10 percentage points to every yellow and green skill-up chance.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local function near(actual, expected, label)
	assert(
		type(actual) == "number" and math.abs(actual - expected) < 1e-12,
		label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)
	)
end

local WORKING_OVERTIME = 1225451
local CLOAK = 1001
local c = Client.load({
	data = {
		Thresholds = { [CLOAK] = { 1, 40, 55, 70 } },
	},
})
local ns = c.ns
local Model = ns.Model
local thresholds = Model.Get(CLOAK)

equal(type(thresholds), "table", "the recipe has thresholds")
near(Model.Chance(thresholds, 48), 22 / 30, "a yellow recipe without the talent")

-- Picking the talent raises the yellow chance by ten points and refreshes what shows it.
c.known[WORKING_OVERTIME] = true
c.Fire("SPELLS_CHANGED")
near(Model.Chance(thresholds, 48), 22 / 30 + 0.10, "a yellow recipe with the talent")
near(Model.Chance(thresholds, 41), 1, "a yellow chance is capped at certainty")
equal(Model.Chance(thresholds, 39), 1, "an orange recipe stays certain")
equal(Model.Chance(thresholds, 70), 0, "a grey recipe stays impossible")
equal(Model.Chance(thresholds, 71), 0, "grey stays impossible past its range")

-- Unlearning it puts the chance back, through the same event path.
c.known[WORKING_OVERTIME] = nil
c.Fire("SPELLS_CHANGED")
near(Model.Chance(thresholds, 48), 22 / 30, "a yellow recipe after the talent is unlearned")
equal(Model.Chance(thresholds, 70), 0, "grey stays impossible after the talent is unlearned")

-- Other specs share the module's state when they load it in the same process.
Model.SetChanceBonus(0)
Client.report("working overtime")
