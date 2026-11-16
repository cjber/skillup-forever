"""Reject source decoding errors instead of changing generated names."""

import gzip
import re
import tempfile
import unittest
from pathlib import Path

from gen_trainer import (
    ROOT,
    SEEN_REQUIREMENTS,
    dump_tables,
    generate,
    rank_quests,
    recipe_levels,
    recipe_trainers,
    render,
)


class DumpEncodingTests(unittest.TestCase):
    def test_invalid_utf8_is_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "dump.sql.gz"
            with gzip.open(path, "wb") as stream:
                stream.write(b"CREATE TABLE `npc` (\n  `Name` text\n);\nINSERT INTO `npc` VALUES ('D\xfforf');\n")
            with self.assertRaises(UnicodeDecodeError):
                dump_tables(path, {"npc"})

    def test_valid_utf8_name_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "dump.sql.gz"
            with gzip.open(path, "wt", encoding="utf-8") as stream:
                stream.write("CREATE TABLE `npc` (\n  `Name` text\n);\nINSERT INTO `npc` VALUES ('Dörf');\n")
            self.assertEqual(dump_tables(path, {"npc"}), {"npc": [{"Name": "Dörf"}]})


class RequirementTests(unittest.TestCase):
    def trainer(self, spell, required):
        return {
            "entry": "1",
            "spell": str(spell),
            "spellcost": "900",
            "reqskill": "164",
            "reqskillvalue": str(required),
            "reqlevel": "0",
            "ReqAbility1": None,
            "condition_id": "0",
        }

    # Issue #107: classic-db's 125 for Heavy Sharpening Stone is above Forever's grey 115 for it.
    def test_requirement_moves_with_the_recipe_range(self):
        effects = [
            {"SpellID": str(teach), "DifficultyID": "0", "Effect": "36", "EffectTriggerSpell": str(taught)}
            for teach, taught in ((10, 2674), (11, 9985), (12, 3), (13, 99))
        ]
        effects.append(
            {"SpellID": "99", "DifficultyID": "0", "Effect": "118", "EffectBasePoints": "1", "EffectMiscValue_0": "164"}
        )
        trainer = [self.trainer(10, 125), self.trainer(11, 125), self.trainer(12, 10), self.trainer(13, 50)]
        fees, _, _, inferred = generate({2674, 9985, 3}, trainer, effects, {2674: -25, 3: -25})
        self.assertEqual(fees[2674], (900, 100))
        self.assertEqual(fees[9985], (900, 125))
        self.assertEqual(fees[3], (900, 1))
        # Issue #124: a moved requirement keeps classic-db's, so a trainer visit can confirm or correct it.
        self.assertEqual(inferred, {2674: 125, 3: 10})

    # Issue #123: a player made Bronze Warhammer at 110 on Forever, where classic-db (unmoved) says 125.
    def test_a_requirement_players_saw_lower_comes_down(self):
        effects = [
            {"SpellID": str(teach), "DifficultyID": "0", "Effect": "36", "EffectTriggerSpell": str(taught)}
            for teach, taught in ((10, 9985), (11, 2674), (13, 99))
        ]
        effects.append(
            {"SpellID": "99", "DifficultyID": "0", "Effect": "118", "EffectBasePoints": "1", "EffectMiscValue_0": "164"}
        )
        trainer = [self.trainer(10, 125), self.trainer(11, 125), self.trainer(13, 50)]
        fees, _, _, inferred = generate({9985, 2674}, trainer, effects, {2674: -25}, {9985: 110, 2674: 105})
        self.assertEqual(fees[9985], (900, 110))
        # A lower requirement the rule already gives is never raised to what players saw.
        self.assertEqual(fees[2674], (900, 100))
        # It is still a guess: /skillup trainers lists it with classic-db's number for a trainer to confirm.
        self.assertEqual(inferred, {9985: 125, 2674: 125})

    # The bundled data keeps what players saw: every SEEN_REQUIREMENTS recipe at or below its value, never below 1.
    def test_bundled_requirements_players_saw_lower_hold(self):
        text = (ROOT / "Data" / "Trainer.lua").read_text(encoding="utf-8")
        for recipe, most in SEEN_REQUIREMENTS.items():
            row = re.search(rf"\n\t\[{recipe}\] = {{ \d+, (\d+) }},", text)
            assert row is not None, recipe
            self.assertTrue(1 <= int(row.group(1)) <= most, recipe)

    # Issue #124: a Leatherworking trainer showed Gray Leather Boots at 35, where the rule gave 75 (classic-db 100).
    # The trainer visit confirmed the rule for the eight other moved recipes it listed.
    def test_gray_leather_boots_asks_what_the_trainer_showed(self):
        text = (ROOT / "Data" / "Trainer.lua").read_text(encoding="utf-8")
        self.assertRegex(text, r"\n\t\[2167\] = \{ \d+, 35 \},")

    def test_unmoved_zero_requirement_is_not_inferred(self):
        effects = [
            {"SpellID": str(teach), "DifficultyID": "0", "Effect": "36", "EffectTriggerSpell": str(taught)}
            for teach, taught in ((10, 5), (13, 99))
        ]
        effects.append(
            {"SpellID": "99", "DifficultyID": "0", "Effect": "118", "EffectBasePoints": "1", "EffectMiscValue_0": "164"}
        )
        trainer = [self.trainer(10, 0), self.trainer(13, 50)]
        fees, _, _, inferred = generate({5}, trainer, effects)
        self.assertEqual(fees[5], (900, 1))
        self.assertEqual(inferred, {})

    def test_clamped_requirements_keep_the_strictest(self):
        effects = [
            {"SpellID": str(teach), "DifficultyID": "0", "Effect": "36", "EffectTriggerSpell": str(taught)}
            for teach, taught in ((10, 5), (11, 5), (13, 99))
        ]
        effects.append(
            {"SpellID": "99", "DifficultyID": "0", "Effect": "118", "EffectBasePoints": "1", "EffectMiscValue_0": "164"}
        )
        for order in ((20, 5), (5, 20)):
            trainer = [self.trainer(10, order[0]), self.trainer(11, order[1]), self.trainer(13, 50)]
            _, _, _, inferred = generate({5}, trainer, effects, {5: -25})
            self.assertEqual(inferred, {5: 20})


