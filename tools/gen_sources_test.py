"""Check which gathered reagents gen_sources keeps, on hand-built loot tables."""

import unittest
from unittest.mock import patch

import gen_sources
from gen_sources import CHEST, gathered

MINE, VEIN, LOOT = "7", "70", "700"


def loot(entry, item, chance, ref=0, group=0, times=1):
    return {
        "entry": entry,
        "item": str(item),
        "ChanceOrQuestChance": str(chance),
        "groupid": str(group),
        "mincountOrRef": str(-ref if ref else 1),
        "maxcount": str(times),
    }


def lock():
    row = {"ID": MINE}
    for i in range(8):
        row[f"Type_{i}"], row[f"_Index_{i}"] = "0", "0"
    row["Type_0"], row["_Index_0"] = "2", "3"  # LOCK_KEY_SKILL, Mining
    return row


class GatheredTests(unittest.TestCase):
    def found(self, node_loot, references):
        tables = {
            "gameobject_template": [{"type": CHEST, "data0": MINE, "data1": LOOT, "entry": VEIN}],
            "gameobject_loot_template": node_loot,
            "reference_loot_template": references,
            "skinning_loot_template": [],
        }
        return gathered(tables, [lock()], {1, 2, 3, 4})

    def test_references_scale_and_nest(self):
        found = self.found(
            [loot(LOOT, 0, 100, ref=10), loot(LOOT, 0, 50, ref=20)],
            [
                loot("10", 1, 5),  # a 5% find inside a sure reference
                loot("10", 0, 100, ref=11),
                loot("11", 2, 100),  # a sure drop one reference deeper
                loot("20", 3, 15),  # 15% of a 50% roll: 7.5%
            ],
        )
        self.assertEqual(found, {2: 186})

    def test_zero_chance_is_a_share_only_inside_a_group(self):
        found = self.found(
            [
                loot(LOOT, 1, 0),  # no group to share: the server never rolls it
                loot(LOOT, 2, 80, group=1),
                loot(LOOT, 3, 0, group=1),  # the 20% the group's other chance leaves
            ],
            [],
        )
        self.assertEqual(found, {2: 186, 3: 186})

    def test_reference_is_no_member_of_its_group(self):
        refs = {10: [loot("10", 3, 100, group=1), loot("10", 4, 100, group=2), loot("10", 5, 100)]}
        rows = [
            loot(LOOT, 1, 60, group=1),
            loot(LOOT, 2, 0, group=1),  # the 40% the other item leaves: the reference takes none of it
            loot(LOOT, 0, 100, ref=10, group=1),
            loot(LOOT, 0, 30, ref=10, group=2),
        ]
        # Each reference rolls on its own, and only the group of the referenced loot that it names.
        self.assertEqual(sorted(gen_sources.loot_items(rows, refs)), [(1, 0.6), (2, 0.4), (3, 1.0), (4, 0.3)])

    def test_overfull_group_is_an_error(self):
        rows = [loot(LOOT, 1, 60, group=1), loot(LOOT, 2, 60, group=1)]
        with self.assertRaisesRegex(ValueError, "Loot 700 group 1 has chances summing to 120%"):
            list(gen_sources.loot_chances(rows))

    def test_reference_rolls_its_loot_maxcount_times(self):
        refs = {10: [loot("10", 1, 50)]}

        def chance(times):
            return dict(gen_sources.loot_items([loot(LOOT, 0, 40, ref=10, times=times)], refs))[1]

        self.assertAlmostEqual(chance(1), 0.2)
        self.assertAlmostEqual(chance(2), 0.3)  # 40% of at least one of two 50% rolls
        self.assertEqual(chance(0), 0)

    def test_generate_reports_source_without_spawn(self):
        empty = {name: [] for name in gen_sources.TABLES}
        empty["item_template"] = [
            {
                "class": "9",
                "entry": "500",
                "spellid_1": "700",
                "spellid_2": "0",
                "spellid_3": "0",
                "spellid_4": "0",
                "spellid_5": "0",
                "RequiredSkillRank": "1",
                "BuyPrice": "25",
            }
        ]
        empty["npc_vendor"] = [{"item": "500", "entry": "900", "maxcount": "0"}]
        empty["creature_template"] = [
            {"Entry": "900", "Name": "Missing Spawn", "Faction": "1", "VendorTemplateId": "0"}
        ]
        with (
            patch.object(gen_sources, "spell_maps", return_value=({700: {700}}, {})),
            patch.object(gen_sources, "reagent_items", return_value=set()),
            patch.object(gen_sources, "gathered", return_value={}),
            patch.object(gen_sources, "trainer_caps", return_value={}),
        ):
            data = gen_sources.generate(
                {700},
                empty,
                [],
                {1: {"FactionGroup": "2", "FriendGroup": "0", "EnemyGroup": "0"}},
                [],
                set(),
                [],
            )
        self.assertEqual(data["sources"], {})
        self.assertEqual(data["omitted"], {900: "missing creature spawn"})


if __name__ == "__main__":
    unittest.main()
