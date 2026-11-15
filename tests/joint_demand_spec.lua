local ns = {}
assert(loadfile("Core/Model.lua"))("SkillUpForever", ns)
assert(loadfile("Core/Demand.lua"))("SkillUpForever", ns)
local checks = 0
local function Check(ok, label)
	checks = checks + 1
	assert(ok, label)
end
local function Leg(first, last, use, thresholds, gain)
	return {
		fromSkill = first,
		toSkill = last,
		use = use,
		thresholds = thresholds or { 0, 0, 0, 2 },
		skillUps = gain,
		rawConsumption = true,
		deterministicOutput = true,
	}
end
local function Run(legs, held, buy, budget)
	local job = ns.Demand.Start({ legs = legs, held = held or {}, buy = buy or {} })
	while job.result.status == "calculating" do
		job:Advance(budget or 17)
	end
	return job.result
end
local function Encloses(result, exact, label)
	Check(result.coverageKnown, label .. " known")
	Check(result.coverageLower <= exact and result.coverageUpper >= exact, label .. " encloses exact oracle")
	Check(result.coverageUpper - result.coverageLower < 1e-10, label .. " tight")
	Check(not result.costKnown, label .. " cannot rank source costs")
end
local shared = { Leg(1, 2, { [1] = 1 }), Leg(1, 2, { [1] = 1 }) }
Encloses(Run(shared, { [1] = 2 }, { [1] = 6 }), 247 / 256, "pooled leftovers")
Encloses(Run(shared, {}, { [1] = 7 }), 15 / 16, "below whole-route target")
Encloses(
	Run({ Leg(1, 2, { [1] = 1 }), Leg(1, 2, { [2] = 1 }) }, {}, { [1] = 5, [2] = 5 }),
	961 / 1024,
	"marginals do not certify joint"
)
Encloses(Run({ Leg(0, 2, { [1] = 1 }) }, {}, { [1] = 5 }), 15 / 16, "changing chance")
Encloses(Run({ Leg(1, 2, {}) }), 1, "zero consumption infinite tail")
Encloses(Run({}, {}, {}), 1, "empty route")
local missing = Leg(1, 2, { [1] = 1 })
missing.thresholds = nil
Check(not Run({ missing }).coverageKnown, "unknown chance stays unknown")
Check(Run({ Leg(2, 3, { [1] = 1 }) }).status == "unreachable", "grey unreachable")
local unsupported = Leg(1, 2, { [1] = 1 })
unsupported.rawConsumption = false
Check(not Run({ unsupported }).supported, "subcraft explicitly unsupported")
Check(not Run(shared, { [1] = -1 }).supported, "invalid inventory")
local input = { legs = shared, held = {}, buy = { [1] = 1000000 } }
local job = ns.Demand.Start(input)
Check(job:Advance(1).status == "calculating", "bounded work yields")
job:Cancel()
Check(job:Advance(1).status == "cancelled" and not job.result.coverageKnown, "cancel discards incomplete result")
local changing = ns.Demand.Start(input)
changing:Advance(1)
ns.Model.SetChanceBonus(0.25)
Check(
	not changing:Advance(1).coverageKnown and changing.result.status == "unknown",
	"changed chance invalidates snapshot"
)
ns.Model.SetChanceBonus(0)
local stage = ns.Model.DemandStage({ 0, 10, 20, 30 }, 25, 4, 30)
Check(stage.chance == 0.25 and stage.gain == 4, "stage uses live chance and capped gain")
Check(ns.Model.DemandStage({ 0, 10, 20, 30 }, 30, 1, 31).chance == 0, "grey stage remains unreachable")
print("joint demand: " .. checks .. " checks passed")
