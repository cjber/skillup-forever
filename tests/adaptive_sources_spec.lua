-- Production seam: native merchant events, source ownership, shared snapshot and publication.
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
c.items[10], c.items[11], c.items[20] = { name = "Reagent" }, { sell = 0 }, { name = "Token" }
c.bags[10], c.bags[20], c.money = 0, 2, 5
c.G.C_CurrencyInfo.GetCurrencyInfo = function()
	return { quantity = 1 }
end
c.G.CanAffordMerchantItem = function()
	return false
end -- dated affordability is not fixed access
c.merchant = {
	{
		itemID = 10,
		price = 3,
		stackCount = 2,
		numAvailable = 2,
		isPurchasable = true,
		hasExtendedCost = true,
		costs = {
			{ 1, 1, "item:20" },
			{ 1, 1, "currency:20", "Coin" },
			{ 1, 1, "item:20" },
			{
				1,
				1,
				"currency:20",
				"Coin",
			},
		},
	},
	{ itemID = 10, price = 6, stackCount = 1, numAvailable = 1, isPurchasable = true, hasExtendedCost = false },
}
-- The complete four-slot quote needs two currency units.
c.G.C_CurrencyInfo.GetCurrencyInfo = function()
	return { quantity = 2 }
end
c.Boot()
c.Fire("MERCHANT_SHOW")
local ns, equal = c.ns, Client.equal
local owner = ns.SupplySources
local offers = assert(ns.MerchantOffers.current).offers
local function Law(value)
	return { value = value, provenance = "explicit synthetic assumption", scope = "current finite window" }
end
local function Laws(index)
	return {
		access = Law(true),
		price = Law("fixed"),
		vendor = Law("V"),
		ceiling = Law(1),
		stock = Law({
			key = "S" .. index,
			available = 1,
			perBundle = 1,
			law = "finite-no-restock",
			unit = "bundle-opportunity",
			observedUnits = "items",
		}),
		initialDelivery = Law("certain"),
		futureDelivery = Law({ chance = 1, payOnFailure = true }),
	}
end
local economics = {
	initialVisitMoney = Law({ V = 2 }),
	refillVisitMoney = Law({ V = 2 }),
	initialVisitValue = Law({ V = 0 }),
	refillVisitValue = Law({ V = 0 }),
	tokenValues = Law({ ["item:20"] = 0, ["currency:20"] = 0 }),
	terminalCarry = Law({ ["item:10"] = 0, ["item:20"] = 0, ["currency:20"] = 0 }),
	failureLoss = Law(100),
}
local options = { workLimit = 1000000, stateLimit = 1000, coordinateLimit = 32, limbLimit = 256 }
-- First RED reaches the missing production declaration path after actual TOC events.
assert(owner.DeclareAdaptive(offers[1], 1, Laws(1)))
local incomplete = owner.InspectAdaptive({ [10] = true }, options.workLimit)
equal(incomplete.status, "unavailable", "undeclared competing offer prevents complete universe")
assert(owner.DeclareAdaptive(offers[2], 1, Laws(2)))
assert(owner.DeclareEconomics(1, economics))
economics.initialVisitMoney.value.V = 999
local owned = assert(owner.ReadAdaptive(options, { [10] = true }))
equal(owned.policy.initialVisitMoney.V, 2, "economics owns declared maps")
owned.policy.sources[1].costs["item:20"] = 99
equal(
	assert(owner.ReadAdaptive(options, { [10] = true })).policy.sources[1].costs["item:20"],
	2,
	"read requests own typed costs"
)
equal(owner.DeclareEconomics(1, economics), false, "economic revisions strictly increase")
equal(owner.ConfigureAdaptive(197, 1, options, { [10] = true }), true, "production reader configured")
local function Current()
	return ns.PlanRoute(assert(ns.RouteProfessions()[197]))
