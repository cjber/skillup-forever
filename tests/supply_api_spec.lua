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
})
c.professions = { { name = "Tailoring", icon = 1, rank = 1, max = 75, id = 8197 } }
c.known[1] = true
c.spells[1] = "Synthetic Cloth"
c.items[11] = { sell = 0 }
c.schematics = { [1] = { reagents = { { 10, 1 } }, output = 11 } }
c.money = 6
c.auction[10] = 3
c.Boot()
local ns, API = c.ns, c.G.SkillUpForever.API
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
Client.report("Supply API")
