-- Run from the repository root: luajit tests/prices_spec.lua
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local onEvent
local results, timers, searches = {}, {}, {}
local full, requestedMore = true, 0
local now = 100
local auctionatorDays = 1
local old = { copper = 200, time = 1 }
local auctions = { [1] = { copper = 100, time = 1 }, [2] = old }
local ns = {
	VendorPrices = {},
	db = { tracked = { [1] = true, [2] = true }, auctions = { ["Realm-Faction"] = auctions } },
	InvalidatePlans = function() end,
	RefreshRecipeList = function() end,
	RefreshRoute = function() end,
	RefreshTracker = function() end,
	Print = function() end,
}
local frame = {
	SetScript = function(_, _, callback)
		onEvent = callback
	end,
	RegisterEvent = function() end,
}
local env = setmetatable({
	CreateFrame = function()
		return frame
	end,
	GetNormalizedRealmName = function()
		return "Realm"
	end,
	UnitFactionGroup = function()
		return "Faction"
	end,
	time = function()
		return now
	end,
	Auctionator = {
		API = {
			v1 = {
				GetAuctionPriceByItemID = function(_, itemID)
					return itemID == 1 and 500 or nil
				end,
				GetAuctionAgeByItemID = function()
					return auctionatorDays
				end,
			},
		},
	},
	hooksecurefunc = function(tbl, name, hook)
		local original = tbl[name]
		tbl[name] = function(...)
			original(...)
			hook(...)
		end
	end,
	C_Timer = {
		After = function(_, callback)
			timers[#timers + 1] = callback
		end,
	},
	C_AuctionHouse = {
		IsThrottledMessageSystemReady = function()
			return true
		end,
		MakeItemKey = function(itemID)
			return { itemID = itemID }
		end,
		SearchForItemKeys = function(keys)
			searches[#searches + 1] = keys
		end,
		SendBrowseQuery = function() end,
		SearchForFavorites = function() end,
		GetBrowseResults = function()
			return results
		end,
		HasFullBrowseResults = function()
			return full
		end,
		RequestMoreBrowseResults = function()
			requestedMore = requestedMore + 1
		end,
	},
}, { __index = _G })
setfenv(assert(loadfile("Prices.lua")), env)("SkillUpForever", ns)
ns.InitPrices()
ns.ScanAuctions(true)
equal(#searches, 1, "scan sends a search")
equal(#searches[1], 2, "search covers both tracked items")

-- The player's search can supersede ours and return nothing: those empty
-- results are not ours, even when they are complete.
env.C_AuctionHouse.SendBrowseQuery({})
for _, event in ipairs({ "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" }) do
	onEvent(frame, event)
	equal(auctions[1].copper, 100, "empty results preserve first scanned price")
	equal(auctions[1].time, 1, "empty results preserve scan age")
	equal(auctions[2], old, "empty results preserve other pending entries")
end
timers[1]()
equal(auctions[2], old, "timeout preserves unmatched prices")
ns.ScanAuctions(true)
equal(#searches, 2, "timeout allows another scan")

results = { { itemKey = { itemID = 99 }, minPrice = 50, totalQuantity = 1 } }
onEvent(frame, "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
equal(auctions[2], old, "unrelated nonempty results preserve pending entries")

results = { { itemKey = { itemID = 1 }, minPrice = 110, totalQuantity = 1 } }
full = false
onEvent(frame, "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
equal(requestedMore, 1, "matching partial results request the rest")
equal(auctions[1].copper, 110, "matching results update scanned prices")
equal(auctions[2], old, "partial results preserve missing items")
full = true
onEvent(frame, "AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
equal(auctions[1].time, now, "matching results stamp scan time")
equal(auctions[2].copper, nil, "proven complete search clears an unlisted item's old price")
equal(auctions[2].time, now, "proven complete search stamps the missing item")

-- With no other search since ours, empty results mean nobody listed the items.
results = {}
ns.ScanAuctions(true)
onEvent(frame, "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
equal(auctions[1].copper, nil, "our own empty search clears a listed-no-more price")
equal(auctions[1].time, now, "our own empty search stamps the scan")
equal(ns.Price(1), nil, "our empty search overrides an older Auctionator price")
auctionatorDays = nil
ns.PricesChanged()
equal(ns.Price(1), nil, "our empty search overrides an Auctionator price too old to date")
auctionatorDays = 0
ns.PricesChanged()
equal(ns.Price(1), nil, "an equally fresh Auctionator price does not override our empty search")
now = now + 1
ns.PricesChanged()
equal(ns.Price(1).copper, 500, "a fresher Auctionator price overrides our empty search")
equal(ns.Price(1).source, "auctionator", "a fresher Auctionator price retains its source")

-- Closing the auction house mid-scan keeps what the finished batches found.
for itemID = 3, 60 do
	ns.db.tracked[itemID] = true
	auctions[itemID] = { copper = 300, time = now }
	equal(ns.Price(itemID).copper, 300, "a scanned price is cached")
end
ns.ScanAuctions(true)
local firstBatch = searches[#searches]
onEvent(frame, "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
onEvent(frame, "AUCTION_HOUSE_CLOSED")
local unlisted = firstBatch[1].itemID == 1 and firstBatch[2].itemID or firstBatch[1].itemID
equal(ns.Price(unlisted), nil, "a finished batch's unlisted item drops its cached price")

print("prices_spec: " .. checks .. " checks passed")
