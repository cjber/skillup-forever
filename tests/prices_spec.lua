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
local old = { copper = 200, time = 1 }
local auctions = { [1] = { copper = 100, time = 1 }, [2] = old }
local ns = {
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

print("prices_spec: " .. checks .. " checks passed")
