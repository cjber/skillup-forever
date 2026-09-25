#!/usr/bin/env python3
"""Print every L["..."] phrase in the shipped Lua as CurseForge's Lua localization import takes it.

Writes nothing: `python3 tools/phrases.py > Locales/phrases.txt`, then paste the file into the
CurseForge project's Localization > Import page (Lua format, enUS).
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# The phrase as written in the source, escapes included, which is also how the import reads it.
PHRASE = re.compile(r'\bL\["((?:\\.|[^"\\\n])*)"\]')


def shipped_lua() -> list[Path]:
    toc = (ROOT / "SkillUpForever.toc").read_text().splitlines()
    return [ROOT / line.replace("\\", "/") for line in toc if line.endswith(".lua")]


def phrases() -> list[str]:
    found = set()
    for path in shipped_lua():
        found.update(PHRASE.findall(path.read_text()))
    return sorted(found)


if __name__ == "__main__":
    for phrase in phrases():
        print(f'L["{phrase}"] = true')
