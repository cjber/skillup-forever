-- Run from the repository root: luajit tests/idle_cpu_spec.lua
-- Issue #412: with no tooltip shown the addon still sees bag, skill and recipe bursts. A burst must not
-- replan every tracked route or rebuild its material lists for every event when the answer did not change.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local FIRST_AID, TAILORING = 129, 197
local BANDAGE, HEAVY, BOLT = 1, 2, 3
local SILK, CLOTH, TOOL = 3, 10, 999

local c = Client.load({
	saved = {
		routeTargets = { [FIRST_AID] = 80, [TAILORING] = 80 },
		trackedProfessions = { [FIRST_AID] = true, [TAILORING] = true },
	},
	data = {
		Thresholds = {
			[BANDAGE] = { 1, 30, 45, 60 },
			[HEAVY] = { 40, 50, 75, 100 },
			[BOLT] = { 1, 40, 50, 60 },
		},
		RecipeData = {
			[BANDAGE] = { skillLine = FIRST_AID, reagents = { { itemID = SILK, quantity = 1 } } },
			[HEAVY] = { skillLine = FIRST_AID, reagents = { { itemID = SILK, quantity = 2 } } },
			[BOLT] = { skillLine = TAILORING, reagents = { { itemID = CLOTH, quantity = 1 } } },
		},
		TrainerFees = { [HEAVY] = { 100, 40 } },
		TrainerRanks = { [FIRST_AID] = { { 150, 500, 50, 0 } }, [TAILORING] = { { 150, 500, 50, 0 } } },
		ItemSellPrices = {},
		GatheredBy = {},
		VendorPrices = { [SILK] = 10, [CLOTH] = 10 },
		ProfessionTrainers = {},
	},
})
local ns = c.ns
ns.SetCollectMode("gather")
c.professions = {
	{ name = "First Aid", rank = 40, max = 75, id = FIRST_AID },
	{ name = "Tailoring", rank = 40, max = 75, id = TAILORING },
}
c.known[BANDAGE], c.known[BOLT] = true, true
c.items[SILK] = { name = "Silk Cloth" }
c.items[CLOTH] = { name = "Linen Cloth" }
c.auction[SILK], c.auction[CLOTH] = 10, 10
c.EnterWorld()
c.Advance(0)

local tracked = 0
for _, profession in pairs(ns.RouteProfessions()) do
	if ns.IsTracked(profession.skillLine) then
		tracked = tracked + 1
	end
end
equal(tracked, 2, "two tracked routes are under test")

-- A cold plan is one the cache had to build: the same plan object handed back is a cache hit.
local plans, cold = {}, 0
local realPlan = ns.PlanRoute
ns.PlanRoute = function(profession, ...)
	local plan = realPlan(profession, ...)
	if plans[profession.skillLine] ~= plan then
		plans[profession.skillLine] = plan
		cold = cold + 1
	end
	return plan
end
local reagents, trackedCalls = 0, 0
local realReagents, realTracked = ns.RouteReagents, ns.TrackedNeeds
ns.RouteReagents = function(plan, ...)
	reagents = reagents + 1
	return realReagents(plan, ...)
end
ns.TrackedNeeds = function(...)
	trackedCalls = trackedCalls + 1
	return realTracked(...)
end
local function Reset()
	cold, reagents, trackedCalls = 0, 0, 0
end

-- A merchant with a reagent the routes still need, so the merchant tab's rebuild path is live.
c.merchant = { { itemID = SILK, price = 100, stackCount = 5 } }
c.Fire("MERCHANT_SHOW")
c.Advance(0)
ns.TrackedNeeds()
Reset()

-- Looting changes the bags many times in one frame. None of it changes a route's plan or its tools, so
-- the tracked routes are read once at most and their material lists are not rebuilt at all.
for _ = 1, 40 do
	c.Fire("BAG_UPDATE_DELAYED")
end
c.Advance(0)
equal(cold, 0, "a burst of bag updates rebuilds no plan")
equal(reagents, 0, "and rebuilds no route's material list")
equal(trackedCalls <= 1, true, "the deferred merchant pass reads the tracked routes once")

-- Learning recipes in a burst drops the plans once for the burst, not once per recipe. One pass after the
-- burst rebuilds each tracked route exactly once.
Reset()
for _ = 1, 20 do
	c.Fire("NEW_RECIPE_LEARNED")
end
c.Advance(0)
equal(cold, tracked, "a burst of learned recipes replans each tracked route once")
equal(trackedCalls, 1, "from one pass over the tracked routes")

