"""The refresh guard: its compare rules, its LuaJIT dump, and the forever-db pin it reads."""

import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import check_refresh
import fdb_pin


def records(*lines):
    return {(record["kind"], record.get("id") or record.get("name")): record for record in lines}


def compare(old_lines, new_lines):
    return check_refresh.compare(records(*old_lines), records(*new_lines))


class PinTest(unittest.TestCase):
    def test_the_pin_constants_agree(self):
        self.assertRegex(fdb_pin.FDB_SHA256, r"^[0-9a-f]{64}$")
        self.assertTrue(fdb_pin.FDB_URL.endswith(f"/{fdb_pin.FDB_TAG}/{fdb_pin.FDB_ASSET}"))

    def test_verify_rejects_a_zip_off_the_pin(self):
        with self.assertRaises(ValueError):
            check_refresh.verify_fdb(b"not the pinned zip", Path("fdb.zip"))


class GoneTest(unittest.TestCase):
    def test_every_kind_names_what_its_loss_is(self):
        self.assertEqual(set(check_refresh.GONE), set(check_refresh.KINDS))


class CompareTest(unittest.TestCase):
    def test_identical_records_are_no_changes(self):
        lines = [
            {"kind": "recipe", "id": 1, "orange": 1, "yellow": 25, "green": 50, "grey": 75},
            {"kind": "trainer_fee", "id": 1, "fee": 100, "req": 25},
        ]
        regressions, reports, reported = compare(lines, lines)
        self.assertEqual((regressions, reports), ([], []))

    def test_a_lost_record_is_reported_not_a_regression(self):
        # A dropped id is the client dropping content, so the loss reports and never fails the refresh.
        old = [{"kind": "recipe", "id": 818, "orange": 1, "yellow": 25, "green": 50, "grey": 75}]
        regressions, reports, reported = compare(old, [])
        self.assertEqual(regressions, [])
        self.assertEqual(reports, ["recipe 818: lost its thresholds"])
        self.assertEqual(reported, [])

    def test_a_zeroed_threshold_fee_and_price_are_regressions(self):
        for kind, field in (
            ("recipe", "yellow"),
            ("recipe", "green"),
            ("recipe", "grey"),
            ("trainer_fee", "fee"),
            ("vendor_price", "price"),
        ):
            with self.subTest(kind=kind, field=field):
                regressions, _, _ = compare([{"kind": kind, "id": 1, field: 100}], [{"kind": kind, "id": 1, field: 0}])
                self.assertEqual(len(regressions), 1)
                self.assertIn("zeroed", regressions[0][2])
                self.assertIn(field, regressions[0][2])

    def test_a_lost_reagent_and_output_item_are_regressions(self):
        old = [
            {
                "kind": "craft",
                "id": 2149,
                "skill": 165,
                "reagents": [{"i": 2318, "q": 2}, {"i": 2320, "q": 1}],
                "output": {"i": 2302, "q": 1},
            }
        ]
        new = [{"kind": "craft", "id": 2149, "skill": 165, "reagents": [{"i": 2318, "q": 2}], "output": "none"}]
        regressions, reports, reported = compare(old, new)
        self.assertEqual(
            [line[2] for line in regressions],
            ["craft 2149: lost reagent 2320", "craft 2149: lost its output item 2302"],
        )
        self.assertEqual(reports, [])

    def test_lost_trainers_ranks_and_quests_are_regressions(self):
        old = [
            {"kind": "trainer_set", "id": 1, "trainers": [223, 1466]},
            {"kind": "trainer_rank", "id": 164, "ranks": [[150, 500, 50, 10], [225, 4500, 125, 20]]},
            {
                "kind": "rank_quest",
                "id": 129,
                "quests": [
                    {"cap": 300, "quest": 6624, "req": 225, "level": 35, "side": "A"},
                    {"cap": 300, "quest": 6622, "req": 225, "level": 35, "side": "H"},
                ],
            },
            {"kind": "profession_trainers", "id": 185, "trainers": [{"npc": 1355, "cap": 225}]},
        ]
        new = [
            {"kind": "trainer_set", "id": 1, "trainers": [1466]},
            {"kind": "trainer_rank", "id": 164, "ranks": [[150, 500, 50, 10]]},
            {
                "kind": "rank_quest",
                "id": 129,
                "quests": [{"cap": 300, "quest": 6622, "req": 225, "level": 35, "side": "H"}],
            },
            {"kind": "profession_trainers", "id": 185, "trainers": [{"npc": 1355, "cap": 150}]},
        ]
        regressions, reports, reported = compare(old, new)
        self.assertEqual(
            [line[2] for line in regressions],
            [
                "profession_trainers 185: trainer 1355 no longer teaches rank 225",
                "rank_quest 129: lost its A rank 300 quest (6624)",
                "trainer_rank 164: lost its rank 225 training",
                "trainer_set 1: trainer 223 no longer teaches it",
            ],
        )
        # The lost rank quest names itself for forever-db's evidence; the other kinds carry none.
        self.assertEqual([line[3] for line in regressions], [[], [6624], [], []])
        self.assertEqual(reports, [])

    def test_a_lost_rank_quest_line_carries_every_quest_for_evidence(self):
        old = [
            {
                "kind": "rank_quest",
                "id": 129,
                "quests": [{"cap": 300, "quest": 6624, "req": 225, "level": 35, "side": "A"}],
            }
        ]
        regressions, reports, reported = compare(old, [])
        self.assertEqual(regressions, [])
        self.assertEqual(reports, ["rank_quest 129: lost the quests that teach its ranks"])
        self.assertEqual(reported, [6624])

    def test_lost_drops_sources_stock_and_nodes_are_regressions(self):
        old = [
            {"kind": "scroll", "id": 2700, "drops": [{"npc": 14266, "chance": 0.84}]},
            {"kind": "scroll", "id": 2406, "world": True},
            {"kind": "gather", "id": 765, "skill": 182},
            {"kind": "loot", "id": 723},
            {"kind": "vendor_stock", "id": 159, "stock": [{"npc": 7943, "count": 5}]},
            {"kind": "node", "name": "Copper Vein", "skill": 186, "req": 1},
            {"kind": "recipe_scroll", "id": 2158, "item": 2406, "req": 65},
        ]
        regressions, reports, reported = compare(old, [])
        self.assertEqual(regressions, [])
        self.assertEqual(
            sorted(reports),
            sorted(
                [
                    "scroll 2700: lost its drop data",
                    "scroll 2406: lost its drop data",
                    "gather 765: lost its gathering source",
                    "loot 723: lost its creature-loot source",
                    "vendor_stock 159: lost its limited-stock vendors",
                    "node Copper Vein: lost its required skill",
                    "recipe_scroll 2158: lost its teaching scroll",
                ]
            ),
        )
        self.assertEqual(reported, [])

    def test_gains_moves_and_changes_are_only_reported(self):
        old = [
            {"kind": "recipe", "id": 1, "orange": 1, "yellow": 25, "green": 50, "grey": 75},
            {"kind": "trainer_fee", "id": 1, "fee": 100, "req": 25},
            {"kind": "scroll", "id": 7, "drops": [{"npc": 8, "chance": 1.5}], "world": None},
            {"kind": "scroll", "id": 9, "world": True},
            {"kind": "gather", "id": 2, "skill": 182},
            {"kind": "vendor_price", "id": 2, "price": 40},
            {"kind": "vendor_stock", "id": 2, "stock": [{"npc": 5, "count": 3}]},
            {"kind": "node", "name": "Copper Vein", "skill": 186, "req": 1},
        ]
        new = [
            {"kind": "recipe", "id": 1, "orange": 5, "yellow": 30, "green": 65, "grey": 100},
            {"kind": "trainer_fee", "id": 1, "fee": 150, "req": 30},
            {"kind": "scroll", "id": 7, "drops": [{"npc": 8, "chance": 2}, {"npc": 10, "chance": 0.5}]},
            {"kind": "scroll", "id": 9, "drops": [{"npc": 12, "chance": 1}]},
            {"kind": "gather", "id": 2, "skill": 186},
            {"kind": "vendor_price", "id": 2, "price": 50},
            {"kind": "vendor_stock", "id": 2, "stock": [{"npc": 5, "count": 2}, {"npc": 6, "count": 1}]},
            {"kind": "node", "name": "Copper Vein", "skill": 186, "req": 65},
        ]
        regressions, reports, reported = compare(old, new)
        # scroll 9's lost world-drop marking is the one regression; everything else is reported.
        self.assertEqual([line[2] for line in regressions], ["scroll 9: lost its world-drop marking"])
        self.assertIn("recipe 1: yellow threshold moved 25 -> 30", reports)
        self.assertIn("trainer_fee 1: required skill 25 -> 30", reports)
        self.assertIn("scroll 7: gained a named drop 10", reports)
        self.assertIn("scroll 7: drop 8 chance 1.5 -> 2", reports)
        self.assertIn("gather 2: gathering skill 182 -> 186", reports)
        self.assertIn("vendor_price 2: price 40 -> 50", reports)
        self.assertIn("vendor_stock 2: vendor 6 now stocks it", reports)
        self.assertIn("node Copper Vein: now asks 186 at 65 (was 186 at 1)", reports)

    def test_a_new_record_is_reported_and_a_lost_one_named_per_kind(self):
        for kind in check_refresh.KINDS:
            with self.subTest(kind=kind):
                key = "name" if kind == "node" else "id"
                value = "Copper Vein" if kind == "node" else 1
                record = {"kind": kind, key: value}
                regressions, reports, reported = compare([record], [])
                self.assertEqual(regressions, [])
                self.assertEqual(reports, [f"{kind} {value}: {check_refresh.GONE[kind]}"])
                self.assertEqual(compare([], [record])[1], [f"{kind} {value}: is new"])


