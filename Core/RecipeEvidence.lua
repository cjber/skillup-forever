---@type string, SkillUpNamespace
local _, ns = ...
if ns.broken then
	return
end

-- No provider declares a recipe's completed-attempt law, so the public report is always "unsupported".
local Owner = {}

---@param _ integer Plan skill-line identity.
---@return SkillUpRecipeEvidence
function Owner.Inspect(_)
	return {
		status = "unsupported",
		scope = "declared-finite-recipes",
		recipeRevision = 0,
		missing = { { code = "recipe-production-law-missing" } },
	}
end

---@cast Owner SkillUpRecipeEvidenceOwner
ns.RecipeEvidence = Owner
