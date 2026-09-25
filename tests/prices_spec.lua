-- Run from the repository root: luajit tests/prices_spec.lua
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local onEvent, dbUpdate
local auctionatorDays = 1
local merchant = {}
local ns = {
	VendorPrices = { [2] = 40 },
	db = { vendor = {} },
	InvalidatePlans = function() end,
	RefreshRecipeList = function() end,
	RefreshRoute = function() end,
	RefreshTracker = function() end,
}
local frame = {
	SetScript = function(_, _, callback)
		onEvent = callback
	end,
	RegisterEvent = function() end,
}
local api = {
	GetAuctionPriceByItemID = function(_, itemID)
		return ({ [1] = 500, [2] = 30, [3] = 90 })[itemID]
	end,
	GetAuctionAgeByItemID = function()
		return auctionatorDays
	end,
	RegisterForDBUpdate = function(_, callback)
		dbUpdate = callback
	end,
}
local env = setmetatable({
	CreateFrame = function()
		return frame
	end,
	Auctionator = { API = { v1 = api } },
	GetMerchantNumItems = function()
		return #merchant
	end,
	GetMerchantItemID = function(index)
		return merchant[index].itemID
	end,
	C_MerchantFrame = {
		GetItemInfo = function(index)
			return merchant[index]
		end,
	},
}, { __index = _G })
setfenv(assert(loadfile("Prices.lua")), env)("SkillUpForever", ns)
ns.InitPrices()

equal(ns.Price(1).copper, 500, "an auction price comes from Auctionator")
equal(ns.Price(1).source, "auctionator", "Auctionator is the auction source")
equal(ns.Price(1).days, 1, "Auctionator's age is kept")
equal(ns.Price(2).source, "auctionator", "a cheaper Auctionator price beats the bundled vendor price")
equal(ns.Price(99), nil, "an item nobody priced has no price")

auctionatorDays = nil
dbUpdate()
equal(ns.Price(1).days, nil, "Auctionator's update re-prices, and an undated age stays unknown")

-- A vendor visit records the unit price, reputation discount included, and it beats the auction.
merchant = { { itemID = 3, price = 100, stackCount = 5 }, { itemID = 4, price = 10, hasExtendedCost = true } }
onEvent(frame, "MERCHANT_SHOW")
equal(ns.db.vendor[3], 20, "a merchant's price is recorded per unit")
equal(ns.db.vendor[4], nil, "a token price is not a money price")
equal(ns.Price(3).source, "vendor", "the vendor's price beats a dearer auction")
equal(ns.Price(3).copper, 20, "the vendor's unit price is used")

-- Without Auctionator, only vendor prices exist.
env.Auctionator = nil
ns.PricesChanged()
equal(ns.Price(1), nil, "without Auctionator an auction-only reagent has no price")
equal(ns.Price(2).source, "vendor", "without Auctionator the bundled vendor price is used")

print("prices_spec: " .. checks .. " checks passed")
