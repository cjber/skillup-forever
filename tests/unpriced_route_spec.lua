-- Run from the repository root: luajit tests/unpriced_route_spec.lua
-- #855: with Buy reagents on and no auction listing seen for a route's reagents, the route went empty: every
-- recipe needing one was left out. A reagent nobody has priced yet stays on the route as a price unknown, ranked
-- after every priced recipe, in the Reagents list and the Auctionator list, so a search can price it (#559).
local Client = dofile("tests/client.lua")
local equal = Client.equal

local LEATHERWORKING, SKINNING = 165, 393
local LIGHT_LEATHER, LIGHT_HIDE, CURED_LIGHT_HIDE = 2318, 783, 4231
-- The patterns a Leatherworking character has by 54.
local KNOWN = { 2149, 2152, 2153, 2158, 2159, 2160, 2162, 2881, 3753, 3756, 3816, 3817, 9065, 9068, 2163, 2164 }

---@param mode "auction"|"gather"
---@param auction table<integer, number>?
local function Loaded(mode, auction)
	local c = Client.load({ auctionator = true })
	c.level = 20
	c.player.faction = "Alliance"
	c.professions = {
		{ name = "Leatherworking", id = LEATHERWORKING, rank = 54, max = 75 },
		{ name = "Skinning", id = SKINNING, rank = 80, max = 150 },
	}
	for _, recipeID in ipairs(KNOWN) do
		c.known[recipeID] = true
	end
	for itemID, copper in pairs(auction or {}) do
		c.auction[itemID] = copper
	end
	c.AuctionatorScan()
	c.ns.SetCollectMode(mode)
	c.ns.db.routeTargets[LEATHERWORKING] = 79
	c.ns.Changed("target")
	return c
end

local PROFESSION = {
	skillLine = LEATHERWORKING,
	name = "Leatherworking",
	base = 54,
	modifier = 0,
	skill = 54,
	max = 75,
	capped = false,
}

local function Reagent(items, itemID)
	for _, item in ipairs(items) do
		if item.itemID == itemID then
			return item
		end
	end
end

-- Buy reagents on, nothing scanned: the route still reaches its target, every unscanned reagent is listed for the
-- Auctionator search, and the header's total says it is incomplete.
local unscanned = Loaded("auction")
local plan = unscanned.ns.PlanRoute(PROFESSION)
equal(#plan.crafts > 0, true, "an unscanned route still has crafts")
equal(plan.reached, 79, "and reaches its target")
equal(unscanned.ns.RouteBlocked(plan), nil, "so it is not blocked for want of prices")
equal(unscanned.ns.PlanMoney(plan).unknown > 0, true, "and its money total says a price is missing")
local reagents = unscanned.ns.RouteReagents(plan)
equal(#reagents > 0, true, "the Reagents list holds what the route needs")
local unknownCount = 0
for _, item in ipairs(reagents) do
	if item.source == "unknown" or item.source == "auction" then
		unknownCount = unknownCount + 1
	end
end
equal(unknownCount > 0, true, "with each unscanned reagent as an auction search")
local leatherOrHide = Reagent(reagents, LIGHT_LEATHER)
	or Reagent(reagents, LIGHT_HIDE)
	or Reagent(reagents, CURED_LIGHT_HIDE)
equal(leatherOrHide ~= nil and leatherOrHide.need > 0, true, "Light Leather or Light Hide is among them")
-- The page names only recipes it left out: a step on the route is not one, so no "left out" warning or notice
-- speaks of the steps it shows, and no reagent is listed both with the route's and among the unpriced.
local onRoute = {}
for _, craft in ipairs(plan.crafts) do
	onRoute[craft.recipeID] = true
end
for _, recipeID in ipairs(plan.unpricedRecipes) do
	equal(onRoute[recipeID], nil, "a recipe counted as left out is not on the route: " .. recipeID)
end
local listed = {}
for _, item in ipairs(reagents) do
	listed[item.itemID] = true
end
for _, itemID in ipairs(unscanned.ns.UnpricedReagents(plan)) do
	equal(listed[itemID], nil, "an unpriced reagent is listed once: " .. itemID)
end
if plan.unpriced == 0 then
	equal(unscanned.ns.RouteNotice(plan), nil, "with nothing left out, no notice says recipes were left out")
end

-- The scan that prices them replans: the same route now has known costs and nothing missing.
for _, itemID in ipairs({ LIGHT_LEATHER, LIGHT_HIDE, CURED_LIGHT_HIDE, 2320, 4289, 2321, 2319, 4234 }) do
	unscanned.auction[itemID] = 25
end
-- Auctionator's database-update callback alone replans: SkillUp registers for it, nothing else is called.
unscanned.AuctionatorScan()
local priced = unscanned.ns.PlanRoute(PROFESSION)
equal(priced.reached, 79, "the priced route reaches its target")
equal(unscanned.ns.PlanMoney(priced).unknown, 0, "with every price known once scanned")

-- Buy reagents off: the skinner farms Light Leather and Light Hide, and the route plans from them.
local farmed = Loaded("gather")
local farmPlan = farmed.ns.PlanRoute(PROFESSION)
equal(#farmPlan.crafts > 0, true, "a gathering route has crafts")
equal(farmPlan.reached, 79, "and reaches its target")

-- Partial prices: a priced recipe still ranks before an unknown one wherever it gains skill, so a scan of some
-- reagents never makes the route lean on the unpriced ones.
local partial = Loaded("auction", { [LIGHT_LEATHER] = 25, [2320] = 10 })
local partialPlan = partial.ns.PlanRoute(PROFESSION)
equal(partialPlan.reached, 79, "a partly priced route reaches its target")
for _, craft in ipairs(partialPlan.crafts) do
	local cost = partial.ns.StepCost(craft.recipeID, 1)
	equal(cost ~= nil, true, "every craft it picks is a priced recipe: " .. tostring(craft.recipeID))
end

-- Training: a learned recipe waiting on an auction price against a priced recipe the trainer teaches, equal in
-- thresholds and reach. The waiting steps count as nothing in the route's money, so savings alone would keep them;
-- the priced recipe is trained instead, because a known cost beats an unknown one.
local SMITHING, WAITING, TRAINED, MARKET_GOOD, VENDOR_GOOD = 164, 300, 301, 3001, 3002
local trainer = Client.load({
	auctionator = true,
	saved = { routeTargets = { [SMITHING] = 20 }, craftValue = "none", vendor = { [VENDOR_GOOD] = 10 } },
	data = {
		Thresholds = { [WAITING] = { 1, 10, 15, 40 }, [TRAINED] = { 1, 10, 15, 40 } },
		RecipeData = {
			[WAITING] = { skillLine = SMITHING, reagents = { { itemID = MARKET_GOOD, quantity = 1 } } },
			[TRAINED] = { skillLine = SMITHING, reagents = { { itemID = VENDOR_GOOD, quantity = 1 } } },
		},
		VendorPrices = {},
		TrainerFees = { [TRAINED] = { 50, 1 } },
		TrainerRanks = {},
		ItemSellPrices = {},
		GatheredBy = {},
		LootedFrom = { [MARKET_GOOD] = true },
		ProfessionTrainers = {},
		ScrollDrops = {},
		WorldDrops = {},
	},
})
trainer.professions = { { name = "Blacksmithing", id = SMITHING, rank = 1, max = 75 } }
trainer.known[WAITING] = true
trainer.level = 20
trainer.ns.SetCollectMode("auction")
trainer.ns.Changed("target")
local trained = trainer.ns.PlanRoute(trainer.ns.RouteProfessions()[SMITHING])
equal(trained.reached, 20, "the route reaches its target")
equal(trained.training[1] and trained.training[1].recipeID, TRAINED, "by training the priced recipe")
equal(trained.crafts[1] and trained.crafts[1].recipeID, TRAINED, "whose crafts carry the route")

Client.report("unpriced_route_spec")
