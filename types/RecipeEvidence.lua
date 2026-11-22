---@meta

---@class SkillUpRecipeEvidence
---@field status 'conditional'|'unsupported'
---@field scope 'declared-finite-recipes'
---@field recipeRevision integer
---@field missing {code: string, recipeID: integer?}[]

---@class SkillUpRecipeEvidenceOwner
---@field Inspect fun(skillLine: integer): SkillUpRecipeEvidence
