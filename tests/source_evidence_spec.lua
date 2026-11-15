local Client = dofile("tests/client.lua")
local equal = Client.equal
local c = Client.load()
local ns = c.ns
local invalidations = 0
ns.WhenStale("sourceEvidence", function()
	invalidations = invalidations + 1
end)
c.npc = { id = 5001, name = "Test vendor" }
c.merchant = { { itemID = 3, price = 100, stackCount = 5, numAvailable = 4 } }
c.Fire("MERCHANT_SHOW")
local offer = ns.db.merchantEvidence[5001][3]
equal(offer.unitCopper, 20, "unit quote belongs to the observed vendor")
equal(offer.stock, 4, "available count is an observation, not a maximum")
equal(offer.observedAt, c.G.GetServerTime(), "observation records its clock")
equal(invalidations, 1, "new source evidence follows the Changes invalidation owner")
equal(offer.price, 100, "original bundle money total survives")
equal(offer.stackCount, 5, "original bundle quantity survives")
equal(offer.numAvailable, 4, "raw API stock count survives without conversion")
equal(offer.stockSource, "C_MerchantFrame.GetItemInfo.numAvailable", "stock provenance is explicit")
equal(offer.stockUnit, nil, "unverified stock units are not invented")
c.merchant[1].price, c.merchant[1].stackCount = 200, 10
c.Fire("MERCHANT_UPDATE")
offer = ns.db.merchantEvidence[5001][3]
equal(offer.unitCopper, 20, "same unit price is retained")
equal(offer.price, 200, "same-time bundle change preserves money total")
equal(offer.stackCount, 10, "same-time bundle change preserves quantity")
equal(invalidations, 2, "bundle-only change invalidates source evidence")
c.Fire("MERCHANT_UPDATE")
equal(invalidations, 2, "identical evidence does not invalidate")
c.now = c.now + 10
c.merchant[1].numAvailable = 0
c.Fire("MERCHANT_UPDATE")
offer = ns.db.merchantEvidence[5001][3]
equal(offer.stock, 0, "sold out stays zero even when a higher historical limit is saved")
equal(offer.numAvailable, 0, "sold-out raw API count stays zero")
equal(offer.observedAt, c.G.GetServerTime(), "updated stock owns its observation date")
equal(ns.db.stock[3][5001], 4, "historical limit remains separate")
c.npc.id = 5002
c.merchant[1].price, c.merchant[1].numAvailable = 200, -1
c.Fire("MERCHANT_SHOW")
offer = ns.db.merchantEvidence[5002][3]
equal(offer.unitCopper, 20, "a second vendor owns its own quote")
equal(offer.stock, "unlimited", "explicit unlimited stock is preserved")
equal(offer.numAvailable, -1, "unlimited observation keeps the raw API sentinel")
equal(ns.db.merchantEvidence[5001][3].unitCopper, 20, "another vendor cannot overwrite a quote")
c.merchant[1].hasExtendedCost = true
c.Fire("MERCHANT_UPDATE")
equal(ns.db.merchantEvidence[5002][3].unitCopper, nil, "a token offer cannot inherit an earlier money quote")
equal(ns.db.merchantEvidence[9999], nil, "no evidence is invented for another vendor")
c.merchant[1].hasExtendedCost, c.merchant[1].price, c.merchant[1].numAvailable = false, 0, nil
c.Fire("MERCHANT_UPDATE")
offer = ns.db.merchantEvidence[5002][3]
equal(offer.unitCopper, 0, "an explicit free money offer remains a known zero")
equal(offer.stock, nil, "missing stock cannot inherit the historical unlimited marker")
equal(offer.hasExtendedCost, false, "explicit money-only requirement survives")
c.merchant[1].hasExtendedCost = true
c.Fire("MERCHANT_UPDATE")
offer = ns.db.merchantEvidence[5002][3]
equal(offer.price, 0, "token offer preserves its zero money component")
equal(offer.hasExtendedCost, true, "token requirement cannot become a free money offer")
equal(offer.unitCopper, nil, "token offer has no money-only quote")
c.merchant[1].hasExtendedCost, c.merchant[1].price = false, 100
local previousPrice = ns.db.vendor[3]
for _, quantity in ipairs({ 0, -1, 1.5, math.huge, 0 / 0 }) do
	c.merchant[1].stackCount = quantity
	c.Fire("MERCHANT_UPDATE")
	offer = ns.db.merchantEvidence[5002][3]
	equal(offer.stackCount, nil, "invalid bundle quantity is absent")
	equal(offer.unitCopper, nil, "invalid bundle quantity cannot fabricate price")
	equal(ns.db.vendor[3], previousPrice, "invalid quantity cannot replace the historical vendor price")
end
c.merchant[1].hasExtendedCost, c.merchant[1].stackCount = false, 5
for _, price in ipairs({ -1, 1.5, math.huge, 0 / 0 }) do
	c.merchant[1].price = price
	c.Fire("MERCHANT_UPDATE")
	offer = ns.db.merchantEvidence[5002][3]
	equal(offer.price, nil, "invalid money total stays absent")
	equal(offer.unitCopper, nil, "invalid total cannot fabricate a quote")
	equal(ns.db.vendor[3], previousPrice, "invalid total cannot replace historical price")
end
for _, available in ipairs({ -2, 1.5, math.huge, 0 / 0 }) do
	c.merchant[1].numAvailable = available
	c.Fire("MERCHANT_UPDATE")
	offer = ns.db.merchantEvidence[5002][3]
	equal(offer.numAvailable, nil, "invalid raw stock stays absent")
	equal(offer.stock, nil, "invalid raw stock cannot imply unlimited")
	equal(offer.stockSource, nil, "absent stock has no provenance claim")
end
c.merchant[1].stackCount, c.merchant[1].hasExtendedCost = nil, false
c.Fire("MERCHANT_UPDATE")
equal(ns.db.merchantEvidence[5002][3].stackCount, nil, "missing quantity is never reconstructed as one")
ns.db.merchantEvidence[9998] = { [3] = { unitCopper = 20, stock = 4, observedAt = 1 } }
c.Fire("MERCHANT_UPDATE")
equal(ns.db.merchantEvidence[9998][3].stackCount, nil, "historical evidence gains no fabricated bundle")
equal(ns.db.merchantEvidence[9998][3].price, nil, "historical evidence gains no fabricated total")
print("source evidence specs passed")
