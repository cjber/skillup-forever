"""Check screenshots.py's ports of the addon's Lua against the Lua's results, without Pillow or wowmock."""

import ast
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

SOURCE = Path(__file__).with_name("screenshots.py")


def port(name):
    """One function from screenshots.py, compiled alone: the script needs Pillow and wowmock to import."""
    tree = ast.parse(SOURCE.read_text(encoding="utf-8"))
    function = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == name)
    scope = {}
    exec(compile(ast.Module(body=[function], type_ignores=[]), str(SOURCE), "exec"), scope)
    return scope[name]


def decoder():
    tree = ast.parse(SOURCE.read_text(encoding="utf-8"))
    names = {"LUA_TABLE_SERIALIZER", "parse_lua_tables"}
    nodes = [
        node
        for node in tree.body
        if isinstance(node, (ast.Assign, ast.FunctionDef))
        and any(getattr(target, "id", None) in names for target in getattr(node, "targets", []))
        or isinstance(node, ast.FunctionDef)
        and node.name == "parse_lua_tables"
    ]
    scope = {"subprocess": subprocess, "json": json, "tempfile": tempfile}
    exec(compile(ast.Module(body=nodes, type_ignores=[]), str(SOURCE), "exec"), scope)
    return scope["parse_lua_tables"]


class CraftValueTests(unittest.TestCase):
    def test_matches_item_value(self):
        craft_value = port("model_craft_value")
        # (sell, auction, mode) -> what Prices.lua's ItemValue returns, nil as None.
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
    def test_luajit_preserves_utf8_and_decimal_escapes(self):
        parse = decoder()
        with tempfile.NamedTemporaryFile("w", suffix=".lua", encoding="utf-8") as source:
            source.write('local _, ns = ...; ns.Names = { [1] = "Dörf", [2] = "line\\0099" }')
            source.flush()
            value = parse(Path(source.name).read_text(encoding="utf-8"))
        self.assertEqual(value["Names"], ["Dörf", "line\t9"])

    def test_luajit_preserves_numeric_maps_and_empty_tables(self):
        parse = decoder()
        source = (
            'local _, ns = ...; ns.Values = { [3275] = "recipe", [4] = "sparse" }; '
            'ns.Sparse = { [1] = "first", [3] = "third" }; ns.Empty = {}'
        )
        value = parse(source)
        self.assertEqual(value["Values"], {3275: "recipe", 4: "sparse"})
        self.assertEqual(value["Sparse"], {1: "first", 3: "third"})
        self.assertEqual(value["Empty"], [])

    def test_luajit_quotes_string_controls(self):
        parse = decoder()
        value = parse(r'local _, ns = ...; ns.Text = { "quote \" slash \\ tab \009" }')
        self.assertEqual(value["Text"], ['quote " slash \\ tab \t'])


if __name__ == "__main__":
    unittest.main()
