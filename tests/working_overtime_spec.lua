-- Run from the repository root: luajit tests/working_overtime_spec.lua
-- The Legacy talent Working Overtime gives 4 percentage points to every yellow and green skill-up chance per
-- point spent, up to 20 at five.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local function near(actual, expected, label)
	assert(
		type(actual) == "number" and math.abs(actual - expected) < 1e-12,
		label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)
	)
end

local WORKING_OVERTIME_TREE = 1187
local WORKING_OVERTIME_NODE = 110290
local CONFIG = 621140
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
near(Model.Chance(thresholds, 48), 22 / 30, "a yellow recipe with no points in the talent")

-- The rank lives in the Legacy professions tree; the client reports it as the node's active rank.
c.traitConfigs[WORKING_OVERTIME_TREE] = CONFIG
c.traitNodes[CONFIG] = { [WORKING_OVERTIME_NODE] = { activeRank = 0, currentRank = 0, maxRanks = 5 } }
local node = c.traitNodes[CONFIG][WORKING_OVERTIME_NODE]

local function Spent(points)
	node.activeRank = points
	c.Fire("TRAIT_NODE_CHANGED", WORKING_OVERTIME_NODE)
end

Spent(0)
near(Model.Chance(thresholds, 48), 22 / 30, "no points")
Spent(1)
near(Model.Chance(thresholds, 48), 22 / 30 + 0.04, "one point")
Spent(3)
near(Model.Chance(thresholds, 48), 22 / 30 + 0.12, "three points")
Spent(5)
near(Model.Chance(thresholds, 48), 22 / 30 + 0.20, "five points")
near(Model.Chance(thresholds, 41), 1, "a yellow chance is capped at certainty")
equal(Model.Chance(thresholds, 39), 1, "an orange recipe stays certain")
equal(Model.Chance(thresholds, 70), 0, "a grey recipe stays impossible")
equal(Model.Chance(thresholds, 71), 0, "grey stays impossible past its range")

-- No more than the node's five points count.
Spent(7)
near(Model.Chance(thresholds, 48), 22 / 30 + 0.20, "more points than the node has ranks")

-- The saved config changing and the spellbook changing both refresh the bonus.
node.activeRank = 0
c.Fire("TRAIT_CONFIG_UPDATED")
near(Model.Chance(thresholds, 48), 22 / 30, "the config event drops the bonus")
node.activeRank = nil
node.currentRank = 3
c.Fire("SPELLS_CHANGED")
near(Model.Chance(thresholds, 48), 22 / 30 + 0.12, "the current rank stands in for the active one")

-- Constants names the tree when the client has it; 1187 is only the fallback.
c.G.Constants = { LegacyConsts = { LEGACY_TREE_PROFESSIONS_ID = 999 } }
c.traitConfigs[999] = CONFIG
node.currentRank = 1
c.Fire("TRAIT_NODE_CHANGED", WORKING_OVERTIME_NODE)
near(Model.Chance(thresholds, 48), 22 / 30 + 0.04, "the tree comes from Constants when it is there")
c.G.Constants = nil

-- A client without the Legacy talent API gives no bonus.
node.currentRank = 5
c.G.C_Traits = nil
c.Fire("TRAIT_NODE_CHANGED", WORKING_OVERTIME_NODE)
near(Model.Chance(thresholds, 48), 22 / 30, "a client without C_Traits")

-- Other specs share the module's state when they load it in the same process.
Model.SetChanceBonus(0)
Client.report("working overtime")
