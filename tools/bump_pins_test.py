"""`--help` and an unknown flag act on the arguments, never on the pins."""

import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))

import bump_pins


class ArgsTest(unittest.TestCase):
    def test_help_prints_usage_and_exits_zero(self):
        for argv in (["--help"], ["-h"]):
            with self.subTest(argv=argv), mock.patch("sys.stdout"):
                with self.assertRaises(SystemExit) as raised:
                    bump_pins.main(argv)
                self.assertEqual(raised.exception.code, 0)

    def test_unknown_flag_exits_two_before_any_pin_moves(self):
        before = {path: path.read_bytes() for path in bump_pins.TOOLS.glob("gen_*.py")}
        with self.subTest(), mock.patch("sys.stderr"), mock.patch("urllib.request.urlopen") as opened:
            with self.assertRaises(SystemExit) as raised:
                bump_pins.main(["--not-a-flag"])
        self.assertEqual(raised.exception.code, 2)
        opened.assert_not_called()
        for path, content in before.items():
            self.assertEqual(path.read_bytes(), content, f"{path.name} was rewritten")


if __name__ == "__main__":
    unittest.main()
