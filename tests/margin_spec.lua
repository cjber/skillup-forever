-- Run from the repository root: luajit tests/margin_spec.lua
-- A route's reagent counts are chosen as a whole to finish with 95% probability from the starting inventory,
-- sharing held reagents and leftovers once, and without inventing a price or a restock trip (#563).
local Client = dofile("tests/client.lua")
local equal = Client.equal
local near = function(actual, expected)
	assert(type(actual) == "number" and math.abs(actual - expected) < 1e-9, tostring(actual) .. " is not " .. expected)
end

local CLOTH, LINEN, HEAVY = 2589, 3275, 3276

local c = Client.load({ saved = { vendor = { [CLOTH] = 2 } }, data = { LootedFrom = {} } })
local ns = c.ns
local Model = ns.Model
c.level = 20
c.professions = { { name = "First Aid", id = 129, rank = 1, max = 75 } }
c.known[LINEN] = true
c.items[1251] = { sell = 0 }

--[[ A whole route ]]

-- The route's legs are planned together: the product of their completion odds clears 95%, not each leg alone.
ns.db.routeTargets[129] = 90
local plan = ns.PlanRoute(ns.PlayerProfessions()[129])
equal(#plan.crafts > 1, true, "the route has more than one leg")
local product = 1
for _, craft in ipairs(plan.crafts) do
	local thresholds = Model.Get(craft.recipeID)
	product = product * Model.CompletionChance(thresholds, craft.from, craft.to, craft.skillUps, craft.crafts)
end
equal(product >= 0.95, true, "the product of every leg's completion odds is at least 95%")
near(plan.completion, product)

-- The reagent list counts the whole route's demand once. The same cloth is used by more than one leg, and a
-- spare left after the first leg is the same bag count the next leg draws on, so they are never counted twice.
local function Cloth()
	for _, item in ipairs(ns.RouteReagents(plan)) do
		if item.itemID == CLOTH then
			return item
		end
	end
end
local expected, usedBy = 0, {}
for _, craft in ipairs(plan.crafts) do
	usedBy[craft.recipeID] = true
	for _, reagent in ipairs(ns.Reagents(craft.recipeID) or {}) do
		if reagent.itemID == CLOTH then
			expected = expected + reagent.quantity * craft.crafts
		end
	end
end
equal(usedBy[LINEN] and usedBy[HEAVY], true, "more than one leg uses the same cloth")
local item = Cloth()
equal(item.need, expected, "the shopping list needs every leg's cloth, once")
c.bags[CLOTH] = 20
ns.Changed("bags")
item = Cloth()
equal(item.need, expected, "held cloth does not change what the route needs")
equal(math.max(item.need - ns.Have(CLOTH), 0), expected - 20, "and is subtracted once, as one shared bag count")

--[[ An unknown price ]]

-- Without a price the budgets still follow the chance model, and the route does not guess a copper value.
local unknown = {
	{ fromSkill = 6, toSkill = 7, skillUps = 1, thresholds = { 1, 5, 7, 9 }, reagentCost = nil },
}
local budgets, completion = Model.BudgetSegments(unknown, 0.95, 0)
equal(completion >= 0.95, true, "an unpriced leg is still planned to the route's chance")
equal(budgets[1] > 1, true, "which asks for more than one craft at a half chance")

--[[ A restock trip ]]

-- Two legs with the same chance but different reagent prices: without a trip cost the cheaper leg carries the
-- margin. A player-set restock cost makes a craft on the cheap leg worth more than one on the expensive leg, as
-- it also avoids a trip, so the cheap leg's budget grows.
local function Leg(cost)
	return { fromSkill = 6, toSkill = 7, skillUps = 1, thresholds = { 1, 5, 7, 9 }, reagentCost = cost }
end
local legs = { Leg(10), Leg(100) }
local cheap, cheapChance = Model.BudgetSegments(legs, 0.95, 0)
local trip, tripChance = Model.BudgetSegments(legs, 0.95, 100000)
equal(cheapChance >= 0.95, true, "without a trip cost the route still reaches 95%")
equal(tripChance >= 0.95, true, "with one it still reaches 95%")
equal(trip[1] > cheap[1], true, "a restock visit cost buys another craft on the cheaper leg")
equal(cheap[2], trip[2], "and leaves the more expensive leg alone")

-- An unsplit route keeps its existing budget instead of repeating the probability search.
do
	local unsplitClient = Client.load({ saved = { vendor = { [2589] = 2 } }, data = { LootedFrom = {} } })
	local unsplit = unsplitClient.ns
	unsplitClient.level = 20
	unsplitClient.professions = { { name = "First Aid", id = 129, rank = 1, max = 75 } }
	unsplitClient.known[3275] = true
	unsplitClient.items[1251] = { sell = 0 }
	unsplit.db.routeTargets[129] = 40
	local original, calls = unsplit.Model.BudgetSegments, 0
	unsplit.Model.BudgetSegments = function(...)
		calls = calls + 1
		return original(...)
	end
	local unsplitPlan = unsplit.PlanRoute(unsplit.PlayerProfessions()[129])
	equal(#unsplitPlan.crafts > 0 and #unsplitPlan.ranks == 0, true, "unsplit crafting route")
	equal(unsplitPlan.completion >= 0.95, true, "the whole route remains budgeted")
	equal(calls, 1, "an unchanged route should use its already calculated budget")
end

Client.report("margin_spec")