-- Tool state is part of the cache key: a tool the bags lack changes the list, and an unchanged one does not.
local missingTool = false
local realTools = ns.MissingToolItems
ns.MissingToolItems = function(plan)
	local tools = realTools(plan)
	if missingTool and plan.profession.skillLine == TAILORING then
		tools[#tools + 1] = TOOL
	end
	return tools
end
missingTool = true
Reset()
ns.TrackedNeeds()
equal(reagents, tracked, "a tool the bags lack rebuilds the routes it joins")
Reset()
ns.TrackedNeeds()
equal(reagents, 0, "an unchanged tool list reads the cache")
missingTool = false
Reset()
ns.TrackedNeeds()
equal(reagents, tracked, "picking the tool up rebuilds the routes again")

-- Item data reaches a tracked list only through a vendor sell price, and that reports `prices` when it
-- arrives (#503). The item data event alone leaves the list as it is; the price change that follows moves a
-- reagent between shopping sources, without the list keeping a wrong bucket until something else changed.
local realSource = ns.PriceSource
local sourceOverride
ns.PriceSource = function(itemID)
	return sourceOverride and sourceOverride[itemID] or realSource(itemID)
end
local function SilkSource()
	for _, entry in ipairs(ns.TrackedNeeds()) do
		for _, item in ipairs(entry.items) do
			if item.itemID == SILK then
				return item.source
			end
		end
	end
end
sourceOverride = { [SILK] = "vendor" }
ns.Changed("prices")
Reset()
equal(SilkSource(), "vendor", "the reagent starts in the vendor bucket")
sourceOverride = { [SILK] = "auctionator" }
Reset()
c.Fire("ITEM_DATA_LOAD_RESULT", SILK, true)
c.Advance(0)
equal(reagents, 0, "item data alone rebuilds no route's material list")
equal(SilkSource(), "vendor", "and leaves the reagent where it was")
Reset()
ns.Changed("prices")
equal(SilkSource(), "auction", "the price change that arrives with it moves the reagent to the auction bucket")
equal(reagents, tracked, "rebuilding each tracked route")
equal(cold, tracked, "and its plan")
ns.PriceSource = realSource
sourceOverride = nil
ns.Changed("prices")

-- A real change to a plan still reaches every reader.
Reset()
ns.db.routeTargets[TAILORING] = 60
ns.Changed("target")
ns.TrackedNeeds()
equal(reagents, tracked, "a new target rebuilds the tracked routes")
equal(cold, tracked, "and their plans")

-- The client fires TRADE_SKILL_LIST_UPDATE for the open window; it can repeat while the profession, its
-- skill and the recipes known are all unchanged. Nothing SkillUp draws may go stale for that.
c.live[BANDAGE] = { info = { learned = true, maxTrivialLevel = 0, numSkillUps = 1 } }
c.live[BOLT] = { info = { learned = true, maxTrivialLevel = 0, numSkillUps = 1 } }
local windowSkill = c.professions[1].rank
c.G.C_TradeSkillUI.GetBaseProfessionInfo = function()
	return { professionID = FIRST_AID, skillLevel = windowSkill, maxSkillLevel = c.professions[1].max }
end
local redrawn = {}
for _, name in ipairs({
	"tooltipCache",
	"api",
	"route",
	"tracker",
	"gear",
	"auctionSearch",
	"detailsBar",
	"shoppingList",
}) do
	ns.WhenStale(name, function()
		redrawn[#redrawn + 1] = name
	end)
end
local function Refreshed(name)
	for _, stale in ipairs(redrawn) do
		if stale == name then
			return true
		end
	end
	return false
end
-- The first scan is the baseline: it records the window as it is now.
c.Fire("TRADE_SKILL_LIST_UPDATE")
c.Advance(0)
redrawn = {}
for _ = 1, 10 do
	c.Fire("TRADE_SKILL_LIST_UPDATE")
	c.Advance(0)
end
equal(#redrawn, 0, "ten unchanged window events mark nothing stale and redraw nothing")

-- A skill-up still moves what the window shows, and the scan on the next event reaches every view.
windowSkill = windowSkill + 1
c.professions[1].rank = windowSkill
c.Fire("TRADE_SKILL_LIST_UPDATE")
c.Advance(0)
equal(Refreshed("tracker"), true, "a skill-up still refreshes the window")

-- A recipe learned in the window moves the known set too.
redrawn = {}
c.live[HEAVY] = { info = { learned = true, maxTrivialLevel = 60, numSkillUps = 1 } }
c.Fire("TRADE_SKILL_LIST_UPDATE")
c.Advance(0)
equal(Refreshed("tracker"), true, "a learned recipe still refreshes the window")

Client.report("idle_cpu_spec")
