<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/media/icon-400.png" width="96" alt=""></p>

<h1 align="center">SkillUp Forever</h1>

<p align="center">
Classic profession-levelling numbers inside WoW: Forever's Professions window.<br>
<a href="https://github.com/cjber/skillup-forever/actions/workflows/ci.yml"><img src="https://github.com/cjber/skillup-forever/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
<a href="https://github.com/cjber/skillup-forever/releases/latest"><img src="https://img.shields.io/github/v/release/cjber/skillup-forever" alt="Latest release"></a>
</p>

WoW: Forever runs Classic content in the modern Professions window. That window shows a recipe's colour, but not the skill it needs, when it turns yellow, green or grey, or how likely your next craft is to give a skill-up. This addon adds that information to the existing window. It does not open a separate frame.

<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/window.png" width="640" alt="The Leatherworking window with skill and skill-up chance on each recipe row, and the threshold tooltip"></p>

## Features

- **Recipe rows** show the skill a recipe needs and your chance of a skill-up, coloured by difficulty: `125 · 62%`. A recipe you can't make yet shows only the requirement, in red.
- **Recipe tooltips** show the orange, yellow, green and grey thresholds on a bar, with your current skill marked, drawn in the style of the profession window's own skill bar.
- **Cost per skill-up**: reagent cost divided by skill-up chance, at the end of the row (`125 · 62% · 45s`) and broken down per reagent in the tooltip. See [Prices](#prices).
- **Sorting** within each category by required skill, skill-up chance or cheapest skill-up, from a *Sort by* section in the recipe list's own Filter menu. Categories and the game's own filters, including *Only skill-ups*, are unchanged.

## Install

Install it from [CurseForge](https://www.curseforge.com/wow/addons/skillup-forever) or [Wago Addons](https://addons.wago.io/addons/skillup-forever), or download the zip from [Releases](https://github.com/cjber/skillup-forever/releases). To install the zip by hand, extract it into `_classic_beta_/Interface/AddOns/` so you end up with `AddOns/SkillUpForever/SkillUpForever.toc`.

## Usage

Open a profession and the numbers are already there.

| Command | What it does |
|---|---|
| `/su` | Open the settings (also in Settings → AddOns, or from the addon compartment on the minimap) |
| `/su audit` | With a profession open, compare the bundled thresholds with the colours the game shows and print any mismatch |
| `/su scan` | With the auction house open, search it for every known reagent now |

Settings: row text, tooltip, cost per skill-up, auction house scan, sort order (also in the Filter menu).

> **Settings and prices reset on reload?** That is a known Forever beta bug, not this addon ([forever-bugs#34](https://github.com/ClassicWoWCommunity/forever-bugs/issues/34)). The addon starts from sensible defaults and keeps working; prices are then relearned each session.

## Prices

Cost per craft counts the recipe's required reagents. Each reagent uses the cheapest price the addon knows:

- **Vendor:** about 50 common trade supplies (thread, vials, flux, dyes, spices) are priced from the start. Any vendor you open that sells a reagent for gold updates its price, including your reputation discount.
- **Auction house:** when you open the auction house, the addon searches it for the reagents of every recipe you've looked at (at most once an hour; `/su scan` forces it). Your own searches update prices too. Prices are kept per realm and faction.
- **Auctionator:** used when the addon hasn't scanned a reagent and [Auctionator](https://www.curseforge.com/wow/addons/auctionator) is installed.

Crafted reagents use their auction price, not the cost of making them. A recipe with any unpriced reagent shows no cost, rather than one that looks cheap only because part of it is missing. Cost per skill-up is cost per craft ÷ skill-up chance, so a yellow recipe at 50% costs twice its reagents per point.

## How the numbers work

Each recipe has four thresholds: orange (required skill), yellow, green and grey. Skill-up chance follows the Classic formula:

| Colour | Chance |
|---|---|
| Orange | 100% |
| Yellow, green | `(grey − skill) / (grey − yellow)` |
| Grey, or at your skill cap | 0% |

The colour itself always comes from the game, so the addon never disagrees with the window. The thresholds are generated from the Forever client's own `SkillLineAbility` data (via [wago.tools](https://wago.tools)). Where it agrees with that data, the Skillet-Classic baseline fills in the orange value. A recipe with no data shows `?` rather than a guess.

**Found a wrong number?** Run `/su audit` with that profession open and [open an issue](https://github.com/cjber/skillup-forever/issues/new) with the output.

## Development

```sh
# link the checkout into the game
ln -s "$PWD" ".../World of Warcraft/_classic_beta_/Interface/AddOns/SkillUpForever"

luacheck .                        # lint
stylua --check .                  # format
luajit tests/model_spec.lua       # threshold and cost maths + generated data
python3 tools/gen_thresholds.py   # regenerate Data/Thresholds.lua (see tools/README.md)
python3 tools/gen_vendor.py       # regenerate Data/Vendor.lua
```

CI runs the three checks on every push. Each day a scheduled job checks wago.tools for a newer Forever build and, if its recipe data differs, opens a pull request with the regenerated `Data/Thresholds.lua` and `Data/Vendor.lua`.

**Releasing:** add the notes to `CHANGELOG.md`, then `git tag -s vX.Y.Z && git push --tags`. The [BigWigs packager](https://github.com/BigWigsMods/packager) builds the zip and uploads it to GitHub Releases, CurseForge and Wago.

## Licence

GPL-3.0-or-later. The threshold baseline is partly derived from [Skillet-Classic](https://github.com/b-morgan/Skillet-Classic) (GPL-3.0-or-later); per-build values come from the game's data via [wago.tools](https://wago.tools). The list of vendor-sold reagents comes from [LibPeriodicTable-3.1](https://github.com/doadin/libperiodictable-3-1) (LGPL-2.1).

Made by Cillian Berragan · [cillian.dev](https://cillian.dev) · [GitHub](https://github.com/cjber) · [Twitter](https://twitter.com/cjberragan)
