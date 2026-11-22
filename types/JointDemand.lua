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
---@field shortfallItem integer? Only for a single-item marginal projection.
---@field expectedShortfallLower number? Expected units missing after using held and purchased stock.
---@field expectedShortfallUpper number?
---@field costKnown boolean Whether feasible source orders establish observed basket expenditure.
---@field costCopper number? Observed expenditure for feasible source orders, never a market valuation.
---@field reasons string[] Explicit unknown/unsupported/cancellation reasons.

---@class SkillUpJointDemandJob
---@field result SkillUpJointDemandResult
---@field Advance fun(self: SkillUpJointDemandJob, work: integer): SkillUpJointDemandResult
---@field Cancel fun(self: SkillUpJointDemandJob)

---@class SkillUpJointDemandProducer
---@field Prepare fun(input: SkillUpJointDemandInput, tick: fun(), physical?: {skill: integer?, cap: integer}): {chance: number, use: table<integer, integer>, skill: integer}[]?, table<integer, integer>?, SkillUpJointDemandResult?
---@field Start fun(input: SkillUpJointDemandInput): SkillUpJointDemandJob

---@class SkillUpRouteDemandProducer
---@field Summary fun(plan: SkillUpPlan): SkillUpSupplySummary
---@field Vendors fun(item: SkillUpNeededItem|SkillUpAPIShoppingItem, byTravel?: boolean): integer[]
---@field Shortfalls fun(tracked: SkillUpTracked[]): table<integer, number>
---@field Held fun(item: SkillUpNeededItem): number?
---@field ConfigureSupply fun(skillLine: integer, read: (fun(): SkillUpResupplyInput?, string?)?, alpha?: number): boolean, string?
---@field SelectSupply fun(plan: SkillUpPlan, contract: SkillUpResupplyInput, alpha: number): SkillUpSupplyChoiceJob
---@field Supply fun(plan: SkillUpPlan): SkillUpPlanSupply?
---@field StartPolicy fun(plan: SkillUpPlan, contract: SkillUpResupplyInput): SkillUpResupplyJob
---@field Count fun(itemID: integer, includeBank: boolean): integer?, string?
---@field QuoteOrders fun(orders: {offer: SkillUpObservedMerchantOffer, bundles: integer}[]): SkillUpMerchantOrderQuote?, string?
---@field Snapshot fun(plan: SkillUpPlan, buy: table<integer, integer>, includeBank?: boolean, tick?: fun(), deferInventory?: boolean): SkillUpJointDemandInput?, string?
---@field Start fun(plan: SkillUpPlan, buy: table<integer, integer>): SkillUpJointDemandJob
---@field Invalidate fun()
