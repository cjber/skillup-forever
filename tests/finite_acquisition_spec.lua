-- Synthetic declared laws only. Independent Fraction oracle is retained at
-- ~/.cache/agent-scratch/skillup563-implementation/finite-objective-oracle.py.
local ns = {}
for _, file in ipairs({ "Model", "Demand", "Dyadic", "FiniteAcquisition" }) do
	assert(loadfile("Core/" .. file .. ".lua"))("SkillUpForever", ns)
end
local checks = 0
local function Check(value, why)
	checks = checks + 1
	assert(value, why)
end
local function Finish(input)
	local job = ns.FiniteAcquisition.Start(input)
	for _ = 1, 100000 do
		if job.result.status ~= "calculating" then
			return job.result
		end
		job:Advance(100)
	end
	error("finite fixture exceeded explicit work budget")
end
local function Source(id, item, units, money, costs, pool, vendor, chance, pay)
	return {
		offerID = id,
		itemID = item,
		bundleUnits = units,
		moneyCopper = money,
		costs = costs,
		stockKey = pool,
		stockPerBundle = 1,
		vendor = vendor,
		access = true,
		priceLaw = "fixed",
		maxBundles = 1,
		futureDelivery = { chance = chance, payOnFailure = pay },
	}
end
local function Input(use, held, sources, stock, wallet, chance)
	local initialMoney, refillMoney, initialValue, refillValue, carry, tokens = {}, {}, {}, {}, {}, {}
	for item in pairs(held) do
		carry["item:" .. item] = 0
	end
	for item in pairs(use) do
		carry["item:" .. item] = 0
	end
	for _, source in ipairs(sources) do
		initialMoney[source.vendor], refillMoney[source.vendor] = 0, 0
		initialValue[source.vendor], refillValue[source.vendor] = 1, 1
		carry["item:" .. source.itemID] = 0
		for key in pairs(source.costs) do
			carry[key], tokens[key] = 0, 0
		end
	end
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
					thresholds = chance == 1 and { 0, 2, 2, 2 } or { 0, 0, 0, 2 },
					use = use,
					rawConsumption = true,
					deterministicOutput = true,
				},
			},
			held = held,
			buy = {},
		},
		sources = sources,
		stock = stock,
		walletCopper = wallet,
		currencies = {},
		initialOrders = {},
		initialVisitMoney = initialMoney,
		refillVisitMoney = refillMoney,
		initialVisitValue = initialValue,
		refillVisitValue = refillValue,
		terminalCarry = carry,
		tokenValues = tokens,
		failureLoss = 100,
		sourceRevision = 1,
		assumptions = {},
		options = { workLimit = 5000000, stateLimit = 1000, coordinateLimit = 32, limbLimit = 256 },
	}
end
local function Encloses(result, name, value)
	Check(result.status == "complete", result.reasons[1] or "finite completion")
	Check(result[name .. "Lower"] <= value and result[name .. "Upper"] >= value, name .. " must enclose " .. value)
end
local function HasAction(result, source, count)
	for _, action in ipairs(result.certificate.policy) do
		if action.kind == "acquire" then
			local found = 0
			for _, order in ipairs(action.orders) do
				if order.source == source then
					found = found + order.bundles
				end
			end
			if found == count then
				return true
			end
		end
	end
	return false
end
local input = Input({ [1] = 1, [2] = 1 }, {}, {
	Source("token", 1, 2, 1, {}, "A", "V", 1, true),
	Source("product", 2, 1, 0, { ["item:1"] = 1 }, "B", "V", 1, true),
}, { A = 1, B = 1 }, 1, 1)
input.tokenValues["item:1"] = 3
local result = Finish(input)
Encloses(result, "success", 1)
Encloses(result, "cost", 6)
Encloses(result, "visits", 2)
Encloses(result, "coverage", 0)
Check(
	result.certificate.kind == "finite-dag-exhaustive",
	"finite acquisition must fund item-token offers through sequential visits, never same-batch products"
)
input.initialOrders = { { source = 1, bundles = 1 }, { source = 2, bundles = 1 } }
Check(Finish(input).status == "infeasible", "initial atomic batch cannot pay with its own delivered products")

