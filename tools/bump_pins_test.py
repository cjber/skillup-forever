"""`--help` and an unknown flag act on the arguments, never on the pins; the forever-db pin moves on releases."""

import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))

import bump_pins

RELEASES = [
    {"tag_name": "data-v2026.10.1", "draft": False, "prerelease": False, "assets": []},
    {
        "tag_name": "data-v2026.11.2",
        "draft": False,
        "prerelease": False,
        "assets": [
            {"name": "forever-db-2026.11.2.zip", "browser_download_url": "https://example/forever-db-2026.11.2.zip"},
        ],
    },
    {
        # A draft never moves the pin, whatever it carries.
        "tag_name": "data-v2026.12.1",
        "draft": True,
        "prerelease": False,
        "assets": [{"name": "forever-db-2026.12.1.zip", "browser_download_url": "https://example/forever-db.zip"}],
    },
]
SUMS = "43157067315537a8b95e5c517e30a1b6d55e117022f89094f039e9e6eb6438ad  forever-db-2026.11.2.zip\n"


def fetch_by_url(url):
    if url.endswith("releases?per_page=30"):
        return json.dumps(RELEASES).encode()
    if url.endswith("SHA256SUMS"):
        return SUMS.encode()
    raise AssertionError(url)


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


class FdbPinTest(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.tools = Path(self.scratch.name)
        shutil.copy(bump_pins.TOOLS / "fdb_pin.py", self.tools / "fdb_pin.py")
        self.gen_thresholds = self.tools / "gen_thresholds.py"
        shutil.copy(bump_pins.TOOLS / "gen_thresholds.py", self.gen_thresholds)
        patcher = mock.patch.dict(bump_pins.PINS, clear=True)
        patcher.start()
        self.addCleanup(patcher.stop)

    def pin(self):
        return (self.tools / "fdb_pin.py").read_text(encoding="utf-8")

    def test_a_current_release_leaves_the_pin(self):
        with mock.patch.object(bump_pins, "TOOLS", self.tools), mock.patch.object(bump_pins, "fetch", fetch_by_url):
            with mock.patch("sys.stderr"):
                self.assertEqual(bump_pins.main([]), None)
        self.assertIn('FDB_TAG = "data-v2026.11.2"', self.pin())
        self.assertNotIn("2026.10.1", self.pin())

    def test_a_newer_release_moves_tag_asset_and_digest(self):
        newer = [
            dict(
                RELEASES[1],
                tag_name="data-v2026.11.3",
                assets=[
                    {
                        "name": "forever-db-2026.11.3.zip",
                        "browser_download_url": "https://example/forever-db-2026.11.3.zip",
                    },
                    {"name": "SHA256SUMS", "browser_download_url": "https://example/SHA256SUMS"},
                ],
            )
        ]
        digest = "f" * 64

        def fetch(url):
            if url.endswith("releases?per_page=30"):
                return json.dumps(newer).encode()
            if url.endswith("SHA256SUMS"):
                return f"{digest}  forever-db-2026.11.3.zip\n".encode()
            raise AssertionError(url)

        with mock.patch.object(bump_pins, "TOOLS", self.tools), mock.patch.object(bump_pins, "fetch", fetch):
            with mock.patch("sys.stdout") as output:
                bump_pins.main([])
        printed = "".join(call.args[0] for call in output.write.call_args_list if call.args)
        self.assertEqual(printed, "forever-db data-v2026.11.3\n")
        self.assertIn('FDB_TAG = "data-v2026.11.3"', self.pin())
        self.assertIn('FDB_ASSET = "forever-db-2026.11.3.zip"', self.pin())
        self.assertIn(f'FDB_SHA256 = "{digest}"', self.pin())
        # The forever-db pin feeds no generator, so the data's SOURCE_DATE stays wherever it was.
        self.assertIn("SOURCE_DATE", self.gen_thresholds.read_text(encoding="utf-8"))

    def test_a_release_without_a_zip_asset_or_sums_is_refused(self):
        for releases, expectation in (
            (
                [dict(RELEASES[1], tag_name="data-v2026.11.3", assets=[])],
                "release on the polestar page carries a zip asset",
            ),
            (
                [dict(RELEASES[1], tag_name="data-v2026.11.3")],
                "carries no SHA256SUMS asset",
            ),
        ):
            with self.subTest(tag="data-v2026.11.3", expectation=expectation):
                with mock.patch.object(bump_pins, "TOOLS", self.tools):
                    with mock.patch.object(
                        bump_pins, "fetch", lambda url, releases=releases: json.dumps(releases).encode()
                    ):
                        with self.assertRaises(SystemExit) as raised:
                            bump_pins.main([])
                self.assertIn(expectation, str(raised.exception))
                self.assertIn('FDB_TAG = "data-v2026.11.2"', self.pin())

    def test_a_sums_without_the_asset_or_a_sha256_is_refused(self):
        release = dict(
            RELEASES[1],
            tag_name="data-v2026.11.3",
            assets=[
                {"name": "forever-db-2026.11.3.zip", "browser_download_url": "https://example/forever-db.zip"},
                {"name": "SHA256SUMS", "browser_download_url": "https://example/SHA256SUMS"},
            ],
        )
        for sums, expectation in (
            (b"fedcba98  some-other-file.zip\n", "names no forever-db-2026.11.3.zip"),
            (b"NOTASHA  forever-db-2026.11.3.zip\n", "not a sha256"),
        ):
            with self.subTest(expectation=expectation):

                def fetch(url, sums=sums):
                    if url.endswith("releases?per_page=30"):
                        return json.dumps([release]).encode()
                    if url.endswith("SHA256SUMS"):
                        return sums
                    raise AssertionError(url)

                with mock.patch.object(bump_pins, "TOOLS", self.tools):
                    with mock.patch.object(bump_pins, "fetch", fetch):
                        with self.assertRaises(SystemExit) as raised:
                            bump_pins.main([])
                self.assertIn(expectation, str(raised.exception))
                self.assertIn('FDB_TAG = "data-v2026.11.2"', self.pin())


if __name__ == "__main__":
    unittest.main()
