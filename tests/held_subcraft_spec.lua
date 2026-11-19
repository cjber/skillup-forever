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

-- A route followed while buying Light Leather was cheaper gains the Light Leather step once the bags hold the scraps
-- to make it, so its steps match Reagents; its crafts stay.
do
	local f = Client.load({ auctionator = false })
	local fns = f.ns
	f.level = 60
	f.player.faction = "Alliance"
	f.professions = { { name = "Leatherworking", id = LEATHERWORKING, rank = 35, max = 150 } }
	for _, recipeID in ipairs(KNOWN) do
		f.known[recipeID] = true
	end
	for itemID, price in pairs({
		[LIGHT_LEATHER] = 20,
		[COARSE_LEATHER] = 60,
		[COARSE_THREAD] = 10,
		[FINE_THREAD] = 40,
		[CURED_LIGHT_HIDE] = 90,
		[SCRAPS] = 50,
	}) do
		fns.db.vendor[itemID] = price
	end
	fns.Changed("prices")
	fns.db.routeTargets[LEATHERWORKING] = 125
	fns.Changed("target")
	---@return table<integer, number>, table<integer, number>, string
	local function Read()
		local plan = fns.PlanRoute(profession)
		local made, need, crafts = {}, {}, {}
		for _, step in ipairs(plan.steps) do
			if step.subcraft then
				made[step.subcraft.itemID] = (made[step.subcraft.itemID] or 0) + step.subcraft.made
			end
		end
		for _, craft in ipairs(plan.crafts) do
			crafts[#crafts + 1] = craft.recipeID .. "x" .. craft.crafts
		end
		for _, item in ipairs(fns.RouteReagents(plan)) do
			need[item.itemID] = item.need
		end
		return made, need, table.concat(crafts, " ")
	end
	---@return table<integer, number>
	local function Tracked()
		local byItem = {}
		for _, item in ipairs(fns.TrackedNeeds()[1].items) do
			byItem[item.itemID] = item.need
		end
		return byItem
	end
	fns.SetTracked(LEATHERWORKING, true)
	local made, need, crafts = Read()
	assert(Tracked()[LIGHT_LEATHER], "the tracked list buys Light Leather")
	equal(made[LIGHT_LEATHER], nil, "while buying Light Leather is cheaper, no step makes it")
	assert(need[LIGHT_LEATHER], "and Reagents buys it")
	f.bags[SCRAPS] = 3 * need[LIGHT_LEATHER]
	f.Fire("BAG_UPDATE_DELAYED")
	f.Advance(0)
	local madeAfter, needAfter, craftsAfter = Read()
	equal(craftsAfter, crafts, "the followed route keeps its crafts")
	equal(needAfter[LIGHT_LEATHER], nil, "the held scraps cover its Light Leather")
	assert(madeAfter[LIGHT_LEATHER] and madeAfter[LIGHT_LEATHER] >= need[LIGHT_LEATHER], "and a step makes it")
	equal(Tracked()[LIGHT_LEATHER], nil, "the tracked shopping list follows the new step")
end

-- Held inputs come before the market's own maker too: with Transmute: Iron to Gold the cheapest Gold Bar at market,
-- held Gold Ore still smelts what it covers, so only the rest is transmuted from bought Iron Bars.
do
	local g = Client.load({ auctionator = false })
	local gns = g.ns
	g.level = 60
	g.professions = {
		{ name = "Blacksmithing", id = 164, rank = 150, max = 225 },
		{ name = "Mining", id = 186, rank = 150, max = 225 },
		{ name = "Alchemy", id = 171, rank = 225, max = 300 },
	}
	local GOLDEN_SCALE_COIF, SMELT_GOLD, TRANSMUTE_IRON_TO_GOLD = 3498, 3308, 11479
	local GOLD_ORE, IRON_BAR = 2776, 3575
	for _, recipeID in ipairs({ GOLDEN_SCALE_COIF, SMELT_GOLD, TRANSMUTE_IRON_TO_GOLD }) do
		g.known[recipeID] = true
	end
	for itemID, price in pairs({ [3577] = 500, [IRON_BAR] = 20, [GOLD_ORE] = 400, [3466] = 5, [3486] = 5, [4234] = 5 }) do
		gns.db.vendor[itemID] = price
	end
	gns.Changed("prices")
	g.bags[GOLD_ORE] = 4
	g.Fire("BAG_UPDATE_DELAYED")
	g.Advance(0)
	equal(gns.SubCraft(3577).recipeID, TRANSMUTE_IRON_TO_GOLD, "the market makes Gold Bars by transmuting")
	local need = {}
	for _, item in
		ipairs(gns.RouteReagents({ crafts = { { recipeID = GOLDEN_SCALE_COIF, crafts = 1 } }, training = {} }))
	do
		need[item.itemID] = item.need
	end
	equal(need[GOLD_ORE], 4, "the held Gold Ore smelts the coif's four Gold Bars")
	equal(need[IRON_BAR], 14, "so only the coif's own Iron Bars are bought, none for transmuting")
end

-- A maker that lists one input in two slots needs both slots' worth held: three scraps do not cover a recipe asking
-- for three twice.
do
	local d = Client.load({ auctionator = false })
	local dns = d.ns
	d.level = 60
	d.professions = { { name = "Leatherworking", id = LEATHERWORKING, rank = 35, max = 150 } }
	for _, recipeID in ipairs(KNOWN) do
		d.known[recipeID] = true
	end
	for itemID, price in pairs({ [LIGHT_LEATHER] = 20, [COARSE_THREAD] = 10, [SCRAPS] = 50 }) do
		dns.db.vendor[itemID] = price
	end
	local recipe = dns.RecipeData[2881]
	recipe.reagents = { { itemID = SCRAPS, quantity = 3 }, { itemID = SCRAPS, quantity = 3 } }
	dns.Changed("prices")
	d.bags[SCRAPS] = 3
	d.Fire("BAG_UPDATE_DELAYED")
	d.Advance(0)
	local BOOTS = 2149
	local need = {}
	for _, item in ipairs(dns.RouteReagents({ crafts = { { recipeID = BOOTS, crafts = 1 } }, training = {} })) do
		need[item.itemID] = item.need
	end
	equal(need[SCRAPS], nil, "three scraps make no Light Leather from a six-scrap schematic")
	assert(need[LIGHT_LEATHER], "so the boots' Light Leather is bought")
end

-- A held input this recipe needs directly is not spent making another of its reagents: with eight Essence of Fire
-- held and Essence of Earth cheaper to buy than to transmute from Fire, the Fire goes into the craft and the Earth is
-- bought.
do
	local a = Client.load({ auctionator = false })
	local ans = a.ns
	a.level = 60
	a.professions = { { name = "Alchemy", id = 171, rank = 300, max = 300 } }
	local STONE, FIRE_TO_EARTH = 17632, 17560
	local EARTH, FIRE = 7076, 7078
	a.known[STONE], a.known[FIRE_TO_EARTH] = true, true
	for itemID, price in pairs({
		[EARTH] = 100,
		[FIRE] = 200,
		[7080] = 5,
		[7082] = 5,
		[9262] = 5,
		[12803] = 5,
		[13468] = 5,
	}) do
		ans.db.vendor[itemID] = price
	end
	ans.Changed("prices")
	a.bags[FIRE] = 8
	a.Fire("BAG_UPDATE_DELAYED")
	a.Advance(0)
	local need = {}
	for _, item in ipairs(ans.RouteReagents({ crafts = { { recipeID = STONE, crafts = 1 } }, training = {} })) do
		need[item.itemID] = item.need
	end
	equal(need[FIRE], 8, "the held Fire goes into the craft")
	equal(need[EARTH], 8, "and the Earth is bought, not transmuted from it")

	-- Nor by an earlier craft of the route: Earth to Water first, then Fire to Earth with the held Fire.
	local EARTH_TO_WATER = 17561
	a.known[EARTH_TO_WATER] = true
	ans.Changed("prices")
	local route = {
		crafts = { { recipeID = EARTH_TO_WATER, crafts = 8 }, { recipeID = FIRE_TO_EARTH, crafts = 8 } },
		training = {},
	}
	local routeNeed = {}
	for _, item in ipairs(ans.RouteReagents(route)) do
		routeNeed[item.itemID] = item.need
	end
	equal(routeNeed[FIRE], 8, "the later craft keeps its held Fire")
	equal(routeNeed[EARTH], 8, "and the earlier craft buys its Earth")
end

Client.report("held_subcraft_spec")
