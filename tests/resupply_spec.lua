local ns = {}
assert(loadfile("Core/Resupply.lua"))("SkillUpForever", ns)
local checks = 0
local function Check(ok, label)
	checks = checks + 1
	assert(ok, label)
end
local function Near(a, b, label)
	Check(type(a) == "number" and math.abs(a - b) < 1e-9, label)
end
local function Source(items, targets, fee, units, group)
	return {
		group = group or "shop",
		items = items or { 1 },
		targets = targets or { 2 },
		bundleQuantities = (function()
			local t = {}
			for i = 1, #(items or { 1 }) do
				t[i] = 1
			end
			return t
		end)(),
		units = units or { 3 },
		visitFee = fee or 12,
		kind = "vendor",
		provenance = "observed",
		ageSeconds = 3600,
		perVisitStock = "unlimited",
		totalStock = "unlimited",
		mode = "order_up_to",
	}
end
local function Input(stages, inventory, sources)
	return {
		stages = stages or { { chance = 0.5, use = { 1 } } },
		inventory = inventory or { 2 },
		sources = sources or { Source() },
		initialCost = 0,
		maxStates = 100,
	}
end
local function Run(input, budget)
	local job = ns.Resupply.Start(input)
	while job.result.status == "calculating" do
		job:Advance(budget or 13)
	end
	Check(
		not job.result.coverageKnown and not job.result.rankable and not job.result.costKnown,
		"no false certification or ranking"
	)
	return job.result
end
-- Independent Fraction fixtures: skillup563-causal/{PROOF.md,test_causal.py}.
-- These are synthetic declared policies, never observations of game behavior.
local result = Run(Input())
Check(result.certificate ~= nil, "finite policy carries a residual certificate")
Check(result.certificate.errorBound >= result.certificate.maxResidual, "error bound rounds outward")
Check(result.certificate.costErrorBound >= result.certificate.errorBound, "initial cost rounding is enclosed")
Near(result.visitsEstimate.shop, 1 / 3, "every repeated trip")
Near(result.unitsEstimate[1], 2 / 3, "batch surplus purchased")
Near(result.expectedCostEstimate, 6, "causal cost, old pooled loss was 9/2")
Check(result.expectedCostEstimate ~= 9 / 2, "reject old pooled-loss physical cost")
Near(result.withoutRefillEstimate, 3 / 4, "initial coverage")
Near(result.completionEstimate, 1, "eventual completion estimate")
local grouped = Run(Input({ { chance = 1, use = { 1, 1 } } }, { 0, 0 }, { Source({ 1, 2 }, { 1, 1 }, 7, { 1, 1 }) }))
Near(grouped.expectedCostEstimate, 9, "one group one fee")
local split = Run(Input({ { chance = 1, use = { 1, 1 } } }, { 0, 0 }, {
	Source({ 1 }, { 1 }, 7, { 1 }, "A"),
	Source({ 2 }, { 1 }, 7, { 1 }, "B"),
}))
Near(split.expectedCostEstimate, 16, "two declared groups two fees")
local stages = { { chance = 0.5, use = { 1 } }, { chance = 0.5, use = { 1 } } }
local shared = Run(Input(stages, { 0 }, { Source(nil, nil, 1, { 0 }) }))
Near(shared.visitsEstimate.shop, 20 / 9, "shared leftovers across stages")
Near(shared.expectedAttemptsEstimate, 4, "full geometric tails")
Near(Run(Input(stages, { 2 }, { Source(nil, nil, 1, { 0 }) })).visitsEstimate.shop, 11 / 9, "initial shared stock")
local finite = Source(nil, { 1 }, 1, { 1 })
finite.totalStock, finite.perVisitStock = { 2 }, { 1 }
local exhausted = Run(Input(nil, { 0 }, { finite }))
Near(exhausted.completionEstimate, 3 / 4, "finite stock terminates")
Near(exhausted.expectedAttemptsEstimate, 3 / 2, "finite attempts")
Near(exhausted.visitsEstimate.shop, 7 / 4, "empty final visit charged")
Near(exhausted.expectedCostEstimate, 13 / 4, "cost until success or stock stop")
local batch = Source(nil, { 4 }, 0, { 1 })
batch.mode, batch.batch = "capped_batch", { 2 }
Near(Run(Input(nil, { 0 }, { batch })).unitsEstimate[1], 8 / 3, "capped batch oracle")
local blocked = Run(Input({ { chance = 1, use = { 3 } } }, { 0 }, { batch }))
Near(blocked.completionEstimate, 0, "one insufficient visit, no invented retry")
Near(blocked.expectedAttemptsEstimate, 0, "unaffordable craft never attempted")
Near(blocked.unitsEstimate[1], 2, "partial buy retained in cost")
for _, field in ipairs({ "ageSeconds", "visitFee", "units" }) do
	local source = Source()
	source[field] = nil
	local unknown = Run(Input(nil, nil, { source }))
	Check(
		unknown.status == "estimated" and unknown.expectedCostEstimate == nil,
		"missing evidence blocks cost: " .. field
	)
	Near(unknown.completionEstimate, 1, "independent probability estimate retained")
