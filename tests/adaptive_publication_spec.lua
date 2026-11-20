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
local API = c.G.SkillUpForever.API
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
equal(ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader), false, "missing alpha rejected")
equal(ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 0), true, "explicit adaptive zero accepted")
API.Professions()
API.ShoppingList()
equal(reads, 0, "getters never dispatch reader")
local pending = API.ShoppingList()[1].supplySummary
equal(pending.status, "calculating", "configured reader pending status")
equal(pending.alpha, 0, "pending explicit zero target")
Frame()
equal(reads, 1, "one frame dispatches fresh reader")
equal(Current().supply.job.result.status, "calculating", "shared frame does not drain snapshot")
local pendingJob = Current().supply.job
for _ = 1, 3 do
	API.ShoppingList()
end
equal(pendingJob.result.status, "calculating", "summary getter never advances job")
local direct =
	ns.RouteDemand.SelectAdaptiveSupply(Current(), { inventoryScope = "bags-only", policy = Copy(policy) }, 0)
while direct.result.status == "calculating" do
	direct:Advance(64)
end
equal(direct.result.status, "complete", "direct job completes before publication")
equal(ns.RouteDemand.Supply(Current()), nil, "unpublished result has no supply authority")
equal(API.ShoppingList()[1].supplySummary.status, "calculating", "unpublished summary waits for supply authority")
equal(API.ShoppingList()[1].supplySummary.coverageLower, nil, "unpublished summary hides probabilities")
local supply = Published()
equal(supply.have[30], 2, "non-route source product held in native bags")
equal(supply.result.service, "adaptive-finite", "plan keeps adaptive service")
equal(supply.result.inventoryScope, "bags-only", "plan keeps scope")
local summary = API.ShoppingList()[1].supplySummary
assert(summary, "public ShoppingList missing supply summary")
equal(summary.alpha, 0, "summary retains explicit zero")
equal(summary.status, "complete", "summary reads completed owner")
equal(summary.coverageLower, supply.result.coverageLower, "summary starting C0 lower")
equal(summary.successUpper, supply.result.successUpper, "summary continuation Ppi upper")
summary.status, summary.alpha = "mutated", 0.95
equal(API.ShoppingList()[1].supplySummary.alpha, 0, "summary caller cannot mutate owner")
local text = ns.ShoppingText()
assert(text:find("Target chance of finishing with starting supplies: 0%.", 1, true), "export retains zero target")
assert(text:find("Chance of finishing with starting supplies:", 1, true), "export explains C0")
assert(text:find("Chance of finishing with later purchases:", 1, true), "export explains Ppi")
local near = ns.SupplySummaryText({
	status = "complete",
	coverageLower = 1 - 1e-15,
	coverageUpper = 1,
	successLower = 0,
	successUpper = 1e-15,
})
assert(near:find("99.99% to 100.00%", 1, true), "near certainty rounds outward")
assert(near:find("0.00% to 0.01%", 1, true), "near zero rounds outward")
local certain = ns.SupplySummaryText({ status = "complete", coverageLower = 1, coverageUpper = 1 })
assert(certain:find("100.00% to 100.00%", 1, true), "exact certainty remains exact")
assert(supply.result.carryLower <= 6 and supply.result.carryUpper >= 6, "plan retains terminal carry")
c.Advance(0)
local public = API.Professions()[1].supply
equal(public.certificate.kind, "finite-dag-exhaustive", "API publishes complete adaptive certificate")
equal(public.selection.kind, "finite-initial-enumeration", "API retains selection proof")
equal(public.inventoryScope, "bags-only", "API preserves scope")
public.certificate.sources[1].offerID = "mutated"
equal(
	API.Professions()[1].supply.certificate.sources[1].offerID,
	policy.sources[1].offerID,
	"API certificate copy owns nested records"
)
equal(ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, -1), false, "invalid replacement rejected")
equal(Current().supply, supply, "invalid configuration preserves owner")
local completed = supply.job
c.bags[30] = 3
c.Fire("PLAYER_MONEY")
equal(completed.result.status, "cancelled", "completed ownership revoked")
supply = Published()
equal(reads, 2, "resource revision obtains fresh request")
equal(supply.have[30], 3, "fresh request uses fresh holdings")
equal(supply.result.sourceRevision, 2, "fresh source revision retained")
ns.RouteDemand.Invalidate()
Frame()
local active = Current().supply.job
c.Fire("PLAYER_MONEY")
equal(active.result.status, "cancelled", "active snapshot revoked")
Published()
equal(reads, 4, "active invalidation also rereads")
-- Display inventory includes bank stock, but certified coordinates exclude it.
local native = c.G.C_Item.GetItemCount
c.G.C_Item.GetItemCount = function(id, bank)
	if id == 30 then
		return bank and 99 or 0
	end
	return native(id)
