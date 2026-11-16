local Client = dofile("tests/client.lua")
local equal = Client.equal
local c = Client.load({
	boot = false,
	saved = { routeTargets = { [197] = 2 }, trackedProfessions = { [197] = true } },
	data = {
		Thresholds = { [1] = { 0, 0, 0, 2 } },
		RecipeData = {
			[1] = {
				skillLine = 197,
				output = { itemID = 11, quantity = 1 },
				reagents = { { itemID = 10, quantity = 1 } },
			},
		},
		VendorPrices = { [10] = 3 },
		TrainerFees = {},
		TrainerRanks = {},
		ItemSellPrices = {},
	},
	questie = {
		items = { [10] = { class = 7, vendors = { 123, 456, 789 } } },
		npcs = {
			[123] = { name = "Selected First", spawns = { [10] = { { 50, 50 } } }, side = "AH" },
			[456] = { name = "Selected Second", spawns = { [10] = { { 60, 60 } } }, side = "AH" },
			[789] = { name = "Unselected Nearest", spawns = { [10] = { { 1, 1 } } }, side = "AH" },
		},
		areas = { [10] = 10 },
	},
})
c.professions = { { name = "Tailoring", icon = 1, rank = 1, max = 75, id = 8197 } }
c.known[1] = true
c.spells[1] = "Synthetic Cloth"
c.items[11] = { sell = 0 }
c.schematics = { [1] = { reagents = { { 10, 1 } }, output = 11 } }
c.money = 6
c.bags[20] = 4
c.items[90] = { name = "Synthetic Tool" }
c.auction[90] = 7
c.live[1] = { requirements = { { type = 1, name = "Synthetic Tool", met = false } } }
c.auction[10] = 3
c.Boot()
c.maps = { [0] = { mapID = 10, name = "Synthetic Zone" } }
local ns, API = c.ns, c.G.SkillUpForever.API
local function Policy()
	return {
		sourceRevision = 7,
		assumptions = {
			{
				offerID = "selected-token-offer",
				field = "stock",
				revision = 2,
				provenance = "synthetic declaration",
				scope = "this run",
				observedAt = 42,
				observationRevision = "fixture",
				session = 1,
				index = 1,
			},
		},
		service = "fixed-batch",
		journey = "independent-round-trips",
		walletCopper = "unlimited",
		route = { legs = {}, held = {}, buy = {} },
		currencies = {},
		tokenValues = { ["item:20"] = 0, ["item:99"] = 0 },
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
				offerID = "selected-token-offer",
				npcID = 123,
				access = true,
				priceLaw = "fixed",
				costs = { ["item:20"] = 1 },
			},
			{
				itemID = 10,
				bundleUnits = 3,
				moneyCopper = 1,
				maxBundles = 1,
				stockKey = "S",
				stockPerBundle = 1,
				vendor = "W",
				offerID = "cheaper-unaffordable",
				npcID = 456,
				access = true,
				priceLaw = "fixed",
				costs = { ["item:99"] = 1 },
			},
		},
		initialOrders = {},
		refillOrders = { { source = 1, bundles = 1 } },
		initialVisitCosts = { V = 5, W = 0 },
		refillVisitCosts = { V = 5, W = 0 },
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

local function Frame()
	for index = c.coreFrames + 1, #c.frames do
		local frame = c.frames[index]
		if frame.scripts.OnUpdate then
			frame.scripts.OnUpdate(frame, 0)
		end
	end
	c.Advance(0)
end
local function Current()
	return ns.PlanRoute(assert(ns.RouteProfessions()[197]))
end
local function Published()
	for _ = 1, 10000 do
		Frame()
		local supply = ns.RouteDemand.Supply(Current())
		if supply then
			return supply
		end
	end
	error("configured supply did not publish")
end
-- Advance only the source job: unrelated views must not refresh a stale API status.
local function PolicyFrame()
	for _, frame in ipairs(c.frames) do
		local callback = frame.scripts.OnUpdate
		if callback and debug.getinfo(callback, "S").source:find("Core/RouteDemand.lua", 1, true) then
			callback(frame, 0)
		end
	end
end
for _ = 1, 4 do
	Frame()
