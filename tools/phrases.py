#!/usr/bin/env python3
"""Print a translation template with every L["..."] phrase in the shipped Lua.

Writes nothing: `python3 tools/phrases.py > Locales/phrases.txt`. A translator copies that file to
Locales/<locale>.lua and translates the right-hand sides (Locales/README.md).
"""

import re
from pathlib import Path

from typecheck_coverage import runtime_files

ROOT = Path(__file__).resolve().parent.parent
HEADER = """\
-- Every phrase SkillUp shows, with its English text: the template the Locales/<locale>.lua files follow.
-- Each client language already has its file; to correct a line, edit that file (Locales/README.md).
local _, ns = ...
if GetLocale() ~= "deDE" then
\treturn
end
local L = ns.L
"""
# The phrase as written in the source, escapes included, so it pastes back into Lua unchanged.
PHRASE = re.compile(r'\bL\["((?:\\.|[^"\\\n])*)"\]')
# ForeverCore's shared out-of-date warning (Core/ForeverRequire.lua, copied byte for byte) hands its English text to
# a `phrase(key, ...)` helper and reads ns.L by that same key, so those strings are phrases too.
SHARED = re.compile(r'\bphrase\("((?:\\.|[^"\\\n])*)"')
# A shared window may choose a phrase in a bracket expression: `L[count == 1 and "board" or "boards"]` uses both,
# so each string alternative is a phrase too.
ALTERNATIVE = re.compile(r"\bL\[([^\]]*)\]")
STRING = re.compile(r'"((?:\\.|[^"\\\n])*)"')
# A phrase may also be picked from a local string list: `local phrase = ORDINALS[rank]` then `L[phrase]`.
TABLE = re.compile(r"\blocal\s+(\w+)\s*=\s*\{([^}]*)\}")
LOOKUP = re.compile(r"\blocal\s+(\w+)\s*=\s*(\w+)\s*\[")


def phrases() -> list[str]:
    found = set()
    for path in runtime_files(ROOT):
        # A translation's keys are this template's own phrases: reading them would keep a removed one alive.
        if path.parent.name == "Locales":
            continue
        text = path.read_text()
        found.update(PHRASE.findall(text))
        found.update(SHARED.findall(text))
        for expression in ALTERNATIVE.findall(text):
            found.update(STRING.findall(expression))
        tables = {name: STRING.findall(body) for name, body in TABLE.findall(text)}
        for alias, table in LOOKUP.findall(text):
            if table in tables and re.search(rf"\bL\[\s*{alias}\s*\]", text):
                found.update(tables[table])
    return sorted(found)


if __name__ == "__main__":
    print(HEADER)
    for phrase in phrases():
        print(f'L["{phrase}"] = "{phrase}"')
