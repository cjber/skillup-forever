# Changelog

## Unreleased

- Cost per skill-up on recipe rows and in the tooltip: reagent cost ÷ skill-up chance, with each reagent's price and where it came from.
- Prices for about 50 vendor trade supplies bundled from the client's data, updated by vendors you visit, an automatic auction house scan of known reagents (at most hourly, or `/su scan`), and Auctionator when installed.
- Rows now show skill-up chance and cost per skill-up (in coin icons); the required skill is an option, and still shows on recipes you can't make yet.
- Fixed: choosing a sort order had no visible effect.
- New sort: cheapest skill-up. Sorting now also sits in the recipe list's Filter menu, under *Sort by*.

## v0.1.0

First release.

- Every recipe row shows the skill it needs and your skill-up chance, coloured by difficulty.
- The recipe tooltip shows the orange / yellow / green / grey thresholds on a bar with your skill marked.
- Recipes can be sorted within each category by required skill or by skill-up chance.
- `/su audit` checks the bundled data against the colours the game shows.
- Thresholds for 2,356 recipes from Forever build 1.60.1.69913.
