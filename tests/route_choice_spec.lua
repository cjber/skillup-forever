local ns = {}
assert(loadfile("Core/RouteChoice.lua"))("SkillUpForever", ns)
local choices, cost = ns.SelectRouteChoices({
	{
		candidates = {
			{ id = "A", use = { [1] = 1 }, cost = { [1] = 10 } },
			{ id = "B", use = { [2] = 1 }, cost = { [2] = 2 } },
		},
	},
	{ candidates = { { id = "A2", use = { [1] = 1 }, cost = { [1] = 10 } } } },
}, { [1] = 1 }, 16)
assert(choices and choices[1].id == "B" and cost == 2, "joint choice preserves cheaper shared route")
local _, _, reason = ns.SelectRouteChoices({ { candidates = { { use = { [1] = 1 }, cost = { [1] = 1 } } } } }, {}, 0)
assert(reason == "route choice state budget exceeded", "bounded selector stays unknown")
print("route choice: ok")
