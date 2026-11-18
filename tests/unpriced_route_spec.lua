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

-- The scan that prices them replans: the same route now has known costs and nothing missing.
for _, itemID in ipairs({ LIGHT_LEATHER, LIGHT_HIDE, CURED_LIGHT_HIDE, 2320, 4289, 2321, 2319, 4234 }) do
	unscanned.auction[itemID] = 25
end
unscanned.AuctionatorScan()
unscanned.ns.Changed("prices")
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

Client.report("unpriced_route_spec")
