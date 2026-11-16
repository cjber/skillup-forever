-- Synthetic declared laws only. Run tests/crafted_oracle.py for the independent Fraction oracle.
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
local function Encloses(result, name, value)
	Check(result.status == "complete", result.reasons[1] or "finite completion")
	Check(result[name .. "Lower"] <= value and result[name .. "Upper"] >= value, name .. " must enclose " .. value)
end
local input = {
	service = "adaptive-finite",
	journey = "independent-round-trips",
	delivery = "independent-bundle-outcomes",
	objective = "expected-expenditure-plus-terminal-carry-plus-failure-loss",
	sources = {},
	stock = {},
	walletCopper = 0,
	currencies = {},
	initialOrders = {},
	initialVisitMoney = {},
	refillVisitMoney = {},
	initialVisitValue = {},
	refillVisitValue = {},
	terminalCarry = { ["item:1"] = 0, ["item:2"] = 0, ["item:3"] = 0 },
	tokenValues = {},
	sourceRevision = 1,
	assumptions = {},
	options = { workLimit = 5000000, stateLimit = 1000, coordinateLimit = 32, limbLimit = 256 },
}
input.failureLoss = 8
input.route = {
	version = "crafted-deterministic-v1",
	coverage = "maximum-craft-only-completion",
	prerequisites = "already-satisfied",
	held = { [1] = 2, [2] = 0, [3] = 0 },
	buy = {},
	recipes = {
		{
			recipeID = 101,
			professionID = 1,
			role = "main",
			available = true,
			scope = "fixture",
			skillEffect = "route",
			productionLaw = "deterministic-completed-attempt",
			use = { [1] = 1 },
			produce = { [2] = 1 },
			evidence = { revision = 1, allocation = "basic", clientBuild = "synthetic" },
		},
		{
			recipeID = 102,
			professionID = 1,
			role = "main",
			available = true,
			scope = "fixture",
			skillEffect = "route",
			productionLaw = "deterministic-completed-attempt",
			use = { [2] = 2 },
			produce = { [3] = 1 },
			evidence = { revision = 1, allocation = "basic", clientBuild = "synthetic" },
		},
	},
	legs = {
		{ recipeID = 101, fromSkill = 1, toSkill = 2, thresholds = { 0, 0, 0, 2 } },
		{ recipeID = 102, fromSkill = 2, toSkill = 3, thresholds = { 0, 3, 3, 3 } },
	},
}
local result = Finish(input)
Encloses(result, "coverage", 1 / 4)
Encloses(result, "success", 1 / 4)
Encloses(result, "failure", 6)
Encloses(result, "cost", 0)

local function Copy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[key] = Copy(child)
	end
	return copy
end
local base = Copy(input)
local function Auxiliary(id, use, produce)
	local recipe = Copy(base.route.recipes[1])
	recipe.recipeID, recipe.role, recipe.skillEffect = id, "auxiliary", "neutral"
	recipe.use, recipe.produce = use, produce
	return recipe
end
local function Rejects(value, reason)
	local failed = Finish(value)
	Check(failed.status == "unknown", "unsupported law must be unknown")
	Check(not failed.certificate and failed.reasons[1]:find(reason, 1, true), failed.reasons[1] or reason)
end
local function Initial(value, coverage)
	local certificate = value.certificate
	for _, action in ipairs(coverage and certificate.coveragePolicy or certificate.policy) do
		if action.state == (coverage and certificate.coverageState or certificate.initialState) then
			return action
		end
	end
end
local function CheckRanks(value)
	local ranks = {}
	for _, policy in ipairs({ value.certificate.policy, value.certificate.coveragePolicy }) do
		for _, action in ipairs(policy) do
			ranks[action.state] = action.rank
		end
	end
	for _, policy in ipairs({ value.certificate.policy, value.certificate.coveragePolicy }) do
		for _, action in ipairs(policy) do
			for _, edge in ipairs(action.successors) do
				local a, b, decreased = action.rank, ranks[edge.state], false
				for i = 1, #a do
					if a[i] ~= b[i] then
						decreased = b[i] < a[i]
						break
					end
				end
				Check(decreased, "every certified edge strictly lowers the declared rank")
			end
		end
	end
