-- Run from the repository root: luajit tests/cooking_route_spec.lua
-- Issue #358: a Cooking route from 1 to 150 with Slitherskin Mackerel known and its raw fish priced at a
-- vendor, plus the meats and egg the player also knows, whose reagents only creatures drop.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local COOKING = 185
local MACKEREL, WOLF, BOAR, EGG = 7752, 2538, 2540, 8604
local RAW_MACKEREL, WOLF_MEAT, BOAR_MEAT, SMALL_EGG = 6303, 2672, 769, 6889
local VENDOR_SCROLL, VENDOR_RECIPE = 6329, 7754
local MILD_SPICES, LOCH_FRENZY = 2678, 6317

local c = Client.load({
	auctionator = false,
	saved = { vendor = { [RAW_MACKEREL] = 5 } },
})
local ns = c.ns
ns.SetCollectMode("gather")
c.level = 60
c.player.faction = "Alliance"
c.professions = { { name = "Cooking", id = COOKING, rank = 1, max = 75 } }
for _, recipeID in ipairs({ MACKEREL, WOLF, BOAR, EGG }) do
	c.known[recipeID] = true
end

local function Cooking(base, max)
	base, max = base or 1, max or 75
	return {
		skillLine = COOKING,
		name = "Cooking",
		base = base,
		modifier = 0,
		skill = base,
		max = max,
		capped = base >= max,
	}
end

local function Plan(target, profession)
	ns.db.routeTargets[COOKING] = target
	ns.Changed("target")
	return ns.PlanRoute(profession or Cooking())
end

local function Reagent(items, itemID)
	for _, item in ipairs(items) do
		if item.itemID == itemID then
			return item
		end
	end
end

local function Training(plan, recipeID)
	for _, step in ipairs(plan.training) do
		if step.recipeID == recipeID then
			return step
		end
	end
end

local function Crafts(plan)
	local crafts = {}
	for _, craft in ipairs(plan.crafts) do
		crafts[craft.recipeID] = true
	end
	return crafts
end

