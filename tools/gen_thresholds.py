#!/usr/bin/env python3
"""Generate recipe spell thresholds for one pinned Forever client (stdlib only)."""

import argparse
import csv
import io
import re
import sys
import urllib.error
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

BUILD = "1.60.1.69977"
# Date this source snapshot was selected, not the date of each regeneration.
SOURCE_DATE = "2026-09-24"
SKILLET_COMMIT = "c6807b055215a810f985f9606458235b8805666e"
SKILLET_URL = f"https://raw.githubusercontent.com/b-morgan/Skillet-Classic/{SKILLET_COMMIT}/SkillLevelData1.lua"
ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / ".cache"
OUTPUT = ROOT / "Data" / "Thresholds.lua"
REQUIRED_SKILLS = {
    129: "First Aid",
    164: "Blacksmithing",
    165: "Leatherworking",
    171: "Alchemy",
    185: "Cooking",
    186: "Mining",
    197: "Tailoring",
    202: "Engineering",
    333: "Enchanting",
}
# Fishing is category 9 with CanLink=0; unlike racials/riding, it is a profession.
SECONDARY_SKILLS = {129, 185, 356}
THRESHOLD_STRING = re.compile(r"[\"'](\d+)/(\d+)/(\d+)/(\d+)[\"']")
ENTRY = re.compile(r"\[(-?\d+)\]\s*=\s*(.+),\s*$")
NESTED_ENTRY = re.compile(r"\[(\d+)\]\s*=\s*([\"']\d+/\d+/\d+/\d+[\"'])\s*,?\s*")


