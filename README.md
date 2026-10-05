<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/media/icon-400.png" width="96" alt=""></p>

<h1 align="center">SkillUp Forever</h1>

<p align="center">
Classic profession-levelling numbers inside WoW: Forever's Professions window.<br>
<a href="https://github.com/cjber/skillup-forever/actions/workflows/ci.yml"><img src="https://github.com/cjber/skillup-forever/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
<a href="https://github.com/cjber/skillup-forever/releases/latest"><img src="https://img.shields.io/github/v/release/cjber/skillup-forever" alt="Latest release"></a>
</p>

WoW: Forever's Professions window shows a recipe's colour, but not when it turns yellow, green or grey, or your next craft's skill-up chance. SkillUp adds those numbers to the window's own rows and tooltips, a levelling route with its shopping list, the same numbers at the trainer, a crafted gear page, and recipe uses on reagent tooltips. It looks like it came with the game.

<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/demo.gif" width="640" alt="Leatherworking levelling from 48 to 60 in the Professions window"></p>

From 48 to 60 the rows re-sort by cost per skill-up, and Handstitched Leather Bracers turns green at 55.

<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/window.png" width="640" alt="The Leatherworking window with skill-up chance and cost per skill-up on each recipe row, and a tooltip showing reagent prices and cost per skill-up"></p>

Each row shows its chance and cost, with the tooltip breaking it down per reagent. This character skins, so Light Leather is free.

<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/tooltip.png" width="640" alt="A recipe tooltip with the orange, yellow, green and grey thresholds on a bar, your skill marked, and each reagent's price and cost per skill-up"></p>

The recipe tooltip draws the thresholds on the game's own bar with your skill marked, then each reagent's price and the cost per skill-up.

## Features

