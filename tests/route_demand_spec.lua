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

local function Policy()
	return {
		service = "fixed-batch",
		journey = "independent-round-trips",
		walletCopper = "unlimited",
		route = { legs = {}, held = {}, buy = {} },
		currencies = {},
		tokenValues = {},
		stock = { S = 1 },
		sources = {
			{
				itemID = 10,
				bundleUnits = 2,
				moneyCopper = 3,
				maxBundles = 1,
				stockKey = "S",
				stockPerBundle = 1,
				vendor = "V",
				access = true,
				priceLaw = "fixed",
				costs = {},
			},
		},
		initialOrders = {},
		refillOrders = { { source = 1, bundles = 1 } },
		initialVisitCosts = { V = 5 },
		refillVisitCosts = { V = 5 },
		options = {
			workLimit = 100000,
			stateLimit = 1000,
			coordinateLimit = 32,
			probabilityTolerance = 1e-9,
			costTolerance = 1e-8,
			visitTolerance = 1e-9,
		},
	}
end
c.bags[10], c.money = 0, 3
local contract = Policy()
local owned = ns.RouteDemand.StartPolicy(plan, contract)
contract.stock.S, contract.sources[1].bundleUnits, contract.options.workLimit = 0, 999, 1
local evaluated = Finish(owned)
equal(evaluated.status, "complete", "owned policy survives caller mutation")
assert(evaluated.successLower <= 1 / 4 and evaluated.successUpper >= 1 / 4, "two-stage live pooled finite supply")
assert(evaluated.costLower <= 8 and evaluated.costUpper >= 8, "live wallet and declared trip expense")
for _, event in ipairs({
	"PLAYER_MONEY",
	"CURRENCY_DISPLAY_UPDATE",
	"PLAYERBANKSLOTS_CHANGED",
	"BANKFRAME_OPENED",
	"BANKFRAME_CLOSED",
}) do
	local pending = ns.RouteDemand.StartPolicy(plan, Policy())
	local complete = ns.RouteDemand.StartPolicy(plan, Policy())
	equal(Finish(complete).status, "complete", "policy completed before " .. event)
	c.Fire(event)
	equal(pending:Advance(1).status, "cancelled", event .. " revokes pending policy")
	equal(complete:Advance(1).status, "cancelled", event .. " revokes completed policy")
end
c.money = nil
equal(Finish(ns.RouteDemand.StartPolicy(plan, Policy())).status, "unknown", "missing wallet never becomes zero")
c.money = 3
local withCurrency = Policy()
withCurrency.sources[1].costs = { ["currency:9"] = 1 }
withCurrency.tokenValues["currency:9"] = 2
equal(Finish(ns.RouteDemand.StartPolicy(plan, withCurrency)).status, "unknown", "currency capability is independent")
c.G.C_CurrencyInfo.GetCurrencyInfo = function()
	return { quantity = 1 }
end
equal(Finish(ns.RouteDemand.StartPolicy(plan, withCurrency)).status, "complete", "live currency balance permits policy")
c.G.C_CurrencyInfo.GetCurrencyInfo = function()
	return {}
end
equal(Finish(ns.RouteDemand.StartPolicy(plan, withCurrency)).status, "unknown", "missing currency amount is not zero")
local withToken = Policy()
withToken.sources[1].costs = { ["item:20"] = 1 }
withToken.tokenValues["item:20"] = 0
c.bags[20] = 1
c.G.C_Item.GetItemCount = function(id, includeBank)
	return countAPI(id) + (includeBank and id == 20 and 1 or 0)
end
local located = Finish(ns.RouteDemand.StartPolicy(plan, withToken))
equal(located.status, "unknown", "bank token needs an explicit location transition")
assert(located.reasons[1]:find("location"), "location remains an explicit unknown")
c.G.C_Item.GetItemCount = countAPI
equal(
	Finish(ns.RouteDemand.StartPolicy(plan, withToken)).status,
	"complete",
	"bag token shares the live item namespace"
)

-- The owned asynchronous selection publishes one shared raw budget. No getter
-- drains work, and a resource event revokes it before another view can read it.
local function Frame()
	for index = c.coreFrames + 1, #c.frames do
		local frame = c.frames[index]
		if frame.scripts.OnUpdate then
			frame.scripts.OnUpdate(frame, 0)
		end
	end
end
c.bags[10], c.money = 0, 6
local selectedContract = Policy()
selectedContract.stock.S = 2
local selected = ns.RouteDemand.SelectSupply(plan, selectedContract, 0.65)
equal(ns.RouteDemand.Supply(plan), nil, "pending selection is not a supply certificate")
for _ = 1, 10000 do
	Frame()
	if selected.result.status ~= "calculating" then
		break
	end
end
equal(selected.result.status, "complete", "frame-owned selection completes")
local supplyFrame
for _, frame in ipairs(c.frames) do
	local callback = frame.scripts and frame.scripts.OnUpdate
	if callback and debug.getinfo(callback, "S").source:find("Core/RouteDemand.lua", 1, true) then
		supplyFrame = frame
	end
end
equal(supplyFrame:IsShown(), false, "solver frame hides once no work is pending")
local supply = assert(ns.RouteDemand.Supply(plan))
equal(supply.items[10], 4, "two-stage shared inventory coverage selects four raw units")
equal(supply.have[10], 0, "published holdings are the fresh snapshot")
local reagents = ns.RouteReagents(plan)
equal(#reagents, 1, "shared raw budget is not duplicated per craft")
equal(reagents[1].need, 4, "shopping reads the selected budget")
c.Fire("PLAYER_MONEY")
equal(supplyFrame:IsShown(), true, "invalidation wakes the solver frame")
equal(ns.RouteDemand.Supply(plan), nil, "wallet revision revokes published shopping counts")
equal(selected.result.status, "cancelled", "published result is revoked too")
equal(plan.supply, nil, "plan does not retain stale published budget")
for _ = 1, 10000 do
	Frame()
	if not supplyFrame:IsShown() then
		break
	end
end
equal(supplyFrame:IsShown(), false, "solver frame sleeps again after the revocation drains")
ns.Model.SetChanceBonus(0.02)
equal(supplyFrame:IsShown(), true, "a chance revision with no game event wakes the solver frame")
ns.Model.SetChanceBonus(0)
local missingAlpha = ns.RouteDemand.SelectSupply(plan, Policy(), nil)
equal(missingAlpha.result.status, "unknown", "live selection has no default confidence")
equal(ns.RouteDemand.Supply(plan), nil, "unknown selection cannot change shopping counts")
Client.report("Route demand")
