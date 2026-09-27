"""Check screenshots.py's ports of Model.lua against the Lua's results, without Pillow or wowmock."""

import ast
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


class CraftValueTests(unittest.TestCase):
    def test_matches_model_craft_value(self):
        craft_value = port("model_craft_value")
        # (sell, auction, mode) -> what Model.CraftValue returns, nil as None.
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


if __name__ == "__main__":
    unittest.main()
