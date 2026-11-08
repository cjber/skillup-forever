-- Run from the repository root: luajit tests/leatherworking_route_spec.lua
-- Issue #394: a Leatherworking route from 35 to 100 leaned on one low-tier pattern because the higher-tier
-- recipes' reagents had no price, so its reagent totals looked farmable when they were not.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local LEATHERWORKING = 165
local LIGHT_LEATHER, COARSE_LEATHER, COARSE_THREAD, FINE_THREAD, CURED_LIGHT_HIDE = 2318, 2319, 2320, 2321, 4231
local HANDSTITCHED_BOOTS, HANDSTITCHED_PANTS, FINE_BOOTS, FINE_CLOAK, EMBOSSED_VEST, TOUGHENED_ARMOR =
	2149, 2153, 2158, 2159, 2160, 2166

local REPRODUCTION = { HANDSTITCHED_BOOTS, HANDSTITCHED_PANTS, FINE_BOOTS, FINE_CLOAK, EMBOSSED_VEST, TOUGHENED_ARMOR }

local function Loaded(prices, max, known)
	max = max or 75
	known = known or REPRODUCTION
	local c = Client.load({ auctionator = false })
	c.level = 60
	c.player.faction = "Alliance"
	c.professions = { { name = "Leatherworking", id = LEATHERWORKING, rank = 1, max = max } }
	for _, recipeID in ipairs(known) do
		c.known[recipeID] = true
	end
	for itemID, price in pairs(prices) do
		c.ns.db.vendor[itemID] = price
	end
	c.ns.Changed("prices")
	return c
end

local function Leatherworking(max)
	return {
		skillLine = LEATHERWORKING,
		name = "Leatherworking",
		base = 35,
		modifier = 0,
		skill = 35,
		max = max or 75,
		capped = false,
	}
end

local function Plan(c, max)
	c.ns.db.routeTargets[LEATHERWORKING] = 100
	c.ns.Changed("target")
	return c.ns.PlanRoute(Leatherworking(max))
end

local function Reagent(items, itemID)
	for _, item in ipairs(items) do
		if item.itemID == itemID then
			return item
		end
	end
end

-- Fully priced, the reproduction's recipes all known: the higher-tier Toughened Leather Armor carries the
-- whole 35 to 100 route, so the totals are its reagents alone and no recipe is left out (#394).
local fully = Loaded({
	[LIGHT_LEATHER] = 1000,
	[COARSE_LEATHER] = 1,
	[COARSE_THREAD] = 1,
	[FINE_THREAD] = 1,
	[CURED_LIGHT_HIDE] = 1,
}, 150)
local fullPlan = Plan(fully, 150)
equal(fullPlan.target, 100, "the requested target")
equal(fullPlan.reached, 100, "a fully priced route reaches it")
equal(fullPlan.unpriced, 0, "with every recipe planned")
equal(#fullPlan.crafts, 1, "a fully priced route is a single craft row")
equal(fullPlan.crafts[1] and fullPlan.crafts[1].recipeID, TOUGHENED_ARMOR, "on the higher-tier pattern")
local fullReagents = fully.ns.RouteReagents(fullPlan)
local coarse = Reagent(fullReagents, COARSE_LEATHER)
local fine = Reagent(fullReagents, FINE_THREAD)
local hide = Reagent(fullReagents, CURED_LIGHT_HIDE)
equal(coarse and coarse.need, 650, "with 650 Coarse Leather")
equal(fine and fine.need, 130, "130 Fine Thread")
equal(hide and hide.need, 130, "and 130 Cured Light Hide")
equal(Reagent(fullReagents, LIGHT_LEATHER), nil, "and no Light Leather")
equal(fully.ns.RouteNotice(fullPlan), nil, "a fully priced route never leans on one reagent")

-- The reproduction's case: the higher tier's Coarse Leather and Cured Light Hide are unpriced, so its recipe
-- is left out and the route falls back to the Light Leather patterns (#394).
local partly = Loaded({
	[LIGHT_LEATHER] = 1,
	[COARSE_THREAD] = 1,
})
local partPlan = Plan(partly)
equal(partPlan.unpriced > 0, true, "an unpriced higher tier leaves recipes out")
local partNotice = partly.ns.RouteNotice(partPlan)
equal(partNotice ~= nil, true, "a route mostly one reagent while recipes are left out warns")
equal(partNotice and partNotice.itemID, LIGHT_LEATHER, "that it is mostly Light Leather")
equal(partNotice and partNotice.recipes, partPlan.unpriced, "and how many recipes are left out")
local partDominant = partly.ns.DominantReagent(partPlan)
equal(partDominant and partDominant.itemID, LIGHT_LEATHER, "the reagent the route leans on is Light Leather")
equal(partDominant and partDominant.share >= 0.5, true, "and it is at least half the route's reagent units")

-- A spread-out route, every reagent priced: no single reagent carries it, so there is no notice (#394).
local spread = Loaded(
	{ [LIGHT_LEATHER] = 100, [COARSE_LEATHER] = 1, [COARSE_THREAD] = 1, [FINE_THREAD] = 1, [CURED_LIGHT_HIDE] = 1 },
	150,
	{ HANDSTITCHED_BOOTS }
)
local spreadPlan = Plan(spread, 150)
equal(spreadPlan.reached, 100, "a fully priced spread-out route reaches the target")
equal(spreadPlan.unpriced, 0, "with every recipe planned")
local spreadDominant = spread.ns.DominantReagent(spreadPlan)
equal(spreadDominant ~= nil, true, "the route still has a largest reagent")
equal(spreadDominant and spreadDominant.share < 0.5, true, "but it is less than half the route")
equal(spread.ns.RouteNotice(spreadPlan), nil, "a spread-out route never produces a notice")

Client.report("leatherworking_route_spec")
