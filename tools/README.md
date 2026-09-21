Regenerate from the repository root with Python 3 (standard library only):

```sh
python3 tools/gen_thresholds.py
python3 tools/gen_vendor.py
python3 tools/gen_recipes.py
python3 tools/gen_trainer.py
luacheck Model.lua tests/ --std lua51
luajit tests/model_spec.lua
```

The generator pins Forever `1.60.1.69913` and a Skillet-Classic commit, caches
downloads in `tools/.cache/`, and writes sorted `Data/Thresholds.lua`. Use
`--refresh` to download again or `--offline` to require cached sources. The header
date identifies the selected source snapshot, so repeated runs are byte-identical.

Wago's `SkillLineAbility` supplies yellow/grey and fallback orange; green is their
floored midpoint. `SkillLine` discovers professions and child lines; `SpellName`
supplies comments. Same-build `SpellEffect` maps created items to recipe spells
for Skillet's item-keyed requirements. A baseline orange is accepted only when
yellow/grey match; scraped `SkillLevels` takes priority over `SkillLineAbility`.
Every row records orange provenance. DB2-derived orange values need a live audit.
Contradictory DB2 requirements (`orange > yellow`, currently spells 2665 and
2674) are retained and flagged, never clamped or replaced with guessed values.

Coverage prints per skill line, including skipped/duplicate rows and missing
names. Gathering abilities and test professions are excluded. Shared recipes
count once per profession but occupy one output key. DB2 download/schema failures
leave existing output untouched; an unavailable Skillet baseline produces a
warning and retains DB2 values. Baseline-derived portions are GPL-3.0-or-later.

`gen_vendor.py` writes `Data/Vendor.lua`: unit prices (`BuyPrice / VendorStackCount`
from the same build's `ItemSparse`) for the items in LibPeriodicTable-3.1's
`Tradeskill.Mat.BySource.Vendor` set (pinned commit, LGPL-2.1), since which items
vendors sell is server data the client doesn't ship. Listed items missing from the
build are reported and skipped. It shares the build pin and cache with `gen_thresholds.py`.

`gen_recipes.py` writes `Data/Recipes.lua`, using only spell IDs already present in
the same-build `Data/Thresholds.lua`. It imports the threshold generator's build,
snapshot date, cache and profession discovery; run thresholds first when changing
builds. All three generators accept `--offline` and `--refresh`. To verify recipe
reproducibility:

```sh
python3 tools/gen_recipes.py --offline
sha256sum Data/Recipes.lua
python3 tools/gen_recipes.py --offline
sha256sum Data/Recipes.lua
```

`gen_trainer.py` writes `Data/Trainer.lua`: base trainer fees for recipes with
thresholds, from the pinned CMaNGOS classic-db `npc_trainer` table (GPL-3.0). Its
rows name teaching spells; Classic Era's `SpellEffect` (LEARN_SPELL) maps them to
recipe spells, since Forever's client leaves the teaching spells out.
Specialisation-gated rows are skipped, and fees recorded at a trainer in game win.

The recipe generator joins `SkillLineAbility` to `SpellReagents` and base-difficulty
`SpellEffect` rows. Reagents are sorted by item ID and repeated slots combined.
Missing or unresolved reagent rows are omitted, never converted into free recipes.
Conflicting memberships, reagent rows, outputs or names fail before replacing the
generated file. Output quantities are mean yields from `EffectBasePointsF`; zero
create-item amounts become one, and `Variance` validates that random yields do not
cross the minimum. Scaled or unsupported outputs fail for review. Permanent
enchants and summoned campfires have `output = false`; absence of create-item data
alone does not establish a non-item output. A valid live schematic takes precedence.

`ItemSellPrices` includes positive `ItemSparse.SellPrice` values for bundled recipe
outputs only. Missing ItemSparse rows are reported and have no bundled value.
`RecipeNames[skillLine][name]` uses exact `SpellName.Name_lang` strings from the enUS
export; ambiguous names map to `false`, including ambiguity between old and new
recipe variants. Name matching is a trainer fallback; other client locales need a
verified spell ID. Counts, omissions and file size print on each generation.

Runtime consumers filter `RecipeData[recipeID].skillLine` using
`C_TradeSkillUI.GetBaseProfessionInfo().professionID` for the open profession.
These are parent skill-line IDs: First Aid 129, Blacksmithing 164, Leatherworking
165, Alchemy 171, Herbalism 182, Cooking 185, Mining 186, Tailoring 197, Engineering
202, Enchanting 333, Fishing 356 and Skinning 393; expansion child lines 2937–2948
are not recipe filters. Guard unavailable profession info and filter learned
recipes before building a route snapshot. `snapshot.skill` and `snapshot.target`
must use the same effective-skill coordinates (base plus modifier); the caller
applies the trained cap. Shopping uses segment `crafts`, the ceiling of accumulated
expected crafts, and subtracts owned items once. Unknown reagent arrays contribute
no shopping rows, so only use priced route segments for a complete list.
