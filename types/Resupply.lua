---@meta

---@class SkillUpPolicyOrder
---@field source integer Index in the immutable source list, preserving distinct offers.
---@field bundles integer Positive integer transaction quantity.

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
