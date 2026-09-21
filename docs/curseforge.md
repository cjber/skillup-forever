WoW: Forever runs Classic content in the modern Professions window. That window shows a recipe's colour, but not the skill it needs, when it turns yellow, green or grey, or how likely your next craft is to give a skill-up. SkillUp Forever adds that information to the existing window. It does not open a separate frame.

![The Leatherworking window with skill and chance on each row](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/window.png)

![Threshold tooltip](https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/tooltip.png)

## Features

- **Recipe rows** show the skill a recipe needs and your chance of a skill-up, coloured by difficulty: `125 · 62%`. A recipe you can't make yet shows only the requirement, in red.
- **Recipe tooltips** show the orange, yellow, green and grey thresholds on a bar with your current skill marked, drawn in the style of the profession window's own skill bar.
- **Sorting** within each category by required skill or by skill-up chance. Categories and the game's own filters, including *Only skill-ups*, are unchanged.

## Usage

Open a profession and the numbers are already there.

- `/su` opens the settings (also in Settings > AddOns, or from the addon compartment on the minimap).
- `/su audit`, with a profession open, compares the bundled thresholds with the colours the game shows and prints any mismatch.

## How the numbers work

Skill-up chance follows the Classic formula: orange 100%, yellow and green `(grey - skill) / (grey - yellow)`, grey 0% (also 0% at your skill cap). The colour always comes from the game, so the addon never disagrees with the window. Thresholds are generated from the Forever client's own recipe data and refreshed when a new Forever build ships. A recipe with no data shows `?` rather than a guess.

**Found a wrong number?** Run `/su audit` with that profession open and open an issue on [GitHub](https://github.com/cjber/skillup-forever/issues) with the output.

*Settings reset on reload?* That is a known Forever beta bug, not this addon. It starts from sensible defaults and keeps working.

Source code and issues: [github.com/cjber/skillup-forever](https://github.com/cjber/skillup-forever) (GPL-3.0).
