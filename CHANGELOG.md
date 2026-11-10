# Changelog

What changed in each release, in the terms someone levelling a profession would notice. Dates are UTC.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). The entries are prose rather than bare
Added/Fixed lists: what matters about a release is why a number on the screen changed.

Each version's entry is also its release notes on GitHub, CurseForge and Wago. Older entries are kept
verbatim rather than rewritten as the addon moves. API changes other addons' authors need go under an
optional `### For addon authors` subsection after a version's player bullets.

## [Unreleased]


## [1.3.5] - 2026-11-10

- **The tracker no longer flashes while you hover equippable items.** An item's tooltip and its comparison tooltips were making the tracked reagents section redraw for item details it does not show. It now draws again only when a reagent or book it lists arrives. Thanks to hardliquor on Discord for the report (#526).

## [1.3.4] - 2026-11-10

- **Opening SkillUp's options no longer shows a blocked action error.** The Open buttons on the options index, `/skillup` and the addon compartment entry now ask the game to open its options instead of opening them themselves, so the client does not refuse the request and blame SkillUp Forever (cjber/forever-core#333).

## [1.3.3] - 2026-11-10

- **Recipe skill ranges start where you learn the recipe.** *Newest recipes first* now sorts correctly too. The client leaves most recipes' first threshold at 1, so the tooltip, its bar, the recipe rows and the sort all took 1 as the range start: Dark Leather Belt said "Skill range starts at 1" although its trainer asks 100, and recipes learned later sorted as if they were learned first. The start now comes from the trainer or recipe item that teaches the recipe, so 406 recipes show the skill you learn them at; a recipe learned at 1, or one the bundle has no source for, keeps the client's number. Thanks to cotijelucie on Discord for the report (#519).

## [1.3.2] - 2026-11-10

- **No more blocked actions in combat.** Hiding or showing one of SkillUp's pages while you were in combat was refused by the client, which showed up as an "action blocked" message while casting or learning a plan. The page switch now waits for combat to end, and your own tabs still update the moment you click. `/skillup` typed in combat opens the settings panel once combat ends rather than being refused.

## [1.3.1] - 2026-11-10

- **Auction prices can come from TradeSkillMaster.** With TradeSkillMaster installed and no Auctionator price for an item, reagents and crafted items use TSM's AuctionDB: its latest snapshot's market value, then the lowest buyout, then the 14-day market value. The desktop app refreshes that data, so TSM does not report how old a price is and no age is shown. Auctionator stays first when both are installed, and its shopping lists still need Auctionator.

## [1.3.0] - 2026-11-09
- **The recipe list can put the recipes you learned most recently first.** *Newest recipes first* sorts by the start of each recipe's skill range, highest first, since trainers teach recipes in that order, and keeps unlearned recipes under their divider. It is in the Filter menu's *Sort by* section and in the addon's settings. Thanks to cotijelucie on Discord for the idea (#486).
- **The Professions window keeps one width while it is open.** Searching, filtering, collapsing a category or crafting used to let the window grow and shrink as the recipe list changed. It now takes its width when a profession opens and keeps it, so the window stops moving under your pointer. Reported on CurseForge by CodexFD (#505).
- **Hovering items no longer stutters with Auctionator loaded.** Each item the game looked up for a tooltip made SkillUp work out the shopping list of every route you track again. Those lists now stay as they are until a price, a plan or your bags change them. Reported on GitHub by Weythx (#503).

<!-- discord-image: docs/screenshots/window.png -->

## [1.2.2] - 2026-11-09

- **Tailoring and First Aid have a route without Auctionator.** Cloth drops from creatures, so with *Buy reagents at the auction house* off it counts as something you get yourself, like other loot, instead of leaving every cloth recipe out of the route. Tick the switch to price cloth at the auction house. Reported on CurseForge by user_sgjdcemk8ha090ft (#487).

## [1.2.1] - 2026-11-09

- **Less work while you hover gear with item comparison on.** The game refreshes an item's tooltip and its comparison tooltips while you move, and SkillUp now adds its lines from what it already worked out instead of counting your bags and rebuilding them each time. Reported on CurseForge by iPulse (#477).

## [1.2.0] - 2026-11-09

- **The Professions window has one SkillUp side tab instead of one per page.** It opens the SkillUp page you used last, and Route, Crafted gear and Buffs are now bottom tabs under the window, like the character window's own tabs. The three settings still choose which pages exist; turn every one off and the side tab goes with them. The tab keeps its place beside What's Training?'s corner tab, and stays a real button so the gamepad interface does not read our scripts (#460).
- **A new Buffs tab shows what each profession can make for you, and when.** Its own dropdown picks the profession, including crafters you do not have, and remembers the choice; it starts on the open profession when that one makes buffs. One row per buff effect (Strength, Agility, Stamina, Intellect, Spirit, attack power, fishing skill, and so on), each item in the column of the skill its recipe is learned at. Items learned at one skill share a column, so every node sits under its own skill number and the columns line up across rows. A profession with more than a screenful of buffs scrolls sideways when you drag the timeline, or with Shift and the wheel, and opens on your current skill. Green nodes are known, yellow ones you can learn now, grey ones are still ahead, and a lock marks a buff above your level. Hover for the item tooltip and the recipe facts, click for the buff in the game's own words, where it is learned and its reagents, and an action button that opens a known recipe or sets a waypoint to its trainer. Cooking, Alchemy and the rest get their specialization art behind the timeline, a divider names the next rank and the skill that trains it, and "Only for level N" hides what you cannot use yet. Another crafter's items are grey, with no rank divider and a disabled action that says so (#461, #357).
- **The generated recipe data now says which effect names a buff's row.** The pinned build's spell effects give each buff spell its aura type and stat, skill line or resistance, so the buffs tab never guesses from description text. A buff the client has no word for is named by its spell.

<!-- discord-image: docs/screenshots/buffs.png -->

## [1.1.8] - 2026-11-09

- **A recipe's product now lowers the cost of every craft in its step, not only the first.** The route page priced a step's first craft with what its product sells for and every later craft at its full reagent cost, so a bandage that vendors above its cloth showed only the cloth's cost, and a profitable recipe never showed the gain its gold made. Every craft now counts the sale under *Count what crafts sell for*, while a free or profitable recipe's extra crafts still pay their reagents so a run to grey does not look free. Reported on CurseForge by st3nlee (#466).

## [1.1.7] - 2026-11-09

- **Opening the Professions window's Filter menu with a gamepad no longer gets SkillUp blamed for a blocked action.** SkillUp adds its sort and buff options to the Professions window's own Filter menu, and the client opens that menu from the gamepad footer. Those options read the addon's saved settings, so the client built the menu under SkillUp's taint, the gamepad frame manager took it into its focus as SkillUp's, and the next secure reader's protected call was refused. With the gamepad interface on the menu keeps the client's own filters, and both settings stay in the addon's settings page; with mouse and keyboard the options are there as before. Reported on CurseForge by Viper2042 (#454, #398).

## [1.1.6] - 2026-11-09

- **The merchant's Reagents tab no longer raises a Lua error when it lists a reagent.** It drew each item through the item button's `Icon` field, but the merchant window's Mainline item button keeps its icon in `icon`, so opening the tab or moving the pointer over a cell raised "attempt to index field 'Icon' (a nil value)". The tab now reads the icon region through the client's own `GetItemButtonIconTexture` and keeps it on the cell. Reported on CurseForge by user_gnq1vt5zaofnctlx, tgkGate and user_oj6nehterf0ydf1p (#447).
- **Hovering gear in your bags or on the character panel no longer rebuilds its tooltip's lines.** A bag, item, name, zone or merchant change used to drop every item, node and corpse tooltip's cached lines, and bag addons fire those constantly while the pointer moves across gear. Each hover then worked the item out again and rebuilt the index of routes that need a reagent. Those changes now leave the cached lines alone: the routes are indexed separately and re-read only when a route or the tools it still needs actually move, and a route line reads its count from the bags as it is drawn. A repeated hover of the same item is a table lookup. Thanks to user_gxp60l4cnnhigc69, icouldonlygetthisname, 3kinex, 0xTrk and Setuaro for the reports and the measurement (cjber/skillup-forever#412, CurseForge 8671057).

## [1.1.5] - 2026-11-09

- **The Professions window's Filter menu can show only the buffs you can use.** *Only buffs for your level* lists the recipes whose product is an elixir, flask, Well Fed food, protection potion, sharpening stone, oil, armour kit or scope you can use at your level, highest required level first. Unlearned ones follow when *List unlearned recipes* is on, with where they are learned. Healing potions, bandages and plain food restore rather than buff, so they are left out. The filter is also in the addon's settings (#357).
- **The levelling route prefers a buff you can use when two recipes are otherwise equal.** When two recipes cost the same per skill point and have the same chance, the route now takes the one whose product is a buff your level can use, so the crafts leave you with something useful, before falling back to the lower recipe ID. A recipe that costs more per point still loses (#357).
- **A buff recipe's tooltip now says what the buff does and where its reagents drop.** The recipe tooltip shows the buff in the game's own words, and with Questie each reagent gets the nearest zone it drops in. A buff consumable's own tooltip names the profession and skill that make it (#357).
- **The route and crafted gear tabs stay in the Professions window beside What's Training?'s own tab.** What's Training? pins its tab to the window's bottom-right corner, in the same strip as ours; a tab switch re-ran the placement, took that corner tab for the last slot and moved the SkillUp tabs underneath it, below the window's edge. The placement now gives our tabs the next free slots under Blizzard's profession tabs, so all three share the column while there is room, whatever order the addons load or re-place their tabs. Reported on CurseForge by user_gxp60l4cnnhigc69 (#446).
- **The Forever Leaderboards period menu works with a gamepad.** With the gamepad interface on, a press on it steps through this week or all time, for your guild and group or for players you've met, instead of opening a game menu that later had the client block `SetPreferredGamepadInteractTarget()` (cjber/forever-core#267).

## [1.1.4] - 2026-11-08

- **The Professions window no longer stutters while it is open.** The client sends recipe-list updates with nothing new in them, and the addon used to redraw the route, tracker, tooltips and shopping list for each one; it now redraws only when the open profession, its skill or the recipes you know actually change. A tracked route also follows a reagent to its new shopping source when item data or a merchant's stock arrives. Reported on CurseForge by Setuaro, 0xTrk and 3kinex (#412).

## [1.1.3] - 2026-11-08

- **With the gamepad interface on, a trainer no longer shows a blocked-action error that names SkillUp.** The error was the client refusing its protected `SetPreferredGamepadInteractTarget()`. SkillUp's right-click menus were opened from its own code, so the gamepad frame manager took them into its focus under SkillUp's taint, and the next window to show or hide read that taint and had its protected call refused. Under the gamepad interface those menus now show "This menu needs mouse and keyboard." instead of opening, and a press on the route's profession picker steps to the next profession. Reported on CurseForge by Viper2042 (#398).
- **The Forever addons page opens with a gamepad.** With the gamepad interface on, the Forever addons settings page can be entered from the Options list (cjber/tweaks-forever#382).

## [1.1.2] - 2026-11-08

- **Working Overtime now gives 4% per point, up to 20% at five.** Each point spent in the Legacy talent raises every yellow and green recipe's skill-up chance by 4 percentage points, where the addon used to look for a spell or aura the client does not have and missed the talent entirely. The route and its costs follow. Reported on CurseForge by Kirdan (#419).
- **The merchant's Reagents tab is back on the merchant window.** The tab was built from a Vanilla-only tab template the Forever client does not load, so opening a merchant that sold something a tracked route needed raised a Lua error and never drew the tab. It now uses the same tab template as Merchant and Buyback. Reported on CurseForge by TechnoHunter (#437).

## [1.1.1] - 2026-11-08

- **A Leatherworking pattern now plans from the skill its trainer teaches it at.** Gray Leather Boots plan from Leatherworking 35, as a Leatherworking trainer lists them, where the bundled guess said 75 (Classic's 100 moved as far as Forever moved its skill range). The same visit confirmed the bundled requirement of the eight other moved Leatherworking recipes that trainer teaches, so only this one changes (#124).

## [1.1.0] - 2026-11-08

- **The tracker can have a background.** Right-click any section's title in the Forever tracker and pick *Tracker background*: Off, or the game's tooltip fill at 25, 50, 75 or 100%, so quest text stays readable over bright ground. The choice is shared by every Forever addon in the column (cjber/forever-core#246).
- **Recipes you have not learned now show the same tooltip as the ones you know.** Hovering one under the Unlearned divider lists its reagents with counts, prices one craft from your own price sources, draws the skill-up colours and chance, and says whether a trainer or a recipe item teaches it and at what skill. The rows still take no click, so they are never selected or crafted. Thanks to prokn4h for the request (cjber/skillup-forever#420, CurseForge 8658050).
- **The merchant's reagents now sit in the window's own Reagents tab.** The red button that floated above the title bar is gone: a merchant that sells something a tracked route still needs gets a third tab beside Merchant and Buyback, in the same tab art. It lists those reagents in the merchant's item cells with the cost of whole stacks, and *Buy all* with the total sits where the page row was, opening the same confirmation first. Merchant and Buyback work as before, and *Show the merchant Reagents tab* turns it off. Seen in game at Dalmond, Auberdine (#410).
- **Moving across a bag of reagents does far less work per item.** Each new item hover rebuilt every tracked route's material list, so a bag or the character panel, with dozens of different items, paid that cost on every item while a handful of action-bar items paid it once. The tracked routes are now indexed once per change and a hover only looks up its own item. Thanks to 0xTrk, user_gxp60l4cnnhigc69 and Setuaro for the reports (cjber/skillup-forever#412, CurseForge 8667390).
- **Controller players no longer trip the client's gamepad block when the Professions window opens.** The route and gear side tabs were frames carrying the side-tab template's mouse scripts, and the gamepad interface's navigation reads a frame's mouse scripts when it focuses a window. Reading ours there tainted the gamepad action bar, so the protected `SetPreferredGamepadInteractTarget()` was refused and blamed on SkillUp. The tabs are real buttons now, so that scan never reads a script this addon created. Thanks to Viper2042 for the report (cjber/skillup-forever#398, CurseForge 8664985).

## [1.0.40] - 2026-11-08

- **The Forever Leaderboards window and `/forever` come from the newest addon installed.** Whichever Forever addon loaded first used to keep its own copy of the window, even an older one, so recent fixes such as full Forever names and `/forever debug` reached you only by chance. The newest copy now takes over (cjber/forever-core#235).

## [1.0.39] - 2026-11-08

- **Tooltips stay cheap while the pointer rests on an item.** The client sets the same tooltip again and again while it is shown, and the addon worked out the item's uses, the tracked routes that need it and its gathering lines every time. Each answer is now kept by item, node and corpse until a recipe, skill, bag, plan or setting change drops it, so a repeated set only draws the lines it already worked out. Thanks to Setuaro for the report (cjber/skillup-forever#412, CurseForge 8665828).
- **The report keeps errors from earlier sessions.** An error SkillUp caught before the last `/reload`, a blocked action or a Lua warning was forgotten when the client reloaded, so it could not be copied into a report once it was gone. The report now lists them under their own heading, with when each was first and last seen and the version, build and locale it happened on, and keeps the 50 most recent. It also carries SkillUp's recent log lines, the steps that led up to a bug, and `/forever debug` turns on detailed lines for the session (cjber/forever-core#204, cjber/forever-core#206).

## [1.0.38] - 2026-11-08

- **The Forever addons settings page no longer writes the client's bare `Text` name.** Its check box came from a Blizzard template under an unnamed page, so the label landed on a global another addon or the game could read as its own. The page is named now (cjber/forever-core#208).

- **Closing the Professions window on the route or gear page no longer shows a Blizzard page from inside the game's own hide.** The window went back to its crafting page from the close itself, which runs in the client's secure panel path, the same kind of mistake 1.0.35 fixed for opening it. That page work now runs on the next frame. This may be behind a controller player's blocked SetPreferredGamepadInteractTarget report (cjber/skillup-forever#398). Thanks to Viper2042 for the report.

- **The levelling route tab stays beside the Professions window with All The Things loaded.** All The Things keeps the window's side tab column in a frame of its own and puts its own tab in the next free slot inside it, and the addon took that frame for the lowest tab, so the route tab slid down under the window and looked attached to nothing. It now sits under the tab already in the column, beside the window, and opens the route inside it. Thanks to TechnoHunter for reporting it (cjber/skillup-forever#402).

- **A profitable recipe no longer gets cheaper the longer a route runs on it, and a craft's time now counts.** Rough Bronze Leggings sold for more than their Bronze Bars, so Blacksmithing 105 to 150 asked for 183 of them and training that would have replaced them never showed a saving. The route now charges the first craft of a step at the recipe's net, never a profit, and the extra crafts a falling chance needs at its reagents, and gives every craft a small price for its time, so a stretch at 1 in 30 no longer looks free even when its reagents are gathered. Thanks to jakeyjake07 for the report (cjber/skillup-forever#400).

## [1.0.37] - 2026-11-08

- **Self-supplied reagents can now be priced at market values.** A new Prices setting, off by default, stops a reagent you gather, loot or already own from counting as free: it takes its Auctionator price after the 5% cut, or its vendor sell price when that is higher, so the route, shopping list and cost totals describe what a fresh character would pay. A reagent with no market price stays unpriced instead of becoming free, and the route page and report say which pricing mode is on (cjber/skillup-forever#399, CurseForge 8664058).

## [1.0.36] - 2026-11-08

- **A route that leans on one cheap reagent now says so.** A recipe the addon has no reagent price for is left out of the plan, so a route can end up sitting on one low-tier pattern and printing totals nobody could farm, which is what a Leatherworking route from 35 to 100 did with Light Leather (cjber/skillup-forever#394). The route page now warns when a route is mostly one reagent while recipes were left out, naming the reagent and how many recipes are waiting on a price. Saving and scanning the auction house with Auctionator is still what fills those prices in.

## [1.0.35] - 2026-11-08

- **Opening the Professions window no longer raises a blocked action.** The route and gear pages used to hide their frames from inside the client's own panel show path, which the client refuses with ADDON_ACTION_BLOCKED. The page work now runs on the next frame, so the window opens and closes cleanly whichever way it is opened (cjber/skillup-forever#393).

## [1.0.34] - 2026-11-07

- **The route's Craft button can make the whole step.** Shift-click presses the Professions window's Create All, and when the route's step fits in your bags a plain click makes all of it. The button now waits until the window shows the route's recipe and its own Create button is ready, and it opens the recipe once per step instead of on every redraw (cjber/skillup-forever#385).

## [1.0.33] - 2026-11-07

- **Crafting from the route works on Forever.** The route page's Craft button no longer tries to cast the recipe by its spell name, which this client ignores. It opens the planned recipe through the client's own `OpenRecipe` and forwards the click to the Professions window's own Create button, so the craft happens as your own click and still never runs as addon code, and it now takes the click on press as well as release so the key-down setting cannot swallow it (cjber/skillup-forever#385).

## [1.0.32] - 2026-11-07

- **Recipes you have not learned can sit in the recipe list too.** A new setting, off by default, adds the open profession's unlearned recipes under an Unlearned divider, greyed and marked with a trainer or recipe item and the skill it asks, so what is ahead is in the same list. Unlearned rows cannot be selected or crafted. Thanks to prokn4h for the request (cjber/skillup-forever#361).
- **Cooking routes use recipes you can buy from vendors and know when stock is limited.** A recipe sold as a scroll at a vendor is now planned like a trainer's, with the scroll's price as its fee and its required skill as where it can be learned, so a cheap vendor recipe replaces the long green stretch that used to end a route. A reagent the vendor the route sends you to stocks in a limited amount now says so, using the stock that vendor's own window shows where you have seen it and the bundled data otherwise, and its tooltip gives how many are sold at a time; a vendor seen selling unlimited stock clears a bundled limit, rather than showing a whole 280-craft route as a single purchase. (cjber/skillup-forever#358).


## [1.0.31] - 2026-11-07

- **Meat and fish on a Cooking route count as yours to get.** Fish count as gathered when you know Fishing, and the parts creatures carry (meat, eggs, scales, feathers, venom sacs, elemental essences) count as gathered for every character, so with Buy reagents off they cost nothing and the switch no longer says it changes nothing for a Cooking route. Cloth, herbs and ore are unchanged: cloth is still bought, and herbs and ore still need the profession. A looted reagent's step reads "Loot ... from creatures" (cjber/skillup-forever#367).

## [1.0.30] - 2026-11-07

- **The Forever Leaderboards tab wears a game icon.** SkillUp's tab in the shared window now draws the game's own blacksmithing icon instead of the addon's logo, so it sits beside the overall trophy without a second gold frame. The TOC, minimap and the rest of the addon keep the addon's icon. (cjber/forever-core#180)

## [1.0.29] - 2026-11-07
- **Opening a recipe, or skipping one from its right-click menu, no longer blocks using an item.** A recipe opened from the route page, or from the tracked-reagents menu, was selected in Blizzard's recipe list by this addon, and changing a row setting or the sort did the same through the page's own rebuild. That wrote the list's selection and the recipe's schematic as the addon's, and the game's craft path reads them, so using a potion or turning one essence into another could be refused until `/reload` (#350, thanks Ekallo). The recipe now opens through the game's own `C_TradeSkillUI.OpenRecipe`, and a redraw re-sorts and redraws the rows in place instead of rebuilding Blizzard's page, so no addon code touches the selection.
- **Skill-up percentages include Working Overtime.** Picking the Legacy talent adds its 10% to every yellow and green recipe's chance, and the route and costs follow (#349).
- **A locked tracker stays quiet until you hover it.** With *Lock the tracker* on, the Forever column's grip no longer shows the long "tracker is locked" sentence all the time, where it overlapped whatever sat below and ran off screen at an edge. The grip stays blank until the pointer is over it, and the sentence is in its tooltip. Thanks to MrFIXlT for the request (cjber/forever-core#193).

## [1.0.28] - 2026-11-07
- **The reagent prices add up to the Reagents total.** Each reagent line is priced the same way the total counts it - the cheaper of buying the reagent and making it - so a reagent your own recipe makes for less no longer shows its higher purchase price on the line against a lower total (Copper Bars 11s 34c against an 11s 32c total; Heavy Leather 51s against 32s), and a craft that loses money shows its red minus on Net per craft as it already did on Per skill-up. Thanks to derzwiebelritter and trias6657 for the reports (cjber/skillup-forever#360).

## [1.0.27] - 2026-11-07
- **Leaderboards show full names.** The Forever Leaderboards rows and tooltips show a player's first name and surname, such as "Dirtyjoke Lovetties", instead of one run-together word or the first name alone. (cjber/forever-core#179)

## [1.0.26] - 2026-11-07
- **The Forever Leaderboards window opens.** `/flb` and `/forever` no longer raise a Lua error on first open: the list's rows now have a fixed height (cjber/forever-core#174).

## [1.0.25] - 2026-11-07
- **SkillUp's recipe board joins the shared Forever Leaderboards window.** `/su leaderboard` and `/su stats` now open one window for every installed Forever addon on SkillUp's tab, with this week's and all-time observed recipe totals, the overall standing across the boards, and the player's place in the unit tooltip. Sharing is on by default: everyone running a Forever addon appears unless they turn it off, and the window's Share my progress switch, `/su share off` or the settings checkbox keeps them off. Recipes already observed stay counted, and reported totals remain player-reported.

## [1.0.24] - 2026-11-07
- **The recipe list fits long recipe names, and says how many you can make beside them.** The Professions window widens its recipe list to the longest name in the open profession, up to the room your screen has, and the count your bags can make now sits in parentheses after the name. Turn the setting off to keep the window's own width.

## [1.0.23] - 2026-11-06
- **You appear once on leaderboards with a two-part name.** A Forever name like Hel Io no longer shows twice, once as you and once as a reported player with the same value.

## [1.0.22] - 2026-11-06
- **A route no longer stays on a free or profitable recipe as it goes grey.** A craft that costs nothing after its sale price, or makes money, was ranked as free at every skill, so the route kept it even when a skill-up needed dozens of crafts: Tailoring 40 to 75 asked for 190 Linen Bags and 1202 Linen Cloth. The craft that earns each point now counts its net cost, and the extra crafts a falling chance needs count at the recipe's reagent cost, for every priced recipe, so the route switches to one that is cheaper to walk. Thanks to a CurseForge player for the report.

## [1.0.21] - 2026-11-06
- **The skill bar's difficulty bands are drawn at the bar art's native height instead of squashed.** The tooltip and details bar pulled a 240 by 15 fill down to about 10.25 high, which flattened the art; the bands now use the client's 124 by 10 cooldown manager fill, keeping its height and varying only its width with each band.

## [1.0.20] - 2026-11-06
- **The skill bar and the selected gear slot use the game's current art.** The tooltip and details bar filled its difficulty bands with a texture the client has carried since before Legion, and a selected gear slot washed the icon with the old check highlight. The bands now use the fill the game's own progress bars use, keeping their colours, and a selected slot shows the professions window's gold glow, so the icon underneath stays readable.

## [1.0.19] - 2026-11-06
- **The tracker column steps aside for EQ Objective Tracker.** EQ Objective Tracker hides the game's quest tracker and draws its own list in that same slot, so its quests and this addon's tracker section drew over each other and neither could be read. The section now asks EQOT where its list is through EQOT's public API and re-places itself below, above or beside it after every redraw, and reads EQOT's own frame the same way when that API is not there. Turn EQOT off and the column goes back where it was.

## [1.0.18] - 2026-11-06
- **Crafting from the route no longer blocks a potion or a conversion.** The route's Craft button ran a `/run` macro supplied by addon code, and macro text an addon gives a secure button still runs in that addon's context: calling the game's protected craft function that way tainted the craft path, so using a potion or turning one essence into another could be refused until `/reload` (#327, #313). The button now sets a spell attribute, which the client resolves itself exactly as clicking the recipe in the Professions window, so no craft runs as addon code. One click now casts the recipe once, as the client's own Craft button does, so a step that wants several crafts takes several clicks. The merchant button no longer calls the protected buy function either: it lists what the tracked routes still need and the total cost, and you buy it from the merchant's own window.

## [1.0.17] - 2026-11-05

- **Crafting from the route works with a controller.** The route's Craft button called the game's protected craft function from addon code, which tainted the client's own crafting path: the craft never finished and controller input stayed blocked until `/reload`. The button now asks a secure button to run the craft as the client's own, and the tracked-reagents menu opens the recipe so its native Craft button does the same. A redraw during a fight waits for the fight to end before it touches that secure button, so it cannot trip the same block itself.

## [1.0.16] - 2026-11-05
- **Tall tracker sections stay under your quests.** A section that fills the room left below the quest tracker now shows what fits there instead of the whole column jumping beside the tracker. Each section gets the room the ones above it left, less the gap under it, so the column never runs past the bottom of the screen. The column only moves above or beside the tracker when nothing fits below it at all.

## [1.0.15] - 2026-11-05

- **The Forever addons settings page ends with a Ko-fi link.** If the addons help you, its Copy link button shows the address, ready to paste into your browser. Nothing is locked behind it, and it shows nowhere else.

## [1.0.14] - 2026-11-05

- **Long lists in the Professions window scroll.** The skipped and pinned route menus, the profession dropdown and a shopping list's block menu show 20 entries at a time and scroll the rest, so every entry stays reachable on any screen. The shared settings page also drops a dropdown helper nothing used.

## [1.0.13] - 2026-11-05

- **The settings page opens without an error.** Its title asked the game for a font Forever does not have, which logged a Lua error each time the page was built; it now uses the font the game's own settings pages title with.

## [1.0.12] - 2026-11-05

- **Opening the Professions window no longer shows a Lua error.** With both side tabs on, the levelling route tab could try to sit under the crafted gear tab, which already sat under it, so the game refused the anchor and raised an error. The route tab now always comes first and the crafted gear tab follows it, below any tab another addon has added to the column.

## [1.0.11] - 2026-11-05

- **The objective tracker column stays still as you enter and leave combat.** All Objectives and your quests keep their place at the top, and the Forever sections always follow below them, so nothing swaps order, jumps or loses a line when a fight starts or ends.

## [1.0.10] - 2026-11-04

- **Profession data now names the 1.60.1.70790 build.** Thresholds, recipes, vendors, trainer requirements and sources are regenerated from the new Forever client build, so every number the addon shows comes from the client you are running. The regenerated skill ranges match the previous build, so nothing a player sees changes.

## [1.0.9] - 2026-11-04


- **Shift-clicking a recipe in the route reliably links it in chat.** The link used a compatibility function that only exists while the game's deprecation fallbacks are enabled. Without them, the click raised a Lua error. It now uses the chat frame's own link insertion.

## [1.0.8] - 2026-11-04

- **Profession data regenerated against the 1.60.1.70755 build.** The profession data (trainer ranks, vendor stock, skill thresholds and sources) is rebuilt from the new Forever client build. The regenerated values match the previous build, so the skill numbers you see do not move.

## [1.0.7] - 2026-11-04

- **Family links keep their gold-bordered buttons when an older addon loads first.** The shared window takes over from older installed copies, so an addon that loads first can no longer keep the legacy button implementation whatever the load order.
- **Peer statistics registrations stay private to their addon.** An addon observes shared leaderboard rows without taking over another addon's sender, and leaderboards accept pair subjects for encounter difficulty.

## [1.0.6] - 2026-11-04

- **Shopping confirmations use the native dialog surface.** The purchase prompt keeps its gold-bordered buttons and uses an opaque NineSlice background. Shared CI also rejects legacy templates and backdrop globals that select loose chrome.
- **Family links keep their gold-bordered buttons when an older addon loads first.** The shared window takes over from older copies so addon load order does not select its button style.

## [1.0.5] - 2026-11-03

- **Preview screenshots use the game's own art.** The rendered scenes in `docs/screenshots` now take their window art from Forever Core's canonical art pin instead of a copy kept here, so a preview cannot show chrome the shipped client does not draw. A new regression test fails when an asset lookup bypasses the pin. Profession data generation stays on the build it already targets.

## [1.0.4] - 2026-11-03

- **Auctionator lists stay with their character.** Route and crafting lists include the character and realm, so switching characters does not replace another character's supplies. Existing lists with the old shared names are left untouched and can be removed in Auctionator.

## [1.0.3] - 2026-11-03

- **A leaderboard for recipes observed learned.** `/su leaderboard` (or `/su stats`) compares your character's distinct recipe observations with totals reported by guild and group members. Repeated scans and relearning do not add to the score. Sharing defaults on; the settings checkbox or `/su share off` stops sending and receiving and hides other players while keeping your history. A saved off choice stays off. Totals are player-reported, not verified.

- **Pin a recipe for skill-ups.** Right-click a route recipe to prefer it through its usable range, including its trainer visit. The newest pin wins where ranges overlap. Pinned rows explain missing prices, requirements and grey recipes, and the tracker menu lets you remove pins.

- **Controls use the Forever asset set.** Shopping list and route controls use the native gold-bordered buttons, and CI rejects legacy loose chrome in runtime UI and screenshot renderers.

- **The profession tabs sit clear of What's Training?'s own tab.** That addon pins its own profession tab to the window's bottom-right corner, which lands in the same strip as ours without joining Blizzard's tab list, and the placement check only looked at the next Blizzard slot, so our tabs could sit on top of it. They now sit under the lowest tab already in the column.

- **What's Training?'s page no longer swallows clicks on ours.** Its page is drawn above the crafting page and stays open when another tab is chosen; our pages now draw in the HIGH layer, above it and below dialogs, so the tab you clicked is the page you get.

- **The "Auctionator's autoscan is off" hint can appear again.** It read Auctionator's old `AUTOSCAN` option, which no longer exists, so the note never showed even with the option off. It reads `AUTO_LIST_SEARCH` now.

## [1.0.2] - 2026-11-03

- **Custom profession pages switch cleanly.** Route and Crafted gear hand off through the native crafting page without leaving another addon page visible or changing Blizzard's gamepad tab state.

- **Profession plans do less work when recipes or prices change.** Each replan reads the recipes for that profession, and repeated profession and reagent lookups allocate less temporary data.

- **No more error while the game is still loading your character.** Opening the shopping list or the route before the client had reported your realm raised "attempt to concatenate a nil value". The addon now reads the realm's display name when the normalized one is not there yet, and until either arrives your per-character settings show their defaults and nothing is saved.

## [1.0.1] - 2026-11-03

- **The profession data now matches the 1.60.1.70753 build.** Enchant Boots - Speed is in the recipe list for the first time, with its pattern, its reagents and its thresholds, and the five enchant patterns the build added join the scroll list so a pattern you own is recognised. Nothing you already had moves.

## [1.0.0] - 2026-11-02

- **The first stable release, ready for the WoW: Forever launch.** SkillUp Forever 1.0 works as 0.20.6 did: the recipe colours, the route, the shopping list and the tracker are unchanged. The version number now marks the addon as ready for everyday play, and the chat line after the update says so in every shipped language.

## [0.20.6] - 2026-11-02

- **Learning a recipe and reopening the route are quicker.** Learning a recipe no longer rebuilds the index of which recipes make each item, since that index only reads the bundled recipes, and the route's skill ceiling is read without building every rank. The harness benchmark runs about a third faster.

### For addon authors

- `API.RequiredMaterials` lists each raw item once. An item a sub-craft is made from and that the recipe also uses directly was listed twice, so a caller that keyed the result by item ID kept only one of the counts. It and `API.SubComponents` now return `nil` for a craft count that is not a whole number above zero, where NaN, infinity and fractions used to give unusable counts.

## [0.20.5] - 2026-11-02

- **Every line now reads in all nine languages.** The thirty-nine strings the shopping list, report and planner work added were still English in German, Spanish, French, Korean, Portuguese, Russian and both Chinese files; they are translated now, so no window falls back to English. The PR check asks for the same thing: `tools/typecheck.sh` runs the locale check with `--release`, so an English line added without its translations fails the change that adds it.

## [0.20.4] - 2026-10-30

- **More players are credited for their reports and fixes.** THIRD_PARTY.md's Ideas and contributors table gains rows for players whose reports, ideas or fixes shipped but were not yet credited there. Thanks to Mouchoir and zazomazzo for what they reported, asked for and fixed.

## [0.20.3] - 2026-10-30

- **Profession data re-pinned to client build 1.60.1.70707.** Recipes, sources, trainer requirements, vendor prices and skill thresholds are read against the newer Forever build; regenerating against it produces no change to the bundled numbers, so nothing a player sees changes.

## [0.20.2] - 2026-10-28

- **Profession data re-pinned to client build 1.60.1.70685.** Recipes, sources, trainer requirements, vendor prices and skill thresholds are read against the newer Forever build; regenerating against it produces no change to the bundled numbers, so nothing a player sees changes.

## [0.20.1] - 2026-10-28

- **Profession data re-pinned to client build 1.60.1.70658.** Recipes, sources, trainer requirements, vendor prices and skill thresholds are read against the newer Forever build and recorded with it. Regenerating against this build produces no change to the bundled numbers, so nothing a player sees changes.

## [0.20.0] - 2026-10-27

- **Other addons can now ask SkillUp Forever what a recipe really costs to craft.** `API.RequiredMaterials` returns the raw inputs for any recipe at a requested craft count, with the cheaper sub-crafts it already knows how to make folded out, and `API.SubComponents` returns those sub-craft recipes. Commissions Forever uses both to work out what a turn-in costs without carrying its own copy of the profession plan.

### For addon authors

- `SkillUpForever.API.minor` is now `4`. `API.RequiredMaterials(recipeID, crafts?)` returns `{ itemID, count }[]` and `API.SubComponents(recipeID, crafts?)` returns the valued sub-craft recipes, both `nil` for an unknown recipe. `ns.RecipeMaterials(recipeID, crafts)` is the shared price-aware entry point behind them.

## [0.19.10] - 2026-10-27

- **Profession data regenerated for client build 1.60.1.70630.** Trainer requirements, recipes, sources, vendor prices and skill thresholds are rebuilt from the new build, and the generators now read the newest Forever build from wago.tools' `wowf` product as well as `wow_classic_beta`. wago lists newer builds only under `wowf`, so the daily refresh had been reporting itself already current and skipped regeneration; that is why the bundled data sat on the previous build.

## [0.19.9] - 2026-10-26

- **The addon now ships the suite's dead-code gate, and an unused details-bar accessor is gone.**
  `tools/deadcode.py` scans the addon for namespace members no code reads, Lua files no TOC loads and media
  nothing references, and runs as its own CI job; adopting it removed `ns.DetailsBarTop()`, which nothing called.
  Nothing changes in game.

## [0.19.8] - 2026-10-26

- **The addon now ships the suite's shared settings-page code.** Forever Core's settings-page chrome (`UI/SettingsPage.lua`) and its spec are vendored byte for byte so the suite's shared-code drift gate covers this addon; SkillUp keeps drawing its own settings page, so nothing changes in game.

## [0.19.7] - 2026-10-24

- The report keeps the same error details, now captured by Forever Core alongside the other shared report code.

## [0.19.6] - 2026-10-24

- **Report and issue text selects when focused.** Ctrl+C now copies the full report or issue link from either text box.

## [0.19.5] - 2026-10-23

- **The trainer requirements you have seen can be copied out.** `/su export` (also `/su export trainers`) opens a window holding the requirement each trainer actually showed your character, written as a `SEEN_REQUIREMENTS` table you can paste into a report. A number no bundled rule guessed right then gets corrected for everyone, not only for you (#124).

## [0.19.4] - 2026-10-23

- **The shopping list says which skill level it is buying for.** The list already followed each profession's route target, but the window never showed it, so it read as one plan to 300: every row now names its target (`Silk Cloth (Tailoring to 60)`) and a line under the title lists each tracked profession with the level it is buying for (#232).

### For addon authors

- `SkillUpForever.API.minor` is now `3`; each `API.ShoppingList(skillLineID?)` record carries `target`, the base skill that profession's plan buys to.

## [0.19.3] - 2026-10-23

- **The Forever addons link box selects its address without a Lua error.** Focusing the read-only box handed the client's own `isUserInput` flag to `HighlightText` as its start argument, so it raised *bad argument #2 to '?' (outside of expected range -2147483648 to 2147483647)* and left the address unselected. It now selects the whole address the way the game asks, from the shared link box the Forever addons all carry (#269).

## [0.19.2] - 2026-10-23

- **Report a bug or request a feature from the game.** `/su issue` (also `/su bug` and `/su feature`) opens a composer: write what went wrong, pick Bug or Feature request, and the window hands you a ready-made GitHub issue link, selected so Ctrl+C and a paste opens the new issue with your words and the addon's system report already filled in. Copy report still puts the same text in your hands for Discord.

## [0.19.1] - 2026-10-23

- **Data checked against Forever 1.60.1.70532.** Skill thresholds, recipes, vendor stock and trainer data are unchanged apart from the bundled data's build pin.

## [0.19.0] - 2026-10-22

- **A shopping list follows every tracked route.** Open it with `/su shopping` or `/su shop` to see missing materials by source, copy a plain text list, or plan vendor and trainer stops with Shortest Path Forever.

### For addon authors

- `SkillUpForever.API.minor` is now `2`; `API.ShoppingList(skillLineID?)` returns a fresh per-profession copy with need, holdings, price and totals.

## [0.18.13] - 2026-10-22

- **The objective tracker can be dragged in Edit Mode again without vanishing.** With snapping on, moving the tracker made it disappear and raised `EditModeSystemTemplates.lua:607: attempt to perform arithmetic on local 'left' (a nil value)` over and over: Blizzard's own move takes the native frame from one anchor to none mid-drag, and both our geometry probe and the hidden companion column were still hanging off that frame at the time. Both now let go before Edit Mode moves the tracker, the native anchor and screen clamp go back to the game outside combat, and queued layouts stay paused until you leave Edit Mode, so the column returns to its usual place afterwards. Thanks to zazomazzo on GitHub.

## [0.18.12] - 2026-10-21

- **Bag clicks no longer taint the objective tracker.** The reagent section used to hand itself to the game's own tracker through Blizzard's container call, which could register our section with Blizzard's tracker manager and taint protected UI paths; it now keeps the parent to itself, so the reagent list still sits under the tracker while clicking items in your bags stays clean.

## [0.18.11] - 2026-10-21

- **The game's All Objectives header stays in its own frame.** The shared tracker host used to lift that header out of the objective tracker and hang it above the Forever rows; the game re-anchors it on every tracker update, so the two fought and left a stranded header with a blank band under it. Nothing of ours touches that header any more - no re-anchor, no show or hide, no reserved gap - so the reagent section starts cleanly under the header and stays there through refreshes. Already released in Shortest Path Forever 1.21.8.

## [0.18.10] - 2026-10-21

- **The tracker no longer errors out beside another Forever addon's sections.** Our profession reagent section carries no ordering of its own, and the shared tracker host compared it against sections that do, so with Shortest Path Forever, Adventure Guide Forever or Legacy Forever loaded the layout pass died with `attempt to compare nil with number` on every refresh (297 times on the report). The shared host now keeps ordered sections in their order and places unordered ones after them in the order they were added; the ordering rule also moved into its own file so the host stays inside the project's file-size rule. Thanks to Torpdotorgx and dryzee on CurseForge.

## [0.18.9] - 2026-10-21

- **Sections that grow in combat no longer get cut off.** While you were in combat, a section that gained lines was drawn inside the height the column had before it grew, so the new lines stayed clipped until the fight ended. The column now measures the taller content and keeps that height for the rest of the fight, and a collapsed native tracker header no longer leaves a blank gap at the top. This is the same shared tracker host fix the other Forever addons already carry, so the quest tracker reports from Syrberus and Fareed are covered here too. Thanks to Syrberus and Fareed on CurseForge.

## [0.18.8] - 2026-10-21

- **Back to a goal level already planned is instant; the level it already has rebuilds nothing.** The planner kept exactly one plan per profession, so any goal level you had used before was planned from scratch again, and leaving the goal-level box rebuilt the route even when the number had not changed. It now keeps the last eight plans per profession, keyed by skill, cap, goal level and collect mode, and the box ignores a value it already holds. Thanks to CtrlDKhayos on CurseForge.

## [0.18.7] - 2026-10-21

- **The quest tracker can be moved again, and the reagent section no longer errors under All Objectives.** A module of ours sat in the objective tracker column on its own, pinned above Blizzard's sections, so Questie's quest list and the game's own quest tracker could no longer be dragged or re-placed in Edit Mode. The reagent section now goes through the shared Forever tracker host, re-reads where it hangs every time it lays out instead of caching the frame, and hides itself rather than raising if that anchor has gone away. Thanks to Fareed and ThePNAG on CurseForge.

## [0.18.6] - 2026-10-20

- **The shared Forever tracker can be locked in place.** *Lock the tracker* (Settings, Objective tracker) sits under *Attach to quest tracker* and is off by default. While it is on, the grip at the top of the column says the tracker is locked instead of offering to move it, and a drag does nothing, so a column placed where you want it stays there. Thanks to Alex21xx on CurseForge for the request.

- **0.18.5 is reissued as 0.18.6.** The 0.18.5 tag was cut, but that build never published, so the tracker lock ships here instead. Nothing else changed from 0.18.5.

## [0.18.5] - 2026-10-20

- **The shared Forever tracker can be locked in place.** *Lock the tracker* (Settings, Objective tracker) sits under *Attach to quest tracker* and is off by default. While it is on, the grip at the top of the column says the tracker is locked instead of offering to move it, and a drag does nothing, so a column placed where you want it stays there. Thanks to Alex21xx on CurseForge for the request.

## [0.18.4] - 2026-10-20

- **The skill bar is on the recipe itself, not just the hover.** Selecting a recipe in the Professions window now draws its orange, yellow, green and grey thresholds, with where your skill sits, under the recipe name: the same bar the tooltip shows, from the same numbers, so the two can never disagree. It follows the selected recipe at the rank you know, moves as your skill moves, and hides when nothing is selected. If it covers the reagents on an unusual layout, *Recipe rows* in Settings turns it off. Thanks to trias6657 for the idea.

## [0.18.3] - 2026-10-20

- **Questie's quest tracker can be moved again.** With a Forever section in the tracker, Questie's quest list and the game's own quest tracker could no longer be dragged, and could vanish. A frame of ours sat between UIParent and Questie's list, and Questie's own drag code reads the list's corners and then clears its points mid-gesture, so a layout pass of ours landing in that window left it nothing to read. Nothing of ours is anchored to the list any more: it is watched through its own show, hide, drag-stop and size calls, the column holds its place while you drag or resize it, and it reflows once when you let go. Thanks to procque and Fareed on CurseForge, and to the Questie team for the report that named the cause in Questie/Questie#8076.

## [0.18.2] - 2026-10-20

- **The Buy reagents switch can always be turned off, and a route with nothing in it says why.** The switch greyed itself out whenever the route had nothing your professions could gather, so a switch already on could be stuck on with no way back. It now stays clickable everywhere, greys only its label, and its tooltip says when it changes nothing for the route. The route is also planned separately for each setting, so turning buying on cannot show the other setting's steps, and a profession with nothing to craft now says so in the list instead of drawing it empty. Thanks to kurila11478 for the report.

## [0.18.1] - 2026-10-19

- **A new plan no longer freezes the game.** Working out a plan after the cache was dropped re-planned every tracked profession in one frame: 850 to 1050 ms and about 54 MB of Lua memory with five professions, measured with the client's own profiler. A replan now takes 70 to 90 ms and a few MB, with the same plans to the bit. Thanks to Mouchoir for the fix.

- **A skill-up in another skill line no longer throws away every plan.** Every weapon and defence skill-up dropped the plans, so the next redraw rebuilt them all; at low level that was every few fights. A profession's own skill-up still rebuilds that profession's plan. Thanks to Mouchoir, and to CtrlDKhayos on CurseForge for the report.

## [0.18.0] - 2026-10-19

- **The levelling route tab makes room for other profession tabs.** When another addon already uses the next tab slot, ours sits below it instead of being hidden underneath. Thanks to Bolthorr for reporting the collision.

## [0.17.0] - 2026-10-18

- **Recipe rows can show what one craft costs or earns.** *Money on recipe rows* (Settings, Recipe rows) switches the row from cost per skill-up to net per craft, and per craft also prices recipes that no longer give skill, so you can spot ones worth crafting anyway. Costs now lead with a red `-`, as profits already led with a green `+`. Thanks to trias6657 for the idea.

- More players credited: THIRD_PARTY.md now thanks SilentGentlemanSG, whose stray click on *Buy tracked reagents* led to the button asking first in 0.10.0.

## [0.16.1] - 2026-10-17

- **The tracker sections now move clear of Questie's quest list.** With Questie's tracker on, its list was drawn over the Forever sections. They now sit below Questie's list, or above or beside it when there isn't room, and follow it when it moves, grows or hides; your quest tracker keeps its own place. Thanks to deathmvp1 for the report and berserkerlxl for finding the cause.

## [0.16.0] - 2026-10-17

- **The recipe tooltip moves beside the Professions window, clear of the reagents.** It used to open next to the recipe you hovered, over the recipe's details and its reagent list. It now opens to the right of the window, past its side tabs. *Recipe tooltip position* (Settings, Recipe rows) puts it at the cursor or back next to the recipe instead. Thanks to ballara for the idea.

- **No more secret-number errors on recipe tooltips.** Hovering a recipe could raise "attempt to perform arithmetic on a secret number value" in the game's tooltip code, hundreds of times a session, blamed on SkillUp. The recipe tooltip asked that code to fit its skill bar in, and it measures the tooltip, which the game now keeps secret from addons. The tooltip now makes room for the bar itself and reads nothing back. Thanks to syrberus, kopuliak and chuujitsuna for the reports.

- **Buy reagents can always be turned off again, and no longer empties the route.** With *Buy reagents* on, a material you gather that no vendor or auction price covered (no Auctionator, or an auction house it hadn't scanned) had no price, so every recipe using it was left out of the route. When that was every recipe, the route showed nothing, and the switch disabled itself while still on, so it couldn't be unticked. Now such a material is priced as gathered, so the route keeps those recipes, and it stays on the Auctionator list and in the auction house search. The switch never disables while it's on. Thanks to kurila11478 for the report.

## [0.15.1] - 2026-10-17

- **Data checked against Forever 1.60.1.70450.** The bundled data is unchanged apart from its build pin.

## [0.15.0] - 2026-10-16

- **In your language.** SkillUp is now in German, French, Spanish (Spain and Latin America), Brazilian Portuguese, Russian, Korean and Chinese (simplified and traditional), using the game's own words for professions, trainers and reagents. It's machine translated, and corrections are welcome through the [translation form](https://github.com/cjber/skillup-forever/issues/new?template=translation.yml). A few French lines are Brainc3ll's, from Legacy Forever. Herb and ore tooltips still need the English client.

## [0.14.0] - 2026-10-16

- **A Forever addons page in settings, and a quiet line where one would help.** Without Shortest Path Forever, a waypoint tooltip (a route's trainer, vendor or quest giver, the tracker, the gear tab) now says that with it, SkillUp would pick the nearest by travel time and lead you there, in place of the old "Install Shortest Path Forever" line; where the waypoint is one fixed NPC, it says a click would lead you there. Without Adventure Guide Forever, an Artisan quest step on the route page says it can plan the quest chain, and so does the tracker's line when Questie names the quest giver. Neither line shows for an addon you have; if Shortest Path is installed but turned off, the tooltip still says to enable it. The new *Forever addons* page in SkillUp's settings lists all five addons, whether each is on, and a link to copy. *Suggest my other Forever addons* on that page turns all these lines off, the enable line included. It replaces *Suggest companion addons*, and if you had that off, it stays off.

- **The README credits the people and addons behind SkillUp Forever.** The players who reported bugs or asked for features, and Polestar, which inspired some features, are named, and THIRD_PARTY.md has the full list.

## [0.13.0] - 2026-10-16

- **Search a recipe's reagents at the auction house for as many crafts as you want.** With the auction house open, the Professions window shows *Reagents for [ ] crafts* beside *Create All*, starting at what your route plans for that recipe, and *Search* looks for the auction house reagents that many still need after your bags (and your bank, once you've opened it this session), so there's nothing to work out on a calculator. With Auctionator it searches a shopping list with the quantities (an older Auctionator searches the names without them); without it, each click puts the next reagent in the game's search box and says how many you need. Vendor reagents and ones you gather are left out, and it says so when they're all that's missing. It only searches, and *Search reagents at the auction house* turns it off. Thanks to the CurseForge player who asked.

## [0.12.0] - 2026-10-16

- **Data checked against Forever 1.60.1.70425.** The new build adds a few crafts to the gathering professions and First Aid, such as Camp Chair, Rock Garden, Greenhouse and First Aid Kit. In Alchemy, Disorienting Smog Potion is gone, Draught of Predatory Senses is now Potion of Predatory Senses, and Greater Mender's Potion now comes from a pattern and starts at 180. This build also takes out the Tinkerbox schematics and the Tinkerbox itself, so nobody can learn or make the seven Tinkerbox recipes any more, and SkillUp leaves them out of routes, suggestions and prices. Vendor sell prices changed for 72 items, mostly downwards, which changes the net cost of some crafts and which recipes a route picks.

- **First Aid and Cooking routes go to 300.** Artisan First Aid and Artisan Cooking come from a quest, not a trainer: Triage for First Aid, with one quest for each side, and Clamlette Surprise for Cooking, both at 225 and level 35. The route now adds that step, "Complete Triage at 225", points you to the quest giver, and carries on past 225 instead of stopping. The quest's name and giver come from Questie; without it the step says "the Artisan quest".

- **SkillUp lets go of the quest tracker when it has nothing to show.** To fit the Forever sections above your quests, SkillUp moves the game's quest tracker. It kept holding it there with no route tracked, *Show tracked professions* off or All Objectives collapsed. Now the tracker goes straight back to where the game, Edit Mode or your UI addon put it, and SkillUp moves it again only once a section has something to show. Thanks to chuujitsuna and another player on CurseForge, who found it stuck mid-screen or over the minimap.

- **Bronze Warhammer is trained by 110.** A player made it at 110 on Forever, where SkillUp's data still asked for Classic's 125, so routes put it off until 125. It now plans it from 110, and `/su trainers` lists it among the guesses a trainer visit confirms. Heavy Sharpening Stone (100) and Patterned Bronze Bracers (95), from the same report, were already right. Thanks to kopuliak.

- **The tracker keeps up in combat.** Collapsing All Objectives during a fight now hides the Forever sections straight away, and a route's lines update as you craft or loot instead of waiting for combat to end.

### For addon authors

- **A rank taught by a quest is a `train` step with a `questID` in `SkillUpForever.API.Professions()`.** It has no cost, and `Navigate` goes to the quest giver. The API version stays 1.

## [0.11.0] - 2026-10-15

- **First Aid and Cooking routes go past 150.** No trainer teaches Expert First Aid or Expert Cooking: you buy a book and read it at 125. The route now plans that step, "Buy and read Expert First Aid - Under Wraps at 125", with the book's price and the nearest vendor that sells it, and carries on to 225 instead of stopping at Journeyman. Artisan comes from a quest the game's data doesn't name, so routes still stop at 225 for now.

- **Herb and ore nodes show the skill they need.** Hovering a node names the Herbalism or Mining skill it asks for and colours it at your skill, orange, yellow, green or grey like a recipe, so you can see which nodes still give skill-ups. It works on English clients, and there's a setting to turn it off. Skinnable corpses show `?` for now, until someone checks that Forever kept Classic's skinning rule.

- **Check the trainer requirements SkillUp guesses with /su trainers.** Where Forever moved a recipe's colours, SkillUp moves the skill its trainer asks for by the same amount, which is right for most recipes but not all. The new command lists those guesses per profession, which ones a trainer you visited agreed with or showed differently, and which ones your trainer should teach at your current skill, so one visit settles them. Paste what it prints into an issue and the wrong ones get fixed in the data.

- **`/su report` gives you something to paste into a bug report.** It opens a small window with the text already selected: your addon and game versions, your character, your professions and where each route gets to, the audit if a profession is open, the trainer checks, your other addons and any errors SkillUp caught this session. Press Ctrl+C and paste it. It fits in one message.

- **No error from a vendor the game hides.** When the game keeps a vendor's name or ID hidden, SkillUp no longer tries to record where that vendor stands.

### For addon authors

- **A rank learned from a book is a step in `SkillUpForever.API.Professions()`.** It is a `buy` step with the book's `itemID`, its price as `cost` and the nearest vendor for `Navigate`, or, once the book is in the bags, a `train` step with the book's `itemID` and no `spellID`. The API version stays 1.

## [0.10.0] - 2026-10-15

- **Data checked against Forever 1.60.1.70374.** The bundled data is unchanged apart from its build pin.

- **Your quests stay below the Forever tracker with EllesmereUI and other UI suites.** When the game, Edit Mode or a UI addon put the quest tracker back in its saved spot, the Forever sections waited for the next quest event to restack, so your quests sat over them until then. The column now follows the quest tracker as soon as it moves, still without touching the game's own tracker code.

- **Value gathered materials at what they'd sell for.** A new Prices setting, off by default, prices a material your professions gather at its Auctionator price after the 5% cut, or its vendor sell price if that is more, instead of free. That is what crafting with it costs you, so the route picks a vendor-reagent recipe over one that burns valuable ore, and recipe rows and tooltips show the same cost. A material with neither price stays free. Thanks to berserkerlxl for the idea.

- **Not this recipe.** Right-click a step or a suggested recipe on the route page and choose *Not this recipe* to leave it out of every route on this character, as training, a sub-craft or a scroll to find. The route plans around it, or says nothing else gets there. A *Skipped* row under the route, the tracker's header menu and `/su unskip` bring a recipe back with *Show again*; `/su skipped` lists them.

- **A detached tracker with nothing to show leaves the screen.** Its "Forever tracker" title hides with the empty column and comes back, where you left it, as soon as a section has something to show.

- **A trainer that shows no skill requirement is not saved as needing none.** Such a recipe keeps the bundled requirement, and one saved as 0 by an earlier version is dropped, so the route no longer plans to learn it before you can.

- **No more secret-number errors on item tooltips.** When the game hands over an item count, sell price or tooltip item it won't let addons read, SkillUp uses the last count it saw (or the bundled price) instead of failing with "attempt to perform arithmetic on a secret number value". Before, one such read could keep failing until `/reload`.

- **The merchant's buy button asks first.** *Buy tracked reagents* now lists what it will buy and the total cost, and buys nothing until you click *Buy*. A change in your bags or route while it is open closes the question. Turn off *Show the buy button at merchants* under Route and trainer to remove the button.

- **Recipes start where Forever lets you make them.** Forever lowered many recipes' skill ranges but its data kept the old Classic starting skill on some, so Runed Copper Belt and Breastplate showed red while the game showed orange, and Heavy Sharpening Stone showed `?`. A recipe now starts at what its pattern asks, or moves down with its range, and a bundled trainer requirement moves down the same way: Heavy Sharpening Stone is trained at 100, not 125, and about 40 trainer recipes that went grey before the trainer would teach them are back in the route. A trainer's own number, once you visit, still wins (#107).

- **Retired patterns are left out.** The game still lists a few patterns nobody can get, such as *Pattern: Double-stitched Leather Gloves OLD* and *Formula: Imbue Cloak - Protection*. SkillUp no longer offers them as a recipe's scroll or takes their skill as where a recipe starts, so Guardian Cloak starts at 160, what its real pattern asks, and Enchant Cloak - Minor Protection, Enchant Boots - Minor Stamina and Goblin Rocket Boots are learned from their trainers.

## [0.9.3] - 2026-10-13

- **Data checked against Forever 1.60.1.70338.** The bundled data is unchanged apart from its build pin.

- **Tracker stays put when Edit Mode places it by its centre or bottom.** Attaching to the quest tracker no longer pushes it down the screen when it has been moved away from the default top-anchored spot.

- **How the Forever addons work together.** The README and store page list each of the other Forever addons and what it adds when installed alongside this one.

## [0.9.2] - 2026-10-09

- **Latest Auctionator prices.** Reagents and crafted items use Auctionator's latest recorded price. Scan with Auctionator to update prices; SkillUp no longer stores or averages daily prices.

## [0.9.1] - 2026-10-09

- **Recipe thresholds** use one pinned Forever client build, with no older Classic overrides. Contradictory difficulty ranges show unknown and are excluded from plans. Trainer recommendations respect learning requirements separately.

- **Latest Auctionator price option.** A new Prices setting prices reagents and crafted items at Auctionator's latest price instead of the median of the last seven days. The median stays the default.

- **Keep Blizzard's tracker methods intact.** The shared Forever tracker responds to objective and player events without wrapping native layout methods.

## [0.9.0] - 2026-10-08

- **Shorter addon descriptions.** The README and store pages explain the features directly and keep the author and licence credits.

- **Quest text stays on screen when the Forever tracker is smaller.** The native quest column and its header keep their full width at the edge of the screen.

- **Hide tracked professions without losing your route.** Turn off *Show tracked professions* to remove SkillUp from the objective tracker. Your tracked professions and target levels are kept.

- **Shared tracker scaling.** SkillUp follows the tracker scale selected in Shortest Path Forever.

## [0.8.4] - 2026-10-07

- **Quest objectives stay below the Forever tracker after reload.** The shared tracker no longer resizes Blizzard's quest container, which could move it over the addon sections.

## [0.8.3] - 2026-10-07

- **Data checked against Forever 1.60.1.70245.** The bundled game data is unchanged.

## [0.8.2] - 2026-10-06

- **Current profession data.** Recipe, trainer and threshold data are refreshed for Forever build 1.60.1.70235.

## [0.8.1] - 2026-10-05

- **The tooltip's skill bar keeps the game's own shape.** The bar under a recipe's tooltip was drawn narrower than the profession window's bar it copies, which squashed its end caps. It is drawn at the game's proportions, a little slimmer than before.

## [0.8.0] - 2026-10-05

- **The route reads the game's own recipe numbers and crafts what it can make cheaper.** A recipe's grey threshold now comes from the client where it reports one, with the bundled yellow and green kept under it, so the chance a row shows matches what the profession window implies. A craft that grants several skill points is counted and priced for every point, so the route asks for fewer crafts where the client says so. When a reagent is made by a recipe you know and crafting it beats buying, it becomes its own step before the craft that needs it (for example *Craft 3 Cured Light Hide*) and the shopping list names the raw materials it is made from, followed three levels deep and never through a cycle. Recipes also report the tool and station they need from the client: a step names where it is made, and a tool you are not carrying disables *Craft next* with the reason and joins the shopping list once. Reading a profession's recipe list now happens once per burst of window events instead of once per event.
- **The tracker returns after Edit Mode is locked.** Hiding and locking Edit Mode without leaving it no longer keeps the Forever sections hidden.
- **The tracker reads in game order.** The game's All Objectives header leads the shared column, the Forever sections follow it, and your quests stay below them. In combat the game keeps its quest list in its own slot, so the header and quests stay together and the Forever sections sit directly below them, keeping the tracker to one column.
- **The route asks for enough crafts to cover bad luck.** A yellow or green recipe does not give a skill-up every craft, and the route counted the average, so a run could end a point short with no reagents left. Each step now asks for the crafts that reach its target in nine runs out of ten, worked out from the chance at each skill point on the way, and a recipe with a low chance carries that risk in its price so the route leans on it less. An orange recipe is unchanged. The page, the craft button, the reagent list and the tracker redraw as you craft and as your skill rises, so a lucky run shrinks what is left and an unlucky one grows it. A step that cannot be crafted names the reagent and how many more are needed, and hovering *Craft* says what a click makes, how many the bags allow now, and that a worse run may need more.
- **The bottom row of the route page no longer overlaps.** *Craft* and *Nearest vendor* sat under the route and could meet when the craft label was long. They now share one bottom row with *Track* and stay clear of each other whatever the label says.
- **Auctionator's shopping list keeps itself up to date.** The *To Auctionator* button and the tracker menu's *Send missing to Auctionator* are gone. With Auctionator installed and the route set to buy rather than gather, the addon keeps its *SkillUp: <profession>* list in step with what the route still needs, leaves it alone while nothing changed, empties it once the bags cover the need, and names the list in the reagent list. When a price is missing or old and Auctionator's own scan-when-the-auction-house-opens option is off, the page says where to turn it on (Auctionator, Basic Options).
- **No false "can't identify the profession" message.** Learning a recipe with no profession window open printed "can't identify the profession (0); please report it." That line now appears only for a real profession the addon does not know.
- **The data matches client build 1.60.1.70205.** In this build Winter Boots and the ten camp furnishings (Incense Candle, Greenhouse, Fish Bowl, Fishing Rack, Camp Chair, Field Guide, First Aid Kit, Toxin Study, Lodestone and Rock Garden) no longer give skill-ups, so they show `?` in place of a chance and routes leave them out. Eight wands, from Lesser Magic Wand to Greater Eternal Wand, now sell to a vendor for 1 copper, so crafting one nets a higher cost.
- **A vendor reagent's tooltip gains its vendor line when the read finishes.** The first hover of a reagent sold by a vendor showed no *Nearest vendor* line while the addon was still reading who sells it, and kept the tooltip without it until the next hover. The row now draws its tooltip again once that read has finished.
- **Tracking starts when you open the profession you are levelling.** Opening a profession's window, or a trainer that teaches it, now tracks it on its own when its route still has steps, so the tracker, the next training step and the waypoint to where to train are there without pressing *Track*. A profession you stop tracking by hand stays stopped until you start it again.
- **One click to the vendor for the reagents your route still buys.** The route page now has a *Nearest vendor* button that sets a waypoint to the closest vendor selling any of the route's missing vendor reagents, instead of a trip through each reagent's line.
- **A crafted gear view, off until you want it.** A *Gear* tab on the Professions window, turned on in settings, draws your character sheet a second time: one item slot down each side and the weapon slots along the bottom, each showing the newest crafted item this character could equip for it, in the game's own empty-slot art, quality border and known mark. The pane in the middle names the pick, its level and type, the profession and the skill its recipe is learned at, its state, its reagents with how many you have, and one button that opens a recipe you know or sets a waypoint to where one you can learn is taught; *Also for this slot* lists the slot's other picks. By default it holds only what the character can make now; a *Show gear I cannot make yet* switch in the header adds the rest and is saved per character. An item the class cannot wear, a weapon whose skill this character has not trained, an item whose own profession rank is above the character's, and an item a use consumes are all left out. Within a slot the newest required level comes first, then the higher skill, then the name. The skill shown is the pattern's own requirement, not the client's placeholder orange of 1, so a Forever-added hood reads `Leatherworking, 100` where it used to read `1`, and a recipe whose source the data does not know says its source is unknown instead of naming a skill. It names the newest thing craftable for a slot, not a best-in-slot list.
- **Choose gathering or buying from the route itself.** A *Buy reagents* switch on the route page decides whether a reagent another of your professions could gather is free to gather or bought and priced at a vendor or the auction house. It is saved per character and no longer hides in the settings. When the route has nothing your professions gather, the switch is disabled and its tooltip says so.
- **The route page is drawn the game's way.** The *Route* and *Reagents  (have / need)* lists are now rows like the window's own items: a full-size icon in its stock border, the name beside it and, underneath, what the row is about, such as `18 crafts to 66, +27s` or `gather, 23/200`. Headings, totals and the auction-price note use the game's own fonts at their normal size, and the lists scroll with its own scroll box. The *Buy reagents* switch sits in the header and *Nearest vendor* in the bottom row, so nothing is drawn under a heading.
- **Prices come from a median of recent scans, and an unpriced reagent is called out.** Auction prices were Auctionator's single last listing, so one cheap auction moved the whole route. The addon now keeps each item's lowest buyout for the last seven days and prices from the middle of those days, saying on the page how many days that is, and a vendor price still wins when it is cheaper. A reagent nobody has priced is unknown, not free: its recipes are left out of the route, the route is marked incomplete and the reagent is named in the reagent list. A vendor whose window you open now carries the client build you saw it on and stops being named once two builds have gone by without seeing it, though nothing is deleted.
- **The route lists keep their own rows.** The *Route* and *Reagents  (have / need)* lists now draw into the game's scroll box list, which keeps a pool of row frames and lays out only the ones on screen. The rows look and behave as before; the addon no longer hides frames by hand as a list redraws, so scrolling stays smooth while a route refreshes.

## [0.7.1] - 2026-10-04

- **An AtlasLoot that is switched off is no longer called missing.** With AtlasLoot installed but not running, because it is unticked or held back as out of date, the route said to install it. It now says to enable it in the AddOns list, or to update it.
- **A suggested recipe's source can be read.** Where the route stops, each recipe scroll's row ran its source into its name and cut it short, so *vendor*, *quest* and *drop* all read as a few letters. The source now sits whole beside the columns and a long name is the part that is shortened.
- **A vendor inside the other faction's capital is not yours.** The holiday vendors stand in every capital and count as friendly to both sides, so an Alliance character could be sent to one in Thunder Bluff. A vendor or trainer inside a capital city now counts as that city's side only: it is shown in red in a scroll's tooltip and never gets the waypoint.
- **A long list of sellers fits on the screen.** A scroll sold by many vendors listed every one and its tooltip ran past the bottom of the screen. It now lists four, starting with the one a click takes you to and then the nearest you can buy from, and counts the rest.
- **A route row's tooltip is whole on the first hover.** The first time you hovered a recipe or reagent on the route page after logging in, its tooltip showed the item and none of the route's own lines, such as *Requires*, *Sold by* and the click hints; they only appeared on a second hover. The game was redrawing the item once its details arrived, and the row now draws its lines again when that happens. Pressing Shift over a row dropped them the same way, and no longer does.
- **A scroll's tooltip names it once.** Under the crafted item's own tooltip the route repeated the item's name. The name is now added only when the recipe is called something else, as with *Train* steps.

## [0.7.0] - 2026-10-03

- **A vendor you have bought from is the one a step names.** Standing at a vendor Questie does not know, the buy step still sent you to one it did. Opening a merchant's window now notes which of your reagents and recipe scrolls that vendor sells and where you stood, so from then on the step, its tooltip and its waypoint use that vendor whenever it is the nearest, with or without Questie.
- **A far vendor is no longer called the nearest.** With every known vendor or trainer on another continent, or with you inside a dungeon, the route picked whichever came first in its data and showed it as the nearest. Now a step names one only when it can tell which is nearest: by distance on your continent, by Shortest Path Forever's travel time when you hover or click, or because there is only one. Otherwise it reads *Vendor* or the trainer's profession, with no waypoint.
- **A detached tracker keeps clear of your quests.** With Attach to quest tracker off, the Forever column could open on top of the quest list. Until you drag it, it now sits beside the quest tracker, level with its top; once dragged, it stays where you put it.
- **Recipe sources, vendors and trainers come from Questie and AtlasLoot.** Where a recipe's scroll is sold, which quest rewards it, who sells a reagent and where a trainer stands are now read from the Questie and AtlasLoot you have installed, so they follow those addons as they are corrected for Forever. Both are optional: without AtlasLoot the route cannot tell which scroll teaches which recipe, and without Questie it names no vendor, quest or trainer and sets no waypoint to one. One line where the route stops, and in a step's tooltip, says which to install. Everything else works as before.
- **A scroll's price is the one you have seen.** The route showed a recipe scroll's classic vendor price and ranked vendors with limited stock after the others. Neither is known for Forever, so a scroll now shows what it cost at the auction house or at a merchant's window you have opened, `?` until then, and every vendor of your faction counts the same.
- **A rank's fee is the one your trainer quotes.** The route's *Train Journeyman*, *Expert* and *Artisan* steps always showed the classic base fee, even after a trainer had shown you a different one. Once you have opened a trainer who still offers the rank, the route and its total use the fee that trainer charges you.

## [0.6.11] - 2026-10-03

- **Trainer fees and level-ups reach the route at once.** After a trainer's fees were recorded, or after you gained a level, the route page and the tracked reagents kept showing the old plan until something else refreshed them. They now update straight away.
- **/su no longer raises an error after an incomplete update.** When the addon asked for a game restart because files were missing, typing /su or clicking its minimap menu entry raised a Lua error. It now does nothing until the restart.
- **Buy tracked reagents can't order twice.** Clicking the merchant button again before the reagents reached your bags bought them all a second time. The button now greys out until the purchase arrives, and comes back after a moment if the merchant refuses it, for instance when your bags are full.
- **Boss drop chances for recipes are worked out the way bosses roll their loot.** The glove and cloak enchanting formulas from Ahn'Qiraj showed 14% from the Ruins bosses; they are about 1% a boss, best from the Temple. Plans and patterns from Azuregos, Kazzak and Onyxia showed 1.3% and are nearer 3%, since those bosses roll that loot more than once.

## [0.6.10] - 2026-10-02

- **A newly learned recipe joins the route at once.** Learning a recipe, or opening a profession, now re-plans the route and the tracked reagents straight away; before, they could keep the old plan until the recipe list next updated.
- **The guides stay put in a fight.** In combat the game stretches its quest tracker and nudges it back on screen, which shoved the Forever sections sideways across the screen until the fight ended. They now stay stacked above the quest list.
- **The what's-new setting fits the settings panel.** Its name was cut off with an ellipsis; it now reads *What's new after an update*.

## [0.6.9] - 2026-10-01

- **Keep guides clear of quests in combat.** Companion sections stay clear when the quest list grows during a fight. Detaching restores the quest tracker’s original Edit Mode position.

## [0.6.8] - 2026-09-30

- **Move the shared tracker.** Turn off Attach to quest tracker in Settings to drag all Forever sections together. The position survives `/reload`.

- **Keep the source easy to audit.** Core logic, integrations and UI now live in matching folders; the shipped load order and player-facing behaviour are unchanged.

## [0.6.7] - 2026-09-30

- **Development disclosure.** This release was developed with AI assistance. Changes were reviewed and checked with automated tests, linting and type checks; live verification remains ongoing.

- **Settings are grouped into subpages.** *Recipe rows*, *Prices*, *Route and trainer*, *Tooltips and sorting* and *Addon* each open from a short index, so no single page runs long. Saved choices, defaults and tooltips are kept.

- **Choose settings without opening a menu.** Craft prices, reagent tooltips and recipe sorting use labelled sliders, avoiding the native dropdown path implicated in a Forever client crash. Your saved choices and recipe-list sorting stay in sync.

- **Keep tracker sections apart in combat.** Companion sections move above the protected quest tracker while fighting, then return to one column afterward, regardless of which addon loads first.

## [0.6.6] - 2026-09-29

- **Keep one tracker column.** Addon sections stack above the quest tracker regardless of which companion addon loads first, while keeping their frame pools separate from Blizzard's tracker.

## [0.6.5] - 2026-09-28

- **Separate addon tracking from Blizzard’s layout.** Addon sections now use their own frame pools and sit beside the quest tracker, avoiding the shared tracker registration implicated in Edit Mode aura errors.
- **Check the client integration in CI.** Regression checks run against pinned Forever tracker source and reject native tracker registration.

## [0.6.4] - 2026-09-27

- **Recipe sorting and shopping tracking use native callbacks and load events.** They no longer hook Blizzard object methods; lifecycle regressions and release checks guard these integrations.

## [0.6.3] - 2026-09-27

- **Profession tab updates stay separate from Blizzard's methods.** The route tab follows skill changes and window events without hooking the profession frame's tab refresh functions. This fixes the fishing skill-up error confirmed on the Forever beta.

## [0.6.2] - 2026-09-27

- **A craft whose sell price isn't known yet shows no cost** instead of the full reagent cost, and the route leaves it out until the price loads. It used to count the craft as selling for nothing, then change its mind.
- **A vendor that doesn't say how many come in a stack no longer overwrites a price.** The addon keeps the last unit price it saw rather than guessing the stack is one.
- **A saved setting the menu no longer offers goes back to its default.** A bad *Count what crafts sell for* or *Sort recipes* value used to stick, quietly acting like vendor price or no sort.
- **A recipe suggestion with no known scroll price shows `?`** instead of an empty cost.
- **The trainer's pick no longer runs into the *Requires:* line.** The recipe to train next now gets the green arrow your bags put on an upgrade instead of the words *Best next*, and a row's chance and cost end in `...` rather than write over the requirement.
- **The cost setting's tooltip says where prices come from**: common vendor reagents priced from the start, reagents you gather free, auction prices from Auctionator.

## [0.6.1] - 2026-09-27

- **The route no longer charges for a rank it never gets to.** When your known recipes ran out before the target, the total still had the next rank's fee in it, though the route stopped short of needing it.
- **Rank training comes where you can do it.** A craft that ran through your cap from below the skill the trainer asks for (First Aid from 40 to 90, say) put *Train Journeyman at 50* before it. The craft is now split at 50, with the training in between.
- **Recipe suggestions show up when your only unpriced recipe is grey.** A grey recipe with no price made the route tab ask for Auctionator instead of listing the scrolls that would carry you on.
- **Unpriced reagents on the route tab get their names** instead of staying as *item 1234* until something else loaded them.
- **The tracker's next training step matches the route tab.** It sorted ranks and recipes by skill on its own, so it could send you to a different trainer than the route does.
- **The tracker says why a route is stuck**, like the route tab does, instead of *Reagents in hand* when nothing you know can be priced or skill up.
- **Tracking or untracking a profession reorders it in Adventure Guide Forever straight away**, not after your next bag change.

## [0.6.0] - 2026-09-25

- **Ready for translation.** Every line SkillUp writes, from recipe tooltips to the route tab and tracker, can now be translated: send a file for your language as a pull request, or paste it into an issue, on [GitHub](https://github.com/cjber/skillup-forever/tree/main/Locales). Rank names, *Default*, *Off* and *Total* already use the game's own words, so they follow your client's language now. English is unchanged.
- **A line in chat after an update says what's new**, once, the first time the new version loads. A fresh install stays quiet, and *Tell me what's new after an update* in settings turns it off.
- **Waypoint tooltips mention Shortest Path Forever when it isn't running.** Trainer, vendor and recipe-source tooltips add a grey line saying to install it, or enable it if it's turned off, for walked routes and boat times. *Suggest companion addons* in settings hides the line.

## [0.5.0] - 2026-09-25

- **Other addons can show your profession progress.** `SkillUpForever.API` hands out each profession's next three steps, next recipes and reagents from the same plan as the levelling route tab, so Adventure Guide Forever can draw them in its Professions tab.
- **Auction prices now come from [Auctionator](https://www.curseforge.com/wow/addons/auctionator).** SkillUp no longer scans the auction house itself: opening it no longer sends searches, and `/su scan` and the *Scan the auction house* setting are gone. With Auctionator installed its prices are used as before; without it, reagents you can only buy at the auction house show no cost, and the tooltips say *Auction prices need Auctionator*. Vendor prices, reputation discounts and the crafted-item sale option are unchanged. Old scanned prices are cleared from your saved settings.

## [0.4.1] - 2026-09-25

Updated for Forever build 1.60.1.70009.

- **Four Leatherworking recipes cost less**, among them Cloudy Gustwoven Trousers: Forever no longer lists Spider Silk Slippers among their reagents, so the cost per skill-up leaves them out.
- **Linen Reagent Bag sells to a vendor for 2s**, down from 50s, as in the game.
- **Potion of Demon Slaying, Potion of Beast Slaying and Potion of Elemental Purging** carry their new names, and the six Spiritcaller pieces follow the game's reshuffle of their recipes.

## [0.4.0] - 2026-09-25

Getting there quicker: waypoints and nearest picks through Shortest Path Forever, clickable tracker
lines, and a round of fixes to prices and the route.

- **Waypoints go through [Shortest Path Forever](https://www.curseforge.com/wow/addons/shortest-path-forever)** when it is installed: clicking a trainer, vendor or reagent like Coarse Thread starts its travel route there. When it can't (in combat, or with its journeys off), TomTom's arrow or the map's own waypoint is set as before.
- **The nearest trainer or vendor is the quickest to reach** with Shortest Path Forever installed: tooltips and clicks rank the closest few by its travel time, flights and boats included, instead of a straight line.
- **Click a tracker line for a waypoint**: the next training step goes to the nearest trainer, and a missing vendor reagent like `12/20 Coarse Thread` to the nearest vendor. Hover the line to see who and where.
- **Your own auction house searches no longer wipe scanned prices.** One that found nothing used to clear them; only SkillUp's own searches now mark an item as unlisted.
- **Free recipes show as free.** One made only from reagents you gather used to show a cost of 1c per skill-up.
- **No more error on `/reload` right after an update.** It used to fire before the "restart the game" message could show.
- **The Craft button stops at your skill cap.** It used to offer crafts past it; now it stops where skill-ups do, until you train the next rank.
- **A scan you walk away from still counts.** Prices from an auction house scan left mid-way used to stay hidden until something else changed.
- **A recipe with no reagent data shows `?`.** It used to count as free.
- **A newer scan beats an old Auctionator price.** When the scan found nobody selling the item, the older Auctionator price used to win.
- **Searching the game's settings no longer blames SkillUp** for a blocked button (Social's Discord Sign In).
- **Hovering some items no longer errors.** An item whose tooltip hid its id tripped a check before the guard for it ran; recipe tooltips had the same fault.
- **Trainer steps in the route** read the same as elsewhere, with one space before "(level N)".
- **The sort setting's tooltip** now says that sorting puts every recipe in one list, and Default restores categories.
- **Thresholds, recipes, trainers and prices are updated** for Forever build 1.60.1.69977.

## [0.3.0] - 2026-09-21

Where to go next, not just what each recipe costs: a route to your target, what to buy for it, and what to
train.

- **A levelling route page on the Professions window**, for any of your professions. Type a target skill
  and it lists the cheapest crafts, training recipes where the fee pays for itself, like `12× Heavy Linen Bandage to 90`, each with its cost, and the total. Every
  skill point takes whichever recipe has the lowest cost per skill-up at that point. Recipes with an
  unpriced reagent are left out and counted rather than treated as free, and a route that runs out of
  recipes stops and says where. Hover any step or reagent for details (click a step to open its recipe),
  and the page shows how old its auction prices are.
  The target can pass your current cap: the route adds each rank to train on the way, with its fee,
  the skill the trainer wants and the level it needs.
  When the recipes you know run out, the route lists the scrolls that would carry it on, from vendors,
  quests and drops, easiest to get first, with every source's zone and coordinates; click one for a
  waypoint to the nearest vendor or the likeliest drop (TomTom's arrow when installed).
  Training steps and vendor reagents show the nearest trainer or vendor of your faction, and a click
  (or the tracker's menu) sets a waypoint there.
- **Craft the next step in one click**: a button under the route (and the tracker's menu) crafts the
  route's first step as many times as it needs and your bags allow, while that profession is open.
- **Gather it yourself.** Reagents another of your professions gathers (Light Leather with Skinning, ore
  with Mining, herbs with Herbalism) count as free, so the route uses them and the shopping list says to
  gather them; turn it off in the settings to price them at market. With Syndicator installed, reagent
  tooltips show what your other characters hold.
- **A shopping list from the route.** The page lists every reagent the route needs against what's in your
  bags and bank. Track it to see the next thing to train and the reagents still missing in the objective tracker, above your quests; at a vendor, one button on the
  merchant window buys the missing reagents that vendor sells. With Auctionator installed, the auction house
  reagents still missing become an Auctionator shopping list.
- **The profession trainer shows the same numbers** as recipe rows, and marks the recipe that most cheapens
  or extends your route, training fee included, as `Best next` (closes #2).
- **Reagent tooltips say what your routes need.** Hovering an item shows how much of it each tracked route
  needs, like `Route: 28/567 · Leatherworking to 150`; hold Shift for every recipe of yours that uses it
  and still skills up, with its colour now, like `yellow until 115`. A setting shows that full list
  always, or turns the section off.
- **Recipes you haven't opened can be priced.** Ones you haven't opened in the Professions window now have reagents
  and crafted items from the game's data, so the trainer and tooltips can price them.

## [0.2.0] - 2026-09-21

What a skill-up costs, so the cheapest way to level is on the screen next to the chance of getting one.

- **Every recipe row shows its cost per skill-up.** That is the reagents, less what the crafted item sells
  for, divided by the chance of a skill-up, so a yellow recipe at 50% costs twice its reagents per point.
  It is shown in coin icons after the chance. A skill-up that makes money shows a green +.
- **The tooltip shows where the number comes from.** Each reagent is listed with its price and its source
  (a vendor, the auction house and how long ago, or Auctionator), then what the craft sells for, the net
  cost of one craft and the cost or profit per skill-up. A recipe with any unpriced reagent shows no cost
  rather than one that looks cheap because part of it is missing, and says how to price it.
- **Prices are gathered as you play.** About 50 common vendor supplies (thread, vials, flux, dyes, spices)
  are priced from the start from the game's own data. A vendor you visit updates its prices, reputation
  discount included. Opening the auction house searches it for the reagents and crafts of every profession
  you have opened, at most once an hour (`/su scan` forces it), and your own searches update prices too.
  Auctionator's prices fill anything not scanned.
- **What a craft sells for counts.** By default its vendor price comes off the cost; a setting can use its
  auction price instead when that is higher, after the 5% cut, or leave it out.
- **Sorting is in the Filter menu, and now does something.** A *Sort by* section at the bottom of the recipe
  list's own Filter menu offers required skill, skill-up chance and the new *Cheapest skill-up*. Forever's
  categories hold one or two recipes each, so the old sort inside each category never visibly changed the
  list; a sort now lists every recipe in one ordered list, learned first, then unlearned. *Default* brings
  the categories back.
- **Rows lead with the chance.** The required skill is now a setting and off by default. A recipe you can't
  make yet still shows it in red, since it is the one number that matters there.

## [0.1.0] - 2026-09-21

First release.

- **Every recipe row shows the skill it needs and your skill-up chance**, coloured by difficulty.
- **The recipe tooltip shows the orange / yellow / green / grey thresholds** on a bar with your skill marked. The bar
  is the Professions window's own header bar and the marker is Forever's rested pip, so it looks like part of the
  window. Settings turn the row text or the tooltip off.
- **Recipes can be sorted within each category** by required skill or by skill-up chance.
- **`/su audit` checks the bundled data** against the colours the game shows.
- **Thresholds for 2,356 recipes** from Forever build 1.60.1.69913.
