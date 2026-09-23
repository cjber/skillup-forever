---
name: sift-project
description: "Project profile for sift in SkillUp Forever: the exact quality-gate and evidence commands, live roots that must never be deleted as dead code, exclusions, conventions and risk order. Load before running sift or any code-quality, cleanup or dead-code work in this repository."
---

# sift project profile — SkillUp Forever

SkillUp Forever is a World of Warcraft addon for the WoW: Forever client (Classic content on the
mainline 12.x UI/API, `## Interface: 16001`). It runs inside the game's Lua 5.1 sandbox; there is
no `require` — the client loads the files `SkillUpForever.toc` lists, in that order, and each file
receives `local addonName, ns = ...`, the addon's shared table. It ships as a zip built by the
BigWigs packager (`.pkgmeta`) on a `v*` tag and is consumed by players via CurseForge / Wago.
Standard-library Python generators in `tools/` rebuild the `Data/*.lua` tables from wago.tools DB2
exports and CMaNGOS dumps; `refresh-data.yml` runs them daily.

## Gate

Run in order from the repository root. All must pass before and after any audit slice.

| Step | Command | Pass means |
|---|---|---|
| Format (Lua) | `stylua --check .` | exit 0 (StyLua 2.5.2) |
| Format (Python) | `ruff format --check tools` | exit 0 (config: `tools/ruff.toml`) |
| Lint (Lua) | `luacheck .` | `0 warnings / 0 errors`, exit 0 |
| Lint (Python) | `ruff check tools` | exit 0 |
| Tests | `luajit tests/model_spec.lua` | prints `model_spec: N checks passed`, exit 0 |
| Workflows | `uvx --from actionlint-py==1.7.12.25 actionlint && uvx zizmor@1.30.1 --offline .github` | exit 0 |
| Secrets | `gitleaks git --redact --no-banner .` | `no leaks found` |

CI (`.github/workflows/ci.yml`) runs all of these. There is no type-checking gate and no
ast-grep rule set (see Evidence).

The tests are a headless harness, not the game client: `tests/model_spec.lua` loads `Model.lua`,
`Data/*.lua` and `Prices.lua` with `loadfile` and stubs the host APIs they touch. Everything else
(UI hooks, menus, tooltips, the objective tracker, the trainer) is only verified in game. The
in-game check for data is `/su audit` with a profession open.

## Evidence

On-demand tools for audits. Output is candidates, never verdicts.

| Concern | Command | Known false positives |
|---|---|---|
| Types (Lua) | `mkdir -p .sift/runs/luals && lua-language-server --check=. --checklevel=Warning --logpath=.sift/runs/luals --check_format=json --check_out_path=.sift/runs/luals/check.json` | exits 1 whenever any diagnostic exists; read `check.json`. Baseline: 6 (`need-check-nil` Prices.lua:345, Route.lua:94/97, tests/model_spec.lua:403/407; `param-type-mismatch` Prices.lua:356) |
| Types (Python) | `uvx ty check tools --extra-search-path tools --output-format concise` | exits 1; baseline 4: `re.fullmatch(...).groups()` on a possible `None` (gen_thresholds.py:109), `defaultdict(Counter)` inferred as `Counter[str]` (gen_trainer.py:94/96), untyped `json.load` result (latest_build.py:14) |
| Dead code (Lua) | `luacheck . --no-color` (unused locals/values) + the live-root searches below | a function stored on `ns` is never "unused" to luacheck — search every file for `ns.<Name>` |
| Dead code (Python) | `uvx vulture tools --min-confidence 60` | clean at baseline; generator functions are imported across files (`from gen_thresholds import …`) |
| Duplication | `npx --yes jscpd@4 --silent --reporters json --output .sift/runs/jscpd --ignore "Data/**,tools/.cache/**,.sift/**" .` | 4 Python clones: the `argparse` + download preamble repeated in each `tools/gen_*.py` |
| Live roots | `rg -n 'hooksecurefunc|RegisterEvent|RegisterCallback|SetScript|AddTooltipPostCall|Menu.ModifyMenu|SLASH_|SlashCmdList' -g '*.lua'` | — |

