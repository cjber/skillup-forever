-- Run from the repository root: luajit tests/price_source_spec.lua
-- Which installed auction addon prices a reagent, and what the other one fills in (#675).
local Client = dofile("tests/client.lua")
local equal = Client.equal

local DATA = {
	VendorPrices = { [2] = 40 },
	GatheredBy = {},
	RecipeData = {},
}

-- Both installed: the saved choice wins, and the other addon fills only the items it has no price for. The default
-- stays Auctionator first, as before the setting existed.
local both = Client.load({ data = DATA, tsm = { [1] = 500, [2] = 30, [3] = 90 } })
both.auction = { [1] = 400, [2] = 20 }
both.auctionAge = 1
both.ns.Changed("prices")
equal(both.ns.db.priceSource, "auctionator", "Auctionator is the default price source")
equal(both.ns.Price(1).copper, 400, "the default uses Auctionator's observation")
equal(both.ns.Price(1).source, "auctionator", "and names it")
equal(both.ns.PriceSourceText(both.ns.Price(1)), "Auctionator, 1d ago", "with its age")
both.SetSetting("priceSource", "tsm")
equal(both.ns.Price(1).copper, 500, "the chosen TradeSkillMaster price wins")
equal(both.ns.Price(1).source, "tsm", "and names TradeSkillMaster")
equal(both.ns.PriceSourceText(both.ns.Price(1)), "TradeSkillMaster", "with no age to claim")
both.auction[4] = 100
both.AuctionatorScan()
equal(both.ns.Price(4).copper, 100, "Auctionator fills an item TradeSkillMaster has no price for")
equal(both.ns.Price(4).source, "auctionator", "the fallback names itself")

-- The choice is not a filter: a chosen addon that is missing gives way to the installed one.
local noTsm = Client.load({ data = DATA })
noTsm.auction = { [1] = 400 }
noTsm.SetSetting("priceSource", "tsm")
equal(noTsm.ns.Price(1).source, "auctionator", "an absent chosen source falls back to Auctionator")
local noAuctionator = Client.load({ data = DATA, auctionator = false, tsm = { [1] = 500 } })
equal(noAuctionator.ns.Price(1).source, "tsm", "an absent default source falls back to TradeSkillMaster")

-- The no-price advice names the chosen source, or the one that is actually installed.
equal(
	both.ns.UnpricedHint(),
	"Update TradeSkillMaster's AuctionDB with the TSM desktop app, or visit a vendor, to price reagents.",
	"the hint follows a chosen TradeSkillMaster"
)
both.SetSetting("priceSource", "auctionator")
equal(
	both.ns.UnpricedHint(),
	"Scan the auction house with Auctionator, or visit a vendor, to price reagents.",
	"and a chosen Auctionator"
)
noAuctionator.SetSetting("priceSource", "auctionator")
equal(
	noAuctionator.ns.UnpricedHint(),
	"Update TradeSkillMaster's AuctionDB with the TSM desktop app, or visit a vendor, to price reagents.",
	"an absent chosen source points at the installed fallback"
)
local neither = Client.load({ data = DATA, auctionator = false })
equal(
	neither.ns.UnpricedHint(),
	"Visit a vendor to price reagents. Auction prices need Auctionator or TradeSkillMaster.",
	"with neither installed the hint names both"
)

Client.report("price_source_spec")
