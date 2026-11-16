-- Synthetic finite laws and explicit alpha, never product defaults.
local ns = {}
for _, file in ipairs({ "Model", "Demand", "Dyadic", "FiniteAcquisition" }) do
	assert(loadfile("Core/" .. file .. ".lua"))("SkillUpForever", ns)
end
local checks = 0
local function Check(value, why)
	checks = checks + 1
	assert(value, why)
end
local function Source(id, units, money, pool)
	return {
		offerID = id,
		itemID = 1,
		bundleUnits = units,
		moneyCopper = money,
		costs = {},
		maxBundles = 1,
		stockKey = pool,
		stockPerBundle = 1,
		vendor = "V",
		access = true,
		priceLaw = "fixed",
		futureDelivery = { chance = 1, payOnFailure = true },
	}
end
local function Input()
	return {
		service = "adaptive-finite",
		journey = "independent-round-trips",
		delivery = "independent-bundle-outcomes",
		objective = "expected-expenditure-plus-terminal-carry-plus-failure-loss",
		route = {
			legs = {
				{
					fromSkill = 1,
					toSkill = 2,
					thresholds = { 0, 2, 2, 2 },
					use = { [1] = 1 },
					rawConsumption = true,
					deterministicOutput = true,
				},
			},
			held = {},
			buy = {},
		},
		sources = { Source("free-bundle", 2, 0, "A"), Source("paid-unit", 1, 1, "B") },
		stock = { A = 1, B = 1 },
		walletCopper = 1,
		currencies = {},
		initialOrders = {},
		initialVisitMoney = { V = 0 },
		refillVisitMoney = { V = 0 },
		initialVisitValue = { V = 0 },
		refillVisitValue = { V = 0 },
		tokenValues = {},
		terminalCarry = { ["item:1"] = 2 },
		failureLoss = 100,
		sourceRevision = 1,
		assumptions = {},
		options = { workLimit = 5000000, stateLimit = 1000, coordinateLimit = 32, limbLimit = 256 },
	}
end
local function Finish(input, alpha)
	local job = ns.FiniteAcquisition.Select(input, alpha)
	for _ = 1, 100000 do
		if job.result.status ~= "calculating" then
			return job.result, job
		end
		job:Advance(100)
	end
	error("finite selection exceeded explicit aggregate budget")
end
local function Encloses(result, name, value)
	Check(result.status == "complete", result.reasons[1] or "selection complete")
	Check(result[name .. "Lower"] <= value and result[name .. "Upper"] >= value, name .. " encloses " .. value)
end
local input = Input()
local result = Finish(input, 1)
Check(
	result.status == "complete" and result.quantities[1] == 0 and result.quantities[2] == 1,
	"initial selection must compare explicit carry: paid unit1 beats free bundle2 with spare carry2"
)
Encloses(result, "objective", 1)
Encloses(result, "coverage", 1)
Check(result.acquisitions[1].offerID == "paid-unit", "initial selected offer identity survives the outer selector")
Check(
	result.selection.evaluated == 4 and result.selection.eligible == 3,
	"complete finite initial domain is enumerated"
)
Check(
	next(input.initialOrders) == nil and input.options.workLimit == 5000000,
	"candidate orders and options never mutate caller inputs"
)
input.terminalCarry["item:1"] = 0
result = Finish(input, 1)
Check(result.quantities[1] == 1 and result.quantities[2] == 0, "explicit zero carry selects the free bundle")
Encloses(result, "objective", 0)
Check(
	result.items[1] == 2 and result.have[1] == nil,
	"gross delivered initial budget remains separate from native holdings"
)

input = Input()
input.sources, input.stock = { Source("unit", 1, 0, "A") }, { A = 1 }
input.terminalCarry["item:1"] = 0
input.route.legs[1].thresholds = { 0, 0, 0, 2 }
result = Finish(input, 0.5)
Check(
	result.status == "complete" and result.quantities[1] == 1,
	"exact C0 equal to alpha is admitted despite outward bounds straddling it"
)
Encloses(result, "coverage", 0.5)
result = Finish(input, 1)
Check(
	result.status == "infeasible" and result.selection.evaluated == 2 and result.selection.eligible == 0,
	"finite stochastic domain cannot certify alpha1"
)

input = Input()
input.sources, input.stock = { Source("unit", 1, 0, "A") }, { A = 2 }
input.route.legs[1].use[1] = 2
input.initialVisitValue.V, input.terminalCarry["item:1"] = 1, 0
result = Finish(input, 1)
Check(
	result.quantities[1] == 2
		and #result.orders == 2
		and result.orders[1].bundles == 1
		and result.orders[2].bundles == 1,
	"finite initial selection splits transactions without imposing a visit or basket cap"
)
Encloses(result, "visits", 1)
Encloses(result, "cost", 1)

