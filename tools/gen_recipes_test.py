"""Rank books: the profession ranks an item teaches, from the client's spell and item tables."""

import unittest

from gen_recipes import XP_BONUS, buff_effects, buff_items, rank_books


def effect(spell, kind, trigger=0, points=0, misc=0):
    return {
        "SpellID": str(spell),
        "DifficultyID": "0",
        "Effect": str(kind),
        "EffectTriggerSpell": str(trigger),
        "EffectBasePointsF": str(points),
        "EffectMiscValue_0": str(misc),
    }


def item(item_id, price=10000, required=125, level=0, flags=0):
    return {
        "ID": str(item_id),
        "BuyPrice": str(price),
        "RequiredSkillRank": str(required),
        "RequiredLevel": str(level),
        "Flags_0": str(flags),
    }


class RankBookTests(unittest.TestCase):
    # Issue #121: Forever's Expert First Aid (7924, tier 3) is taught by spell 19903, which the book 16084 casts.
    effects = [
        effect(7924, 118, points=3, misc=129),
        effect(19903, 36, trigger=7924),
        effect(10846, 118, points=4, misc=129),
        effect(19902, 36, trigger=10846),
        effect(3279, 44, points=1, misc=129),
    ]
    item_effects = [{"ID": "100023", "SpellID": "19903"}, {"ID": "100024", "SpellID": "19902"}]
    links = [{"ItemID": "16084", "ItemEffectID": "100023"}, {"ItemID": "16085", "ItemEffectID": "100024"}]

    def test_book_teaches_its_rank(self):
        books = rank_books(self.effects, [item(16084)], self.item_effects, self.links, {129})
        # The Artisan book 16085 isn't in this build's ItemSparse, so it teaches nobody.
        self.assertEqual(books, {129: [(225, 16084, 10000, 125, 0)]})

    def test_deprecated_or_foreign_books_are_left_out(self):
        self.assertEqual(rank_books(self.effects, [item(16084, flags=0x10)], self.item_effects, self.links, {129}), {})
        self.assertEqual(rank_books(self.effects, [item(16084)], self.item_effects, self.links, {185}), {})

    def test_lowest_requirement_wins(self):
        links = [*self.links, {"ItemID": "20000", "ItemEffectID": "100023"}]
        rows = [item(16084), item(20000, price=500, required=100)]
        books = rank_books(self.effects, rows, self.item_effects, links, {129})
        self.assertEqual(books, {129: [(225, 20000, 500, 100, 0)]})

    def test_contradictory_book_fails(self):
        with self.assertRaisesRegex(ValueError, "Rank book 16084"):
            rank_books(self.effects, [item(16084, required=225)], self.item_effects, self.links, {129})

    def test_a_book_asking_no_skill_is_kept(self):
        books = rank_books(self.effects, [item(16084, required=0)], self.item_effects, self.links, {129})
        self.assertEqual(books, {129: [(225, 16084, 10000, 0, 0)]})


def spell_effect(spell, kind, aura=0, target=1, trigger=0, index=0, misc=0):
    return {
        "SpellID": str(spell),
        "DifficultyID": "0",
        "EffectIndex": str(index),
        "Effect": str(kind),
        "EffectAura": str(aura),
        "EffectMiscValue_0": str(misc),
        "ImplicitTarget_0": str(target),
        "EffectTriggerSpell": str(trigger),
    }


