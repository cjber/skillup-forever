-- Run from the repository root: luajit tests/held_subcraft_spec.lua
-- #858: the route makes Light Leather from Ruined Leather Scraps. Once the player holds the scraps the route asked
-- for, a price change that makes buying Light Leather look cheaper at market must not drop the held scraps and ask
-- for Light Leather instead: the held copies make the intermediate first, as held intermediates and raw reagents
-- already stand in for what they cover.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local LEATHERWORKING = 165
local LIGHT_LEATHER, COARSE_LEATHER, COARSE_THREAD, FINE_THREAD, CURED_LIGHT_HIDE, SCRAPS =
	2318, 2319, 2320, 2321, 4231, 2934
local KNOWN = { 2149, 2152, 2153, 2158, 2159, 2160, 2162, 2166, 2167, 2168, 2881, 3753, 3756, 3759, 3816, 9059 }

local c = Client.load({ auctionator = false })
local ns = c.ns
c.level = 60
c.player.faction = "Alliance"
c.professions = { { name = "Leatherworking", id = LEATHERWORKING, rank = 35, max = 150 } }
for _, recipeID in ipairs(KNOWN) do
	c.known[recipeID] = true
end
for itemID, price in pairs({
	[LIGHT_LEATHER] = 20,
	[COARSE_LEATHER] = 60,
	[COARSE_THREAD] = 10,
	[FINE_THREAD] = 40,
	[CURED_LIGHT_HIDE] = 90,
	[SCRAPS] = 5,
}) do
	ns.db.vendor[itemID] = price
end
ns.Changed("prices")
ns.db.routeTargets[LEATHERWORKING] = 125
ns.Changed("target")

local profession = {
	skillLine = LEATHERWORKING,
	name = "Leatherworking",
	base = 35,
	modifier = 0,
	skill = 35,
	max = 150,
	capped = false,
}

---@return table<integer, number>
local function Reagents()
	local byItem = {}
	for _, item in ipairs(ns.RouteReagents(ns.PlanRoute(profession))) do
		byItem[item.itemID] = item.need
	end
	return byItem
end

local before = Reagents()
assert(before[SCRAPS] and before[SCRAPS] > 0, "the route makes its Light Leather from scraps")
equal(before[LIGHT_LEATHER], nil, "and buys no Light Leather")

-- The player buys the whole list.
for itemID, need in pairs(before) do
	c.bags[itemID] = need
end
c.Fire("BAG_UPDATE_DELAYED")
c.Advance(0)

-- A rescan after buying the cheap listings: scraps now cost more than Light Leather per craft.
ns.db.vendor[SCRAPS] = 50
ns.Changed("prices")
local after = Reagents()
equal(after[SCRAPS], before[SCRAPS], "the held scraps still make the route's Light Leather")
equal(after[LIGHT_LEATHER], nil, "and no Light Leather is added to buy")
for itemID in pairs(after) do
	assert(before[itemID], "a price change after buying added a new reagent: " .. itemID)
end

-- A maker set aside with "Not this recipe" is not used for held inputs either.
local LIGHT_LEATHER_RECIPE = 2881
ns.SetSkipped(LIGHT_LEATHER_RECIPE, true)
local skipped = Reagents()
equal(skipped[SCRAPS], nil, "a skipped maker leaves the held scraps alone")
assert(skipped[LIGHT_LEATHER], "and the route buys its Light Leather")

Client.report("held_subcraft_spec")
