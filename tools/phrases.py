#!/usr/bin/env python3
"""Print a translation template with every L["..."] phrase in the shipped Lua.

Writes nothing: `python3 tools/phrases.py > Locales/phrases.txt`. A translator copies that file to
Locales/<locale>.lua and translates the right-hand sides (Locales/README.md).
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HEADER = """\
-- Copy to Locales/deDE.lua (or your locale), translate the text on the right of each line and
-- delete the lines you leave in English. List the file in SkillUpForever.toc after Locales\\enUS.lua.
local _, ns = ...
if GetLocale() ~= "deDE" then
\treturn
end
local L = ns.L
"""
# The phrase as written in the source, escapes included, so it pastes back into Lua unchanged.
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
    print(HEADER)
    for phrase in phrases():
        print(f'L["{phrase}"] = "{phrase}"')
