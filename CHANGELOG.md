# Changelog

## v0.2.0

Cost per skill-up: which recipes level your profession most cheaply.

- Recipe rows show your skill-up chance and what each skill-up costs, in coin icons. The required skill is now an option; recipes you can't make yet still show it.
- The tooltip lists each reagent with its price and where it came from, what the craft sells for, and the cost (or profit) per skill-up.
- Cost is reagents minus what the crafted item sells for: vendor price by default, auction price optional. A skill-up that makes money shows a green +.
- Prices come from about 50 bundled vendor trade supplies, vendors you visit, an auction house scan when you open it (at most hourly, or `/su scan`), and Auctionator when installed.
- New *Sort by* section in the recipe list's Filter menu, with a new *Cheapest skill-up* order. A sort lists every recipe in one ordered list, learned then unlearned.
- Fixed: sorting had no visible effect, because Forever's categories hold one or two recipes each.

## v0.1.0

First release.

- Every recipe row shows the skill it needs and your skill-up chance, coloured by difficulty.
- The recipe tooltip shows the orange / yellow / green / grey thresholds on a bar with your skill marked.
- Recipes can be sorted within each category by required skill or by skill-up chance.
- `/su audit` checks the bundled data against the colours the game shows.
- Thresholds for 2,356 recipes from Forever build 1.60.1.69913.
