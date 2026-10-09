-- Run from the repository root: luajit tests/prices_spec.lua
-- Latest Auctionator observations, bundled vendor prices and merchants seen.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local DAY = 86400
local DATA = {
	VendorPrices = { [2] = 40 },
	GatheredBy = {},
	RecipeData = {
		[10] = { skillLine = 164, reagents = { { itemID = 1, quantity = 2 } }, output = { itemID = 7, quantity = 1 } },
	},
}
local c = Client.load({ data = DATA })
local ns, api = c.ns, c.G.Auctionator.API.v1
c.auction, c.auctionAge = { [1] = 500, [2] = 30, [3] = 90, [50] = 500 }, 1

equal(ns.Price(1).copper, 500, "an auction price comes from Auctionator")
equal(ns.Price(1).source, "auctionator", "Auctionator is the auction source")
equal(ns.Price(1).days, 1, "Auctionator's age is kept")
equal(ns.Price(2).source, "auctionator", "a cheaper Auctionator price beats the bundled vendor price")
equal(ns.Price(3).copper, 90, "another item's price comes from Auctionator too")
equal(ns.Price(99), nil, "an item nobody priced has no price")

-- The age API's sentinel and its absence, on an item no scan has filed.
c.auctionAge = nil
ns.Changed("prices")
equal(ns.Price(50).days, nil, "a successful nil age stays unknown")
equal(ns.PriceAgeText(ns.Price(50)), "over 3 weeks ago", "the nil age is Auctionator's old-price sentinel")
equal(ns.PriceAge(ns.Price(50)), 22 * DAY, "which is stale")
local ageAPI = api.GetAuctionAgeByItemID
api.GetAuctionAgeByItemID = nil
ns.Changed("prices")
equal(ns.Price(50).copper, 500, "missing age capability keeps the known price")
equal(ns.PriceAge(ns.Price(50)), nil, "missing age capability leaves age unknown")
equal(ns.PriceAgeText(ns.Price(50)), "unknown age", "missing age capability does not claim a date")
api.GetAuctionAgeByItemID = function()
	error("age API failed")
end
ns.Changed("prices")
equal(ns.PriceAgeText(ns.Price(50)), "unknown age", "failed age call does not claim an old date")
api.GetAuctionAgeByItemID = ageAPI
ns.Changed("prices")

-- Every database update uses the newest observation, including a higher price on the same day.
c.auctionAge = 0
c.auction[1] = 300
c.AuctionatorScan()
equal(ns.Price(1).copper, 300, "a database update invalidates cached prices")
c.auction[1] = 900
c.AuctionatorScan()
equal(ns.Price(1).copper, 900, "a higher same-day price replaces the earlier price")
c.now = c.now + DAY
c.auction[1], c.auctionAge = 100, 1
c.AuctionatorScan()
equal(ns.Price(1).copper, 100, "the newest price is never averaged with older scans")
equal(ns.Price(1).days, 1, "the observation retains Auctionator's age")
equal(ns.PriceSourceText(ns.Price(1)), "Auctionator, 1d ago", "the source reports the observation age")
c.auction[2] = 200
c.AuctionatorScan()
equal(ns.Price(2).copper, 40, "a cheaper vendor still beats the latest auction price")

-- A vendor visit records the unit price, reputation discount included, and it beats the auction.
c.merchant = { { itemID = 3, price = 100, stackCount = 5 }, { itemID = 4, price = 10, hasExtendedCost = true } }
c.Fire("MERCHANT_SHOW")
equal(ns.db.vendor[3], 20, "a merchant's price is recorded per unit")
equal(ns.db.vendor[4], nil, "a token price is not a money price")
equal(ns.Price(3).source, "vendor", "the vendor's price beats the filed auction price")
equal(ns.Price(3).copper, 20, "the vendor's unit price is used")

-- A merchant entry without a stack size says nothing about the unit price.
c.merchant = { { itemID = 3, price = 100, stackCount = 0 }, { itemID = 5, price = 100 } }
c.Fire("MERCHANT_UPDATE")
equal(ns.db.vendor[3], 20, "a zero stack size keeps the earlier unit price")
equal(ns.db.vendor[5], nil, "a missing stack size records nothing")

-- Reagent costs and crafted-item resale both follow database updates.
do
	local craft = Client.load({ data = DATA })
	craft.ns.db.craftValue = "auction"
	craft.auction = { [1] = 100, [7] = 200 }
	local cost, value = craft.ns.CraftCost(10)
	equal(cost, 200, "craft cost uses the latest reagent price")
	equal(value.copper, 190, "resale uses the latest output price after the cut")
	craft.auction[1], craft.auction[7] = 300, 400
	craft.AuctionatorScan()
	cost, value = craft.ns.CraftCost(10)
	equal(cost, 600, "a scan refreshes craft costs")
	equal(value.copper, 380, "a scan refreshes crafted-item resale")
end

-- Obsolete saved history and settings cannot supply a price, including when the latest is missing.
local m = Client.load({ data = DATA, saved = {
	priceDays = { Realm = { [1] = { [1] = 1 } } },
	latestPrice = false,
} })
m.auction = { [1] = 800 }
equal(m.ns.Price(1).copper, 800, "old saves use the latest observation")
m.auction[1] = nil
m.AuctionatorScan()
equal(m.ns.Price(1), nil, "a missing latest price stays unknown")
local lookup = m.G.Auctionator.API.v1.GetAuctionPriceByItemID
m.G.Auctionator.API.v1.GetAuctionPriceByItemID = nil
m.ns.Changed("prices")
equal(m.ns.Price(1), nil, "a missing price API stays unknown")
m.G.Auctionator.API.v1.GetAuctionPriceByItemID = lookup
m.auction[1] = 800
m.ns.Changed("prices")
equal(m.ns.Price(1).copper, 800, "the latest price returns with the API")

-- Without Auctionator, only vendor prices exist.
ns = Client.load({ data = DATA, auctionator = false }).ns
equal(ns.Price(1), nil, "without Auctionator an auction-only reagent has no price")
equal(ns.Price(2).source, "vendor", "without Auctionator the bundled vendor price is used")

Client.report("prices_spec")