end
ns.RouteDemand.Invalidate()
supply = Published()
equal(supply.have[30], 0, "bank-only non-route inventory excluded")
local rows = ns.RouteReagents(Current())
local other
for _, row in ipairs(rows) do
	if row.itemID == 30 then
		other = row
	end
end
equal(ns.RouteDemand.Held(other), 0, "certified zero never falls back to bank")
supply.have[30] = nil
other = nil
for _, row in ipairs(ns.RouteReagents(Current())) do
	if row.itemID == 30 then
		other = row
	end
end
equal(ns.RouteDemand.Held(other), nil, "missing certificate coordinate never falls back")
ns.Changed("supply")
c.Advance(0)
local shopping = API.ShoppingList()[1]
for _, row in ipairs(shopping.items) do
	if row.itemID == 30 then
		equal(row.have, nil, "API missing coordinate stays unknown")
		equal(row.inventoryScope, "bags-only", "shopping row exposes native inventory scope")
	end
end
c.G.C_Item.GetItemCount = native
local old = supply.job
local replacement = ns.RouteDemand.SelectAdaptiveSupply(Current(), Reader(), 0)
equal(old.result.status, "cancelled", "direct replacement cancels completed owner")
local fixed = ns.RouteDemand.SelectSupply(Current(), {}, nil)
equal(replacement.result.status, "cancelled", "direct fixed mode replaces adaptive")
assert(ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 0))
local adaptive = ns.RouteDemand.SelectAdaptiveSupply(Current(), Reader(), 0)
equal(fixed.result.status, "cancelled", "direct adaptive mode replaces fixed")
ns.RouteDemand.ConfigureSupply(197, function()
	return nil
end, 1)
Frame()
equal(adaptive.result.status, "cancelled", "configured fixed mode replaces direct owner")
equal(Current().supply.job.result.status, "unknown", "nil fixed reader publishes unknown")
equal(ns.RouteDemand.ConfigureSupply(197, Reader, 0), false, "fixed zero contract preserved")
ns.RouteDemand.ConfigureAdaptiveSupply(197, function()
	error("reader failed")
end, 0)
Frame()
equal(Current().supply.job.result.status, "unknown", "reader exception cannot inherit finite pool")
ns.RouteDemand.ConfigureAdaptiveSupply(197, function()
	return nil
end, 0)
Frame()
equal(Current().supply.job.result.status, "unknown", "nil adaptive request is unknown")
ns.RouteDemand.ConfigureSupply(197, nil)
equal(Current().supply, nil, "either configuration API removes current mode")
-- A reader that replaces itself cannot publish its superseded request.
ns.RouteDemand.ConfigureAdaptiveSupply(197, function()
	ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 0)
	return Reader()
end, 0)
Frame()
equal(Current().supply, nil, "reentrant reader replacement cannot publish old request")
supply = Published()
assert(supply.result.certificate, "replacement reader retains ownership")
-- Cancellation may synchronously publish a replacement owner.
local cancelled = supply.job
local cancel = cancelled.Cancel
local callbackJob
cancelled.Cancel = function(self)
	cancel(self)
	if not callbackJob then
		callbackJob = ns.RouteDemand.SelectAdaptiveSupply(Current(), Reader(), 0)
	end
end
local superseded = ns.RouteDemand.SelectSupply(Current(), {}, nil)
equal(superseded.result.status, "cancelled", "cancellation callback supersedes pending publisher")
equal(Current().supply.job, callbackJob, "callback replacement retains plan ownership")
Published()
-- A source, route or native resource revision obtains new finite input.
for _, kind in ipairs({ "sourceEvidence", "bags", "replan", "recipes" }) do
	local previous = Current().supply.job
	local before = reads
	ns.Changed(kind)
	equal(previous.result.status, "cancelled", kind .. " revokes completed record")
	Published()
	equal(reads, before + 1, kind .. " calls fresh reader")
