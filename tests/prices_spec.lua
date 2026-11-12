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

-- Auctionator loads its database at PLAYER_LOGIN and answers nil before then, so a price asked for while the game
-- loads is cached empty. A /reload brings no item data to clear it: entering the world asks again, once.
do
	local login = Client.load({ data = DATA })
	equal(login.ns.Price(1), nil, "a price asked for before Auctionator loads is empty")
	login.auction[1] = 500
	login.Fire("PLAYER_LOGIN")
	login.Fire("PLAYER_ENTERING_WORLD")
	local price = login.ns.Price(1)
	equal(price and price.copper, 500, "entering the world asks Auctionator again")
	login.auction[1] = 900
	login.Fire("PLAYER_ENTERING_WORLD")
	equal(login.ns.Price(1).copper, 500, "later zoning keeps the cache")
end

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

-- A creature's drop is gathered by anyone: no profession needed, and the price says it is loot.
local LOOTED, FISH = 10, 20
local loot = Client.load({
	data = { GatheredBy = {}, LootedFrom = { [LOOTED] = true }, VendorPrices = {}, RecipeData = {} },
})
local lootNs = loot.ns
lootNs.SetCollectMode("gather")
equal(lootNs.CanGather(LOOTED), "loot", "a reagent creatures drop needs no profession")
local looted = lootNs.Price(LOOTED)
equal(looted.source, "gather", "a looted reagent is priced as gathered")
equal(looted.profession, nil, "with no profession")
equal(looted.loot, true, "and marked as loot")
equal(lootNs.PriceSourceText(looted), "you loot it from creatures", "which the tooltip says")
loot.items[LOOTED] = { sell = 25 }
lootNs.db.valueGathered = true
lootNs.Changed("prices")
equal(
	lootNs.PriceSourceText(lootNs.Price(LOOTED)),
	"you loot it from creatures, valued at its vendor sell price",
	"and values it when Value gathered materials is on"
)

-- Self-supplied pricing: off, a looted reagent is free as before; on, the same reagent takes a market price,
-- and one no market prices stays unpriced rather than free.
local MARKETED, UNMARKETED = 30, 40
local self = Client.load({
	data = {
		GatheredBy = {},
		LootedFrom = { [MARKETED] = true, [UNMARKETED] = true },
		VendorPrices = {},
		RecipeData = {},
	},
})
local selfNs = self.ns
selfNs.SetCollectMode("gather")
self.auction = { [MARKETED] = 200 }
equal(selfNs.db.auctionOnly, false, "self-supplied reagents count as gathered by default")
equal(selfNs.Price(MARKETED).copper, 0, "off, a looted reagent is free")
equal(selfNs.Price(MARKETED).source, "gather", "and still gathered")
self.SetSetting("auctionOnly", true)
equal(selfNs.Price(MARKETED).copper, 190, "on, the same looted reagent is worth its auction price after the cut")
equal(selfNs.Price(MARKETED).source, "auctionator", "so the shopping list puts it with the auction house")
equal(selfNs.Model.ShoppingSource(selfNs.PriceSource(MARKETED)), "auction", "in the auction bucket")
equal(
	selfNs.PriceSourceText(selfNs.Price(MARKETED)),
	"you loot it from creatures, valued at its AH price",
	"while still saying where it comes from"
)
equal(selfNs.Price(UNMARKETED), nil, "on, a gathered reagent no market prices stays unpriced")
self.items[MARKETED] = { sell = 250 }
selfNs.Changed("prices")
equal(selfNs.Price(MARKETED).copper, 250, "on, the vendor sell price is the floor")
equal(selfNs.Price(MARKETED).source, "vendor", "so the shopping list puts it with vendors")
self.SetSetting("auctionOnly", false)
equal(selfNs.Price(MARKETED).copper, 0, "off again, it is free as before")

-- A fish is only gathered when the character knows Fishing.
local fish = Client.load({
	data = { GatheredBy = { [FISH] = 356 }, VendorPrices = {}, RecipeData = {} },
})
fish.ns.SetCollectMode("gather")
equal(fish.ns.CanGather(FISH), nil, "a fish needs Fishing")
equal(fish.ns.Price(FISH), nil, "so a character without it has no gathered price")
fish.professions = { { name = "Fishing", icon = 1, rank = 1, max = 75, id = 356 } }
fish.ns.Changed("prices")
equal(fish.ns.CanGather(FISH), "Fishing", "with Fishing it is gathered")
equal(fish.ns.Price(FISH).profession, "Fishing", "and priced under that profession")

-- #598: a bolt crafted from gathered cloth is not free. With Buy reagents off the cloth costs nothing, but
-- the bolt can be sold, so using it in a recipe gives that sale up and the recipe must pay for it. An auction
-- price for the bolt wins over the vendor's when there is one.
local SILK, BOLT, ROBE = 4306, 4305, 4324
local bolt = Client.load({
	data = {
		GatheredBy = {},
		LootedFrom = { [SILK] = true },
		VendorPrices = {},
		ItemSellPrices = {},
		RecipeData = {
			[3839] = {
				skillLine = 197,
				reagents = { { itemID = SILK, quantity = 4 } },
				output = { itemID = BOLT, quantity = 1 },
			},
			[3858] = {
				skillLine = 197,
				reagents = { { itemID = BOLT, quantity = 1 } },
				output = { itemID = ROBE, quantity = 1 },
			},
		},
	},
})
local boltNs = bolt.ns
boltNs.SetCollectMode("gather")
bolt.professions = { { name = "Tailoring", rank = 1, max = 300, id = 197 } }
bolt.known[3839], bolt.known[3858] = true, true
bolt.items[SILK] = { name = "Silk Cloth" }
bolt.items[BOLT] = { name = "Bolt of Silk Cloth", sell = 600 }
bolt.items[ROBE] = { name = "Silk Robe", sell = 2000 }
equal(boltNs.Price(SILK).copper, 0, "gathered silk is free with Buy reagents off")
equal(boltNs.ObtainCost(BOLT), 600, "a crafted bolt is worth what it sells for, not its free cloth")
local boltCost = boltNs.CraftCost(3858)
equal(boltCost, 600, "a recipe using the bolt pays for it")
equal(boltNs.NetCost(3858), -1400, "so the recipe's profit is its result less a sellable bolt")
bolt.auction[BOLT] = 1000
boltNs.Changed("prices")
equal(boltNs.ObtainCost(BOLT), 950, "an auction price for the bolt wins, net of the auction house's cut")

Client.report("prices_spec")
