SkillUp Forever shows skill-up chances, recipe costs and colour thresholds in the Professions window. Its side panel has levelling routes, shopping lists, crafted gear and the buffs each profession makes.

Free, with nothing locked behind it. If it saves you time, you can [sponsor me on GitHub](https://github.com/sponsors/cjber), which takes no fees, or [buy me a coffee on Ko-fi](https://ko-fi.com/cjber).

![Leatherworking levelling from 48 to 60](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/demo.gif)

From 48 to 60 the rows re-sort by cost per skill-up, and the bracers turn green at 55.

![The Leatherworking window with skill-up chance and cost per skill-up on each row](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/window.png)

Chance and cost, right in the window's own rows.

![Recipe tooltip with thresholds, reagent prices and cost per skill-up](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/tooltip.png)

Colour thresholds and reagent prices for the recipe you hover.

![The SkillUp route tab with training and crafting steps and the reagents they need](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/route.png)

The route tab from 48 to 73: what to train, what to craft and where reagents come from.

![The Crafted gear tab with item slots down both sides and along the bottom, each showing the newest crafted item, and one slot's recipe, reagents and status in the middle](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/gear.png)

The gear tab, turned on in settings: each slot shows the newest thing this character could craft for it.

![The Buffs tab with the Cooking buff timeline scrolled to the next rank, column skill numbers, the rank divider, the legend, and the selected buff's words, source and reagents](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/buffs.png)

The buffs tab: what each profession can make for your level, in columns on a skill timeline.

![The objective tracker with the route's next training step and missing reagents](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/tracker.png)

Track it and the route sits beside your quests.

![A Leatherworking trainer's recipes with skill-up chance, cost and a green arrow on the one that best helps the route](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/trainer.png)

At the trainer, a green arrow marks the recipe that best extends or cheapens your route.

![Light Leather's tooltip with how much the tracked route needs](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/reagent.png)

Hover a reagent to see how much your routes need.

## Features

- **Recipe rows and tooltips** show skill-up chance, cost and colour thresholds.
- **A wide recipe list** grows to the longest recipe name in the open profession, with how many your bags can make in parentheses after each name. The window grows with it, up to the room your screen has. Turn it off in settings to keep the game's own width.
- **Unlearned recipes** can sit under the learned ones in the same list. A setting, off by default, greys them and marks each with its trainer or recipe item and the skill it asks, and hovering one shows its reagents, cost and skill-up colours like a learned recipe's. They cannot be selected or crafted.
- **Sorting** orders recipes by difficulty range start, chance, cheapest skill-ups or newest learned first.
- **Levelling routes** list crafts, trainer visits, skill books and rank quests to your target skill, including fees, tools and stations. Steps allow for unlucky skill-ups. Cheaper crafted reagents become their own steps; routes that stop short name recipes that could extend them. Right-click a recipe and choose *Not this recipe* to plan without it.
- **Shopping lists** count reagents against bags and bank. Choose whether gathered materials are free or bought, track them beside quests, buy vendor stock and keep an Auctionator list up to date. At the auction house, search a recipe's reagents for as many crafts as you choose.
- **Trainer annotations** mark the best recipe to train next. Reagent tooltips show what tracked routes need.
- **Gathering nodes** show the Herbalism or Mining skill they need, coloured at yours, on English clients.
- **Crafted gear** shows the newest craft for each slot, with its recipe, reagents and learning location. Enable its tab in settings.
- **Buffs** show what each profession can make for your level, on a skill timeline: known buffs, the ones you can learn now, and the ones still ahead. Pick the profession from the page's own dropdown, including crafters you do not have.
- **Forever Leaderboards** rank the distinct recipes SkillUp has observed as learned on your character against guild and group totals, for this week or all time, in the shared window every Forever addon uses. The window also shows the overall standing across installed Forever addons and puts a player's place in the unit tooltip.

## Prices

Each reagent uses the cheapest known vendor or Auctionator price; visiting a vendor records its prices and reputation discounts. Materials your professions gather count as free until you choose *Buy reagents*, or cost what they'd sell for with *Value gathered materials at what they'd sell for* on. *Price self-supplied reagents at auction values* prices whatever you gather, loot or already own at its market value, and leaves it unpriced rather than free when there is none.

SkillUp never scans the auction house itself: scan with Auctionator to update prices. Missing prices stay unknown and leave affected recipes out of the route.

A craft's vendor sell value comes off its cost, or its auction value after the 5% cut if you choose. Profit shows a green `+`.

## Usage

Open a profession and the numbers are already there.

- `/su` opens the settings (also in Settings > AddOns and the minimap's addon compartment).
- `/su skipped` lists the recipes you said *Not this recipe* to, and `/su unskip <ID>` (or `all`) brings them back.
- `/su leaderboard` opens the Forever Leaderboards window on SkillUp's tab (also `/su stats`).
- `/su share on|off` controls sharing with your guild and group. Sharing is on by default, and the window's Share my progress switch and the settings checkbox turn it off.
- `/su audit`, with a profession open, prints where the bundled thresholds differ from the colours the game shows.
- `/su report` shows a report to copy into a bug report.
- `/su issue` opens a ready-made GitHub issue link to report a bug or request a feature.
- `/su trainers` lists the trainer skill requirements SkillUp guessed and which ones a trainer has confirmed.

Missing data shows `?`. Settings cover rows and tooltips, the recipe list's width, prices, the route, gear and buffs tabs, trainer annotations, sorting, reagent tooltips and Forever addon hints.

<!-- forever-family:start -->

## The Forever addons

Each one works on its own, and they work together when you install more than one.

| Addon | What it does | Issues |
|---|---|---|
| [Shortest Path Forever](https://www.curseforge.com/wow/addons/shortest-path-forever) | Plans journeys on foot, by air, by sea and through portals, with directions in the tracker. | [Issues](https://github.com/cjber/shortest-path-forever/issues) |
| [Adventure Guide Forever](https://www.curseforge.com/wow/addons/adventure-guide-forever) | Suggests quests for your level and routes you from one to the next. | [Issues](https://github.com/cjber/adventure-guide-forever/issues) |
| [SkillUp Forever](https://www.curseforge.com/wow/addons/skillup-forever) | Shows skill-up chances, recipe costs and levelling routes in the Professions window. | [Issues](https://github.com/cjber/skillup-forever/issues) |
| [Legacy Forever](https://www.curseforge.com/wow/addons/legacy-forever) | Shows your unfinished Legacy challenges on the world map and tracks the ones you choose. | [Issues](https://github.com/cjber/legacy-forever/issues) |
| [Tweaks Forever](https://www.curseforge.com/wow/addons/tweaks-forever) | Adds quest automation, rare alerts and merchant options to the game's settings. | [Issues](https://github.com/cjber/tweaks-forever/issues) |
| [Field Guide Forever](https://www.curseforge.com/wow/addons/field-guide-forever) | Keeps a cosmetic journal of the creatures you kill, zone by zone. | [Issues](https://github.com/cjber/field-guide-forever/issues) |

Bug reports, feature requests and pull requests are welcome on each addon's GitHub. Everyone whose report or idea ships is thanked by name in the addon's credits and changelog.

For help, ideas and each day's release notes, join [cjber's Workshop on Discord](https://discord.gg/FpHugGxRJY).

<!-- forever-family:end -->

With [Shortest Path Forever](https://www.curseforge.com/wow/addons/shortest-path-forever), clicking a trainer or vendor in the route plans the trip there, and SkillUp picks the nearest one by travel time. [Adventure Guide Forever](https://www.curseforge.com/wow/addons/adventure-guide-forever) shows each profession's next steps in its Professions tab. A tracked route shares one tracker column with the Shortest Path, Adventure Guide and Legacy Forever sections, above your quests.

Translated into German, French, Spanish, Brazilian Portuguese, Russian, Korean and Chinese (machine translated; corrections welcome through the [translation form](https://github.com/cjber/skillup-forever/issues/new?template=translation.yml)).

Source: [github.com/cjber/skillup-forever](https://github.com/cjber/skillup-forever), GPL-3.0-or-later.

Built with AI assistance.

[![Sponsor me on GitHub](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/github-sponsors-button.png)](https://github.com/sponsors/cjber) [![Support me on Ko-fi](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/kofi-button.png)](https://ko-fi.com/cjber)
