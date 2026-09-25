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
| Types and multi-values | `tools/typecheck.sh` | LuaLS 3.19.1 reports no diagnostics; tokenizer/parser lint and its tests pass |
| Tests | `for s in tests/*_spec.lua; do luajit "$s" \|\| exit 1; done` | each prints `<name>_spec: N checks passed`, exit 0 |
| Workflows | `uvx --from actionlint-py==1.7.12.25 actionlint && uvx zizmor@1.30.1 --offline .github` | exit 0 |
| Secrets | `gitleaks git --redact --no-banner .` | `no leaks found` |
| Project rules | `python3 .sift/gate.py --base origin/main && python3 .sift/agents.py check` | exit 0 |

CI (`.github/workflows/ci.yml`) runs all of these, plus a `sift` job (`sift check`, `sift agents
check`, pinned by commit). LuaLS checks all TOC files against pinned WoW API annotations plus
`types/`; there is no ast-grep rule set.

The tests are a headless harness, not the game client. Each spec `loadfile`s one production file
with stubbed host APIs: `model_spec` (Model.lua, Data/*.lua, Prices.lua), `prices_spec` (Prices.lua),
`route_spec` (Route.lua's `ns.NextCraft`) and `core_spec` (Core.lua's init guard). Everything else
(UI hooks, menus, tooltips, the objective tracker, the trainer) is only verified in game. The
in-game check for data is `/su audit` with a profession open.

## Evidence

On-demand tools for audits. Output is candidates, never verdicts.

| Concern | Command | Known false positives |
|---|---|---|
| Types (Lua) | `tools/typecheck.sh` | Zero-diagnostic gate; missing Forever FrameXML surfaces are typed in `types/Client.lua` |
| Types (Python) | `uvx ty check tools --extra-search-path tools --output-format concise` | exits 1; baseline 6: `re.fullmatch(...).groups()` on a possible `None` (gen_thresholds.py:109), `defaultdict(Counter)` inferred as `Counter[str]` (gen_trainer.py:94/96), untyped `json.load` result (latest_build.py:14), unresolved `wowmock` (the wow-mock-screenshots library, put on `sys.path` at run time; screenshots.py:260) and the `("divider",)` row tuple (screenshots.py:454) |
| Dead code (Lua) | `luacheck . --no-color` (unused locals/values) + the live-root searches below | a function stored on `ns` is never "unused" to luacheck — search every file for `ns.<Name>` |
| Dead code (Python) | `uvx vulture tools --min-confidence 60` | clean at baseline; generator functions are imported across files (`from gen_thresholds import …`) |
| Duplication | `npx --yes jscpd@4 --silent --reporters json --output .sift/runs/jscpd --ignore "Data/**,tools/.cache/**,.sift/**" .` | 4 Python clones: the `argparse` + download preamble repeated in each `tools/gen_*.py` |
| Live roots | `rg -n 'hooksecurefunc|RegisterEvent|RegisterCallback|SetScript|AddTooltipPostCall|AddInitializedFrameCallback|Menu.ModifyMenu|SLASH_|SlashCmdList' -g '*.lua'` | — |
| Data byte-compare | copy the primary checkout's ignored `tools/.cache/`, then `python3 tools/gen_<name>.py --offline` and `git status Data` | only `gen_thresholds` and `gen_vendor` run from the usual cache; the others need the classic-db and era DB2 downloads (drop `--offline` once) |
| Standards | `SIFT_STANDARDS_PATH=~/skills python3 <sift>/scripts/agents.py standards` | the `wow-forever-addon` pack lives in the `~/skills` clone, not `~/.agents/skills`; without the path the check prints `unknown-standard` |

## Live roots

Things reached indirectly. The dead-code lens must treat these as referenced.

- `SkillUpForever.toc` file list — loads every top-level `.lua` and `Data/*.lua`; nothing `require`s them.
- `ns.*` — the shared addon table; a function defined in one file is typically called from another. Search all files for `ns.Name`, not the local file.
- `## SavedVariables: SkillUpForeverDB` — persisted per account; keys in `Core.lua` `DEFAULTS` and anything read from `SkillUpForeverDB` may hold data written by older versions.
- `## AddonCompartmentFunc: SkillUpForever_OnAddonCompartmentClick` — global called by the client by name.
- `SLASH_SKILLUPFOREVER1/2` + `SlashCmdList.SKILLUPFOREVER` — `/su` commands.
- `hooksecurefunc("ClassTrainerFrame_InitServiceButton" | "ClassTrainerFrame_Update", …)`, `hooksecurefunc(ProfessionsFrame, "RefreshRightTabs" | "RightTabSelected")`, `hooksecurefunc(ObjectiveTrackerManager, "AddContainer")`, `hooksecurefunc(recipeList.ScrollBox, "SetDataProvider")` — Blizzard functions hooked by string name.
- `EventRegistry:RegisterCallback("Professions.RecipeListOnEnter")`, `Menu.ModifyMenu("MENU_PROFESSIONS_FILTER")`, `TooltipDataProcessor.AddTooltipPostCall` — host callbacks.
- `ScrollUtil.AddInitializedFrameCallback(recipeList.ScrollBox, DecorateRow, ns)` (RecipeList.lua) and `Auctionator.API.v1.RegisterForDBUpdate(addonName, PricesChanged)` (Prices.lua `ns.InitPrices`) — callbacks the plain live-root search misses.
- `RegisterEvent("…")` + `OnEvent` dispatch on the event string — handlers are reached by event name.
- Optional integrations (`## OptionalDeps: Auctionator, TomTom, Syndicator`) — code guarded by `if Auctionator` etc. is live only with that addon installed.
- `tools/gen_*.py` public names imported by sibling generators; `tools/latest_build.py` and `tools/changelog.py` run from workflows.
- `tools/screenshots.py` — run by hand (WFA-9) to rewrite `docs/screenshots/`; it ports Model/Core maths to Python, so check its ports against the Lua (`round_money` vs `Model.RoundMoney`) rather than treating it as its own source of truth.

## Zones

How each part of the tree is reviewed. Unlisted paths are `production`.

| Path | Zone | Reason |
|---|---|---|
| `Data/*.lua` | generated | written by `tools/gen_*.py`; never hand-edit, fix the generator |
| `tools/` | script | data generators, CI helpers; not shipped |
| `tests/` | test | headless LuaJIT harness |
| `.github/`, `.pkgmeta`, `.luacheckrc`, `.luarc.json`, `stylua.toml`, `.gitleaks.toml`, `.gitattributes`, `.gitignore`, `.styluaignore`, `tools/ruff.toml`, `SkillUpForever.toc` | config | the TOC's `## Notes` is user-facing |
| `types/` | config | LuaLS `---@meta` annotations; not shipped. Check them against the code they describe |
| `README.md`, `CHANGELOG.md`, `PLAN.md`, `docs/`, `tools/README.md` | docs | `docs/curseforge.md` is the store listing |
| `media/`, `docs/screenshots/` | assets | |

## Conventions

- One feature per top-level file; each starts `local addonName, ns = ...` (or `local _, ns = ...`) and exports through `ns.Name = …` / `function ns.Name(…)`. File-private helpers are `local function`.
- Tabs, 120 columns, double quotes (StyLua). PascalCase for functions, camelCase for locals and DB keys.
- Unknown data renders `?`/`nil` rather than a guess; generators raise instead of clamping bad data (see `tools/README.md`). A silent fallback that invents a number is a defect here.
- Comments explain *why* (client quirks, Forever beta bugs, data provenance), not what.
- Host globals go in `.luacheckrc` `read_globals`. LuaLS uses pinned Ketho annotations and typed gaps in `types/`, never a bare globals allowlist.
- Text shown in game (Settings tooltips, `ns.Print` messages) and the store listing `docs/curseforge.md` are user-facing: audits propose changes, never make them.
- New dev-only root files must be added to `.pkgmeta` `ignore:` so they don't ship in the zip. Dot paths
  never ship (the pinned packager prunes them before `ignore:`), so they need no entry.
- Some guards and annotations exist for LuaLS, not at run time: `---@class` on a table built field by
  field (List.lua `CreateList`) and `if not module then return end` narrowing an optional upvalue
  (Shopping.lua `Attach`). Removing either fails `tools/typecheck.sh`.

## Risk order

Audit slices from lowest to highest risk:

1. `tools/` — scripts, not shipped; output is diffable.
2. `tests/` — harness only.
3. `Model.lua`, `Settings.lua`, `Sources.lua`, `List.lua`, `types/` — pure maths / settings / lookups /
   the shared list widget, partly under test.
4. `Tooltip.lua`, `RecipeList.lua`, `Trainer.lua` — UI hooks, in-game verification only.
5. `Prices.lua`, `Core.lua` — SavedVariables, vendor prices and the Auctionator price seam; persisted data.
6. `Route.lua`, `Shopping.lua` — largest, most stateful UI; crafting, buying and tracker integration.

Tiers 5 and 6 get a second, independent reviewer (Codex): on 2026-09-24 it found the two route and
price bugs the first reviewer missed, each with an in-memory LuaJIT repro.

## Anti-patterns

Recurring judgment defects; check new code for them.

- A hand port drifts from its Lua source (`parallel-implementations`): `tools/screenshots.py`
  `round_money`/`model_recipe_cost`/`price()` vs `Model.RoundMoney`/`RecipeCost`/`ns.Price`.
- The price-source set restated (`stringly-typed`): "auctionator means auction" in
  `Model.ShoppingList` and Route.lua `PriceAge`; unknown sources fall silently into `unknown`.
- A saved setting read without checking it against its options (`silent-fallbacks`): `LoadDB`
  validates `reagentTooltip` only; `craftValue` and `sortMode` fall back silently.

## Project rules and lenses

- Rules: none yet (no repeated shape a tool can match without judgment).
- Lenses: none yet.
