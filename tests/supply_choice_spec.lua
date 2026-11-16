-- Synthetic policy contracts, never live supply claims. Exact Fraction oracle:
-- ~/.cache/agent-scratch/issue563-oracle, independently derived analytic answers.
local ns = {}
assert(loadfile("Core/Model.lua"))("SkillUpForever", ns)
assert(loadfile("Core/Demand.lua"))("SkillUpForever", ns)
assert(loadfile("Core/Resupply.lua"))("SkillUpForever", ns)
assert(loadfile("Core/SupplyChoice.lua"))("SkillUpForever", ns)
local checks = 0
local function Check(value, why)
	checks = checks + 1
	assert(value, why)
end
local function Finish(job)
	for _ = 1, 10000 do
		if job.result.status ~= "calculating" then
			return job.result
		end
		job:Advance(100)
	end
	error("policy fixture exceeded work budget")
end
local function Leg(use)
	return {
		fromSkill = 1,
		toSkill = 2,
		skillUps = 1,
		thresholds = { 0, 0, 0, 2 },
		use = use,
		rawConsumption = true,
		deterministicOutput = true,
	}
end
local function Input(held, units, price, trip, stock)
	return {
		service = "fixed-batch",
		journey = "independent-round-trips",
		route = { legs = { Leg({ [1] = 1 }) }, held = { [1] = held }, buy = {} },
		walletCopper = "unlimited",
		currencies = {},
		stock = { S = stock or "unlimited" },
		tokenValues = {},
		sources = {
			{
				itemID = 1,
				bundleUnits = units,
				moneyCopper = price,
				maxBundles = 1,
				stockKey = "S",
				stockPerBundle = 1,
				vendor = "V",
				access = true,
				priceLaw = "fixed",
				costs = {},
			},
		},
		initialOrders = {},
		refillOrders = { { source = 1, bundles = 1 } },
		initialVisitCosts = { V = trip },
		refillVisitCosts = { V = trip },
		options = {
			workLimit = 1000000,
			stateLimit = 1000,
			coordinateLimit = 32,
			probabilityTolerance = 1e-9,
			costTolerance = 1e-8,
			visitTolerance = 1e-9,
		},
	}
end
local function Encloses(result, name, expected)
	Check(result.status == "complete", result.reasons[1] or name .. " not complete")
	Check(
		result[name .. "Lower"] <= expected and result[name .. "Upper"] >= expected,
		name
			.. " expected "
			.. expected
			.. " outside "
			.. tostring(result[name .. "Lower"])
			.. ","
			.. tostring(result[name .. "Upper"])
	)
end

local input = Input(0, 2, 3, 5, 2)
input.sourceRevision = 7
input.assumptions = {
	{
		offerID = "synthetic:1",
		field = "stock",
		revision = 2,
		provenance = "synthetic finite pool",
		scope = "this run",
		observedAt = 42,
		observationRevision = "fixture",
		session = 1,
		index = 1,
	},
}
local result = Finish(ns.SupplyChoice.Start(input, 0.7))
Check(result.status == "complete", result.reasons[1] or "finite optimum")
Check(result.sourceRevision == 7 and result.assumptions[1].observedAt == 42, "dated source evidence survives selection")
input.assumptions[1].scope = "changed by caller"
Check(result.assumptions[1].scope == "this run", "published evidence is owned")
Check(result.quantities[1] == 1, "one bundle is the least-cost feasible start")
Encloses(result, "coverage", 3 / 4)
Check(result.orders[1].bundles == 1, "transaction quantity preserved")
Check(result.costUpper < 13, "initial and repeated cost counted")

