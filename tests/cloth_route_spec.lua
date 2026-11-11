-- Run from the repository root: luajit tests/cloth_route_spec.lua
-- Issue #487: a Tailoring or First Aid character with no Auctionator and the default collect mode got an
-- empty route because every cloth reagent was left out for want of a price. Cloth is loot, so with Buy
-- reagents off it costs nothing and the route is there.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local TAILORING, FIRST_AID = 197, 129
local LINEN, WOOL = 2589, 2592
local BOLT, LINEN_BANDAGE, HEAVY_LINEN_BANDAGE = 2963, 3275, 3276

-- A character with this profession, the recipes it knows and a route target, and the plan for it.
local function Load(name, skillLine, rank, max, known, target)
	local c = Client.load({ auctionator = false })
	c.level = 60
	c.player.faction = "Alliance"
	c.professions = { { name = name, id = skillLine, rank = rank, max = max } }
	for _, recipeID in ipairs(known) do
		c.known[recipeID] = true
		c.spells[recipeID] = "Recipe " .. recipeID
	end
	local ns = c.ns
	ns.SetCollectMode("gather")
	ns.db.routeTargets[skillLine] = target
	ns.Changed("target")
	return c, ns.PlanRoute(ns.RouteProfessions()[skillLine])
end

-- Cloth is carried by creatures, so anyone can loot it and the gather mode prices it at nothing.
local c, plan = Load("Tailoring", TAILORING, 1, 75, { BOLT }, 26)
local ns = c.ns
equal(ns.CollectMode(), "gather", "the gather choice is kept")
equal(ns.CanGather(LINEN), "loot", "Linen Cloth is loot anyone can get")
equal(ns.Price(LINEN).source, "gather", "so it is priced as gathered")
equal(ns.Price(LINEN).copper, 0, "at no cost with Buy reagents off")
equal(#plan.crafts > 0, true, "a Tailoring route with only a linen recipe still has crafts")
equal(ns.RouteBlocked(plan), nil, "and is not blocked for an unpriced reagent")

-- The same for First Aid, whose first recipes are bandages made from the same cloth.
local firstAid, firstAidPlan = Load("First Aid", FIRST_AID, 1, 75, { LINEN_BANDAGE, HEAVY_LINEN_BANDAGE }, 26)
local firstAidNs = firstAid.ns
equal(#firstAidPlan.crafts > 0, true, "a First Aid route with linen bandages still has crafts")
equal(firstAidNs.RouteBlocked(firstAidPlan), nil, "and is not blocked for an unpriced reagent")

-- Wool is both looted from creatures and skinned from sheep: a Tailoring character without Skinning still
-- gets it from the creatures that carry it.
local wool, woolPlan = Load("Tailoring", TAILORING, 80, 150, { 3277 }, 100)
local woolNs = wool.ns
equal(woolNs.CanGather(WOOL), "loot", "Wool Cloth is loot for a character without Skinning")
equal(woolNs.Price(WOOL).source, "gather", "so it is priced as gathered")
equal(#woolPlan.crafts > 0, true, "a Tailoring route that needs wool still has crafts")
equal(woolNs.RouteBlocked(woolPlan), nil, "and is not blocked for an unpriced reagent")

Client.report("cloth_route_spec")
