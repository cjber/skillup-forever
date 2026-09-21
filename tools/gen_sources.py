#!/usr/bin/env python3
"""Generate where each recipe's scroll comes from, for the pinned Forever client (stdlib only)."""

import argparse
from collections import Counter, defaultdict
import gzip
import re
import sys
import urllib.error

from gen_recipes import put_unique, threshold_ids
from gen_thresholds import BUILD, ROOT, db2
from gen_trainer import (
    CLASSICDB_CACHE, CLASSICDB_COMMIT, PROFESSION_SKILLS, ROW, TEACH_BUILD, classicdb, spell_maps, teach_effects,
)

OUTPUT = ROOT / "Data" / "Sources.lua"
VENDOR_DATA = ROOT / "Data" / "Vendor.lua"
VENDOR_ROW = re.compile(r"\t\[(\d+)\] = \d+,")
RECIPE_CLASS = "9"
DROPS_KEPT = 3
TABLES = (
    "item_template", "npc_vendor", "npc_vendor_template", "creature_template", "creature",
    "creature_loot_template", "reference_loot_template", "quest_template",
)
QUEST_REWARDS = [f"RewItemId{i}" for i in range(1, 5)] + [f"RewChoiceItemId{i}" for i in range(1, 7)]
# FactionTemplate groups: 1 player, 2 Alliance, 4 Horde.
ALLIANCE, HORDE = 2, 4


def parse_rows(line):
    """The value tuples of one extended INSERT, as lists of strings (None for NULL)."""
    rows, i, n = [], line.index("VALUES") + 6, len(line)
    while i < n:
        if line[i] == ";":
            break
        if line[i] != "(":
            i += 1
            continue
        row, value, i = [], None, i + 1
        while True:
            c = line[i]
            if c == "'":
                j, chars = i + 1, []
                while line[j] != "'" or line[j + 1] == "'":
                    if line[j] == "\\" or line[j] == "'":
                        j += 1
                    chars.append(line[j])
                    j += 1
                value, i = "".join(chars), j + 1
            elif c in ",)":
                row.append(value)
                value, i = None, i + 1
                if c == ")":
                    break
            else:
                j = i
                while line[j] not in ",)":
                    j += 1
                value, i = (None if line[i:j] == "NULL" else line[i:j]), j
        rows.append(row)
    return rows


def dump_tables(refresh=False, offline=False):
    classicdb(refresh, offline)  # downloads and caches the dump
    columns, rows, current = {}, defaultdict(list), None
    with gzip.open(CLASSICDB_CACHE, "rt", encoding="utf-8", errors="replace") as dump:
        for line in dump:
            if line.startswith("CREATE TABLE"):
                name = line.split("`")[1]
                current = name if name in TABLES else None
                if current:
                    columns[current] = []
            elif current and line.startswith("  `"):
                columns[current].append(line.split("`")[1])
            elif line.startswith("INSERT INTO") and line.split("`")[1] in TABLES:
                rows[line.split("`")[1]].extend(parse_rows(line))
    missing = set(TABLES) - columns.keys()
    if missing:
        raise ValueError(f"classic-db dump lacks tables {sorted(missing)}")
    return {table: [dict(zip(columns[table], row)) for row in rows[table]] for table in TABLES}


def side(template):
    """"A", "H", or "" for a vendor either faction can use."""
    if template is None:
        return ""
    group = int(template["FactionGroup"]) | int(template["FriendGroup"])
    enemy = int(template["EnemyGroup"])
    alliance = bool(group & ALLIANCE) and not enemy & ALLIANCE
    horde = bool(group & HORDE) and not enemy & HORDE
    return "A" if alliance and not horde else "H" if horde and not alliance else ""


def vendor_items():
    """Reagents gen_vendor.py marks as vendor-sold."""
    items = {int(m[1]) for m in VENDOR_ROW.finditer(VENDOR_DATA.read_text(encoding="utf-8"))}
    if not items:
        raise ValueError("No items in Data/Vendor.lua; run gen_vendor.py first")
    return items


def trainer_caps(trainer_lines, teaches, rank_of):
    """[skill line][npc] = the highest rank cap that trainer teaches."""
    caps = defaultdict(dict)
    for line in trainer_lines:
        for match in ROW.finditer(line):
            entry, spell, _, skill, _, _, ability, _, _, condition = match.groups()
            if int(skill) not in PROFESSION_SKILLS or ability != "NULL" or condition != "0":
                continue
            for taught in teaches.get(int(spell), ()):
                line_cap = rank_of.get(taught)
                if line_cap and line_cap[0] == int(skill):
                    known = caps[int(skill)].get(int(entry), 0)
                    caps[int(skill)][int(entry)] = max(known, line_cap[1])
    if not caps:
        raise ValueError("No profession trainers resolved; leaving existing output untouched")
    return caps


