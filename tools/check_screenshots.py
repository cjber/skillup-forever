#!/usr/bin/env python3
"""Fail when a screenshot is older than what it shows (WFA-9, forever_tools.screens).

tools/screenshots.py runs the addon's own Lua under LuaJIT for the route, tracker, trainer and reagent scenes and
ports Core/Model.lua, Integrations/Prices.lua, UI/RecipeList.lua and UI/Tooltip.lua for the rest. Each image's dump
is those files' hashes, so a change to any of them needs a fresh render. Generated `Data/` is left out: the daily
data refresh moves it and cannot render, and the release re-renders every image (the release skill).
docs/screenshots/scenes.sha256 holds each image's hash beside its dump's; after a render, `--record` rewrites it
(with `--force` for an image that came out the same).

    python3 tools/check_screenshots.py           # CI: fail on a stale image
    python3 tools/check_screenshots.py --record  # after tools/screenshots.py renders
"""

import functools
import sys
from pathlib import Path

try:
    from tools.forever_tools import screens
except ModuleNotFoundError:
    from forever_tools import screens

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs/screenshots"
SOURCES = (
    "Locales/enUS.lua",
    "SkillUpForever.toc",
    "tools/screenshots.py",
    "Core/*.lua",
    "Integrations/*.lua",
    "UI/*.lua",
    "UI/*.xml",
)
SCENES = {
    path.name: functools.partial(screens.files, ROOT, SOURCES)
    for pattern in screens.IMAGES
    for path in sorted(OUT.glob(pattern))
}


if __name__ == "__main__":
    sys.exit(screens.main(OUT, SCENES))
