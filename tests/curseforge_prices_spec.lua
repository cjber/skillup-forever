-- Run from the repository root: luajit tests/curseforge_prices_spec.lua
local Client = dofile("tests/client.lua")
local equal = Client.equal
local c = Client.load()
local ns = c.ns
c.professions = { { name = "Skinning", id = 393, rank = 1, max = 75 } }
ns.SetCollectMode("gather")
equal(ns.db.valueGathered, true, "gathered materials are valued by default")
equal(ns.Price(2318).copper, 15, "uncached Light Leather has its bundled vendor sale value")
equal(ns.Price(2318).copper * 300, 4500, "300 Light Leather costs 45 silver of sale value")
equal(ns.Price(2318).worth, "vendor", "the source explains the vendor valuation")
c.items[2318] = { sell = 20 }
ns.Changed("prices")
equal(ns.Price(2318).copper, 20, "a live sell price replaces the bundled value")
c.auction[2318] = 100
c.AuctionatorScan()
equal(ns.Price(2318).copper, 95, "an auction observation counts after the house cut")
-- A synthetic gathered item with neither sale source stays unpriced.
local missing = Client.load({ data = { GatheredBy = { [900001] = 393 }, ItemSellPrices = {} } })
missing.professions = c.professions
missing.ns.SetCollectMode("gather")
equal(missing.ns.Price(900001).unknown, true, "absent sale data is explicitly unknown")
equal(missing.ns.ObtainCost(900001), nil, "absent sale data cannot become a free reagent")
missing.items[900001] = { sell = 15 }
missing.Fire("GET_ITEM_INFO_RECEIVED", 900001, true)
missing.Advance(0.5)
equal(missing.ns.Price(900001).copper, 15, "arrival of item data clears the unknown price")
Client.report("curseforge_prices_spec")
