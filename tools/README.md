Regenerate from the repository root with Python 3 (standard library only):

```sh
python3 tools/gen_thresholds.py
python3 tools/gen_vendor.py
python3 tools/gen_recipes.py
python3 tools/gen_trainer.py
python3 tools/gen_sources.py
luacheck .
tools/typecheck.sh
for s in tests/*_spec.lua; do luajit "$s" || exit 1; done
```

The generator pins a Forever build (`BUILD`) and a Skillet-Classic commit, caches
downloads in `tools/.cache/`, and writes sorted `Data/Thresholds.lua`. Use
`--refresh` to download again or `--offline` to require cached sources. The header
date identifies the selected source snapshot, so repeated runs are byte-identical.

Wago's `SkillLineAbility` supplies yellow/grey and fallback orange; green is their
floored midpoint. `SkillLine` discovers professions and child lines; `SpellName`
supplies comments. Same-build `SpellEffect` maps created items to recipe spells
for Skillet's item-keyed requirements. A baseline orange is accepted only when
yellow/grey match; scraped `SkillLevels` takes priority over `SkillLineAbility`.
Every row records orange provenance. DB2-derived orange values need a live audit.
Contradictory DB2 requirements (`orange > yellow`, currently spells 2665 and
2674) are retained and flagged, never clamped or replaced with guessed values.

Coverage prints per skill line, including skipped/duplicate rows and missing
names. Gathering abilities and test professions are excluded. Shared recipes
count once per profession but occupy one output key. DB2 download/schema failures
leave existing output untouched; an unavailable Skillet baseline produces a
warning and retains DB2 values. Baseline-derived portions are GPL-3.0-or-later.

