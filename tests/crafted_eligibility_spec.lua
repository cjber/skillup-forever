local Client = dofile("tests/client.lua")
local c = Client.load({
	boot = false,
	saved = { routeTargets = { [197] = 2 }, trackedProfessions = { [197] = true } },
	data = {
		Thresholds = { [1] = { 0, 2, 2, 2 }, [4] = { 0, 3, 3, 3 } },
		RecipeData = {
			[1] = {
				skillLine = 197,
				output = { itemID = 11, quantity = 1 },
				reagents = { { itemID = 10, quantity = 1 } },
			},
		},
		TrainerFees = {},
		TrainerRanks = {},
		ItemSellPrices = {},
	},
})
c.professions = { { name = "Tailoring", icon = 1, rank = 1, max = 75, id = 8197 } }
c.known[1], c.spells[1] = true, "Synthetic Cloth"
c.schematics = { [1] = { reagents = { { 10, 1 } }, output = 11 } }
c.bags[10], c.bags[30], c.money = 1, 2, 0
c.Boot()
local ns = c.ns
local plan = {
	profession = { modifier = 0 },
	crafts = { { recipeID = 1, from = 1, to = 2 } },
}
local policy = {
	service = "adaptive-finite",
	journey = "independent-round-trips",
	delivery = "independent-bundle-outcomes",
	objective = "expected-expenditure-plus-terminal-carry-plus-failure-loss",
	route = assert(ns.RouteDemand.Snapshot(plan, {})),
	walletCopper = 0,
	currencies = {},
	stock = { S = 1 },
	sources = {
		{
			offerID = "inaccessible-other-product",
			itemID = 30,
			bundleUnits = 1,
			moneyCopper = 0,
			costs = {},
			maxBundles = 1,
			stockKey = "S",
			stockPerBundle = 1,
			vendor = "V",
			access = false,
			priceLaw = "fixed",
			futureDelivery = { chance = 1, payOnFailure = true },
		},
	},
	initialOrders = {},
	tokenValues = {},
	terminalCarry = { ["item:10"] = 0, ["item:30"] = 3 },
	failureLoss = 100,
	initialVisitMoney = { V = 0 },
	refillVisitMoney = { V = 0 },
	initialVisitValue = { V = 0 },
	refillVisitValue = { V = 0 },
	sourceRevision = 1,
	assumptions = {},
	options = { workLimit = 1000000, stateLimit = 1000, coordinateLimit = 32, limbLimit = 256 },
}
local checks = 0
local function Check(value, why)
	checks = checks + 1
	assert(value, why)
end
local function Copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for k, v in pairs(value) do
		result[k] = Copy(v)
	end
	return result
end
local owner = ns.RecipeEvidence
local schemas = {
	[1] = {
		recipeID = 1,
		isRecraft = false,
		quantityMin = 1,
		quantityMax = 1,
		outputItemID = 11,
		reagentSlotSchematics = {
			{
				reagentType = 0,
				quantityRequired = 1,
				reagents = { { itemID = 20 } },
				slotIndex = 1,
				dataSlotIndex = 1,
				required = true,
				variableQuantities = { { reagent = { itemID = 20 }, quantity = 1 } },
				slotInfo = { mcrSlotID = 9, requiredSkillRank = 0 },
			},
		},
	},
	[2] = {
		recipeID = 2,
		isRecraft = false,
		quantityMin = 2,
		quantityMax = 2,
		outputItemID = 20,
		reagentSlotSchematics = {
			{
				reagentType = 0,
				quantityRequired = 1,
				reagents = { { itemID = 10 } },
				slotIndex = 1,
				dataSlotIndex = 1,
				required = true,
				slotInfo = { mcrSlotID = 9, requiredSkillRank = 0 },
			},
		},
	},
	[3] = {
		recipeID = 3,
		isRecraft = false,
		quantityMin = 3,
		quantityMax = 3,
		outputItemID = 20,
		reagentSlotSchematics = {
			{
				reagentType = 0,
				quantityRequired = 2,
				reagents = { { itemID = 10 } },
				slotIndex = 1,
				dataSlotIndex = 1,
				required = true,
				slotInfo = { mcrSlotID = 9, requiredSkillRank = 0 },
			},
		},
	},
}
c.G.C_TradeSkillUI.GetRecipeSchematic = function(id)
	return schemas[id]
