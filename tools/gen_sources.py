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
RECIPE_DATA = ROOT / "Data" / "Recipes.lua"
REAGENT = re.compile(r"itemID = (\d+), quantity")
# Lock rows of type LOCK_KEY_SKILL name the gathering skill: 2 Herbalism, 3 Mining.
LOCK_KEY_SKILL = "2"
LOCK_SKILLS = {"2": 182, "3": 186}
SKINNING = 393
CHEST = "3"  # gameobject type; data0 is its lock, data1 its loot
# Below this, a gathered item is a lucky find (gems in veins), not something to plan on.
GATHER_CHANCE = 10
RECIPE_CLASS = "9"
DROPS_KEPT = 3
TABLES = (
    "item_template", "npc_vendor", "npc_vendor_template", "creature_template", "creature",
    "creature_loot_template", "reference_loot_template", "quest_template",
    "gameobject_template", "gameobject_loot_template", "skinning_loot_template",
)
QUEST_REWARDS = [f"RewItemId{i}" for i in range(1, 5)] + [f"RewChoiceItemId{i}" for i in range(1, 7)]
# FactionTemplate groups: 1 player, 2 Alliance, 4 Horde.
ALLIANCE, HORDE = 2, 4
# ChrRaces bits: Human, Dwarf, Night Elf, Gnome; Orc, Undead, Tauren, Troll.
ALLIANCE_RACES, HORDE_RACES = 1 | 4 | 8 | 64, 2 | 16 | 32 | 128
# A scroll this many creatures drop is a world drop, not worth naming three of them. Measured:
# 211 scrolls drop from under 25 creatures (bosses, a dungeon's trash), world drops from 325-780.
WORLD_DROP = 100


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


def reagent_items():
    items = {int(m[1]) for m in REAGENT.finditer(RECIPE_DATA.read_text(encoding="utf-8"))}
    if not items:
        raise ValueError("No reagents in Data/Recipes.lua; run gen_recipes.py first")
    return items


def gathered(tables, locks, items):
    """[reagent] = the gathering skill line that yields it at least GATHER_CHANCE% of the time."""
    lock_skill = {}
    for row in locks:
        for i in range(8):
            if row[f"Type_{i}"] == LOCK_KEY_SKILL and row[f"_Index_{i}"] in LOCK_SKILLS:
                lock_skill[int(row["ID"])] = LOCK_SKILLS[row[f"_Index_{i}"]]
    references = defaultdict(list)
    for row in tables["reference_loot_template"]:
        references[int(row["entry"])].append(row)

    def expand(rows):
        for row in rows:
            count = int(row["mincountOrRef"])
            yield from references[-count] if count < 0 else (row,)

    loot = defaultdict(list)
    for row in tables["gameobject_loot_template"]:
        loot[int(row["entry"])].append(row)
    sources = []  # (skill line, loot rows)
    for node in tables["gameobject_template"]:
        skill = node["type"] == CHEST and lock_skill.get(int(node["data0"] or 0))
        if skill:
            sources.append((skill, loot.get(int(node["data1"] or 0), [])))
    skinning = defaultdict(list)
    for row in tables["skinning_loot_template"]:
        skinning[int(row["entry"])].append(row)
    sources.extend((SKINNING, rows) for rows in skinning.values())
    found = defaultdict(set)
    for skill, rows in sources:
        for row in expand(rows):
            chance = float(row["ChanceOrQuestChance"])
            # Chance 0 is an equal share of its loot group: the node's main yield.
            if int(row["item"]) in items and (chance == 0 or chance >= GATHER_CHANCE):
                found[int(row["item"])].add(skill)
    ambiguous = sorted(item for item, skills in found.items() if len(skills) > 1)
    if ambiguous:
        raise ValueError(f"Reagents gathered by several skills: {ambiguous}")
    return {item: skills.pop() for item, skills in found.items()}


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


def race_side(races):
    """"A" or "H" when only that faction's races may take the quest, else ""."""
    if races and not races & HORDE_RACES:
        return "A"
    if races and not races & ALLIANCE_RACES:
        return "H"
    return ""


def loot_chances(rows):
    """(row, chance %) per loot row; 0 is an equal share of what its group's other chances leave."""
    groups = defaultdict(list)
    for row in rows:
        groups[int(row["groupid"])].append(row)
    for group, members in groups.items():
        given = [float(row["ChanceOrQuestChance"]) for row in members]
        shared = given.count(0)
        rest = max(0.0, 100 - sum(c for c in given if c > 0))
        for row, chance in zip(members, given):
            if chance > 0:
                yield row, chance
            elif chance == 0:
                yield row, 100.0 if group == 0 else rest / shared


