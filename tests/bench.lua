-- Run from the repository root: luajit tests/bench.lua
-- Measures the addon inside the headless harness the specs use: what each file SkillUpForever.toc lists
-- costs to load, what login and init do, and what each event, timer and hot lookup costs to run. Every
-- number is CPU time from os.clock, printed per call. Nothing here asserts; it is a measuring stick.
local Client = dofile("tests/client.lua")

-- The harness loads each file and gives it the stub environment with setfenv; the wrappers forward that
-- environment to the real chunk and time its execution.
local realLoadfile, realSetfenv = loadfile, setfenv
local envOf = setmetatable({}, { __mode = "k" })
rawset(_G, "setfenv", function(fn, env)
	envOf[fn] = env
	return realSetfenv(fn, env)
end)
local fileTimes, fileCompile, fileOrder = {}, {}, {}
rawset(_G, "loadfile", function(path)
	local compileStarted = os.clock()
	local chunk, err = realLoadfile(path)
	fileCompile[path] = os.clock() - compileStarted
	if not chunk then
		return chunk, err
	end
	local wrapper
	wrapper = function(...)
		local env = envOf[wrapper]
		if env then
			realSetfenv(chunk, env)
		end
		local started = os.clock()
		local a, b, d, e, f, g, h, i = chunk(...)
		local cost = os.clock() - started
		fileTimes[path] = (fileTimes[path] or 0) + cost
		fileOrder[#fileOrder + 1] = path
		return a, b, d, e, f, g, h, i
	end
	return wrapper
end)

local function report(label, iterations, fn)
	collectgarbage("collect")
	collectgarbage("collect")
	local started = os.clock()
	for index = 1, iterations do
		fn(index)
	end
	local total = os.clock() - started
	print(
		string.format(
			"%-52s %10.4f ms/call  %9.2f ms total  x%d",
			label,
			total * 1000 / iterations,
			total * 1000,
			iterations
		)
	)
	return total
end

-- A character with one open profession that knows every recipe of it, so a plan has real work.
local c = Client.load({ boot = false })
local ns = c.ns

-- The client surfaces the harness does not stub for the tooltip path, and a hook that captures the item
-- tooltip post-call the addon registers.
local noop = function() end
local tooltipPostCall
c.G.TooltipDataProcessor = {
	AddTooltipPostCall = function(kind, fn)
		if kind == c.G.Enum.TooltipDataType.Item then
			tooltipPostCall = fn
		end
	end,
}
c.G.GameTooltip = {
	IsForbidden = function()
		return false
	end,
	SetOwner = noop,
	AddDoubleLine = noop,
	Show = noop,
}
c.G.GameTooltip_AddBlankLineToTooltip = noop
c.G.GameTooltip_AddNormalLine = noop
c.G.GameTooltip_AddDisabledLine = noop
c.G.GameTooltip_AddColoredLine = noop
c.G.GameTooltip_SetTitle = noop
c.G.IsShiftKeyDown = function()
	return false
end

local LW, MAX = 165, 300
local lwids = {}
for recipeID, recipe in pairs(ns.RecipeData) do
	if recipe.skillLine == LW then
		lwids[#lwids + 1] = recipeID
	end
end
table.sort(lwids)
for _, recipeID in ipairs(lwids) do
	c.known[recipeID] = true
end
c.professions = { { name = "Leatherworking", icon = 136247, rank = 200, max = MAX, id = 8165, modifier = 0 } }
for itemID in pairs(ns.ItemSellPrices) do
	c.items[itemID] = { name = "Item " .. itemID, sell = ns.ItemSellPrices[itemID] }
end

print("== file load (execution of each TOC file, before SavedVariables) ==")
local bootStarted = os.clock()
c.Boot()
ns.SetCollectMode("gather")
local bootTime = os.clock() - bootStarted
local compileTotal, runTotal = 0, 0
for _, path in ipairs(fileOrder) do
	compileTotal = compileTotal + fileCompile[path]
	runTotal = runTotal + fileTimes[path]
	print(
		string.format("%-46s compile %8.4f ms   run %8.4f ms", path, fileCompile[path] * 1000, fileTimes[path] * 1000)
	)
end
print(string.format("%-46s compile %8.4f ms   run %8.4f ms", "ALL TOC files", compileTotal * 1000, runTotal * 1000))
print(string.format("%-52s %10.4f ms", "Boot (ADDON_LOADED init, first time)", bootTime * 1000))

local lw = ns.PlayerProfessions()[LW]

print("== first ask for what the load path does not build ==")
local reagentIndexCold = report("ns.UsedIn (builds the reagent index)", 1, function()
	ns.UsedIn(2318)
end)
local planCold = 0
for _ = 1, 5 do
	ns.Changed("recipes")
	planCold = planCold + report("PlanRoute (rebuilt after recipes change)", 1, function()
		ns.PlanRoute(lw)
	end)
end
local apiCold = 0
for _ = 1, 5 do
	ns.Changed("bags")
	apiCold = apiCold + report("API.Professions (rebuilt)", 1, function()
		c.G.SkillUpForever.API.Professions()
	end)
end

print("== event handlers (fired through the shared Changes frame) ==")
-- The open profession's whole recipe list, as a list update hands it over.
c.G.C_TradeSkillUI.GetAllRecipeIDs = function()
	return lwids
end
c.G.C_TradeSkillUI.GetRecipeInfo = function()
	return { learned = true }
end
-- A merchant with a stack of a reagent the plan uses, so RecordMerchant and the buy button work.
c.merchant = { { itemID = 2318, price = 200, stackCount = 5 } }
c.npc = { id = 1234, name = "Trader" }
ns.SetTracked(LW, true)

for _, case in ipairs({
	{ "TRADE_SKILL_LIST_UPDATE", 200 },
	{ "BAG_UPDATE_DELAYED", 200 },
	{ "SKILL_LINES_CHANGED", 200 },
	{ "MODIFIER_STATE_CHANGED", 5000 },
	{ "TOOLTIP_DATA_UPDATE", 5000 },
	{ "MERCHANT_UPDATE", 200 },
	{ "MERCHANT_SHOW", 200 },
	{ "PLAYER_LEVEL_UP", 200 },
	{ "ZONE_CHANGED_NEW_AREA", 200 },
	{ "ITEM_DATA_LOAD_RESULT", 200 },
	{ "NEW_RECIPE_LEARNED", 200 },
}) do
	report("fire " .. case[1], case[2], function()
		c.Fire(case[1])
	end)
end

print("== event burst ==")
-- A synthetic burst with a merchant open and a tracked profession, followed by deferred timers.
-- This combines work across timer advances; it is not a measurement of a rendered game frame.
local function eventBurst()
	c.Fire("TRADE_SKILL_LIST_UPDATE")
	c.Fire("SKILL_LINES_CHANGED")
	c.Fire("NEW_RECIPE_LEARNED")
	c.Fire("BAG_UPDATE_DELAYED")
	c.Advance(0)
	c.Advance(0.2)
end
report("events + deferred work", 500, eventBurst)

print("== interaction paths (tracker and tooltip) ==")
report("ns.TrackedNeeds (one tracked profession)", 500, function()
	ns.TrackedNeeds()
end)
report("tracker LayoutContents (marks dirty)", 500, function()
	c.Tracker()
end)
if tooltipPostCall then
	report("item tooltip post-call (reagent, route mode)", 5000, function()
		tooltipPostCall(c.G.GameTooltip, { id = 2318 })
	end)
end

print("== hot lookups ==")
report("ns.IsLearned (learned recipe)", 200000, function()
	ns.IsLearned(lwids[1])
end)
report("ns.PlayerProfessions", 100000, function()
	ns.PlayerProfessions()
end)
report("ns.Price (cached)", 200000, function()
	ns.Price(2318)
end)
report("ns.CraftCost (cached recipe)", 20000, function()
	ns.CraftCost(lwids[1])
end)
report("ns.UsedIn (warm index)", 200000, function()
	ns.UsedIn(2318)
end)
report("ns.PlanRoute (cached)", 200000, function()
	ns.PlanRoute(lw)
end)
-- Every call copies the cached answer into fresh tables, as each Forever API read does (forever-core
-- docs/api-conventions.md), so it costs microseconds rather than a table lookup; a caller reads it once per refresh.
report("API.Professions (cached, fresh copy)", 5000, function()
	c.G.SkillUpForever.API.Professions()
end)

local builtPlan = ns.PlanRoute(lw)
report("ns.RouteReagents", 5000, function()
	ns.RouteReagents(builtPlan)
end)

print(string.format("COLD used-in index: %.4f ms", reagentIndexCold * 1000))
print(string.format("COLD plan rebuild avg: %.4f ms", planCold * 1000 / 5))
print(string.format("COLD API rebuild avg: %.4f ms", apiCold * 1000 / 5))

print("== a full replan: five professions half-way to 300, every reagent priced ==")
-- What a dropped plan cache costs in game: every trainer recipe up to each rank known, an auction and a sell
-- price for every reagent and product, and each route run to 300 through the ranks and the training on the way.
-- Mining makes its ores free to the others (collect mode "gather", the benchmark's choice). Time and the Lua memory one
-- replan of the five allocates, with the collector held for the measure.
local HALFWAY = {
	{ name = "Blacksmithing", id = 164, rank = 150, max = 225 },
	{ name = "Engineering", id = 202, rank = 120, max = 150 },
	{ name = "Cooking", id = 185, rank = 160, max = 225 },
	{ name = "First Aid", id = 129, rank = 110, max = 150 },
	{ name = "Mining", id = 186, rank = 140, max = 150 },
}
local halfwaySaved = { routeTargets = {} }
for _, profession in ipairs(HALFWAY) do
	halfwaySaved.routeTargets[profession.id] = 300
end
local h = Client.load({ boot = false, saved = halfwaySaved })
for _, profession in ipairs(HALFWAY) do
	h.professions[#h.professions + 1] =
		{ name = profession.name, rank = profession.rank, max = profession.max, id = profession.id }
	for recipeID, training in pairs(h.ns.TrainerFees) do
		local recipe = h.ns.RecipeData[recipeID]
		if recipe and recipe.skillLine == profession.id and training[2] <= profession.rank then
			h.known[recipeID] = true
		end
	end
end
local priced = {}
for _, recipe in pairs(h.ns.RecipeData) do
	for _, reagent in ipairs(recipe.reagents) do
		priced[reagent.itemID] = true
	end
	if recipe.output then
		priced[recipe.output.itemID] = true
	end
end
local pricedIDs = {}
for itemID in pairs(priced) do
	pricedIDs[#pricedIDs + 1] = itemID
end
table.sort(pricedIDs)
for index, itemID in ipairs(pricedIDs) do
	h.auction[itemID] = 100 + index * 7919 % 20000
	h.items[itemID] = { name = "Item " .. itemID, sell = h.ns.ItemSellPrices[itemID] or index * 104729 % 500 }
end
h.Boot()
h.ns.SetCollectMode("gather")
local halfwayProfessions = h.ns.RouteProfessions()
local replanTime, replanMemory = 0, 0
for _ = 1, 5 do
	h.ns.Changed("prices")
	collectgarbage("collect")
	collectgarbage("stop")
	local memory, started = collectgarbage("count"), os.clock()
	for _, profession in pairs(halfwayProfessions) do
		h.ns.PlanRoute(profession)
	end
	replanTime = replanTime + os.clock() - started
	replanMemory = replanMemory + collectgarbage("count") - memory
	collectgarbage("restart")
end
print(string.format("COLD full replan avg (5 professions): %.1f ms, %.2f MB", replanTime * 200, replanMemory / 5120))

print("== first hover of each reagent item, over a bag of them ==")
-- The frame-rate report on #412: a bag holds many different reagent items, so every item is an uncached
-- first hover while the pointer moves across it. An action bar holds a handful, so only their first hovers
-- pay this. Four crafters are tracked with real plans, and the item tooltip's post-call is timed over 50
-- distinct reagent items, with a bag change before each pass as a bag addon fires them while the pointer moves.
-- The item lines stay cached across those bag changes; only the route index is checked for moved tools.
local hoverPost = h.postCalls[h.G.Enum.TooltipDataType.Item]
hoverPost = hoverPost and hoverPost[1]
h.G.IsShiftKeyDown = function()
	return false
end
h.G.GameTooltip = c.G.GameTooltip
local hoverTracked = {}
for _, profession in pairs(h.ns.RouteProfessions()) do
	h.ns.SetTracked(profession.skillLine, true)
	hoverTracked[#hoverTracked + 1] = profession
end
if hoverPost then
	local seen, hoverItems = {}, {}
	local function AddItem(itemID)
		if itemID and not seen[itemID] then
			seen[itemID] = true
			hoverItems[#hoverItems + 1] = itemID
		end
	end
	for _, entry in ipairs(h.ns.TrackedNeeds()) do
		for _, item in ipairs(entry.items) do
			AddItem(item.itemID)
		end
	end
	for _, profession in ipairs(hoverTracked) do
		for _, recipe in pairs(h.ns.RecipeData) do
			if recipe.skillLine == profession.skillLine then
				for _, reagent in ipairs(recipe.reagents) do
					AddItem(reagent.itemID)
				end
			end
		end
	end
	table.sort(hoverItems)
	local count = math.min(50, #hoverItems)
	local passes, hoverTime = 5, 0
	for _ = 1, passes do
		h.ns.Changed("bags")
		for index = 1, count do
			local started = os.clock()
			hoverPost(h.G.GameTooltip, { id = hoverItems[index] })
			hoverTime = hoverTime + os.clock() - started
		end
	end
	print(
		string.format(
			"%-52s %10.4f ms/item  %9.2f ms total  x%d",
			string.format("first hover x%d (%d tracked)", count, #hoverTracked),
			hoverTime * 1000 / (passes * count),
			hoverTime * 1000,
			passes * count
		)
	)
end

print("== item tooltip refresh with two comparison tooltips ==")
-- The report on #477: with item comparison on, the game shows the hovered item's tooltip and up to two
-- shopping comparison tooltips, and refreshes all three while the character moves. This times one frame of
-- that refresh and counts the addon's lookups and the lines it adds. An unchanged item must cost only its
-- lookup: no uses worked out, no routes read, no bag counts read and no lines added again.
if hoverPost then
	local reagent = h.ns.TrackedNeeds()[1].items[1].itemID
	local gear = 99999
	h.ns.db.reagentTooltip = "full"
	local work = { UsedIn = 0, TrackedNeeds = 0, PlayerProfessions = 0, Have = 0 }
	local real = {}
	for name in pairs(work) do
		real[name] = h.ns[name]
		h.ns[name] = function(...)
			work[name] = work[name] + 1
			return real[name](...)
		end
	end
	local draws = 0
	local function CountingTooltip()
		local tooltip = {
			IsForbidden = function()
				return false
			end,
		}
		function tooltip.AddDoubleLine()
			draws = draws + 1
		end
		return tooltip
	end
	local function CountingLine()
		draws = draws + 1
	end
	h.G.GameTooltip_AddBlankLineToTooltip = CountingLine
	h.G.GameTooltip_AddNormalLine = CountingLine
	h.G.GameTooltip_AddDisabledLine = CountingLine
	h.G.GameTooltip_AddColoredLine = CountingLine
	local main, comparisonOne, comparisonTwo = CountingTooltip(), CountingTooltip(), CountingTooltip()
	hoverPost(main, { id = reagent })
	hoverPost(comparisonOne, { id = gear })
	hoverPost(comparisonTwo, { id = gear })
	for name in pairs(work) do
		work[name] = 0
	end
	draws = 0
	report("item tooltip + 2 comparisons, one refresh", 5000, function()
		hoverPost(main, { id = reagent })
		hoverPost(comparisonOne, { id = gear })
		hoverPost(comparisonTwo, { id = gear })
	end)
	print(
		string.format(
			"%-52s used-in %d  routes %d  professions %d  bag counts %d  lines %d (x5000 frames)",
			"an unchanged frame",
			work.UsedIn,
			work.TrackedNeeds,
			work.PlayerProfessions,
			work.Have,
			draws
		)
	)
end

print("== idle event bursts with five tracked routes ==")
-- No tooltip is shown. A burst is what a frame holds while looting, fighting or learning recipes; the
-- host lays the tracker out once for it. A replan is a plan the cache had to build, and a reagent list
-- is one RouteReagents build.
for _, profession in pairs(h.ns.RouteProfessions()) do
	h.ns.SetTracked(profession.skillLine, true)
end
local burstSeen, replans, listBuilds = {}, 0, 0
for _, entry in ipairs(h.ns.TrackedNeeds()) do
	burstSeen[entry.plan.profession.skillLine] = entry.plan
end
local realBurstPlan, realBurstReagents = h.ns.PlanRoute, h.ns.RouteReagents
h.ns.PlanRoute = function(profession, ...)
	local plan = realBurstPlan(profession, ...)
	if burstSeen[profession.skillLine] ~= plan then
		burstSeen[profession.skillLine] = plan
		replans = replans + 1
	end
	return plan
end
h.ns.RouteReagents = function(plan, ...)
	listBuilds = listBuilds + 1
	return realBurstReagents(plan, ...)
end
local function Burst(label, event, times)
	replans, listBuilds = 0, 0
	local started = os.clock()
	for _ = 1, times do
		h.Fire(event)
	end
	h.Advance(0.001)
	h.Tracker()
	print(
		string.format(
			"%-44s %8.3f ms  replans %d  reagent lists %d",
			label,
			(os.clock() - started) * 1000,
			replans,
			listBuilds
		)
	)
end

Burst("40x BAG_UPDATE_DELAYED", "BAG_UPDATE_DELAYED", 40)
Burst("200x UNIT_AURA", "UNIT_AURA", 200)
Burst("40x SKILL_LINES_CHANGED", "SKILL_LINES_CHANGED", 40)
Burst("40x TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_LIST_UPDATE", 40)
Burst("40x QUEST_LOG_UPDATE", "QUEST_LOG_UPDATE", 40)
Burst("20x NEW_RECIPE_LEARNED", "NEW_RECIPE_LEARNED", 20)

local merchantItem = h.ns.TrackedNeeds()[1].items[1].itemID
h.merchant = { { itemID = merchantItem, price = 200, stackCount = 5 } }
h.npc = { id = 1234, name = "Trader" }
h.Fire("MERCHANT_SHOW")
h.Advance(0.001)
Burst("40x BAG_UPDATE_DELAYED (merchant open)", "BAG_UPDATE_DELAYED", 40)
Burst("40x MERCHANT_UPDATE (merchant open)", "MERCHANT_UPDATE", 40)
Burst("20x NEW_RECIPE_LEARNED (merchant open)", "NEW_RECIPE_LEARNED", 20)
h.merchant = nil
h.Fire("MERCHANT_CLOSED")

-- The client can fire TRADE_SKILL_LIST_UPDATE while the Profession window stays open and nothing SkillUp
-- reads has moved. One event a frame, with the open profession's recipe list and skill; the row counts how
-- often a view was told to redraw for what the window shows.
local open = h.ns.PlayerProfessions()[129]
local windowRecipes = {}
for recipeID, recipe in pairs(h.ns.RecipeData) do
	if recipe.skillLine == 129 then
		windowRecipes[#windowRecipes + 1] = recipeID
	end
end
table.sort(windowRecipes)
h.G.C_TradeSkillUI.GetAllRecipeIDs = function()
	return windowRecipes
end
h.G.C_TradeSkillUI.GetRecipeInfo = function(recipeID)
	return { learned = h.known[recipeID] == true, maxTrivialLevel = 0, numSkillUps = 1 }
end
h.G.C_TradeSkillUI.GetBaseProfessionInfo = function()
	return { professionID = 129, skillLevel = open.base, maxSkillLevel = open.max }
end
h.Fire("TRADE_SKILL_LIST_UPDATE")
h.Advance(0)

local windowRedraws = 0
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
	h.ns.WhenStale(name, function()
		windowRedraws = windowRedraws + 1
	end)
end

local function WindowTicks(label, frames)
	replans, listBuilds, windowRedraws = 0, 0, 0
	local started = os.clock()
	for _ = 1, frames do
		h.Fire("TRADE_SKILL_LIST_UPDATE")
		h.Advance(0)
	end
	print(
		string.format(
			"%-44s %8.3f ms  replans %d  reagent lists %d  redraws %d",
			label,
			(os.clock() - started) * 1000,
			replans,
			listBuilds,
			windowRedraws
		)
	)
end

print("== repeated window event with the Professions window shown ==")
WindowTicks("40x TRADE_SKILL_LIST_UPDATE, unchanged", 40)
