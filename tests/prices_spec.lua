-- Run from the repository root: luajit tests/prices_spec.lua
-- Where a price comes from, with the whole addon loaded: Auctionator, the bundled vendor list and merchants seen.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local DATA = { VendorPrices = { [2] = 40 }, GatheredBy = {} }
local c = Client.load({ data = DATA })
local ns, api = c.ns, c.G.Auctionator.API.v1
c.auction, c.auctionAge = { [1] = 500, [2] = 30, [3] = 90 }, 1

equal(ns.Price(1).copper, 500, "an auction price comes from Auctionator")
equal(ns.Price(1).source, "auctionator", "Auctionator is the auction source")
equal(ns.Price(1).days, 1, "Auctionator's age is kept")
equal(ns.Price(2).source, "auctionator", "a cheaper Auctionator price beats the bundled vendor price")
equal(ns.Price(99), nil, "an item nobody priced has no price")

c.auctionAge = nil
c.AuctionatorScan()
equal(ns.Price(1).days, nil, "Auctionator's update re-prices, and an undated age stays unknown")

equal(ns.PriceAgeText(ns.Price(1)), "over 3 weeks ago", "successful nil age keeps Auctionator's old-price sentinel")
equal(ns.PriceAge(ns.Price(1)), 22 * 86400, "old-price sentinel is stale")
local ageAPI = api.GetAuctionAgeByItemID
api.GetAuctionAgeByItemID = nil
c.AuctionatorScan()
equal(ns.Price(1).copper, 500, "missing age capability keeps the known price")
equal(ns.PriceAge(ns.Price(1)), nil, "missing age capability leaves age unknown")
equal(ns.PriceAgeText(ns.Price(1)), "unknown age", "missing age capability does not claim a date")
api.GetAuctionAgeByItemID = function()
	error("age API failed")
end
c.AuctionatorScan()
equal(ns.PriceAgeText(ns.Price(1)), "unknown age", "failed age call does not claim an old date")
api.GetAuctionAgeByItemID = ageAPI
c.AuctionatorScan()

-- A vendor visit records the unit price, reputation discount included, and it beats the auction.
c.merchant = { { itemID = 3, price = 100, stackCount = 5 }, { itemID = 4, price = 10, hasExtendedCost = true } }
c.Fire("MERCHANT_SHOW")
equal(ns.db.vendor[3], 20, "a merchant's price is recorded per unit")
equal(ns.db.vendor[4], nil, "a token price is not a money price")
equal(ns.Price(3).source, "vendor", "the vendor's price beats a dearer auction")
equal(ns.Price(3).copper, 20, "the vendor's unit price is used")

-- A merchant entry without a stack size says nothing about the unit price.
c.merchant = { { itemID = 3, price = 100, stackCount = 0 }, { itemID = 5, price = 100 } }
c.Fire("MERCHANT_UPDATE")
equal(ns.db.vendor[3], 20, "a zero stack size keeps the earlier unit price")
equal(ns.db.vendor[5], nil, "a missing stack size records nothing")

-- Without Auctionator, only vendor prices exist.
ns = Client.load({ data = DATA, auctionator = false }).ns
equal(ns.Price(1), nil, "without Auctionator an auction-only reagent has no price")
equal(ns.Price(2).source, "vendor", "without Auctionator the bundled vendor price is used")

Client.report("prices_spec")