input = Input(0, 2, 3, 5, 2)
result = Finish(ns.SupplyChoice.Start(input, 0.9))
Check(result.status == "complete", result.reasons[1] or "larger finite optimum")
Check(result.quantities[1] == 2, "coverage constraint requires two bundles")
Check(#result.orders == 2, "per-transaction maximum does not cap a visit")
Encloses(result, "visits", 1)
Encloses(result, "cost", 11)

input = Input(0, 2, 3, 5)
result = Finish(ns.SupplyChoice.Start(input, 0.7))
Check(
	result.status == "complete" and result.quantities[1] == 1,
	"paid unlimited source gets an incumbent-proven finite bound"
)
input.walletCopper = 6
result = Finish(ns.SupplyChoice.Start(input, 0.9))
Check(result.status == "complete" and result.quantities[1] == 2, "wallet proves finite domain")

input = Input(0, 2, 3, 5, 1)
result = Finish(ns.SupplyChoice.Start(input, 0.9))
Check(result.status == "unknown", "finite domain has no feasible initial order")
Check(result.reasons[1]:find("no feasible", 1, true), "infeasibility distinguished from optimum")
result = Finish(ns.SupplyChoice.Start(input, nil))
Check(result.status == "unknown", "no default confidence")
result = Finish(ns.SupplyChoice.Start(input, 0 / 0))
Check(result.status == "unknown", "NaN is not an explicit coverage target")
input.options.workLimit = 5
result = Finish(ns.SupplyChoice.Start(input, 0.7))
Check(result.status == "unknown", "budget exhaustion is not infeasibility")

input = Input(0, 2, 3, 5, 2)
local job = ns.SupplyChoice.Start(input, 0.7)
job:Advance(1)
Check(job.result.status == "calculating", "selection is cooperative")
job:Cancel()
Check(job:Advance(1).status == "cancelled", "cancellation stays final")

input = Input(0, 2, 3, 5, 1)
local other = {}
for key, value in pairs(input.sources[1]) do
	other[key] = value
end
other.moneyCopper = 8
input.sources[2] = other
result = Finish(ns.SupplyChoice.Start(input, 0.7))
Check(result.status == "complete", result.reasons[1] or "distinct offer choice")
Check(result.quantities[1] == 1 and result.quantities[2] == 0, "same product/vendor preserves different offers")
Encloses(result, "cost", 8)
Check(result.acquisitions ~= nil, "selected acquisition records must survive publication")
local acquisition = result.acquisitions[1]
Check(acquisition.source == 1 and acquisition.vendor == "V", "selected source and vendor identity preserved")
Check(acquisition.itemID == 1 and acquisition.units == 2, "selected bundle output preserved")
Check(acquisition.moneyCopper == 3 and next(acquisition.costs) == nil, "selected payment preserved")

other.moneyCopper = 3
result = Finish(ns.SupplyChoice.Start(input, 0.7))
Check(result.status == "unknown", "overlapping objective bounds never invent a strict winner")

input = Input(0, 2, 0, 5)
input.currencies[9] = 2
input.sources[1].costs["currency:9"] = 1
input.tokenValues["currency:9"] = 2
result = Finish(ns.SupplyChoice.Start(input, 0.7))
Check(result.status == "complete", result.reasons[1] or "currency bounded domain")
Check(result.quantities[1] == 1, "typed token balance bounds all initial orders")
Encloses(result, "cost", 35 / 4)

input = Input(0, 1, 1, 10)
result = Finish(ns.SupplyChoice.Start(input, 0.49))
Check(result.status == "complete", result.reasons[1] or "unlimited paid optimum")
Check(result.quantities[1] == 4, "expected repeated visits select the economic margin without a 95 percent target")
Encloses(result, "coverage", 15 / 16)
Encloses(result, "cost", 123 / 8)
input.sources[1].moneyCopper = 0
result = Finish(ns.SupplyChoice.Start(input, 0.49))
Check(result.status == "unknown", "free unlimited inventory has no assumed attained finite optimum")

input = Input(0, 2, 0, 0)
input.refillVisitCosts.V = 5
input.sourceRevision, input.assumptions = 9, {}
result = Finish(ns.SupplyChoice.Start(input, 0.7))
Check(result.status == "unattained", "free initial supply with positive refill trips has no finite minimizer")
Check(
	result.infimumKnown and result.objectiveInfimumLower == 0 and result.objectiveInfimumUpper == 0,
	"exact zero infimum is proved"
)
Check(
	result.orders == nil and result.items == nil and not result.costKnown,
	"nonattainment invents no selected finite basket"
)
Check(
	result.nonattainment.chance == 0.5 and result.nonattainment.refillUnits == 2,
	"geometric proof retains its declared parameters"
)
Check(
	result.sourceRevision == 9 and result.assumptions ~= input.assumptions,
	"nonattainment preserves owned source evidence"
)
input.terminalCarry = { ["item:1"] = 1 }
Check(
	Finish(ns.SupplyChoice.Start(input, 0.7)).status == "unknown",
	"additional carrying cost needs another objective proof"
)
input.terminalCarry = nil
input.capacity = 10
Check(Finish(ns.SupplyChoice.Start(input, 0.7)).status == "unknown", "additional finite capacity needs another proof")
input.capacity = nil
input.initialVisitCosts.V = 1
Check(Finish(ns.SupplyChoice.Start(input, 0.7)).status == "unknown", "positive initial cost is outside this theorem")
input.initialVisitCosts.V = 0
Check(
	Finish(ns.SupplyChoice.Start(input, 1)).status == "unknown",
	"alpha one is a separate finite feasibility question"
)
input.refillVisitCosts.V = 0
Check(
	Finish(ns.SupplyChoice.Start(input, 0.7)).status == "unknown",
	"zero refill cost does not imply strict improvement"
)
input.refillVisitCosts.V = 5
input.route.legs[2] = Leg({ [1] = 1 })
Check(Finish(ns.SupplyChoice.Start(input, 0.7)).status == "unknown", "multiple stages require another theorem")
input.route.legs[2] = nil
input.route.legs[1].use[1] = 2
Check(Finish(ns.SupplyChoice.Start(input, 0.7)).status == "unknown", "other consumption bands are outside this theorem")
input.route.legs[1].use[1] = 1
input.route.legs[1].thresholds = { 1, 2, 3, 4 }
Check(
	Finish(ns.SupplyChoice.Start(input, 0.7)).status == "unknown",
	"certain skill-ups do not have geometric nonattainment"
)
input.route.legs[1].thresholds = { 0, 0, 0, 2 }
input.stock.S = 2
Check(
	Finish(ns.SupplyChoice.Start(input, 0.7)).status ~= "unattained",
	"finite stock cannot give an unbounded improvement sequence"
)
input.stock.S = "unlimited"
input.sources[1].costs = { ["item:30"] = 1 }
input.route.held[30], input.tokenValues["item:30"] = 2, 1
Check(
	Finish(ns.SupplyChoice.Start(input, 0.7)).status ~= "unattained",
	"finite token payments are outside the free-source theorem"
)
input.sources[1].costs = {}
input.refillOrders, input.refillVisitCosts = {}, {}
Check(
	Finish(ns.SupplyChoice.Start(input, 0.7)).status == "unknown",
	"an empty refill batch has no geometric refill law"
)

input = Input(0, 2, 3, 5, 2)
input.sources[1].offerID, input.sources[1].npcID = "token-offer", 123
input.sources[1].costs = { ["item:30"] = 1, ["currency:9"] = 2 }
input.route.held[30], input.currencies[9] = 3, 6
input.tokenValues = { ["item:30"] = 1, ["currency:9"] = 1, ["item:88"] = 0 }
local alternative = {}
for key, value in pairs(input.sources[1]) do
	alternative[key] = value
end
alternative.offerID, alternative.npcID, alternative.vendor = "cheaper-unaffordable", 456, "W"
alternative.moneyCopper, alternative.bundleUnits = 1, 3
alternative.costs = { ["item:88"] = 1 }
input.sources[2] = alternative
input.initialVisitCosts.W, input.refillVisitCosts.W = 0, 0
result = Finish(ns.SupplyChoice.Start(input, 0.7))
Check(result.status == "complete", result.reasons[1] or "typed selected identity")
local selected = result.acquisitions[1]
Check(
	selected.offerID == "token-offer" and selected.npcID == 123,
	"selected offer is not cheapest displayed alternative"
)
Check(selected.costs["item:30"] == 1 and selected.costs["currency:9"] == 2, "all typed payments retained")
Check(result.initialVisits.V == 5 and result.initialVisits.W == nil, "only selected vendor charges an initial visit")
input.sources[1].costs["item:30"] = 99
Check(selected.costs["item:30"] == 1, "selected requirements own their table after completion")
input.sources[1].offerID = {}
result = Finish(ns.SupplyChoice.Start(input, 0.7))
Check(result.status == "unknown", "untyped offer identity cannot escape in a certificate")
input.sources[1].offerID, input.sources[1].npcID = "valid", 1.5
result = Finish(ns.SupplyChoice.Start(input, 0.7))
Check(result.status == "unknown", "fractional NPC identity cannot escape in a certificate")
print("supply_choice_spec: " .. checks .. " checks passed")