end
local function Frame()
	for _, frame in ipairs(c.frames) do
		local fn = frame.scripts.OnUpdate
		if fn and debug.getinfo(fn, "S").source:find("Core/RouteDemand.lua", 1, true) then
			fn(frame, 0)
		end
	end
end
local function Settled()
	for _ = 1, 10000 do
		Frame()
		local supply = Current().supply
		if supply and supply.job.result.status ~= "calculating" then
			return supply
		end
	end
	error("source publication did not settle")
end
local supply = Settled()
equal(supply.result.status, "complete", "native wallet five funds three plus fare two")
equal(supply.result.service, "adaptive-finite", "existing adaptive publication")
equal(supply.result.inventoryScope, "bags-only", "native resource scope")
equal(supply.result.sourceRevision, 3, "two source laws and economic revision retained")
local poolEvidence, economicEvidence
for _, row in ipairs(supply.result.assumptions) do
	if row.offerID == offers[1].session .. ":1" and row.field == "stock" then
		poolEvidence = row
	end
	if row.offerID == "economics" and row.field == "initialVisitMoney" then
		economicEvidence = row
	end
end
equal(poolEvidence.revision, 1, "finite pool declaration revision retained")
equal(poolEvidence.session, offers[1].session, "pool evidence binds observed session")
equal(poolEvidence.index, 1, "pool evidence binds exact slot")
equal(economicEvidence.revision, 1, "economic revision retained independently")
equal(supply.result.quantities[1], 1, "first competing offer selected")
equal(supply.result.quantities[2], 0, "second competing offer retained but unaffordable")
local sources = supply.result.certificate.sources
equal(#sources, 2, "all competing offers retained")
equal(sources[1].offerID, offers[1].session .. ":1", "exact observed offer identity")
equal(sources[1].costs["item:20"], 2, "duplicate typed item slots summed")
equal(sources[1].costs["currency:20"], 2, "same-id currency separate")
equal(supply.result.certificate.laws.initialVisitMoney.V, 2, "fare debits shared wallet")
local prior = supply.job
c.money = 4
c.Fire("PLAYER_MONEY")
equal(prior.result.status, "cancelled", "completed publication revoked immediately")
equal(
	owner.InspectAdaptive({ [10] = true }, 1000000).status,
	"unavailable",
	"resource event requires explicit pool reconciliation"
)
equal(owner.DeclareAdaptive(offers[1], 1, Laws(1)), false, "same revision never replenishes")
assert(owner.DeclareAdaptive(offers[1], 2, Laws(1)))
assert(owner.DeclareAdaptive(offers[2], 2, Laws(2)))
supply = Settled()
equal(supply.job.result.status, "infeasible", "wallet four cannot fund quoted three plus fare two")
equal(ns.RouteDemand.Supply(Current()), nil, "infeasible has no published counts")
equal(owner.ConfigureAdaptive(197, nil, options, { [10] = true }), false, "no default alpha")
equal(owner.ConfigureAdaptive(197, 0, options, { [10] = true }), true, "explicit zero accepted")
equal(Settled().result.status, "complete", "zero permits empty initial basket")
-- Reader dispatch and public getters do not read balances or compile declarations.
local reads = 0
local count = c.G.C_Item.GetItemCount
c.G.C_Item.GetItemCount = function(...)
	reads = reads + 1
	return count(...)
end
for _ = 1, 3 do
	c.G.SkillUpForever.API.Professions()
	c.G.SkillUpForever.API.ShoppingList()
end
equal(reads, 0, "getters perform no native balance reads")
c.G.C_Item.GetItemCount = count
-- Source/economic revisions revoke complete and active publication through Changes.
local previous = Current().supply.job
local revised = Laws(1)
revised.futureDelivery.value.chance = 0.5
assert(owner.DeclareAdaptive(offers[1], 3, revised))
equal(previous.result.status, "cancelled", "source revision revokes publication")
Frame()
local active = Current().supply.job
economics.initialVisitMoney.value.V = 2
assert(owner.DeclareEconomics(2, economics))
equal(active.result.status, "cancelled", "economic revision cancels active snapshot")
Settled()
-- No typed resource can be paid using acquired products from the same basket.
c.money, c.bags[20] = 5, 1
c.Fire("BAG_UPDATE_DELAYED")
assert(owner.DeclareAdaptive(offers[1], 4, Laws(1)))
assert(owner.DeclareAdaptive(offers[2], 3, Laws(2)))
assert(owner.ConfigureAdaptive(197, 1, options, { [10] = true }))
equal(Settled().job.result.status, "infeasible", "native item payment must be affordable before action")
-- Buying item tokens in the same atomic initial basket cannot finance another order.
c.bags[20] = 0
c.merchant[3] =
	{ itemID = 20, price = 0, stackCount = 2, numAvailable = 2, isPurchasable = true, hasExtendedCost = false }
c.Fire("MERCHANT_UPDATE")
offers = ns.MerchantOffers.current.offers
assert(owner.DeclareAdaptive(offers[1], 5, Laws(1)))
assert(owner.DeclareAdaptive(offers[2], 4, Laws(2)))
assert(owner.DeclareAdaptive(offers[3], 1, Laws(3)))
assert(owner.ConfigureAdaptive(197, 1, options, { [10] = true, [20] = true }))
equal(Settled().job.result.status, "infeasible", "acquired tokens cannot fund same-basket purchase")
local malformed = Laws(1)
malformed.stock.value.observedUnits = nil
local accepted, reasons = owner.DeclareAdaptive(offers[1], 6, malformed)
equal(accepted, false, "no inferred stock units")
equal(reasons[1].code, "stock-unit-law-missing", "precise stock-unit failure")
malformed = Laws(1)
malformed.futureDelivery.value.chance = nil
equal(owner.DeclareAdaptive(offers[1], 6, malformed), false, "no default future probability")
local request = assert(owner.ReadAdaptive(options, { [10] = true }))
equal(request.policy.sources[1].futureDelivery.chance, 1, "invalid replacement preserves valid law")
local shared = Laws(2)
shared.stock.value.key, shared.stock.value.unit = "S1", "different-opportunity"
assert(owner.DeclareAdaptive(offers[2], 5, shared))
request, reasons = owner.ReadAdaptive(options, { [10] = true })
equal(request, nil, "shared pool unit conflict prevents solving")
equal(reasons[1].code, "inconsistent-shared-pool-law", "shared identity includes unit law")
assert(owner.DeclareAdaptive(offers[2], 6, Laws(2)))
-- Compose the provider with the existing declared recipe adapter, including a neutral auxiliary.
local schemas = {}
for id = 1, 2 do
	local input, output = id == 1 and 10 or 30, id == 1 and 11 or 31
	c.known[id], c.spells[id] = true, "Synthetic recipe " .. id
	schemas[id] = {
		recipeID = id,
		isRecraft = false,
		quantityMin = 1,
		quantityMax = 1,
		outputItemID = output,
		reagentSlotSchematics = {
			{
				reagentType = 0,
				quantityRequired = 1,
				reagents = { { itemID = input } },
				slotIndex = 1,
				dataSlotIndex = 1,
				required = true,
				slotInfo = { mcrSlotID = 9, requiredSkillRank = 0 },
			},
		},
	}
end
c.G.C_TradeSkillUI.GetRecipeSchematic = function(id)
	return schemas[id]
end
c.G.C_TradeSkillUI.GetProfessionInfoByRecipeID = function()
	return { professionID = 8197, skillLevel = 1, skillModifier = 0, maxSkillLevel = 75 }
end
local declaration = {
	version = "crafted-adapter-v1",
	skillGainLaw = "whole-successful-count-bounded-by-rank",
	universeComplete = true,
	recipes = {},
	prerequisites = {},
	allocations = {},
	eligibility = {},
}
for id = 1, 2 do
	local input, output = id == 1 and 10 or 30, id == 1 and 11 or 31
	local observed = assert(ns.RecipeEvidence.Observe(id, "synthetic-allocation-" .. id, 10000))
	declaration.recipes[id] = {
		recipeID = id,
		professionID = observed.professionID,
		role = id == 1 and "main" or "auxiliary",
		available = true,
		scope = "explicit synthetic production",
		skillEffect = id == 1 and "route" or "neutral",
		productionLaw = "deterministic-completed-attempt",
		use = { [input] = 1 },
		produce = { [output] = 1 },
		evidence = {
			revision = observed.revision,
			allocation = observed.allocation,
			clientBuild = observed.clientBuild,
		},
	}
	declaration.prerequisites[id] = { rank = true, training = true, tools = true, station = true, access = true }
	declaration.allocations[id] = {
		identity = observed.allocation,
		complete = true,
		slots = { { slotIndex = 1, dataSlotIndex = 1, itemID = input, quantity = 1 } },
	}
	declaration.eligibility[id] = { fromSkill = 0, toSkill = 75 }
end
assert(ns.RecipeEvidence.Declare(197, declaration, 10000))
c.bags[10], c.bags[30] = 1, 1
c.Fire("BAG_UPDATE_DELAYED")
assert(owner.DeclareAdaptive(offers[1], 7, Laws(1)))
assert(owner.DeclareAdaptive(offers[2], 7, Laws(2)))
assert(owner.DeclareAdaptive(offers[3], 2, Laws(3)))
for _, key in ipairs({ "item:11", "item:30", "item:31" }) do
	economics.terminalCarry.value[key] = 0
end
assert(owner.DeclareEconomics(3, economics))
local token = { version = "crafted-adapter-v1", revision = ns.RecipeEvidence.Revision(), skillLine = 197 }
assert(owner.ConfigureAdaptive(197, 1, options, { [10] = true, [20] = true }, token))
supply = Settled()
assert(supply.job.result.status == "complete", "crafted composition: " .. tostring(supply.job.result.reasons[1]))
equal(supply.result.certificate.craftedVersion, "crafted-deterministic-v1", "existing recipe adapter owns compilation")
equal(supply.result.certificate.recipes[2].role, "auxiliary", "neutral auxiliary retained")
equal(supply.have[30], 1, "auxiliary input native bags captured")
equal(supply.have[31], 0, "auxiliary output native bags captured")
local function Conflict(field, value, expected)
	local original = c.merchant[1][field]
	c.merchant[1][field] = value
	c.Fire("MERCHANT_UPDATE")
	local current = ns.MerchantOffers.current.offers[1]
	local ok, why = owner.DeclareAdaptive(current, 10, Laws(1))
	equal(ok, false, "native contradiction rejected: " .. field)
	equal(why[1].code, expected, "precise native conflict: " .. field)
	c.merchant[1][field] = original
	c.Fire("MERCHANT_UPDATE")
end
Conflict("isPurchasable", false, "native-access-conflict")
Conflict("numAvailable", 0, "native-stock-conflict")
Conflict("numAvailable", -1, "native-stock-unit-conflict")
c.G.GetMerchantItemMaxStack = function()
	return 0
end
c.Fire("MERCHANT_UPDATE")
local ok, why = owner.DeclareAdaptive(ns.MerchantOffers.current.offers[1], 10, Laws(1))
equal(ok, false, "zero native ceiling cannot admit positive transaction")
equal(why[1].code, "native-ceiling-conflict", "native item-unit ceiling enforced")
c.Fire("MERCHANT_CLOSED")
equal(
	owner.InspectAdaptive({ [10] = true }, options.workLimit).missing[1].code,
	"merchant-window-unavailable",
	"closed window revokes source scope"
)
ns.RouteDemand.ConfigureAdaptiveSupply(197, nil)
print("adaptive_sources_spec: production seam passed")
