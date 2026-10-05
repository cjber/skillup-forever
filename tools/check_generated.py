#!/usr/bin/env python3
"""Regenerate committed data twice and require fresh, byte-stable results."""

import argparse
import subprocess
import sys
from pathlib import Path

from forever_tools import generated
from forever_tools.report import Subset

ROOT = Path(__file__).resolve().parent.parent
OUTPUTS = ["Thresholds.lua", "Vendor.lua", "Recipes.lua", "Trainer.lua", "Sources.lua"]
GENERATORS = ["gen_thresholds.py", "gen_vendor.py", "gen_recipes.py", "gen_trainer.py", "gen_sources.py"]
# Both are limited to the threshold recipes by their generators, so a recipe that left Thresholds must leave them.
SUBSETS = [
    Subset("ns.RecipeData", "ns.Thresholds", "recipe data covers threshold recipes only"),
    Subset("ns.TrainerFees", "ns.Thresholds", "trainer fees cover threshold recipes only"),
]


def outputs(root: Path) -> dict[str, bytes]:
    return {f"Data/{name}": (root / "Data" / name).read_bytes() for name in OUTPUTS}


def regenerate(scratch: Path, offline: bool) -> None:
    for name in OUTPUTS:
        (scratch / "Data" / name).unlink()
    for generator in GENERATORS:
        subprocess.run(
            [sys.executable, f"tools/{generator}", *(["--offline"] if offline else [])], cwd=scratch, check=True
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--offline", action="store_true")
    generated.check_generated(
        ROOT,
        outputs=outputs,
        regenerate=regenerate,
        offline=parser.parse_args().offline,
        success="Generated data is fresh and byte-stable.",
        subsets=SUBSETS,
    )


if __name__ == "__main__":
    main()
