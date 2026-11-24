#!/usr/bin/env python3
"""Diff the regenerated Data files against the previous ones for lost data (stdlib only).

    python3 tools/check_refresh.py --old <data-dir> --new <data-dir> --fdb <forever-db.zip>

Dumps both Data directories through tools/data_dump.lua (LuaJIT) and fails on a regression: a recipe that lost
its thresholds, reagents, output item, teaching scroll or trainers, a trainer row whose fee was zeroed, a rank
its training, quest or book lost, a scroll that lost its named drops, a reagent that lost its gathering or
creature-loot source, a vendor entry or stock that vanished, a price or threshold zeroed, or a node that lost
its required skill. A refresh's other effects are only reported: a record the new data drops whole (the client
dropped the content), gained entries and prices, moved requirements and chances, changed fees and quantities,
and records added.

forever-db -- the zip at --fdb, or the release pinned in tools/fdb_pin.py fetched into tools/.cache when --fdb
is omitted -- is the second source only where it has facts: it records quests, so a lost rank quest is printed
with its forever-db record; for every other kind it carries nothing and the evidence line says so, rather than
inventing evidence. The zip is checked against the pin's FDB_SHA256 before it is read, whatever fetched it.
"""

import argparse
import hashlib
import io
import json
import shutil
import subprocess
import sys
import tempfile
import zipfile
from collections import Counter
from pathlib import Path

import fdb_pin
import gen_thresholds
from forever_tools import wago

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
CACHE = TOOLS / ".cache"

KINDS = (
    "recipe",
    "craft",
    "trainer_fee",
    "trainer_set",
    "trainer_rank",
    "rank_quest",
    "rank_book",
    "profession_trainers",
    "recipe_scroll",
    "scroll",
    "gather",
    "loot",
    "vendor_price",
    "vendor_stock",
    "node",
)

# What a record's complete disappearance is called, per kind.
GONE = {
    "craft": "lost its reagent and output data",
    "gather": "lost its gathering source",
    "loot": "lost its creature-loot source",
    "node": "lost its required skill",
    "profession_trainers": "lost its trainers",
    "rank_book": "lost its rank books",
    "rank_quest": "lost the quests that teach its ranks",
    "recipe": "lost its thresholds",
    "recipe_scroll": "lost its teaching scroll",
    "scroll": "lost its drop data",
    "trainer_fee": "lost its trainer row",
    "trainer_rank": "lost its rank trainings",
    "trainer_set": "lost its trainers",
    "vendor_price": "lost its vendor price",
    "vendor_stock": "lost its limited-stock vendors",
}


def dump(data):
    """The Data files as tools/data_dump.lua's JSON lines, keyed by (kind, id or name)."""
    if shutil.which("luajit") is None:
        raise SystemExit("check_refresh: luajit is not on PATH")
    records = {}
    with tempfile.TemporaryDirectory(prefix="skillup-refresh-") as scratch:
        lines = Path(scratch) / "data.jsonl"
        subprocess.run(["luajit", str(TOOLS / "data_dump.lua"), str(data), str(lines)], cwd=ROOT, check=True)
        for line in lines.read_text(encoding="utf-8").splitlines():
            record = json.loads(line)
            key = record.get("id") or record.get("name")
            records[(record["kind"], key)] = record
    return records


def fetch_fdb(path):
    """The pinned forever-db zip's bytes: `path`'s when it exists, otherwise fetched into tools/.cache under the
    sha256 name the guard shares. Checked against the pin's FDB_SHA256 before anything reads it. A relative
    path is the workflow's `tools/.cache/...` and resolves against the checkout root."""
    name = f"fdb-{fdb_pin.FDB_SHA256}.zip"
    path = path if path.is_absolute() else ROOT / path
    if path.is_file():
        content = path.read_bytes()
    elif path.parent == CACHE and path.name == name:
        content = wago.fetch(fdb_pin.FDB_URL, CACHE / name, user_agent=gen_thresholds.USER_AGENT, offline=False)
        try:
            verify_fdb(content, path)
        except ValueError:
            # A changed or corrupted cached zip: redownload once, then hold the pin.
            content = wago.fetch(
                fdb_pin.FDB_URL, CACHE / name, user_agent=gen_thresholds.USER_AGENT, refresh=True, offline=False
            )
    else:
        raise SystemExit(f"check_refresh: {path} does not exist")
    verify_fdb(content, path)
    return content


