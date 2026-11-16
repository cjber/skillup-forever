# Conditional recipe evidence

`Core/RecipeEvidence.lua` owns session-only native observations and separate
caller declarations. There is no default declaration, provider or alpha, and
no craft execution. `Inspect(skillLine)` reports `unsupported` with stable
missing-reason codes until a complete declaration is current. Public API minor
12 exposes this report under each profession's `recipeEvidence` without
starting or advancing a job.

`Observe(recipeID, allocation, workLimit)` copies the readable native schematic,
including nested reagent alternatives, variable quantities, slot identities,
required flags and output bounds. It records the exact native profession,
current skill/modifier/cap, recipe requirements, build and caller allocation
identity. This adapter supports only the default-level, non-recraft schema:
`GetRecipeSchematic(recipeID, false)` with no `recipeLevel`. Observation records
`variant = "default-non-recraft"`; recraft or recipe-level request/allocation
fields are explicitly unsupported. Its returned record is an owned copy. Missing capabilities remain
explicit in `missing`. Reobservation replaces freshness and revokes previous
declarations and jobs. Equal output bounds, learned status, grey colour and
mean pricing yield never establish a completed-attempt law.

`Declare(skillLine, declaration, workLimit)` owns a bounded plain, acyclic copy.
The declaration has `version = "crafted-adapter-v1"`,
`universeComplete = true`,
`skillGainLaw = "whole-successful-count-bounded-by-rank"`, a dense `recipes` array of the complete
`SkillUpCraftedRecipe` laws, and three maps keyed by recipe ID:

- `allocations`: `identity`, explicit `complete = true` and dense `slots` in
  native schematic order. Every choice supplies exact `slotIndex`,
  `dataSlotIndex`, `itemID` and integer `quantity`. A zero quantity can omit an
  optional slot. Selected items and quantities must match native alternatives
  and variable quantities; summed use must match the declared consumption.
- `eligibility`: inclusive effective-skill `fromSkill` and `toSkill` bounds, including
  singleton intervals. Each final main interval must fit. During evaluation,
  recipes in the Plan profession use the actual successful-gain skill at the
  current stage. Other-profession neutral auxiliaries use their unchanged
  observed skill plus modifier. Alternatives remain declared even when they
  first become eligible later.
- `prerequisites`: explicit true `rank`, `training`, `tools`, `station` and
  `access` declarations for each recipe. These booleans are caller assumptions,
  not native verification. Known unmet native requirements or final Plan
  training/rank steps cannot be overridden by them.

Every recipe binds `evidence.revision`, `allocation` and `clientBuild` to its
owned observation. Native output bounds constrain the supplied output map but
do not supply its deterministic law. The full declared universe includes every
alternative supplied by the caller, including cross-profession auxiliaries
with an explicit neutral skill law. It never uses the pricing producer's
cheapest subcraft winner. `universeComplete` asserts completeness of this
finite declaration, not discovery of every live recipe. Selection is
conditional on that universe.

An adaptive request opts in with
`crafted = {version = "crafted-adapter-v1", revision = RecipeEvidence.Revision(), skillLine = skillLine}`.
The existing explicit adaptive reader, alpha, shared 64-operation frame,
finite selector and publication owner remain in use. Configured readers may
return existing declarations but cannot call `Observe` or `Declare`: those
bounded producer operations run separately, so a reader cannot add synchronous
observation copies outside the shared snapshot budget. No raw or fixed-refill
contract changes. Final Plan identities, profession, ordered base intervals,
live thresholds and skill-up counts compile into the kernel's effective-skill
legs. Missing bounds, a mismatched native cap or an unmet training/rank gate
remain unsupported. The crafted snapshot supplies an effective `skillCap` and
uses the explicitly declared `skillGainLaw`: a successful main attempt grants its
whole `skillUps` count, bounded by that rank cap, rather than clipping at the
Plan leg target or recipe grey threshold. Overshoot carries into the next leg;
a leg whose target is already reached requires no extra attempt. No-gain
branches preserve effective skill. The certificate records each actual stage
skill and the cap. The count is read by `Core/Live.lua` from native `GetRecipeInfo.numSkillUps`
(default one when absent); the cap is observed `maxSkillLevel` plus
`skillModifier`, matched to the Plan rank. Those observed values do not establish
the gain law. A missing declaration returns
`recipe-successful-skill-gain-law-missing`. Random gain sizes, changing modifiers,
rank transitions and skill-affecting auxiliaries are not modeled. This is a
conditional gain law, not native RNG or grey-crossing verification.

The snapshot owns the complete declaration and native observations, including
nested slot metadata. Its input/output, source product/payment and valuation
coordinates join the existing bags-only native read set. Each coordinate is
read once; caller holdings never fill a missing native value. Completed results
retain `recipeRevision`, `recipeScope = "declared-finite-recipes"` and
`recipeEvidence = {revision, scope, declaration, observations}` beside the
finite certificate. Recipe/allocation/eligibility changes revoke partial and
complete work through Changes ownership. Build freshness is checked before
reuse and by the shared frame. Existing route, chance and resource
invalidation still revoke both partial and complete results. Replacing/removing
an adaptive reader retains the existing cancellation semantics. Getters never
advance a solve. Source owners still owe fresh reconciled finite pools after
resource changes; this recipe declaration cannot restore a source opportunity.

The source boundary is Blizzard-authored definitions at Forever revision
[`bebcb6bf309cf41b41bd74f8ca651e6a105b2676`](https://github.com/Gethe/wow-ui-source/tree/bebcb6bf309cf41b41bd74f8ca651e6a105b2676):
[TradeSkillUIDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/TradeSkillUIDocumentation.lua)
and [TradeSkillUITypesDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/TradeSkillUITypesDocumentation.lua).
The exact native calls are `GetRecipeSchematic(recipeID, false)` (lines 753-766),
`GetProfessionInfoByRecipeID(recipeID)` (473-486) and
`GetRecipeRequirements(recipeID)` (738-750). `ProfessionInfo` defines
`professionID`, `skillLevel`, `maxSkillLevel` and `skillModifier` (types 361-379);
`CraftingRecipeRequirement` defines `met` (270-277). Reagent slot fields and
recipe output bounds are the structures at types 243-258 and 281-295.
These signatures and structures establish no completed-attempt production,
refund/failure semantics or auxiliary neutrality. Tests supply synthetic
conditional laws; no native gameplay proof is claimed. Issue #563 remains
open. Plan.NextCraft, player coverage/margin presentation and craft execution
are unchanged.