- **Recipe rows** show your chance of a skill-up and what each costs, coloured by difficulty: `62% · 45s`. Required skill is optional; a recipe you can't make yet shows its requirement, in red.
- **Recipe tooltips** show the orange, yellow, green and grey thresholds on a bar, with your current skill marked, in the window's own style.
- **Cost per skill-up** divides reagent cost by skill-up chance, on the row and per reagent. See [Prices](#prices).
- **Sorting** by required skill, chance or cheapest skill-up, from *Sort by* in the recipe list's Filter menu. *Default* restores the game's categories; its filters still apply.
- **Levelling route**: a tab beside the window opens a SkillUp page. Type a target skill and it lists the cheapest crafts as the game lists an item: a full icon, the recipe's name and, under it, the crafts, the skill it reaches and the cost, with trainer steps, fees and total. A reagent a recipe you know makes and crafting it beats buying becomes its own step, and a step names the tool and the station it needs. Each step asks for enough crafts to cover an unlucky run, not just the average, so the shopping list lasts; *Craft* makes the first step and *Nearest vendor* points to the closest vendor for what the route still buys. A route that stops short lists vendor, quest and drop recipes that would. [More](docs/route.md#levelling-route).
- **Shopping list**: every reagent the route needs, how many you have, green once covered. *Buy reagents* in the route header chooses whether a reagent another of your professions gathers is free to gather or bought at a vendor or the auction house. *Track* puts it beside your quests, and opening the profession you are levelling tracks it on its own; *Buy tracked reagents* buys what a vendor sells; with Auctionator it keeps a shopping list up to date as you buy, craft and skill up. [More](docs/route.md#shopping-list).
- **Profession trainer**: recipes show their row text (`62% · 45s`), and the one that most cheapens or extends your route gets a green arrow, fee included. An unknown recipe shows `?`.
- **Reagent tooltips**: hovering an item shows what your tracked routes need. Hold Shift for every recipe of your professions that uses it and still skills up, with its colour: `Heavy Linen Bandage    yellow until 115`.
- **Crafted gear**: a *Gear* tab beside the window, turned on in settings, draws your character sheet again, one item a slot down both sides and the weapon slots along the bottom, each showing the newest thing you could craft for it. The pane in the middle names the pick, the skill its recipe is learned at, its state, its reagents with how many you have, and one button to open the recipe or walk to where it is taught. Not a best-in-slot list. [More](docs/gear.md).

<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/route.png" width="640" alt="The SkillUp route tab: training and crafting steps from 48 to 73 with their costs, and the reagents they need"></p>

The route tab from 48 to 73: train the vest, craft 28, and where reagents come from.

<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/gear.png" width="640" alt="The Crafted gear tab: item slots down both sides and along the bottom, each showing the newest crafted item, with one slot's recipe, reagents and status in the middle"></p>

The gear tab, turned on in settings: each slot shows the newest thing this character could craft for it, with the pick's recipe, reagents and status in the middle.

<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/tracker.png" width="320" alt="The objective tracker with Leatherworking to 73, the next training step and two missing reagents"></p>

Tracked, the same route sits beside your quests: the next trainer visit and what's still missing.

<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/trainer.png" width="320" alt="An Apprentice Leatherworking trainer's recipes, each with its skill-up chance and cost, and a green arrow on the vest"></p>

At the trainer, every recipe shows its chance and cost; a green arrow marks the one to train next.

<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/reagent.png" width="320" alt="Light Leather's tooltip with how much the tracked route needs"></p>

Hover a reagent to see how much your tracked routes need.

## Install

Install it from [CurseForge](https://www.curseforge.com/wow/addons/skillup-forever) or [Wago Addons](https://addons.wago.io/addons/skillup-forever), or download the zip from [Releases](https://github.com/cjber/skillup-forever/releases). To install the zip by hand, extract it into `_classic_beta_/Interface/AddOns/`.

## Usage

Open a profession and the numbers are already there.

| Command | What it does |
|---|---|
| `/su`, `/skillup` | Open the settings (also in Settings → AddOns, or from the addon compartment on the minimap) |
| `/su audit` | With a profession open, compare the bundled thresholds with the colours the game shows and print any mismatch |

Settings cover rows and tooltips, what crafts count for, sort order, the route and crafted gear tabs, trainer annotations, reagent tooltips and companion hints.

> **Settings and prices reset on reload?** A known Forever beta bug, not this addon ([forever-bugs#34](https://github.com/ClassicWoWCommunity/forever-bugs/issues/34)). It keeps working; prices are relearned each session.

## Prices

Cost per craft counts the recipe's reagents, each at the cheapest price the addon knows:

- **Vendor:** about 50 common trade supplies (thread, vials, flux, dyes, spices) are priced from the start. A vendor you open that sells a reagent for gold updates its price, including your reputation discount.
- **Auction house:** prices need [Auctionator](https://www.curseforge.com/wow/addons/auctionator), whose prices SkillUp uses without scanning the auction house itself. Each day Auctionator sees an item, the addon keeps that day's lowest buyout, and the reagent is priced from the middle of the last seven days, so one cheap listing does not move a route; the page says how many days that is. Without it, a reagent only sold there has no price.

By default a craft's vendor sell price comes off its cost; a setting can use its auction price when higher (after the 5% cut). A profitable recipe shows a green `+` and sorts first under *Cheapest skill-up*. Crafted reagents use their auction price too. An unpriced reagent shows no cost rather than a misleadingly cheap one, and every recipe that needs it is left out of the route, which names the reagent; cost per skill-up is net cost per craft ÷ skill-up chance.

## How the numbers work

Each recipe has four thresholds: orange (required skill), yellow, green and grey. Chance follows the Classic formula:

| Colour | Chance |
|---|---|
| Orange | 100% |
| Yellow, green | `(grey − skill) / (grey − yellow)` |
| Grey, or at your skill cap | 0% |

The colour always comes from the game, so the addon never disagrees. Thresholds and recipe data come from the Forever client's `SkillLineAbility` (via [wago.tools](https://wago.tools)); where it agrees, the Skillet-Classic baseline fills in orange, and the grey threshold is the game's own live value where it reports one. Missing data shows `?`.

**Found a wrong number?** Run `/su audit` with that profession open and [open an issue](https://github.com/cjber/skillup-forever/issues/new) with the output.

Turn off **Attach to quest tracker** in Settings to drag the shared Forever column. Its position survives `/reload`; turn the setting back on to attach it above your quests.

## Works alongside

All optional: Auctionator supplies auction prices and takes the shopping list, TomTom draws waypoint arrows, and Syndicator shows your other characters' reagents. [Questie](https://www.curseforge.com/wow/addons/questie) names the vendors, quests and trainers the route points to, and [AtlasLoot](https://www.curseforge.com/wow/addons/atlaslootclassic) tells it which scroll teaches which recipe; without them the route still plans your crafts, and says in one line what to install for the rest. [Shortest Path Forever](https://www.curseforge.com/wow/addons/shortest-path-forever) walks you to its waypoints, and [Adventure Guide Forever](https://www.curseforge.com/wow/addons/adventure-guide-forever) shows each profession's next steps from its route.

## Development

Developed with AI assistance; changes are reviewed and checked with automated tests, linting and type checks.


Link the checkout into the game (`ln -s "$PWD" ".../Interface/AddOns/SkillUpForever"`) and run the gate under [Commands in AGENTS.md](AGENTS.md#commands) ([tools/README.md](tools/README.md) covers the data generators). CI runs the same gate plus actionlint, zizmor, gitleaks and sift; a daily job opens a pull request on a newer Forever build.

Run `luajit tests/bench.lua` from the repository root to measure loading, route rebuilds, event bursts and cached lookups in the headless client. These are CPU timings, not in-game latency measurements.

**Releasing:** move `[Unreleased]` notes in `CHANGELOG.md` under `## [X.Y.Z] - YYYY-MM-DD`, set `ns.WHATS_NEW` in `Core/Core.lua` to the headline, then `git tag -s vX.Y.Z && git push --tags`. The [BigWigs packager](https://github.com/BigWigsMods/packager) builds and uploads the zip to GitHub, CurseForge and Wago, with the `tools/changelog.py` entry as notes.

**Translating:** translations are welcome as a pull request or an issue; [Locales](https://github.com/cjber/skillup-forever/tree/main/Locales) has a template.

**Contributing:** read [CONTRIBUTING.md](https://github.com/cjber/.github/blob/main/CONTRIBUTING.md) and [AGENTS.md](AGENTS.md) first. Report security problems privately, as [SECURITY.md](https://github.com/cjber/.github/blob/main/SECURITY.md) describes.

## Licence

GPL-3.0-or-later. Thresholds are partly derived from [Skillet-Classic](https://github.com/b-morgan/Skillet-Classic) (GPL-3.0-or-later); per-build values come from the game via [wago.tools](https://wago.tools). Trainer fees, who trains what, drop chances and gathered reagents come from [CMaNGOS classic-db](https://github.com/cmangos/classic-db) (GPL-3.0); vendors, quests, NPC places and scroll recipes are read in game from your own Questie and AtlasLoot, and none of their data is bundled; vendor reagents from [LibPeriodicTable-3.1](https://github.com/doadin/libperiodictable-3-1) (LGPL-2.1).

Made by Cillian Berragan · [cillian.dev](https://cillian.dev) · [GitHub](https://github.com/cjber) · [Twitter](https://twitter.com/cjberragan)