end
for _, event in ipairs({
	"CURRENCY_DISPLAY_UPDATE",
	"PLAYERBANKSLOTS_CHANGED",
	"BANKFRAME_OPENED",
	"BANKFRAME_CLOSED",
}) do
	local previous = Current().supply.job
	local before = reads
	c.Fire(event)
	equal(previous.result.status, "cancelled", event .. " revokes completed record")
	Published()
	equal(reads, before + 1, event .. " calls fresh reader")
end
-- The persisted estimate option revokes a published certificate through the chance producer.
c.SetSetting("includeWorkingOvertime", true)
c.traitConfigs[1187] = 621140
c.traitNodes[621140] = { [110290] = { activeRank = 5, maxRanks = 5 } }
c.Fire("TRAIT_NODE_CHANGED", 110290)
Published()
local enabledPlan = Current()
local enabledJob = enabledPlan.supply.job
local enabledRevision = ns.Model.ChanceRevision()
local optionReads = reads
c.SetSetting("includeWorkingOvertime", false)
equal(ns.Model.ChanceRevision(), enabledRevision + 1, "option advances chance revision")
equal(enabledJob.result.status, "cancelled", "option revokes published certificate")
assert(Current() ~= enabledPlan, "option invalidates cached route plan")
equal(ns.RouteDemand.Supply(Current()), nil, "option hides old certificate until recomputed")
equal(reads, optionReads, "option does not synchronously invoke reader")
Published()
equal(reads, optionReads + 1, "option obtains fresh certificate request")
local disabledJob = Current().supply.job
c.traitNodes[621140][110290].activeRank = 1
c.Fire("TRAIT_CONFIG_UPDATED")
equal(ns.Model.ChanceRevision(), enabledRevision + 1, "trait event while off preserves chance revision")
equal(Current().supply.job, disabledJob, "trait event while off preserves certificate")
c.SetSetting("includeWorkingOvertime", true)
equal(disabledJob.result.status, "cancelled", "reenabling revokes base certificate")
equal(ns.workingOvertimeRank, 1, "reenabling uses current detected rank")
Published()
local before = reads
local previous = Current().supply.job
ns.Model.SetChanceBonus(0.01)
equal(ns.RouteDemand.Supply(Current()), nil, "getter rejects stale chance certificate without starting work")
equal(API.ShoppingList()[1].supplySummary.status, "cancelled", "summary rejects stale chance owner")
equal(API.ShoppingList()[1].supplySummary.coverageLower, nil, "stale owner hides probability")
equal(reads, before, "chance getter does not invoke reader")
Frame()
equal(previous.result.status, "cancelled", "shared frame revokes completed chance revision")
Published()
equal(reads, before + 1, "chance revision obtains fresh request")
ns.Model.SetChanceBonus(0)
Published()
-- Configuration commits reject nested replacement from cancellation callbacks.
ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 0)
supply = Published()
local configJob = supply.job
local configCancel = configJob.Cancel
local nestedResult
configJob.Cancel = function(self)
	configCancel(self)
	nestedResult = ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 0)
end
local beforeSwitchReads = reads
equal(
	ns.RouteDemand.ConfigureSupply(197, function()
		return nil
	end, 1),
	true,
	"outer mode change commits despite reentrant cancellation callback"
)
equal(nestedResult, false, "nested configuration cannot replace the committed mode")
equal(configJob.result.status, "cancelled", "committed switch retires the adaptive job")
for _ = 1, 5 do
	Frame()
	API.ShoppingList()
end
equal(reads, beforeSwitchReads, "rejected nested configuration cannot resurrect adaptive reader")
assert(ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 0))
supply = Published()
local beforeCancel = reads
supply.job:Cancel()
equal(API.ShoppingList()[1].supplySummary.status, "cancelled", "cancelled configured owner stays cancelled")
for _ = 1, 5 do
	Frame()
	API.ShoppingList()
end
equal(reads, beforeCancel, "cancelled getter never schedules replacement")
equal(API.ShoppingList()[1].supplySummary.status, "cancelled", "cancelled status persists without queued replacement")
ns.RouteDemand.Invalidate()
equal(API.ShoppingList()[1].supplySummary.status, "calculating", "invalidation queues replacement")
Published()
-- Typed payments and actual visit fares are separate from offer money.
c.bags[10], c.bags[20], c.money = 0, 2, 20
c.G.C_CurrencyInfo.GetCurrencyInfo = function()
	return { quantity = 2 }