input = Input({ [1] = 1 }, {}, {
	Source("cheap", 1, 2, 1, {}, "A", "V", 1, true),
	Source("costly", 1, 1, 2, {}, "B", "V", 1, true),
}, { A = 1, B = 2 }, 10, 0.5)
result = Finish(input)
Encloses(result, "success", 15 / 16)
Encloses(result, "money", 7 / 4)
Encloses(result, "visitValue", 11 / 8)
Encloses(result, "failure", 25 / 4)
Encloses(result, "objective", 75 / 8)
Check(HasAction(result, 2, 1), "finite stock exhaustion permits a different source action")

input = Input({ [1] = 1 }, {}, {
	Source("risky", 1, 2, 0, {}, "A", "risky", 0.5, false),
	Source("sure", 1, 1, 3, {}, "B", "sure", 1, false),
}, { A = 1, B = 1 }, 3, 0.5)
input.failureLoss, input.terminalCarry["item:1"] = 20, 1 / 4
result = Finish(input)
Encloses(result, "success", 11 / 16)
Encloses(result, "objective", 157 / 16)
Encloses(result, "money", 15 / 8)
Encloses(result, "carry", 1 / 16)
Check(HasAction(result, 2, 1), "a failed opportunity is depleted before switching to the sure source")

input = Input({ [1] = 2 }, {}, { Source("unit", 1, 1, 0, {}, "A", "V", 1, true) }, { A = 2 }, 0, 1)
result = Finish(input)
Encloses(result, "success", 1)
Encloses(result, "visits", 1)
local selected
for _, action in ipairs(result.certificate.policy) do
	if action.state == result.certificate.initialState then
		selected = action
	end
end
Check(
	selected and #selected.orders == 2 and selected.orders[1].bundles == 1 and selected.orders[2].bundles == 1,
	"per-transaction ceilings split one grouped visit without imposing a basket cap"
)

local function InitialAction(value)
	for _, action in ipairs(value.certificate.policy) do
		if action.state == value.certificate.initialState then
			return action
		end
	end
end
input = Input({ [1] = 1 }, {}, {
	Source("unit", 1, 1, 1, {}, "A", "V", 1, true),
	Source("bundle", 1, 2, 0, {}, "A", "V", 1, true),
}, { A = 1 }, 1, 1)
input.failureLoss, input.refillVisitValue.V = 20, 0
local lowCarry = Finish(input)
input.terminalCarry["item:1"] = 2
local highCarry = Finish(input)
Check(
	InitialAction(lowCarry).orders[1].source == 2 and InitialAction(highCarry).orders[1].source == 1,
	"explicit terminal carry changes the optimal bundle"
)

input = Input({ [10] = 1 }, {}, {
	Source("currency", 10, 1, 2, { ["currency:10"] = 1 }, "A", "V", 1, true),
}, { A = 2 }, 3, 0.5)
input.currencies[10], input.tokenValues["currency:10"], input.failureLoss = 1, 4, 20
result = Finish(input)
Encloses(result, "success", 0.5)
Encloses(result, "money", 2)
Encloses(result, "tokens", 4)
Encloses(result, "objective", 17)

input = Input({ [1] = 1, [2] = 1 }, {}, {
	Source("first", 1, 1, 0, {}, "A", "V", 1, true),
	Source("second", 2, 1, 0, {}, "A", "V", 1, true),
}, { A = 1 }, 0, 1)
result = Finish(input)
Encloses(result, "success", 0)
Encloses(result, "cost", 0)
Encloses(result, "objective", 100)
Check(InitialAction(result).kind == "stop", "shared stock cannot be spent twice; stopping is explicit")

