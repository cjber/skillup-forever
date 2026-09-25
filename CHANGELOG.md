# Changelog

What changed in each release, in the terms someone levelling a profession would notice. Dates are UTC.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). The entries are prose rather than bare
Added/Fixed lists: what matters about a release is why a number on the screen changed.

Each version's entry is also its release notes on GitHub, CurseForge and Wago. Older entries are kept
verbatim rather than rewritten as the addon moves.

## [Unreleased]

- **Ready for translation.** Every line SkillUp writes, from recipe tooltips to the route tab and tracker, can now be translated: send a file for your language as a pull request, or paste it into an issue, on [GitHub](https://github.com/cjber/skillup-forever/tree/main/Locales). Rank names, *Default*, *Off* and *Total* already use the game's own words, so they follow your client's language now. English is unchanged.

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
- **Fixed** your own auction house search wiping scanned prices when it found nothing. Only SkillUp's own searches now mark an item as unlisted.
- **Fixed** free recipes, made only from reagents you gather, showing a cost of 1c per skill-up.
- **Fixed** an error on `/reload` right after an update, before the "restart the game" message could show.
- **Fixed** the Craft button offering crafts past your skill cap. It now stops where skill-ups do, until you train the next rank.
- **Fixed** prices from an auction house scan you walked away from mid-way not showing until something else changed.
- **Fixed** a recipe with no reagent data counting as free. It shows `?` now.
- **Fixed** an old Auctionator price winning over a newer scan that found nobody selling the item.
- **Fixed** searching the game's settings blaming SkillUp for a blocked button (Social's Discord Sign In).
- **Trainer steps in the route** read the same as elsewhere, with one space before "(level N)".
- **The sort setting's tooltip** now says that sorting puts every recipe in one list, and Default restores categories.
- Thresholds, recipes, trainers and prices for Forever build 1.60.1.69977.

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
