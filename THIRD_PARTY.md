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
| Wowhead's Forever tooltips for objects [566779](https://nether.wowhead.com/forever/tooltip/object/566779) and [566786](https://nether.wowhead.com/forever/tooltip/object/566786) | The skill Heavy Thorium Vein and Demonsage need, in `Data/Sources.lua` | `FOREVER_NODES` in `tools/gen_sources.py` | Game data |
| Warcraft Wiki's [Demonsage](https://warcraft.wiki.gg/wiki/Demonsage) and [Heavy Thorium Ore](https://warcraft.wiki.gg/wiki/Heavy_Thorium_Ore) pages | The item each of those nodes yields, in `Data/Sources.lua`; facts only, no text copied | `FOREVER_NODES` in `tools/gen_sources.py` | CC BY-SA 4.0 |
| [LibPeriodicTable-3.1](https://github.com/doadin/libperiodictable-3-1) | Which reagents vendors sell, in `Data/Vendor.lua` | `PT_COMMIT` in `tools/gen_vendor.py` | LGPL-2.1 |

`tools/bump_pins.py` moves `BUILD`, `TEACH_BUILD` and `PT_COMMIT`, and the forever-db pin in `tools/fdb_pin.py`. No embedded libraries ship. `media/` is this addon's own: the icon is drawn in `media/icon.svg`.

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
| [forever-db](https://github.com/fitzforge/polestar) | Evidence for the rank quests in the refresh guard's report, fetched into `tools/.cache/` | `FDB_SHA256` in `tools/fdb_pin.py` | GPL-3.0 (its layer CC BY 4.0); fetched, never committed |
| [forever-core/tools/wowmock](https://github.com/cjber/forever-core/tree/main/tools/wowmock) and the client art it fetches | `tools/screenshots.py` | `FOREVER_CORE` (a local forever-core checkout); the art at `UI_ART_BUILD` in `tools/screenshots.py` | MIT; the art is Blizzard Entertainment's, fetched at build time and committed only as it appears in `docs/screenshots/` |
| Ko-fi's Support me on Ko-fi button | The support button in the README (`ko-fi.com/img/githubbutton_sm.svg`) and its PNG render, `docs/kofi-button.png`, in the store description | None: the README links Ko-fi's live file; the PNG is rendered from it | Ko-fi's brand asset, used as Ko-fi provides it for linking to a Ko-fi page |
| `docs/github-sponsors-button.png` | The GitHub Sponsors button in the README and store description; drawn here to match the Ko-fi button, with the heart from GitHub's [Octicons](https://github.com/primer/octicons) and the Adwaita Sans font | None | Octicons: MIT; Adwaita Sans: SIL OFL 1.1 |
| `docs/discord-button.png` | The Discord button on the store page; drawn in forever-core with Discord's logo from [Simple Icons](https://simpleicons.org) and the Adwaita Sans font | None | Simple Icons: CC0; Adwaita Sans: SIL OFL 1.1; the logo is Discord's, used to link to a Discord server |

CI tools (StyLua, ruff, luacheck, lua-language-server, actionlint, zizmor, gitleaks, the BigWigs packager) are pinned in `.github/workflows/` and `tools/typecheck.sh`, except luajit and luacheck, which come from the runner's apt; they build and check the addon and are never part of it.

## Players

Credit for the reports and requests behind the addon.

| Who | What | Notes |
|---|---|---|
| ZMasterKing | No freeze naming vendor places or planning routes to them | CurseForge; comment 100022031; #1049, #1051 |
| sirbobbydanger | No freeze naming vendor places | CurseForge; comment 100020535; #1049 |
| alexaroth | No freeze from route planning on bag, price and zone changes | Discord; #1051 |
| knetoen | Routes skip lessons your specialisation cannot learn | CurseForge; comment 100015366; #1037 |
| user_oin05iu5ioauw23u | Window scale for the side pages | CurseForge; comment 100008248; #1019, #1027 |
| Bogdanov89 | Crafting cost on crafted item tooltips | CurseForge; comment 100006435; #1025 |
| xh43k | Vendor Reagents tab lists what to buy | CurseForge; comment 100003864; #1024 |
| [Amryu](https://github.com/Amryu) | Lighter route updates on each skill point (code) | GitHub; PR #1008 |
| Trejonv | Long row values stay off recipe names | CurseForge; comment 8760724; #979 |
| Declan_Does | Routes keep their recipes while you craft | CurseForge; comment 8779587; #978 |
| thetruekritze | Shopping lists count down as you craft | CurseForge; comment 8778238; #978 |
| Aperolll | Recipe item price on unlearned tooltips | CurseForge; comment 8779323; #989 |
| [b-morgan](https://github.com/b-morgan) | API for a recipe's skill bands | GitHub; #970 |
| kopuliak | Clear message when ForeverCore is out of date | CurseForge; comment 8766890; #953 |
| [sn0rlacks](https://github.com/sn0rlacks) | Auctionator shopping lists sync again | GitHub; #922 |
| woke3k | Auctionator shopping lists sync again | Discord; #918 |
| bromidious | The Buy reagents setting saves | Discord; #918 |
| CorvidofShadows13 | Poisons tracked with colours, costs and routes | CurseForge; comment 8758718; #906 |
| oriax06 | Tracker trainer and vendor lines no longer error | CurseForge; comment 8757802; #901 |
| treadpool | Tracker trainer and vendor lines no longer error | CurseForge; comment 8757883; #901 |
| BeneG\_ | No more freeze while pricing routes | CurseForge; comment 8757920; #899 |
| user_eq5vm5qd1sa8e2e7 | No more freeze while pricing routes | CurseForge; comment 8758262; #899 |
| fantqt | No more freeze while pricing routes | CurseForge; comment 8758429; #899 |
| blaauwe | No more freeze while pricing routes | Discord; #899 |
| user_euigz728rowxf4f7 | /skillup keeps answering after an update | CurseForge; comment 8749283; #866 |
| high_knuth52 | SkillUp keeps working after an update | CurseForge; comment 8753106; #866 |
| hella_v | Choice settings are dropdowns | CurseForge; comment 8744237; #919 |
| hella_v | Unlearned recipe rows show full names | CurseForge; comment 8744200; #854 |
| prokn4h | Auctionator shopping lists can be turned off | CurseForge; comment 8743391; #851 |
| analavenger | Bought reagents stay in your route | CurseForge; comment 8742724; #858 |
| analavenger | No more freeze on bags and merchants | CurseForge; comment 8742724; #846 |
| jovial_torvalds97 | No more freeze on bags and merchants | CurseForge; comment 8742638; #846 |
| ratman_codes | Recipes can be selected under every sort | CurseForge; comment 8742020; #840 |
| sundered1985 | Recipes can be selected under every sort | CurseForge; thread 8742020; #840 |
| prokn4h | Recipes can be selected after training | CurseForge; comment 8743308; #840 |
| user_eq5vm5qd1sa8e2e7 | Recipes can be selected after opening other windows | CurseForge; comment 8743699; #840 |
| irspeshal | Recipes can be selected after opening other windows | CurseForge; thread 8743699; #840 |
| snoochiedk | Routes show steps before reagents are priced | Discord; #855 |
| linhkawa | The SkillUp tab stays under the profession tabs | CurseForge; comment 8745629; #807 |
| [ratman-codes](https://github.com/ratman-codes) | Working Overtime left out of chances by default | GitHub; #741, PR #842 |
| jugg__ | Working Overtime left out of chances by default | Discord; #741, PR #842 |
| Joly0 | The SkillUp tab stays where it belongs | CurseForge; comment 8738355; #807 |
| Tinter | The SkillUp tab stays where it belongs | CurseForge; comment 8735245; #807 |
| user_2z94vp7dvu2wcvai | The SkillUp tab stays where it belongs | CurseForge; comment 8735914; #807 |
| user_2md58226ziq3j0em | Training no longer reroutes your levelling | CurseForge; comment 8736921; #807 |
| cheeq | Clearer setting for the recipe hover tooltip | CurseForge; comment 8735887 |
| 0xTrk | Reagent lines on item tooltips start off | CurseForge; comment 8667390; PR #829 |
| Mirades96 | The minimap button is gone | CurseForge; comment 8731392; #806 |
| p1tu | The minimap button is gone | CurseForge; comment 8730902; #759, #806 |
| Laddylucks | The minimap button is gone | CurseForge; comment 8729503; #759 |
| thirex | The minimap button is gone | CurseForge; comment 8729648; #759 |
| axejess | The minimap button is gone | CurseForge; comment 8729935; #759 |
| user_g496wu46adiwjuc5 | The minimap button is gone | CurseForge; comment 8732950; #759 |
| noenken | A quieter first install | CurseForge; comment 8736279; #806 |
| fusionley | A quieter first install | CurseForge; comment 8733873; #806 |
| ayacostv | AHDB supplies auction prices | Discord; #761 |
| xh43k | ForeverCore ships inside SkillUp | CurseForge; thread 8715086 |
| user_46x8szwptrswqttc | Reported a route sending them to a trainer for Troll's Blood Elixir | CurseForge; thread 100011189; #1021 |
| AlteredIgor | Open chat after closing Professions in Gamepad UI | CurseForge, thread 8771450, #967 |
| Benjy_Boi | Reported that resetting SkillUp's settings page could reset game settings and keybindings | CurseForge; comment 8722308; #925 |
| DemDragons | Reported lag planning routes with limited vendor stock | CurseForge; comment 8764076; #904 |
| user_nd8yffdjkebopqym | Reported lag planning routes with limited vendor stock | CurseForge; comment 8763397; #904 |
| [vulpeep](https://github.com/vulpeep) | Forever Ledger prices reagents (code) | GitHub; PR #908 |
| messajahswe | Gathered materials have a sale value by default | CurseForge; comment 8733694; #780 |
| davef1n | Sort recipes by profit regardless of skill | CurseForge; comment 8735009; #781 |
| user_bvgv4fnauhmhf9i7 | AHDB supplies auction prices | CurseForge; comment 8730894; #761 |
| [puschie286](https://github.com/puschie286) | Preview unlearned recipes in the crafting pane | GitHub; PR #729 |
| Belth | Routes prefer materials already in the bags | CurseForge; #744 |
| yavinn | SkillUp pages stay visible with ClassicUI Forever | CurseForge; thread 8722440; #734 |
| cursebandit | Reported the route sending players to a trainer who would not train them | CurseForge; comment 8718641; #722 |
| [rissole](https://github.com/rissole) | Public recipe data, recipe source and account-wide learned-recipe API | GitHub; #724, #757 |
| davef1n | Separate unlearned recipe order and regional sales volume | CurseForge; thread 8715846; #720; #721 |
| codipherus | Craft quantities lead each route step | CurseForge; thread 8702620; #684 |
| sundered1985 | Vendor and auction profit on the recipe tooltip | CurseForge; #678; thread 8701206 |
| jugg__ | Vendor and auction profit on recipe and pattern tooltips | Discord; #678, #726 |
| keerp | Choose Auctionator or TradeSkillMaster for prices | CurseForge; #675; thread 8700437 |
| [yusufdanis](https://github.com/yusufdanis) | Each Used in tooltip line names its recipe's profession (code) | GitHub; PR #670 |
| Diamondclaw | The recipe skill band clears the icon and the Reagents header | CurseForge; #674; thread 8700469 |
| [mimmordino](https://github.com/mimmordino) | The recipe skill band clears the icon and the Reagents header | GitHub; #685; also CurseForge thread 8702929 |
| soviman1 | Smelting recipes show their skill range | CurseForge; #688; thread 8703325 |
| Yivry | Items in your bags can be used after holding Shift over their tooltip | CurseForge; #708; thread 8706489 |
| luna | A route step opens its recipe on the visible crafting page | Discord; #683 |
| [FreakinNerd](https://github.com/FreakinNerd) | SkillUp's pages no longer draw over the Professions window's own page | GitHub; #658, fixed in 1.9.1 (#669) |
| nookie909 | A route you are shopping for stays put after buying its reagents | CurseForge; #621; thread 8689912 |
| [vladdoubrov](https://github.com/vladdoubrov) | Held sub-craft reagents are used from the bags before crafting more (#667) | GitHub; #667 |
| _spada | Asked for completed-sale values when planning profession levels (#478) | Discord |
| kopuliak | Item-level searches filter bundled unlearned recipes | CurseForge; #662, thread 8697280 |
| [SanyaBane](https://github.com/SanyaBane) | Recipe tooltip keeps its skill bar when another tooltip clears (code) | GitHub; #649, PR #649 |
| [Rambomst](https://github.com/Rambomst) | Fixed progress-bar fill masking and Auctionator prices after reload (#655, #656) | |
| bromidious | Reported overlapping Supply controls and profession tabs staying visible (#787) | Discord; #787 |
| bromidious | Reported route progress bars overflowing their track (#665) | Discord; #665 |
| fusionley | Reported Auctionator lists coming back after being deleted (#714) | CurseForge; thread 8710486 |
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
| cotijelucie | Newest recipes, grouped controls and independent tooltip details | Discord; #486, #725, #736; message 1571545185374970028 |
| cotijelucie | Skill ranges start where learned | Discord; #519 |
| CodexFD | Professions window keeps one width | CurseForge; #505 |
| rockhumper84 | TradeSkillMaster as a price source | CurseForge; #488 |
| Kozoaku | TradeSkillMaster auction prices (code) | GitHub; PR #500 |
| st3nlee | Self-supplied reagents priced at market values | CurseForge; #399 |
| st3nlee | Crafted items' sale value counted | CurseForge; #466 |
| st3nlee | Route prices respect limited vendor stock | CurseForge; #881 |
| turkeyfire69 | Auctionator searches start on request | CurseForge; #880 |
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
| Da_Tronic | Movable minimap button when ATT shares its position | CurseForge; threads 8710025, 8712306 |
| shenhyrosame | Minimap button discoverability and profession-window access | CurseForge; threads 8715494, 8715499 |
| davefin | Hide unlearned recipes with no estimated skill-up chance when filtered | Discord; #975 |

## Inspired by

Credit for the addons and projects an idea came from.

| Who | What | Notes |
|---|---|---|
| [Polestar](https://github.com/fitzforge/polestar) by Fitz | Ideas for many features | Expert and Artisan First Aid and Cooking from books and quests; skill colour on nodes and skinnable mobs; the shared report window and tooling. GPL-3.0. Inspired only; no code was copied. Fitz is welcome to use our code. |

Thanks also to everyone else who reported a bug or asked for a feature, here or on CurseForge.
