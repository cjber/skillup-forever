# Recipe evidence

`Core/RecipeEvidence.lua` reports `unsupported` with the stable missing-reason code
`recipe-production-law-missing`, because nothing declares a recipe's completed-attempt law.
`Inspect(skillLine)` answers without reading the client or starting a job. Public API minor 12
exposes this report under each profession's `recipeEvidence`.
