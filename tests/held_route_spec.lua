-- Run from the repository root: luajit tests/held_route_spec.lua
-- #744: the route chooses a recipe the bags can already make when using what they hold is cheaper than buying
-- a market recipe's reagents. Two synthetic Alchemy recipes, equal in thresholds, so only their price differs.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local SKILL = 171
local BAGS, MARKET = 201, 202
-- #744: a second profession, for a training candidate whose reagent the bags hold. One learned recipe is grey
-- by the character's skill, so only training can carry the route, and two candidates can carry it: one the bags
-- can make, one only from the market. Both are held by the same trainer at the same fee.
local TRAINING_SKILL = 333
local STALE, TRAINED_HELD, TRAINED_MARKET = 4101, 4102, 4103

local c = Client.load({
	saved = {
		routeTargets = { [SKILL] = 20 },
		craftValue = "none",
		vendor = { [2001] = 10, [2002] = 12, [2101] = 10 },
	},
	data = {
		Thresholds = {
			[BAGS] = { 1, 5, 8, 30 },
			[MARKET] = { 1, 5, 8, 30 },
			[STALE] = { 1, 2, 3, 4 },
			[TRAINED_HELD] = { 1, 10, 15, 40 },
			[TRAINED_MARKET] = { 1, 10, 15, 40 },
		},
		RecipeData = {
			[BAGS] = { skillLine = SKILL, reagents = { { itemID = 2002, quantity = 1 } } },
			[MARKET] = { skillLine = SKILL, reagents = { { itemID = 2001, quantity = 1 } } },
			[STALE] = { skillLine = TRAINING_SKILL, reagents = { { itemID = 2101, quantity = 1 } } },
			[TRAINED_HELD] = { skillLine = TRAINING_SKILL, reagents = { { itemID = 2002, quantity = 1 } } },
			[TRAINED_MARKET] = { skillLine = TRAINING_SKILL, reagents = { { itemID = 2001, quantity = 1 } } },
		},
		VendorPrices = {},
		TrainerFees = { [TRAINED_HELD] = { 50, 1 }, [TRAINED_MARKET] = { 50, 1 } },
		TrainerRanks = {},
		ItemSellPrices = {},
		GatheredBy = {},
		LootedFrom = {},
		ProfessionTrainers = {},
		ScrollDrops = {},
		WorldDrops = {},
	},
})
local ns = c.ns
c.professions = { { name = "Alchemy", id = SKILL, rank = 1, max = 75 } }
c.known[BAGS], c.known[MARKET] = true, true
c.level = 20
-- The held recipe's reagent sells for a copper, the market recipe's for more than the market price.
c.items[2002] = { sell = 1 }
c.items[2001] = { sell = 5 }

-- What using a held copy gives up is the lesser of selling it and buying another.
equal(ns.HeldCost(2002), 1, "a held copy costs what selling it brings when that beats buying another")
equal(ns.HeldCost(2001), 5, "and never more than either")
ns.db.vendor[2003] = 7
ns.Changed("prices")
equal(ns.HeldCost(2003), 7, "an unknown sale value falls back to the buy price, never free")
c.items[2003] = { sell = 0 }
ns.Changed("prices")
equal(ns.HeldCost(2003), 0, "a known zero sale value makes a held copy free to use")

local function Profession()
	return ns.RouteProfessions()[SKILL]
end

-- A target change drops the plans cache; a replan also lets go of the route being followed.
local function Plan()
	ns.db.routeTargets[SKILL] = 20
	ns.Changed("target")
	return ns.PlanRoute(Profession())
end
local function Fresh()
	ns.Changed("replan")
	return Plan()
end
local function Crafts(plan)
	local ids = {}
	for index, craft in ipairs(plan.crafts) do
		ids[index] = craft.recipeID
	end
	return table.concat(ids, " ")
end

-- A market recipe costs 10 a craft, the held one 12 while its reagent is bought. With the bags holding that
-- reagent at a 1c sale value, using a copy gives up 1c, so the held recipe wins; empty bags pick the cheaper
-- market one.
c.bags[2002] = 1000
local held = Fresh()
equal(Crafts(held), tostring(BAGS), "a recipe the bags can make wins over a cheaper market one")
equal(held.crafts[1].held, true, "and its step is marked as using what the player already has")
c.bags[2002] = nil
local market = Fresh()
equal(Crafts(market), tostring(MARKET), "with the bags empty the cheaper market recipe is chosen")
equal(market.crafts[1].held, nil, "and no step claims held materials")

-- A held copy that would sell for more than the market route's whole cost is not free to use: its opportunity
-- cost makes the market recipe cheaper again.
c.items[2002].sell = 10000
ns.db.vendor[2002] = 50
ns.Changed("prices")
c.bags[2002] = 1000
local expensive = Fresh()
equal(Crafts(expensive), tostring(MARKET), "a held copy worth more than buying another is not used")
c.items[2002].sell = 1
ns.db.vendor[2002] = 12
ns.Changed("prices")

-- Only two held copies: the route crafts the held recipe for those points, then falls back to the market one.
c.bags[2002] = 2
local short = Fresh()
equal(Crafts(short), tostring(BAGS) .. " " .. tostring(MARKET), "the held recipe is used until its copies run out")
equal(short.crafts[1].held, true, "its first step uses the bags")
equal(short.crafts[2].held, nil, "the step after them buys its reagents")
equal(short.crafts[1].to, 3, "two crafts of the held recipe reach skill 3")