`gen_vendor.py` writes `Data/Vendor.lua`: unit prices (`BuyPrice / VendorStackCount`
from the same build's `ItemSparse`) for the items in LibPeriodicTable-3.1's
`Tradeskill.Mat.BySource.Vendor` set (pinned commit, LGPL-2.1), since which items
vendors sell is server data the client doesn't ship. Listed items missing from the
build are reported and skipped. It shares the build pin and cache with `gen_thresholds.py`.

`gen_recipes.py` writes `Data/Recipes.lua`, using only spell IDs already present in
the same-build `Data/Thresholds.lua`. It imports the threshold generator's build,
snapshot date, cache and profession discovery; run thresholds first when changing
builds. All five generators accept `--offline` and `--refresh`. To verify recipe
reproducibility:

```sh
python3 tools/gen_recipes.py --offline
sha256sum Data/Recipes.lua
python3 tools/gen_recipes.py --offline
sha256sum Data/Recipes.lua
```

`gen_trainer.py` writes `Data/Trainer.lua`: base trainer fees for recipes with
thresholds, from the pinned CMaNGOS classic-db `npc_trainer` table (GPL-3.0). Its
rows name teaching spells; Classic Era's `SpellEffect` (LEARN_SPELL) maps them to
recipe spells, since Forever's client leaves the teaching spells out.
Specialisation-gated rows are skipped, and fees recorded at a trainer in game win. It also writes `ns.TrainerRanks`: each profession rank a trainer teaches (the
taught spell's `SKILL` effect gives the skill line and the new cap), with fee,
required skill and level. Ranks that come from books or quests are absent.

`gen_sources.py` writes `Data/Sources.lua`: for each recipe taught by a scroll, where
the scroll comes from, from the same classic-db dump. Scroll items (`item_template`
class 9) map to recipes through Classic Era's LEARN_SPELL effects, as trainer spells
do. Vendors come from `npc_vendor` and vendor templates (limited when every vendor
stocks it in limited supply), the three likeliest creature drops from
`creature_loot_template`, world drops from `reference_loot_template`, and quest
rewards from `quest_template`. Each NPC keeps its name, faction (`FactionTemplate`)
and one world spawn; the client turns that into a zone and map position, so the
generator needs no zone boundaries. Dungeon spawns carry the instance name from `Map`.
It also writes each profession's trainers with the highest rank they teach (their
`npc_trainer` rank spells), and the vendors that always stock each vendor reagent in
`Data/Vendor.lua`, for waypoints to the nearest one. `ns.GatheredBy` maps reagents to
the gathering profession that yields them at least 10% of the time: herb and mining
nodes (`gameobject_template` chests whose `Lock` needs the skill) and
`skinning_loot_template`, with reference loot expanded. Rarer finds (gems in veins)
are left out.

The recipe generator joins `SkillLineAbility` to `SpellReagents` and base-difficulty
`SpellEffect` rows. Reagents are sorted by item ID and repeated slots combined.
Missing or unresolved reagent rows are omitted, never converted into free recipes.
Conflicting memberships, reagent rows, outputs or names fail before replacing the
generated file. Output quantities are mean yields from `EffectBasePointsF`; zero
create-item amounts become one, and `Variance` validates that random yields do not
cross the minimum. Scaled or unsupported outputs fail for review. Permanent
enchants and summoned campfires have `output = false`; absence of create-item data
alone does not establish a non-item output. A valid live schematic takes precedence.

`ItemSellPrices` includes positive `ItemSparse.SellPrice` values for bundled recipe
outputs only. Missing ItemSparse rows are reported and have no bundled value.
`RecipeNames[skillLine][name]` uses exact `SpellName.Name_lang` strings from the enUS
export; ambiguous names map to `false`, including ambiguity between old and new
recipe variants. Name matching is a trainer fallback; other client locales need a
verified spell ID. Counts, omissions and file size print on each generation.

Runtime consumers filter `RecipeData[recipeID].skillLine` by the skill line
`ns.ProfessionSkillLine` (Core.lua) resolves from the open profession's name.
These are parent skill-line IDs: First Aid 129, Blacksmithing 164, Leatherworking
165, Alchemy 171, Herbalism 182, Cooking 185, Mining 186, Tailoring 197, Engineering
202, Enchanting 333, Fishing 356 and Skinning 393; expansion child lines 2937–2948
are not recipe filters. Guard unavailable profession info and filter learned
recipes before building a route snapshot. `snapshot.skill` and `snapshot.target`
must use the same effective-skill coordinates (base plus modifier); the caller
applies the trained cap. Shopping uses segment `crafts`, the ceiling of accumulated
expected crafts, and subtracts owned items once. Unknown reagent arrays contribute
no shopping rows, so only use priced route segments for a complete list.

## Screenshots

`docs/screenshots/window.png` and `tooltip.png` are mocks rendered from the
client's own UI art, not in-game captures. Regenerate them from the repository
root with:

```sh
python3 tools/screenshots.py
```

It needs Pillow and `wowmock.py` from the `wow-mock-screenshots` skill in the
cjber/skills checkout, found at `~/.claude/skills/wow-mock-screenshots` by
default; set `WOWMOCK` to another directory that holds it. Art and fonts come
from wago.tools for the pinned Forever build and are cached under
`~/.cache/wowmock/`. Every number drawn comes from `Data/*.lua` through a port
of `Model.lua`; only the scene's state (skill, bags, auction prices) is chosen
in the script. Repeated runs are byte-identical. `SCALE` (default 2) sets the
render scale.

## Type checking

Install LuaLS 3.19.1, then run `tools/typecheck.sh` from any directory. The script
fetches Ketho's WoW annotations at `d0b5b51fac4c52c493371b9b18e66ce604ea4326`,
verifies that checkout is clean, runs the Python checker tests and TOC-wide
multi-value lint, and fails on any LuaLS diagnostic. CI downloads LuaLS with a
pinned SHA-256. Editors use the same `.luarc.json` and `.types/` library.

`types/Namespace.lua` describes the shared addon table and data shapes;
`types/Client.lua` fills gaps in Ketho's FrameXML coverage using the Forever
client source; `types/Integrations.lua` describes optional addon APIs. Runtime
files annotate their parameters and custom frames. Generated files receive their
namespace annotation from the generators. Tests and tools are outside the LuaLS
workspace; every TOC-loaded Lua file is checked.

`python3 tools/lint_multivalue.py [files...]` also runs alone. A final bare
`select(...)` expands in a call, table constructor or return. Use `(select(...))`
for one value, or a local. Intentional expansion needs a trailing line comment:
`return select(2, ...) -- multi-value: forward the remaining results`.
