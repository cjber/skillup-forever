"""Focused independent Fraction oracle for the declared deterministic kernel.

Run from the repository root: python3 tests/crafted_oracle.py
No client, generated data, source laws or probability defaults are used.
"""

import subprocess
from fractions import Fraction
from functools import cache


def literal(value):
    if isinstance(value, dict):
        return "{" + ",".join(f"[{literal(k)}]={literal(v)}" for k, v in value.items()) + "}"
    if isinstance(value, list):
        return "{" + ",".join(map(literal, value)) + "}"
    if isinstance(value, str):
        return '"' + value + '"'
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def oracle(held, main, auxiliary, failure_loss, carry):
    # Deliberately enumerate every craft recursively instead of using the Lua
    # compiler, graph/rank, memoized explicit-stack solver or dyadic arithmetic.
    @cache
    def solve(stage, inventory):
        terminal_carry = sum(Fraction(n) * c for n, c in zip(inventory, carry, strict=True))
        if stage == len(main):
            return Fraction(1), Fraction(1), terminal_carry
        coverage, success, objective = Fraction(0), Fraction(0), terminal_carry + failure_loss
        for consume, produce, p, advance in [(*main[stage], True), *[(u, v, Fraction(0), False) for u, v in auxiliary]]:
            if any(n < use for n, use in zip(inventory, consume, strict=True)):
                continue
            following = tuple(n - use + product for n, use, product in zip(inventory, consume, produce, strict=True))
            branches = [(p, stage + 1), (1 - p, stage)] if advance else [(Fraction(1), stage)]
            values = [(q, solve(next_stage, following)) for q, next_stage in branches if q]
            candidate_c = sum(q * v[0] for q, v in values)
            candidate_s = sum(q * v[1] for q, v in values)
            candidate_o = sum(q * v[2] for q, v in values)
            coverage = max(coverage, candidate_c)
            if candidate_o < objective:
                success, objective = candidate_s, candidate_o
        return coverage, success, objective

    return solve(0, held)


def recipe(identity, role, use, produce):
    return {
        "recipeID": identity,
        "professionID": 1,
        "role": role,
        "available": True,
        "scope": "synthetic-oracle",
        "skillEffect": "route" if role == "main" else "neutral",
        "productionLaw": "deterministic-completed-attempt",
        "use": {i + 1: n for i, n in enumerate(use) if n},
        "produce": {i + 1: n for i, n in enumerate(produce) if n},
        "evidence": {"revision": 1, "allocation": "basic", "clientBuild": "synthetic"},
    }


fixtures, expected = [], []
for raw in range(4):
    for intermediate in range(3):
        for needed in (1, 2):
            for loss in (0, 8):
                for carrying in (Fraction(0), Fraction(1, 2)):
                    for extra in (False, True):
                        held = (raw, intermediate, 0)
                        main = [((1, 0, 0), (0, 1, 0), Fraction(1, 2)), ((0, needed, 0), (0, 0, 1), Fraction(1))]
                        auxiliary = [((1, 0, 0), (0, 2, 0))] if extra else []
                        carry = (Fraction(0), carrying, Fraction(0))
                        expected.append(oracle(held, main, auxiliary, loss, carry))
                        recipes = [
                            recipe(101, "main", main[0][0], main[0][1]),
                            recipe(102, "main", main[1][0], main[1][1]),
                        ]
                        if extra:
                            recipes.append(recipe(201, "auxiliary", *auxiliary[0]))
                        fixtures.append(
                            {
                                "service": "adaptive-finite",
                                "journey": "independent-round-trips",
                                "delivery": "independent-bundle-outcomes",
                                "objective": "expected-expenditure-plus-terminal-carry-plus-failure-loss",
                                "route": {
                                    "version": "crafted-deterministic-v1",
                                    "coverage": "maximum-craft-only-completion",
                                    "prerequisites": "already-satisfied",
                                    "held": {i + 1: n for i, n in enumerate(held)},
                                    "buy": {},
                                    "recipes": recipes,
                                    "legs": [
                                        {"recipeID": 101, "fromSkill": 1, "toSkill": 2, "thresholds": [0, 0, 0, 2]},
                                        {"recipeID": 102, "fromSkill": 2, "toSkill": 3, "thresholds": [0, 3, 3, 3]},
                                    ],
                                },
                                "sources": [],
                                "stock": {},
                                "walletCopper": 0,
                                "currencies": {},
                                "initialOrders": [],
                                "initialVisitMoney": {},
                                "refillVisitMoney": {},
                                "initialVisitValue": {},
                                "refillVisitValue": {},
                                "terminalCarry": {"item:1": 0, "item:2": float(carrying), "item:3": 0},
                                "tokenValues": {},
                                "failureLoss": loss,
                                "sourceRevision": 1,
                                "assumptions": [],
                                "options": {
                                    "workLimit": 1000000,
                                    "stateLimit": 10000,
                                    "coordinateLimit": 16,
                                    "limbLimit": 256,
                                },
                            }
                        )

script = """
local ns = {}
for _, name in ipairs({"Model", "Demand", "Dyadic", "FiniteAcquisition"}) do
 assert(loadfile("Core/" .. name .. ".lua"))("SkillUpForever", ns)
end
"""
script += "local fixtures = " + literal(fixtures) + "\n"
script += """
for _, input in ipairs(fixtures) do
 local job = ns.FiniteAcquisition.Start(input)
 while job.result.status == "calculating" do job:Advance(1000) end
 local result = job.result
 assert(result.status == "complete", result.reasons[1])
 for _, field in ipairs({"coverage", "success", "objective"}) do
  io.write(string.format("%.17g %.17g ", result[field .. "Lower"], result[field .. "Upper"]))
 end
 io.write("\\n")
end
"""
# Feed stdin to EOF explicitly; no files, processes or servers remain afterward.
result = subprocess.run(["luajit", "-"], input=script, text=True, capture_output=True)
assert result.returncode == 0, result.stderr
rows = result.stdout.splitlines()
assert len(rows) == len(expected)
for index, (row, exact) in enumerate(zip(rows, expected, strict=True)):
    bounds = [Fraction(value) for value in row.split()]
    for component, value in enumerate(exact):
        lower, upper = bounds[2 * component : 2 * component + 2]
        assert lower <= value <= upper, (index, component, value, lower, upper)
print(f"crafted_oracle: {len(fixtures)} exact Fraction fixtures passed")
