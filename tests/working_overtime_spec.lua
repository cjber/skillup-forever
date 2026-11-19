-- Run from the repository root: luajit tests/working_overtime_spec.lua
-- Tests the optional additive estimate, not the server probability law. The estimate is off by default (#741); this
-- character turned it on after that default reached them.
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
	saved = { includeWorkingOvertime = true, workingOvertimeOffSeen = true },
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

-- The saved option gates the estimate, while the producer keeps reading the actual rank.
local stale = {}
for _, key in ipairs({ "plans", "trackedNeeds", "api", "recipeList" }) do
	ns.WhenStale(key, function()
		stale[key] = (stale[key] or 0) + 1
	end)
end
equal(ns.db.includeWorkingOvertime, true, "an on chosen after the off default stays on")
for _, rank in ipairs({ 0, 1, 5 }) do
	node.activeRank, node.currentRank = rank, rank
	c.Fire("TRAIT_NODE_CHANGED", WORKING_OVERTIME_NODE)
	local revision = Model.ChanceRevision()
	c.SetSetting("includeWorkingOvertime", false)
	equal(ns.db.includeWorkingOvertime, false, "off is saved")
	equal(ns.workingOvertimeRank, rank, "actual rank retained while off")
	near(Model.Chance(thresholds, 60), 1 / 3, "off uses base estimate")
	local baseCost = Model.CostPerSkillUp(100, Model.Chance(thresholds, 60))
	local snapshot = {
		skill = 60,
		target = 61,
		recipes = { { recipeID = CLOAK, thresholds = thresholds, netCost = 100, reagentCost = 100 } },
	}
	local baseRoute = Model.PlanRoute(snapshot)
	equal(Model.ChanceRevision(), revision + (rank > 0 and 1 or 0), "off revises only a changed chance")
	local offRevision = Model.ChanceRevision()
	node.activeRank = 5
	for _, event in ipairs({ "TRAIT_NODE_CHANGED", "TRAIT_CONFIG_UPDATED", "SPELLS_CHANGED" }) do
		c.Fire(event)
		equal(ns.workingOvertimeRank, 5, "event still reads rank while disabled")
		near(Model.Chance(thresholds, 60), 1 / 3, "event cannot reenable estimate")
		equal(Model.ChanceRevision(), offRevision, "disabled events keep chance revision")
	end
	node.activeRank = rank
	local invalidations = stale.plans or 0
	c.SetSetting("includeWorkingOvertime", true)
	equal(ns.workingOvertimeRank, rank, "enabling rereads the client rank")
	near(Model.Chance(thresholds, 60), 1 / 3 + rank * 0.04, "on applies detected rank")
	equal(Model.ChanceRevision(), offRevision + (rank > 0 and 1 or 0), "on chance revision")
	if rank > 0 then
		assert(Model.CostPerSkillUp(100, Model.Chance(thresholds, 60)) < baseCost, "cost uses selected estimate")
		local route = Model.PlanRoute(snapshot)
		assert(route.expectedCost < baseRoute.expectedCost, "route cost uses selected estimate")
		assert(route.segments[1].crafts < baseRoute.segments[1].crafts, "route crafts use selected estimate")
		equal(stale.plans, invalidations + 1, "producer invalidates plans")
		for _, key in ipairs({ "trackedNeeds", "api", "recipeList" }) do
			equal(stale[key], stale.plans, key .. " follows talents invalidation")
		end
	end
	equal(Model.Chance(thresholds, 39), 1, "orange unchanged")
	equal(Model.Chance(thresholds, 70), 0, "grey unchanged")
end
local restored = Client.load({ boot = false, saved = { includeWorkingOvertime = false } })
restored.traitConfigs[WORKING_OVERTIME_TREE] = CONFIG
restored.traitNodes[CONFIG] = { [WORKING_OVERTIME_NODE] = { activeRank = 5, maxRanks = 5 } }
restored.Boot()
equal(restored.ns.db.includeWorkingOvertime, false, "saved false survives load")
equal(restored.ns.workingOvertimeRank, 5, "disabled startup reads actual rank")
near(restored.ns.Model.Chance({ 1, 40, 55, 70 }, 60), 1 / 3, "disabled startup uses base estimate")

-- A client without the Legacy talent API gives no bonus.
node.currentRank = 5
c.G.C_Traits = nil
c.Fire("TRAIT_NODE_CHANGED", WORKING_OVERTIME_NODE)
near(Model.Chance(thresholds, 48), 22 / 30, "a client without C_Traits")

-- Other specs share the module's state when they load it in the same process.
Model.SetChanceBonus(0)
Client.report("working overtime")