end
CheckRanks(result)
Check(
	result.certificate.stages[1].recipeID == 101 and result.certificate.stages[1].produce["item:2"] == 1,
	"stage binds identity and production"
)
Check(table.concat(result.certificate.topologicalItems, ",") == "1,2,3", "all-edge dependency order")
Check(Initial(result, true).recipeID == 101, "coverage policy identifies selected main recipe")
input = Copy(base)
input.route.recipes[2].use[2] = 1
result = Finish(input)
Encloses(result, "coverage", 3 / 4)
Encloses(result, "success", 3 / 4)
Encloses(result, "failure", 2)
-- Zero economic loss makes stop win the economic tie. C0 still maximizes
-- success across crafts rather than inheriting the stop policy.
input.failureLoss = 0
result = Finish(input)
Encloses(result, "coverage", 3 / 4)
Encloses(result, "success", 0)
Check(
	Initial(result, false).kind == "stop" and Initial(result, true).kind == "craft",
	"separate economic and coverage policies"
)
-- An explicitly skill-neutral (including grey) auxiliary has no gain branch.
-- Its two-unit yield funds two later main legs and leaves shared surplus.
input = Copy(base)
input.route.held = { [1] = 1, [2] = 0, [3] = 0, [4] = 0 }
input.terminalCarry["item:4"] = 0
input.route.recipes = {
	Auxiliary(201, { [1] = 1 }, { [2] = 3 }),
	Copy(base.route.recipes[2]),
	Copy(base.route.recipes[2]),
}
input.route.recipes[2].use, input.route.recipes[2].produce = { [2] = 1 }, { [3] = 1 }
input.route.recipes[3].recipeID, input.route.recipes[3].use, input.route.recipes[3].produce =
	103, { [2] = 1 }, { [4] = 1 }
