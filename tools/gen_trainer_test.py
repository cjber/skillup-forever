"""Reject source decoding errors instead of changing generated names."""

import gzip
import tempfile
import unittest
from pathlib import Path

from gen_trainer import dump_tables


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
