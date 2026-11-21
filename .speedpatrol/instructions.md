# About the app

SkillUp Forever is a World of Warcraft: Forever addon in Lua 5.1. The game cannot run here. The
benchmarks run the offline spec harness the specs use, which stubs the client API and loads the files
`SkillUpForever.toc` lists in order.

- Keep a change only when it speeds up a file the TOC loads or the spec suite itself. A change to a
  bench script or other measuring code is not a speed-up.
- Every change must pass the full gate in `AGENTS.md` under "Commands".
- Generated data and vendored code are never edited by hand.
- Commit only the files the change needs: no profiler output or scratch files.
- Never use the network, and never start the game, Battle.net, Lutris or Wine.

## On pull requests

`.github/workflows/speedpatrol.yml` runs `speedpatrol compare` on every pull request: three A/B rounds
against the base branch, over `harness.bench` only, failing the job on a regression. CI's `check` job
runs `tests/bench.lua` as well; `gate.specs` is for the local patrol.
