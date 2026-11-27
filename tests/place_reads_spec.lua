-- Run from the repository root: luajit tests/place_reads_spec.lua
-- #1049, #1051: reading from Questie where an item's vendors or droppers stand, for a tooltip, a tracker line or
-- the public API that names them, replanned every profession. On a character with several professions far from
-- their caps that is seconds of frozen client for each item read. Only a read a price was made from replans, and
-- no hover or click on a tracked reagents line, with either button, replans at all.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local TAILORING = 197
local BOLT, SHIRT, CLOAK, SASH = 1, 2, 3, 4
local CLOTH, THREAD, DYE, WOOL = 10, 11, 12, 13
local DROPPER, CLOTH_SELLERS = 401, { 301, 302, 303, 304, 305, 306, 307, 308 }

local npcs = {
	[311] = { name = "Thread seller", side = "AH", spawns = { [10] = { { 60, 60 } } } },
	[312] = { name = "Dye seller", side = "AH", spawns = { [10] = { { 70, 70 } } } },
	[313] = { name = "Wool seller", side = "AH", spawns = { [10] = { { 80, 80 } } } },
	[321] = { name = "Sash trainer", side = "AH", spawns = { [10] = { { 20, 20 } } } },
	[322] = { name = "Far sash trainer", side = "AH", spawns = { [10] = { { 90, 90 } } } },
	[DROPPER] = { name = "Cloth dropper", spawns = { [10] = { { 50, 50 } } } },
}
for index, npcID in ipairs(CLOTH_SELLERS) do
	npcs[npcID] = { name = "Cloth seller " .. index, side = "AH", spawns = { [10] = { { 10 * index, 40 } } } }
end
local c = Client.load({
	boot = false,
	saved = {
		routeTargets = { [TAILORING] = 75 },
		trackedProfessions = { [TAILORING] = true },
	},
	data = {
		Thresholds = {
			[BOLT] = { 1, 30, 45, 60 },
			[SHIRT] = { 1, 40, 55, 70 },
			[CLOAK] = { 1, 40, 55, 75 },
			[SASH] = { 500, 510, 520, 530 },
		},
		RecipeData = {
			[BOLT] = { skillLine = TAILORING, reagents = { { itemID = CLOTH, quantity = 2 } } },
			[SHIRT] = { skillLine = TAILORING, reagents = { { itemID = THREAD, quantity = 1 } } },
			[CLOAK] = { skillLine = TAILORING, reagents = { { itemID = DYE, quantity = 1 } } },
			[SASH] = { skillLine = TAILORING, reagents = { { itemID = WOOL, quantity = 1 } } },
		},
		-- Sash is a trainer's recipe past the route's target, taught by two of them.
		TrainerFees = { [SASH] = { 100, 500 } },
		RecipeTrainerSets = { [SASH] = 1 },
		TrainerSets = { { 321, 322 } },
		TrainerAbilities = {},
		TrainerRanks = { [TAILORING] = { { 150, 500, 50, 0 } } },
		ItemSellPrices = {},
		GatheredBy = {},
		-- Thread is a market good its vendor sells only a few of, so its price is made from its nearest seller.
		LootedFrom = { [THREAD] = true },
		-- Dye is sold only by a vendor, also a few at a time, so the shopping list reads that vendor's limit.
		LimitedStock = { [THREAD] = { [311] = 5 }, [DYE] = { [312] = 3 } },
		VendorPrices = { [CLOTH] = 10, [THREAD] = 10, [DYE] = 10, [WOOL] = 10 },
		ProfessionTrainers = {},
	},
	questie = {
		items = {
			[CLOTH] = { vendors = CLOTH_SELLERS, drops = { DROPPER } },
			[THREAD] = { vendors = { 311 } },
			[DYE] = { vendors = { 312 }, drops = { DROPPER } },
			[WOOL] = { vendors = { 313 } },
		},
		npcs = npcs,
		areas = { [10] = 10 },
	},
})
local ns = c.ns
c.maps[0] = { mapID = 10, name = "Cloth zone" }
c.maps[1] = { mapID = 11, name = "Far zone" }
c.professions = { { name = "Tailoring", rank = 1, max = 75, id = TAILORING } }
c.known[BOLT], c.known[SHIRT], c.known[CLOAK] = true, true, true
for _, id in ipairs({ CLOTH, THREAD, DYE, WOOL }) do
	c.items[id] = { name = "Item " .. id, sell = 0 }