def verify_fdb(content, path):
    """`content`'s sha256, raised against the pin's FDB_SHA256 so the guard never reads another zip."""
    digest = hashlib.sha256(content).hexdigest()
    if digest != fdb_pin.FDB_SHA256:
        raise ValueError(f"check_refresh: {path}: sha256 {digest} does not match the pin's {fdb_pin.FDB_SHA256}")


def member(archive, stem):
    """The archive member holding `stem` under its data/ folder, whatever folder prefix the release packs."""
    found = [name for name in archive.namelist() if name == f"data/{stem}" or name.endswith(f"/data/{stem}")]
    if len(found) != 1:
        raise ValueError(f"check_refresh: expected one data/{stem} member in the release, found {len(found)}")
    return found[0]


def read_fdb(content):
    """The forever-db quests, from the zip's bytes after fetch_fdb checked them against the pin."""
    quests = {}
    with zipfile.ZipFile(io.BytesIO(content)) as archive:
        with archive.open(member(archive, "quest.jsonl")) as rows:
            for row in rows:
                entry = json.loads(row)
                quests[entry["id"]] = entry
    return quests


def evidence(quests, kind, lost):
    """What forever-db says about a regression's records: a rank quest's own record, since forever-db is a quest
    database; for every other kind nothing, said outright rather than invented."""
    if kind != "rank_quest":
        return [f"forever-db carries no {kind} data"]
    lines = []
    for quest_id in lost:
        row = quests.get(quest_id)
        if row:
            lines.append(f"forever-db records quest {quest_id} ({row.get('title')}, xp {row.get('xp') or 0})")
        else:
            lines.append(f"forever-db has no record of quest {quest_id}")
    return lines


def coverage(quests, records):
    """How many of the new data's rank-teaching quests forever-db records; it holds nothing for the rest."""
    named = sorted(
        {
            row["quest"]
            for record in records.values()
            if record["kind"] == "rank_quest"
            for row in record.get("quests") or ()
        }
    )
    carried = [quest_id for quest_id in named if quest_id in quests]
    return (
        f"forever-db records {len(carried)} of the {len(named)} rank-teaching quests the new data names; it "
        "carries nothing for the fees, thresholds, reagents, drops, stock and nodes"
    )