def reagent_vendors(tables, creatures, items):
    """[item] = vendors with it always in stock."""
    sellers = defaultdict(set)
    for row in tables["npc_vendor"]:
        if int(row["item"]) in items and int(row["maxcount"]) == 0:
            sellers[int(row["item"])].add(int(row["entry"]))
    by_template = defaultdict(set)
    for row in tables["npc_vendor_template"]:
        if int(row["item"]) in items and int(row["maxcount"]) == 0:
            by_template[int(row["entry"])].add(int(row["item"]))
    for entry, creature in creatures.items():
        for item in by_template.get(int(creature["VendorTemplateId"] or 0), ()):
            sellers[item].add(entry)
    return sellers


def spawn_of(spawns):
    """One spawn to point at: on the map with most spawns, the one nearest their middle."""
    if not spawns:
        return None
    home = Counter(s[0] for s in spawns).most_common(1)[0][0]
    here = [s for s in spawns if s[0] == home]
    mx = sum(s[1] for s in here) / len(here)
    my = sum(s[2] for s in here) / len(here)
    return min(here, key=lambda s: (s[1] - mx) ** 2 + (s[2] - my) ** 2)


def generate(ids, tables, effect_rows, factions, maps, trainer_lines, items):
    teaches, rank_of = spell_maps(effect_rows)
    scrolls = {}
    for item in tables["item_template"]:
        if item["class"] != RECIPE_CLASS:
            continue
        for k in range(1, 6):
            spell = int(item[f"spellid_{k}"] or 0)
            for taught in teaches.get(spell, set()) | {spell}:
                if taught in ids:
                    put_unique(scrolls, int(item["entry"]), (taught, item), "recipe item")
    if not scrolls:
        raise ValueError("No recipe items resolved; leaving existing output untouched")

    creatures = {int(c["Entry"]): c for c in tables["creature_template"]}
    vendors = defaultdict(dict)
    for row in tables["npc_vendor"]:
        if int(row["item"]) in scrolls:
            vendors[int(row["item"])][int(row["entry"])] = int(row["maxcount"]) > 0
    by_template = defaultdict(dict)
    for row in tables["npc_vendor_template"]:
        if int(row["item"]) in scrolls:
            by_template[int(row["entry"])][int(row["item"])] = int(row["maxcount"]) > 0
    for entry, creature in creatures.items():
        for item, limited in by_template.get(int(creature["VendorTemplateId"] or 0), {}).items():
            vendors[item][entry] = limited
    drops, world = defaultdict(dict), set()
    for row in tables["creature_loot_template"]:
        item, chance = int(row["item"]), float(row["ChanceOrQuestChance"])
        if item in scrolls and int(row["mincountOrRef"]) > 0 and chance > 0:
            drops[item][int(row["entry"])] = chance
    for row in tables["reference_loot_template"]:
        if int(row["item"]) in scrolls:
            world.add(int(row["item"]))
    quests = defaultdict(set)
    titles = {}
    for quest in tables["quest_template"]:
        for column in QUEST_REWARDS:
            if int(quest[column] or 0) in scrolls:
                quests[int(quest[column])].add(int(quest["entry"]))
                titles[int(quest["entry"])] = quest["Title"]

    spawns = defaultdict(list)
    for row in tables["creature"]:
        spawns[int(row["id"])].append((int(row["map"]), float(row["position_x"]), float(row["position_y"])))
    sources, npcs = {}, {}

    def keep(entry):
        spawn = spawn_of(spawns.get(entry))
        if spawn is None or entry not in creatures:
            return False
        creature = creatures[entry]
        npcs[entry] = (creature["Name"], side(factions.get(int(creature["Faction"]))), *spawn)
        return True

    for item, (spell, row) in sorted(scrolls.items()):
        sold = sorted(entry for entry in vendors.get(item, {}) if keep(entry))
        dropped = sorted(drops.get(item, {}).items(), key=lambda kv: (-kv[1], kv[0]))
        dropped = [(entry, chance) for entry, chance in dropped if keep(entry)][:DROPS_KEPT]
        source = {
            "item": item,
            "skill": int(row["RequiredSkillRank"]),
            "price": int(row["BuyPrice"]) if sold else 0,
            "vendors": sold,
            "limited": bool(sold) and all(vendors[item][entry] for entry in sold),
            "drops": dropped,
            "world": item in world,
            "quests": sorted(quests.get(item, ())),
        }
        if sold or dropped or source["world"] or source["quests"]:
            # Several scrolls can teach one recipe: keep the easiest to get.
            best = sources.get(spell)
            if best is None or (not source["vendors"], source["item"]) < (not best["vendors"], best["item"]):
                sources[spell] = source
    trainers = {
        skill: sorted((entry, cap) for entry, cap in caps.items() if keep(entry))
        for skill, caps in trainer_caps(trainer_lines, teaches, rank_of).items()
    }
    reagents = {
        item: sorted(entry for entry in sellers if keep(entry))
        for item, sellers in reagent_vendors(tables, creatures, items).items()
    }
    instances = {int(m["ID"]): m["MapName_lang"] for m in maps if m["InstanceType"] != "0"}
    used_npcs = {e for s in sources.values() for e in s["vendors"] + [d for d, _ in s["drops"]]}
    used_npcs |= {e for rows in trainers.values() for e, _ in rows} | {e for rows in reagents.values() for e in rows}
    return {
        "sources": sources,
        "npcs": {e: npcs[e] for e in used_npcs},
        "titles": {q: titles[q] for s in sources.values() for q in s["quests"]},
        "instances": instances,
        "trainers": trainers,
        "reagents": {item: rows for item, rows in reagents.items() if rows},
    }


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render(data):
    sources, npcs = data["sources"], data["npcs"]
    lines = [
        "-- Generated by tools/gen_sources.py — do not edit.",
        f"-- Source: CMaNGOS classic-db {CLASSICDB_COMMIT} (GPL-3.0): item_template, npc_vendor(_template),",
        "-- creature(_template), creature/reference_loot_template, quest_template. Scroll -> recipe via",
        f"-- wago.tools SpellEffect (LEARN_SPELL), wow_classic_era {TEACH_BUILD}; factions and instance names",
        f"-- from wago.tools FactionTemplate and Map, wow_classic_beta {BUILD}.",
        "-- Trainers: npc_trainer rows whose rank spell (SpellEffect SKILL) sets the new cap.",
        f"-- recipes={len(sources)}, npcs={len(npcs)}.",
        "local _, ns = ...",
        "-- stylua: ignore",
        "-- [recipeID] = { item, skill (required base), price (vendor copper), vendors, limited,",
        "--   drops = { { npc, chance % } }, world (world drop), quests }",
        "ns.RecipeSources = {",
    ]
    for spell, s in sorted(sources.items()):
        parts = [f"item = {s['item']}", f"skill = {s['skill']}"]
        if s["vendors"]:
            parts.append(f"price = {s['price']}")
            parts.append("vendors = { " + ", ".join(map(str, s["vendors"])) + " }")
        if s["limited"]:
            parts.append("limited = true")
        if s["drops"]:
            parts.append("drops = { " + ", ".join(f"{{ {e}, {c:g} }}" for e, c in s["drops"]) + " }")
        if s["world"]:
            parts.append("world = true")
        if s["quests"]:
            parts.append("quests = { " + ", ".join(map(str, s["quests"])) + " }")
        lines.append(f"\t[{spell}] = {{ {', '.join(parts)} }},")
    lines += ["}", "", "-- [npc] = { name, faction (\"A\", \"H\", \"\" for both), world map, world x, world y }",
              "-- stylua: ignore", "ns.SourceNPCs = {"]
    lines += [f"\t[{e}] = {{ {lua_string(n)}, \"{f}\", {m}, {x:.1f}, {y:.1f} }},"
              for e, (n, f, m, x, y) in sorted(npcs.items())]
    lines += ["}", "", "-- [skill line] = { { trainer npc, highest cap it teaches } }", "-- stylua: ignore",
              "ns.ProfessionTrainers = {"]
    for skill, rows in sorted(data["trainers"].items()):
        lines.append(f"\t[{skill}] = {{ " + ", ".join(f"{{ {e}, {c} }}" for e, c in rows) + " },")
    lines += ["}", "", "-- [reagent item] = vendors that always stock it", "-- stylua: ignore", "ns.ReagentVendors = {"]
    for item, rows in sorted(data["reagents"].items()):
        lines.append(f"\t[{item}] = {{ " + ", ".join(map(str, rows)) + " },")
    lines += ["}", "", "-- stylua: ignore", "ns.SourceQuests = {"]
    lines += [f"\t[{q}] = {lua_string(t)}," for q, t in sorted(data["titles"].items())]
    lines += ["}", "", "-- [world map] = dungeon or raid name, for drops the zone map can't show", "-- stylua: ignore",
              "ns.InstanceNames = {"]
    used = {n[2] for n in npcs.values()}
    lines += [f"\t[{m}] = {lua_string(name)}," for m, name in sorted(data["instances"].items()) if m in used]
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--refresh", action="store_true", help="redownload the pinned sources")
    mode.add_argument("--offline", action="store_true", help="use cached sources only")
    args = parser.parse_args()
    options = {"refresh": args.refresh, "offline": args.offline}
    factions = db2("FactionTemplate", ("ID", "FactionGroup", "FriendGroup", "EnemyGroup"), **options)
    data = generate(
        threshold_ids(),
        dump_tables(**options),
        teach_effects(**options),
        {int(row["ID"]): row for row in factions},
        db2("Map", ("ID", "MapName_lang", "InstanceType"), **options),
        classicdb(**options),
        vendor_items(),
    )
    OUTPUT.write_text(render(data), encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}: {len(data['sources'])} recipes, {len(data['npcs'])} npcs, "
          f"{sum(map(len, data['trainers'].values()))} trainers, {len(data['reagents'])} vendor reagents")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, urllib.error.URLError) as error:
        print(f"error: {error}", file=sys.stderr)
        sys.exit(1)
