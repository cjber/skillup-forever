"""Check which gathered reagents gen_sources keeps, on hand-built loot tables."""

import unittest

from gen_sources import CHEST, gathered

MINE, VEIN, LOOT = "7", "70", "700"


def loot(entry, item, chance, ref=0, group=0):
    return {
        "entry": entry,
        "item": str(item),
        "ChanceOrQuestChance": str(chance),
        "groupid": str(group),
        "mincountOrRef": str(-ref if ref else 1),
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
            [loot(LOOT, 0, 100, ref=10), loot(LOOT, 0, 50, ref=20), loot(LOOT, 4, 0)],
            [
                loot("10", 1, 5),  # a 5% find inside a sure reference
                loot("10", 0, 100, ref=11),
                loot("11", 2, 100),  # a sure drop one reference deeper
                loot("20", 3, 15),  # 15% of a 50% roll: 7.5%
            ],
        )
        self.assertEqual(found, {2: 186, 4: 186})


if __name__ == "__main__":
    unittest.main()