def compare(old, new):
    """The refresh's regressions, which fail it, and its other changes, which are only reported. A regression
    carries the quest ids its forever-db evidence needs (rank quests only; every other kind carries none)."""
    regressions, reports, reported_quests = [], [], []

    def regression(kind, key, text, quests=()):
        regressions.append((kind, key, f"{kind} {key}: {text}", list(quests)))

    def report(text):
        reports.append(text)

    def order(entry):
        kind, key = entry
        return (kind, 0, key, "") if isinstance(key, int) else (kind, 1, 0, key)

    for entry in sorted(set(old) | set(new), key=order):
        kind, key = entry
        was, now = old.get(entry), new.get(entry)
        if was is not None and now is None:
            # A dropped id is the client dropping content, not a broken join, so it reports; only a record that
            # lost its entries below fails the refresh.
            lost = [row["quest"] for row in (was.get("quests") or ())] if kind == "rank_quest" else ()
            report(f"{kind} {key}: {GONE[kind]}")
            reported_quests.extend(lost)
            continue
        if was is None:
            report(f"{kind} {key}: is new")
            continue
        text = f"{kind} {key}"
        if kind == "recipe":
            for field in ("yellow", "green", "grey"):
                had, has = was.get(field) or 0, now.get(field) or 0
                if had > 0 and has == 0:
                    regression(kind, key, f"zeroed its {field} threshold ({had} -> 0)")
                elif had != has:
                    report(f"{text}: {field} threshold moved {had} -> {has}")
            if (was.get("orange") or 0) != (now.get("orange") or 0):
                report(f"{text}: orange threshold {was.get('orange') or 0} -> {now.get('orange') or 0}")
        elif kind == "craft":
            had_items = {row["i"]: row["q"] for row in was.get("reagents") or ()}
            has_items = {row["i"]: row["q"] for row in now.get("reagents") or ()}
            for item in sorted(set(had_items) - set(has_items)):
                regression(kind, key, f"lost reagent {item}")
            for item in sorted(set(has_items) - set(had_items)):
                report(f"{text}: gained reagent {item}")
            for item in sorted(set(had_items) & set(has_items)):
                if had_items[item] != has_items[item]:
                    report(f"{text}: reagent {item} quantity {had_items[item]} -> {has_items[item]}")
            had_out, has_out = was.get("output"), now.get("output")
            if isinstance(had_out, dict):
                if has_out is None or has_out == "none":
                    regression(kind, key, f"lost its output item {had_out['i']}")
                elif has_out["i"] != had_out["i"]:
                    regression(kind, key, f"changed its output item {had_out['i']} -> {has_out['i']}")
                elif has_out["q"] != had_out["q"]:
                    report(f"{text}: output quantity {had_out['q']} -> {has_out['q']}")
            if was.get("skill") != now.get("skill"):
                report(f"{text}: profession line {was.get('skill')} -> {now.get('skill')}")
        elif kind == "trainer_fee":
            had_fee, has_fee = was.get("fee") or 0, now.get("fee") or 0
            if had_fee > 0 and has_fee == 0:
                regression(kind, key, f"zeroed its fee ({had_fee} -> 0)")
            elif had_fee != has_fee:
                report(f"{text}: fee {had_fee} -> {has_fee}")
            if (was.get("req") or 0) != (now.get("req") or 0):
                report(f"{text}: required skill {was.get('req') or 0} -> {now.get('req') or 0}")
        elif kind == "trainer_set":
            had_trainers = set(was.get("trainers") or ())
            has_trainers = set(now.get("trainers") or ())
            for npc in sorted(had_trainers - has_trainers):
                regression(kind, key, f"trainer {npc} no longer teaches it")
            for npc in sorted(has_trainers - had_trainers):
                report(f"{text}: trainer {npc} now teaches it")
        elif kind == "trainer_rank":
            had_ranks = {rank[0]: rank for rank in was.get("ranks") or ()}
            has_ranks = {rank[0]: rank for rank in now.get("ranks") or ()}
            for cap in sorted(set(had_ranks) - set(has_ranks)):
                regression(kind, key, f"lost its rank {cap} training")
            for cap in sorted(set(has_ranks) - set(had_ranks)):
                report(f"{text}: gained a rank {cap} training")
            for cap in sorted(set(had_ranks) & set(has_ranks)):
                if had_ranks[cap][1] > 0 and has_ranks[cap][1] == 0:
                    regression(kind, key, f"zeroed its rank {cap} fee ({had_ranks[cap][1]} -> 0)")
                elif had_ranks[cap][1] != has_ranks[cap][1]:
                    report(f"{text}: rank {cap} fee {had_ranks[cap][1]} -> {has_ranks[cap][1]}")
                for field, index in (("required skill", 2), ("level", 3)):
                    if had_ranks[cap][index] != has_ranks[cap][index]:
                        report(f"{text}: rank {cap} {field} {had_ranks[cap][index]} -> {has_ranks[cap][index]}")
        elif kind == "rank_quest":
            had_quests = {(row["side"], row["cap"]): row for row in was.get("quests") or ()}
            has_quests = {(row["side"], row["cap"]): row for row in now.get("quests") or ()}
            for side_cap in sorted(set(had_quests) - set(has_quests)):
                quest_id = had_quests[side_cap]["quest"]
                regression(
                    kind, key, f"lost its {side_cap[0]} rank {side_cap[1]} quest ({quest_id})", quests=(quest_id,)
                )
            for side_cap in sorted(set(has_quests) - set(had_quests)):
                row = has_quests[side_cap]
                report(f"{text}: gained a {row['side']} rank {row['cap']} quest ({row['quest']})")
            for side_cap in sorted(set(had_quests) & set(has_quests)):
                if had_quests[side_cap]["quest"] != has_quests[side_cap]["quest"]:
                    report(
                        f"{text}: {side_cap[0]} rank {side_cap[1]} quest changed "
                        f"{had_quests[side_cap]['quest']} -> {has_quests[side_cap]['quest']}"
                    )
                if had_quests[side_cap]["req"] != has_quests[side_cap]["req"]:
                    report(
                        f"{text}: {side_cap[0]} rank {side_cap[1]} quest required skill "
                        f"{had_quests[side_cap]['req']} -> {has_quests[side_cap]['req']}"
                    )
                level_was, level_has = had_quests[side_cap].get("level"), has_quests[side_cap].get("level")
                if level_was != level_has:
                    report(f"{text}: {side_cap[0]} rank {side_cap[1]} quest required level {level_was} -> {level_has}")
        elif kind == "rank_book":
            had_books = {row["cap"]: row for row in was.get("books") or ()}
            has_books = {row["cap"]: row for row in now.get("books") or ()}
            for cap in sorted(set(had_books) - set(has_books)):
                regression(kind, key, f"lost its rank {cap} book (item {had_books[cap]['item']})")
            for cap in sorted(set(has_books) - set(had_books)):
                report(f"{text}: gained a rank {cap} book (item {has_books[cap]['item']})")
            for cap in sorted(set(had_books) & set(has_books)):
                if had_books[cap]["fee"] > 0 and has_books[cap]["fee"] == 0:
                    regression(kind, key, f"zeroed its rank {cap} book fee ({had_books[cap]['fee']} -> 0)")
                elif had_books[cap]["fee"] != has_books[cap]["fee"]:
                    report(f"{text}: rank {cap} book fee {had_books[cap]['fee']} -> {has_books[cap]['fee']}")
                for field in ("item", "req", "level"):
                    if had_books[cap][field] != has_books[cap][field]:
                        report(f"{text}: rank {cap} book {field} {had_books[cap][field]} -> {has_books[cap][field]}")
        elif kind == "profession_trainers":
            had_trainers = {row["npc"]: row["cap"] for row in was.get("trainers") or ()}
            has_trainers = {row["npc"]: row["cap"] for row in now.get("trainers") or ()}
            for npc in sorted(set(had_trainers) - set(has_trainers)):
                regression(kind, key, f"trainer {npc} no longer trains it")
            for npc in sorted(set(has_trainers) - set(had_trainers)):
                report(f"{text}: trainer {npc} now trains it")
            for npc in sorted(set(had_trainers) & set(has_trainers)):
                if has_trainers[npc] < had_trainers[npc]:
                    regression(kind, key, f"trainer {npc} no longer teaches rank {had_trainers[npc]}")
                elif has_trainers[npc] > had_trainers[npc]:
                    report(f"{text}: trainer {npc} now teaches rank {has_trainers[npc]}")
        elif kind == "recipe_scroll":
            for field in ("item", "req"):
                if was.get(field) != now.get(field):
                    report(f"{text}: {field} {was.get(field)} -> {now.get(field)}")
        elif kind == "scroll":
            had_drops = {row["npc"]: row["chance"] for row in was.get("drops") or ()}
            has_drops = {row["npc"]: row["chance"] for row in now.get("drops") or ()}
            for npc in sorted(set(had_drops) - set(has_drops)):
                regression(kind, key, f"lost its named drop {npc}")
            for npc in sorted(set(has_drops) - set(had_drops)):
                report(f"{text}: gained a named drop {npc}")
            for npc in sorted(set(had_drops) & set(has_drops)):
                if had_drops[npc] != has_drops[npc]:
                    report(f"{text}: drop {npc} chance {had_drops[npc]} -> {has_drops[npc]}")
            had_world, has_world = bool(was.get("world")), bool(now.get("world"))
            if had_world and not has_world:
                regression(kind, key, "lost its world-drop marking")
            elif has_world and not had_world:
                report(f"{text}: now a world drop")
        elif kind == "gather":
            if was.get("skill") != now.get("skill"):
                report(f"{text}: gathering skill {was.get('skill')} -> {now.get('skill')}")
        elif kind == "vendor_price":
            had_price, has_price = was.get("price") or 0, now.get("price") or 0
            if had_price > 0 and has_price == 0:
                regression(kind, key, f"zeroed its vendor price ({had_price} -> 0)")
            elif had_price != has_price:
                report(f"{text}: price {had_price} -> {has_price}")
        elif kind == "vendor_stock":
            had_stock = {row["npc"]: row["count"] for row in was.get("stock") or ()}
            has_stock = {row["npc"]: row["count"] for row in now.get("stock") or ()}
            for npc in sorted(set(had_stock) - set(has_stock)):
                regression(kind, key, f"vendor {npc} no longer stocks it")
            for npc in sorted(set(has_stock) - set(had_stock)):
                report(f"{text}: vendor {npc} now stocks it")
            for npc in sorted(set(had_stock) & set(has_stock)):
                if had_stock[npc] != has_stock[npc]:
                    report(f"{text}: vendor {npc} stock {had_stock[npc]} -> {has_stock[npc]}")
        elif kind == "node":
            if (was.get("skill"), was.get("req")) != (now.get("skill"), now.get("req")):
                report(
                    f"{text}: now asks {now.get('skill')} at {now.get('req')} "
                    f"(was {was.get('skill')} at {was.get('req')})"
                )
    return regressions, reports, reported_quests