end
for _, field in ipairs({ "totalStock", "perVisitStock" }) do
	local source = Source()
	source[field] = nil
	Check(Run(Input(nil, nil, { source })).status == "unknown", "availability unknown: " .. field)
end
local farm = Source(nil, nil, 0, { 999 })
farm.kind, farm.provenance = "farm", "entered"
farm.workSeconds, farm.yieldUnits, farm.copperPerSecond, farm.setupSeconds = 6, 2, 2, 5
Near(Run(Input(nil, { 0 }, { farm })).expectedCostEstimate, 88 / 3, "farm explicit effort conversion")
farm.workSeconds = nil
Check(Run(Input(nil, { 0 }, { farm })).expectedCostEstimate == nil, "farm scalar quote cannot replace effort")
local initial = Input({ { chance = 1, use = { 1 } } }, { 1 })
initial.initialCost = 123
Near(Run(initial).expectedCostEstimate, 123, "separate actual initial acquisition cost")
initial.initialCost = nil
Check(Run(initial).expectedCostEstimate == nil, "missing initial cost not free")
local missingChance = Input({ { use = { 1 } } })
Check(Run(missingChance).status == "unknown", "missing chance explicit")
local zeroChance = Input({ { chance = 0, use = { 1 } } })
Check(Run(zeroChance).status == "unreachable", "zero chance explicit")
local tinyChance = Input({ { chance = 2 ^ -60, use = { 0 } } })
Check(Run(tinyChance).status == "unsupported", "lost numerical pivot cannot certify")
local noBudget = Input()
noBudget.maxStates = nil
Check(Run(noBudget).status == "unsupported", "no fitted default state budget")
local capped = Input()
capped.maxStates = 1
local limited = Run(capped)
Check(
	limited.status == "unsupported" and limited.completionEstimate == nil,
	"resource limit gives no partial certificate"
)
local job = ns.Resupply.Start(Input())
Check(job:Advance(1).status == "calculating", "incremental work begins with snapshot")
job:Cancel()
Check(job:Advance(1).status == "cancelled", "cancellation remains terminal")
local deterministic = Run(Input(), 1)
Near(deterministic.expectedCostEstimate, result.expectedCostEstimate, "scheduler budget does not change policy")
-- Review regressions: malformed routes must never silently evaluate a prefix.
for _, stagesInput in ipairs({
	{ [1] = { chance = 1, use = { 1 } }, [3] = { chance = 0, use = { 1 } } },
	{ false },
	{ { chance = 1, use = { 1 } }, extra = true },
}) do
	Check(Run(Input(stagesInput)).status == "unsupported", "reject malformed or sparse stages")
