---@meta

-- Explicit mathematical supply laws. No field is inferred from a merchant
-- quote, historical stock, an auction valuation, an icon or a display name.
---@class SkillUpPolicySource
---@field offerID string? Explicit source-owner identity.
---@field npcID integer? Explicit navigation identity.
---@field itemID integer
---@field bundleUnits integer
---@field moneyCopper integer Per bundle, debited from the shared wallet.
---@field costs table<string, integer> Complete canonical item:ID/currency:ID requirements per bundle.
---@field maxBundles integer Declared PER TRANSACTION ceiling, not a visit limit.
---@field vendor string Explicit shared visit identity.
---@field stockKey string Shared stock pool identity; different offers may share one.
---@field stockPerBundle integer Declared stock units consumed by one bundle.
---@field access boolean Explicit current/future access law for this model.
---@field priceLaw 'fixed' Explicit conditional law, not a promise from an observation.

---@class SkillUpPolicyOrder
---@field source integer Index in the immutable source list, preserving distinct offers.
---@field bundles integer Positive integer transaction quantity.

---@class SkillUpPolicyOptions
---@field probabilityTolerance number
---@field costTolerance number
---@field visitTolerance number
---@field workLimit integer
---@field stateLimit integer Maximum live states, exhaustion means unknown.
---@field coordinateLimit integer Bounds sorting/key construction dimensions.

---@class SkillUpResupplyInput
---@field sourceRevision integer? Session-only source-owner revision.
---@field assumptions SkillUpSourceAssumption[]? Explicit scoped law provenance.
---@field route SkillUpJointDemandInput buy must be empty; initial orders are checked separately.
---@field service 'fixed-batch' Every shortage attempts the declared batch, with no discretionary stop.
---@field journey 'independent-round-trips' Distinct vendors add one explicit trip cost per batch.
---@field walletCopper integer|'unlimited' Explicit budget law; native balances are finite.
---@field currencies table<integer, integer>
---@field stock table<string, integer|'unlimited'> Explicit stock law in declared units, never raw numAvailable.
---@field sources SkillUpPolicySource[]
---@field tokenValues table<string, number> Explicit nonnegative opportunity value per typed token unit.
---@field initialOrders SkillUpPolicyOrder[] Atomic batch, products cannot bootstrap its payments.
---@field refillOrders SkillUpPolicyOrder[] Same atomic batch on every shortage; must enable the next craft.
---@field initialVisitCosts table<string, number> Explicit incremental acquisition/travel values.
---@field refillVisitCosts table<string, number>
---@field options SkillUpPolicyOptions

---@class SkillUpResupplyResult
---@field status 'calculating'|'complete'|'unknown'|'cancelled'|'unattained' The selector alone can prove nonattainment.
---@field reasons string[]
---@field initialFeasible boolean? False only for proved initial batch infeasibility.
---@field costKnown boolean Conditional on all explicit policy laws, never live supply certification.
---@field coverageLower number? C0: completion using the initial post-purchase inventory alone.
---@field coverageUpper number?
---@field successLower number? Ppi: completion after subsequent policy acquisitions.
---@field successUpper number?
---@field costLower number? Initial plus repeated money, token opportunity values and visit costs.
---@field costUpper number?
---@field visitsLower number? Initial plus later distinct vendor visits.
---@field visitsUpper number?

---@class SkillUpResupplyJob
---@field result SkillUpResupplyResult
---@field Advance fun(self: SkillUpResupplyJob, work: integer): SkillUpResupplyResult
---@field Cancel fun(self: SkillUpResupplyJob)

---@class SkillUpResupplyProducer
---@field Start fun(input: SkillUpResupplyInput): SkillUpResupplyJob Inputs immutable throughout the job.

---@class SkillUpPolicyState
---@field balances table<string, integer>
---@field stock table<string, integer|'unlimited'>
---@field wallet integer|'unlimited'

---@class SkillUpPolicyBatch
---@field products table<string, integer>
---@field costs table<string, integer>
---@field stock table<string, integer>
---@field money integer
---@field low number
---@field high number
---@field visits integer
---@field access boolean?
