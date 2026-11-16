local Client = dofile("tests/client.lua")
local c = Client.load({
	boot = false,
	saved = { routeTargets = { [197] = 2 }, trackedProfessions = { [197] = true } },
	data = {
		Thresholds = { [1] = { 0, 0, 2, 2 } },
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
c.bags[10], c.bags[30], c.money = 2, 0, 0
c.items[11] = { sell = 0 }
c.items[10] = { name = "Synthetic Reagent" }
c.items[20] = { name = "Synthetic Token" }
c.items[30] = { name = "Synthetic Other" }
c.auction[10] = 3
c.G.Professions = {
	GetProfessionInfo = function()
		return { professionName = "Tailoring", professionID = 197 }
	end,
}
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
	terminalCarry = { ["item:10"] = 0, ["item:30"] = 0, ["item:11"] = 0 },
	failureLoss = 0,
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

local crafted = false
local reads = 0
local function Reader()
	reads = reads + 1
	return {
		inventoryScope = "bags-only",
		policy = Copy(policy),
		crafted = crafted
				and { version = "crafted-adapter-v1", revision = ns.RecipeEvidence.Revision(), skillLine = 197 }
			or nil,
	}
end
assert(ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 0.75))
local supply = Published()
local root, coverage
for _, row in ipairs(supply.result.certificate.policy) do
	if row.state == supply.result.certificate.initialState then
		root = row
	end
end
for _, row in ipairs(supply.result.certificate.coveragePolicy) do
	if row.state == supply.result.certificate.coverageState then
		coverage = row
	end
end
assert(
	supply.result.coverageLower <= 0.75 and supply.result.coverageUpper >= 0.75,
	"two half-chance attempts C0 contains exact 3/4"
)
equal(supply.result.successUpper, 0, "economic continuation stops with Ppi zero")
equal(root.kind, "stop", "economic root stops")
equal(coverage.kind, "craft", "coverage root crafts")
equal(ns.NextCraft(Current()).recipeID, nil, "economic stop must suppress estimated craft")
local function Action()
	return ns.RouteDemand.NextAction(Current())
end
equal(Action().kind, "stop", "economic stop resolves from A root")
equal(Action().reason, "economic-stop", "stop differs from completion")
equal(Action().state, supply.result.certificate.initialState, "exact economic key")
equal(Action().resources.wallet, 0, "owned wallet")
equal(Action().resources.balances[1], 2, "ordered exact holding")
local beforeReads = reads
local itemCount, wallet = c.G.C_Item.GetItemCount, c.G.GetMoney
c.G.C_Item.GetItemCount = function()
	error("getter read native inventory")
end
c.G.GetMoney = function()
	error("getter read native wallet")
end
for _ = 1, 4 do
	local a = Action()
	a.resources.balances[1] = 999
	local public = API.Professions()[1].nextAction
	equal(public.kind, "stop", "API uses current action owner")
	public.resources.balances[1] = 888
end
local routeProfessions, planRoute = ns.RouteProfessions, ns.PlanRoute
ns.RouteProfessions = function()
	error("API copy re-enumerated professions")
end
ns.PlanRoute = function()
	error("API copy resolved a plan")
end
for _ = 1, 3 do
	local public = API.Professions()[1].nextAction
	equal(public.generation, supply.generation, "stable API copy retains current publication generation")
	equal(public.kind, "stop", "stable API copy retains current action")
end
ns.RouteProfessions, ns.PlanRoute = routeProfessions, planRoute
equal(reads, beforeReads, "getters do not dispatch reader")
equal(Action().resources.balances[1], 2, "action and API copies own nested resources")
c.G.C_Item.GetItemCount, c.G.GetMoney = itemCount, wallet
local oldGeneration = Action().generation
c.Fire("PLAYER_MONEY")
equal(Action().kind, "unsupported", "resource event revokes action immediately")
equal(API.Professions()[1].nextAction.kind, "unsupported", "API copy rejects revoked action owner")
equal(ns.NextCraft(Current()).recipeID, nil, "stale configured mode cannot estimate")
Published()
assert(Action().generation > oldGeneration, "new publication generation")
equal(API.Professions()[1].nextAction.generation, Action().generation, "API copy observes replacement publication")
-- A direct finished job has no authority until the existing shared frame publishes.
local direct = ns.RouteDemand.SelectAdaptiveSupply(Current(), Reader(), 0.75)
while direct.result.status == "calculating" do
	direct:Advance(64)
end
equal(direct.result.status, "complete", "direct solve completed")
equal(Action().kind, "unsupported", "direct solve awaits publication")
Published()
-- Raw consumption has no identified recipe binding.
policy.failureLoss = 100
ns.RouteDemand.Invalidate()
Published()
equal(Action().reason, "recipe-binding-missing", "raw craft never borrows estimated recipe")
equal(ns.NextCraft(Current()).recipeID, nil, "unbound craft disabled")
-- Bind the actual crafted adapter through native schematic observation.
c.G.C_TradeSkillUI.GetProfessionInfoByRecipeID = function()
	return { professionID = 8197, skillLevel = 1, skillModifier = 0, maxSkillLevel = 75 }
end
c.G.C_TradeSkillUI.GetRecipeSchematic = function()
	return {
		recipeID = 1,
		isRecraft = false,
		quantityMin = 1,
		quantityMax = 1,
		outputItemID = 11,
		reagentSlotSchematics = {
			{
				reagentType = 0,
				quantityRequired = 1,
				reagents = { { itemID = 10 } },
				slotIndex = 1,
				dataSlotIndex = 1,
				required = true,
			},
		},
	}
end
local observed = assert(ns.RecipeEvidence.Observe(1, "action-main", 10000))
assert(ns.RecipeEvidence.Declare(197, {
	version = "crafted-adapter-v1",
	skillGainLaw = "whole-successful-count-bounded-by-rank",
	universeComplete = true,
	recipes = {
		{
			recipeID = 1,
			professionID = observed.professionID,
			role = "main",
			available = true,
			scope = "synthetic completed attempt law",
			skillEffect = "route",
			productionLaw = "deterministic-completed-attempt",
			use = { [10] = 1 },
			produce = { [11] = 1 },
			evidence = {
				revision = observed.revision,
				allocation = observed.allocation,
				clientBuild = observed.clientBuild,
			},
		},
	},
	prerequisites = { [1] = { rank = true, training = true, tools = true, station = true, access = true } },
	allocations = {
		[1] = {
			identity = observed.allocation,
			complete = true,
			slots = { { slotIndex = 1, dataSlotIndex = 1, itemID = 10, quantity = 1 } },
		},
	},
	eligibility = { [1] = { fromSkill = 0, toSkill = 75 } },
}, 10000))
crafted = true
ns.RouteDemand.Invalidate()
supply = Published()
equal(Action().kind, "craft", "crafted economic root")
equal(Action().recipeID, 1, "declared exact recipe")
equal(Action().role, "main", "declared main role")
equal(Action().count, 1, "one attempt despite craftable batch")
equal(Action().executable, false, "guidance only")
equal(ns.NextCraft(Current()).count, 1, "Plan dispatch retains one attempt")
equal(ns.NextCraft(Current()).nextAction.state, Action().state, "UI dispatch receives same action")
local cert = supply.result.certificate
for _, row in ipairs(cert.policy) do
	if row.state == cert.initialState then
		equal(#row.successors, 2, "gain and no-gain successors retained")
	end
end
-- Exercise the actual Route page and tracker closures with synthetic frames.
local G = c.G
c.live[1] = { info = { recipeID = 1, learned = true } }
local function UIFrame(name, parent)
	return G.CreateFrame("Frame", name, parent)
end
local frame = UIFrame("ProfessionsFrame", G.UIParent)
frame:SetSize(673, 594)
frame:SetPoint("TOPLEFT", G.UIParent, "TOPLEFT", 51, -34)
local craftingPage = UIFrame("CraftingPage", frame)
craftingPage:SetSize(673, 594)
local book = UIFrame("BookPage", frame)
book:Hide()
local list = UIFrame(nil, craftingPage)
list:SetWidth(304)
list.ScrollBox = UIFrame(nil, list)
list.ScrollBox.GetDataProvider = function()
	return nil
end
list.ScrollBox.RegisterCallback = function() end
list.IsVisible = function(self)
	return self:IsShown()
end
craftingPage.RecipeList = list
craftingPage.SchematicForm = UIFrame(nil, craftingPage)
craftingPage.SchematicForm:SetWidth(360)
local shown = nil
craftingPage.SchematicForm.GetRecipeInfo = function()
	return shown
end
craftingPage.CreateAllButton = UIFrame(nil, craftingPage)
craftingPage.CreateButton = UIFrame(nil, craftingPage)
frame.CraftingPage, frame.BookPage = craftingPage, book
frame.Pages = { craftingPage, book }
frame.ProfessionsOverviewTab = UIFrame(nil, frame)
frame.ProfessionsOverviewTab:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -60)
frame.ProfessionsOverviewTab:SetSize(43, 55)
frame.rightProfessionTabs = {}
frame.professionInfo = { professionID = 197, professionName = "Tailoring" }
frame.RefreshRightTabs = function() end
G.ProfessionsFrame = frame
G.Professions.GetHighestLearnedRecipe = function(info)
	return info
end
local opened = {}
G.C_TradeSkillUI.OpenRecipe = function(id)
	opened[#opened + 1] = id
end
G.C_TradeSkillUI.CraftRecipe = function()
	error("adaptive guidance executed craft")
end
G.BuyMerchantItem = function()
	error("adaptive guidance executed purchase")
end
c.LoadAddOn("Blizzard_Professions")
local route
for _, child in ipairs({ frame:GetChildren() }) do
	if child.Profession and child.RouteList then
		route = child
	end
end
assert(route, "actual Route page built")
local tab = ns.Pages.SideTab()
tab.mouseUp(tab, "LeftButton", true)
Published()
c.Advance(0.3)
local function HasRouteMessage(text)
	for _, row in ipairs(route.RouteList.rows) do
		if row.kind == "message" and row.text == text then
			return true
		end
	end
	return false
end
assert(
	HasRouteMessage(
		"Adaptive guidance opens the recommended recipe. Choose how many to craft in the profession window."
	),
	"adaptive status explains recipe guidance"
)
equal(
	HasRouteMessage("Craft next follows the estimated route."),
	false,
	"adaptive status does not claim estimated dispatch"
)
equal(opened[#opened], 1, "route guidance only opens native recipe")
equal(route.Craft:IsEnabled(), false, "adaptive route cannot execute a craft")
for _, attribute in ipairs({ "type", "clickbutton", "shift-type1", "shift-clickbutton1" }) do
	equal(route.Craft.attributes[attribute], nil, "no adaptive secure proxy: " .. attribute)
end
-- The queued render contains craft guidance. Revoke it while combat owns the
-- protected button, then replay only after resolving the new economic stop.
c.combat = true
ns.Changed("supply")
c.Advance(0.3)
policy.failureLoss = 0
ns.RouteDemand.Invalidate()
Published()
equal(Action().kind, "stop", "replacement economic stop while combat queues redraw")
local openedBefore = #opened
c.combat = false
c.Fire("PLAYER_REGEN_ENABLED")
equal(#opened, openedBefore, "combat callback cannot open superseded recipe")
equal(route.Craft.recipeID, nil, "combat callback re-resolves stop")
equal(route.Craft:IsEnabled(), false, "stop stays disarmed")
-- Re-publish craft and capture a tracker callback, then replace its owner.
policy.failureLoss = 100
ns.RouteDemand.Invalidate()
Published()
c.Advance(0.3)
local function Menu()
	local menu = { buttons = {} }
	function menu.CreateTitle() end
	function menu.SetScrollMode() end
	function menu.CreateButton(_, text, callback)
		local child = Menu()
		child.text, child.callback = text, callback
		menu.buttons[#menu.buttons + 1] = child
		return child
	end
	return menu
end
local menu = Menu()
G.ForeverCore.ContextMenu = function(owner, generator)
	generator(owner, menu)
end
local block = { id = 197, profession = "Tailoring", plan = Current(), steps = {}, vendorMissing = {} }
local module = G.SkillUpForeverObjectiveTracker
module.GetContextMenuParent = function()
	return module
end
module:OnBlockHeaderClick(block)
local captured
for _, button in ipairs(menu.buttons) do
	if button.text:find("^Craft") then
		captured = button.callback
	end
end
assert(captured, "tracker offers identified recipe guidance")
policy.failureLoss = 0
ns.RouteDemand.Invalidate()
Published()
openedBefore = #opened
captured()
equal(#opened, openedBefore, "tracker callback re-resolves instead of opening captured recipe")
-- A native recipe refresh must resolve the economic stop before opening.
for _, callback in ipairs(c.callbacks["Professions.RecipeSelected"] or {}) do
	callback.callback(callback.owner)
end
equal(#opened, openedBefore, "native refresh cannot open superseded recipe")
equal(route.Craft.recipeID, nil, "native refresh re-resolves stop")
policy.failureLoss = 100
ns.RouteDemand.Invalidate()
Published()
c.Advance(0.3)
-- No gesture or getter traverses a successor. A coherent resource event revokes
-- the whole publication, even when only one coordinate appears to match.
local currentKey = Action().state
ns.NextCraft(Current())
equal(Action().state, currentKey, "guidance query never advances state")
c.bags[10], c.bags[11] = 1, 1
ns.Changed("bags")
equal(Action().kind, "unsupported", "observed no-gain resources revoke old root")
equal(ns.NextCraft(Current()).recipeID, nil, "no second old action on bag event")
-- Initial purchase remains the whole pre-payment basket, not its delivered root.
c.bags[10], c.bags[11], c.money = 0, 0, 20
policy.sources[1].itemID, policy.sources[1].access, policy.sources[1].moneyCopper = 10, true, 3
policy.sources[1].npcID, policy.sources[1].maxBundles = 123, 1
policy.stock.S = 2
policy.initialVisitMoney.V = 2
c.bags[20] = 2
c.G.C_CurrencyInfo = {
	GetCoinTextureString = c.G.C_CurrencyInfo.GetCoinTextureString,
	GetCurrencyInfo = function()
		return { quantity = 2 }
	end,
}
policy.sources[1].costs = { ["item:20"] = 1, ["currency:20"] = 1 }
policy.currencies = { [20] = 0 }
policy.tokenValues = { ["item:20"] = 0, ["currency:20"] = 0 }
policy.terminalCarry["item:20"], policy.terminalCarry["currency:20"] = 0, 0
policy.assumptions = {
	{
		offerID = policy.sources[1].offerID,
		field = "priceLaw",
		revision = 1,
		provenance = "synthetic observation",
		scope = "current session",
		observedAt = 1,
		observationRevision = "synthetic:1",
		session = 7,
		index = 2,
	},
}
policy.terminalCarry["item:11"] = 0
assert(ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 0.75))
supply = Published()
local purchase = Action()
equal(purchase.kind, "purchase", "initial purchase before hypothetical root")
equal(purchase.phase, "initial", "initial phase explicit")
equal(#purchase.orders, 2, "full atomic basket keeps split ceiling orders")
equal(purchase.orders[1].binding.offerID, policy.sources[1].offerID, "source identity retained")
equal(purchase.orders[1].binding.npcID, 123, "exact NPC binding")
equal(purchase.orders[1].binding.moneyCopper, 3, "quote separate from fare")
equal(purchase.visits.V, 2, "monetary fare retained")
equal(purchase.resources.wallet, 20, "pre-payment wallet")
local pre, post = {}, {}
for i, coordinate in ipairs(purchase.coordinates) do
	pre[coordinate] = purchase.resources.balances[i]
	post[coordinate] = supply.result.certificate.initialResources.balances[i]
end
equal(pre["item:20"], 2, "initial item-token payment outstanding")
equal(pre["currency:20"], 2, "same-id currency payment outstanding")
equal(pre["item:10"], 0, "product not yet delivered")
equal(post["item:20"], 0, "hypothetical root debits item tokens")
equal(post["currency:20"], 0, "hypothetical root debits separate currency")
equal(post["item:10"], 2, "hypothetical root includes full delivery")
equal(supply.result.certificate.initialResources.wallet, 12, "hypothetical root debits fare and quote")
equal(purchase.assumptions[1].session, 7, "dated exact session retained")
equal(purchase.assumptions[1].index, 2, "dated exact offer slot retained")
purchase.orders[1].binding.costs["currency:20"] = 999
purchase.assumptions[1].session = 99
equal(Action().orders[1].binding.costs["currency:20"], 1, "basket nested copy")
equal(Action().assumptions[1].session, 7, "basket provenance copy")
equal(purchase.postInitialState, supply.result.certificate.initialState, "hypothetical delivered root named separately")
assert(purchase.state ~= purchase.postInitialState, "purchase cannot claim delivered root")
equal(purchase.atomic, true, "basket indivisible")
equal(purchase.executable, false, "no automatic merchant execution")
equal(ns.NextCraft(Current()).recipeID, nil, "purchase disables estimated craft")
for _ = 1, 3 do
	equal(Action().state, purchase.state, "getters never deliver basket")
end
c.bags[10], c.money = 1, 17
ns.Changed("bags")
equal(Action().kind, "unsupported", "partial purchase cannot reconcile root")
-- Continuation acquisition is selected at alpha zero, never guessed from rows.
c.bags[10], c.money = 0, 20
policy.failureLoss, policy.initialVisitMoney.V = 100, 0
policy.sources[1].costs = {}
assert(ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 0))
Published()
equal(Action().kind, "purchase", "economic continuation acquisition")
equal(Action().phase, "continuation", "empty initial basket does not hide continuation")
equal(Action().orders[1].binding.stockKey, "S", "finite pool bound")
c.money = 2
ns.Changed("bags")
Published()
equal(Action().kind, "stop", "unaffordable acquisition stops economically")
-- A chance revision is rejected synchronously, before the shared frame cancels.
ns.Model.SetChanceBonus(0.01)
equal(Action().kind, "unsupported", "chance mismatch revokes authority before frame")
equal(ns.NextCraft(Current()).recipeID, nil, "chance mismatch never estimates")
ns.Model.SetChanceBonus(0)
ns.RouteDemand.Invalidate()
Published()
local completedOwner = Current().supply.job
assert(ns.RecipeEvidence.Observe(1, "new-action-allocation", 10000))
equal(completedOwner.result.status, "cancelled", "recipe observation revokes completed owner")
equal(Action().kind, "unsupported", "recipe revision never estimates")
crafted = false
-- Replacing configuration revokes action before its reader runs.
assert(ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 0))
equal(Action().kind, "unsupported", "replacement configuration cannot reuse old owner")
equal(ns.NextCraft(Current()).recipeID, nil, "replacement cannot fall through")
policy.options.workLimit = 2
local function Settled()
	for _ = 1, 10000 do
		Frame()
		local owner = Current().supply
		if owner and owner.job.result.status ~= "calculating" then
			return owner.job.result.status
		end
	end
	error("fixture did not settle")
end
equal(Settled(), "unknown", "bounded exhaustion remains unknown")
equal(Action().kind, "unsupported", "unknown never estimates")
policy.options.workLimit = 1000000
policy.stock.S = 0
assert(ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 1))
equal(Settled(), "infeasible", "finite infeasible distinct")
equal(ns.NextCraft(Current()).recipeID, nil, "infeasible never estimates")
assert(ns.RouteDemand.ConfigureAdaptiveSupply(197, nil))
equal(Action(), nil, "explicit removal restores ordinary mode")
c.bags[10] = 2
ns.Changed("bags")
equal(ns.NextCraft(Current()).recipeID, 1, "ordinary estimate remains available")
-- Direct adaptive ownership also survives replacement of the cached Plan.
policy.stock.S, policy.failureLoss = 0, 0
local directPlan = Current()
ns.RouteDemand.SelectAdaptiveSupply(directPlan, Reader(), 0)
Published()
equal(Action().kind, "stop", "direct adaptive publication owns current plan")
ns.Changed("replan")
assert(Current() ~= directPlan, "replan replaces cached Plan")
equal(Action().kind, "unsupported", "direct adaptive intent survives replaced Plan")
equal(ns.NextCraft(Current()).recipeID, nil, "direct stale owner never becomes estimate")
assert(ns.RouteDemand.ConfigureAdaptiveSupply(197, nil))
equal(Action(), nil, "explicit removal clears direct adaptive intent")
-- Direct fixed selection removes the configured adaptive reader as well as intent.
assert(ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 0))
local switching = Published().job
local fixed = Copy(policy)
fixed.service = "fixed-batch"
fixed.options.probabilityTolerance = 1e-9
fixed.options.costTolerance = 1e-8
fixed.options.visitTolerance = 1e-9
fixed.refillOrders = { { source = 1, bundles = 1 } }
fixed.initialVisitCosts, fixed.refillVisitCosts = { V = 0 }, { V = 0 }
local fixedJob = ns.RouteDemand.SelectSupply(Current(), fixed, 0.75)
equal(switching.result.status, "cancelled", "fixed switch cancels configured adaptive job")
equal(Current().supply.job, fixedJob, "fixed switch owns its selected job")
equal(Action(), nil, "direct fixed switch clears configured adaptive guard")
equal(ns.NextCraft(Current()).recipeID, 1, "fixed switch restores ordinary estimate")
c.Advance(0.3)
assert(HasRouteMessage("Craft next follows the estimated route."), "fixed status retains estimated guidance")
local switchReads = reads
ns.Changed("bags")
for _ = 1, 5 do
	Frame()
end
equal(reads, switchReads, "fixed switch cannot resurrect adaptive reader")
equal(Action(), nil, "fixed mode survives resource invalidation")
-- A cancellation callback replacing configuration wins over the outer switch.
assert(ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 0))
local cancelling = Published().job
local cancel = cancelling.Cancel
local replaced = false
cancelling.Cancel = function(self)
	cancel(self)
	if not replaced then
		replaced = true
		assert(ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 0))
	end
end
local superseded = ns.RouteDemand.SelectSupply(Current(), fixed, 0.75)
equal(superseded.result.status, "cancelled", "reentrant configuration supersedes fixed switch")
equal(Action().kind, "unsupported", "replacement configuration retains adaptive guard")
Published()
equal(Action().kind, "stop", "replacement adaptive reader publishes")
-- A direct owner published by cancellation also supersedes the outer switch.
local directCancelled = Current().supply.job
local directCancel = directCancelled.Cancel
local callbackJob
directCancelled.Cancel = function(self)
	directCancel(self)
	if not callbackJob then
		callbackJob = ns.RouteDemand.SelectAdaptiveSupply(Current(), Reader(), 0)
	end
end
superseded = ns.RouteDemand.SelectSupply(Current(), fixed, 0.75)
equal(superseded.result.status, "cancelled", "direct callback supersedes fixed switch")
equal(Current().supply.job, callbackJob, "direct callback retains owner")
Published()
equal(Action().kind, "stop", "direct callback retains adaptive intent")

-- A direct Configure call during cancellation is rejected without replacing
-- the staged configuration, while the outer commit still completes.
assert(ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 0))
local reentrant = Published().job
local reentrantCancel = reentrant.Cancel
local reentrantResult
reentrant.Cancel = function(self)
	reentrantCancel(self)
	reentrantResult = ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 0)
end
assert(ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 0))
assert(reentrantResult == false, "direct reentrant Configure is rejected")

-- A failing old cancellation is contained at the final configuration commit.
assert(ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 0))
local throwing = Published().job
throwing.Cancel = function()
	error("synthetic cancellation failure")
end
assert(ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 0), "replacement survives old cancellation failure")
assert(Current().supply == nil, "throwing cancellation detaches the retired plan owner")
assert(ns.RouteDemand.ConfigureAdaptiveSupply(197, nil), "failed cancellation does not wedge configuration")

assert(ns.RouteDemand.ConfigureAdaptiveSupply(197, nil))
c.professions[1].rank = 75
c.Fire("SKILL_LINES_CHANGED")
assert(ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 0))
Published()
equal(Action().kind, "stop", "completed route resolves stop")
equal(Action().reason, "complete", "completion differs from economic failure stop")
equal(ns.NextCraft(Current()).recipeID, nil, "complete never estimates a craft")
assert(ns.RouteDemand.ConfigureAdaptiveSupply(197, nil))
print("adaptive action: passed")
