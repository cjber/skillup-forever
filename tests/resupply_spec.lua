-- Synthetic policy contracts, never live supply claims. Exact Fraction oracle:
-- ~/.cache/agent-scratch/issue563-oracle, independently derived analytic answers.
local ns = {}
assert(loadfile("Core/Model.lua"))("SkillUpForever", ns)
assert(loadfile("Core/Demand.lua"))("SkillUpForever", ns)
assert(loadfile("Core/Resupply.lua"))("SkillUpForever", ns)
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
local input = Input(2, 2, 1, 0)
local job = ns.Resupply.Start(input)
Check(job.result.status == "calculating", "construction does no work")
job:Advance(1)
Check(job.result.status == "calculating", "one coordinate does not drain the job")
local result = Finish(job)
Encloses(result, "coverage", 3 / 4)
Encloses(result, "success", 1)
Encloses(result, "visits", 1 / 3)
Encloses(result, "cost", 1 / 3)
Check(result.visitsLower > 1 / 4, "repeated visits are not the probability of any shortage")

local finite = Input(0, 2, 3, 5, 1)
result = Finish(ns.Resupply.Start(finite))
Encloses(result, "success", 3 / 4)
Encloses(result, "visits", 1)
Encloses(result, "cost", 8)
local unlimited = Input(0, 2, 3, 5)
result = Finish(ns.Resupply.Start(unlimited))
Encloses(result, "success", 1)
Encloses(result, "visits", 4 / 3)
Encloses(result, "cost", 32 / 3)
local sold = Input(0, 2, 3, 5, 0)
result = Finish(ns.Resupply.Start(sold))
Encloses(result, "success", 0)
Encloses(result, "visits", 0)
Encloses(result, "cost", 0)

finite.initialOrders = { { source = 1, bundles = 1 } }
result = Finish(ns.Resupply.Start(finite))
Encloses(result, "coverage", 3 / 4)
Encloses(result, "success", 3 / 4)
Encloses(result, "cost", 8)
Encloses(result, "visits", 1)
local wallet = Input(0, 2, 3, 5)
wallet.walletCopper = 3
result = Finish(ns.Resupply.Start(wallet))
Encloses(result, "success", 3 / 4)
Encloses(result, "cost", 8)

local shared = Input(1, 2, 0, 0, 0)
shared.route.legs = { Leg({ [1] = 1 }), Leg({ [1] = 1 }) }
shared.initialOrders = { { source = 1, bundles = 1 } }
shared.stock.S = 1
result = Finish(ns.Resupply.Start(shared))
Encloses(result, "coverage", 1 / 2)
Encloses(result, "success", 1 / 2)

local grouped = Input(0, 1, 0, 1)
grouped.route.legs = { Leg({ [1] = 1, [2] = 1 }) }
grouped.sources[2] = {
	itemID = 2,
	bundleUnits = 1,
	moneyCopper = 0,
	maxBundles = 1,
	stockKey = "S",
	stockPerBundle = 1,
	vendor = "V",
	access = true,
	priceLaw = "fixed",
	costs = {},
}
grouped.refillOrders[2] = { source = 2, bundles = 1 }
result = Finish(ns.Resupply.Start(grouped))
Encloses(result, "visits", 2)
Encloses(result, "cost", 2)
grouped.sources[2].vendor = "W"
grouped.refillVisitCosts.W = 1
result = Finish(ns.Resupply.Start(grouped))
Encloses(result, "visits", 4)
Encloses(result, "cost", 4)

-- Shared pre-order wallet/token/stock constraints, never per-row affordability.
local tokens = Input(0, 1, 1, 0)
tokens.sources[2] = {
	itemID = 2,
	bundleUnits = 1,
	moneyCopper = 1,
	maxBundles = 1,
	stockKey = "S",
	stockPerBundle = 1,
	vendor = "V",
	access = true,
	priceLaw = "fixed",
	costs = { ["item:3"] = 1 },
}
tokens.sources[1].costs = { ["item:3"] = 1 }
tokens.tokenValues["item:3"] = 0
tokens.route.held[3] = 1
tokens.refillOrders[2] = { source = 2, bundles = 1 }
result = Finish(ns.Resupply.Start(tokens))
Encloses(result, "success", 0)
Encloses(result, "cost", 0)
tokens.route.held[3], tokens.walletCopper = 2, 1
result = Finish(ns.Resupply.Start(tokens))
Encloses(result, "success", 0)
tokens.walletCopper, tokens.stock.S = 2, 1
result = Finish(ns.Resupply.Start(tokens))
Encloses(result, "success", 0)
tokens.stock.S = 2
tokens.route.legs = { Leg({ [1] = 1, [3] = 1 }) }
result = Finish(ns.Resupply.Start(tokens))
Check(
	result.status == "unknown" and result.reasons[1]:find("does not enable"),
	"token reagent is debited from the same pool"
)

local currency = Input(0, 2, 0, 0)
currency.sources[1].costs = { ["currency:9"] = 1 }
currency.tokenValues["currency:9"] = 3
currency.currencies[9] = 1
result = Finish(ns.Resupply.Start(currency))
Encloses(result, "success", 3 / 4)
Encloses(result, "cost", 3)
currency.tokenValues = {}
Check(Finish(ns.Resupply.Start(currency)).status == "unknown", "unknown token value never becomes zero")

for _, field in ipairs({ "walletCopper", "stock", "currencies", "tokenValues", "refillVisitCosts" }) do
	local missing = Input(0, 1, 0, 0)
	missing[field] = nil
	Check(Finish(ns.Resupply.Start(missing)).status == "unknown", "missing " .. field)
end
for _, stock in ipairs({ -1, 0 / 0, math.huge, "unknown" }) do
	local missing = Input(0, 1, 0, 0)
	missing.stock.S = stock
	Check(Finish(ns.Resupply.Start(missing)).status == "unknown", "raw stock is not a supply law")
end
local zero = Input(0, 1, 0, 0)
zero.route.legs[1].fromSkill, zero.route.legs[1].toSkill = 2, 3
Check(Finish(ns.Resupply.Start(zero)).status == "unknown", "zero chance has no invented finite reward")
local budget = Input(0, 1, 0, 0)
budget.options.workLimit = 2
Check(Finish(ns.Resupply.Start(budget)).status == "unknown", "resource exhaustion is unknown")
local cancelled = ns.Resupply.Start(Input(0, 1, 0, 0))
cancelled:Advance(1)
cancelled:Cancel()
Check(cancelled:Advance(10).status == "cancelled", "cancelled work cannot resume")
local original = ns.Model.ChanceRevision
ns.Model.ChanceRevision = function()
	return original() + 1
end
Check(job:Advance(1).status == "cancelled", "chance change revokes a completed certificate")
ns.Model.ChanceRevision = original
print("resupply_spec: " .. checks .. " checks passed")
