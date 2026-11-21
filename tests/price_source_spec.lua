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
	"Visit a vendor to price reagents. Auction prices need Auctionator, TradeSkillMaster, AHDB, Naowh Forever "
		.. "or Forever Ledger.",
	"with neither installed the hint names both"
)

-- AHDB and nightly snapshots are usable before any auction house visit.
for _, source in ipairs({ "ahdb", "naowh" }) do
	local c = Client.load({ data = DATA, auctionator = false, ahdb = {}, naowh = {}, saved = { priceSource = source } })
	local ns = c.ns
	equal(ns.db.priceSource, source, "the saved source is accepted")
	local hint = source == "ahdb" and "Scan the auction house with AHDB, or visit a vendor, to price reagents."
		or "Update Naowh Forever's auction data, or visit a vendor, to price reagents."
	equal(ns.UnpricedHint(), hint, "with both installed the hint names the chosen source")
	equal(
		ns.RouteBlocked({ crafts = {}, ranks = {}, profession = {}, unpriced = 1 }),
		hint,
		"a route blocked on prices names the chosen source, not a missing addon"
	)
	equal(ns.Price(1), nil, "an empty feed is unknown")
	c.ahdb[1], c.naowh[1] = { 1700000000 - 2 * 86400, 120, 150, 3 }, { 180, 1700000000 - 3 * 86400 }
	c.Fire("PLAYER_ENTERING_WORLD")
	equal(ns.Price(1).copper, source == "ahdb" and 120 or 180, "entering the world refreshes the chosen feed")
	equal(ns.Price(1).days, source == "ahdb" and 2 or 3, "snapshot time becomes whole days")
	equal(
		ns.PriceSourceText(ns.Price(1)),
		source == "ahdb" and "AHDB, 2d ago" or "Naowh Forever, 3d ago",
		"source and age are visible"
	)
	equal(ns.PriceAge(ns.Price(1)), ns.Price(1).days * 86400, "all observed ages share one rule")
	c.ahdb[1], c.naowh[1] = nil, nil
	c.ahdb[4], c.naowh[5] = { 1700000000, 80 }, { 90 }
	c.ahdbListeners.SCAN_DATA()
	equal(ns.Price(1), nil, "a scan invalidates a missing observation")
	equal(ns.Price(4).source, "ahdb", "AHDB fills a gap in either choice")
	equal(ns.Price(5).source, "naowh", "Naowh fills a gap in either choice")
	equal(ns.PriceAgeText(ns.Price(5)), "unknown age", "missing snapshot time does not claim Auctionator's sentinel")
	c.ahdb[4] = { 1700000000, 85 }
	c.ahdbListeners.HISTORY_MERGED()
	equal(ns.Price(4).copper, 85, "merged history invalidates cached prices")
	c.G.AuctionDB.LastPrice = function()
		error("broken provider")
	end
	c.G.NaowhForever.AuctionPrice = function()
		return "bad", "bad"
	end
	ns.Changed("prices")
	equal(ns.Price(4), nil, "broken and malformed providers leave prices unknown")
end
-- Forever Ledger's own scans: the typical price with its scan's age, nothing for an item the scan found none of.
local ledger = Client.load({
	data = DATA,
	auctionator = false,
	naowh = {},
	foreverLedger = { [1] = { 250, 200, 4, 1700000000 - 86400 }, [3] = { nil, nil, 0, 1700000000 } },
	saved = { priceSource = "foreverledger" },
})
equal(ledger.ns.db.priceSource, "foreverledger", "the saved Forever Ledger source is accepted")
equal(ledger.ns.Price(1).copper, 250, "the chosen Forever Ledger price is its typical price")
equal(ledger.ns.Price(1).source, "foreverledger", "and names Forever Ledger")
equal(ledger.ns.Price(1).days, 1, "scan time becomes whole days")
equal(ledger.ns.PriceSourceText(ledger.ns.Price(1)), "Forever Ledger, 1d ago", "source and age are visible")
equal(ledger.ns.Price(3), nil, "an item scanned with none listed has no price")
local ledgerHint = "Run a full scan in Forever Ledger, or visit a vendor, to price reagents."
equal(ledger.ns.UnpricedHint(), ledgerHint, "the hint follows a chosen Forever Ledger")
equal(
	ledger.ns.RouteBlocked({ crafts = {}, ranks = {}, profession = {}, unpriced = 1 }),
	ledgerHint,
	"a route blocked on prices names Forever Ledger"
)
ledger.naowh[4] = { 90, 1700000000 }
ledger.ns.Changed("prices")
equal(ledger.ns.Price(4).source, "naowh", "another installed source fills a gap in Forever Ledger")
ledger.SetSetting("priceSource", "naowh")
equal(ledger.ns.Price(1).source, "foreverledger", "Forever Ledger fills a gap in the chosen source")
ledger.G.ForeverLedgerAPI.GetPrice = function()
	error("broken provider")
