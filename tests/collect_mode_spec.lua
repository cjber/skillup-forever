-- Run from the repository root: luajit tests/collect_mode_spec.lua
-- Buying reagents is the default. Unobserved market costs remain unknown and searchable.
-- A character who chose gathering keeps that choice.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local TAILORING, LINEN, BOLT = 197, 2589, 2963

-- A Tailoring character whose only recipe uses Linen Cloth, a reagent anyone can loot, priced by nothing.
local function Load(saved, quantity, shared)
	local c = Client.load({
		saved = saved,
		data = {
			Thresholds = { [BOLT] = { 1, 30, 45, 60 }, [999] = shared and { 1, 30, 45, 60 } or nil },
			RecipeData = {
				[999] = shared and { skillLine = TAILORING, reagents = { { itemID = LINEN, quantity = 2 } } } or nil,
				[BOLT] = {
					skillLine = TAILORING,
					reagents = { { itemID = LINEN, quantity = quantity or 1 } },
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
	c.known[999] = shared or nil
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

-- Unknown purchase costs are excluded from ranking, but their recipes and reagents stay searchable.
local plan = ns.PlanRoute(ns.RouteProfessions()[TAILORING])
equal(#plan.crafts, 0, "an unknown zero placeholder cannot become a free route")
equal(plan.reached, 1, "no skill gain is promised without a known cost")
equal(plan.unpriced, 1, "the unpriced recipe is counted")
equal(plan.unpricedRecipes[1], BOLT, "and identified for the route page")
equal(ns.UnpricedReagents(plan)[1], LINEN, "the route page retains the missing market observation")
equal(ns.NetCost(BOLT), nil, "the recipe has no known net cost")
equal(
	ns.RouteBlocked(plan),
	"Auctionator hasn't seen these reagents yet: scan the auction house with it to price them.",
	"the route explains the missing observation"
)
ns.db.trackedProfessions[TAILORING] = true
c.G.AuctionHouseFrame = {
	IsShown = function()
		return true
	end,
}
c.Fire("AUCTION_HOUSE_SHOW")
c.Advance(0)
equal(#c.auctionSearches, 1, "opening the auction house searches a wholly unpriced tracked route")
equal(
	c.auctionSearches[1][1],
	"Linen Clothx1",
	"price discovery asks for one observation, not invented route quantities"
)
c.Fire("AUCTION_HOUSE_SHOW")
c.Advance(0)
equal(#c.auctionSearches, 1, "duplicate show events keep price discovery to one query per visit")
equal(
	#ns.PlanRoute(ns.RouteProfessions()[TAILORING]).crafts,
	0,
	"searching does not turn unknown costs into planned crafts"
)
c.auctionSearches = {}
equal((ns.SearchReagents(BOLT, 25)), "auctionator", "an unpriced recipe can still request its reagents")
equal(#c.auctionSearches, 1, "the recipe search reaches Auctionator")
equal(c.auctionSearches[1][1], "Linen Clothx25", "the query retains the exact reagent name and requested count")
equal(c.auction[LINEN], nil, "a search request does not invent an auction observation")
equal(ns.NetCost(BOLT), nil, "the cost stays unknown until an observation arrives")

-- Price discovery shares inventory and deduplicates excluded recipes, without inventing their route counts.
local shared, sharedNs = Load({ trackedProfessions = { [TAILORING] = true } }, 3, true)
shared.bags[LINEN] = 1
shared.G.AuctionHouseFrame = {
	IsShown = function()
		return true
	end,
}
shared.Fire("AUCTION_HOUSE_SHOW")
shared.Advance(0)
equal(#shared.auctionSearches, 1, "excluded recipes share one visit query")
equal(#shared.auctionSearches[1], 1, "their shared unpriced reagent appears once")
equal(shared.auctionSearches[1][1], "Linen Clothx2", "one-craft discovery subtracts the held copy once")
equal(shared.auction[LINEN], nil, "discovery still supplies no fictional price")
equal(#sharedNs.PlanRoute(sharedNs.RouteProfessions()[TAILORING]).crafts, 0, "excluded recipes remain unplanned")
shared.Fire("AUCTION_HOUSE_CLOSED")
shared.bags[LINEN] = 3
shared.Fire("BAG_UPDATE_DELAYED")
shared.Fire("AUCTION_HOUSE_SHOW")
shared.Advance(0)
equal(#shared.auctionSearches, 1, "fully held one-craft dependencies need no discovery query")

-- A character who picked gathering keeps it, and its reagent stays free.
local gathered, gatheredNs = Load({ valueGathered = false, collectModes = { ["Tester-Realm"] = "gather" } })
equal(gatheredNs.CollectMode(), "gather", "a saved gather choice is kept")
equal(gatheredNs.Price(LINEN).source, "gather", "so its reagent is priced as gathered")
equal(gatheredNs.Price(LINEN).copper, 0, "at no cost")
local gatheredPlan = gatheredNs.PlanRoute(gatheredNs.RouteProfessions()[TAILORING])
equal(#gatheredPlan.crafts > 0, true, "and the route still crafts with it")
equal(gathered.shoppingLists[gatheredNs.AuctionListName("Tailoring")], nil, "gather writes no Auctionator list")

Client.report("collect_mode_spec")