end
c.G.C_TradeSkillUI.GetProfessionInfoByRecipeID = function()
	return { professionID = 197, skillLevel = 1, skillModifier = 0, maxSkillLevel = 75 }
end
plan.profession = { skillLine = 197, professionID = 197, modifier = 0, max = 75 }
plan.training, plan.ranks = {}, {}
plan.crafts[1].subcrafts = { { recipeID = 2 } }
policy.route = { held = { [10] = 999, [20] = 999, [11] = 999 }, legs = {} }
policy.terminalCarry = { ["item:10"] = 0, ["item:20"] = 0, ["item:11"] = 1, ["item:30"] = 0 }
c.bags[10], c.bags[20], c.bags[11] = 1, 0, 2
local declaration
local function Declare()
	declaration = {
		version = "crafted-adapter-v1",
		skillGainLaw = "whole-successful-count-bounded-by-rank",
		universeComplete = true,
		recipes = {},
		prerequisites = {},
		allocations = {},
		eligibility = {},
	}
	for id = 1, 3 do
		local observed = assert(owner.Observe(id, "allocation-" .. id, 10000))
		local recipe = {
			recipeID = id,
			professionID = observed.professionID,
			role = id == 1 and "main" or "auxiliary",
			available = true,
			scope = "synthetic completed attempt law",
			skillEffect = id == 1 and "route" or "neutral",
			productionLaw = "deterministic-completed-attempt",
			use = id == 1 and { [20] = 1 } or { [10] = id == 2 and 1 or 2 },
			produce = id == 1 and { [11] = 1 } or { [20] = id == 2 and 2 or 3 },
			evidence = {
				revision = observed.revision,
				allocation = observed.allocation,
				clientBuild = observed.clientBuild,
			},
		}
		declaration.recipes[#declaration.recipes + 1] = recipe
		declaration.prerequisites[id] = { rank = true, training = true, tools = true, station = true, access = true }
		declaration.allocations[id] = {
			identity = observed.allocation,
			complete = true,
			slots = {
				{ slotIndex = 1, dataSlotIndex = 1, itemID = id == 1 and 20 or 10, quantity = id == 3 and 2 or 1 },
			},
		}
		declaration.eligibility[id] = { fromSkill = 0, toSkill = 75 }
	end
	return owner.Declare(197, declaration, 10000)
end
local function Request()
	return {
		inventoryScope = "bags-only",
		policy = policy,
		crafted = { version = "crafted-adapter-v1", revision = owner.Revision(), skillLine = 197 },
	}
end
local function Finish(request, alpha)
	local job = ns.RouteDemand.StartAdaptive(plan, request or Request(), alpha == nil and 1 or alpha)
	for _ = 1, 100000 do
		if job.result.status ~= "calculating" then
			return job.result, job
		end
		job:Advance(64)
	end
	error("fixture work exhausted")
end

-- Reproduce auxiliary used only after its own profession leaves its declared bound.
assert(Declare())
schemas[2].reagentSlotSchematics[1].reagents = { { itemID = 11 } }
schemas[2].outputItemID = 40
schemas[4] = Copy(schemas[1])
schemas[4].recipeID = 4
schemas[4].outputItemID = 21
schemas[4].reagentSlotSchematics[1].reagents = { { itemID = 40 } }
schemas[4].reagentSlotSchematics[1].variableQuantities = {}
local second = assert(owner.Observe(2, "allocation-2", 10000))
local fourth = assert(owner.Observe(4, "allocation-4", 10000))
local d = Copy(declaration)
d.recipes[2].evidence = { revision = second.revision, allocation = second.allocation, clientBuild = second.clientBuild }
d.recipes[2].use = { [11] = 1 }
d.recipes[2].produce = { [40] = 2 }
d.allocations[2].slots[1].itemID = 11
d.eligibility[2] = { fromSkill = 0, toSkill = 1 }
d.recipes[3].available = false
local main = Copy(d.recipes[1])
main.recipeID = 4
main.use = { [40] = 1 }
main.produce = { [21] = 1 }
main.evidence = { revision = fourth.revision, allocation = fourth.allocation, clientBuild = fourth.clientBuild }
d.recipes[4] = main
d.allocations[4] = {
	identity = fourth.allocation,
	complete = true,
	slots = { { slotIndex = 1, dataSlotIndex = 1, itemID = 40, quantity = 1 } },
}
d.eligibility[4] = { fromSkill = 0, toSkill = 75 }
d.prerequisites[4] = Copy(d.prerequisites[1])
assert(owner.Declare(197, d, 10000))
plan.crafts[2] = { recipeID = 4, from = 2, to = 3 }
c.bags[10], c.bags[20], c.bags[11], c.bags[40], c.bags[21] = 0, 1, 0, 0, 0
policy.terminalCarry["item:40"], policy.terminalCarry["item:21"] = 0, 0
local function Policies(result)
	assert(result.status == "complete", tostring(result.reasons[1]))
	for _, graph in ipairs({ result.certificate.coveragePolicy, result.certificate.policy }) do
		for _, action in ipairs(graph) do
			if action.kind == "craft" then
				local stage = tonumber(action.state:match("^[^:]+:(%d+):"))
				local law = result.certificate.recipes[action.recipeID].eligibility
				local skill = law.fixedSkill or result.certificate.stages[stage].skill
				Check(
					skill >= law.fromSkill and skill <= law.toSkill,
					"both policies obey inclusive actual-skill bounds"
				)
			end
		end
	end
end
local function Bound(lo, hi, expected)
	d.eligibility[2] = { fromSkill = lo, toSkill = hi }
	assert(owner.Declare(197, d, 10000))
	local r = Finish(nil, 0)
	Policies(r)
	Check(
		r.coverageLower <= expected
			and r.coverageUpper >= expected
			and r.coverageUpper - r.coverageLower < 1e-10
			and (expected ~= 0 or r.coverageUpper == 0),
		"exact C0 bound"
	)
	return r
end
Check(Finish().status == "infeasible", "crossing upper bound cannot satisfy alpha one")
Bound(0, 1, 0)
Bound(2, 2, 1) -- Not initially eligible: retained for the later stage.
Bound(1, 2, 1) -- Inclusive upper endpoint.
Bound(2, 3, 1) -- Inclusive lower endpoint.
-- Effective skill, including a nonzero profession modifier.
local modifier, other, cap = 5, false, 75
c.G.C_TradeSkillUI.GetProfessionInfoByRecipeID = function(id)
	return {
		professionID = other and id == 2 and 164 or 197,
		skillLevel = 1,
		skillModifier = modifier,
		maxSkillLevel = cap,
	}
end
local function Reobserve()
	for _, recipe in ipairs(d.recipes) do
		local observed = assert(owner.Observe(recipe.recipeID, "allocation-" .. recipe.recipeID, 10000))
		recipe.professionID = observed.professionID
		recipe.evidence =
			{ revision = observed.revision, allocation = observed.allocation, clientBuild = observed.clientBuild }
	end
end
plan.profession.modifier = modifier
ns.Thresholds[1], ns.Thresholds[4] = { 0, 20, 20, 20 }, { 0, 20, 20, 20 }
Reobserve()
Bound(2, 2, 0)
Bound(7, 7, 1)
-- Other profession remains at observed effective skill six after main gain.
other = true
Reobserve()
Bound(6, 6, 1)
Bound(7, 7, 0)
other, modifier, plan.profession.modifier = false, 0, 0
Reobserve()
-- Nondivisible gain overshoots the first target: next leg starts at actual 3,
-- never the target-clipped 2. A subsequent target 4 still requires main 4.
local function Gains(first, nextGain)
	c.live[1] = { info = { numSkillUps = first, maxTrivialLevel = ns.Thresholds[1][4], learned = true } }
	c.live[4] = { info = { numSkillUps = nextGain, maxTrivialLevel = ns.Thresholds[4][4], learned = true } }
	c.Fire("TRADE_SKILL_LIST_UPDATE")
	c.Advance(0)
	Reobserve()
end
Gains(2, 1)
plan.crafts[2].to = 4
local r = Bound(2, 2, 0)
Check(r.certificate.stages[2].skill == 3, "nondivisible overshoot carried into next leg")
r = Bound(3, 3, 1)
Check(r.certificate.stages[1].skill == 1 and r.certificate.stages[2].skill == 3, "whole multi-point gain")
-- A leg already covered by overshoot consumes no extra recipe/output.
plan.crafts[2].to = 3
r = Bound(0, 0, 1)
Check(#r.certificate.stages == 1, "overshoot completes covered next leg")
-- Stochastic no-gain branches keep stage and effective skill unchanged.
plan.crafts[2].to = 4
ns.Thresholds[1] = { 0, 0, 4, 4 }
Gains(1, 1)
c.bags[20] = 3
d.eligibility[2] = { fromSkill = 2, toSkill = 2 }
assert(owner.Declare(197, d, 10000))
r = Finish(nil, 0)
Policies(r)
Check(r.certificate.stages[1].skill == 1 and r.certificate.stages[2].skill == 2, "no-gain stages preserve skill")
local loops = 0
for _, graph in ipairs({ r.certificate.policy, r.certificate.coveragePolicy }) do
	local found = false
	for _, action in ipairs(graph) do
		if action.recipeID == 1 then
			for _, edge in ipairs(action.successors) do
				if edge.state:match("^[^:]+:(%d+):") == action.state:match("^[^:]+:(%d+):") then
					found = true
				end
			end
		end
	end
	Check(found, "no-gain branch stays at actual skill in each policy")
	loops = loops + 1
end
Check(loops == 2, "both policy graphs checked")
-- Grey affects chance, not the size of a successful gain across it.
ns.Thresholds[1] = { 0, 2, 2, 2 }
Gains(2, 2)
plan.crafts[2].to = 4
c.bags[20] = 1
r = Bound(3, 3, 1)
Check(r.certificate.stages[2].skill == 3, "gain crosses grey without clipping physical skill")
-- Divisible multi-gain interval and a genuine nondivisible three-point leg.
ns.Thresholds[1] = { 0, 20, 20, 20 }
Gains(2, 1)
plan.crafts[1].to, plan.crafts[2].from, plan.crafts[2].to = 3, 3, 4
r = Bound(3, 3, 1)
Check(r.certificate.stages[2].skill == 3, "divisible multi-gain boundary")
plan.crafts[1].to, plan.crafts[2].from, plan.crafts[2].to = 4, 4, 6
c.bags[20] = 2
r = Bound(4, 4, 0)
Check(r.certificate.stages[3].skill == 5, "three-point leg overshoots by one before next recipe")
r = Bound(5, 5, 1)
Check(#r.certificate.stages == 3, "actual skill stages are one three five")
-- An overshot main stage must also obey its inclusive declared bound.
d.eligibility[4] = { fromSkill = 4, toSkill = 4 }
assert(owner.Declare(197, d, 10000))
Check(Finish(nil, 0).reasons[1] == "recipe-plan-eligibility-boundary", "main declared interval remains required")
d.eligibility[4] = { fromSkill = 0, toSkill = 75 }
assert(owner.Declare(197, d, 10000))
-- Successful gains stop at the explicit effective rank cap.
cap, plan.profession.max = 3, 3
plan.crafts[1].to, plan.crafts[2].from, plan.crafts[2].to = 2, 2, 3
Gains(5, 1)
c.bags[20] = 1
r = Bound(0, 0, 1)
Check(#r.certificate.stages == 1 and r.certificate.laws.skillCap == 3, "rank cap bounds successful overshoot")
local noGainLaw = Copy(d)
noGainLaw.skillGainLaw = nil
local accepted, reason = owner.Declare(197, noGainLaw, 10000)
Check(
	not accepted and reason == "recipe-successful-skill-gain-law-missing",
	"native count and cap do not establish gain law"
)
assert(owner.Declare(197, d, 10000))
-- Malformed optional kernel law cannot be silently ignored.
local route = assert(owner.Snapshot(plan, Request().crafted, function() end))
local malformed = Copy(policy)
malformed.route = route
route.recipes[2].eligibility.toSkill = -1
local bad = ns.FiniteAcquisition.Start(malformed)
for _ = 1, 10000 do
	if bad.result.status ~= "calculating" then
		break
	end
	bad:Advance(64)
end
Check(bad.result.status == "unknown", "invalid bounds rejected")
route.recipes[2].eligibility.toSkill = 0
route.recipes[1].eligibility.fixedSkill = 0
bad = ns.FiniteAcquisition.Start(malformed)
for _ = 1, 10000 do
	if bad.result.status ~= "calculating" then
		break
	end
	bad:Advance(64)
end
Check(
	bad.result.status == "unknown" and bad.result.reasons[1] == "invalid recipe eligibility",
	"main recipe cannot replace actual skill with fixedSkill"
)
print("crafted eligibility: " .. checks .. " checks passed")
