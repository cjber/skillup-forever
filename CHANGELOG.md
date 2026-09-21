# Changelog

What changed in each release, in the terms someone levelling a profession would notice. Dates are UTC.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). The entries are prose rather than bare
Added/Fixed lists: what matters about a release is why a number on the screen changed.

Each version's entry is also its release notes on GitHub, CurseForge and Wago. Older entries are kept
verbatim rather than rewritten as the addon moves.

## [Unreleased]

Where to go next, not just what each recipe costs: a route to your target, what to buy for it, and what to
train.

- **A levelling route page on the Professions window**, for any of your professions. Type a target skill
  and it lists the cheapest crafts, training recipes where the fee pays for itself, like `12× Heavy Linen Bandage to 90`, each with its cost, and the total. Every
  skill point takes whichever recipe has the lowest cost per skill-up at that point. Recipes with an
  unpriced reagent are left out and counted rather than treated as free, and a route that runs out of
  recipes stops and says where.
  The target can pass your current cap: the route adds each rank to train on the way, with its fee,
  the skill the trainer wants and the level it needs.
- **A shopping list from the route.** The page lists every reagent the route needs against what's in your
  bags and bank. Track it to see the next thing to train and the reagents still missing in the objective tracker, above your quests; at a vendor, one button on the
  merchant window buys the missing reagents that vendor sells. With Auctionator installed, the auction house
  reagents still missing become an Auctionator shopping list.
- **The profession trainer shows the same numbers** as recipe rows, and marks the recipe that most cheapens
  or extends your route, training fee included, as `Best next` (closes #2).
- **Reagent tooltips list the recipes that use them.** Any item you hover shows the recipes of your
  professions that use it and still skill up, with their colour now, like `yellow until 115`.
- Recipes you haven't opened in the Professions window now have reagents and crafted items from the game's
  data, so the trainer and tooltips can price them.

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

- Every recipe row shows the skill it needs and your skill-up chance, coloured by difficulty.
- The recipe tooltip shows the orange / yellow / green / grey thresholds on a bar with your skill marked.
- Recipes can be sorted within each category by required skill or by skill-up chance.
- `/su audit` checks the bundled data against the colours the game shows.
- Thresholds for 2,356 recipes from Forever build 1.60.1.69913.
