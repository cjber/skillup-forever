# SkillUp Forever — plan

A WoW: Forever addon that puts Classic profession-levelling numbers into the retail Professions UI Forever ships with.

## Why this one

WoW: Forever (beta now, launch 2026-11-04, client 1.60.x, `## Interface: 16001`) runs Classic content on the mainline 12.1.5 UI/API. The retail Professions frame only shows a difficulty colour, which is useless for Classic levelling:

- "can't distinguish which yellow craftable is the higher base skill value"; asks for "profession skill level sorting" and "required skill level display" — [Blizzard forums](https://us.forums.blizzard.com/en/wow/t/classic-forever-needs-its-ui-fixed/2352794); community tracker [#50](https://github.com/ClassicWoWCommunity/forever-bugs/issues/50), [#53](https://github.com/ClassicWoWCommunity/forever-bugs/issues/53).
- No competitor on CurseForge (ForeverProfessor is an off-site planner).
- Runs entirely out of combat, so Midnight "secret value" restrictions don't apply.

Runners-up, if this lands well: a mega-realm LFG chat board (LFG Bulletin Board has no Forever support), a Legacy challenge tracker, a Camping companion, AH random-suffix display (tracker #52; Blizzard may fix it first).

## MVP

1. **Row text** — each recipe row shows required skill and skill-up chance, e.g. `125 · 62%`. Unknowns render `?`.
2. **Row tooltip** — orange / yellow / green / grey thresholds for the hovered recipe.
3. **Sort** — within each category: by required skill (asc) or chance (desc). Preserves categories, favourites, collapse state and selection. Self-disables with one chat warning if it errors.
4. **Filter** — reuse the native "only skill-ups" filter (`Professions.InitSkillUpFilter` → `C_TradeSkillUI.SetOnlyShowSkillUpRecipes`); do not build a second one.
5. **Settings + AddonCompartment** entry (toggle row text, sort mode).
6. **`/su audit`** — for every known recipe, compare the colour our table predicts at current skill against the live `relativeDifficulty`; print mismatches. This is how the data gets validated on Forever, cheaply and continuously.

Later: item/reagent tooltips ("used in X, grey at 190" — needs an item→recipe index), "next best recipe to level", macro-body persistence if the SavedVariables bug outlives beta.

## Contracts relied on (Forever branch of [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source/tree/forever))

| Need | Seam | Status |
|---|---|---|
| Recipe data | `C_TradeSkillUI.GetRecipeInfo` → `relativeDifficulty`, `canSkillUp`, `numSkillUps`, `maxTrivialLevel` | Verified in source; read by `Blizzard_ProfessionsRecipeList.lua`. `maxTrivialLevel` == grey is **unverified** |
| Row decoration | `ScrollUtil.AddInitializedFrameCallback(ProfessionsFrame.CraftingPage.RecipeList.ScrollBox, fn)`; read `node:GetData().recipeInfo`; own FontString, cleared on recycle | Verified (`Blizzard_SharedXML/Shared/Scroll/ScrollUtil.lua`) |
| Sort | `Professions.GenerateCraftingDataProvider` builds a tree; on `OnDataProviderReassigned`, `TreeNodeMixin:SetSortComparator` on recipe siblings | Verified (`Blizzard_SharedXML/TreeListDataProvider.lua`); taint safety unverified until tested live |
| Settings | `Settings.RegisterCanvasLayoutCategory` / `RegisterAddOnCategory` | Verified |
| Compartment | `AddonCompartmentFrame:RegisterAddon` | Verified |
| Later tooltips | `TooltipDataProcessor.AddTooltipPostCall` | Verified |

Not a mixin `hooksecurefunc(ProfessionsRecipeListRecipeMixin, "Init")`: mixins are copied into frames at creation, so it misses existing rows.

## Threshold data

The API gives only a colour (and maybe grey), so ship a table: `recipeSpellID → {req, yellow, grey}`; green = floor((yellow+grey)/2), validated in-game.

- **Baseline:** Skillet-Classic `SkillLevelData1.lua` — GPL-3.0-or-later (verified in file header). So this addon is **GPL-3.0-or-later**, with attribution.
- **Forever delta:** `SkillLineAbility` DB2 (`TrivialSkillLineRankLow/High`, [WoWDBDefs](https://github.com/wowdev/WoWDBDefs/blob/master/definitions/SkillLineAbility.dbd) lists Forever builds) for new Forever recipes. `MinSkillLineRank` is unreliable (often 1), so never trust it for `req` without a baseline or audit confirmation.
- **Chance:** orange 100%; yellow/green `(grey − skill)/(grey − yellow)`; grey 0%. Guard `grey <= yellow` → `?`. Labelled an estimate.
- Missing or conflicting data → `?`, never invented. The generator never silently falls back to Era/SoD values.

`tools/gen_thresholds.py` → `Data/Thresholds.lua` (deterministic, header records source + build).

## Persistence

SavedVariables often don't load on Forever beta ([forever-bugs#34](https://github.com/ClassicWoWCommunity/forever-bugs/issues/34), all characters, not just two-part names). Start from defaults every load, merge any valid loaded values over them, never error on a missing/corrupt table. Settings stay in memory otherwise. No macro hack in MVP.

## Layout

```
SkillUpForever.toc        ## Interface: 16001, SavedVariables: SkillUpForeverDB
Core.lua                  defaults/merge, events, /su commands (incl. audit)
Model.lua                 threshold lookup + chance maths (pure)
RecipeList.lua            row text, row tooltip, sort
Settings.lua              Settings panel + AddonCompartment
Data/Thresholds.lua       generated
tools/gen_thresholds.py
tests/model_spec.lua      busted: chance boundaries, rounding, zero denominator
.luacheckrc  .pkgmeta  .github/workflows/release.yml (BigWigs packager)
LICENSE (GPL-3.0)  README.md
```

Dev: symlink the repo to `~/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_classic_beta_/Interface/AddOns/SkillUpForever`.

## Verification

- `luacheck .` and `busted tests/` clean.
- In beta: `/dump C_TradeSkillUI.GetRecipeInfo(id)` on real recipes and confirm fields exist and `maxTrivialLevel` flips exactly when the row turns grey.
- `/su audit` returns zero mismatches for each profession you have.
- Scroll, search, favourites, switch professions and craft with `/console taintLog 1`: no taint entries attributable to the addon.
- Delete/corrupt the SavedVariables file and the addon loads on defaults without errors.

## Risks

- Beta UI churn before launch: re-diff the `forever` branch before each release.
- Forever's new recipes may lack thresholds until DB2 data or audits fill them (shown as `?`).
- Sorting may taint: behind a toggle, self-disabling.
- CurseForge flavour mapping for Forever in the packager is unverified; check before first upload.

## Implementation split (/pr phase 3)

- **Codex:** `tools/gen_thresholds.py`, `Data/Thresholds.lua`, `Model.lua`, `tests/`.
- **Claude:** `.toc`, `Core.lua`, `RecipeList.lua`, `Settings.lua`, packaging, lint, README.