class BuffItemTests(unittest.TestCase):
    # Issue #357, shapes from Forever 1.60.1.70862: Crocolisk Steak (3662) casts Nutritious Food (1248382), which
    # triggers the seated Food (434) and, through a periodic trigger, Well Fed (1248420).
    effects = [
        spell_effect(1248382, 64, trigger=434),
        spell_effect(1248382, 6, aura=227, trigger=1248420),
        spell_effect(434, 6, aura=84),
        spell_effect(1248420, 6, aura=29),
        spell_effect(2367, 6, aura=29),  # Lesser Strength, Elixir of Minor Strength (2454)
        spell_effect(4042, 10),  # Healing Potion (929): a heal, no aura
        spell_effect(2829, 54, target=0),  # Sharpen Blade II, Coarse Sharpening Stone (2863)
        spell_effect(4064, 2, target=16, trigger=4065),  # a bomb's damage on its target
        spell_effect(4065, 6, aura=12),
    ]
    interrupts = [
        {"SpellID": "434", "DifficultyID": "0", "AuraInterruptFlags_0": str(0x40080)},
        {"SpellID": "1248382", "DifficultyID": "0", "AuraInterruptFlags_0": str(0x40080)},
    ]

    def buffs(self, uses, outputs=None, trigger_type=0, charges=-1):
        item_effects = [
            {"ID": str(100 + i), "TriggerType": str(trigger_type), "Charges": str(charges), "SpellID": str(spell)}
            for i, (_, spell) in enumerate(uses)
        ]
        links = [{"ItemID": str(item), "ItemEffectID": str(100 + i)} for i, (item, _) in enumerate(uses)]
        outputs = {item for item, _ in uses} if outputs is None else outputs
        return buff_items(outputs, item_effects, links, self.effects, self.interrupts)

    def test_a_meal_names_its_well_fed_not_the_eating(self):
        self.assertEqual(self.buffs([(3662, 1248382)]), {3662: 1248420})

    def test_eating_alone_is_no_buff(self):
        self.assertEqual(self.buffs([(2287, 434)]), {})

    def test_an_elixir_and_a_stone_are_buffs(self):
        self.assertEqual(self.buffs([(2454, 2367), (2863, 2829)]), {2454: 2367, 2863: 2829})

    def test_a_heal_and_a_bomb_are_not(self):
        self.assertEqual(self.buffs([(929, 4042), (4358, 4064)]), {})

    def test_gear_a_use_does_not_consume_is_left_out(self):
        self.assertEqual(self.buffs([(2454, 2367)], charges=0), {})

    def test_only_a_use_counts_and_only_crafted_items(self):
        self.assertEqual(self.buffs([(2454, 2367)], trigger_type=1), {})
        self.assertEqual(self.buffs([(2454, 2367)], outputs=set()), {})


class BuffEffectTests(unittest.TestCase):
    # Issue #461: the first aura a buff spell applies names its row; the XP bonus a meal also triggers does not.
    effects = [
        spell_effect(1248420, 6, aura=29, misc=1),  # Well Fed: Agility
        spell_effect(1248420, 6, aura=99, misc=0, index=1),
        spell_effect(1249521, 6, aura=30, misc=356),  # Well Fed: Fishing Skill
        spell_effect(1249907, 6, aura=30, misc=2944),  # Well Fed: a child Herbalism line
        spell_effect(2829, 54, target=0),  # Sharpen Blade II: an enchant, no aura
        spell_effect(XP_BONUS, 6, aura=200),
        spell_effect(200, 6, aura=29, misc=2, trigger=XP_BONUS),
    ]

    def test_the_first_aura_names_the_row(self):
        effects = buff_effects({1248420, 1249521}, self.effects)
        self.assertEqual(effects, {1248420: (29, 1), 1249521: (30, 356)})

    def test_a_child_skill_line_names_its_profession(self):
        # 2944 is Herbalism's child line in the same build; a parent line (356, Fishing) stays as it is.
        effects = buff_effects({1249521, 1249907}, self.effects, {2944: 182, 356: 0})
        self.assertEqual(effects, {1249521: (30, 356), 1249907: (30, 182)})

    def test_a_spell_without_an_aura_has_no_effect(self):
        self.assertEqual(buff_effects({2829}, self.effects), {})

    def test_the_xp_bonus_is_never_the_row(self):
        self.assertEqual(buff_effects({XP_BONUS}, self.effects), {})
        self.assertEqual(buff_effects({200}, self.effects), {})


if __name__ == "__main__":
    unittest.main()
