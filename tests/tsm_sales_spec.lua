-- Run from the repository root: luajit tests/tsm_sales_spec.lua
-- Optional TradeSkillMaster regional sale average as crafted-item value, while reagent buying stays on listing prices.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local DATA = {
	VendorPrices = {},
	GatheredBy = {},
	RecipeData = {
		[10] = { skillLine = 164, reagents = { { itemID = 1, quantity = 2 } }, output = { itemID = 7, quantity = 1 } },
		[11] = { skillLine = 164, reagents = { { itemID = 1, quantity = 2 } }, output = { itemID = 7, quantity = 3 } },
	},
}

-- A client with TSM installed: listing sources answer from `listings`, DBRegionSaleAvg from `sale`.
-- Every query is recorded, so a spec can prove what was and was not asked.
local function load(mode, listings, sale)
	local c = Client.load({ data = DATA, auctionator = false, tsm = {} })
	c.listings = listings or {}
	c.listingsAsked, c.saleAsked = {}, {}
	c.G.TSM_API.GetCustomPriceValue = function(source, itemString)
		local itemID = tonumber(itemString:match("^i:(%d+)$"))
		if source == "DBRegionSaleAvg" then
			c.saleAsked[#c.saleAsked + 1] = itemID
			return sale(itemID)
		end
		c.listingsAsked[#c.listingsAsked + 1] = itemID
		local copper = c.listings[itemID]
		if copper then
			return copper
		end
		return nil, "no value"
	end
	c.ns.db.craftValue = mode
	return c
end

local function contains(list, value)
	for _, entry in ipairs(list) do
		if entry == value then
			return true
		end
	end
	return false
end

-- The sale mode values the crafted output at TSM's regional sale average as TSM reports it, times the output
-- quantity, and never asks that source for a reagent that is being bought.
do
	local c = load("sale", { [1] = 500, [7] = 900 }, function(itemID)
		return itemID == 7 and 2000 or nil
	end)
	equal(c.ns.Price(1).copper, 500, "a reagent is still bought at its listing price")
	equal(c.ns.Price(1).source, "tsm", "and says the listing source")
	local cost, value, net = c.ns.CraftCost(10)
	equal(c.saleAsked[1], 7, "the sale query is for the crafted output")
	equal(#c.saleAsked, 1, "the sale query is only for the output")
	equal(contains(c.listingsAsked, 7), false, "the output listing price is not asked for sale value")
	equal(cost, 1000, "reagent cost still uses the listing price")
	equal(value.copper, 2000, "sale value is the regional average exactly as reported, with no further cut")
	equal(value.source, "sale", "and is marked as a regional sale, not a listing")
	equal(value.quantity, 1, "with one craft's output quantity")
	equal(net, -1000, "net cost subtracts the regional sale value")
	equal(c.ns.NetCost(10), -1000, "the net cost alone agrees")
	local _, three = c.ns.CraftCost(11)
	equal(three.copper, 6000, "a three-item craft counts all three in its sale value")
end

-- An absent, zero, erroring or invalid sale value never becomes a listing estimate: the vendor price is the
-- only fallback, and without that the value stays unknown.
do
	local cases = {
		{
			name = "absent",
			answer = function()
				return nil
			end,
		},
		{
			name = "zero",
			answer = function()
				return 0
			end,
		},
		{
			name = "erroring",
			answer = function()
				error("boom")
			end,
		},
		{
			name = "not a number",
			answer = function()
				return "2000"
			end,
		},
		{
			name = "negative",
			answer = function()
				return -2000
			end,
		},
		{
			name = "NaN",
			answer = function()
				return 0 / 0
			end,
		},
		{
			name = "infinite",
			answer = function()
				return math.huge
			end,
		},
	}
	for _, case in ipairs(cases) do
		local c = load("sale", { [1] = 500, [7] = 900 }, case.answer)
		c.items[7] = { sell = 400 }
		local cost, value, net = c.ns.CraftCost(10)
		equal(cost, 1000, case.name .. ": reagent cost is unchanged")
		equal(value and value.copper, 400, case.name .. ": the vendor sell price is the fallback")
		equal(value and value.source, "vendor", case.name .. ": and the source says vendor, never a listing")
		equal(net, 600, case.name .. ": net cost uses the vendor fallback")
	end
end

-- With no sale value and no vendor price, the value and net stay explicitly unknown; the reagent cost is known.
do
	local c = load("sale", { [1] = 500, [7] = 900 }, function()
		return nil
	end)
	local cost, value, net = c.ns.CraftCost(10)
	equal(cost, 1000, "the reagent cost is known")
	equal(value, nil, "no sale and no vendor value is unknown, not a listing")
	equal(net, nil, "so net cost is unknown, never the full reagent cost")
end

-- A zero vendor sell price is known to be worthless: net is the full reagent cost, not unknown. Only when both
-- the sale and the vendor price are missing does the net stay unknown.
do
	local c = load("sale", { [1] = 500 }, function()
		return nil
	end)
	c.items[7] = { sell = 0 }
	local cost, value, net = c.ns.CraftCost(10)
	equal(cost, 1000, "the reagent cost is known")
	equal(value, nil, "a zero vendor price has no value")
	equal(net, 1000, "but it is a known full cost, not an unknown net")
end

-- A known sale value is enough even while the client has not loaded the output's vendor sell price.
do
	local c = load("sale", { [1] = 500 }, function(itemID)
		return itemID == 7 and 1000 or nil
	end)
	local _, value, net = c.ns.CraftCost(10)
	equal(value.copper, 1000, "the sale value is known without a vendor sell price")
	equal(net, 0, "and the net is known too")
end

-- The vendor's guaranteed price still wins when it is higher than the regional sale average.
do
	local c = load("sale", { [1] = 500 }, function(itemID)
		return itemID == 7 and 100 or nil
	end)
	c.items[7] = { sell = 500 }
	local _, value = c.ns.CraftCost(10)
	equal(value.copper, 500, "a higher vendor sell price wins")
	equal(value.source, "vendor", "and is the source")
end

-- Every other mode keeps its old one-source behaviour and never asks TSM for a regional sale.
do
	local auction = load("auction", { [1] = 500, [7] = 900 }, function()
		error("sale must not be asked")
	end)
	local cost, value = auction.ns.CraftCost(10)
	equal(cost, 1000, "auction mode keeps the listing reagent cost")
	equal(value.copper, 855, "auction mode still values the output at its listing price after the cut")
	equal(value.source, "auction", "with the auction source")
	equal(#auction.saleAsked, 0, "auction mode never asks for a sale")

	local vendor = load("vendor", { [1] = 500, [7] = 900 }, function()
		error("sale must not be asked")
	end)
	vendor.items[7] = { sell = 400 }
	value = select(2, vendor.ns.CraftCost(10))
	equal(value.copper, 400, "vendor mode values only the vendor sell price")
	equal(value.source, "vendor", "with the vendor source")
	equal(#vendor.saleAsked, 0, "vendor mode never asks for a sale")

	local none = load("none", { [1] = 500, [7] = 900 }, function()
		error("sale must not be asked")
	end)
	local noneCost, noneValue, noneNet = none.ns.CraftCost(10)
	equal(noneValue, nil, "none mode counts no value")
	equal(noneCost, 1000, "none mode keeps the reagent cost")
	equal(noneNet, 1000, "none mode nets to the reagent cost")
	equal(#none.saleAsked, 0, "none mode never asks for a sale")
end

-- Without TSM, the sale mode has no regional sale and falls back to the vendor, without an error.
do
	local c = Client.load({ data = DATA, auctionator = false })
	c.ns.db.craftValue = "sale"
	c.ns.db.vendor[1] = 100
	c.items[7] = { sell = 400 }
	local cost, value, net = c.ns.CraftCost(10)
	equal(c.ns.HasTradeSkillMaster(), false, "TSM is not installed")
	equal(cost, 200, "a known vendor price still prices the reagent")
	equal(value and value.copper, 400, "the sale mode still values the output at the vendor price")
	equal(value and value.source, "vendor", "and says vendor")
	equal(net, -200, "the known values net normally")
end

Client.report("tsm_sales_spec")
