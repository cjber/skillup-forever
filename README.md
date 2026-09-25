<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/media/icon-400.png" width="96" alt=""></p>

<h1 align="center">SkillUp Forever</h1>

<p align="center">
Classic profession-levelling numbers inside WoW: Forever's Professions window.<br>
<a href="https://github.com/cjber/skillup-forever/actions/workflows/ci.yml"><img src="https://github.com/cjber/skillup-forever/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
<a href="https://github.com/cjber/skillup-forever/releases/latest"><img src="https://img.shields.io/github/v/release/cjber/skillup-forever" alt="Latest release"></a>
</p>

WoW: Forever's modern Professions window shows a recipe's colour, but not when it turns yellow, green or grey, or how likely your next craft is to give a skill-up. This addon adds those numbers to the window, plus a levelling route beside it, the same numbers at the trainer, and recipe uses on reagent tooltips. The numbers sit in the window's own rows and tooltips, so it looks like it came with the game.

<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/window.png" width="640" alt="The Leatherworking window with skill-up chance and cost per skill-up on each recipe row, and a tooltip showing reagent prices and cost per skill-up"></p>

## Features

- **Recipe rows** show your chance of a skill-up and what each skill-up costs, coloured by difficulty: `62% · 45s` (in coin icons). The skill a recipe needs can be added in settings. A recipe you can't make yet shows only its requirement, in red.
- **Recipe tooltips** show the orange, yellow, green and grey thresholds on a bar, with your current skill marked, drawn in the style of the profession window's own skill bar.
- **Cost per skill-up**: reagent cost divided by skill-up chance, on the row and broken down per reagent in the tooltip. See [Prices](#prices).
- **Sorting** by required skill, skill-up chance or cheapest skill-up, from a *Sort by* section in the recipe list's Filter menu. A sort lists every recipe in one ordered list; *Default* brings the categories back. The game's own filters still apply.
- **Levelling route**: a map tab beside the Professions window opens a SkillUp page. Type a target skill and it lists the cheapest crafts to get there, like `12× Heavy Linen Bandage to 90`, with trainer steps, fees and the total cost; *Craft* makes the first step. When nothing you know reaches the target, it lists the vendor, quest and drop recipes that would, with waypoints. [More](docs/route.md#levelling-route).
- **Shopping list**: every reagent the route needs, with how many you have, green once covered. *Track* puts it in the objective tracker above your quests; at a vendor, *Buy tracked reagents* buys what they sell; with Auctionator, *To Auctionator* makes a shopping list. Reagents you gather yourself count as free. [More](docs/route.md#shopping-list).
- **Profession trainer**: each recipe a trainer teaches shows its row text (`62% · 45s`) and the one that most cheapens or extends your route, fee included, is marked `Best next`. A recipe the addon can't identify for certain shows `?`.
- **Reagent tooltips**: hovering an item anywhere shows what your tracked routes need of it. Hold Shift, or choose it in settings, to list the recipes of your professions that use it and still skill up, with their colour now: `Heavy Linen Bandage    yellow until 115`.

## Install

Install it from [CurseForge](https://www.curseforge.com/wow/addons/skillup-forever) or [Wago Addons](https://addons.wago.io/addons/skillup-forever), or download the zip from [Releases](https://github.com/cjber/skillup-forever/releases). To install the zip by hand, extract it into `_classic_beta_/Interface/AddOns/` so you end up with `AddOns/SkillUpForever/SkillUpForever.toc`.

## Usage

Open a profession and the numbers are already there.

| Command | What it does |
|---|---|
| `/su`, `/skillup` | Open the settings (also in Settings → AddOns, or from the addon compartment on the minimap) |
| `/su audit` | With a profession open, compare the bundled thresholds with the colours the game shows and print any mismatch |

Settings cover what rows and tooltips show, what crafts count for, sort order, the route tab, trainer annotations, reagent tooltips, companion addon hints and the chat line after an update.

> **Settings and prices reset on reload?** That is a known Forever beta bug, not this addon ([forever-bugs#34](https://github.com/ClassicWoWCommunity/forever-bugs/issues/34)). The addon starts from sensible defaults and keeps working; prices are then relearned each session.

## Prices

Cost per craft counts the recipe's required reagents. Each reagent uses the cheapest price the addon knows:

- **Vendor:** about 50 common trade supplies (thread, vials, flux, dyes, spices) are priced from the start. Any vendor you open that sells a reagent for gold updates its price, including your reputation discount.
- **Auction house:** auction prices need [Auctionator](https://www.curseforge.com/wow/addons/auctionator). SkillUp doesn't scan the auction house itself; it uses Auctionator's prices, and routes re-price as Auctionator scans. Without Auctionator, a reagent you can only buy at the auction house has no price.

What you craft counts too: by default its vendor sell price is taken off the cost, and a setting can use its auction price instead when that's higher (after the 5% cut; it may not sell). A recipe that earns more than it costs shows a green `+` and sorts first under *Cheapest skill-up*.

Crafted reagents use their auction price, so they need Auctionator too. A recipe with an unpriced reagent shows no cost rather than a misleadingly cheap one. Cost per skill-up is net cost per craft ÷ skill-up chance, so a yellow recipe at 50% costs twice its reagents per point.

## How the numbers work

Each recipe has four thresholds: orange (required skill), yellow, green and grey. Skill-up chance follows the Classic formula:

| Colour | Chance |
|---|---|
| Orange | 100% |
| Yellow, green | `(grey − skill) / (grey − yellow)` |
| Grey, or at your skill cap | 0% |

The colour itself always comes from the game, so the addon never disagrees with the window. The thresholds are generated from the Forever client's own `SkillLineAbility` data (via [wago.tools](https://wago.tools)). Where it agrees with that data, the Skillet-Classic baseline fills in the orange value. A recipe with no data shows `?` rather than a guess. Reagents, crafted items and trainer recipe names for recipes you haven't opened come from the same data (`SpellReagents`, `SpellEffect`).

**Found a wrong number?** Run `/su audit` with that profession open and [open an issue](https://github.com/cjber/skillup-forever/issues/new) with the output.

## Works alongside

All optional: Auctionator supplies auction prices and takes the shopping list (see [Prices](#prices)), TomTom draws the arrow for route waypoints, and Syndicator shows the reagents your other characters hold.

## Development

Link the checkout into the game (`ln -s "$PWD" ".../_classic_beta_/Interface/AddOns/SkillUpForever"`) and run the gate under [Commands in AGENTS.md](AGENTS.md#commands); [tools/README.md](tools/README.md) lists the data generators. The type gate needs Git and Python 3.10+ and fetches pinned WoW API annotations into ignored `.types/`. CI runs the same gate plus actionlint, zizmor, gitleaks and sift; a daily job opens a pull request when a newer Forever build changes the recipe data.

**Releasing:** move the `[Unreleased]` notes in `CHANGELOG.md` under `## [X.Y.Z] - YYYY-MM-DD` and set `ns.WHATS_NEW` in `Core.lua` to that release's headline, then `git tag -s vX.Y.Z && git push --tags`. The [BigWigs packager](https://github.com/BigWigsMods/packager) builds the zip and uploads it to GitHub Releases, CurseForge and Wago, with that version's entry (`tools/changelog.py`) as the release notes.

**Translating:** translations are welcome as a pull request on GitHub, or pasted into an issue if that's easier. [Locales](https://github.com/cjber/skillup-forever/tree/main/Locales) has a template and how to add one.

**Contributing:** read [CONTRIBUTING.md](https://github.com/cjber/.github/blob/main/CONTRIBUTING.md) and [AGENTS.md](AGENTS.md) first. Report security problems privately, as [SECURITY.md](https://github.com/cjber/.github/blob/main/SECURITY.md) describes.

## Licence

GPL-3.0-or-later. The threshold baseline is partly derived from [Skillet-Classic](https://github.com/b-morgan/Skillet-Classic) (GPL-3.0-or-later); per-build values come from the game's data via [wago.tools](https://wago.tools). Trainer fees and recipe sources come from [CMaNGOS classic-db](https://github.com/cmangos/classic-db) (GPL-3.0). The list of vendor-sold reagents comes from [LibPeriodicTable-3.1](https://github.com/doadin/libperiodictable-3-1) (LGPL-2.1).

Made by Cillian Berragan · [cillian.dev](https://cillian.dev) · [GitHub](https://github.com/cjber) · [Twitter](https://twitter.com/cjberragan)