def table(text, name):
    """One generated Lua table's body, without its comment or the closing brace."""
    body = re.search(rf"ns\.{name} = \{{\n(.*?)\n\}}", text, re.S)
    assert body is not None, name
    return body.group(1)


def entries(body):
    """[key] = value rows, as integers."""
    return {int(key): int(value) for key, value in re.findall(r"\n\t\[(\d+)\] = (\d+),", body)}


class RecipeTrainerTests(unittest.TestCase):
    # Issue #722: Una and Telonis teach Barbaric Shoulders and Guardian Gloves, Drakk Stonehand does not,
    # though his Artisan cap covers them.
    def trainer(self, entry, spell, level="0", skill="165"):
        return {
            "entry": str(entry),
            "spell": str(spell),
            "spellcost": "900",
            "reqskill": skill,
            "reqskillvalue": "0",
            "reqlevel": level,
            "ReqAbility1": None,
            "condition_id": "0",
        }

    def effects(self, *pairs):
        return [
            {"SpellID": str(teach), "DifficultyID": "0", "Effect": "36", "EffectTriggerSpell": str(taught)}
            for teach, taught in pairs
        ]

    def test_trainers_teaching_the_same_recipes_share_one_set(self):
        effects = self.effects((10, 100), (10, 200), (11, 100), (12, 300))
        trainer = [
            self.trainer(1, 10),
            self.trainer(2, 10),
            self.trainer(3, 11),
            self.trainer(4, 12),
            self.trainer(5, 13),  # teaches no bundled recipe, so it names no set
        ]
        self.assertEqual(
            recipe_trainers({100, 200, 300}, trainer, effects),
            ({100: 1, 200: 2, 300: 3}, [(1, 2, 3), (1, 2), (4,)]),
        )

    def test_a_recipe_no_trainer_teaches_names_no_set(self):
        found, sets = recipe_trainers({100, 400}, [self.trainer(1, 10)], self.effects((10, 100)))
        self.assertEqual((found, sets), ({100: 1}, [(1,)]))

    def test_a_level_above_zero_is_kept_and_a_disagreement_refused(self):
        effects = self.effects((10, 100), (11, 200), (12, 300))
        trainer = [
            self.trainer(1, 10, level="35"),
            self.trainer(2, 10),
            self.trainer(3, 11, level="35"),
            self.trainer(4, 11, level="40"),
            self.trainer(5, 12),
        ]
        self.assertEqual(recipe_levels({100, 200, 300}, [trainer[0], trainer[1], trainer[4]], effects), {100: 35})
        with self.assertRaisesRegex(ValueError, "disagree on the level for recipe 200"):
            recipe_levels({100, 200, 300}, trainer, effects)

    def test_render_emits_the_sets_the_recipes_name(self):
        rendered = render({}, [], {}, {}, None, ({100: 1}, [(3007, 4212)]), {100: 35})
        self.assertIn("ns.TrainerSets = {\n\t[1] = { 3007, 4212 },\n}", rendered)
        self.assertIn("ns.RecipeTrainerSets = {\n\t[100] = 1,\n}", rendered)
        self.assertIn("ns.TrainerLevels = {\n\t[100] = 35,\n}", rendered)

    def test_barbaric_shoulders_names_una_and_telonis_alone(self):
        text = (ROOT / "Data" / "Trainer.lua").read_text(encoding="utf-8")
        chosen, sets = entries(table(text, "RecipeTrainerSets")), table(text, "TrainerSets")
        self.assertEqual(chosen[7151], chosen[7156])
        members = re.search(rf"\n\t\[{chosen[7151]}\] = \{{ ([^}}]+) \}},", sets)
        assert members is not None
        self.assertEqual([int(npc) for npc in members.group(1).split(", ")], [3007, 4212])

    def test_runecloth_bandages_ask_level_35(self):
        levels = entries(table((ROOT / "Data" / "Trainer.lua").read_text(encoding="utf-8"), "TrainerLevels"))
        self.assertEqual((levels.get(18629), levels.get(18630)), (35, 35))


