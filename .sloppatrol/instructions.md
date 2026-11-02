# About the code

SkillUp Forever is a World of Warcraft: Forever addon in Lua 5.1. The files `SkillUpForever.toc` lists are
what the game loads; `tests/*_spec.lua` load them in that order inside a stubbed client.

- Keep the public API in `Core/API.lua` and every saved variable name unchanged.
- Generated data, `Libs/` and `tools/forever_tools/` are never edited by hand.
- Taint: never replace a Blizzard global or hook a secure function a spec does not already hook.
- Never launch the game, Battle.net, Lutris or Wine, and never use the network.