end
equal(API.Professions()[1].supply, nil, "unconfigured status is cached as absent")
-- A direct configuration is visible to the next read: the API's cache drops in the call that made it, not on a
-- later frame after a publication.
equal(API.Professions()[1].nextAction, nil, "an unconfigured profession publishes no next action")
assert(ns.RouteDemand.ConfigureAdaptiveSupply(197, function()
	return nil
end, 0.5))
local directAction = API.Professions()[1].nextAction
equal(directAction and directAction.kind, "unsupported", "a direct adaptive configure reaches the next API read")
assert(ns.RouteDemand.ConfigureSupply(197, nil))
equal(API.Professions()[1].nextAction, nil, "removing a direct configure reaches the next API read")
ns.RouteDemand.ConfigureSupply(197, function()
	return nil
end, 0.9)
PolicyFrame()
equal(
	API.Professions()[1].supply.status,
	"unknown",
	"rejected source reader publishes status without unrelated invalidation"
)
ns.RouteDemand.ConfigureSupply(197, nil)
equal(API.Professions()[1].supply, nil, "removing a rejected configuration removes its public status")
local unresolved = Policy()
unresolved.assumptions = {}
for index = 1, 100 do
	unresolved.assumptions[index] = Policy().assumptions[1]
end
unresolved.sources[1].priceLaw = "unestablished"
local unresolvedJob = ns.RouteDemand.SelectSupply(Current(), unresolved, 0.9)
equal(API.Professions()[1].supply.status, "calculating", "new selection publishes calculating status immediately")
for _ = 1, 100 do
	PolicyFrame()
end
equal(unresolvedJob.result.status, "unknown", "invalid law eventually rejects asynchronous work")
equal(API.Professions()[1].supply.status, "unknown", "terminal unknown replaces the cached calculating status")
unresolvedJob:Cancel()
equal(API.Professions()[1].supply, nil, "cancelling an unpublished selection removes public status")

local free = Policy()
free.sources[2] = nil
free.sources[1].moneyCopper, free.sources[1].costs = 0, {}
free.stock.S, free.tokenValues = "unlimited", {}
free.initialVisitCosts.V, free.refillVisitCosts.V = 0, 5
local freeJob = ns.RouteDemand.SelectSupply(Current(), free, 0.9)
for _ = 1, 100 do
	PolicyFrame()
end
equal(freeJob.result.status, "unattained", "free initial acquisitions expose nonattainment through the real job")
local freePublic = API.Professions()[1].supply
equal(freePublic.status, "unattained", "public API preserves the distinct nonattainment status")
equal(freePublic.objectiveInfimumUpper, 0, "public API publishes the proved infimum")
equal(freePublic.orders, nil, "public nonattainment has no invented finite orders")
equal(ns.RouteDemand.Supply(Current()), nil, "nonattainment never publishes a selectable budget")
freePublic.nonattainment.refillUnits = 999
equal(API.Professions()[1].supply.nonattainment.refillUnits, 2, "public proof parameters are owned")
freeJob:Cancel()

local contract = Policy()
contract.stock.S = 2
local declaredStock = 2
local available = true
equal(
	ns.RouteDemand.ConfigureSupply(197, function()
		return Policy()
	end, 0 / 0),
	false,
	"NaN is not a configured coverage target"
)
local ok = ns.RouteDemand.ConfigureSupply(197, function()
	if not available then
		return nil
	end
	local fresh = Policy()
	fresh.stock.S = declaredStock
	return fresh
end, 0.9)
equal(ok, true, "explicit profession policy accepted")
contract.stock.S = 0
local supply = Published()
equal(supply.items[10], 4, "configured input is owned and selects whole bundle budget")
local entry = API.Professions()[1]
equal(entry.recipeEvidence.status, "unsupported", "native production law absent without alpha")
equal(entry.recipeEvidence.missing[1].code, "recipe-production-law-missing", "recipe evidence stable missing code")
equal(entry.sourceEvidence.status, "unavailable", "default production owner reports missing evidence without alpha")
equal(entry.sourceEvidence.missing[1].code, "merchant-window-unavailable", "default evidence keeps structured reasons")
equal(entry.supply.sourceRevision, 7, "public certificate retains source revision")
equal(entry.supply.assumptions[1].observedAt, 42, "public certificate retains dated provenance")
entry.supply.assumptions[1].scope = "mutated"
equal(API.Professions()[1].supply.assumptions[1].scope, "this run", "public evidence is recursively owned")
local selectedStep = entry.steps[1]
equal(entry.steps[3].itemID, 90, "conditional plan retains missing tool acquisition")
equal(entry.steps[3].cost, 7, "missing tool retains its independent display price")
local tool
for _, row in ipairs(API.ShoppingList(197)[1].items) do
	if row.itemID == 90 then
		tool = row
	end
