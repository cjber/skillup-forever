Regenerate from the repository root with Python 3 (standard library only):

```sh
python3 tools/gen_thresholds.py
luacheck Model.lua tests/ --std lua51
luajit tests/model_spec.lua
```

The generator pins Forever `1.60.1.69913` and a Skillet-Classic commit, caches
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
