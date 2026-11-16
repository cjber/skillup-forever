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

c.bags[10] = 0
local nativeCount = c.G.C_Item.GetItemCount
c.G.C_Item.GetItemCount = function(id, bank)
	if id == 10 then
		return bank and 99 or 0
	end
	return nativeCount(id, bank)
end
policy.sources[1].itemID = 10
policy.sources[1].bundleUnits = 3
policy.sources[1].access = true
policy.terminalCarry = { ["item:10"] = 0 }
ns.db.reagentTooltip = "full"
ns.db.showTooltipRoute = true
local lines = {}
c.G.GameTooltip_AddColoredLine = function(_, text)
	lines[#lines + 1] = text
end
local post = c.postCalls[c.G.Enum.TooltipDataType.Item][1]
local function Hover()
	lines = {}
	post({
		IsForbidden = function()
			return false
		end,
		HookScript = function() end,
		AddDoubleLine = function() end,
	}, { id = 10 })
	return table.concat(lines, " | ")
end
assert(Hover():find("1/1", 1, true), "legacy route uses bank stock")
ns.RouteDemand.ConfigureAdaptiveSupply(197, Reader, 1)
local supply = Published()
equal(supply.have[10], 0, "certificate excludes bank stock")
equal(supply.items[10], 3, "certificate selects three units")
assert(Hover():find("0/3", 1, true), "publication refreshes cached tooltip route")
supply.job:Cancel()
assert(Hover():find("1/1", 1, true), "revocation refreshes cached tooltip route")
print("tooltip publication: passed")
