SkillUp Forever puts skill-up chances, recipe costs and colour thresholds straight into the Professions window's own rows and tooltips, with a levelling route and shopping list in a side panel. Nothing new to learn: open a profession and it looks like it came with the game, just with the numbers you'd otherwise look up.

![The Leatherworking window with skill-up chance and cost per skill-up on each row](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/window.png)

Chance and cost per skill-up, right in the Professions window's own rows.

![Recipe tooltip with thresholds, reagent prices and cost per skill-up](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/tooltip.png)

Hover a recipe for its colour thresholds and what each reagent costs.

## Features

- **Recipe rows and tooltips** show skill-up chance and cost, such as `62% · 45s`, plus orange, yellow, green and grey thresholds and a breakdown of reagent prices. Required skill is optional on rows.
- **Sorting** by required skill, skill-up chance or cheapest skill-up puts recipes in one list, learned first. *Default* restores categories; the game's filters still apply.
- **Levelling route** plans crafts towards your target skill, including worthwhile trainer recipes and rank training fees. Craft the next step from the panel. If the route stops short, see recipes from vendors, quests and drops that could extend it. Set waypoints to trainers and suppliers, with TomTom support.
- **Shopping list** counts reagents against your bags and bank. Track it above your quests, buy missing supplies at a vendor, or send missing auction reagents to an Auctionator shopping list. Syndicator can show what your other characters hold.
- **Profession trainer** shows skill-up chance and cost beside recipes and marks the best next training choice for your route, fee included.
- **Reagent tooltips** show what tracked routes need. Hold Shift for every recipe of your professions that uses the item and still skills up, or choose that view in settings.

## Prices

- Common vendor supplies have bundled prices; visiting vendors records their prices, including reputation discounts.
- Opening the auction house scans known reagents and crafted items at most hourly. Your own searches update prices too.
- With [Auctionator](https://www.curseforge.com/wow/addons/auctionator), the fresher of its price and SkillUp's scan is used. Automatic scans skip items Auctionator priced today.
- Reagents gathered by your professions count as free by default; turn this off in settings if you prefer.

Otherwise, each reagent uses the cheaper known vendor or auction price. The craft's vendor sell value comes off its cost by default; optionally use its auction value when higher, after the 5% cut. Profit shows a green `+`. Unpriced recipes show no cost and are excluded from routes.

## Usage

Open a profession and the numbers are already there.

- `/su scan`, with the auction house open, rescans reagent prices.
- `/su` opens the settings (also in Settings > AddOns, or from the addon compartment on the minimap).
- `/su audit`, with a profession open, compares the bundled thresholds with the colours the game shows and prints any mismatch.

Thresholds come from the Forever client's recipe data; missing data shows `?`. Found a wrong number? Include `/su audit` output in an issue on [GitHub](https://github.com/cjber/skillup-forever/issues).

Prices are only as good as what you've seen, so a recipe with an unpriced reagent shows no cost until you've visited a vendor or the auction house.

Source code: [github.com/cjber/skillup-forever](https://github.com/cjber/skillup-forever). Licence: GPL-3.0-or-later.
