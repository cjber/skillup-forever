SkillUp Forever puts skill-up chances, recipe costs and colour thresholds into the Professions window's own rows and tooltips, with a levelling route and shopping list in a side panel. Nothing new to learn: it looks like it came with the game.

![Leatherworking levelling from 48 to 60](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/demo.gif)

From 48 to 60 the rows re-sort by cost per skill-up, and the bracers turn green at 55.

![The Leatherworking window with skill-up chance and cost per skill-up on each row](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/window.png)

Chance and cost, right in the window's own rows.

![Recipe tooltip with thresholds, reagent prices and cost per skill-up](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/tooltip.png)

Colour thresholds and reagent prices for the recipe you hover.

![The SkillUp route tab with training and crafting steps and the reagents they need](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/route.png)

The route tab from 48 to 73: what to train, what to craft and where reagents come from.

![The objective tracker with the route's next training step and missing reagents](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/tracker.png)

Track it and the route sits beside your quests.

![A Leatherworking trainer's recipes with skill-up chance, cost and a green arrow on the one to train next](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/trainer.png)

At the trainer, a green arrow marks the one to train next.

![Light Leather's tooltip with how much the tracked route needs](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/reagent.png)

Hover a reagent to see how much your routes need.

## Features

- **Recipe rows and tooltips** show skill-up chance and cost, such as `62% · 45s`, plus orange, yellow, green and grey thresholds and reagent prices. Required skill is optional.
- **Sorting** by required skill, chance or cheapest skill-up puts recipes in one list. *Default* restores categories; the game's filters still apply.
- **Levelling route** plans crafts towards your target skill, with trainer recipes and rank fees. If a route stops short, it lists vendor, quest and drop recipes that could extend it. Waypoints cover trainers and suppliers, via Shortest Path Forever or TomTom.
- **Shopping list** counts reagents against your bags and bank. Track it beside your quests, buy what a vendor sells, or send auction reagents to an Auctionator list. Syndicator shows what your other characters hold.
- **Profession trainer** shows chance and cost beside recipes, with a green arrow on the best one to train next.
- **Reagent tooltips** show what tracked routes need; hold Shift for every recipe of your professions that uses the item and still skills up.

## Prices

- Common vendor supplies have bundled prices; visiting vendors records their prices, including reputation discounts.
- Auction prices need [Auctionator](https://www.curseforge.com/wow/addons/auctionator); SkillUp uses its prices and never scans the auction house itself. Without it, reagents only sold at the auction house have no price.
- Reagents your professions gather count as free by default.

Each reagent uses the cheaper known vendor or auction price, and the craft's vendor sell value comes off its cost by default. You can choose its auction value when higher, after the 5% cut. Profit shows a green `+`; unpriced recipes show no cost and are left out of routes.

## Usage

Open a profession and the numbers are already there.

- `/su` opens the settings (also in Settings > AddOns, or from the addon compartment on the minimap).
- `/su audit`, with a profession open, compares the bundled thresholds with the colours the game shows and prints any mismatch.

Thresholds come from the Forever client's recipe data; missing data shows `?`.

It also works with my other Forever addons: [Shortest Path Forever](https://www.curseforge.com/wow/addons/shortest-path-forever) walks you to its waypoints, and [Adventure Guide Forever](https://www.curseforge.com/wow/addons/adventure-guide-forever) shows each profession's next steps from its route.

SkillUp is in English for now; translations are welcome as a pull request or issue.

Source: [github.com/cjber/skillup-forever](https://github.com/cjber/skillup-forever), GPL-3.0-or-later.