def download(url, filename, refresh=False, offline=False):
    path = CACHE / filename
    if path.exists() and not refresh:
        return path.read_text(encoding="utf-8-sig")
    if offline:
        raise ValueError(f"Missing cached source: {path}")
    request = urllib.request.Request(url, headers={"User-Agent": "SkillUpForever/1.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read()
    content = data.decode("utf-8-sig")
    if content.lstrip().startswith("<"):
        raise ValueError(f"Expected data, received HTML from {url}")
    CACHE.mkdir(parents=True, exist_ok=True)
    # A failed/interrupted download must not leave a partial cache entry.
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(data)
    temporary.replace(path)
    return content


def db2(name, columns, refresh=False, offline=False):
    content = download(
        f"https://wago.tools/db2/{name}/csv?build={BUILD}",
        f"{name}-{BUILD}.csv",
        refresh,
        offline,
    )
    reader = csv.DictReader(io.StringIO(content))
    missing = set(columns) - set(reader.fieldnames or [])
    if missing:
        raise ValueError(f"{name}: missing columns: {', '.join(sorted(missing))}")
    rows = list(reader)
    if not rows:
        raise ValueError(f"{name}: empty DB2 export for {BUILD}")
    return rows


def parse_skillet(content):
    """Read only the two literal data tables; never execute downloaded Lua.

    SkillLevels positive keys are item IDs, negative keys are spell IDs;
    nested keys and SkillLineAbility keys are always recipe spell IDs.
    Keep duplicate candidates so inconsistent baselines cannot overwrite silently.
    """
    items, recipes, abilities = (defaultdict(set) for _ in range(3))
    table = None
    seen = set()
    for number, raw in enumerate(content.splitlines(), 1):
        line = raw.split("--", 1)[0].strip()
        start = re.fullmatch(r"Skillet\.db\.global\.(SkillLevels|SkillLineAbility)\s*=\s*\{", line)
        if start:
            table = start[1]
            seen.add(table)
            continue
        if table is None or not line:
            continue
        if line == "}":
            table = None
            continue
        match = ENTRY.fullmatch(line)
        if not match:
            raise ValueError(f"Unsupported Skillet entry at line {number}")
        key, value = int(match[1]), match[2]
        if value.startswith("{") and value.endswith("}") and table == "SkillLevels":
            nested = value[1:-1].strip()
            matches = list(NESTED_ENTRY.finditer(nested))
            if not matches or NESTED_ENTRY.sub("", nested).strip():
                raise ValueError(f"Unsupported nested Skillet entry at line {number}")
            for entry in matches:
                recipes[int(entry[1])].add(tuple(map(int, THRESHOLD_STRING.fullmatch(entry[2]).groups())))
        else:
            thresholds = THRESHOLD_STRING.fullmatch(value)
            if not thresholds:
                raise ValueError(f"Unsupported Skillet thresholds at line {number}")
            target = abilities if table == "SkillLineAbility" else recipes if key < 0 else items
            target[abs(key)].add(tuple(map(int, thresholds.groups())))
    if seen != {"SkillLevels", "SkillLineAbility"} or table is not None:
        raise ValueError("Missing or incomplete Skillet baseline tables")
    return items, recipes, abilities


def professions(skill_rows):
    """Discover primary professions, linked secondaries, and their child lines."""
    skills = {int(row["ID"]): row for row in skill_rows}
    selected = set(REQUIRED_SKILLS)
    excluded = {}
    for sid, row in skills.items():
        if "[DNT]" in row["DisplayName_lang"] or row["DisplayName_lang"].startswith("Test "):
            excluded[sid] = row["DisplayName_lang"]
        elif (
            int(row["CategoryID"]) == 11
            or sid in SECONDARY_SKILLS
            or (int(row["CategoryID"]) == 9 and row["CanLink"] == "1")
        ):
            selected.add(sid)
    while True:
        children = {
            sid for sid, row in skills.items() if int(row["ParentSkillLineID"]) in selected and sid not in excluded
        }
        if children <= selected:
            break
        selected.update(children)
    return skills, selected, excluded


def spell_effects(rows):
    items, effects = defaultdict(set), defaultdict(set)
    for row in rows:
        if int(row["DifficultyID"]) != 0:
            continue
        spell, effect = int(row["SpellID"]), int(row["Effect"])
        effects[spell].add(effect)
        # SPELL_EFFECT_CREATE_ITEM: only outputs, never reagents or name matches.
        if effect == 24 and int(row["EffectItemType"]) > 0:
            items[spell].add(int(row["EffectItemType"]))
    return items, effects


def orange_threshold(spell, yellow, grey, db2_orange, baseline, outputs):
    items, recipes, abilities = baseline
    scraped = set(recipes.get(spell, ()))
    for item in outputs.get(spell, ()):
        scraped.update(items.get(item, ()))
    # Prefer Wrath-scraped requirements to Skillet's DB2-based ability fallback,
    # which also contains many unreliable orange=1 entries.
    for candidates, source in (
        (scraped, "Skillet SkillLevels"),
        (abilities.get(spell, ()), "Skillet SkillLineAbility"),
    ):
        matching = {t[0] for t in candidates if t[1] == yellow and t[3] == grey and 0 <= t[0] <= t[1] <= t[2] <= t[3]}
        if len(matching) == 1:
            return next(iter(matching)), source
        if len(matching) > 1:
            return db2_orange, "DB2-derived (conflicting baseline)"
    if scraped or abilities.get(spell):
        return db2_orange, "DB2-derived (baseline mismatch)"
    return db2_orange, "DB2-derived (no baseline)"


def generate(ability_rows, skills, selected, names, baseline, outputs, effects):
    stats = {sid: Counter() for sid in selected}
    candidates = defaultdict(list)
    for row in ability_rows:
        sid = int(row["SkillLine"])
        if sid not in selected:
            continue
        counts = stats[sid]
        counts["rows"] += 1
        try:
            spell = int(row["Spell"])
            orange = int(row["MinSkillLineRank"])
            yellow = int(row["TrivialSkillLineRankLow"])
            grey = int(row["TrivialSkillLineRankHigh"])
            if spell <= 0 or min(orange, yellow, grey) < 0:
                raise ValueError
        except (ValueError, TypeError):
            counts["skip:missing/invalid data"] += 1
            continue
        if grey <= yellow:
            counts["skip:grey<=yellow"] += 1
            continue
        # Mining's open-lock gathering abilities have thresholds but are not
        # crafting recipes. Do not emit them as smelting recipes.
        if effects.get(spell) == {33}:
            counts["skip:gathering ability"] += 1
            continue
        orange, source = orange_threshold(spell, yellow, grey, orange, baseline, outputs)
        if orange > yellow:
            source += "; inconsistent orange>yellow"
        t = (orange, yellow, (yellow + grey) // 2, grey)
        candidates[spell].append((sid, t, source))

    emitted = {}
    for spell, rows in sorted(candidates.items()):
        if len({t for _, t, _ in rows}) != 1:
            for sid, _, _ in rows:
                stats[sid]["skip:conflicting recipe rows"] += 1
            continue
        seen = set()
        for sid, thresholds, source in sorted(rows):
            if sid in seen:
                stats[sid]["skip:duplicate recipe row"] += 1
                continue
            seen.add(sid)
            stats[sid]["emitted"] += 1
            stats[sid]["orange:" + source] += 1
            if thresholds[0] > thresholds[1]:
                stats[sid]["inconsistent orange>yellow"] += 1
                print(
                    f"WARNING: recipe {spell} ({names.get(spell, 'SpellName unavailable')}): "
                    f"keeping inconsistent DB2 thresholds {thresholds}",
                    file=sys.stderr,
                )
            if not names.get(spell):
                stats[sid]["missing spell name"] += 1
        emitted[spell] = (rows[0][1], sorted({source for _, _, source in rows}))

    coverage = []
    for sid in sorted(selected):
        counts = stats[sid]
        name = skills.get(sid, {}).get("DisplayName_lang", REQUIRED_SKILLS.get(sid, "Unknown"))
        skipped = sum(value for key, value in counts.items() if key.startswith("skip:"))
        reasons = ", ".join(f"{key[5:]}={value}" for key, value in sorted(counts.items()) if key.startswith("skip:"))
        line = f"{name} ({sid}): {counts['emitted']} emitted / {skipped} skipped"
        if reasons:
            line += f" ({reasons})"
        if counts["inconsistent orange>yellow"]:
            line += f"; inconsistent DB2 orange>yellow={counts['inconsistent orange>yellow']} retained"
        if not counts["rows"]:
            line += "; no SkillLineAbility rows"
        if sid not in skills:
            line += "; MISSING SkillLine"
        coverage.append(line)
        print(line)
        sources = ", ".join(f"{key[7:]}={value}" for key, value in sorted(counts.items()) if key.startswith("orange:"))
        if sources:
            print(f"  Orange: {sources}")
        if counts["missing spell name"]:
            print(f"  Missing SpellName: {counts['missing spell name']} (comments only)")
    return emitted, coverage


def render(emitted, coverage, names):
    lines = [
        "-- Generated by tools/gen_thresholds.py — do not edit.",
        f"-- Source: wago.tools DB2, wow_classic_beta {BUILD}, {SOURCE_DATE}. "
        "Baseline portions derived from Skillet-Classic (GPL-3.0-or-later).",
        f"-- DB2: https://wago.tools/db2/SkillLineAbility/csv?build={BUILD}",
        "-- SkillLine, SpellName, and SpellEffect: same source and build.",
        f"-- Baseline: {SKILLET_URL}",
        "-- {orange, yellow, green, grey}; green = floor((yellow + grey) / 2).",
        "-- Orange provenance follows each name; DB2-derived requirements need a live audit.",
        f"-- {len(emitted)} unique recipe spell IDs; a shared recipe counts in each profession below.",
    ]
    lines.extend("-- " + line for line in coverage)
    lines.extend(["---@type string, SkillUpNamespace", "local _, ns = ...", "ns.Thresholds = {"])
    for spell, (thresholds, sources) in sorted(emitted.items()):
        name = " ".join(names.get(spell, "SpellName unavailable").split())
        values = ", ".join(map(str, thresholds))
        lines.append(f"\t[{spell}] = {{ {values} }}, -- {name}; orange: {', '.join(sources)}")
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--refresh", action="store_true", help="redownload the pinned sources")
    mode.add_argument("--offline", action="store_true", help="use cached sources only")
    args = parser.parse_args()
    options = {"refresh": args.refresh, "offline": args.offline}
    ability_rows = db2(
        "SkillLineAbility",
        (
            "Spell",
            "SkillLine",
            "MinSkillLineRank",
            "TrivialSkillLineRankHigh",
            "TrivialSkillLineRankLow",
        ),
        **options,
    )
    skill_rows = db2(
        "SkillLine",
        (
            "ID",
            "DisplayName_lang",
            "CategoryID",
            "CanLink",
            "ParentSkillLineID",
        ),
        **options,
    )
    name_rows = db2("SpellName", ("ID", "Name_lang"), **options)
    effect_rows = db2(
        "SpellEffect",
        (
            "SpellID",
            "Effect",
            "EffectItemType",
            "DifficultyID",
        ),
        **options,
    )
    # Baseline failure must not discard authoritative DB2 thresholds.
    try:
        baseline = parse_skillet(
            download(
                SKILLET_URL,
                f"SkillLevelData1-{SKILLET_COMMIT}.lua",
                **options,
            )
        )
    except (OSError, ValueError, urllib.error.URLError) as error:
        print(f"WARNING: Skillet baseline unavailable: {error}; using DB2 orange values", file=sys.stderr)
        baseline = ({}, {}, {})
    skills, selected, excluded = professions(skill_rows)
    names = {int(row["ID"]): row["Name_lang"] for row in name_rows}
    outputs, effects = spell_effects(effect_rows)
    emitted, coverage = generate(ability_rows, skills, selected, names, baseline, outputs, effects)
    if not emitted:
        raise ValueError("No usable recipes; leaving existing generated output untouched")
    for sid, name in sorted(excluded.items()):
        print(f"Excluded test skill line: {name} ({sid})")
    missing = [str(sid) for sid in sorted(REQUIRED_SKILLS) if sid not in skills]
    print("Missing required skill lines: " + (", ".join(missing) or "none"))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(render(emitted, coverage, names), encoding="utf-8")
    print(f"Wrote {len(emitted)} unique recipe spell IDs to {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, urllib.error.URLError) as error:
        sys.exit(f"error: {error}")
