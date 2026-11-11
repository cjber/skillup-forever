# About the code

SkillUp Forever is a World of Warcraft: Forever addon in Lua 5.1. The files `SkillUpForever.toc` lists are
what the game loads; `tests/*_spec.lua` load them in that order inside a stubbed client.

- Keep the public API in `Core/API.lua` and every saved variable name unchanged.
- Generated data, `Libs/` and `tools/forever_tools/` are never edited by hand.
- Taint: never replace a Blizzard global or hook a secure function a spec does not already hook.
- Never use the network, and never start the game, Battle.net, Lutris or Wine. The headless client (forever-core's `wow-forever-addon/in-game.md`) tests the build linked into the game, not this checkout, so in-game checks belong to the agent that ships a change.

## Live roots

Things reached indirectly: none of them is dead code, even when no file calls it by name.

- `SkillUpForever.toc` file list: loads `Core/ForeverRequire.lua` and `Core/Require.lua` first (the shared out-of-date warning and the API floor), then the Lua and XML files it lists under `Locales/`, `Data/`, `Core/`, `Integrations/` and `UI/`, in that order (`tests/client.lua` injects fixtures before the first non-Locales, non-Data code file); nothing `require`s them.
- `ns.*`: the shared addon table; a function defined in one file is typically called from another. Search all files for `ns.Name`, not the local file.
- `## SavedVariables: SkillUpForeverDB`: persisted per account; keys in `Core/Core.lua` `DEFAULTS` and anything read from `SkillUpForeverDB` may hold data written by older versions.
- `Locales/<locale>.lua`: translators' files, loaded from the TOC after `enUS.lua`; `tools/phrases.py` runs from `tests/locale_spec.lua`.
- `SkillUpForever.API` (Core/API.lua): the public API other addons (Adventure Guide Forever) call; `types/API.lua` is its contract.
- `## AddonCompartmentFunc: SkillUpForever_OnAddonCompartmentClick`: global called by the client by name.
- `SLASH_SKILLUPFOREVER1` + `SlashCmdList.SKILLUPFOREVER`: `/skillup` commands.
- `hooksecurefunc("ClassTrainerFrame_InitServiceButton" | "ClassTrainerFrame_Update", …)`, `EventUtil.ContinueAfterAllEvents`: Blizzard trainer functions hooked by string name, plus a load-sequencing callback.
- `EventRegistry:RegisterCallback("Professions.RecipeListOnEnter")`, `Menu.ModifyMenu("MENU_PROFESSIONS_FILTER")`, `TooltipDataProcessor.AddTooltipPostCall`: host callbacks.
- `ScrollUtil.AddInitializedFrameCallback(recipeList.ScrollBox, DecorateRow, ns)` (UI/RecipeList.lua) and `Auctionator.API.v1.RegisterForDBUpdate(addonName, PricesChanged)` (Integrations/Prices.lua `ns.InitPrices`): callbacks the plain live-root search misses.
- `ns.WhenStale(name, fn)` and `ns.WhenEvent(event, fn)`: handlers Core/Changes.lua calls by cache/view name and by event; its `EVENTS` table registers the game events.
- `RegisterEvent("…")` + `OnEvent` dispatch on the event string: handlers are reached by event name.
- Optional integrations (`## OptionalDeps: Auctionator, TomTom, Syndicator, ShortestPathForever`): code guarded by `if Auctionator` etc. is live only with that addon installed.
- `tools/gen_*.py` public names imported by sibling generators; `tools/bump_pins.py` (which imports `tools/latest_build.py`) and `tools/changelog.py` run from workflows.
- `tools/screenshots.py`: run by hand (WFA-9) to rewrite `docs/screenshots/`; the route, tracker, trainer and reagent scenes run the addon's own Lua under luajit, while the recipe-list scenes port Model/Core maths to Python, so check its ports against the Lua (`round_money` vs `Model.RoundMoney`) rather than treating it as its own source of truth.

## Settled

Shapes that look like defects here but are not. Add an entry when the same shape keeps being raised and
dismissed for the same reason.

- Client-capability checks (`defensive-noise`): a guard on a host global or field (`C_TooltipInfo`,
  `issecretvalue`, `GameTooltip.RefreshData`) stays even when `types/Client.lua` annotates it; the
  annotations never run in the client, e.g. `UI/Tooltip.lua`, `Integrations/Trainer.lua`
- Host-mirroring annotations (`dead-code`): `types/Client.lua` members that mirror a real client table
  or a shape the host reads (`VarType.Number`, `colorStyle.reverse`) stay though the addon never names them
- Money and name one-liners (`parallel-implementations`): signed-money text and "name or placeholder"
  lookups composed from `Model.RoundMoney`/`ns.FormatNet`/`L[...]` are a small idiom; Tooltip keeps copper
  precision and API formats positive fees on purpose, e.g. `UI/Route.lua` `Money`, `Core/Core.lua` `Describe`
- Price provenance vs shopping bucket (`stringly-typed`): `SkillUpPriceSource` (`vendor`/`auctionator`/`tsm`/`gather`)
  and the shopping bucket (`auction`, ...) are distinct literal-union contracts; `PriceAge` reads
  Auctionator-only age data, so its `"auctionator"` test is not the bucket, e.g. `UI/Route.lua` `PriceAge`

## Anti-patterns

Recurring judgment defects; check new code for them.

- **Hand port drift**: a hand port drifts from its Lua source (`parallel-implementations`): `tools/screenshots.py`
  `round_money`/`model_recipe_cost`/`price()` vs `Model.RoundMoney`/Prices.lua's `ReagentCost`/`ns.Price`.
- **Shopping bucket list restated**: the bucket list `gather`/`vendor`/`auction`/`unknown` enumerated
  by hand (`stringly-typed`) instead of walking `Model.SHOPPING_SOURCES`; an added bucket silently drops items.
  `route_spec` checks every bucket gets a Source label; Core/API.lua's `ReagentSource` maps buckets onto the public
  API's own sources on purpose.
- **Unvalidated saved setting**: a saved choice read without checking it against its options
  (`silent-fallbacks`). `LoadDB` resets `craftValue`, `sortMode` and `reagentTooltip` to their defaults when the
  saved value isn't one of `ns.*_OPTIONS`; a new dropdown setting joins that loop.
- **View left out of a change**: a `STALE` row in `Core/Changes.lua` drops a cache but not the views that show
  what it holds (`silent-fallbacks`), e.g. `fees` and `level` rebuild the plan or the API while the route page
  and tracker keep the old text. `changes_spec` pins each row as written, so check a row against every reader
  of the input that changed.
