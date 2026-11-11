#!/usr/bin/env python3
"""Fail when a screenshot is older than what it shows (WFA-9, forever_tools.screens).

tools/screenshots.py runs the addon's own Lua under LuaJIT for the route, tracker, trainer and reagent scenes and
ports Core/Model.lua, Integrations/Prices.lua, UI/RecipeList.lua and UI/Tooltip.lua for the rest. Each image's dump
is the hashes of the files in SOURCES, the TOC's file lines in load order, and the one TOC field a scene draws, so
a change to any of them needs a fresh render. The TOC's other metadata shapes no pixel: the core sync's
`## X-Forever-Core` line no longer marks every image stale. Generated `Data/` is left out: the daily data refresh
moves it and cannot render, and the release re-renders every image (the release skill).
docs/screenshots/scenes.sha256 holds each image's hash beside its dump's; after a render, `--record` rewrites it
(with `--force` for an image that came out the same).

    python3 tools/check_screenshots.py           # CI: fail on a stale image
    python3 tools/check_screenshots.py --record  # after tools/screenshots.py renders
"""

import re
import sys
from pathlib import Path

try:
    from tools.forever_tools import screens
except ModuleNotFoundError:
    from forever_tools import screens

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs/screenshots"
TOC = ROOT / "SkillUpForever.toc"
# The one TOC field a scene draws: tools/screenshots.py puts it on every side tab and the shopping window, and
# Core/Core.lua reads it onto ns.ICON for the addon's own identity surfaces. Title, Version and X-Forever-Core only
# feed the out-of-date warning and the update chat line, which no scene draws, so they stay out of the dump.
TOC_ICON = re.compile(r"^##\s*X-Forever-Icon:\s*(.*?)\s*$", re.MULTILINE)
# The files whose code shapes what the scenes show: the planner and its data readers, the windows, tooltips and
# route list they draw, and the text. The rest of the addon loads in the Lua scene too, but cannot change a pixel
# (settings, the report window, caught errors, trainer audits), so editing it needs no render.
SOURCES = (
    "tools/screenshots.py",
    "Locales/enUS.lua",
    "Core/Core.lua",
    "Core/Stats.lua",
    "Core/Model.lua",
    "Core/Plan.lua",
    "Core/API.lua",
    "Core/Changes.lua",
    "Core/Gear.lua",
    "Core/Buffs.lua",
    "Integrations/Prices.lua",
    "Integrations/Sources.lua",
    "UI/Gear.lua",
    "UI/Buffs.lua",
    "UI/PageParts.lua",
    "UI/Pages.lua",
    "UI/List.lua",
    "UI/RecipeList.lua",
    "UI/Route.lua",
    "UI/ShoppingList.lua",
    "UI/Shopping.lua",
    "UI/Tooltip.lua",
)


def toc_dump() -> bytes:
    """What the TOC contributes to a scene: its file lines in load order, then the one metadata field a scene draws.

    A file's presence or its place in the load order can change a pixel, so the file lines stay. The metadata
    cannot, so only `## X-Forever-Icon` joins them: a new order and a new icon need a render, a rewritten
    `## X-Forever-Core` does not."""
    text = TOC.read_text(encoding="utf-8-sig")
    files = [line.strip() for line in text.splitlines() if line.strip() and not line.startswith("#")]
    icon = TOC_ICON.search(text)
    if not icon:
        raise ValueError(f"{TOC.name}: no ## X-Forever-Icon, which the scenes draw")
    return "\n".join([*files, f"X-Forever-Icon: {icon[1]}"]).encode()


def scene_dump() -> bytes:
    """Every scene's dump: the hashes of the code it is drawn from, then the TOC's file list and icon field."""
    return screens.files(ROOT, SOURCES) + b"\n" + toc_dump()


SCENES = {path.name: scene_dump for pattern in screens.IMAGES for path in sorted(OUT.glob(pattern))}


if __name__ == "__main__":
    sys.exit(screens.main(OUT, SCENES))
