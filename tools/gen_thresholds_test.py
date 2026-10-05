import tempfile
import unittest
from pathlib import Path
from unittest import mock

import gen_thresholds


class Db2Test(unittest.TestCase):
    def rows(self, text, columns=("ID", "Value")):
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory)
            (cache / f"T-{gen_thresholds.BUILD}.csv").write_text(text, encoding="utf-8")
            with mock.patch.object(gen_thresholds, "CACHE", cache):
                return gen_thresholds.db2("T", columns, offline=True)

    def test_valid_rows_keep_their_strings(self):
        self.assertEqual(self.rows("ID,Value\n1,2\n3,4\n"), [{"ID": "1", "Value": "2"}, {"ID": "3", "Value": "4"}])

    def test_rejects_duplicate_columns(self):
        with self.assertRaisesRegex(ValueError, "duplicate columns"):
            self.rows("ID,Value,Value\n1,2,3\n")

    def test_rejects_duplicate_ids_and_short_rows(self):
        with self.assertRaisesRegex(ValueError, "duplicate ID"):
            self.rows("ID,Value\n1,2\n1,3\n")
        with self.assertRaisesRegex(ValueError, "malformed CSV row"):
            self.rows("ID,Value\n1\n")

    def test_rejects_missing_columns_and_empty_exports(self):
        with self.assertRaisesRegex(ValueError, "missing required columns"):
            self.rows("ID\n1\n")
        with self.assertRaisesRegex(ValueError, "empty export"):
            self.rows("ID,Value\n")

    def test_invalid_refresh_preserves_cached_source(self):
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory)
            path = cache / f"T-{gen_thresholds.BUILD}.csv"
            original = b"ID,Value\n1,2\n"
            path.write_bytes(original)
            with (
                mock.patch.object(gen_thresholds, "CACHE", cache),
                mock.patch.object(gen_thresholds.wago, "read_source", return_value=(b"ID,Value,Value\n1,2,3\n", True)),
                self.assertRaisesRegex(ValueError, "duplicate columns"),
            ):
                gen_thresholds.db2("T", ("ID", "Value"), refresh=True)
            self.assertEqual(path.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