end
equal(tool.price, 7, "conditional shopping preserves missing tool pricing")
equal(tool.acquisitions, nil, "tool has no invented conditional source certificate")
equal(
	selectedStep.detail:find("Requires 1 item:20", 1, true) ~= nil,
	true,
	"step visibly includes selected token requirements"
)
equal(
	ns.AcquisitionPayments({ { costs = { ["item:20"] = 2, ["currency:9"] = 3 } } }),
	"3 currency:9, 2 item:20",
	"display keeps item and currency requirements distinct when names are unknown"
)

equal(selectedStep.acquisition.costs["item:20"], 1, "API preserves selected token payment")
equal(ns.RouteDemand.Vendors(ns.RouteReagents(Current())[1], true)[1], 123, "shopping navigation keeps selected NPC")
equal(
	#ns.RouteDemand.Vendors({ itemID = 10, source = "vendor", acquisitions = {} }),
	0,
	"empty selected offers forbid nearest-vendor fallback"
)
equal(selectedStep.acquisition.offerID, "selected-token-offer", "API keeps selected offer, without price fallback")
equal(selectedStep.acquisition.npcID, 123, "API keeps selected NPC instead of nearest vendor")
equal(selectedStep.cost, 3, "API quotes one selected bundle, not display unit price")
local shopping = API.ShoppingList(197)[1].items[1]
equal(
	shopping.acquisitions[1].offerID,
	selectedStep.acquisition.offerID,
	"shopping and steps retain same selected offer"
)
equal(shopping.cost, 6, "shopping adds exact selected transactions instead of repricing units")
equal(shopping.price, nil, "selected bundles do not invent a per-unit purchase quote")
selectedStep.acquisition.costs["item:999"] = 99
equal(API.Professions()[1].steps[1].acquisition.costs["item:999"], nil, "nested public requirements are owned copies")
shopping.acquisitions[1].vendor = "mutated"
equal(API.ShoppingList(197)[1].items[1].acquisitions[1].vendor, "V", "shopping selected records are owned copies")

equal(entry.reagents[1].need, 4, "API materials share the shopping certificate")
local acquired = 0
for _, step in ipairs(entry.steps) do
	if step.itemID == 10 and step.kind ~= "craft" then
		acquired = acquired + step.count
	end
end
equal(acquired, 4, "API steps acquire the shared starting budget exactly once")
local firstJob = supply.job
declaredStock = 1
c.bags[10], c.money = 2, 3
c.Fire("BAG_UPDATE_DELAYED")
equal(ns.RouteDemand.Supply(Current()), nil, "purchase revokes the old quantities immediately")
supply = Published()
equal(firstJob.result.status, "cancelled", "old certificate stays cancelled")
equal(supply.have[10], 2, "automatic reselection reads newly bought inventory")
equal(supply.items[10], 4, "new selection retains only its fresh total target")
entry = API.Professions()[1]
equal(entry.reagents[1].have, 2, "API holdings use the same new snapshot")
acquired = 0
for _, step in ipairs(entry.steps) do
	if step.itemID == 10 and step.kind ~= "craft" then
		acquired = acquired + step.count
	end