input = Input({ [1] = 1 }, {}, { Source("fare", 1, 1, 0, {}, "A", "V", 1, true) }, { A = 1 }, 0, 1)
input.failureLoss, input.refillVisitMoney.V, input.refillVisitValue.V = 20, 1, 0
Encloses(Finish(input), "success", 0)
input.refillVisitMoney.V, input.refillVisitValue.V = 0, 1
Encloses(Finish(input), "success", 1)
input.walletCopper, input.refillVisitMoney.V, input.refillVisitValue.V = 1, 1, 0
result = Finish(input)
Encloses(result, "money", 1)
Encloses(result, "visitValue", 0)
input.sources[1].futureDelivery = { chance = 0.5, payOnFailure = false }
input.refillVisitValue.V = 2
result = Finish(input)
Encloses(result, "success", 0.5)
Encloses(result, "money", 1)
Encloses(result, "visitValue", 2)
Encloses(result, "objective", 13)
local failedFare = false
for _, action in ipairs(result.certificate.policy) do
	if action.state == "A:1:0:0:0" then
		failedFare = true
	end
end
Check(failedFare, "failed visit debits both the monetary fare and finite opportunity")

input.sources[1].futureDelivery.chance = 1
input.refillVisitMoney.V, input.refillVisitValue.V = 0, 0
result = Finish(input)
Encloses(result, "success", 1)
local impossible = false
for _, action in ipairs(result.certificate.policy) do
	if action.state == "A:1:0:0:1" then
		impossible = true
	end
end
Check(not impossible, "zero-probability delivery/craft children are skipped before state creation")

input = Input({ [1] = 1, [3] = 3 }, { [3] = 3 }, {
	Source("item-token", 1, 1, 0, { ["item:3"] = 1 }, "A", "V", 1, true),
}, { A = 1 }, 0, 1)
input.initialOrders = { { source = 1, bundles = 1 } }
result = Finish(input)
Encloses(result, "coverage", 0)
Check(
	result.acquisitions[1].costs["item:3"] == 1 and result.acquisitions[1].offerID == "item-token",
	"initial acquisition certificate retains typed token debits and distinct offer identity"
)
input.sources[1].costs["item:3"] = 2
Check(result.acquisitions[1].costs["item:3"] == 1, "published transaction records are owned")
input.sources[1].costs["item:3"] = 1
input.failureLoss = 0
result = Finish(input)
Encloses(result, "success", 0)
Encloses(result, "objective", 1) -- one explicit initial visit, then rational stop.
Check(InitialAction(result).kind == "stop", "zero explicit failure loss may rationally abandon a run")

for _, field in ipairs({ "workLimit", "stateLimit", "coordinateLimit", "limbLimit" }) do
	local previous = input.options[field]
	input.options[field] = 1
	Check(Finish(input).status == "unknown", field .. " exhaustion cannot certify a policy")
	input.options[field] = previous
