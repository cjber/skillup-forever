local ns = {}
assert(loadfile("Core/Model.lua"))("SkillUpForever", ns)
assert(loadfile("Core/Demand.lua"))("SkillUpForever", ns)
local input = {
	held = {},
	legs = {
		{
			fromSkill = 1,
			toSkill = 2,
			skillUps = 1,
			thresholds = { 0, 0, 0, 2 },
			use = { [1] = 1 },
			rawConsumption = true,
			deterministicOutput = true,
		},
		{
			fromSkill = 1,
			toSkill = 2,
			skillUps = 1,
			thresholds = { 0, 0, 0, 2 },
			use = { [1] = 1 },
			rawConsumption = true,
			deterministicOutput = true,
		},
	},
}

local function Finish(job)
	for _ = 1, 10000 do
		if job.result.status ~= "calculating" then
			return job.result
		end
		job:Advance(1)
	end
	error("basket job exceeded fixture work budget")
end
local function Costs(trip, unit)
	return { tripCopper = trip, unitCopper = { [1] = unit or 0 } }
end
local baskets = { { [1] = 2 }, { [1] = 4 } }
local job = ns.Demand.StartBasketChoice(input, baskets, Costs(100), { [1] = 1 })
assert(job.result.status == "calculating", "creation does no demand work")
job:Advance(1)
assert(job.result.status == "calculating", "one work unit does not drain the evaluator")
local expensive = Finish(job)
assert(expensive.status == "complete" and expensive.basket[1] == 4, "expensive shortfall buys extra stock")
assert(expensive.coverageLower > 0 and expensive.coverageUpper <= 1, "choice retains joint coverage bounds")
assert(expensive.costLower <= expensive.costUpper, "choice retains expected cost bounds")
local cheap = Finish(ns.Demand.StartBasketChoice(input, baskets, Costs(0), { [1] = 1 }))
assert(cheap.status == "complete" and cheap.basket[1] == 2, "cheap shortfall does not justify extra stock")
local replacement = Finish(ns.Demand.StartBasketChoice(input, baskets, Costs(0, 10), { [1] = 1 }))
assert(replacement.status == "complete" and replacement.basket[1] == 4, "replacement cost alone can justify spares")
assert(
	replacement.costLower <= 11.5 and replacement.costUpper >= 11.5,
	"four purchases plus 0.75 expected missing units at ten copper"
)
local correlated = {
	held = {},
	legs = {
		{
			fromSkill = 1,
			toSkill = 2,
			skillUps = 1,
			thresholds = { 0, 0, 0, 2 },
			use = { [1] = 1, [2] = 1 },
			rawConsumption = true,
			deterministicOutput = true,
		},
	},
}
local marginal = Finish(
	ns.Demand.StartBasketChoice(
		correlated,
		{ { [1] = 1, [2] = 2 } },
		{ tripCopper = 0, unitCopper = { [1] = 10, [2] = 2 } },
		{ [1] = 1, [2] = 1 }
	)
)
assert(
	marginal.status == "complete" and marginal.costLower <= 14 and marginal.costUpper >= 14,
	"joint clipping never hides the second reagent's 0.5 expected missing units"
)
local missingReplacement =
	Finish(ns.Demand.StartBasketChoice(input, baskets, { tripCopper = 0, unitCopper = {} }, { [1] = 1 }))
assert(missingReplacement.status == "unknown", "missing resupply observations stay unknown")
local unknown = Finish(ns.Demand.StartBasketChoice(input, baskets, Costs(100), {}))
assert(
	unknown.status == "unknown" and unknown.reasons[1] == "observed basket cost unavailable",
	"unknown prices stay unknown"
)
for _, invalid in ipairs({ math.huge, -math.huge, 0 / 0, -1 }) do
	assert(Finish(ns.Demand.StartBasketChoice(input, baskets, Costs(invalid), { [1] = 1 })).status == "unknown")
	assert(Finish(ns.Demand.StartBasketChoice(input, baskets, Costs(0, invalid), { [1] = 1 })).status == "unknown")
	assert(Finish(ns.Demand.StartBasketChoice(input, { { [1] = invalid } }, Costs(1), { [1] = 1 })).status == "unknown")
	assert(Finish(ns.Demand.StartBasketChoice(input, baskets, Costs(1), { [1] = invalid })).status == "unknown")
end
local sparse = Finish(ns.Demand.StartBasketChoice(input, { [2] = { [1] = 2 } }, Costs(1), { [1] = 1 }))
assert(sparse.status == "unknown", "a candidate prefix is never certified")
local starts, original = 0, ns.Demand.Start
ns.Demand.Start = function(value)
	starts = starts + 1
	return original(value)
end
Finish(ns.Demand.StartBasketChoice(input, baskets, Costs(100), { [1] = 1 }))
assert(starts == 4, "each basket evaluator persists across all work ticks")
ns.Demand.Start = original
local cancelled = ns.Demand.StartBasketChoice(input, baskets, Costs(100), { [1] = 1 })
for _ = 1, 8 do
	cancelled:Advance(1)
end
cancelled:Cancel()
assert(cancelled:Advance(1).status == "cancelled", "cancellation cannot resume demand work")
local stale = ns.Demand.StartBasketChoice(input, baskets, Costs(100), { [1] = 1 })
stale:Advance(1)
local revision = ns.Model.ChanceRevision
ns.Model.ChanceRevision = function()
	return revision() + 1
end
assert(stale:Advance(1).status == "unknown", "chance changes revoke a pending choice")
ns.Model.ChanceRevision = revision
print("count margin: scheduling, shared inventory, observed costs and invalidation pass")
