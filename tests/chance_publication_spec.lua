local Client = dofile("tests/client.lua")
local c = Client.load({
	boot = false,
	saved = { routeTargets = { [197] = 2 }, trackedProfessions = { [197] = true } },
	data = {
		Thresholds = { [1] = { 0, 2, 2, 2 } },
		RecipeData = {
			[1] = {
				skillLine = 197,
				output = { itemID = 11, quantity = 1 },
				reagents = { { itemID = 10, quantity = 1 } },
			},
		},
		TrainerFees = {},
		TrainerRanks = {},
		ItemSellPrices = {},
	},
})
c.professions = { { name = "Tailoring", icon = 1, rank = 1, max = 75, id = 8197 } }
c.known[1], c.spells[1] = true, "Synthetic Cloth"
c.schematics = { [1] = { reagents = { { 10, 1 } }, output = 11 } }
c.bags[10], c.bags[30], c.money = 1, 2, 0
c.items[11] = { sell = 0 }
c.items[10] = { name = "Synthetic Reagent" }
c.items[20] = { name = "Synthetic Token" }
c.items[30] = { name = "Synthetic Other" }
c.auction[10] = 3
c.Boot()
local ns = c.ns
local plan = {
	profession = { modifier = 0 },
	crafts = { { recipeID = 1, from = 1, to = 2 } },
}
local policy = {
	service = "adaptive-finite",
	journey = "independent-round-trips",
	delivery = "independent-bundle-outcomes",
	objective = "expected-expenditure-plus-terminal-carry-plus-failure-loss",
	route = assert(ns.RouteDemand.Snapshot(plan, {})),
	walletCopper = 0,
	currencies = {},
	stock = { S = 1 },
	sources = {
		{
			offerID = "inaccessible-other-product",
			itemID = 30,
			bundleUnits = 1,
			moneyCopper = 0,
			costs = {},
			maxBundles = 1,
			stockKey = "S",
			stockPerBundle = 1,
			vendor = "V",
			access = false,
			priceLaw = "fixed",
			futureDelivery = { chance = 1, payOnFailure = true },
		},
	},
	initialOrders = {},
	tokenValues = {},
	terminalCarry = { ["item:10"] = 0, ["item:30"] = 3 },
	failureLoss = 100,
	initialVisitMoney = { V = 0 },
	refillVisitMoney = { V = 0 },
	initialVisitValue = { V = 0 },
	refillVisitValue = { V = 0 },
	sourceRevision = 1,
	assumptions = {},
	options = { workLimit = 1000000, stateLimit = 1000, coordinateLimit = 32, limbLimit = 256 },
}
local equal = Client.equal
local function Current()
	return ns.PlanRoute(assert(ns.RouteProfessions()[197]))
end
local function Frame()
	for _, frame in ipairs(c.frames) do
		local callback = frame.scripts.OnUpdate
		if callback and debug.getinfo(callback, "S").source:find("Core/RouteDemand.lua", 1, true) then
			callback(frame, 0)
		end
	end
end
local function Published()
	for _ = 1, 10000 do
		Frame()
		local supply = ns.RouteDemand.Supply(Current())
		if supply then
			return supply
		end
	end
	error("adaptive publication did not complete")
end
local function Copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, field in pairs(value) do
		result[key] = Copy(field)
	end
	return result
end
local reads = 0
local function Reader()
	reads = reads + 1
	local fresh = Copy(policy)
	fresh.sourceRevision = reads
	return { inventoryScope = "bags-only", policy = fresh }
end
-- Both sides of the frame boundary preserve only current-revision owners.
for _, mode in ipairs({ "adaptive", "fixed" }) do
	local function Select()
		if mode == "adaptive" then
			return ns.RouteDemand.SelectAdaptiveSupply(Current(), Reader(), 0)
		end
		local fixed = Copy(policy)
		fixed.service = "fixed-batch"
		fixed.options.probabilityTolerance = 1e-9
		fixed.options.costTolerance = 1e-8
		fixed.options.visitTolerance = 1e-9
		fixed.refillOrders = {}
		fixed.initialVisitCosts, fixed.refillVisitCosts = { V = 0 }, { V = 0 }
		return ns.RouteDemand.SelectSupply(Current(), fixed, 0.9)
	end
	ns.Model.SetChanceBonus(0.01)
	local current = Select()
	Frame()
	assert(current.result.status ~= "cancelled", mode .. " current direct job survives delayed chance frame")
	equal(Current().supply.job, current, mode .. " current direct owner retained")
	ns.Model.SetChanceBonus(0.02)
	Frame()
	equal(current.result.status, "cancelled", mode .. " stale direct job revoked")
	local after = Select()
	Frame()
	assert(after.result.status ~= "cancelled", mode .. " direct job after chance frame survives")
	-- Cancelling the stale owner can synchronously publish a current owner.
	local cancel = after.Cancel
	local replacement
	after.Cancel = function(self)
		cancel(self)
		if not replacement then
			replacement = Select()
		end
	end
	ns.Model.SetChanceBonus(0.03)
	Frame()
	equal(after.result.status, "cancelled", mode .. " reentrant stale job cancelled")
	equal(Current().supply.job, replacement, mode .. " reentrant current owner survives")
	assert(replacement.result.status ~= "cancelled", mode .. " reentrant current job survives")
	-- Complete a current-revision direct solve before the frame observes it.
	ns.Model.SetChanceBonus(0.035)
	local complete = Select()
	for _ = 1, 10000 do
		if complete.result.status ~= "calculating" then
			break
		end
		complete:Advance(1000)
	end
	equal(
		complete.result.status,
		"complete",
		mode .. " direct solver completes before chance frame: " .. table.concat(complete.result.reasons, "; ")
	)
	Frame()
	equal(complete.result.status, "complete", mode .. " completed current direct job survives")
	equal(Current().supply.job, complete, mode .. " completed current owner survives")
	equal(ns.RouteDemand.Supply(Current()).job, complete, mode .. " current completion publishes")
	ns.RouteDemand.Invalidate()
	equal(complete.result.status, "cancelled", mode .. " explicit invalidation revokes completed current job")
	equal(replacement.result.status, "cancelled", mode .. " explicit invalidation still revokes current jobs")
	ns.Model.SetChanceBonus(0)
	Frame()
end
-- Configured readers refresh even if a direct current job was already published.
ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 0)
Published()
local before = reads
ns.Model.SetChanceBonus(0.04)
local direct = ns.RouteDemand.SelectAdaptiveSupply(Current(), Reader(), 0)
Frame()
equal(reads, before + 2, "chance frame refreshes configured reader after direct publication")
equal(direct.result.status, "cancelled", "configured refresh replaces direct owner")
Published()
-- A reader can move chance during dispatch. The next frame must retain the
-- newly captured revision rather than cancelling it for the delayed observation.
local moved = false
ns.RouteDemand.ConfigureAdaptiveSupply(197, function()
	if not moved then
		moved = true
		ns.Model.SetChanceBonus(0.05)
	end
	return Reader()
end, 0)
Frame()
local fresh = Current().supply.job
Frame()
-- The configured refresh is intentional, so the old job is replaced once.
equal(fresh.result.status, "cancelled", "reentrant chance change refreshes configuration")
local owner = Current().supply.job
Published()
equal(owner.result.status, "complete", "reentrant configured replacement completes")
ns.RouteDemand.ConfigureAdaptiveSupply(197, nil)
print("chance publication: passed")