class RankQuestTests(unittest.TestCase):
    # Issue #121: Artisan First Aid comes from Triage (one quest a side), Artisan Cooking from Clamlette Surprise.
    EFFECTS = [
        {"SpellID": "10846", "DifficultyID": "0", "Effect": "118", "EffectBasePoints": "3", "EffectMiscValue_0": "129"},
        {"SpellID": "10847", "DifficultyID": "0", "Effect": "36", "EffectTriggerSpell": "10846"},
        {"SpellID": "18260", "DifficultyID": "0", "Effect": "118", "EffectBasePoints": "3", "EffectMiscValue_0": "185"},
        {"SpellID": "18261", "DifficultyID": "0", "Effect": "36", "EffectTriggerSpell": "18260"},
        {"SpellID": "500", "DifficultyID": "0", "Effect": "36", "EffectTriggerSpell": "501"},
    ]

    @staticmethod
    def quest(entry, spell, cast, races, skill="0", required="0", level="35"):
        return {
            "entry": str(entry),
            "RewSpell": str(spell),
            "RewSpellCast": str(cast),
            "RequiredRaces": str(races),
            "RequiredSkill": skill,
            "RequiredSkillValue": required,
            "MinLevel": level,
        }

    def test_quests_that_teach_a_rank(self):
        quests = [
            self.quest(6624, 10846, 10847, 77, "129", "225"),
            self.quest(6622, 0, 10847, 178, "129", "225"),
            self.quest(6610, 18260, 0, 255, "185", "225"),
            # A reward spell that teaches no rank, and a quest with none, are not rank quests.
            self.quest(7000, 500, 0, 0),
            self.quest(7001, 0, 0, 0),
        ]
        self.assertEqual(
            rank_quests(quests, self.EFFECTS),
            {
                129: [(300, 6624, 225, 35, "A"), (300, 6622, 225, 35, "H")],
                185: [(300, 6610, 225, 35, "A"), (300, 6610, 225, 35, "H")],
            },
        )

    def test_the_quest_asking_least_wins_per_side(self):
        quests = [self.quest(9001, 18260, 0, 0, "185", "250"), self.quest(9000, 0, 18261, 77, "185", "225")]
        self.assertEqual(
            rank_quests(quests, self.EFFECTS), {185: [(300, 9000, 225, 35, "A"), (300, 9001, 250, 35, "H")]}
        )

    def test_a_requirement_at_the_cap_is_refused(self):
        with self.assertRaises(ValueError):
            rank_quests([self.quest(1, 18260, 0, 0, "185", "300")], self.EFFECTS)
