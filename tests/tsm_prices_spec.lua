-- Run from the repository root: luajit tests/tsm_prices_spec.lua
-- TradeSkillMaster's AuctionDB as an auction price source, alone and beside Auctionator.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local DATA = {
	VendorPrices = { [2] = 40 },
	GatheredBy = {},
	RecipeData = {
		[10] = { skillLine = 164, reagents = { { itemID = 1, quantity = 2 } }, output = { itemID = 7, quantity = 1 } },
	},
}

local c = Client.load({ data = DATA, auctionator = false, tsm = { [1] = 500, [2] = 30, [3] = 90 } })
local ns = c.ns
equal(ns.HasAuctionator(), false, "Auctionator is not installed")
equal(ns.HasTradeSkillMaster(), true, "TradeSkillMaster is")
equal(ns.Price(1).copper, 500, "an auction price comes from TSM")
equal(ns.Price(1).source, "tsm", "and says so")
equal(ns.PriceSourceText(ns.Price(1)), "TradeSkillMaster", "the tooltip names it, with no age")
equal(ns.Model.ShoppingSource("tsm"), "auction", "a TSM price is bought at the auction house")
equal(ns.Price(2).source, "tsm", "a cheaper TSM price beats the bundled vendor price")
equal(ns.Price(99), nil, "an item TSM has nothing for stays unpriced")
equal(
	ns.UnpricedHint(),
	"Update TradeSkillMaster's AuctionDB with the TSM desktop app, or visit a vendor, to price reagents.",
	"the unpriced hint points at TSM"
)

-- TSM reads its AuctionDB at login: a price asked for earlier is empty until the first entering-world event.
c.tsm[99] = 70
equal(ns.Price(99), nil, "the empty answer is cached")
c.Fire("PLAYER_ENTERING_WORLD")
equal(ns.Price(99).copper, 70, "entering the world asks again")
c.tsm[99] = 80
c.Fire("PLAYER_ENTERING_WORLD")
equal(ns.Price(99).copper, 70, "later zoning keeps the cache")

-- A broken or changed API is no price, not an error.
local broken = Client.load({ data = DATA, auctionator = false, tsm = {} })
broken.G.TSM_API.GetCustomPriceValue = function()
	error("boom")
end
equal(broken.ns.Price(1), nil, "an erroring API prices nothing")

-- With both, Auctionator's observation wins and TSM fills only its gaps.
local both = Client.load({ data = DATA, tsm = { [1] = 500, [3] = 90 } })
both.auction, both.auctionAge = { [1] = 400 }, 1
both.ns.Changed("prices")
equal(both.ns.Price(1).source, "auctionator", "Auctionator stays first")
equal(both.ns.Price(1).copper, 400, "at its own price")
equal(both.ns.Price(3).source, "tsm", "TSM fills what Auctionator has not seen")

-- Without TSM nothing changes.
local none = Client.load({ data = DATA, auctionator = false })
equal(none.ns.HasTradeSkillMaster(), false, "no TSM_API, no TSM")
equal(none.ns.Price(1), nil, "and no auction price")

-- A self-supplied reagent priced at market keeps the source that priced it, so it joins the auction bucket.
local ORE = 2770
local market = Client.load({
	data = { VendorPrices = {}, GatheredBy = {}, LootedFrom = { [ORE] = true }, RecipeData = {} },
	auctionator = false,
	tsm = { [ORE] = 1000 },
})
market.ns.SetCollectMode("gather")
market.ns.db.auctionOnly = true
market.ns.Changed("prices")
equal(market.ns.Price(ORE).source, "tsm", "market-priced self-supply reads as TSM")
equal(market.ns.Price(ORE).worth, "auction", "valued at its auction price")

Client.report("tsm_prices_spec")