input = Input()
input.route.held[1] = 1
input.terminalCarry["item:1"] = 0
result = Finish(input, 1)
Check(
	result.status == "complete" and #result.orders == 0 and result.items[1] == 1,
	"empty initial order remains an eligible finite decision"
)
Check(
	#result.quantities == 2 and result.quantities[1] == 0 and result.quantities[2] == 0,
	"empty order publishes a dense zero source vector"
)
input.options.workLimit = 1
result = Finish(input, 0)
Check(
	result.status == "unknown" and result.certificate == nil and result.selection == nil,
	"aggregate work exhaustion never certifies an incumbent"
)
input = Input()
input.sources[1].futureDelivery = nil
Check(Finish(input, 0).status == "unknown", "unresolved candidate laws prevent a global certificate even at alpha0")
input = Input()
Check(Finish(input, nil).status == "unknown", "alpha has no default")
Check(Finish(input, 0 / 0).status == "unknown", "NaN alpha rejected")
input.initialOrders = { { source = 1, bundles = 1 } }
Check(
	Finish(input, 1).status == "unknown",
	"fixed initial orders must use Start rather than being silently overwritten"
)
input = Input()
local job = ns.FiniteAcquisition.Select(input, 1)
Check(job.result.status == "calculating", "selection getters do not drain jobs")
job:Advance(100)
job:Cancel()
Check(job:Advance(100).status == "cancelled", "selector cancellation remains terminal")
local _, completed = Finish(input, 1)
ns.Model.SetChanceBonus(0.01)
Check(
	completed:Advance(1).status == "cancelled",
	"completed selector and its exact incumbent invalidate on model revision"
)
job = ns.FiniteAcquisition.Select(input, 1)
job:Advance(10)
ns.Model.SetChanceBonus(0)
Check(job:Advance(1).status == "cancelled", "model revision cancels in-progress child and private exact values")
input = Input()
input.sources, input.stock = { Source("third", 1, 0, "A") }, { A = 1 }
input.terminalCarry["item:1"] = 0
input.route.legs[1].fromSkill, input.route.legs[1].toSkill, input.route.legs[1].thresholds = 2, 3, { 0, 0, 0, 3 }
result = Finish(input, 1 / 3)
Check(
	result.status == "complete" and result.quantities[1] == 1,
	"non-dyadic-looking binary64 C0 exactly equal to alpha is admitted"
)
Check(
	Finish(input, 1 / 3 + 2 ^ -54).status == "infeasible",
	"next representable alpha above exact C0 is rejected despite overlapping displayed bounds"
)

input = Input()
input.sources[1].itemID, input.sources[1].bundleUnits, input.sources[1].costs = 1, 1, { ["item:2"] = 1 }
input.sources[2].itemID, input.sources[2].moneyCopper = 2, 0
input.route.held[2], input.route.legs[1].use[2] = 1, 1
input.tokenValues["item:2"], input.terminalCarry["item:1"], input.terminalCarry["item:2"] = 0, 0, 0
result = Finish(input, 1)
Check(
	result.status == "complete" and result.quantities[1] == 1 and result.quantities[2] == 1,
	"initial selection jointly replaces a shared item token consumed as payment"
)
Check(
	result.items[2] == 2 and result.have[2] == 1 and result.acquisitions[1].costs["item:2"] == 1,
	"gross initial units and held units remain distinct from net post-payment coverage inventory"
)
Encloses(result, "coverage", 1)
input.route.held[2] = 0
Check(
	Finish(input, 1).status == "infeasible",
	"same-batch products cannot bootstrap an initial token payment even when later adaptive visits could"
)

input = Input()
input.sources[1].itemID, input.sources[1].bundleUnits = 1, 1
input.sources[2].itemID, input.sources[2].stockKey, input.sources[2].moneyCopper = 2, "A", 0
input.stock, input.route.legs[1].use[2] = { A = 1 }, 1
input.terminalCarry["item:1"], input.terminalCarry["item:2"] = 0, 0
result = Finish(input, 1)
Check(
	result.status == "infeasible" and result.selection.evaluated == 4,
	"shared initial stock rejects the joint vector rather than spending the same pool twice"
)

input = Input()
input.sources, input.stock = { Source("currency-unit", 1, 1, "A") }, { A = 2 }
input.sources[1].costs["currency:1"] = 1
input.currencies[1], input.tokenValues["currency:1"] = 1, 3
input.terminalCarry["currency:1"], input.terminalCarry["item:1"] = 0, 0
input.route.legs[1].thresholds = { 0, 0, 0, 2 }
result = Finish(input, 0.5)
Check(
	result.status == "complete" and result.quantities[1] == 1,
	"shared finite wallet and currency constrain initial quantity"
)
Encloses(result, "objective", 54)
Check(
	Finish(input, 0.75).status == "infeasible",
	"currency and wallet cannot be spent again to reach a higher initial target"
)
input = Input()
input.sources, input.stock = { Source("finite-evidence", 1, 0, "A") }, { A = 1 }
input.route.legs[1].thresholds = { 0, 0, 0, 2 }
input.assumptions = {
	{
		offerID = "finite-evidence",
		field = "declared-contract",
		revision = 1,
		provenance = "synthetic declared laws",
		scope = "finite fixture",
		observedAt = 42,
		observationRevision = "synthetic:1",
		session = 1,
		index = 1,
	},
}
result = Finish(input, 1)
Check(
	result.status == "infeasible" and result.sourceRevision == 1 and result.assumptions[1].scope == "finite fixture",
	"global finite infeasibility retains the source revision and owned dated assumptions"
)
input.assumptions[1].scope = "mutated"
Check(result.assumptions[1].scope == "finite fixture", "infeasible provenance records remain owned")
print("finite_selection_spec: " .. checks .. " checks passed")