end
ledger.ns.Changed("prices")
equal(ledger.ns.Price(1), nil, "a Forever Ledger that errors leaves the price unknown")
local noLedger = Client.load({ data = DATA, saved = { priceSource = "foreverledger" } })
noLedger.auction = { [1] = 400 }
noLedger.ns.Changed("prices")
equal(noLedger.ns.HasForeverLedger(), false, "Forever Ledger is absent when not installed")
equal(noLedger.ns.AuctionProvider(), "auctionator", "an absent chosen Forever Ledger gives way")
equal(noLedger.ns.Price(1).source, "auctionator", "to the installed source's price")

-- A provider with no update callback can change its quote during an auction house visit.
for _, source in ipairs({ "foreverLedger", "tsm", "naowh" }) do
	local quotes = {}
	local function quote(copper)
		if source == "foreverLedger" then
			return { copper, copper, 4, 1700000000 }
		elseif source == "naowh" then
			return { copper, 1700000000 }
		end
		return copper
	end
	quotes[1] = quote(250)
	local c = Client.load({ data = DATA, auctionator = false, [source] = quotes })
	c.Fire("PLAYER_ENTERING_WORLD")
	equal(c.ns.Price(1).copper, 250, source .. " caches the initial quote")
	c[source][1] = quote(500)
	c.Fire("AUCTION_HOUSE_CLOSED")
	equal(c.ns.Price(1).copper, 500, source .. " refreshes its quote when the auction house closes")
end

-- Every chosen source wins; absent observations fall back in the same fixed order.
local chain = Client.load({
	data = DATA,
	tsm = { [1] = 200 },
	ahdb = { [1] = { 1700000000, 300 } },
	naowh = { [1] = { 400, 1700000000 } },
	foreverLedger = { [1] = { 500, 450, 3, 1700000000 } },
})
chain.auction[1] = 100
for index, source in ipairs({ "auctionator", "tsm", "ahdb", "naowh", "foreverledger" }) do
	chain.SetSetting("priceSource", source)
	equal(chain.ns.Price(1).copper, index * 100, "each chosen source takes precedence")
end
chain.foreverLedger[1] = nil
chain.ns.Changed("prices")
equal(chain.ns.Price(1).source, "auctionator", "the first fallback is Auctionator")
chain.auction[1] = nil
chain.ns.Changed("prices")
equal(chain.ns.Price(1).source, "tsm", "the next fallback is TSM")
chain.tsm[1] = nil
chain.ns.Changed("prices")
equal(chain.ns.Price(1).source, "ahdb", "the next fallback is AHDB")
chain.ahdb[1] = nil
chain.ns.Changed("prices")
equal(chain.ns.Price(1).source, "naowh", "the next fallback is Naowh Forever")
chain.SetSetting("priceSource", "auctionator")
chain.naowh[1], chain.foreverLedger[1] = nil, { 500, 450, 3, 1700000000 }
chain.ns.Changed("prices")
equal(chain.ns.Price(1).source, "foreverledger", "the last fallback is Forever Ledger")
for _, bad in ipairs({ -1, math.huge, 0 / 0, "bad", false }) do
	chain.ahdb[1] = { 1700000000, bad }
	chain.naowh[1] = { bad, 1700000000 }
	chain.foreverLedger[1] = { bad, bad, 1, 1700000000 }
	chain.ns.Changed("prices")
	equal(chain.ns.Price(1), nil, "invalid new-source amounts stay unknown")
end
chain.ahdb[1], chain.naowh[1] = { 1700000000, 0 }, { 0 }
chain.ns.Changed("prices")
equal(chain.ns.Price(1).copper, 0, "an explicit zero observation is a known value")
Client.report("price_source_spec")
