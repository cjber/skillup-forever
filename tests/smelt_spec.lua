-- Run from the repository root: luajit tests/smelt_spec.lua
-- Issue #688: the client's smelting rows have grey equal to yellow (Smelt Mithril is 175/175), a range with no
-- yellow or green band. It is orange below the value and grey from it, not a contradiction, so every reader
-- keeps it and none draws a zero-width band or divides by its width.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local c = Client.load()
local ns, M = c.ns, c.ns.Model

local function Mining(skill)
	return {
		skillLine = 186,
		name = "Mining",
		base = skill,
		modifier = 0,
		skill = skill,
		max = 300,
		capped = false,
	}
end

local MITHRIL = 10097
local t = M.Get(MITHRIL)
equal(type(t), "table", "Smelt Mithril has thresholds")
equal(t and table.concat(t, "/"), "1/175/175/175", "its grey is its yellow, so green is that value too")
equal(M.Color(t, 174), "orange", "orange below the shared value")
equal(M.Color(t, 175), "grey", "grey from it, with no yellow or green band")
equal(M.Chance(t, 174), 1, "a craft below it is certain")
equal(M.Chance(t, 175), 0, "and gives no skill-up from it")

-- The trainer teaches it at 175, so the range starts there and every band above it stays equal.
local range = ns.RangeThresholds(Mining(170), MITHRIL)
equal(range and table.concat(range, "/"), "175/175/175/175", "the range starts where Mining learns it")
equal(ns.RecipeBands(Mining(170), MITHRIL)[1].color, "grey", "no zero-width band is listed")
equal(#ns.RecipeBands(Mining(170), MITHRIL), 1, "the recipe only has its grey band there")

Client.report("smelt_spec")
