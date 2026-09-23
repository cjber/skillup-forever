#!/usr/bin/env python3
"""Generate bundled profession trainer fees for the pinned Forever client (stdlib only)."""

import argparse
import csv
import gzip
import io
import re
import sys
import urllib.error
import urllib.request
from collections import Counter, defaultdict

from gen_recipes import put_unique, threshold_ids
from gen_thresholds import BUILD, CACHE, ROOT, download

OUTPUT = ROOT / "Data" / "Trainer.lua"
CLASSICDB_COMMIT = "22b51464f1625f6ef6275771de1f5466c6f5d19e"
CLASSICDB_URL = (
    f"https://raw.githubusercontent.com/cmangos/classic-db/{CLASSICDB_COMMIT}/Full_DB/ClassicDB_1_12_1_z2815.sql.gz"
)
CLASSICDB_CACHE = CACHE / f"classicdb-{CLASSICDB_COMMIT[:7]}.sql.gz"
PROFESSION_SKILLS = {129, 164, 165, 171, 182, 185, 186, 197, 202, 333, 356, 393}
LEARN_SPELL = 36
SKILL = 118  # Sets a skill line's rank: base points 0-3 raise the cap to 75-300.
RANK_SKILL = 75
# Forever's client leaves out the trainers' teaching spells; Classic Era keeps them,
# with the same recipe spell IDs.
TEACH_BUILD = "1.15.9.69722"
# entry, spell, spellcost, reqskill, reqskillvalue, reqlevel, ReqAbility1-3, condition_id
ROW = re.compile(r"\((\d+),(\d+),(\d+),(\d+),(\d+),(\d+),(NULL|\d+),(NULL|\d+),(NULL|\d+),(\d+)\)")


def classicdb(refresh=False, offline=False):
    if not CLASSICDB_CACHE.exists() or refresh:
        if offline:
            raise ValueError(f"Missing cached source: {CLASSICDB_CACHE}")
        request = urllib.request.Request(CLASSICDB_URL, headers={"User-Agent": "SkillUpForever/1.0"})
        with urllib.request.urlopen(request, timeout=120) as response:
            data = response.read()
        temporary = CLASSICDB_CACHE.with_suffix(".tmp")
        CACHE.mkdir(parents=True, exist_ok=True)
        temporary.write_bytes(data)
        temporary.replace(CLASSICDB_CACHE)
    with gzip.open(CLASSICDB_CACHE, "rt", encoding="utf-8", errors="replace") as dump:
        return [line for line in dump if line.startswith("INSERT INTO `npc_trainer` VALUES")]


def teach_effects(refresh=False, offline=False):
    content = download(
        f"https://wago.tools/db2/SpellEffect/csv?build={TEACH_BUILD}",
        f"SpellEffect-{TEACH_BUILD}.csv",
        refresh,
        offline,
    )
    rows = list(csv.DictReader(io.StringIO(content)))
    if (
        not rows
        or not {"SpellID", "DifficultyID", "Effect", "EffectTriggerSpell", "EffectBasePoints", "EffectMiscValue_0"}
        <= rows[0].keys()
    ):
        raise ValueError(f"SpellEffect {TEACH_BUILD}: empty or missing columns")
    return rows


def spell_maps(effect_rows):
    """Teaching spell -> taught spells, and rank spell -> (skill line, new cap)."""
    teaches = defaultdict(set)
    rank_of = {}
    for row in effect_rows:
        if int(row["DifficultyID"]) != 0:
            continue
        if int(row["Effect"]) == LEARN_SPELL:
            teaches[int(row["SpellID"])].add(int(row["EffectTriggerSpell"]))
        elif int(row["Effect"]) == SKILL:
            cap = (int(row["EffectBasePoints"]) + 1) * RANK_SKILL
            put_unique(rank_of, int(row["SpellID"]), (int(row["EffectMiscValue_0"]), cap), "rank effect")
    return teaches, rank_of