end
equal(acquired, 2, "automatic reselection does not ask to buy the first bundle twice")
c.professions[1].rank = 2
c.Fire("SKILL_LINES_CHANGED")
supply = Published()
equal(next(supply.items), nil, "skill progress reselects only the unfinished route")
equal(#API.Professions()[1].reagents, 0, "completed route has no inherited material order")
available = false
c.Fire("PLAYER_MONEY")
Frame()
equal(Current().supply.job.result.status, "unknown", "missing fresh source law never replenishes old finite stock")
equal(ns.RouteDemand.Supply(Current()), nil, "unknown fresh source cannot publish counts")
ns.RouteDemand.ConfigureSupply(197, nil)
equal(ns.RouteDemand.Supply(Current()), nil, "removing policy revokes canonical counts")
equal(Current().supply, nil, "removed policy clears its unpublished status")

-- Both offers are needed: their distinct finite pools each permit one bundle.
c.professions[1].rank, c.bags[10], c.bags[99], c.money = 1, 0, 1, 6
ns.RouteDemand.ConfigureSupply(197, function()
	local fresh = Policy()
	fresh.stock.T = 1
	fresh.sources[2].stockKey = "T"
	return fresh
end, 0.9)
c.Fire("SKILL_LINES_CHANGED")
supply = Published()
equal(#supply.acquisitions, 2, "both distinct offers selected for whole-route coverage")
local combined = API.ShoppingList(197)[1].items[1]
equal(#combined.acquisitions, 2, "shopping retains both offers for one product")
local vendors = ns.RouteDemand.Vendors(combined, true)
equal(vendors[1], 123, "first selected NPC retained")
equal(vendors[2], 456, "second selected NPC retained")
entry = API.Professions()[1]
equal(entry.steps[1].acquisition.npcID, 123, "first selected transaction retained in steps")
equal(entry.steps[2].acquisition.npcID, 456, "second selected transaction retained in steps")
equal(combined.need, 5, "different selected bundle sizes remain exact")
equal(combined.cost, 4, "two selected money components remain exact")
ns.NPCLocation(123)
ns.NPCLocation(456)
c.Advance(0)
local routed
c.G.ShortestPathForever = { API = {
	NavigateRoute = function(_, stops)
		routed = stops
		return true
	end,
} }
equal(ns.ShoppingTrip(197), true, "actual shopping trip consumes selected offers")
equal(#routed, 2, "trip includes both selected NPCs")
equal(routed[1].title:find("Selected First", 1, true) ~= nil, true, "trip keeps first selected vendor")
equal(
	routed[2].title:find("Selected Second", 1, true) ~= nil,
	true,
	"trip keeps second selected vendor instead of nearest alternative"
)
c.G.ShortestPathForever = nil

ns.RouteDemand.ConfigureSupply(197, nil)

-- Default evidence reporting must revoke its cached answer without any policy.
c.npc = { id = 123 }
c.merchant = {}
for _, reagent in ipairs(API.Professions()[1].reagents) do
	c.merchant[#c.merchant + 1] = {
		itemID = reagent.itemID,
		price = 1,
		stackCount = 1,
		numAvailable = 8,
		hasExtendedCost = false,
	}
end
c.Fire("MERCHANT_SHOW")
local function Law(value)
	return { value = value, provenance = "synthetic finite law", scope = "this fixture run" }
end
local function DeclareAll(version)
	for _, offer in ipairs(ns.MerchantOffers.current.offers) do
		equal(
			ns.SupplySources.Declare(offer, version, {
				access = Law(true),
				price = Law("fixed"),
				vendor = Law("V"),
				ceiling = Law(1),
				stock = Law({ key = tostring(offer.itemID), perBundle = 1, available = 8, law = "finite-no-restock" }),
				initialVisit = Law(0),
				refillVisit = Law(1),
				tokenValues = {},
			}),
			true,
			"synthetic production offer laws declared"
		)
	end
end
for version, event in ipairs({
	"PLAYER_MONEY",
	"CURRENCY_DISPLAY_UPDATE",
	"BANKFRAME_OPENED",
	"PLAYERBANKSLOTS_CHANGED",
	"BANKFRAME_CLOSED",
}) do
	DeclareAll(version)
	local evidence = API.Professions()[1].sourceEvidence
	equal(evidence.status, "conditional", "default API caches current-window laws without a policy before " .. event)
	c.Fire(event)
	local revoked = API.Professions()[1].sourceEvidence
	equal(revoked.status, "unavailable", event .. " revokes cached default evidence without a policy")
	equal(revoked.missing[1].code, "reconciliation-required", "revocation retains the missing stock-law reason")
	equal(revoked.sourceRevision > evidence.sourceRevision, true, "law invalidation advances evidence revision")
end
Client.report("Supply API")
