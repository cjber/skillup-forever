---@meta

---@class SkillUpSupplyChoiceResult: SkillUpResupplyResult
---@field items table<integer, integer>? Shared initial raw inventory budget, before initial token payments.
---@field have table<integer, integer>? Fresh inventory snapshot.
---@field orders SkillUpPolicyOrder[]? Selected initial transactions.
---@field quantities integer[]? Bundles by distinct source index.
---@field alpha number? Explicit starting coverage constraint.

---@class SkillUpSupplyChoiceJob
---@field result SkillUpSupplyChoiceResult
---@field Advance fun(self: SkillUpSupplyChoiceJob, work: integer): SkillUpSupplyChoiceResult
---@field Cancel fun(self: SkillUpSupplyChoiceJob)

---@class SkillUpSupplyChoiceProducer
---@field Start fun(input: SkillUpResupplyInput, alpha: number): SkillUpSupplyChoiceJob Immutable inputs, one fixed refill policy.

---@class SkillUpSupplyConfiguration
---@field read fun(): SkillUpResupplyInput?, string?
---@field alpha number
---@field dirty boolean
---@field job SkillUpSupplyChoiceJob?