## Live roots

Things reached indirectly. The dead-code lens must treat these as referenced.

- `SkillUpForever.toc` file list — loads every top-level `.lua` and `Data/*.lua`; nothing `require`s them.
- `ns.*` — the shared addon table; a function defined in one file is typically called from another. Search all files for `ns.Name`, not the local file.
- `## SavedVariables: SkillUpForeverDB` — persisted per account; keys in `Core.lua` `DEFAULTS` and anything read from `SkillUpForeverDB` may hold data written by older versions.
- `## AddonCompartmentFunc: SkillUpForever_OnAddonCompartmentClick` — global called by the client by name.
- `SLASH_SKILLUPFOREVER1/2` + `SlashCmdList.SKILLUPFOREVER` — `/su` commands.
- `hooksecurefunc("ClassTrainerFrame_InitServiceButton" | "ClassTrainerFrame_Update", …)`, `hooksecurefunc(ProfessionsFrame, "RefreshRightTabs" | "RightTabSelected")`, `hooksecurefunc(ObjectiveTrackerManager, "AddContainer")`, `hooksecurefunc(recipeList.ScrollBox, "SetDataProvider")` — Blizzard functions hooked by string name.
- `EventRegistry:RegisterCallback("Professions.RecipeListOnEnter")`, `Menu.ModifyMenu("MENU_PROFESSIONS_FILTER")`, `TooltipDataProcessor.AddTooltipPostCall` — host callbacks.
- `RegisterEvent("…")` + `OnEvent` dispatch on the event string — handlers are reached by event name.
- Optional integrations (`## OptionalDeps: Auctionator, TomTom, Syndicator`) — code guarded by `if Auctionator` etc. is live only with that addon installed.
- `tools/gen_*.py` public names imported by sibling generators; `tools/latest_build.py` and `tools/changelog.py` run from workflows.

## Zones

How each part of the tree is reviewed. Unlisted paths are `production`.

| Path | Zone | Reason |
|---|---|---|
| `Data/*.lua` | generated | written by `tools/gen_*.py`; never hand-edit, fix the generator |
| `tools/` | script | data generators, CI helpers; not shipped |
| `tests/` | test | headless LuaJIT harness |
| `.github/`, `.pkgmeta`, `.luacheckrc`, `.luarc.json`, `stylua.toml`, `.gitleaks.toml` | config | |
| `README.md`, `CHANGELOG.md`, `PLAN.md`, `docs/`, `tools/README.md` | docs | `docs/curseforge.md` is the store listing |
| `media/`, `docs/screenshots/` | assets | |

## Conventions

- One feature per top-level file; each starts `local addonName, ns = ...` (or `local _, ns = ...`) and exports through `ns.Name = …` / `function ns.Name(…)`. File-private helpers are `local function`.
- Tabs, 120 columns, double quotes (StyLua). PascalCase for functions, camelCase for locals and DB keys.
- Unknown data renders `?`/`nil` rather than a guess; generators raise instead of clamping bad data (see `tools/README.md`). A silent fallback that invents a number is a defect here.
- Comments explain *why* (client quirks, Forever beta bugs, data provenance), not what.
- Host globals must be declared in `.luacheckrc` `read_globals`; `.luarc.json` mirrors that list (regenerate it from `.luacheckrc` when adding one).
- New dev-only root files must be added to `.pkgmeta` `ignore:` so they don't ship in the zip.

## Risk order

Audit slices from lowest to highest risk:

1. `tools/` — scripts, not shipped; output is diffable.
2. `tests/` — harness only.
3. `Model.lua`, `Settings.lua`, `Sources.lua` — pure maths / settings / lookups, partly under test.
4. `Tooltip.lua`, `RecipeList.lua`, `Trainer.lua` — UI hooks, in-game verification only.
5. `Prices.lua`, `Core.lua` — SavedVariables and auction-house scanning; persisted data.
6. `Route.lua`, `Shopping.lua` — largest, most stateful UI; crafting, buying and tracker integration.

## Project rules and lenses

- Rules: none yet.
- Lenses: none yet.
