-- Run from the repository root: luajit tests/collect_mode_spec.lua
-- Buying reagents is the default. Unobserved market costs remain unknown and searchable.
-- A character who chose gathering keeps that choice.
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

-- An unknown purchase cost plans as an unknown-cost step, ranked after any priced recipe, and stays counted and
-- searchable (#559, #855): the route still shows what to craft, never as free.
local plan = ns.PlanRoute(ns.RouteProfessions()[TAILORING])
equal(#plan.crafts, 1, "the recipe waiting on an auction price still plans")
equal(plan.reached, 26, "so the route reaches its target")
equal(ns.PlanMoney(plan).unknown > 0, true, "with its cost unknown, never free")
equal(plan.unpriced, 0, "a step on the route is not counted as left out")
local routeLinen
for _, item in ipairs(ns.RouteReagents(plan)) do
	if item.itemID == LINEN then
		routeLinen = item
	end
end
equal(routeLinen ~= nil and routeLinen.need > 0, true, "the route page lists the reagent it waits on")
equal(#ns.UnpricedReagents(plan), 0, "once, with the route's own reagents")
equal(ns.NetCost(BOLT), nil, "the recipe has no known net cost")
equal(ns.RouteBlocked(plan), nil, "a route with a craft to show is not blocked")
c.G.AuctionHouseFrame = {
	IsShown = function()
		return true
	end,
}
equal((ns.SearchReagents(BOLT, 25)), "auctionator", "an unpriced recipe can still request its reagents")
equal(#c.auctionSearches, 1, "the recipe search reaches Auctionator")
equal(c.auctionSearches[1][1], "Linen Clothx25", "the query retains the exact reagent name and requested count")
equal(c.auction[LINEN], nil, "a search request does not invent an auction observation")
equal(ns.NetCost(BOLT), nil, "the cost stays unknown until an observation arrives")

-- A character who picked gathering keeps it, and its reagent stays free.
local gathered, gatheredNs =
	Load({ valueGathered = false, gatheredValueSeen = true, collectModes = { ["Tester Surname-6941"] = "gather" } })
equal(gatheredNs.CollectMode(), "gather", "a saved gather choice is kept")
equal(gatheredNs.Price(LINEN).source, "gather", "so its reagent is priced as gathered")
equal(gatheredNs.Price(LINEN).copper, 0, "at no cost")
local gatheredPlan = gatheredNs.PlanRoute(gatheredNs.RouteProfessions()[TAILORING])
equal(#gatheredPlan.crafts > 0, true, "and the route still crafts with it")
equal(gathered.shoppingLists[gatheredNs.AuctionListName("Tailoring")], nil, "gather writes no Auctionator list")

Client.report("collect_mode_spec")