def scroll_drops(tables, scrolls):
    """Per scroll, {creature: chance %} through direct and referenced loot; and the world drops, scrolls
    that too many creatures drop to name or that only chests and containers hold."""
    refs, loot = defaultdict(list), defaultdict(list)
    for row in tables["reference_loot_template"]:
        refs[int(row["entry"])].append(row)
    for row in tables["creature_loot_template"]:
        loot[int(row["entry"])].append(row)

    def reached(rows, seen):
        for row in rows:
            ref = -int(row["mincountOrRef"])
            if ref > 0 and ref not in seen:
                seen.add(ref)
                reached(refs[ref], seen)
        return seen

    def dropped(rows, scale, seen):
        for row, chance in loot_chances(rows):
            ref, share = -int(row["mincountOrRef"]), scale * chance / 100
            if ref < 0:
                yield int(row["item"]), share
            elif ref > 0 and ref not in seen:
                yield from dropped(refs[ref], share, seen | {ref})

    drops = defaultdict(dict)
    for entry, rows in loot.items():
        for item, share in dropped(rows, 1.0, frozenset()):
            if item in scrolls and share > 0:
                drops[item][entry] = max(drops[item].get(entry, 0), share * 100)
    world = {item for item, by in drops.items() if len(by) > WORLD_DROP}
    creature_refs = set()
    for rows in loot.values():
        reached(rows, creature_refs)
    for ref in refs.keys() - creature_refs:
        world |= {int(row["item"]) for row in refs[ref] if int(row["item"]) in scrolls} - drops.keys()
    return {item: by for item, by in drops.items() if item not in world}, world


def generate(ids, tables, effect_rows, factions, maps, trainer_lines, items, locks):
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
    drops, world = scroll_drops(tables, scrolls)
    quests = defaultdict(set)
    titles = {}
    for quest in tables["quest_template"]:
        for column in QUEST_REWARDS:
            if int(quest[column] or 0) in scrolls:
                quests[int(quest[column])].add(int(quest["entry"]))
                titles[int(quest["entry"])] = (quest["Title"], race_side(int(quest["RequiredRaces"] or 0)))

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
            "limited": [entry for entry in sold if vendors[item][entry]],
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
        "gathered": gathered(tables, locks, reagent_items()),
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
        "-- Trainers: npc_trainer rows whose rank spell (SpellEffect SKILL) sets the new cap. Gathering:",
        "-- herb/mining node loot (gameobject_template lock -> wago.tools Lock) and skinning_loot_template.",
        f"-- recipes={len(sources)}, npcs={len(npcs)}.",
        "local _, ns = ...",
        "-- stylua: ignore",
        "-- [recipeID] = { item, skill (required base), price (vendor copper), vendors, limited (vendors of those",
        "--   with limited stock),",
        "--   drops = { { npc, chance % } }, world (world drop), quests }",
        "ns.RecipeSources = {",
    ]
    for spell, s in sorted(sources.items()):
        parts = [f"item = {s['item']}", f"skill = {s['skill']}"]
        if s["vendors"]:
            parts.append(f"price = {s['price']}")
            parts.append("vendors = { " + ", ".join(map(str, s["vendors"])) + " }")
        if s["limited"]:
            parts.append("limited = { " + ", ".join(map(str, s["limited"])) + " }")
        if s["drops"]:
            parts.append("drops = { " + ", ".join(f"{{ {e}, {round(c, 2):g} }}" for e, c in s["drops"]) + " }")
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
    lines += ["}", "", f"-- [reagent item] = gathering skill line that yields it ({GATHER_CHANCE}%+ of the time)",
              "-- stylua: ignore", "ns.GatheredBy = {"]
    lines += [f"\t[{item}] = {skill}," for item, skill in sorted(data["gathered"].items())]
    lines += ["}", "", "-- [quest] = { title, faction (\"A\", \"H\", \"\" for both) }", "-- stylua: ignore",
              "ns.SourceQuests = {"]
    lines += [f"\t[{q}] = {{ {lua_string(t)}, \"{f}\" }}," for q, (t, f) in sorted(data["titles"].items())]
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
        db2("Lock", ["ID"] + [f"{c}_{i}" for c in ("Type", "_Index") for i in range(8)], **options),
    )
    OUTPUT.write_text(render(data), encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}: {len(data['sources'])} recipes, {len(data['npcs'])} npcs, "
          f"{sum(map(len, data['trainers'].values()))} trainers, {len(data['reagents'])} vendor reagents, "
          f"{len(data['gathered'])} gathered reagents")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, urllib.error.URLError) as error:
        print(f"error: {error}", file=sys.stderr)
        sys.exit(1)
