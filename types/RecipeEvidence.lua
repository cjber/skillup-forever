---@meta

---@class SkillUpRecipeEvidence
---@field status 'conditional'|'unsupported'
---@field scope 'declared-finite-recipes'
---@field recipeRevision integer
---@field missing {code: string, recipeID: integer?}[]

---@class SkillUpRecipeEvidenceOwner
---@field Observe fun(recipeID: integer, allocation: string, workLimit: integer, variant?: table): table?, string?
---@field Declare fun(skillLine: integer, declaration: table, workLimit: integer): boolean, string?
---@field Inspect fun(skillLine: integer): SkillUpRecipeEvidence
---@field ReadRequest fun(read: fun(): SkillUpResupplyInput|SkillUpAdaptiveSupplyRequest|nil, string?): boolean, SkillUpResupplyInput|SkillUpAdaptiveSupplyRequest|nil, string?
---@field Current fun(captured: integer): boolean
---@field Refresh fun()
---@field Revision fun(): integer
---@field Snapshot fun(plan: SkillUpPlan, token: table, tick: fun()): SkillUpCraftedRoute?, string?, table?
