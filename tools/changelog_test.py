"""A maintenance release has no bold lead and still needs a changelog entry the release can publish.

`python3 tools/changelog.py --check` reads every version's section, and a core sync's entry is a comment, a blank
line and one plain bullet, so it must pass like any other. The in-game update line skips it for the headline above
(tests/core_spec.lua), and the release still publishes these words as its notes.
"""

import contextlib
import io
import unittest

from tools.forever_tools.changelog import check, section

CHANGELOG = """# Changelog

## [Unreleased]

## [1.6.3] - 2026-11-12

<!-- forever-core-sync -->

- Ships with the same shared code as your other Forever addons, so they keep working together.

## [1.6.2] - 2026-11-11

- **Tells you which addon to update.** If another Forever addon you have installed is older than this one, the
  message now names it.
"""


class MaintenanceReleaseTest(unittest.TestCase):
    def test_a_maintenance_entry_above_a_normal_one_is_accepted(self):
        quiet = io.StringIO()
        with contextlib.redirect_stdout(quiet):
            check(CHANGELOG, [])
            check(CHANGELOG, ["1.6.3", "1.6.2"])
        self.assertEqual(
            section(CHANGELOG, "1.6.3"),
            "<!-- forever-core-sync -->\n\n"
            "- Ships with the same shared code as your other Forever addons, so they keep working together.",
        )
        self.assertIn("- **Tells you which addon to update.**", section(CHANGELOG, "1.6.2"))
        self.assertNotIn("- **", section(CHANGELOG, "1.6.3"))


if __name__ == "__main__":
    unittest.main()
