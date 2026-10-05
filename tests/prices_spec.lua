-- Run from the repository root: luajit tests/prices_spec.lua
-- Where a price comes from, with the whole addon loaded: the median of the days Auctionator has seen an
-- item at, its last buyout, the bundled vendor list and merchants seen.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local DAY = 86400
local DATA = { VendorPrices = { [2] = 40 }, GatheredBy = {} }
local c = Client.load({ data = DATA })
local ns, api = c.ns, c.G.Auctionator.API.v1
c.auction, c.auctionAge = { [1] = 500, [2] = 30, [3] = 90, [50] = 500 }, 1

equal(ns.Price(1).copper, 500, "an auction price comes from Auctionator")
equal(ns.Price(1).source, "auctionator", "Auctionator is the auction source")
equal(ns.Price(1).basis, 1, "a last buyout is a one-day basis")
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

-- A scan files today's lowest buyout of each item the addon has priced.
c.auctionAge = 0
c.AuctionatorScan()
equal(ns.Price(1).copper, 500, "one day's price is that day's price")
equal(ns.Price(1).basis, 1, "and its basis is one day")
equal(ns.Price(1).days, 0, "the newest day is today")
equal(
	ns.PriceSourceText({ copper = 100, source = "auctionator", basis = 5 }),
	"Auctionator, the middle of 5 days",
	"a median price names the days behind it"
)
equal(
	ns.PriceSourceText({ copper = 100, source = "auctionator", basis = 1, days = 0 }),
	"Auctionator, today",
	"a one-day price names its age"
)

-- A later day moves the price to the middle of the days held, and the vendor is still the cheaper of
-- vendor and auction.
c.now = c.now + DAY
c.auction[1], c.auction[2] = 300, 200
c.AuctionatorScan()
equal(ns.Price(1).copper, 400, "two days price from their middle")
equal(ns.Price(1).basis, 2, "and the basis counts both")
equal(ns.Price(2).source, "vendor", "the cheaper vendor price beats the filed auction price")
equal(ns.Price(2).copper, 40, "at the vendor's unit price")

c.now = c.now + DAY
c.auction[1] = 100
c.AuctionatorScan()
equal(ns.Price(1).copper, 300, "three days price from their middle")
equal(ns.Price(1).basis, 3, "and the basis counts all three")

-- A price the scan left alone is not filed as today's: only what the age says it saw.
c.now = c.now + DAY
c.auction[1], c.auction[3] = 700, 70
c.auctionAge = { [1] = 0, [2] = 0, [3] = 5 }
c.AuctionatorScan()
equal(ns.Price(1).basis, 4, "a price seen today is filed")
equal(ns.Price(1).copper, 400, "and joins the middle")
equal(ns.Price(3).basis, 3, "a price the scan did not see is not filed again")
equal(ns.Price(3).days, 1, "so its newest day stays the one it was seen on")

-- A second scan the same day keeps the lowest buyout of the two, never a higher one.
c.auctionAge = 0
c.auction[1] = 900
c.AuctionatorScan()
equal(ns.Price(1).basis, 4, "a second scan the same day adds no day")
equal(ns.Price(1).copper, 400, "and a higher later price does not raise the day's low")
c.auction[1] = 50
c.AuctionatorScan()
equal(ns.Price(1).copper, 200, "a lower later price lowers the day's low")

-- Eight more days of scans: the store keeps the newest seven and drops the rest.
for _ = 1, 8 do
	c.now = c.now + DAY
	c.auction[1] = 1000
	c.AuctionatorScan()
end
equal(ns.Price(1).basis, 7, "the store keeps at most seven days")
equal(ns.Price(1).copper, 1000, "and prices from the days it kept")

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

-- The saved store is per realm and pruned to seven days at login.
local saved = { priceDays = { Realm = {} } }
for day = 1, 9 do
	saved.priceDays.Realm[day] = { [1] = day * 10 }
end
local reloaded = Client.load({ data = DATA, saved = saved })
equal(reloaded.ns.Price(1).basis, 7, "login prunes the store to seven days")
equal(reloaded.ns.Price(1).copper, 60, "the days kept are the newest seven")

-- Without Auctionator, only vendor prices exist.
ns = Client.load({ data = DATA, auctionator = false }).ns
equal(ns.Price(1), nil, "without Auctionator an auction-only reagent has no price")
equal(ns.Price(2).source, "vendor", "without Auctionator the bundled vendor price is used")

Client.report("prices_spec")
