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
c.now = c.now + 10
c.merchant[1].numAvailable = 0
c.Fire("MERCHANT_UPDATE")
offer = ns.db.merchantEvidence[5001][3]
equal(offer.stock, 0, "sold out stays zero even when a higher historical limit is saved")
equal(offer.observedAt, c.G.GetServerTime(), "updated stock owns its observation date")
equal(ns.db.stock[3][5001], 4, "historical limit remains separate")
c.npc.id = 5002
c.merchant[1].price, c.merchant[1].numAvailable = 200, -1
c.Fire("MERCHANT_SHOW")
offer = ns.db.merchantEvidence[5002][3]
equal(offer.unitCopper, 40, "a second vendor owns its own quote")
equal(offer.stock, "unlimited", "explicit unlimited stock is preserved")
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
print("source evidence specs passed")