end
c.auction[THREAD] = 50
c.G.OBJECTIVE_DASH_STYLE_HIDE = 2

-- Shortest Path Forever's travel estimates and routes, counted. The farther east is the quicker to reach, so a pick
-- by travel differs from a pick by straight line. `quickest` is the best place estimated, `destination` the one a
-- route went to.
local estimates, navigates = 0, 0
local quickest, destination
c.G.ShortestPathForever = {
	API = {
		version = 2,
		Estimate = function(_, _, _, _, toX)
			estimates = estimates + 1
			quickest = math.max(toX, quickest or 0)
			return 1000 - toX * 100
		end,
		Navigate = function(_, _, x)
			navigates, destination = navigates + 1, x
			return true
		end,
	},
}
-- The section's right-click menu, as ForeverCore's tracker host is handed it.
local trackerMenu
local create = c.G.ForeverCore.TrackerSection.Create
c.G.ForeverCore.TrackerSection.Create = function(name, mixin, opts)
	trackerMenu = opts.contract.menu
	return create(name, mixin, opts)
end
c.Boot()
ns.SetCollectMode("auction")
c.EnterWorld()
local function Frames()
	for _ = 1, 20 do
		c.Advance(0)
	end
end
Frames()

-- A fresh plan is one the route search had to make; the counts are per step below.
local plans, changes = 0, {}
local realPlan = ns.Model.PlanWithTraining
ns.Model.PlanWithTraining = function(...)
	plans = plans + 1
	return realPlan(...)
