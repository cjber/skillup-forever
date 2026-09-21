WoW: Forever runs Classic content in the modern Professions window. That window shows a recipe's colour, but not the skill it needs, when it turns yellow, green or grey, or how likely your next craft is to give a skill-up. SkillUp Forever adds that information to the existing window. It does not open a separate frame.

![The Leatherworking window with skill-up chance and cost per skill-up on each row](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/window.png)

![Recipe tooltip with thresholds, reagent prices and cost per skill-up](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/tooltip.png)

## Features

- **Recipe rows** show your chance of a skill-up and what each skill-up costs, coloured by difficulty: `62% · 45s` (in coin icons). The skill a recipe needs can be added in settings. A recipe you can't make yet shows only its requirement, in red.
- **Recipe tooltips** show the orange, yellow, green and grey thresholds on a bar with your current skill marked, then each reagent's price and where it came from, what the craft sells for, and the cost per skill-up, when known.
- **Sorting** by required skill, skill-up chance or cheapest skill-up, from a *Sort by* section in the recipe list's own Filter menu. The game's own filters, including *Only skill-ups*, still apply.

## Prices

Each reagent uses the cheapest price the addon knows: about 50 common vendor supplies are priced from the start, vendors you visit update theirs, opening the auction house scans it for your reagents (at most hourly; `/su scan` forces it), and [Auctionator](https://www.curseforge.com/wow/addons/auctionator) fills anything not scanned. What the craft sells for comes off the cost (vendor price by default, auction price optional), and a skill-up that makes money shows a green `+`. A recipe with any unpriced reagent shows no cost rather than a misleadingly cheap one.

## Usage

Open a profession and the numbers are already there.

- `/su scan`, with the auction house open, rescans reagent prices.
- `/su` opens the settings (also in Settings > AddOns, or from the addon compartment on the minimap).
- `/su audit`, with a profession open, compares the bundled thresholds with the colours the game shows and prints any mismatch.

## How the numbers work

Skill-up chance follows the Classic formula: orange 100%, yellow and green `(grey - skill) / (grey - yellow)`, grey 0% (also 0% at your skill cap). The colour always comes from the game, so the addon never disagrees with the window. Thresholds are generated from the Forever client's own recipe data and refreshed when a new Forever build ships. A recipe with no data shows `?` rather than a guess.

**Found a wrong number?** Run `/su audit` with that profession open and open an issue on [GitHub](https://github.com/cjber/skillup-forever/issues) with the output.

*Settings reset on reload?* That is a known Forever beta bug, not this addon. It starts from sensible defaults and keeps working.

Source code and issues: [github.com/cjber/skillup-forever](https://github.com/cjber/skillup-forever) (GPL-3.0).