end
local overflowSource = Source(nil, nil, nil, { 1e308 })
overflowSource.visitFee = nil
local overflow = Run(Input({ { chance = 1, use = { 1 } } }, { 0 }, { overflowSource }))
Check(overflow.status == "estimated" and overflow.expectedCostEstimate == nil, "unknown money cannot poison solve")
Near(overflow.completionEstimate, 1, "overflow isolated from probability")
local broken = Input()
setmetatable(broken.stages[1], {
	__index = function()
		error("synthetic input read failure")
	end,
})
broken.stages[1].chance = nil
local failedJob = ns.Resupply.Start(broken)
while failedJob.result.status == "calculating" do
	failedJob:Advance(1)
end
Check(failedJob.result.status == "unsupported", "failed resume terminalizes")
Check(failedJob:Advance(1).status == "unsupported", "failed job polling stays terminal")
-- Count actual executed Lua loop headers, independent of source line numbers.
local sourceFile = assert(io.open("Core/Resupply.lua"))
local headers, lineNumber = {}, 0
for line in sourceFile:lines() do
	lineNumber = lineNumber + 1
	if line:match("for _, stock in ipairs%(stocks%) do") then
		headers[lineNumber] = true
	end
end
sourceFile:close()
local manySources, manyHeld, consumption = {}, {}, {}
for i = 1, 300 do
	manySources[i] = Source({ i }, { 1 }, 1, { 1 }, tostring(i))
	manyHeld[i], consumption[i] = 1, 1
end
local bounded = ns.Resupply.Start(Input({ { chance = 1, use = consumption } }, manyHeld, manySources))
local observed, largest = 0, 0
local originalResume = coroutine.resume
coroutine.resume = function(thread, ...) -- luacheck: ignore 122
	debug.sethook(thread, function(_, line)
		if headers[line] then
			observed = observed + 1
		end
	end, "l")
	return originalResume(thread, ...)
end
jit.off()
for _ = 1, 30000 do
	observed = 0
	bounded:Advance(1)
	largest = math.max(largest, observed)
	if bounded.result.status ~= "calculating" then
		break
	end
end
coroutine.resume = originalResume -- luacheck: ignore 122
bounded:Cancel()
Check(largest > 0 and largest <= 2, "every unlimited stock group yields")
local emptySources, accesses = {}, 0
for i = 1, 1000 do
	local entry = Source({}, {}, 1, {}, tostring(i))
	entry.group = nil
	setmetatable(entry, {
		__index = function(_, key)
			if key == "group" then
				accesses = accesses + 1
				return tostring(i)
			end
		end,
	})
	emptySources[i] = entry
end
local emptyJob = ns.Resupply.Start(Input(nil, nil, emptySources))
local mostAccesses = 0
for _ = 1, 3000 do
	local before = accesses
	emptyJob:Advance(1)
	mostAccesses = math.max(mostAccesses, accesses - before)
	if emptyJob.result.status ~= "calculating" then
		break
	end
