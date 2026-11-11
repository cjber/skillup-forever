-- Run from the repository root: luajit tests/collect_mode_spec.lua
-- #559: buying reagents is the default, and a gatherable nothing has priced is still bought at the auction
-- house as a price unknown rather than dropped from the route. A character who chose gathering keeps it.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local TAILORING, LINEN, BOLT = 197, 2589, 2963

-- A Tailoring character whose only recipe uses Linen Cloth, a reagent anyone can loot, priced by nothing.
local function Load(saved)
	local c = Client.load({
		saved = saved,
		data = {
			Thresholds = { [BOLT] = { 1, 30, 45, 60 } },
			RecipeData = {
				[BOLT] = {
					skillLine = TAILORING,
					reagents = { { itemID = LINEN, quantity = 1 } },
					output = { itemID = 2964, quantity = 1 },
				},
			},
			TrainerFees = {},
			TrainerRanks = {},
			RankBooks = {},
			ItemSellPrices = {},
			GatheredBy = {},
			LootedFrom = { [LINEN] = true },
			VendorPrices = {},
			ProfessionTrainers = {},
			ScrollDrops = {},
			WorldDrops = {},
		},
	})
	c.level = 60
	c.player.faction = "Alliance"
	c.professions = { { name = "Tailoring", id = TAILORING, rank = 1, max = 75 } }
	c.items[LINEN] = { name = "Linen Cloth" }
	c.items[2964] = { name = "Bolt of Linen Cloth", sell = 0 }
	c.known[BOLT] = true
	c.spells[BOLT] = "Bolt of Linen Cloth"
	local ns = c.ns
	ns.db.routeTargets[TAILORING] = 26
	ns.Changed("target")
	return c, ns
end

-- A new character buys: the default mode, named in the route's own type.
local c, ns = Load(nil)
equal(ns.CollectMode(), "auction", "a character with no saved choice buys reagents")
local price = ns.Price(LINEN)
equal(price ~= nil, true, "the looted reagent keeps a price record")
equal(price.source, "auction", "under the auction house")
equal(price.unknown, true, "as a price unknown")
equal(ns.PriceSource(LINEN), "auction", "so the shopping list puts it in the auction bucket")
equal(ns.Model.ShoppingSource(ns.PriceSource(LINEN)), "auction", "the bucket the window draws")

-- The route keeps the recipe: nothing priced it, but it is still something to buy (#162, #559).
local plan = ns.PlanRoute(ns.RouteProfessions()[TAILORING])
equal(#plan.crafts > 0, true, "the route still has its craft")
equal(ns.RouteBlocked(plan), nil, "and is not blocked for the unpriced reagent")
local reagent
for _, item in ipairs(ns.RouteReagents(plan)) do
	if item.itemID == LINEN then
		reagent = item
	end
end
equal(reagent and reagent.source, "auction", "the reagent list sends it to the auction house")

-- The shopping list says it is a price unknown, never a made-up number, and still lists it in Auctionator.
ns.db.trackedProfessions[TAILORING] = true
ns.SetCollectMode("auction")
local lists = ns.ShoppingList()
local row
for _, list in ipairs(lists) do
	for _, item in ipairs(list.items) do
		if item.itemID == LINEN then
			row = item
		end
	end
end
equal(row and row.source, "auction", "the shopping list keeps it under Auction house")
equal(row and row.price, nil, "with no price")
equal(row and row.cost, nil, "and no cost")
local listName = ns.AuctionListName("Tailoring")
equal(type(c.shoppingLists[listName]), "table", "and writes the Auctionator list")
local needed = 0
for _, item in ipairs(ns.RouteReagents(plan)) do
	if item.itemID == LINEN then
		needed = item.need
	end
end
equal(c.shoppingLists[listName][1], "Linen Clothx" .. needed, "with its exact name and what the route needs")

-- A character who picked gathering keeps it, and its reagent stays free.
local gathered, gatheredNs = Load({ collectModes = { ["Tester-Realm"] = "gather" } })
equal(gatheredNs.CollectMode(), "gather", "a saved gather choice is kept")
equal(gatheredNs.Price(LINEN).source, "gather", "so its reagent is priced as gathered")
equal(gatheredNs.Price(LINEN).copper, 0, "at no cost")
local gatheredPlan = gatheredNs.PlanRoute(gatheredNs.RouteProfessions()[TAILORING])
equal(#gatheredPlan.crafts > 0, true, "and the route still crafts with it")
equal(gathered.shoppingLists[gatheredNs.AuctionListName("Tailoring")], nil, "gather writes no Auctionator list")

Client.report("collect_mode_spec")
