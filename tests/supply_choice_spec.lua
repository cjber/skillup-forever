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
local result = Finish(ns.SupplyChoice.Start(input, 0.7))
Check(result.status == "complete", result.reasons[1] or "finite optimum")
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
print("supply_choice_spec: " .. checks .. " checks passed")
