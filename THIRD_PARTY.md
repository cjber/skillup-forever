# Third-party inputs

Everything SkillUp Forever is built from that it did not write itself: where each comes from, where its pin lives, its
licence, and whether any of it reaches the zip players install. A pin is named by the constant that holds it, so a data
refresh that moves the pin never leaves this file behind. The addon itself is GPL-3.0-or-later ([LICENSE](LICENSE)).

## Ships in the zip

| Input | Used for | Pin | Licence |
|---|---|---|---|
| WoW: Forever client tables, via [wago.tools](https://wago.tools) | Skill thresholds, recipes, reagents, the skill books that teach a rank, gathering locks and vendor prices in `Data/*.lua` | `BUILD` in `tools/gen_thresholds.py` (the other generators import it) | Blizzard Entertainment's game data |
| Classic Era client tables, via wago.tools | Which item teaches which recipe, and which spell is a rank, in `Data/Sources.lua` and `Data/Trainer.lua` | `TEACH_BUILD` in `tools/gen_thresholds.py` (the trainer and sources generators import it) | Blizzard Entertainment's game data |
| [CMaNGOS classic-db](https://github.com/cmangos/classic-db) | Trainer fees, who trains what, the quests that teach a rank, drop chances and gathered reagents in `Data/Trainer.lua` and `Data/Sources.lua` | `CLASSICDB_COMMIT` in `tools/gen_trainer.py` (`tools/gen_sources.py` imports it) | GPL-3.0 |
| [LibPeriodicTable-3.1](https://github.com/doadin/libperiodictable-3-1) | Which reagents vendors sell, in `Data/Vendor.lua` | `PT_COMMIT` in `tools/gen_vendor.py` | LGPL-2.1 |

`tools/bump_pins.py` moves `BUILD`, `TEACH_BUILD` and `PT_COMMIT`. No embedded libraries ship. `media/` is this addon's own: the icon is drawn in `media/icon.svg`.

## Read in game, never bundled

| Input | Used for | Licence |
|---|---|---|
| Questie and QuestieDB, if installed | Vendors, quests and NPC places | QuestieDB carries no licence; nothing is copied |
| AtlasLoot Classic, if installed | Recipe scrolls and where they drop | Its own; nothing is copied |
| Auctionator, Syndicator, TomTom, Shortest Path Forever, if installed | Prices, counts across characters and waypoints, through their public APIs | Their own; nothing is copied |

## Build and test only

| Input | Used for | Pin | Licence |
|---|---|---|---|
| [Blizzard UI source](https://github.com/Gethe/wow-ui-source) | The shared client simulator's UI source, fetched into `tools/.cache/` | the pin in `tools/forever_sim/fetch.py` | Blizzard Entertainment's; fetched, never committed |
| [Ketho's WoW API annotations](https://github.com/Ketho/vscode-wow-api) | lua-language-server types in `tools/typecheck.sh` | `revision` in `tools/typecheck.sh` | MIT |
| [forever_tools](https://github.com/cjber/forever-core/tree/main/.agents/skills/wow-forever-addon/tooling/forever_tools) | Shared lints, release checks and the generated-data gate, vendored in `tools/forever_tools/` | `revision` in `tools/forever_tools/MANIFEST.json` | MIT |
| [forever-core/tools/wowmock](https://github.com/cjber/forever-core/tree/main/tools/wowmock) and the client art it fetches | `tools/screenshots.py` | `FOREVER_CORE` (a local forever-core checkout); the art at `UI_ART_BUILD` in `tools/screenshots.py` | MIT; the art is Blizzard Entertainment's, fetched at build time and committed only as it appears in `docs/screenshots/` |
| Ko-fi's Support me on Ko-fi button | The support button in the README (`ko-fi.com/img/githubbutton_sm.svg`) and its PNG render, `docs/kofi-button.png`, in the store description | None: the README links Ko-fi's live file; the PNG is rendered from it | Ko-fi's brand asset, used as Ko-fi provides it for linking to a Ko-fi page |
| `docs/github-sponsors-button.png` | The GitHub Sponsors button in the README and store description; drawn here to match the Ko-fi button, with the heart from GitHub's [Octicons](https://github.com/primer/octicons) and the Adwaita Sans font | None | Octicons: MIT; Adwaita Sans: SIL OFL 1.1 |
| `docs/discord-button.png` | The Discord button on the store page; drawn in forever-core with Discord's logo from [Simple Icons](https://simpleicons.org) and the Adwaita Sans font | None | Simple Icons: CC0; Adwaita Sans: SIL OFL 1.1; the logo is Discord's, used to link to a Discord server |

CI tools (StyLua, ruff, luacheck, lua-language-server, actionlint, zizmor, gitleaks, the BigWigs packager) are pinned in `.github/workflows/` and `tools/typecheck.sh`, except luajit and luacheck, which come from the runner's apt; they build and check the addon and are never part of it.

## Players

Credit for the reports and requests behind the addon.

| Who | What | Notes |
|---|---|---|
| Diamondclaw | The recipe skill band clears the icon and the Reagents header | CurseForge; #674; thread 8700469 |
| [mimmordino](https://github.com/mimmordino) | The recipe skill band clears the icon and the Reagents header | GitHub; #685; also CurseForge thread 8702929 |
| soviman1 | Smelting recipes show their skill range | CurseForge; #688; thread 8703325 |
| [FreakinNerd](https://github.com/FreakinNerd) | SkillUp's pages no longer draw over the Professions window's own page | GitHub; #658, fixed in 1.9.1 (#669) |
| nookie909 | A route you are shopping for stays put after buying its reagents | CurseForge; #621; thread 8689912 |
| [Rambomst](https://github.com/Rambomst) | Fixed progress-bar fill masking and Auctionator prices after reload (#655, #656) | |
| bromidious | Reported the progress-bar overlap fixed in #656 | Discord; #656 |
| ItachiGrave | Selected recipes show their skill band | CurseForge; #613; thread 8688792 |
| bromidious | Buffs controls no longer overlap | Discord; #599 |
| bromidious | Native controls stay behind SkillUp pages | Discord; forever-core#477; Core 1.7.4 |
| .phear | Native controls stay behind SkillUp pages | Discord; forever-core#477; Core 1.7.4 |
| Brainc3ll | French translation | GitHub; cjber/legacy-forever#99 |
| kopuliak | Recipe minimum skills and automatic auction list settings corrected | CurseForge; #107, #123, #647 |
| kopuliak | No more secret-number tooltip errors | CurseForge; #161, 0.10.0, 0.16.0 |
| kopuliak | Option to hide the tracked professions | CurseForge; 0.9.0 |
| kopuliak | Auctionator's latest price used | CurseForge; 0.9.1 |
| Chuujitsuna | Tracker scale slider | CurseForge; #517 |
| Chuujitsuna | Tracker no longer stuck mid-screen | CurseForge; #136 |
| Chuujitsuna | No more secret-number tooltip errors | CurseForge; #161 |
| berserkerlxl | Gathered materials priced at what they sell for | CurseForge; 0.10.0 |
| SilentGentlemanSG | Buy button asks before buying | CurseForge; 0.10.0 |
| BallaRa | Recipe tooltip moved beside the window | CurseForge; #163 |
| kurila11478 | Buy reagents can be turned off | CurseForge; #162, #190 |
| trias6657 | Net per craft on recipe rows | CurseForge; 0.17.0 |
| trias6657 | Skill bar on the selected recipe | CurseForge; 0.18.4 |
| Bolthorr | Route tab clears All The Things' tab | CurseForge; #179 |
| TechnoHunter | Route tab stays in the Professions window | CurseForge; #402 |
| Viper2042 | Route and gear tabs are real buttons | CurseForge; #398 |
| Syrberus | Fixed the recipe-tooltip secret-number error | CurseForge; #161 |
| [Mouchoir](https://github.com/Mouchoir) | Route no longer errors on a priced tool (code) | GitHub; #174, PR #173 |
| [Mouchoir](https://github.com/Mouchoir) | Tab switches no longer re-plan everything (code) | GitHub; #176, PR #175 |
| [Mouchoir](https://github.com/Mouchoir) | Other professions' skill-ups keep the plans (code) | GitHub; #183, PR #182 |
| [Mouchoir](https://github.com/Mouchoir) | Faster re-plan after a scan or new recipe (code) | GitHub; #185, PR #184 |
| [zazomazzo](https://github.com/zazomazzo) | Fixed the tracker vanishing in Edit Mode (code) | GitHub; #221, PR #222 |
| iPulse | Cheaper hover tooltips | CurseForge; #412, #477 |
| iPulse | Professions tab stays in the window | CurseForge; #446 |
| Setuaro | Hovering a tooltip no longer drops the frame rate | CurseForge; #412 |
| 0xTrk | Cheaper item hovers | CurseForge; #412 |
| 3kinex | Cheaper item hovers | CurseForge; #412 |
| icouldonlygetthisname | Tooltip frame drops measured and fixed | GitHub; #412 |
| jakeyjake07 | Route no longer over-crafts profitable recipes | GitHub; #400 |
| Rekalicious | Controller crafting no longer blocked | GitHub; #313 |
| leenagil-coder | Merchant Reagents tab no longer errors | GitHub; #447 |
| Weythx | No stutter hovering items with Auctionator | GitHub; #503 |
| lokitako | Recipe minimum skills corrected | GitHub; #107 |
| Rawveggie | Campfire and plan-use actions no longer blocked | GitHub; #489 |
| sundered1985 | Campfire and plan-use actions no longer blocked | CurseForge; #489 |
| hardliquor | Tracker no longer flashes on item hover | Discord; #526 |
| cotijelucie | Newest recipes first | Discord; #486 |
| cotijelucie | Skill ranges start where learned | Discord; #519 |
| CodexFD | Professions window keeps one width | CurseForge; #505 |
| rockhumper84 | TradeSkillMaster as a price source | CurseForge; #488 |
| Kozoaku | TradeSkillMaster auction prices (code) | GitHub; PR #500 |
| st3nlee | Self-supplied reagents priced at market values | CurseForge; #399 |
| st3nlee | Crafted items' sale value counted | CurseForge; #466 |
| prokn4h | Unlearned recipes can be listed | CurseForge; #361 |
| prokn4h | Unlearned recipes show their tooltips | CurseForge; #420 |
| Kirdan | Working Overtime at 4% per point | CurseForge; #349, #419 |
| rick1tz | Tailoring route no longer asks for 190 Linen Bags | GitHub; #339 |
| time2w8 | Leatherworking route no longer asks for 1183 Light Leather | CurseForge; #394 |
| ThePNAG | Reagent section no longer errors under All Objectives | CurseForge; #191 |
| CtrlDKhayos | Faster planning, no freeze at login | CurseForge; #189 |
| CtrlDKhayos | Other professions' skill-ups keep the plans | CurseForge |
| derzwiebelritter | Reagent prices add up to the total | GitHub; #360 |
| Ekallo | Item use no longer blocked | CurseForge; #350 |
| CorvidofShadows13 | Item use no longer blocked | CurseForge; #350 |
| Sogu | Shopping list shows its target | CurseForge; #232 |
| achubbert | Wider recipe list with craftable counts | CurseForge; #343 |
| jackthereaper\_ | Addon loads without a separate ForeverCore install | CurseForge; 1.4.0 |
| qwertzyxc | Professions overview back to its own width | Discord; #636 |

## Inspired by

Credit for the addons and projects an idea came from.

| Who | What | Notes |
|---|---|---|
| [Polestar](https://github.com/fitzforge/polestar) by Fitz | Ideas for many features | Expert and Artisan First Aid and Cooking from books and quests; skill colour on nodes and skinnable mobs; the shared report window and tooling. GPL-3.0. Inspired only; no code was copied. Fitz is welcome to use our code. |

Thanks also to everyone else who reported a bug or asked for a feature, here or on CurseForge.
