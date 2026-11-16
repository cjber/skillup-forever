local Client = dofile("tests/client.lua")
local equal = Client.equal
local c = Client.load()
local ns = c.ns
local changes = 0
ns.WhenStale("sourceEvidence", function()
	changes = changes + 1
end)
c.npc = { id = 5001, name = "Synthetic vendor" }
c.merchant = {
	{
		itemID = 3,
		price = 100,
		stackCount = 5,
		numAvailable = 4,
		hasExtendedCost = true,
		costs = { { 111, 2, "item:900001" } },
		isPurchasable = false,
		isUsable = true,
	},
	{
		itemID = 3,
		price = 100,
		stackCount = 5,
		numAvailable = -1,
		hasExtendedCost = true,
		costs = { { 111, 3, "item:900002" } },
		isPurchasable = true,
	},
}
c.Fire("MERCHANT_SHOW")
local function current()
	return ns.MerchantOffers.current.offers
end
local offers = current()
equal(#offers, 2, "same product retains distinct offers")
equal(offers[1].costs[1].id, 900001, "stable item link resolved")
equal(offers[1].requirementsComplete, true, "complete conjunction captured")
equal(offers[1].isPurchasable, false, "purchase permission independent of usability")
equal(offers[1].isUsable, true, "usability preserved")
equal(offers[1].canAfford, nil, "absent affordability is unknown")
equal(offers[1].maxPurchaseItems, 20, "native ceiling captured independently")
equal(offers[1].stockUnit, nil, "positive stock units unknown")
equal(offers[2].certifiedUnlimited, nil, "minus one cannot certify future supply")
local quote = assert(ns.RouteDemand.QuoteOrders({ { offer = offers[1], bundles = 2 } }))
equal(quote.moneyCopper, 200, "quote scales original money per bundle")
equal(quote.products[3], 10, "quote counts item units")
equal(quote.costs["item:900001"], 4, "quote scales token requirement")
equal(
	ns.MerchantOffers.BundleBound(offers[1], 1000, { ["item:900001"] = 5 }),
	2,
	"conditional bound counts full bundles without stock conversion"
)
equal(ns.MerchantOffers.BundleBound(offers[1], 1000, {}), nil, "unknown token balance prevents bound")
local before = changes
c.merchant[1].costs[1][3] = "item:900003"
c.Fire("MERCHANT_UPDATE")
equal(changes, before + 1, "token-only identity change invalidates")
equal(current()[1].costs[1].id, 900003, "new token identity captured")
equal(
	ns.RouteDemand.QuoteOrders({ { offer = offers[1], bundles = 2 } }),
	nil,
	"replaced observation cannot quote a transient merchant index"
)
c.Fire("MERCHANT_UPDATE")
equal(changes, before + 1, "identical observation does not invalidate")
c.merchant[1], c.merchant[2] = c.merchant[2], c.merchant[1]
c.Fire("MERCHANT_UPDATE")
equal(current()[1].costs[1].id, 900002, "reordered slot has current requirement")
equal(current()[2].costs[1].id, 900003, "other offer survives reorder")
-- MERCHANT_UPDATE also arrives for what this addon does not read. A window that still shows the last scan's
-- offers is answered from them: no offer table is built and nothing is notified.
local rescans = 0
local read = ns.MerchantOffers.Read
ns.MerchantOffers.Read = function(...)
	rescans = rescans + 1
	return read(...)
end
local scanned = current()
local notified = changes
local changedKinds = {}
local realChanged = ns.Changed
ns.Changed = function(kind)
	changedKinds[#changedKinds + 1] = kind
	return realChanged(kind)
end
c.Fire("MERCHANT_UPDATE")
ns.Changed = realChanged
equal(rescans, 0, "an unchanged window is not rescanned")
equal(current(), scanned, "an unchanged window keeps its offers")
equal(changes, notified, "an unchanged window notifies no source evidence")
equal(#changedKinds, 0, "an unchanged window notifies nothing else either")
c.merchant[2].numAvailable = 2
c.Fire("MERCHANT_UPDATE")
equal(rescans, 2, "a changed window is rescanned in full")
equal(current()[2].numAvailable, 2, "the changed offer is recorded")
ns.MerchantOffers.Read = read
c.merchant[1].costs = {
	{ 1, 1, "item:900001" },
	{ 2, 2, "item:900002" },
	{ 3, 3, "item:900003" },
	{ 4, 4, "currency:900004", "Synthetic currency" },
}
c.Fire("MERCHANT_UPDATE")
equal(#current()[1].costs, 4, "all reported slots captured beyond UI display limit")
equal(current()[1].costs[4].kind, "currency", "currency typed separately")
equal(current()[1].costs[4].id, 900004, "currency link resolver used")
c.merchant[1].costs[4][3] = nil
c.Fire("MERCHANT_UPDATE")
equal(current()[1].requirementsComplete, false, "name and texture never identity")
c.merchant[1].costCount = 5
c.Fire("MERCHANT_UPDATE")
equal(#current()[1].costs, 5, "missing reported slot retained")
equal(current()[1].requirementsComplete, false, "missing slot is incomplete")
c.G.GetMerchantItemCostItem = nil
c.Fire("MERCHANT_UPDATE")
equal(current()[1].capabilities.costSlot, "missing", "cost slot capability independent")
equal(current()[1].maxPurchaseItems, 20, "cost capability cannot erase native maximum")
equal(current()[1].requirementsComplete, false, "missing capability cannot imply free")
c.G.GetMerchantItemMaxStack = nil
c.Fire("MERCHANT_UPDATE")
equal(current()[1].maxPurchaseItems, nil, "missing maximum never inherited")
c.G.CanAffordMerchantItem = function()
	return false
end
c.Fire("MERCHANT_UPDATE")
equal(current()[1].canAfford, false, "false affordability preserved")
c.merchant[1].price = nil
c.Fire("MERCHANT_UPDATE")
equal(current()[1].price, nil, "current quote never inherited")
equal(current()[1].travelCopper, nil, "travel never defaults to zero")
-- Unknown structured data does not erase the separate historical observation.
local historical = ns.db.merchantEvidence[5001][3]
c.G.C_MerchantFrame.GetItemInfo = nil
c.Fire("MERCHANT_UPDATE")
equal(current()[1].requirementsComplete, false, "missing item info cannot fabricate a quote")
equal(current()[1].capabilities.itemInfo, "missing", "item info capability captured")
equal(ns.db.merchantEvidence[5001][3], historical, "missing current info preserves history")
c.G.C_MerchantFrame.GetItemInfo = function(index)
	return c.merchant[index]
end
c.G.GetMerchantItemCostItem = function(index, slot)
	local row = c.merchant[index].costs
	if row and row[slot] then
		return unpack(row[slot], 1, 4)
	end
end
c.merchant[1].price, c.merchant[1].costCount = 100, 2
c.merchant[1].costs = { { 1, 2, "item:900001" }, { 2, 3, "item:900001" } }
c.G.GetMerchantItemMaxStack = function()
	return 7
end
c.Fire("MERCHANT_UPDATE")
local duplicate = current()[1]
equal(
	ns.MerchantOffers.BundleBound(duplicate, 1000, { ["item:900001"] = 9 }),
	1,
	"duplicate costs share a balance and partial native ceiling floors to bundles"
)
equal(assert(ns.MerchantOffers.Quote(duplicate, 2)).costs["item:900001"], 10, "duplicate requirements sum per bundle")
c.merchant[1].price = 1e308
c.Fire("MERCHANT_UPDATE")
local enormous = current()[1]
equal(
	ns.RouteDemand.QuoteOrders({ { offer = enormous, bundles = 1 }, { offer = enormous, bundles = 1 } }),
	nil,
	"aggregate quote overflow stays unknown"
)
c.G.C_Item.GetItemInfoInstant = nil
c.Fire("MERCHANT_UPDATE")
equal(current()[1].requirementsComplete, false, "missing identity resolver cannot guess from link")
equal(current()[1].costs[1].capabilities.identity, "missing", "resolver capability explicit")
c.G.GetMerchantItemCostInfo = function()
	error("synthetic capability failure")
end
c.Fire("MERCHANT_UPDATE")
equal(current()[1].capabilities.costCount, "failed", "failed capability stays explicit")
equal(current()[1].requirementsComplete, false, "failed count cannot imply free")
equal(current()[1].maxPurchaseItems, 7, "failed cost API cannot hide independent maximum")
equal(#c.purchased, 0, "reader never buys")
c.Fire("MERCHANT_CLOSED")
equal(ns.MerchantOffers.current, nil, "closed merchant revokes active offers")
print("merchant offers specs passed")