-- A reagent only creatures drop is gathered for nothing, not left out: every known recipe is planned,
-- through a free Stringy Wolf Meat, Chunk of Boar Meat or Small Egg (#358, part 2).
equal(ns.CanGather(WOLF_MEAT), "loot", "a reagent only creatures drop is lootable")
equal(ns.Price(WOLF_MEAT).source, "gather", "and priced as gathered")
equal(ns.Price(WOLF_MEAT).copper, 0, "at no cost")
local lootedPlan = Plan(100)
equal(lootedPlan.unpriced, 0, "no known recipe is left out for an unpriced reagent")
equal(#lootedPlan.unpricedRecipes, 0, "and none is named")
local used = Crafts(lootedPlan)
equal(used[WOLF] or used[BOAR] or used[EGG], true, "a recipe whose reagent only drops is planned")
local reagents = ns.RouteReagents(lootedPlan)
local looted = nil
for _, itemID in ipairs({ WOLF_MEAT, BOAR_MEAT, SMALL_EGG }) do
	local item = Reagent(reagents, itemID)
	looted = looted or (item and item.source == "gather" and itemID)
end
equal(looted ~= nil, true, "its reagent is in the reagent list as gathered")

-- The issue's own setup: the raw fish is priced at a vendor, and the route reaches the target instead of
-- grinding Slitherskin Mackerel to 85 and stopping (#358).
equal(ns.Price(RAW_MACKEREL).source, "vendor", "the raw fish is bought at its vendor price")
local plan = Plan(150)
equal(plan.target, 150, "the requested target")
equal(plan.reached, 150, "the route reaches it")
equal(plan.stopReason, nil, "without running out of recipes")
equal(plan.unpriced, 0, "with every known recipe planned")
equal(plan.ranks[1] and plan.ranks[1].name, "Journeyman", "and trains the next rank on the way")

-- Part 1: a recipe sold as a scroll at a vendor is planned like training. Its scroll's vendor price is the
-- fee and the scroll's required skill is where it is learned. The trainer's own recipes are skipped here so
-- only the vendor recipe can carry the route past the known ones.
ns.db.vendor[VENDOR_SCROLL] = 500
ns.db.vendor[LOCH_FRENZY] = 3
ns.Changed("prices")
for recipeID in pairs(ns.TrainerFees) do
	local recipe = ns.RecipeData[recipeID]
	if recipe and recipe.skillLine == COOKING then
		ns.SetSkipped(recipeID, true)
	end
end
local vendor = Plan(100)
local bought = Training(vendor, VENDOR_RECIPE)
equal(bought ~= nil, true, "a vendor-sold recipe is planned unwrapped")
equal(bought and bought.fee, 500, "with the scroll's vendor price as its fee")
equal(bought and bought.scroll, VENDOR_SCROLL, "and carries the scroll item that teaches it")
equal(bought and bought.reqSkill, 50, "and the scroll's required skill")
equal(bought and bought.usedAt >= bought.reqSkill, true, "used no earlier than the scroll is learnable")
equal(Crafts(vendor)[VENDOR_RECIPE], true, "and the route crafts it")
local spices = Reagent(ns.RouteReagents(vendor), MILD_SPICES)
equal(spices and spices.source, "vendor", "its vendor reagent is bought")
local frenzy = Reagent(ns.RouteReagents(vendor), LOCH_FRENZY)
equal(frenzy and frenzy.source, "vendor", "and the fish it needs is bought")

-- Part 4: the next recipe replaces the long green stretch. At 65 the known meats are green and the scroll
-- recipe is still yellow, so the cheaper point per skill is the scroll recipe's.
local meat
for _, craft in ipairs(vendor.crafts) do
	if craft.recipeID == WOLF or craft.recipeID == BOAR or craft.recipeID == EGG then
		meat = craft
		break
	end
end
equal(meat ~= nil, true, "a known meat recipe starts the route")
equal(meat and meat.to <= 65, true, "and stops before its green band")
for recipeID in pairs(ns.TrainerFees) do
	local recipe = ns.RecipeData[recipeID]
	if recipe and recipe.skillLine == COOKING then
		ns.SetSkipped(recipeID, false)
	end
end

-- Part 3: the limit is per vendor, not an item every seller must limit: 6303 is bought at a seller that
-- stocks only 5, while an item at a seller with no limit is not flagged (#358). The bundled table keeps
-- each npc_vendor row's maxcount by NPC.
equal(type(ns.LimitedStock[6270]), "table", "the bundled data keeps limited stock per vendor")
equal(ns.LimitedStock[MILD_SPICES], nil, "an item no vendor limits has no entry")
local VENDOR_NPC, LIMITED = 5001, 5
local limited = Client.load({
	auctionator = false,
	saved = {
		vendor = { [RAW_MACKEREL] = 5 },
		sellers = {
			[VENDOR_NPC] = {
				name = "Fish Vendor",
				side = "A",
				map = 10,
				x = 0.5,
				y = 0.5,
				items = { [RAW_MACKEREL] = true, [MILD_SPICES] = true },
			},
		},
	},
	data = { LimitedStock = { [RAW_MACKEREL] = { [VENDOR_NPC] = LIMITED } } },
})
limited.level = 60
limited.player.faction = "Alliance"
limited.professions = { { name = "Cooking", id = COOKING, rank = 1, max = 75 } }
limited.known[MACKEREL] = true
local lns = limited.ns
lns.db.routeTargets[COOKING] = 45
local limitedPlan = lns.PlanRoute({
	skillLine = COOKING,
	name = "Cooking",
	base = 1,
	modifier = 0,
	skill = 1,
	max = 75,
	capped = false,
})
equal(lns.NearestVendor(RAW_MACKEREL, true), VENDOR_NPC, "the route's vendor sells the fish")
equal(lns.IsLimitedStock(RAW_MACKEREL), LIMITED, "the fish is flagged at a vendor that limits it")
equal(lns.NearestVendor(MILD_SPICES, true), VENDOR_NPC, "the same vendor is nearest for an unlimited reagent")
equal(lns.IsLimitedStock(MILD_SPICES), nil, "an item at an unlimited vendor is not flagged")
local fish = Reagent(lns.RouteReagents(limitedPlan), RAW_MACKEREL)
equal(fish ~= nil, true, "the limited reagent is on the route")
equal(fish and fish.source, "vendor", "bought from its vendor")
equal(fish and fish.limited, LIMITED, "and marked with the limited stock count")

-- A vendor's own window is the newest word on its stock: the fish at a seller no bundled data limits is
-- flagged from what the window shows (#358).
local unbundled = Client.load({
	auctionator = false,
	saved = {
		sellers = {
			[VENDOR_NPC] = {
				name = "Fish Vendor",
				side = "A",
				map = 10,
				x = 0.5,
				y = 0.5,
				items = { [RAW_MACKEREL] = true },
			},
		},
	},
	data = { LimitedStock = {} },
})
unbundled.level = 60
unbundled.player.faction = "Alliance"
unbundled.npc = { id = VENDOR_NPC, name = "Fish Vendor" }
unbundled.merchant = { { itemID = RAW_MACKEREL, price = 5, stackCount = 1, numAvailable = LIMITED } }
local uns = unbundled.ns
equal(uns.LimitedStock[RAW_MACKEREL], nil, "the bundled data does not limit the fish")
unbundled.Fire("MERCHANT_SHOW")
equal(uns.IsLimitedStock(RAW_MACKEREL), LIMITED, "a vendor's own count flags the fish")
equal(
	uns.db.stock[RAW_MACKEREL] and uns.db.stock[RAW_MACKEREL][VENDOR_NPC],
	LIMITED,
	"and the count is saved per vendor"
)

-- The same fish at a vendor whose window shows no limit is not flagged, though the bundled data limits it.
limited.npc = { id = VENDOR_NPC, name = "Fish Vendor" }
limited.merchant = { { itemID = RAW_MACKEREL, price = 5, stackCount = 1, numAvailable = -1 } }
limited.Fire("MERCHANT_SHOW")
equal(lns.IsLimitedStock(RAW_MACKEREL), nil, "a seen unlimited vendor clears the bundled limit")
equal(lns.db.stock[RAW_MACKEREL][VENDOR_NPC], false, "and is saved as unlimited")
equal(Reagent(lns.RouteReagents(limitedPlan), RAW_MACKEREL).limited, nil, "the route's reagent is no longer flagged")

-- A limited item sold out when the window opens proves the limit: zero is saved as limited, at least one,
-- and the highest count seen stays (#560).
local soldOut = Client.load({
	auctionator = false,
	saved = {
		sellers = {
			[VENDOR_NPC] = {
				name = "Fish Vendor",
				side = "A",
				map = 10,
				x = 0.5,
				y = 0.5,
				items = { [RAW_MACKEREL] = true },
			},
		},
	},
	data = { LimitedStock = {} },
})
soldOut.level = 60
soldOut.player.faction = "Alliance"
soldOut.professions = { { name = "Cooking", id = COOKING, rank = 1, max = 75 } }
soldOut.known[MACKEREL] = true
soldOut.npc = { id = VENDOR_NPC, name = "Fish Vendor" }
soldOut.merchant = { { itemID = RAW_MACKEREL, price = 5, stackCount = 1, numAvailable = 0 } }
local ons = soldOut.ns
ons.db.routeTargets[COOKING] = 45
soldOut.Fire("MERCHANT_SHOW")
equal(
	ons.db.stock[RAW_MACKEREL] and ons.db.stock[RAW_MACKEREL][VENDOR_NPC],
	1,
	"a sold-out item is saved as limited, at least one"
)
equal(ons.IsLimitedStock(RAW_MACKEREL), 1, "and the route flags it limited")
local soldPlan = ons.PlanRoute(Cooking())
local soldFish = Reagent(ons.RouteReagents(soldPlan), RAW_MACKEREL)
equal(soldFish and soldFish.limited, 1, "the route's reagent carries the limit")
soldOut.merchant = { { itemID = RAW_MACKEREL, price = 5, stackCount = 1, numAvailable = 4 } }
soldOut.Fire("MERCHANT_UPDATE")
equal(ons.IsLimitedStock(RAW_MACKEREL), 4, "a later count raises the limit")
soldOut.merchant = { { itemID = RAW_MACKEREL, price = 5, stackCount = 1, numAvailable = 0 } }
soldOut.Fire("MERCHANT_UPDATE")
equal(ons.IsLimitedStock(RAW_MACKEREL), 4, "a sold-out reading keeps the highest count seen")

Client.report("cooking_route_spec")