-- #621: a route the player is following keeps its recipes after a bag change, even when the bags would now
-- favour the other one; asking for a route afresh takes the held-aware choice.
c.bags[2002] = nil
local followed = Fresh()
equal(Crafts(followed), tostring(MARKET), "the route starts on the market recipe with empty bags")
ns.db.routeTargets[SKILL] = 20
c.bags[2002] = 1000
c.Fire("BAG_UPDATE_DELAYED")
equal(ns.PlanRoute(Profession()), followed, "a bag change keeps the route being followed")
equal(Crafts(ns.PlanRoute(Profession())), tostring(MARKET), "with its recipes unchanged")

-- With nothing being followed, the same bag change is a fresh choice: the cached market plan is not served.
ns.Changed("replan")
c.bags[2002] = nil
local cached = Plan()
equal(Crafts(cached), tostring(MARKET), "a plain plan caches the market recipe")
ns.Changed("replan")
c.bags[2002] = 1000
c.Fire("BAG_UPDATE_DELAYED")
local fresh = ns.PlanRoute(Profession())
equal(Crafts(fresh), tostring(BAGS), "a bag change with no followed route plans the held recipe")
equal(fresh ~= cached, true, "and does not serve the plan made before it")

-- #744: near the target a craft can gain fewer points than the client says a recipe grants at once. A pooled
-- recipe is still keyed on Rank's own basis -- the crafts that cover one craft's skillUps points, over those
-- points -- never on the single point left to the target, which would make it look dearer than the static
-- recipe beside it for a reason the bags have nothing to do with.
c.live[BAGS] = { info = { learned = true, maxTrivialLevel = 30, numSkillUps = 2, relativeDifficulty = 1 } }
c.live[MARKET] = { info = { learned = true, maxTrivialLevel = 30, numSkillUps = 2, relativeDifficulty = 1 } }
c.Fire("TRADE_SKILL_SHOW")
c.Fire("TRADE_SKILL_LIST_UPDATE")
c.Advance(0)
c.professions = { { name = "Alchemy", id = SKILL, rank = 4, max = 75 } }
ns.db.routeTargets[SKILL] = 5
c.bags[2002] = 1000
ns.Changed("replan")
equal(Crafts(ns.PlanRoute(Profession())), tostring(BAGS), "a pooled recipe near the target ranks on Rank's basis")

-- #744: PoolReagentCost totals a step's reagents over every craft, while Model.RouteStepCost takes a per-craft
-- net and reagent cost and multiplies by the crafts. A step of several crafts must therefore be priced from
-- the per-craft share: hand it the step's total and the money is multiplied by the crafts twice. At skill 4 a
-- The half-chance recipe needs five crafts at 95%. Two reagents come from the bags at 50 and three
-- are bought at 100, so the batch costs 400 plus 500 for craft time.
local POOLED, BOUGHT = 3001, 3002
local many = ns.Model.PlanRoute({
	skill = 4,
	target = 5,
	held = { [POOLED] = 2 },
	recipes = {
		{
			recipeID = POOLED,
			thresholds = { 1, 2, 4, 6 },
			netCost = 100,
			reagentCost = 100,
			reagents = { { itemID = POOLED, quantity = 1, buy = 100, held = 50 } },
		},
		{
			recipeID = BOUGHT,
			thresholds = { 1, 2, 4, 6 },
			netCost = 100,
			reagentCost = 100,
			reagents = { { itemID = BOUGHT, quantity = 1, buy = 100 } },
		},
	},
})
equal(many.segments[1].crafts, 5, "a half-chance step covers one point at 95% in five crafts")
equal(many.segments[1].recipeID, POOLED, "the partly held recipe wins on its per-craft cost")
equal(many.expectedCost, 900, "the final budget prices held copies once and buys only the shortfall")

-- #744: the bags weigh in on a training candidate too. A trained recipe is neither learned nor a walk's recipe
-- until the search takes it, so the planner's held pool must count its reagents before the search re-plans over
-- them. Both candidates reach the same skill from a grey learned recipe; the one the bags can make is the
-- cheaper craft, so the market one wins only while the pool doesn't know the bags hold its rival's reagent.
c.professions = { { name = "Enchanting", id = TRAINING_SKILL, rank = 4, max = 75 } }
c.known[STALE] = true
c.bags[2002] = 1000
ns.db.routeTargets[TRAINING_SKILL] = 20
ns.Changed("prices")
ns.Changed("replan")
local training = ns.RouteProfessions()[TRAINING_SKILL]
local trained = ns.PlanRoute(training)
equal(
	trained.crafts[1] and trained.crafts[1].recipeID,
	TRAINED_HELD,
	"a training candidate the bags can make wins over a cheaper market one"
)
equal(trained.training[1] and trained.training[1].recipeID, TRAINED_HELD, "and the route is planned by training it")
equal(
	ns.BestTraining(training, {}, { { recipeID = TRAINED_HELD, fee = 50 }, { recipeID = TRAINED_MARKET, fee = 50 } }),
	TRAINED_HELD,
	"the trainer window weighs an offer against the bags too"
)

Client.report("held_route_spec")
