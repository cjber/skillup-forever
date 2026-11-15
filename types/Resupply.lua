---@meta

---@class SkillUpResupplyStage
---@field chance number? Supplied Model probability, after gain expansion. Zero is unreachable.
---@field use integer[] Dense raw deterministic consumption, indexed by input inventory coordinate.

---@class SkillUpResupplySource
---@field group string Unique explicit visit group, one coherent record per group.
---@field items integer[] One-based inventory coordinates, exactly one source owner per item.
---@field bundleQuantities integer[] Required positive physical units per acquisition bundle; stock vectors count physical units.
---@field targets integer[] Finite order-up-to storage caps, including capped_batch policies.
---@field mode 'order_up_to'|'capped_batch'
---@field batch integer[]? Required for capped_batch, clipped to targets.
---@field perVisitStock integer[]|'unlimited' Explicit renewed availability on EVERY visit.
---@field totalStock integer[]|'unlimited' Explicit remaining ledger AFTER initial acquisition, or unlimited replenishment.
---@field kind 'vendor'|'auction'|'farm'
---@field provenance 'observed'|'entered'|'measured'
---@field ageSeconds number? Required for market cost estimates, no invented age cutoff.
---@field units number[]? Market per-unit costs, separate from initial quotes.
---@field visitFee number? Market fee charged even on an empty triggered visit.
---@field workSeconds number? Farm deterministic work per yield, no random yield model.
---@field yieldUnits number? Farm yield, strictly positive.
---@field setupSeconds number? Farm setup on every refill visit.
---@field copperPerSecond number? Explicit player time valuation. Missing effort blocks cost estimation.

---@class SkillUpResupplyInput
---@field inventory integer[] Shared held plus actually acquired inventory. Held inventory is sunk.
---@field terminalUnitValues number[]? Explicit nonnegative copper value per leftover physical unit, on success and blocked termination. Missing blocks objective comparison.
---@field initialCost number? Separately supplied initial acquisition cost, zero must be explicit.
---@field stages SkillUpResupplyStage[] Dense ordered raw route; no subcraft/random output support.
---@field sources SkillUpResupplySource[] Dense selected policy array only, no source optimization.
---@field maxStates integer Caller resource cap. Exceeding it returns unsupported without partial results.

---@class SkillUpResupplyResult
---@field status 'calculating'|'estimated'|'unsupported'|'unknown'|'unreachable'|'cancelled'
---@field coverageKnown boolean Legacy flag always false; optional certificate supplies selected-policy bounds.
---@field costKnown boolean Legacy flag always false; optional certificate supplies selected-policy bounds.
---@field rankable boolean Always false, never probability-only ranking.
---@field reasons string[]
---@field completionEstimate number?
---@field withoutRefillEstimate number?
---@field expectedCostEstimate number? Absent when price, age, provenance, farm effort or initial cost is unknown.
---@field expectedAttemptsEstimate number?
---@field visitsEstimate table<string, number>?
---@field unitsEstimate number[]?
---@field states integer?
---@field policyScope string? Restricted selected source policy, never unrestricted optimality.
---@field expectedSurplusValueEstimate number?
---@field netCostEstimate number? Initial and refill spend minus explicit terminal surplus value.
---@field netCostLower number? Outward net objective enclosure.
---@field netCostUpper number?
---@field constraintStatus 'feasible'|'infeasible'|'unknown'?
---@field costScope string? Spend until completion OR declared stock-blocked termination.
---@field certificate { errorBound: number, costErrorBound: number?, maxResidual: number, transientBound: number }? Selected-policy numerical enclosure, consumed by Compare; legacy authority flags stay false.

---@class SkillUpResupplyJob
---@field result SkillUpResupplyResult
--- Failed evaluation returns terminal unsupported and releases its coroutine.
---@field Advance fun(self: SkillUpResupplyJob, work: integer): SkillUpResupplyResult
---@field Cancel fun(self: SkillUpResupplyJob)

---@class SkillUpResupplyProducer
---@field Start fun(input: SkillUpResupplyInput): SkillUpResupplyJob
---@field Compare fun(input: SkillUpResupplyComparisonInput): SkillUpResupplyComparisonJob

---@class SkillUpResupplyComparisonInput
---@field candidates SkillUpResupplyInput[] Explicit dense nonempty finite basket/policy domain, immutable until completion. Each inventory is held plus physically acquired bundles and initialCost is the actual corresponding spend; caller establishes stock feasibility. No implicit enumeration/cap.
---@field minCompletion number Explicit [0,1] eventual route completion constraint, not initial no-refill confidence.

---@class SkillUpResupplyComparisonResult
---@field status 'calculating'|'complete'|'unknown'|'unsupported'|'infeasible'|'cancelled'
---@field reasons string[]
---@field evaluations SkillUpResupplyResult[]?
---@field chosenIndex integer? Only a certified strict minimum among feasible declared candidates. Overlapping bounds remain unknown.
---@field domainScope string? Finite declared baskets and selected reactive policies only; no unrestricted policy optimum.

---@class SkillUpResupplyComparisonJob
---@field result SkillUpResupplyComparisonResult
---@field Advance fun(self: SkillUpResupplyComparisonJob, work: integer): SkillUpResupplyComparisonResult
---@field Cancel fun(self: SkillUpResupplyComparisonJob)
