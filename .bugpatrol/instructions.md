# About the app

SkillUp Forever is a World of Warcraft: Forever addon written in Lua 5.1. It cannot run outside the
game client, and this patrol never starts it (see the rules below). What runs here is its headless test harness: each
`tests/<name>_spec.lua` stubs the client API, loads the addon files the TOC lists, and checks one
feature. Run a spec with `luajit tests/<name>_spec.lua`; a failing spec exits non-zero and prints
the failed assertion. `luacheck <file>` lints a file.

The Lua the specs load reads recipe, reagent, trainer and item data from `Data/`, which is generated
and checked in. `python3 tools/check_generated.py` regenerates it in a scratch tree and fails when
the committed copy differs, so a change that claims a data fix can be checked against it.

Use the specs and `luajit -e` one-liners that load the harness to check what a change claims.
Report a spec that fails, an error that a spec prints, or a behaviour a spec shows that the change
does not intend.

## Sign in

No sign-in.

## Important flows

- The windows the addon paints in the Professions window: the skill-up rows, the route tab and the
  chance and cost columns. Specs: `tests/*_spec.lua`, the ones named after the window files.
- Locale lines: `python3 tools/check_locales.py` checks every `Locales/<locale>.lua` against
  `Locales/phrases.txt` and fails on a placeholder, colour escape or grammar mismatch.
- Data regeneration: `python3 tools/check_generated.py --offline` when the pinned inputs are cached,
  without `--offline` to fetch them.

## Never do these things

- Never start the game, Battle.net, Lutris or Wine. The headless client (forever-core's `wow-forever-addon/in-game.md`) tests the build linked into the game, not this checkout, so in-game checks belong to the agent that ships a change.
- Never edit, move or delete files.
- Never use the network.