class DumpTest(unittest.TestCase):
    def test_the_luajit_dump_reads_generated_files_through_a_stub_ns(self):
        if shutil.which("luajit") is None:
            self.skipTest("luajit is not on PATH")
        with tempfile.TemporaryDirectory() as scratch:
            data = Path(scratch) / "Data"
            data.mkdir()
            (data / "Thresholds.lua").write_bytes(b"local _, ns = ...\nns.Thresholds = { [818] = { 1, 25, 50, 75 } }\n")
            (data / "Recipes.lua").write_bytes(
                b"local _, ns = ...\n"
                b"ns.RecipeData = { [818] = { skillLine = 185, reagents = { { itemID = 4470, quantity = 1 } },"
                b" output = false } }\n"
                b"ns.RecipeScrolls = { [818] = { 2700, 110 } }\n"
                b"ns.RankBooks = { [185] = { { 225, 16072, 10000, 125, 0 } } }\n"
            )
            (data / "Trainer.lua").write_bytes(
                b"local _, ns = ...\n"
                b"ns.TrainerFees = { [818] = { 50, 15 } }\n"
                b"ns.TrainerSets = { [1] = { 223 } }\n"
                b"ns.RecipeTrainerSets = { [818] = 1 }\n"
                b"ns.TrainerRanks = { [185] = { { 150, 500, 50, 0 } } }\n"
                b"ns.RankQuests = { [185] = { { 225, 6610, 125, 35, 'H' } } }\n"
                b"ns.ProfessionTrainers = { [185] = { { 1355, 150 } } }\n"
            )
            (data / "Sources.lua").write_bytes(
                b"local _, ns = ...\n"
                b"ns.ScrollDrops = { [2700] = { { 14266, 0.84 } } }\n"
                b"ns.WorldDrops = { [2701] = true }\n"
                b"ns.GatheredBy = { [765] = 182 }\n"
                b"ns.LootedFrom = { [723] = true }\n"
                b"ns.LimitedStock = { [765] = { [1313] = 3 } }\n"
                b"ns.NodeSkills = { ['Copper Vein'] = { 186, 1 } }\n"
            )
            (data / "Vendor.lua").write_bytes(b"local _, ns = ...\nns.VendorPrices = { [765] = 50 }\n")
            dumped = check_refresh.dump(data)
        self.assertEqual(
            dumped[("recipe", 818)], {"kind": "recipe", "id": 818, "orange": 1, "yellow": 25, "green": 50, "grey": 75}
        )
        self.assertEqual(
            dumped[("craft", 818)],
            {"kind": "craft", "id": 818, "skill": 185, "reagents": [{"i": 4470, "q": 1}], "output": "none"},
        )
        self.assertEqual(dumped[("trainer_set", 818)], {"kind": "trainer_set", "id": 818, "trainers": [223]})
        self.assertEqual(
            dumped[("trainer_rank", 185)], {"kind": "trainer_rank", "id": 185, "ranks": [[150, 500, 50, 0]]}
        )
        self.assertEqual(
            dumped[("rank_quest", 185)],
            {
                "kind": "rank_quest",
                "id": 185,
                "quests": [{"cap": 225, "quest": 6610, "req": 125, "level": 35, "side": "H"}],
            },
        )
        self.assertEqual(
            dumped[("profession_trainers", 185)],
            {"kind": "profession_trainers", "id": 185, "trainers": [{"npc": 1355, "cap": 150}]},
        )
        self.assertEqual(dumped[("recipe_scroll", 818)], {"kind": "recipe_scroll", "id": 818, "item": 2700, "req": 110})
        self.assertEqual(
            dumped[("scroll", 2700)], {"kind": "scroll", "id": 2700, "drops": [{"npc": 14266, "chance": 0.84}]}
        )
        self.assertEqual(dumped[("scroll", 2701)], {"kind": "scroll", "id": 2701, "world": True})
        self.assertEqual(dumped[("gather", 765)], {"kind": "gather", "id": 765, "skill": 182})
        self.assertEqual(dumped[("loot", 723)], {"kind": "loot", "id": 723})
        self.assertEqual(dumped[("vendor_price", 765)], {"kind": "vendor_price", "id": 765, "price": 50})
        self.assertEqual(
            dumped[("vendor_stock", 765)], {"kind": "vendor_stock", "id": 765, "stock": [{"npc": 1313, "count": 3}]}
        )
        self.assertEqual(
            dumped[("node", "Copper Vein")], {"kind": "node", "name": "Copper Vein", "skill": 186, "req": 1}
        )
        self.assertEqual(
            dumped[("rank_book", 185)],
            {
                "kind": "rank_book",
                "id": 185,
                "books": [{"cap": 225, "item": 16072, "fee": 10000, "req": 125, "level": 0}],
            },
        )

    def test_the_dump_is_byte_identical_for_the_same_data(self):
        if shutil.which("luajit") is None:
            self.skipTest("luajit is not on PATH")
        data = Path(__file__).resolve().parent.parent / "Data"
        with tempfile.TemporaryDirectory() as scratch:
            lines = []
            for run in range(2):
                path = Path(scratch) / f"data-{run}.jsonl"
                subprocess.run(
                    ["luajit", str(check_refresh.TOOLS / "data_dump.lua"), str(data), str(path)],
                    cwd=check_refresh.ROOT,
                    check=True,
                )
                lines.append(path.read_bytes())
        self.assertEqual(lines[0], lines[1])


class EvidenceTest(unittest.TestCase):
    def test_only_rank_quests_carry_forever_db_evidence(self):
        self.assertEqual(
            check_refresh.evidence({}, "trainer_fee", ()),
            ["forever-db carries no trainer_fee data"],
        )
        quests = {6622: {"title": "Triage", "xp": 3900}}
        self.assertEqual(
            check_refresh.evidence(quests, "rank_quest", (6622, 6623)),
            ["forever-db records quest 6622 (Triage, xp 3900)", "forever-db has no record of quest 6623"],
        )


class CoverageTest(unittest.TestCase):
    def test_coverage_counts_the_new_data_s_rank_quests(self):
        records = {
            ("rank_quest", 129): {"kind": "rank_quest", "id": 129, "quests": [{"quest": 6624}, {"quest": 6622}]},
            ("trainer_fee", 1): {"kind": "trainer_fee", "id": 1, "fee": 50, "req": 15},
        }
        line = check_refresh.coverage({6622: {"title": "Triage"}}, records)
        self.assertEqual(
            line,
            "forever-db records 1 of the 2 rank-teaching quests the new data names; it "
            "carries nothing for the fees, thresholds, reagents, drops, stock and nodes",
        )


if __name__ == "__main__":
    unittest.main()