def summary(records):
    counts = Counter(kind for kind, _ in records)
    return ", ".join(f"{kind} {counts[kind]}" for kind in KINDS if counts[kind])


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--old", type=Path, required=True, help="the Data files as the previous pins built them")
    parser.add_argument("--new", type=Path, required=True, help="the Data files as the refreshed pins built them")
    parser.add_argument(
        "--fdb",
        type=Path,
        default=CACHE / f"fdb-{fdb_pin.FDB_SHA256}.zip",
        help="the forever-db release zip, fetched into tools/.cache here when it is absent",
    )
    options = parser.parse_args()
    quests = read_fdb(fetch_fdb(options.fdb))
    old = dump(options.old.resolve())
    new = dump(options.new.resolve())
    regressions, reports, reported_quests = compare(old, new)
    fills = coverage(quests, new)
    if not regressions and not reports:
        print(f"no data changes ({summary(new)})")
        print(fills)
        return 0
    if regressions:
        print(f"REGRESSIONS ({len(regressions)}):")
        for kind, _key, line, lost in regressions:
            print(f"  {line}")
            for note in evidence(quests, kind, lost):
                print(f"    {note}")
    if reports:
        print(f"REPORTED ({len(reports)}):")
        for line in reports:
            print(f"  {line}")
        shown = set()
        for quest_id in reported_quests:
            if quest_id in shown:
                continue
            shown.add(quest_id)
            for note in evidence(quests, "rank_quest", [quest_id]):
                print(f"    {note}")
    print(fills)
    return 1 if regressions else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        sys.exit(f"check_refresh: {error}")