input.route.legs = {
	{ recipeID = 102, fromSkill = 1, toSkill = 2, thresholds = { 0, 2, 2, 2 } },
	{ recipeID = 103, fromSkill = 2, toSkill = 3, thresholds = { 0, 3, 3, 3 } },
}
local surplus = Copy(input)
result = Finish(input)
Encloses(result, "coverage", 1)
Check(
	Initial(result, true).recipeID == 201 and Initial(result, true).role == "auxiliary",
	"neutral auxiliary remains craftable without skill gain"
)
CheckRanks(result)
input.route.held[1], input.route.held[2] = 0, 2
result = Finish(input)
Encloses(result, "coverage", 1)
Check(Initial(result, true).recipeID == 102, "held intermediate skips auxiliary")
-- Competing auxiliaries spend the same raw item. Only the second can finish.
input = Copy(surplus)
input.route.recipes[1].produce[2] = 1
input.route.recipes[#input.route.recipes + 1] = Auxiliary(202, { [1] = 1 }, { [2] = 2 })
input.failureLoss = 0
result = Finish(input)
Encloses(result, "coverage", 1)
Encloses(result, "success", 0)
Check(Initial(result, true).recipeID == 202, "coverage chooses best declared recipe independently of economic loss")
-- A craft output used as a source token has one shared item balance.
input = Copy(base)
input.route.legs = { Copy(base.route.legs[2]) }
input.route.recipes = { Auxiliary(201, { [1] = 1 }, { [4] = 1 }), Copy(base.route.recipes[2]) }
input.route.recipes[2].use = { [2] = 1 }
input.route.held = { [1] = 1 }
input.sources = { Source("token-product", 2, 1, 0, { ["item:4"] = 1 }, "stock", "V", 1, true) }
input.stock = { stock = 1 }
input.initialVisitMoney, input.refillVisitMoney = { V = 0 }, { V = 0 }
input.initialVisitValue, input.refillVisitValue = { V = 0 }, { V = 0 }
input.terminalCarry["item:4"], input.tokenValues["item:4"] = 0, 3
result = Finish(input)
Encloses(result, "coverage", 0)
Encloses(result, "success", 1)
Encloses(result, "tokens", 3)
CheckRanks(result)
input.route.held = {}
Encloses(Finish(input), "success", 0)
input = Copy(base)
input.route.recipes[1].produce = { [1] = 2 }
Rejects(input, "cyclic")
input = Copy(surplus)
input.route.recipes[1].produce = { [1] = 1 }
Rejects(input, "cyclic")
input = Copy(surplus)
input.route.recipes[1].use = {}
Rejects(input, "free auxiliary")
input = Copy(surplus)
input.route.recipes[1].skillEffect = "affecting"
Rejects(input, "skill-affecting auxiliary")
input = Copy(base)
input.route.recipes[1].use = {}
Rejects(input, "zero-progress zero-consumption")
input = Copy(base)
input.route.recipes[1].use = {}
input.route.legs[1].thresholds = { 0, 2, 2, 2 }
Encloses(Finish(input), "coverage", 0)
input = Copy(base)
input.terminalCarry["item:3"] = nil
Rejects(input, "terminal carry")
input = Copy(base)
input.route.recipes[1].produce[2] = 2 ^ 52 - 1
Rejects(input, "exact integer range")
for _, budget in ipairs({ "workLimit", "stateLimit", "coordinateLimit", "limbLimit" }) do
	input = Copy(base)
	input.options[budget] = 1
	local exhausted = Finish(input)
	Check(exhausted.status == "unknown" and not exhausted.certificate, budget .. " exhaustion never clips the answer")
end
input = Copy(base)
input.route.recipes[1].productionLaw = "mean-yield"
Rejects(input, "deterministic recipes")
input = Copy(base)
input.route.recipes[1].evidence.allocation = nil
Rejects(input, "production evidence")
input = Copy(base)
input.route.recipes[2].recipeID = 101
Rejects(input, "distinct identified")
input = Copy(base)
input.route.recipes[1].available = false
Encloses(Finish(input), "coverage", 0)
input = Copy(base)
input.route.recipes[1].produce = {}
Rejects(input, "positive deterministic")
input = Copy(base)
input.route.recipes[3] = nil
input.route.recipes[4] = Copy(input.route.recipes[1])
Rejects(input, "dense")
-- The existing finite initial enumerator consumes crafted C0 without changing
-- its held/gross purchase API or selecting an implicit alpha.
local selected = ns.FiniteAcquisition.Select(Copy(base), 1 / 4)
while selected.result.status == "calculating" do
	selected:Advance(100)
end
Encloses(selected.result, "coverage", 1 / 4)
Check(
	selected.result.have[1] == 2 and selected.result.items[1] == 2,
	"selection retains held and gross inventory semantics"
)
selected = ns.FiniteAcquisition.Select(Copy(base), 1 / 2)
while selected.result.status == "calculating" do
	selected:Advance(100)
end
Check(selected.result.status == "infeasible", "exact crafted C0 determines initial eligibility")
input = Copy(surplus)
input.failureLoss, input.terminalCarry["item:1"] = 0, 10
result = Finish(input)
Encloses(result, "objective", 0)
Check(Initial(result, false).recipeID == 201, "economic auxiliary may dispose of carrying cost without a shortage rule")
local job = ns.FiniteAcquisition.Start(Copy(base))
job:Advance(10)
job:Cancel()
Check(job:Advance(1).status == "cancelled", "caller cancels partial evidence snapshot")
job = ns.FiniteAcquisition.Start(Copy(base))
while job.result.status == "calculating" do
	job:Advance(100)
end
job:Cancel()
Check(job.result.status == "cancelled", "caller cancels completed evidence snapshot")
print("crafted_finite_spec: " .. checks .. " checks passed")
