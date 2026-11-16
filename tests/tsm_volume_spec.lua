local Client = dofile("tests/client.lua")
local equal = Client.equal

local c = Client.load({
	data = {
		VendorPrices = { [1] = 500 },
		GatheredBy = {},
		RecipeData = {
			[10] = {
				skillLine = 164,
				reagents = { { itemID = 1, quantity = 1 } },
				output = { itemID = 7, quantity = 1 },
			},
		},
	},
	auctionator = false,
	tsm = {},
})
c.ns.db.craftValue = "sale"
c.G.TSM_API.GetCustomPriceValue = function(source, itemString)
	local itemID = tonumber(itemString:match("^i:(%d+)$"))
	if source == "DBRegionSaleAvg" and itemID == 7 then
		return 2000
	end
	if source == "first(DBRecent, DBMinBuyout, DBMarket)" and itemID == 1 then
		return 500
	end
	if source == "DBRegionSoldPerDay" and itemID == 7 then
		return 12.5
	end
	if source == "DBRegionSoldPerDay" and itemID == 1 then
		return 0
	end
	return nil, "missing"
end
local _, value = c.ns.CraftCost(10)
equal(value.volume, 12.5, "TSM regional sold-per-day is preserved as reported")

c.ns.db.craftValue = "auction"
c.G.TSM_API.GetCustomPriceValue = function(source)
	if source == "DBRegionSoldPerDay" then
		return 12.5
	end
	return 2000
end
c.ns.Changed("prices")
local _, listing = c.ns.CraftCost(10)
equal(listing.source, "auction", "the listing remains the selected price")
equal(listing.volume, 12.5, "volume is available beside listing prices too")
c.items[7] = { sell = 5000 }
c.ns.Changed("prices")
local _, vendor = c.ns.CraftCost(10)
equal(vendor.source, "vendor", "a higher vendor payout still wins")
equal(vendor.volume, 12.5, "vendor selection does not erase regional volume")

-- Zero is a known regional result, while absence remains unknown.
local c2 = Client.load({
	data = {
		VendorPrices = {},
		GatheredBy = {},
		RecipeData = { [10] = { skillLine = 164, reagents = {}, output = { itemID = 7, quantity = 1 } } },
	},
	auctionator = false,
	tsm = {},
})
c2.ns.db.craftValue = "sale"
c2.G.TSM_API.GetCustomPriceValue = function(source)
	if source == "DBRegionSaleAvg" then
		return 100
	end
	if source == "DBRegionSoldPerDay" then
		return 0
	end
end
local _, zero = c2.ns.CraftCost(10)
equal(zero.volume, 0, "zero sold-per-day remains known")

for _, entry in ipairs({
	{ value = nil },
	{ value = "error" },
	{ value = 0 / 0 },
	{ value = math.huge },
	{ value = -math.huge },
	{ value = -1 },
	{ value = 12.5 },
}) do
	local case = entry.value
	local probe = Client.load({
		data = {
			VendorPrices = { [1] = 500 },
			GatheredBy = {},
			RecipeData = {
				[10] = {
					skillLine = 164,
					reagents = { { itemID = 1, quantity = 1 } },
					output = { itemID = 7, quantity = 1 },
				},
			},
		},
		auctionator = false,
		tsm = {},
	})
	probe.ns.db.craftValue = "sale"
	probe.G.TSM_API.GetCustomPriceValue = function(source)
		if source == "DBRegionSaleAvg" then
			return 2000
		end
		if source == "DBRegionSoldPerDay" then
			if case == "error" then
				error("provider failure")
			end
			return case
		end
		return 500
	end
	local _, result = probe.ns.CraftCost(10)
	equal(
		result.volume,
		type(case) == "number" and case >= 0 and case < math.huge and case == case and case or nil,
		"invalid volume stays unknown"
	)
end
print("tsm_volume_spec: passed")
