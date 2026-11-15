local ns = {}
assert(loadfile("Core/RouteChoice.lua"))("SkillUpForever", ns)
local choices, cost = ns.SelectRouteChoices({
	{ candidates = { { use = { [1] = 2 }, cost = 5 }, { use = { [1] = 4 }, cost = 8 } } },
	{ candidates = { { use = { [1] = 2 }, cost = 5 }, { use = { [1] = 1 }, cost = 9 } } },
}, {}, 16)
assert(choices and #choices == 2 and cost == 10, "shared fixed-reagent route chooses whole-route minimum")
local _, _, reason = ns.SelectRouteChoices({ { candidates = { { use = { [1] = 1 }, cost = 1 } } } }, {}, 0)
assert(reason == "route choice state budget exceeded", "bounded selector stays unknown")
print("route choice: ok")