end
local saved = input.failureLoss
input.failureLoss = nil
Check(Finish(input).status == "unknown", "failure loss is never defaulted")
input.failureLoss = saved
input.terminalCarry["item:1"] = nil
Check(Finish(input).status == "unknown", "terminal carry must explicitly include zero")
input.terminalCarry["item:1"] = 0
input.refillVisitMoney.V = nil
Check(Finish(input).status == "unknown", "money fares cannot be inferred from travel opportunity values")
input.refillVisitMoney.V = 0
input.sources[1].futureDelivery = nil
Check(Finish(input).status == "unknown", "current stock does not imply a future delivery law")
input.sources[1].futureDelivery = { chance = 1, payOnFailure = true }
input.capacity = 5
Check(Finish(input).status == "unknown", "unsupported capacity terms are never silently ignored")
input.capacity = nil
local job = ns.FiniteAcquisition.Start(input)
Check(job.result.status == "calculating", "getters do not drain the finite job")
job:Advance(5)
job:Cancel()
Check(job:Advance(100).status == "cancelled", "explicit cancellation remains terminal")
job = ns.FiniteAcquisition.Start(input)
ns.Model.SetChanceBonus(0.01)
Check(job:Advance(1).status == "cancelled", "changed probability model invalidates the job")
ns.Model.SetChanceBonus(0)
input = Input({ [1] = 1 }, { [1] = 1, [2] = 2 ^ 52 - 1 }, {}, {}, 2 ^ 52 - 2, 1)
result = Finish(input)
Check(
	result.certificate.initialState == "A:1:1,4503599627370495::4503599627370494",
	"accepted large balances and wallet require exact canonical integer state keys"
)
input = Input({ [1] = 1 }, { [4503599627370495] = 1 }, {
	Source("large-item-token", 1, 1, 0, { ["item:4503599627370495"] = 1 }, "A", "V", 1, true),
}, { A = 1 }, 0, 1)
input.initialOrders = { { source = 1, bundles = 1 } }
Encloses(Finish(input), "coverage", 1)
input.sources[1].access, input.initialOrders, input.stock.A = false, {}, 4503599627370495
result = Finish(input)
Check(
	result.certificate.initialState:find(":4503599627370495:0", 1, true),
	"finite stock coordinates also use exact integer keys"
)
input.sources[1].restockSeconds = 30
Check(Finish(input).status == "unknown", "unsupported source restock laws are rejected")
input.sources[1].restockSeconds = nil
input.sources[1].futureDelivery.partialUnits = 1
Check(Finish(input).status == "unknown", "unsupported partial delivery laws are rejected")
input = Input({ [1] = 1 }, { [1] = 1 }, {}, {}, 0, 1)
input.tokenValues["item:1"] = -1
local safelyRejected, invalidResult = pcall(Finish, input)
Check(
	safelyRejected and invalidResult.status == "unknown",
	"invalid optional token valuation must return unknown without throwing"
)
for _, invalid in ipairs({ false, 0 / 0, math.huge, "bad" }) do
	input.tokenValues["item:1"] = invalid
	safelyRejected, invalidResult = pcall(Finish, input)
	Check(
		safelyRejected and invalidResult.status == "unknown",
		"all invalid supplied pooled valuations are rejected safely"
	)
end
input = Input({ [1] = 1 }, {}, { Source("bound-source", 1, 1, 0, {}, "A", "V", 0.5, false) }, { A = 1 }, 0, 1)
input.assumptions = {
	{
		offerID = "bound-source",
		field = "declared-contract",
		revision = 3,
		provenance = "synthetic explicit laws",
		scope = "this fixture only",
		observedAt = 42,
		observationRevision = "synthetic:1",
		session = 1,
		index = 1,
	},
}
result = Finish(input)
Check(
	result.certificate.sources[1].offerID == "bound-source"
		and result.certificate.sources[1].futureDelivery.chance == 0.5,
	"future policy orders bind owned distinct source identities and delivery laws"
)
Check(
	result.certificate.laws.failureLoss == 100 and result.certificate.laws.refillVisitMoney.V == 0,
	"certificate owns explicit objective and monetary trip laws"
)
input.sources[1].offerID, input.sources[1].futureDelivery.chance = "mutated", 0
input.refillVisitMoney.V, input.assumptions[1].provenance = 50, "mutated"
Check(
	result.certificate.sources[1].offerID == "bound-source"
		and result.certificate.sources[1].futureDelivery.chance == 0.5
		and result.certificate.laws.refillVisitMoney.V == 0
		and result.assumptions[1].provenance == "synthetic explicit laws",
	"published source laws, nested kernels, valuations and provenance do not alias caller inputs"
)
input = Input({ [1] = 1 }, { [1] = 1 }, {}, {}, 0, 1)
input.initialVisitMoney.unused = false
Check(Finish(input).status == "unknown", "published optional monetary law values are validated too")
input.initialVisitMoney.unused = nil
input.route.capacity = 10
Check(Finish(input).status == "unknown", "unsupported nested route capacity is rejected")
input.route.capacity = nil
input.route.legs[1].outputs = { [1] = 1 }
Check(Finish(input).status == "unknown", "unsupported craft outputs are never silently discarded")
print("finite_acquisition_spec: " .. checks .. " checks passed")
