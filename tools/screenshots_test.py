"""Check screenshots.py's ports of the addon's Lua against the Lua's results, without Pillow or wowmock."""

import ast
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SOURCE = Path(__file__).with_name("screenshots.py")


class CommandLineTests(unittest.TestCase):
    def invoke(self, *args):
        with tempfile.TemporaryDirectory() as directory:
            return subprocess.run(
                [sys.executable, "-S", str(SOURCE), *args],
                env={**os.environ, "FOREVER_CORE": directory},
                text=True,
                capture_output=True,
                timeout=10,
            )

    def test_help_exits_before_renderer_dependencies(self):
        result = self.invoke("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("usage:", result.stdout)
        self.assertIn("Render the README screenshots", result.stdout)
        self.assertEqual(result.stderr, "")

    def test_unsupported_arguments_exit_before_renderer_dependencies(self):
        for argument in ("--unsupported", "unexpected"):
            with self.subTest(argument=argument):
                result = self.invoke(argument)
                self.assertEqual(result.returncode, 2)
                self.assertIn("unrecognized arguments:", result.stderr)
                self.assertNotIn("wowmock.py not found", result.stderr)

    def test_no_arguments_reach_existing_renderer_setup(self):
        result = self.invoke()
        self.assertEqual(result.returncode, 1)
        self.assertIn("wowmock.py not found", result.stderr)


def port(name, *constants, scope=None):
    """Compile one screenshots.py function with the constants it reads."""
    tree = ast.parse(SOURCE.read_text(encoding="utf-8"))
    nodes: list[ast.stmt] = [
        node
        for node in tree.body
        if isinstance(node, ast.FunctionDef)
        and node.name == name
        or isinstance(node, ast.Assign)
        and getattr(node.targets[0], "id", None) in constants
    ]
    scope = dict(scope or {})
    exec(compile(ast.Module(body=nodes, type_ignores=[]), str(SOURCE), "exec"), scope)
    return scope[name]


class ProbabilityTests(unittest.TestCase):
    def test_threshold_and_chance_parity_with_lua(self):
        # These scenes use the default, zero Legacy talent bonus.
        chance = port("model_chance")
        color = port("model_color")
        ranges = [
            None,
            [1, 20, 20, 20],
            [20, 20, 20, 20],
            [1, 20, 20, 40],
            [1, 20, 30, 40],
            [1, 20, 30, 20],
            [1, 30, 20, 40],
            [30, 20, 30, 40],
        ]
        skills = [0, 1, 19, 20, 29, 30, 39, 40, 48]
        for thresholds in ranges:
            for skill in skills:
                with self.subTest(thresholds=thresholds, skill=skill):
                    literal = "nil" if thresholds is None else "{" + ",".join(map(str, thresholds)) + "}"
                    lua = f"""
local ns = {{ Thresholds = {{ [1] = {literal} }} }}
assert(loadfile("Core/Model.lua"))("SkillUpForever", ns)
local t = ns.Model.Get(1)
local chance = ns.Model.Chance(t, {skill})
io.write(t and "valid" or "missing", "\\n", tostring(chance), "\\n", tostring(ns.Model.Color(t, {skill})))
"""
                    result = subprocess.run(
                        ["luajit", "-"],
                        input=lua,
                        text=True,
                        capture_output=True,
                        check=True,
                        cwd=SOURCE.parent.parent,
                    ).stdout.splitlines()
                    describe = port(
                        "describe",
                        scope={
                            "NS": {"Thresholds": {1: thresholds}},
                            "SKILL": skill,
                            "range_thresholds": lambda recipe_id, t: t,
                            "craft_cost": lambda recipe_id: (None, None, None),
                            "model_chance": chance,
                            "model_color": color,
                            "model_cost_per_skill_up": port("model_cost_per_skill_up"),
                        },
                    )
                    actual = describe(1)
                    self.assertEqual(actual["thresholds"] is not None, result[0] == "valid")
                    expected = None if result[1] == "nil" else float(result[1])
                    self.assertEqual(actual["chance"], expected)
                    self.assertEqual(actual["color"], None if result[2] == "nil" else result[2])
                    # Chance also has its own narrower validation, independent of Model.Get.
                    if thresholds is None or thresholds[0] <= thresholds[1] <= thresholds[2] <= thresholds[3]:
                        self.assertEqual(chance(thresholds, skill), expected)


class CraftValueTests(unittest.TestCase):
    def test_matches_item_value(self):
        craft_value = port("model_craft_value")
        cases = {
            (None, None, "none"): (None, None),
            (50, 100, "vendor"): (50, "vendor"),
            (50, 100, "auction"): (95.0, "auction"),
            (50, 40, "auction"): (50, "vendor"),
            (0, None, "auction"): (None, None),
            (None, 0, "auction"): (0, "auction"),
            (0, 0, "auction"): (0, "auction"),
        }
        for args, expected in cases.items():
            with self.subTest(args=args):
                self.assertEqual(craft_value(*args), expected)


class LuaDecoderTests(unittest.TestCase):
    def setUp(self):
        scope = {"subprocess": subprocess, "json": json, "tempfile": tempfile}
        self.parse = port("parse_lua_tables", "LUA_TABLE_SERIALIZER", scope=scope)

    def test_luajit_preserves_utf8_and_decimal_escapes(self):
        value = self.parse('local _, ns = ...; ns.Names = { [1] = "Dörf", [2] = "line\\0099" }')
        self.assertEqual(value["Names"], ["Dörf", "line\t9"])

    def test_luajit_preserves_numeric_maps_and_empty_tables(self):
        source = (
            'local _, ns = ...; ns.Values = { [3275] = "recipe", [4] = "sparse" }; '
            'ns.Sparse = { [1] = "first", [3] = "third" }; ns.Empty = {}'
        )
        value = self.parse(source)
        self.assertEqual(value["Values"], {3275: "recipe", 4: "sparse"})
        self.assertEqual(value["Sparse"], {1: "first", 3: "third"})
        self.assertEqual(value["Empty"], [])

    def test_luajit_quotes_string_controls(self):
        value = self.parse(r'local _, ns = ...; ns.Text = { "quote \" slash \\ tab \009" }')
        self.assertEqual(value["Text"], ['quote " slash \\ tab \t'])


if __name__ == "__main__":
    unittest.main()
