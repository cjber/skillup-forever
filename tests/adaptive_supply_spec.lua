local Client = dofile("tests/client.lua")
local c = Client.load({
	boot = false,
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
local job = ns.RouteDemand.StartAdaptive(plan, { inventoryScope = "bags-only", policy = policy }, 1)
while job.result.status == "calculating" do
	job:Advance(64)
end
assert(job.result.status == "complete", job.result.reasons[1])
assert(
	job.result.carryLower <= 6 and job.result.carryUpper >= 6,
	"native bags hold two unused source products: terminal carry must enclose 6, got "
		.. job.result.carryLower
		.. ","
		.. job.result.carryUpper
)
local checks = 1
local function Check(value, reason)
	checks = checks + 1
	assert(value, reason)
end
local request = { inventoryScope = "bags-only", policy = policy }
local function Finish(requested, alpha)
	local pending = ns.RouteDemand.StartAdaptive(plan, requested or request, alpha == nil and 1 or alpha)
	for _ = 1, 100000 do
		if pending.result.status ~= "calculating" then
			return pending.result, pending
		end
		pending:Advance(64)
	end
	error("adaptive snapshot exceeded explicit work budget")
end
Check(
	job.result.inventoryScope == "bags-only" and job.result.service == "adaptive-finite",
	"scope and adaptive mode remain explicit"
)
Check(policy.route.held[30] == nil and policy.walletCopper == 0, "caller policy remains unchanged")
local nativeCount = c.G.C_Item.GetItemCount
local reads = 0
c.G.C_Item.GetItemCount = function(id, bank, uses, reagentBank, accountBank)
	reads = reads + 1
	Check(
		bank == false and uses == false and reagentBank == false and accountBank == false,
		"every native include flag is explicitly false"
	)
	return c.bags[id] or 0
end
local pending = ns.RouteDemand.StartAdaptive(plan, request, 1)
Check(reads == 0 and pending.result.status == "calculating", "getters/start do no synchronous inventory traversal")
pending:Advance(1)
Check(reads == 0 and pending.result.status == "calculating", "snapshot copying yields before native reads")
pending:Cancel()
Check(
	pending:Advance(64).status == "cancelled" and reads == 0,
	"cancelled partial snapshot never reads native balances"
)
local result = Finish()
Check(
	result.status == "complete" and result.have[30] == 2,
	"unused inaccessible source product is owned native inventory"
)
-- An explicit modeled coordinate must be read even when only a valuation mentions it.
c.bags[40] = 4
policy.terminalCarry["item:40"] = 2
result = Finish()
Check(
	result.status == "complete" and result.have[40] == 4 and result.carryLower <= 14 and result.carryUpper >= 14,
	"valuation-only native holdings enter terminal carry"
)
policy.terminalCarry["item:40"] = nil
local before = reads
policy.options.coordinateLimit = 1
result = Finish()
Check(result.status == "unknown" and reads == before, "complete coordinate domain is bounded before inventory reads")
policy.options.coordinateLimit = 32
c.G.C_Item.GetItemCount = function(id, bank, uses, reagentBank, accountBank)
	Check(
		bank == false and uses == false and reagentBank == false and accountBank == false,
		"bank-only stock is excluded with all flags false"
	)
	return id == 30 and 0 or c.bags[id] or 0
end
result = Finish()
Check(
	result.status == "complete" and result.have[30] == 0 and result.carryUpper == 0,
	"bank-only stock is never available through bags-only snapshot"
)
c.G.C_Item.GetItemCount = nil
Check(Finish().status == "unknown", "missing item capability is unknown")
c.G.C_Item.GetItemCount = function()
	return nil
end
Check(Finish().status == "unknown", "missing item quantity is unknown")
c.G.C_Item.GetItemCount = nativeCount
local money = c.G.GetMoney
c.G.GetMoney = function()
	return nil
end
Check(Finish().status == "unknown", "missing wallet quantity is unknown")
c.G.GetMoney = money
policy.currencies[30], policy.terminalCarry["currency:30"] = 999, 2
Check(Finish().status == "unknown", "modeled currency requires native capability")
c.G.C_CurrencyInfo = {
	GetCurrencyInfo = function(id)
		return { quantity = id == 30 and 5 or 0 }
	end,
}
result = Finish()
Check(
	result.status == "complete" and result.carryLower <= 16 and result.carryUpper >= 16 and result.have[30] == 2,
	"typed currency and item identities remain separate and caller balance is replaced"
)
c.G.C_CurrencyInfo.GetCurrencyInfo = function()
	return { quantity = -1 }
end
Check(Finish().status == "unknown", "invalid currency count never becomes zero")
policy.currencies[30], policy.terminalCarry["currency:30"] = nil, nil
Check(Finish({ inventoryScope = "bank", policy = policy }).status == "unknown", "bank access is never assumed")
Check(Finish(request, 0 / 0).status == "unknown", "alpha remains explicit finite probability")
local complete, completed = Finish()
Check(complete.status == "complete", "complete before invalidation")
ns.RouteDemand.Invalidate()
Check(completed.result.status == "cancelled", "completed native certificate is revoked")
local active = ns.RouteDemand.StartAdaptive(plan, request, 1)
active:Advance(5)
ns.RouteDemand.Invalidate()
Check(active:Advance(64).status == "cancelled", "invalidation revokes partial freeze")
local original = c.G.C_Item.GetItemCount
c.G.C_Item.GetItemCount = function(id)
	c.Fire("PLAYER_MONEY")
	return c.bags[id] or 0
end
Check(Finish().status == "cancelled", "reentrant native invalidation cannot overwrite cancellation with publication")
c.G.C_Item.GetItemCount = original
c.G.GetMoney = function()
	c.Fire("PLAYER_MONEY")
	return c.money
end
Check(Finish().status == "cancelled", "reentrant wallet invalidation cannot publish")
c.G.GetMoney = money
c.G.GetMoney = function()
	ns.Model.SetChanceBonus(0.01)
	return c.money
end
local reentrantRevision = ns.RouteDemand.StartAdaptive(plan, request, 1)
reentrantRevision:Advance(1000000)
Check(
	reentrantRevision.result.status == "cancelled",
	"reentrant probability revision cannot publish within same Advance"
)
ns.Model.SetChanceBonus(0)
c.G.GetMoney = money
local secret, secretCheck = {}, c.G.issecretvalue
c.G.issecretvalue = function(value)
	return value == secret
end
c.G.C_Item.GetItemCount = function()
	return secret
end
Check(Finish().status == "unknown", "secret inventory count remains unknown")
c.G.C_Item.GetItemCount = original
c.G.GetMoney = function()
	return secret
end
Check(Finish().status == "unknown", "secret wallet remains unknown")
c.G.GetMoney = money
policy.currencies[30], policy.terminalCarry["currency:30"] = 0, 0
c.G.C_CurrencyInfo.GetCurrencyInfo = function()
	return { quantity = secret }
end
Check(Finish().status == "unknown", "secret currency quantity remains unknown")
policy.currencies[30], policy.terminalCarry["currency:30"] = nil, nil
c.G.issecretvalue = secretCheck
for _, event in ipairs({
	"BAG_UPDATE_DELAYED",
	"PLAYER_MONEY",
	"CURRENCY_DISPLAY_UPDATE",
	"PLAYERBANKSLOTS_CHANGED",
	"BANKFRAME_OPENED",
	"BANKFRAME_CLOSED",
	"SKILL_LINES_CHANGED",
}) do
	local _, snapshot = Finish()
	c.Fire(event)
	c.Advance(0)
	Check(snapshot.result.status == "cancelled", event .. " revokes complete native snapshot")
end
local owned = Finish()
local sourceID = owned.certificate.sources[1].offerID
policy.sources[1].offerID = "caller changed after snapshot"
Check(owned.certificate.sources[1].offerID == sourceID, "completed certificate owns source bindings")
policy.sources[1].offerID = sourceID
local missingAlpha = ns.RouteDemand.StartAdaptive(plan, request, nil)
missingAlpha:Advance(64)
Check(missingAlpha.result.status == "unknown", "missing alpha is never a default")
Check(Finish(request, 0).status == "complete", "explicit zero alpha remains a supported adaptive choice")
local _, probabilityJob = Finish()
ns.Model.SetChanceBonus(0.01)
Check(probabilityJob:Advance(1).status == "cancelled", "probability revision cancels completed adapter before reuse")
ns.Model.SetChanceBonus(0)
local _, sourceJob = Finish()
ns.Changed("sourceEvidence")
c.Advance(0)
Check(sourceJob.result.status == "cancelled", "source evidence revision cancels completed adapter")
policy.options.workLimit = 2
result = Finish()
Check(result.status == "unknown" and result.certificate == nil, "snapshot work exhaustion never certifies")
policy.options.workLimit = 1000000
local cycle = {}
cycle.self = cycle
policy.assumptions = cycle
Check(Finish().status == "unknown", "cyclic caller records are rejected under budget")
policy.assumptions = {}
Check(type(ns.RouteDemand.ConfigureAdaptiveSupply) == "function", "configured adaptive publication exists")
print("adaptive supply: " .. checks .. " checks passed")
