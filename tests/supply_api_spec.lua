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
local contract = Policy()
contract.stock.S = 2
local declaredStock = 2
local available = true
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
equal(Current().supply.job.result.status, "cancelled", "removed policy job is cancelled")

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
Client.report("Supply API")