end
policy.sources[1] = {
	offerID = "typed",
	npcID = 123,
	itemID = 10,
	bundleUnits = 1,
	moneyCopper = 3,
	costs = { ["item:20"] = 1, ["currency:20"] = 1 },
	maxBundles = 1,
	stockKey = "S",
	stockPerBundle = 1,
	vendor = "V",
	access = true,
	priceLaw = "fixed",
	futureDelivery = { chance = 1, payOnFailure = true },
}
policy.terminalCarry = { ["item:10"] = 0, ["item:20"] = 0, ["currency:20"] = 0 }
policy.tokenValues = { ["item:20"] = 0, ["currency:20"] = 0 }
policy.initialVisitMoney.V = 5
ns.Changed("bags")
c.Advance(0)
ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 1)
supply = Published()
equal(supply.items[10], 1, "initial inventory target is gross product")
equal(supply.have[20], 2, "held token count is pre-payment inventory")
equal(supply.acquisitions[1].moneyCopper, 3, "offer quote excludes monetary fare")
equal(supply.acquisitions[1].costs["item:20"], 1, "item payment retained")
equal(supply.acquisitions[1].costs["currency:20"], 1, "same-id currency payment retained separately")
equal(supply.result.certificate.laws.initialVisitMoney.V, 5, "certificate retains visit fare")
c.Advance(0)
public = API.Professions()[1]
local buy
for _, step in ipairs(public.steps) do
	if step.acquisition then
		buy = step
	end
end
equal(buy.cost, 3, "API acquisition quotes offer money only")
equal(buy.acquisition.costs["currency:20"], 1, "API acquisition retains typed payment")
equal(public.supply.certificate.laws.initialVisitMoney.V, 5, "API retains fare in certificate")
local job = supply.job
ns.RouteDemand.ConfigureAdaptiveSupply(197, nil)
equal(job.result.status, "cancelled", "removal cancels completed owned job")
equal(Current().supply, nil, "removal clears plan owner")
local function Status()
	for _ = 1, 10000 do
		Frame()
		local owner = Current().supply
		if owner and owner.job.result.status ~= "calculating" then
			return owner.job.result.status
		end
	end
	error("configured status did not settle")
end
policy.options.workLimit = 2
ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 1)
equal(Status(), "unknown", "snapshot exhaustion cannot publish incumbent")
local unknown = API.ShoppingList()[1].supplySummary
equal(unknown.status, "unknown", "shopping retains unknown status")
equal(unknown.coverageLower, nil, "unknown cannot publish probability")
equal(ns.RouteDemand.Supply(Current()), nil, "unknown has no shopping budget")
policy.options.workLimit, policy.stock.S = 1000000, 0
ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 1)
equal(Status(), "infeasible", "finite impossibility remains distinct")
equal(API.ShoppingList()[1].supplySummary.status, "infeasible", "shopping retains infeasible status")
equal(ns.RouteDemand.Supply(Current()), nil, "infeasible has no shopping budget")
ns.RouteDemand.ConfigureSupply(197, nil)
local unconfigured = API.ShoppingList()[1].supplySummary
equal(unconfigured.status, "unconfigured", "removed configuration leaves ordinary estimates")
equal(unconfigured.alpha, nil, "ordinary estimates have no default alpha")
assert(ns.ShoppingText():find("quantities are estimates", 1, true), "ordinary export labels estimates")
-- A configured reader that moves the chance revision while the solver frame runs keeps the frame up to revoke
-- that revision, so the reader runs again rather than the frame sleeping on a stale result.
local solver
for _, frame in ipairs(c.frames) do
	local callback = frame.scripts.OnUpdate
	if callback and debug.getinfo(callback, "S").source:find("Core/RouteDemand.lua", 1, true) then
		solver = frame
	end
end
local movedReads = 0
assert(ns.RouteDemand.ConfigureSupply(197, function()
	movedReads = movedReads + 1
	if movedReads == 1 then
		ns.Model.SetChanceBonus(0.03)
	end
	return nil
end, 1))
for _ = 1, 100 do
	if not solver:IsShown() then
		break
	end
	solver.scripts.OnUpdate(solver, 0)
end
equal(movedReads, 2, "a revision moved inside the solver frame is revoked before it sleeps")
equal(solver:IsShown(), false, "the solver frame sleeps once the moved revision is handled")
ns.RouteDemand.ConfigureSupply(197, nil)
ns.Model.SetChanceBonus(0)
print("adaptive publication: passed")
