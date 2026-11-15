---@meta

---@class SkillUpJointDemandLeg
---@field fromSkill integer Base skill at this leg's start.
---@field toSkill integer Exclusive skill goal, already split at training/rank boundaries.
---@field skillUps integer? Live guaranteed points on a successful craft.
---@field thresholds number[]? Caller-resolved live thresholds.
---@field use table<integer, integer> Raw item consumption per craft, with duplicate rows summed.
---@field rawConsumption boolean Must explicitly be true; no subcraft expansion or output reuse.
---@field deterministicOutput boolean Must explicitly be true; random outputs unsupported.

---@class SkillUpJointDemandInput
---@field held table<integer, integer> Shared starting inventory, used only once.
---@field buy table<integer, integer> Explicit prepared basket, never an optimized recommendation.
---@field legs SkillUpJointDemandLeg[] Dense fixed final ordered route; immutable for the job's lifetime.

---@class SkillUpJointDemandResult
---@field status 'calculating'|'complete'|'unknown'|'unreachable'|'cancelled'
---@field supported boolean Whether the inventory-transition model supports the input.
---@field coverageKnown boolean Whether coverage bounds are available.
---@field coverageLower number? Conservative lower probability conditional on Model.Chance.
---@field coverageUpper number? Conservative upper probability conditional on Model.Chance.
---@field costKnown boolean Always false: source-aware costs are not implemented by this producer.
---@field reasons string[] Explicit unknown/unsupported/cancellation reasons.

---@class SkillUpJointDemandJob
---@field result SkillUpJointDemandResult
---@field Advance fun(self: SkillUpJointDemandJob, work: integer): SkillUpJointDemandResult
---@field Cancel fun(self: SkillUpJointDemandJob)

---@class SkillUpJointDemandProducer
---@field Start fun(input: SkillUpJointDemandInput): SkillUpJointDemandJob

---@class SkillUpRouteDemandProducer
---@field Snapshot fun(plan: SkillUpPlan, buy: table<integer, integer>): SkillUpJointDemandInput?, string?
---@field Start fun(plan: SkillUpPlan, buy: table<integer, integer>): SkillUpJointDemandJob
---@field Invalidate fun()
