local Client = dofile("tests/client.lua")
local c = Client.load({
	boot = false,
	saved = { routeTargets = { [197] = 9, [164] = 5 }, trackedProfessions = { [197] = true, [164] = true } },
	data = {
		Thresholds = { [1] = { 0, 20, 20, 20 }, [2] = { 0, 20, 20, 20 } },
		RecipeData = {
			[2] = {
				skillLine = 164,
				output = { itemID = 12, quantity = 1 },
				reagents = { { itemID = 10, quantity = 1 } },
			},
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
c.known[2], c.spells[2] = true, "Synthetic Bar"
c.professions[2] = { name = "Blacksmithing", icon = 1, rank = 1, max = 75, id = 8198 }
c.schematics = { [1] = { reagents = { { 10, 1 } }, output = 11 }, [2] = { reagents = { { 10, 1 } }, output = 12 } }
c.bags[10], c.bags[30], c.money = 1, 2, 0
c.items[11] = { sell = 0 }
c.items[12] = { sell = 0 }
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
local native = c.G.C_Item.GetItemCount
c.G.C_Item.GetItemCount = function(id, bank)
	if id == 10 then
		return bank and 11 or 1
	end
	return native(id)
end
policy.sources[1] = {
	offerID = "bag-product",
	itemID = 10,
	bundleUnits = 3,
	moneyCopper = 0,
	costs = {},
	maxBundles = 1,
	stockKey = "S",
	stockPerBundle = 1,
	vendor = "V",
	access = true,
	priceLaw = "fixed",
	futureDelivery = { chance = 1, payOnFailure = true },
}
policy.terminalCarry = { ["item:10"] = 0 }
c.merchant = { { itemID = 10, name = "Synthetic Reagent", price = 1, stackCount = 1 } }
c.Fire("MERCHANT_SHOW")
c.Advance(0)
ns.RouteDemand.ConfigureAdaptiveSupply(164, function()
	return { inventoryScope = "bags-only", policy = policy }
end, 1)
local function Frame()
	for _, frame in ipairs(c.frames) do
		local callback = frame.scripts.OnUpdate
		if callback and debug.getinfo(callback, "S").source:find("Core/RouteDemand.lua", 1, true) then
			callback(frame, 0)
		end
	end
end
local function AdaptivePlan()
	return ns.PlanRoute(assert(ns.RouteProfessions()[164]))
end
for _ = 1, 10000 do
	Frame()
	if ns.RouteDemand.Supply(AdaptivePlan()) then
		break
	end
end
assert(ns.RouteDemand.Supply(AdaptivePlan()), "actual adaptive plan must publish")
local tracked = ns.TrackedNeeds()
equal(#tracked, 2, "both actual professions tracked")
local bySkill = {}
for _, entry in ipairs(tracked) do
	bySkill[entry.plan.profession.skillLine] = entry
end
equal(bySkill[197].items[1].need, 8, "ordinary route needs eight")
equal(bySkill[164].items[1].need, 4, "adaptive route gross target four")
equal(ns.RouteDemand.Held(bySkill[197].items[1]), 11, "ordinary route counts bags and bank")
equal(ns.RouteDemand.Held(bySkill[164].items[1]), 1, "adaptive route counts bags only")
-- Reverse the actual tracked array, without replacing any producer.
for _, first in ipairs({ 197, 164 }) do
	tracked[1], tracked[2] = bySkill[first], bySkill[first == 197 and 164 or 197]
	ns.Changed("supply")
	c.Advance(0)
	local tab = rawget(c.G, "SkillUpForeverMerchantTab")
	assert(tab and tab.shown, "mixed inventory shortage keeps merchant tab visible")
	tab.scripts.OnClick(tab)
	local page = rawget(c.G, "SkillUpForeverMerchantPage")
	equal(page.Items[1].price:GetText(), "3c", "merchant satisfies total and bags constraints in either order")
	local missing = ns.RouteDemand.Shortfalls(tracked)
	equal(missing[10], 3, "shared bag stock counted once in either order")
end
-- Missing certified coordinates suppress a shared count rather than using display inventory.
local held = bySkill[164].items[1].have
bySkill[164].items[1].have = nil
local missing = ns.RouteDemand.Shortfalls(tracked)
equal(missing[10], nil, "unknown holdings provide no aggregate purchase count")
bySkill[164].items[1].have = held
print("adaptive mixed scope: passed")
