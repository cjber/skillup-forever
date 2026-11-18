-- Run from the repository root: luajit tests/item_info_spec.lua
-- #846: item data arrives for any item, from any addon (opening bags, a merchant window, players coming into view).
-- Only a sell price a route was priced without, arriving with another value, may plan the tracked routes again,
-- and every arrival in one frame shares that one plan.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local LEATHERWORKING, SKINNING = 165, 393
local LIGHT_LEATHER, COARSE_THREAD = 2318, 2320
local HANDSTITCHED_BOOTS, HANDSTITCHED_PANTS = 2149, 2153
local UNRELATED = 6948

local c = Client.load({ auctionator = false })
local ns = c.ns
c.level = 60
c.professions = {
	{ name = "Leatherworking", id = LEATHERWORKING, rank = 1, max = 75 },
	{ name = "Skinning", id = SKINNING, rank = 1, max = 75 },
}
c.known[HANDSTITCHED_BOOTS], c.known[HANDSTITCHED_PANTS] = true, true
ns.db.vendor[COARSE_THREAD] = 10
ns.SetCollectMode("gather")
ns.Changed("prices")
ns.SetTracked(LEATHERWORKING, true)

local plans = 0
local realPlan = ns.Model.PlanWithTraining
ns.Model.PlanWithTraining = function(...)
	plans = plans + 1
	return realPlan(...)
end
local function Plans(fire)
	plans = 0
	fire()
	c.Advance(1)
	ns.TrackedNeeds()
	return plans
end

ns.TrackedNeeds()
equal(c.requested[LIGHT_LEATHER], true, "the route asks for the sell price of its gathered leather")
equal(ns.Price(LIGHT_LEATHER).copper, 15, "meanwhile it uses the bundled sale value")

equal(
	Plans(function()
		for _ = 1, 40 do
			c.Fire("GET_ITEM_INFO_RECEIVED", UNRELATED, true)
		end
	end),
	0,
	"item data for other items plans nothing"
)

c.items[LIGHT_LEATHER] = { sell = 15 }
equal(
	Plans(function()
		c.Fire("GET_ITEM_INFO_RECEIVED", LIGHT_LEATHER, true)
	end),
	0,
	"the awaited sell price arriving at the value already used plans nothing"
)

-- The leather leaves the cache, the route is priced again without it, then it arrives at a new value.
c.items[LIGHT_LEATHER] = nil
ns.Changed("prices")
ns.TrackedNeeds()
c.items[LIGHT_LEATHER] = { sell = 20 }
equal(
	Plans(function()
		c.Fire("GET_ITEM_INFO_RECEIVED", LIGHT_LEATHER, true)
		c.Fire("GET_ITEM_INFO_RECEIVED", LIGHT_LEATHER, true)
		c.Fire("GET_ITEM_INFO_RECEIVED", UNRELATED, true)
	end),
	1,
	"a new sell price plans the tracked route once"
)
equal(ns.Price(LIGHT_LEATHER).copper, 20, "from the live sell price")

-- The rest of a bag, merchant and camera session's traffic: item data SkillUp did not ask for, bag slots that
-- did not move a route, and a merchant whose offers do not change. None of it plans a route.
c.merchant = {}
equal(
	Plans(function()
		for _ = 1, 40 do
			c.Fire("ITEM_DATA_LOAD_RESULT", UNRELATED, true)
			c.Fire("BAG_UPDATE_DELAYED")
		end
		c.Fire("MERCHANT_SHOW")
		for _ = 1, 20 do
			c.Fire("MERCHANT_UPDATE")
		end
		c.Fire("MERCHANT_CLOSED")
	end),
	0,
	"unrelated item, bag and merchant traffic plans nothing"
)

-- Item data SkillUp asked for arrives in a burst: one pass for the frame it arrives in and one for the rest,
-- however many arrive, and an answer that failed to load is still an answer.
local passes = 0
ns.WhenStaleObserver("route", function()
	passes = passes + 1
end)
for itemID = 30000, 30039 do
	ns.RequestItemData(itemID)
end
c.Advance(1)
for itemID = 30000, 30039 do
	c.Fire("ITEM_DATA_LOAD_RESULT", itemID, itemID % 2 == 0)
end
c.Advance(0)
equal(passes <= 2, true, "a burst of 40 answers is at most two passes, got " .. passes)
passes = 0
for itemID = 30000, 30039 do
	c.Fire("ITEM_DATA_LOAD_RESULT", itemID, true)
end
c.Advance(0)
equal(passes, 0, "answered requests, loaded or not, are not heard again")

Client.report("item_info_spec")