end
emptyJob:Cancel()
Check(accesses > 0 and mostAccesses <= 5, "source validation bounded per resume")
-- Bundle rounding preserves physical acquisition and the finite stock ledger.
local bundles = Source(nil, { 5 }, 0, { 2 })
bundles.bundleQuantities, bundles.totalStock = { 3 }, { 5 }
local bundled = Run(Input({ { chance = 1, use = { 1 } } }, { 0 }, { bundles }))
Near(bundled.unitsEstimate[1], 3, "whole bundle, not five loose units")
Near(bundled.expectedCostEstimate, 6, "bundle spend")
local finiteBundles = Run(Input({ { chance = 0.5, use = { 1 } } }, { 0 }, { bundles }))
Near(finiteBundles.completionEstimate, 7 / 8, "leftover stock cannot form another whole bundle")
Near(finiteBundles.expectedCostEstimate, 6, "unusable stock never purchased")
bundles.bundleQuantities = nil
Check(Run(Input(nil, nil, { bundles })).status == "unknown", "unknown bundle size stays unknown")
local backup = Source(nil, { 1 }, 0, { 10 }, "backup")
Check(Run(Input(nil, nil, { Source(), backup })).status == "unsupported", "finite then backup policy unsupported")
local valued = Input({ { chance = 1, use = { 1 } } }, { 3 })
valued.terminalUnitValues = { 4 }
local surplus = Run(valued)
Near(surplus.expectedSurplusValueEstimate, 8, "successful terminal surplus valued")
Near(surplus.netCostEstimate, -8, "explicit value may exceed spend")
Check(surplus.netCostLower <= -8 and surplus.netCostUpper >= -8, "net objective enclosure")
local stochasticSurplus = Input()
stochasticSurplus.terminalUnitValues = { 4 }
local stochasticValue = Run(stochasticSurplus)
Near(stochasticValue.expectedSurplusValueEstimate, 8 / 3, "geometric odd-attempt terminal leftover")
Check(
	stochasticValue.netCostLower <= 10 / 3 and stochasticValue.netCostUpper >= 10 / 3,
	"stochastic objective enclosure"
)
local stop = Input({ { chance = 1, use = { 3 } } }, { 2 }, { Source(nil, { 0 }, 0, { 0 }) })
stop.terminalUnitValues = { 4 }
Near(Run(stop).expectedSurplusValueEstimate, 8, "blocked terminal surplus valued")
local function Compare(candidates, minimum)
	local comparison = ns.Resupply.Compare({ candidates = candidates, minCompletion = minimum })
	while comparison.result.status == "calculating" do
		comparison:Advance(19)
	end
	return comparison.result
end
local cheapFailure = Input({ { chance = 1, use = { 1 } } }, { 0 }, { Source(nil, { 0 }, 0, { 0 }) })
cheapFailure.terminalUnitValues = { 0 }
local complete = Input({ { chance = 1, use = { 1 } } }, { 1 })
complete.initialCost, complete.terminalUnitValues = 10, { 0 }
local comparison = Compare({ cheapFailure, complete }, 0.95)
Check(comparison.status == "complete" and comparison.chosenIndex == 2, "cheap early failure cannot win")
Check(comparison.evaluations[1].constraintStatus == "infeasible", "completion constraint explicit")
local unvalued = Input({ { chance = 1, use = { 1 } } }, { 1 })
Check(Compare({ unvalued }, 0.95).status == "unknown", "no invented surplus valuation")
Check(Compare({ complete, complete }, 0.95).status == "unknown", "overlapping objectives not ranked")
Check(Compare({ cheapFailure }, 0.95).status == "infeasible", "empty feasible set")
Check(Compare({ [2] = complete }, 0.95).status == "unsupported", "dense finite domain required")
Check(Compare({ complete }, nil).status == "unsupported", "no invented completion target")
local compareJob = ns.Resupply.Compare({ candidates = { complete }, minCompletion = 0.95 })
compareJob:Advance(3)
compareJob:Cancel()
Check(compareJob:Advance(1).status == "cancelled", "comparison cancellation terminal")
-- Optional machine-readable differential harness. External Python remains exact
-- and independent; this test never imports its equations into production Lua.
if arg and arg[1] == "--oracle-grid" then
	for denominator = 1, 5 do
		for numerator = 1, denominator do
			for held = 0, 3 do
				for total = 0, 3 do
					local source = Source(nil, { 2 }, 3, { 2 })
					source.totalStock = { total }
					local r = Run(Input({ { chance = numerator / denominator, use = { 1 } } }, { held }, { source }))
					print(
						string.format(
							"%d %d %d %d %.17g %.17g %.17g %.17g",
							numerator,
							denominator,
							held,
							total,
							r.completionEstimate,
							r.withoutRefillEstimate,
							r.expectedCostEstimate,
							r.visitsEstimate.shop
						)
					)
				end
			end
		end
	end
else
	print("resupply_spec: " .. checks .. " checks passed")
end
