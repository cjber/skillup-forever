#!/usr/bin/env python3
"""Regenerate committed data twice and require fresh, byte-stable results."""

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTPUTS = ["Thresholds.lua", "Vendor.lua", "Recipes.lua", "Trainer.lua", "Sources.lua"]
GENERATORS = ["gen_thresholds.py", "gen_vendor.py", "gen_recipes.py", "gen_trainer.py", "gen_sources.py"]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--offline", action="store_true")
    args = parser.parse_args()
    suffix = ["--offline"] if args.offline else []
    original = {name: (ROOT / "Data" / name).read_bytes() for name in OUTPUTS}
    with tempfile.TemporaryDirectory() as directory:
        scratch = Path(directory) / ROOT.name
        scratch.mkdir()
        tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
        for name in tracked.decode().split("\0"):
            if not name:
                continue
            source = ROOT / name
            target = scratch / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
        cache = ROOT / "tools" / ".cache"
        if cache.is_dir():
            shutil.copytree(cache, scratch / "tools" / ".cache")
        for name in OUTPUTS:
            (scratch / "Data" / name).unlink()
        for generator in GENERATORS:
            subprocess.run([sys.executable, f"tools/{generator}", *suffix], cwd=scratch, check=True)
        first = {name: (scratch / "Data" / name).read_bytes() for name in OUTPUTS}
        for name in OUTPUTS:
            if first[name] != original[name]:
                raise SystemExit(f"generated output is stale: Data/{name}")
        for name in OUTPUTS:
            (scratch / "Data" / name).unlink()
        for generator in GENERATORS:
            subprocess.run([sys.executable, f"tools/{generator}", "--offline"], cwd=scratch, check=True)
        for name in OUTPUTS:
            if (scratch / "Data" / name).read_bytes() != first[name]:
                raise SystemExit(f"generator is not byte-stable: Data/{name}")


if __name__ == "__main__":
    main()
