-- Run from the repository root: luajit tests/working_overtime_spec.lua
-- The Legacy talent Working Overtime adds 4 percentage points per point spent, capped at 20 with five points.
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

-- The curve: 4 percentage points per point, and no more than 20 with more than five points.
near(Model.WorkingOvertimeBonus(0), 0, "no points")
near(Model.WorkingOvertimeBonus(1), 0.04, "one point")
near(Model.WorkingOvertimeBonus(3), 0.12, "three points")
near(Model.WorkingOvertimeBonus(5), 0.20, "five points")
near(Model.WorkingOvertimeBonus(8), 0.20, "past the cap")

equal(type(thresholds), "table", "the recipe has thresholds")
near(Model.Chance(thresholds, 48), 22 / 30, "a yellow recipe without the talent")

-- Picking the talent raises the yellow chance by one point's worth and refreshes what shows it.
c.known[WORKING_OVERTIME] = true
c.Fire("SPELLS_CHANGED")
near(Model.Chance(thresholds, 48), 22 / 30 + 0.04, "a yellow recipe with one point")

-- The aura carries the points spent, so three points raise the chance by twelve.
local G = c.G
local aura = G.C_UnitAuras.GetPlayerAuraBySpellID
G.C_UnitAuras.GetPlayerAuraBySpellID = function(id)
	if id == WORKING_OVERTIME then
		return { spellId = id, applications = 3 }
	end
	return aura(id)
end
c.Fire("SPELLS_CHANGED")
near(Model.Chance(thresholds, 48), 22 / 30 + 0.12, "a yellow recipe with three points")
near(Model.Chance(thresholds, 41), 1, "a yellow chance is capped at certainty")

-- Five points are the cap, and eight spend no further.
G.C_UnitAuras.GetPlayerAuraBySpellID = function(id)
	if id == WORKING_OVERTIME then
		return { spellId = id, applications = 5 }
	end
	return aura(id)
end
c.Fire("SPELLS_CHANGED")
near(Model.Chance(thresholds, 48), 22 / 30 + 0.20, "a yellow recipe with five points")
G.C_UnitAuras.GetPlayerAuraBySpellID = function(id)
	if id == WORKING_OVERTIME then
		return { spellId = id, applications = 8 }
	end
	return aura(id)
end
c.Fire("SPELLS_CHANGED")
near(Model.Chance(thresholds, 48), 22 / 30 + 0.20, "eight points stay at the cap")

equal(Model.Chance(thresholds, 39), 1, "an orange recipe stays certain")
equal(Model.Chance(thresholds, 70), 0, "a grey recipe stays impossible")
equal(Model.Chance(thresholds, 71), 0, "grey stays impossible past its range")

-- Unlearning it puts the chance back, through the same event path.
G.C_UnitAuras.GetPlayerAuraBySpellID = aura
c.known[WORKING_OVERTIME] = nil
c.Fire("SPELLS_CHANGED")
near(Model.Chance(thresholds, 48), 22 / 30, "a yellow recipe after the talent is unlearned")
equal(Model.Chance(thresholds, 70), 0, "grey stays impossible after the talent is unlearned")

-- Other specs share the module's state when they load it in the same process.
Model.SetChanceBonus(0)
Client.report("working overtime")
