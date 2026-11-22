local Client = dofile("tests/client.lua")
local equal = Client.equal
local c = Client.load({
	data = {
		Thresholds = { [1] = { 0, 0, 0, 2 }, [2] = { 0, 0, 0, 2 }, [3] = { 0, 0, 0, 2 } },
		RecipeData = {
			[1] = { skillLine = 197, reagents = { { itemID = 10, quantity = 1 } } },
			[2] = { skillLine = 197, reagents = { { itemID = 10, quantity = 1 } } },
			[3] = {
				skillLine = 197,
				output = { itemID = 10, quantity = 1 },
				reagents = { { itemID = 20, quantity = 1 } },
			},
		},
		VendorPrices = { [10] = 100, [20] = 1 },
		TrainerFees = {},
		TrainerRanks = {},
		ItemSellPrices = {},
	},
})
local ns = c.ns
ns.SetCollectMode("gather")
c.schematics = {
	[1] = { reagents = { { 10, 1 } }, output = 11 },
	[2] = { reagents = { { 10, 1 } }, output = 12 },
	[3] = { reagents = { { 20, 1 } }, output = 10 },
}
c.known[3] = true
c.bags[10] = 2
local plan = {
	profession = { modifier = 0 },
	crafts = {
		{ recipeID = 1, from = 1, to = 2, subcrafts = {} },
		{ recipeID = 2, from = 1, to = 2, subcrafts = {} },
	},
}
local function Finish(job)
	while job.result.status == "calculating" do
		job:Advance(17)
	end
	return job.result
end
-- Prices prefers making this item, but the final route explicitly buys it.
assert(ns.Price(10) and not ns.Price(10).unknown, "fixture has a released price valuation")
assert(ns.SubCraft(10), "fixture establishes a cheaper known crafted input")
local result = Finish(ns.RouteDemand.Start(plan, { [10] = 6 }))
equal(result.coverageKnown, true, "bought crafted ingredient accepted")
assert(result.coverageLower <= 247 / 256 and result.coverageUpper >= 247 / 256, "pooled held stock exact probability")
assert(result.coverageUpper - result.coverageLower < 1e-10, "tight probability enclosure")
equal(result.costKnown, false, "released valuation is not observed expenditure")
equal(result.costCopper, nil, "no invented expenditure")
assert(
	table.concat(result.reasons, " "):find("feasible source orders", 1, true),
	"explicit missing source evidence reason"
)
plan.crafts[1].subcrafts = { { recipeID = 3 } }
equal(Finish(ns.RouteDemand.Start(plan, { [10] = 6 })).supported, false, "selected subcraft rejected")
plan.crafts[1].subcrafts = {}
local reuse = { profession = plan.profession, crafts = { { recipeID = 3, from = 1, to = 2 }, plan.crafts[1] } }
equal(Finish(ns.RouteDemand.Start(reuse, { [10] = 6, [20] = 6 })).supported, false, "route output reuse rejected")
local malformed = {
	{ [10] = -1 },
	{ [10] = 0.5 },
	{ [10] = math.huge },
	{ [10] = 0 / 0 },
	{ [10] = "6" },
	{ bad = 6 },
	{ [math.huge] = 6 },
	false,
}
for _, basket in ipairs(malformed) do
	local ok, rejected = pcall(function()
		return Finish(ns.RouteDemand.Start(plan, basket))
	end)
	assert(ok, "malformed basket must not throw")
	equal(rejected.supported, false, "malformed basket rejected by Demand")
	equal(rejected.coverageKnown, false, "malformed basket cannot certify coverage")
end
local absent = Finish(ns.RouteDemand.Start(plan, nil))
equal(absent.supported, false, "missing basket rejected")
local basket = { [10] = 6 }
local frozen = ns.RouteDemand.Start(plan, basket)
basket[10] = 0
frozen:Advance(1)
frozen:Advance(1)
equal(#frozen.result.reasons, 1, "pending cost reason stays bounded")
equal(Finish(frozen).coverageKnown, true, "caller basket mutation cannot change snapshot")
c.bags[10] = math.huge
equal(Finish(ns.RouteDemand.Start(plan, { [10] = 6 })).supported, false, "nonfinite inventory rejected by Demand")
c.bags[10] = 2
for _, change in ipairs({ "sourceEvidence", "prices" }) do
	local pending = ns.RouteDemand.Start(plan, { [10] = 6 })
	local complete = ns.RouteDemand.Start(plan, { [10] = 6 })
	equal(Finish(complete).coverageKnown, true, "completed certificate before change")
	local rebuilds = 0
	ns.WhenStaleObserver("plans", function()
		rebuilds = rebuilds + 1
	end)
	ns.Changed(change)
	equal(pending:Advance(1).status, "cancelled", change .. " revokes pending")
	equal(complete:Advance(1).status, "cancelled", change .. " revokes completed")
	equal(complete.result.coverageKnown, false, "revoked coverage")
	if change == "sourceEvidence" then
		equal(rebuilds, 0, "source evidence does not rebuild plans")
	end
end
-- Probability certificates cannot use the display's last-readable count.
equal(ns.Have(10), 2, "display count primed")
local countAPI = c.G.C_Item.GetItemCount
c.G.C_Item.GetItemCount = function()
	return nil
end
equal(ns.Have(10), 2, "legacy display retains its last readable count")
local missingCount, countReason = ns.RouteDemand.Snapshot(plan, {})
equal(missingCount, nil, "unreadable current inventory never certifies an old quantity")
assert(countReason and countReason:find("inventory"), "missing inventory has an explicit reason")
c.G.C_Item.GetItemCount = countAPI
c.G.C_Item.GetItemCount = nil
equal(ns.RouteDemand.Snapshot(plan, {}), nil, "missing count capability stays unknown")
c.G.C_Item.GetItemCount = countAPI
c.bags[10] = 5
local fresh = assert(ns.RouteDemand.Snapshot(plan, {}))
equal(fresh.held[10], 5, "restored capability reads the new count")
local Secret = {}
local secretAPI = c.G.issecretvalue
c.G.issecretvalue = function(value)
	return value == Secret
end
c.G.C_Item.GetItemCount = function()
	return Secret
end
equal(ns.RouteDemand.Snapshot(plan, {}), nil, "secret native count is unknown")
c.G.C_Item.GetItemCount = countAPI
c.G.issecretvalue = secretAPI
equal(ns.RouteDemand.Count(0, true), nil, "zero is not an item identity")

Client.report("Route demand")