end
local realChanged = ns.Changed
ns.Changed = function(kind)
	changes[#changes + 1] = kind
	return realChanged(kind)
end
local function Step(fn)
	plans, estimates, navigates, changes = 0, 0, 0, {}
	quickest, destination = nil, nil
	fn()
	Frames()
	c.Tracker()
	c.G.SkillUpForever.API.Professions()
	Frames()
end

-- Everything the route shows has been read: laying it out and the public list again plan nothing.
Step(function()
	c.Tracker()
	c.G.SkillUpForever.API.Professions()
end)
Step(function() end)
equal(plans, 0, "a settled route plans nothing more")
local thread = ns.LimitedReagentPrice(THREAD)
equal(thread, 5, "thread is priced from its nearest seller's stock")
equal(ns.PricesReadVendors(THREAD), true, "so reading its sellers is a plan input")

-- A reagent's droppers read for the first time: only lines naming where it drops can change.
equal(ns.DropZone(CLOTH), nil, "cloth's droppers are not read yet")
Step(function() end)
equal(ns.DropZone(CLOTH), "Cloth zone", "then they are")
equal(plans, 0, "a drop read replans nothing")
equal(changes[1], "places", "it redraws the lines that name places")

-- An item's vendors read for the first time, when no price was made from where they stand.
equal(ns.NearestVendor(WOOL), nil, "wool's vendors are not read yet")
equal(ns.PricesReadVendors(WOOL), false, "and no price is made from them")
Step(function() end)
equal(ns.NearestVendor(WOOL), 313, "then they are")
equal(plans, 0, "a vendor read for a line replans nothing")
equal(changes[1], "places", "and redraws those lines")

-- What a plan reads changing still replans: the counts above are not blind.
Step(function()
	ns.Changed("sources")
end)
equal(plans > 0, true, "a catalogue change replans")

c.G.GameTooltip = setmetatable({}, {
	__index = function()
		return function() end
	end,
})
c.G.GameTooltip_SetTitle = function() end
c.G.GameTooltip_AddInstructionLine = function() end
c.G.GameTooltip_AddColoredLine = function() end
c.G.Professions = false

-- A click that ranks places by travel goes to the quickest of at most six; one naming a single vendor asks nothing.
local ranked = 0
local function CheckPick()
	equal(estimates <= 6, true, "after at most six travel estimates")
	if estimates > 0 then
		ranked = ranked + 1
		equal(destination, quickest, "to the quickest to reach")
	end
end

-- Every line of the section: hover it, then click it with each button and take every action its menu offers.
local block = c.Tracker()[1]
local lines = 0
for _, line in ipairs(block.lines) do
	local scripts = line.frame.scripts
	if scripts and scripts.OnMouseUp then
		lines = lines + 1
		Step(function()
			scripts.OnEnter(line.frame)
		end)
		equal(plans, 0, "hovering " .. tostring(line.key) .. " replans nothing")
		equal(estimates <= 6, true, "and asks at most six travel estimates")
		Step(function()
			scripts.OnMouseUp(line.frame, "LeftButton")
		end)
		equal(plans, 0, "a left click on " .. tostring(line.key) .. " replans nothing")
		equal(navigates, 1, "it starts one route")
		CheckPick()
	end
end
equal(lines > 0, true, "the section has lines to click")
local actions = {}
local function Builder()
	local menu = {}
	function menu.Title() end
	function menu.Action(_, label, run)
		actions[#actions + 1] = { label = label, run = run }
	end
	menu.Open, menu.End = menu.Action, menu.Action
	function menu.Submenu()
		return Builder()
	end
	return menu
end
Step(function()
	trackerMenu({ block = block }, Builder())
end)
equal(plans, 0, "a right click builds its menu without a plan")
local waypoints = 0
for _, action in ipairs(actions) do
	if action.label:find("Waypoint", 1, true) then
		waypoints = waypoints + 1
		Step(action.run)
		equal(plans, 0, action.label .. " replans nothing")
		equal(navigates, 1, "it starts one route")
		CheckPick()
	end
end
equal(waypoints > 0, true, "the menu offers a waypoint")
equal(ranked >= 2, true, "a left click and a menu waypoint both rank by travel")

-- A travel estimate is a whole route search: rebuilding prices and the shopping list asks for none, or the client
-- stops the script before a list is ever kept (#1051).
local redraws = {
	{
		"a price change",
		function()
			ns.Changed("prices")
		end,
	},
	{
		"a catalogue change",
		function()
			ns.Changed("sources")
		end,
	},
	{
		"a bag change",
		function()
			c.bags[DYE] = (c.bags[DYE] or 0) + 1
			c.Fire("BAG_UPDATE_DELAYED")
		end,
	},
	{
		"a zone change",
		function()
			c.Fire("ZONE_CHANGED_NEW_AREA")
		end,
	},
}
for _, redraw in ipairs(redraws) do
	Step(function()
		redraw[2]()
		c.G.SkillUpForever.API.ShoppingList()
	end)
	equal(estimates, 0, redraw[1] .. " asks no travel estimate")
end
local limits = {}
for _, entry in ipairs(ns.TrackedNeeds()) do
	for _, item in ipairs(entry.items) do
		limits[item.itemID] = item.limited
	end
end
equal(limits[DYE], 3, "the list still says how many its vendor sells")

-- The Gear and Buffs pages draw their button on every render: it asks no travel estimate, and the click is what
-- ranks the trainers, also from another continent where only travel can choose between them.
local sash = { state = "trainable", recipeID = SASH, skillLine = TAILORING, skill = 1 }
local waypoint
ns.SetWaypoint = function(npcID)
	waypoint = npcID
end
ns.PageParts.Action(sash, ns.PlayerProfessions())
Frames()
for _, place in ipairs({ { 0, "beside the trainers" }, { 1, "away from every trainer" } }) do
	c.player.instance, waypoint = place[1], nil
	local enabled, click
	Step(function()
		local _
		_, enabled, click = ns.PageParts.Action(sash, ns.PlayerProfessions())
	end)
	equal(estimates, 0, place[2] .. ", drawing the button asks no travel estimate")
	equal(enabled, true, place[2] .. ", the button offers a waypoint")
	Step(click)
	equal(estimates, 2, place[2] .. ", the click asks each trainer's travel time")
	equal(waypoint, 322, place[2] .. ", and goes to the quickest to reach")
end

-- In combat nothing gives a travel time, so the button offers no click that would name nobody.
c.combat = true
local _, enabled = ns.PageParts.Action(sash, ns.PlayerProfessions())
equal(enabled, false, "away from every trainer in combat, the button offers none")
c.combat = false

Client.report("place_reads_spec")
