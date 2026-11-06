-- Run from the repository root: luajit tests/tailoring_route_spec.lua
-- Issue #339: Tailoring 40 to 75 asked for 190 Linen Bags and 1202 Linen Cloth. The route is planned twice
-- through the route tab's planner: with every trainer recipe allowed, and with only the recipes known at 40.
-- Linen Cloth is priced and no Bolt of Linen Cloth is, so the reagent list expands each bolt into the cloth
-- it is made from, which is what the report counted.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local TAILORING = 197
local LINEN, THREAD, BLEACH = 2589, 2320, 2324
local BOLT, VEST, BELT, BAG = 2963, 2385, 8776, 3755
local SHIRT, CAPE, BOOTS, BARBARIC, ROBE, SIMPLE_BOOTS = 2393, 2397, 2386, 2395, 7623, 12045
local NAMES = {
	[BOLT] = "Bolt of Linen Cloth",
	[VEST] = "Brown Linen Vest",
	[BELT] = "Linen Belt",
	[BAG] = "Linen Bag",
	[SHIRT] = "White Linen Shirt",
	[CAPE] = "Reinforced Linen Cape",
	[BOOTS] = "Linen Boots",
	[BARBARIC] = "Barbaric Linen Vest",
	[ROBE] = "Brown Linen Robe",
	[SIMPLE_BOOTS] = "Simple Linen Boots",
}
-- The trainer recipes a Tailoring 40 character has by then: the bag, shirt and belt are taught long before 40.
local KNOWN = {
	[BOLT] = true,
	[VEST] = true,
	[BELT] = true,
	[BAG] = true,
	[SHIRT] = true,
	[CAPE] = true,
	[BOOTS] = true,
	[BARBARIC] = true,
	[ROBE] = true,
	[SIMPLE_BOOTS] = true,
}

local function Load()
	local c = Client.load({ saved = { vendor = { [LINEN] = 20, [THREAD] = 10, [BLEACH] = 20 } } })
	c.level = 60
	c.professions = { { name = "Tailoring", id = TAILORING, rank = 40, max = 75 } }
	for recipeID, name in pairs(NAMES) do
		c.spells[recipeID] = name
	end
	for recipeID in pairs(KNOWN) do
		c.known[recipeID] = true
	end
	return c
end

-- The route tab's own plan. With `trainers` off, every recipe the character does not know is skipped, so
-- the planner sees only the recipes known at 40 and trains nothing.
local function Plan(c, trainers)
	local ns = c.ns
	if not trainers then
		for recipeID, recipe in pairs(ns.RecipeData) do
			if recipe.skillLine == TAILORING and not KNOWN[recipeID] then
				ns.SetSkipped(recipeID, true)
			end
		end
	end
	ns.db.routeTargets[TAILORING] = 75
	ns.Changed("target")
	return ns.PlanRoute(ns.RouteProfessions()[TAILORING])
end

-- What the report counted: the linen cloth the plan needs once each bolt is made from two cloth.
local function Cloth(ns, plan)
	for _, item in ipairs(ns.RouteReagents(plan)) do
		if item.itemID == LINEN then
			return item.need
		end
	end
	return 0
end

-- Print the steps the way the report read them, and assert they are a route a player would walk.
local function Check(label, c, trainers)
	local ns = c.ns
	local plan = Plan(c, trainers)
	local bags, cloth = 0, Cloth(ns, plan)
	print(label .. ":")
	for _, craft in ipairs(plan.crafts) do
		local thresholds = ns.Model.Get(craft.recipeID)
		local chance = ns.Model.Chance(thresholds, craft.from)
		if craft.recipeID == BAG then
			bags = bags + craft.crafts
		end
		print(
			string.format(
				"  %s %d to %d: %d crafts, %s, %.0f%% chance at the start",
				NAMES[craft.recipeID] or ("recipe " .. craft.recipeID),
				craft.from,
				craft.to,
				craft.crafts,
				craft.color,
				chance * 100
			)
		)
	end
	print(string.format("  %d Linen Cloth in all", cloth))
	equal(plan.target, 75, label .. ": the target is 75")
	equal(plan.reached, 75, label .. ": the route reaches 75")
	equal(#plan.crafts > 0, true, label .. ": there are crafts to walk")
	equal(bags <= 30, true, label .. ": the route does not stay on Linen Bags into grey")
	equal(cloth <= 300, true, label .. ": 40 to 75 stays under 300 Linen Cloth, not 1202")
end

Check("trainer recipes allowed", Load(), true)
Check("known recipes only", Load(), false)

Client.report("tailoring_route_spec")
