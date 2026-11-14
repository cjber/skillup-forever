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
local stamp = c.G.GetServerTime()
local offer = ns.MerchantEvidence(3, 5001, stamp)
equal(offer.unitCopper, 20, "unit quote belongs to the observed vendor")
equal(offer.stock, 4, "available count is an observation, not a maximum")
equal(offer.observedAt, stamp, "observation records its clock")
equal(offer.ageSeconds, 0, "observation age uses the supplied clock")
equal(invalidations, 1, "new source evidence follows the Changes invalidation owner")
offer.stock = 999
equal(ns.MerchantEvidence(3, 5001, stamp).stock, 4, "returned evidence cannot change the saved observation")
c.now = c.now + 10
c.merchant[1].numAvailable = 0
c.Fire("MERCHANT_UPDATE")
offer = ns.MerchantEvidence(3, 5001, c.G.GetServerTime() + 7)
equal(offer.stock, 0, "sold out stays zero even when a higher historical limit is saved")
equal(offer.ageSeconds, 7, "age is not replaced by a freshness threshold")
equal(ns.db.stock[3][5001], 4, "historical limit remains separate")
c.npc.id = 5002
c.merchant[1].price, c.merchant[1].numAvailable = 200, -1
c.Fire("MERCHANT_SHOW")
offer = ns.MerchantEvidence(3, 5002, c.G.GetServerTime())
equal(offer.unitCopper, 40, "a second vendor owns its own quote")
equal(offer.stock, "unlimited", "explicit unlimited stock is preserved")
equal(
	ns.MerchantEvidence(3, 5001, c.G.GetServerTime()).unitCopper,
	20,
	"last visited vendor cannot overwrite another quote"
)
c.merchant[1].hasExtendedCost = true
c.Fire("MERCHANT_UPDATE")
equal(
	ns.MerchantEvidence(3, 5002, c.G.GetServerTime()).unitCopper,
	nil,
	"a token offer cannot inherit an earlier money quote"
)
equal(ns.MerchantEvidence(3, 9999, c.G.GetServerTime()), nil, "no evidence is invented for another vendor")
equal(ns.MerchantEvidence(3, 5001, stamp - 1), nil, "a clock before the observation cannot establish age")
c.merchant[1].hasExtendedCost, c.merchant[1].price, c.merchant[1].numAvailable = false, 0, nil
c.Fire("MERCHANT_UPDATE")
offer = ns.MerchantEvidence(3, 5002, c.G.GetServerTime())
equal(offer.unitCopper, 0, "an explicit free money offer remains a known zero")
equal(offer.stock, nil, "missing available stock cannot inherit the historical unlimited marker")
equal(ns.MerchantEvidence(3, 5002, 0 / 0), nil, "an invalid clock cannot establish age")
print("source evidence specs passed")