def generate(ids, trainer_lines, effect_rows):
    teaches, rank_of = spell_maps(effect_rows)
    # Specialisation-gated rows (condition, required ability) can't be assumed
    # trainable; a recipe offered without a gate anywhere is.
    fees = defaultdict(Counter)
    ranks = defaultdict(Counter)
    for line in trainer_lines:
        for match in ROW.finditer(line):
            _, spell, cost, skill, required, level, ability, _, _, condition = match.groups()
            if int(skill) not in PROFESSION_SKILLS or ability != "NULL" or condition != "0":
                continue
            for taught in teaches.get(int(spell), ()):
                if taught in ids:
                    fees[taught][(int(cost), int(required))] += 1
                if rank_of.get(taught, (None,))[0] == int(skill):
                    ranks[int(skill)][(rank_of[taught][1], int(cost), int(required), int(level))] += 1
    if not fees:
        raise ValueError("No trainer fees resolved; leaving existing output untouched")
    # Duplicate trainers almost always agree; take the most common (fee, skill), cheaper on a tie.
    chosen = {recipe: min(c.items(), key=lambda kv: (-kv[1], kv[0]))[0] for recipe, c in fees.items()}
    conflicts = sorted(recipe for recipe, c in fees.items() if len(c) > 1)
    by_cap = defaultdict(dict)
    for skill, seen in ranks.items():
        for (cap, cost, required, level), count in seen.items():
            best = by_cap[skill].get(cap)
            if best is None or (-count, cost) < (-best[1], best[0][1]):
                by_cap[skill][cap] = ((cap, cost, required, level), count)
    rank_rows = {skill: sorted(entry for entry, _ in caps.values()) for skill, caps in by_cap.items()}
    if not rank_rows:
        raise ValueError("No profession ranks resolved; leaving existing output untouched")
    return chosen, conflicts, rank_rows


def render(fees, conflicts, ranks):
    lines = [
        "-- Generated by tools/gen_trainer.py — do not edit.",
        f"-- Source: CMaNGOS classic-db {CLASSICDB_COMMIT} npc_trainer (GPL-3.0), base fees before",
        "-- reputation discounts; teaching spell -> recipe via wago.tools SpellEffect (LEARN_SPELL),",
        f"-- wow_classic_era {TEACH_BUILD}; recipes limited to wow_classic_beta {BUILD} thresholds.",
        "-- Specialisation-gated rows are left out. Fees seen at a trainer win.",
        f"-- recipes={len(fees)}; conflicts resolved to the most common: {conflicts}.",
        "local _, ns = ...",
        "-- stylua: ignore",
        "-- [recipeID] = { fee in copper, required base skill }",
        "ns.TrainerFees = {",
    ]
    lines.extend(f"\t[{recipe}] = {{ {fee}, {skill} }}," for recipe, (fee, skill) in sorted(fees.items()))
    lines.extend(
        [
            "}",
            "",
            "-- [skill line] = rank trainings above Apprentice: { cap, fee, required base skill, level }",
            "-- stylua: ignore",
            "ns.TrainerRanks = {",
        ]
    )
    for skill, rows in sorted(ranks.items()):
        entries = ", ".join(
            f"{{ {cap}, {cost}, {required}, {level} }}" for cap, cost, required, level in rows if cap > 75
        )
        lines.append(f"\t[{skill}] = {{ {entries} }},")
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--refresh", action="store_true", help="redownload the pinned sources")
    mode.add_argument("--offline", action="store_true", help="use cached sources only")
    args = parser.parse_args()
    options = {"refresh": args.refresh, "offline": args.offline}
    fees, conflicts, ranks = generate(
        threshold_ids(),
        classicdb(**options),
        teach_effects(**options),
    )
    content = render(fees, conflicts, ranks)
    OUTPUT.write_text(content, encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}: {len(fees)} recipes, conflicts {conflicts}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, urllib.error.URLError) as error:
        print(f"error: {error}", file=sys.stderr)
        sys.exit(1)
