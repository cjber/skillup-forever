-- Run from the repository root: luajit tests/tooltip_cache_spec.lua
-- Issue #412: the client sets a tooltip again and again while the pointer rests on it, so every post-call that
-- works something out each time runs many times a second. An item, an object and a unit keep what they drew by
-- item or by the skill they ask, and only the events that move those answers drop them: a bag, item, name, zone
-- or merchant change draws the same cached lines again.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local BANDAGE, LINEN, BANDAGE_ITEM, GEAR = 1, 3, 50, 5000
local FIRST_AID, MINING, SKINNING = 129, 186, 393
local COPPER = 1

local c = Client.load({
	boot = false,
	saved = { routeTargets = { [FIRST_AID] = 50 }, trackedProfessions = { [FIRST_AID] = true } },
	data = {
		Thresholds = { [BANDAGE] = { 1, 30, 45, 60 } },
		RecipeData = {
			[BANDAGE] = {
				skillLine = FIRST_AID,
				reagents = { { itemID = LINEN, quantity = 1 } },
				output = { itemID = BANDAGE_ITEM, quantity = 1 },
			},
		},
		TrainerFees = {},
		TrainerRanks = { [FIRST_AID] = {} },
		ItemSellPrices = {},
		GatheredBy = {},
		VendorPrices = { [LINEN] = 10 },
		ProfessionTrainers = {},
		NodeSkills = { ["Copper Vein"] = { MINING, COPPER } },
	},
})
local G, ns = c.G, c.ns
G.IsShiftKeyDown = function()
	return false
end

c.items[LINEN] = { name = "Linen Cloth" }
c.items[BANDAGE_ITEM] = { name = "Linen Bandage", sell = 3 }
c.items[GEAR] = { name = "Sturdy Boots" }
c.known[BANDAGE] = true
c.professions = {
	{ name = "First Aid", rank = 20, max = 75, id = FIRST_AID },
	{ name = "Mining", rank = 140, max = 150, id = MINING },
	{ name = "Skinning", rank = 60, max = 75, id = SKINNING },
}
c.Boot()
c.EnterWorld()
c.Advance(0)

-- Count the calls each post-call makes while it works out what to draw. A second set of the same tooltip must
-- not make any of them; the answer is already in the cache.
local calls = {}
local function Wrap(name, table)
	calls[name] = 0
	local real = table[name]
	table[name] = function(...)
		calls[name] = calls[name] + 1
		return real(...)
	end
end
local function Reset()
	for name in pairs(calls) do
		calls[name] = 0
	end
end
Wrap("UsedIn", ns)
Wrap("TrackedNeeds", ns)
Wrap("RouteReagents", ns)
Wrap("PlayerProfessions", ns)
Wrap("Get", ns.Model)
Wrap("GatherThresholds", ns.Model)

-- The route lines the item post-call draws, so a live bag count can be read back.
local colored = {}
c.G.GameTooltip_AddColoredLine = function(_, text)
	colored[#colored + 1] = text
end

-- A tooltip that keeps what it was given, and the data shape D. AddUses and the gathering calls read.
local function Tooltip(unit)
	local tooltip = { lines = {}, unit = unit }
	function tooltip.IsForbidden()
		return false
	end
	function tooltip:GetUnit()
		return self.unit and "corpse" or nil, self.unit
	end
	function tooltip:AddDoubleLine(left, right)
		self.lines[#self.lines + 1] = { left = left, right = right }
	end
	return tooltip
end
local function Post(kind, index)
	return c.postCalls[kind][index]
end
local ITEM, OBJECT, UNIT = G.Enum.TooltipDataType.Item, G.Enum.TooltipDataType.Object, G.Enum.TooltipDataType.Unit
local itemPost = Post(ITEM, 1)
local objectPost = Post(OBJECT, 1)
-- ForeverCore's leaderboards register the unit hook as they load; the addon's own comes when ADDON_LOADED boots it.
local unitPost = Post(UNIT, #c.postCalls[UNIT])

-- An item's uses, route needs and names are worked out once, then read from the cache. The old code repeated
-- every one of them on each set, and this is the check that failed.
local tooltip = Tooltip()
local data = { id = LINEN }
Reset()
itemPost(tooltip, data)
equal(calls.UsedIn, 1, "the first set works out what uses the item")
equal(calls.TrackedNeeds, 1, "and what routes need it")
Reset()
itemPost(tooltip, data)
equal(calls.UsedIn, 0, "setting the same item again reads the cache instead")
equal(calls.TrackedNeeds, 0, "without looking at the routes again")
equal(calls.PlayerProfessions, 0, "or the professions")

-- The cache follows what changes the answer, and only then works it out again.
ns.Changed("recipes")
Reset()
itemPost(tooltip, data)
equal(calls.UsedIn, 1, "a recipe change drops the item's answer")
Reset()
itemPost(tooltip, data)
equal(calls.UsedIn, 0, "and the new answer is cached too")

-- A bag, item, name, zone or merchant change does not move an item's lines: a bag addon fires them constantly
-- while the pointer moves across gear, and rebuilding there is what made the character panel stutter. The
-- item's own answer stays, and the route marker is drawn from the index and the live bag count.
local gear = { id = GEAR }
Reset()
itemPost(tooltip, gear)
equal(calls.UsedIn, 1, "the first set of an item works out its uses")
Reset()
itemPost(tooltip, gear)
equal(calls.UsedIn, 0, "a repeated set of the same item is a table lookup")

for _, case in ipairs({
	{
		"a bag change",
		function()
			c.Fire("BAG_UPDATE_DELAYED")
		end,
	},
	{
		"item data",
		function()
			c.Fire("ITEM_DATA_LOAD_RESULT", GEAR, true)
		end,
	},
	{
		"a name arriving",
		function()
			ns.Changed("names")
		end,
	},
	{
		"a zone change",
		function()
			c.Fire("ZONE_CHANGED_NEW_AREA")
		end,
	},
	{
		"a merchant change",
		function()
			ns.Changed("merchant")
		end,
	},
}) do
	case[2]()
	Reset()
	itemPost(tooltip, gear)
	equal(calls.UsedIn, 0, case[1] .. " does not rebuild an item's uses")
	equal(calls.PlayerProfessions, 0, case[1] .. " does not read the professions again")
	equal(calls.TrackedNeeds, 0, case[1] .. " does not rebuild the tracked routes")
end

-- The tracked routes are indexed once for a move, so a hover across many items matches its own instead of
-- rebuilding every route's list. Only an event that moves a route drops the index. Item data above dropped the
-- tracked-needs list, so drop and warm both together first.
ns.Changed("recipes")
itemPost(tooltip, data)
ns.Changed("bags")
Reset()
for itemID = 1000, 1049 do
	itemPost(tooltip, { id = itemID })
end
equal(calls.TrackedNeeds, 0, "a bag change with the same tools keeps the route index")
equal(calls.RouteReagents, 0, "and builds no route's material list")
Reset()
itemPost(tooltip, { id = 2000 })
equal(calls.TrackedNeeds, 0, "the next new item reads the same index")

-- A route line reads the bag count when it is drawn, so looting updates it without rebuilding the item or the
-- route's material list.
c.bags[LINEN] = 0
colored = {}
itemPost(tooltip, data)
equal(colored[1] ~= nil, true, "a tracked reagent draws a route line")
c.bags[LINEN] = 1
c.Fire("BAG_UPDATE_DELAYED")
Reset()
colored = {}
itemPost(tooltip, data)
equal(calls.UsedIn, 0, "looting one more does not rebuild the item's uses")
equal(calls.TrackedNeeds, 0, "or the routes, when the tools are the same")
equal(string.find(colored[1] or "", "^Route: 1/") ~= nil, true, "and the line shows the new count")

-- A route that actually moved works the answer out again.
ns.Changed("target")
Reset()
itemPost(tooltip, data)
equal(calls.TrackedNeeds, 1, "a route change rebuilds the index once")
Reset()
itemPost(tooltip, data)
equal(calls.TrackedNeeds, 0, "and the next item reads it")

-- Herb and ore nodes: the line for a node's skill is looked up by the skill it asks, not recomputed, and a
-- bag or zone change does not touch it either.
local node = Tooltip()
local nodeData = { lines = { { leftText = "Copper Vein" } } }
Reset()
objectPost(node, nodeData)
equal(calls.PlayerProfessions, 1, "a node line reads your professions once")
equal(calls.GatherThresholds, 1, "and builds its bands once")
local drawn = node.lines[1]
equal(drawn and drawn.left, "Mining 1", "the node line names the skill it asks")
Reset()
objectPost(node, nodeData)
equal(calls.PlayerProfessions, 0, "setting the same node again reads the cache")
equal(calls.GatherThresholds, 0, "with no bands built again")
equal(node.lines[2] and node.lines[2].left, "Mining 1", "and draws the same line")
c.Fire("BAG_UPDATE_DELAYED")
c.Fire("ZONE_CHANGED_NEW_AREA")
Reset()
objectPost(node, nodeData)
equal(calls.PlayerProfessions, 0, "a bag or zone change keeps the node's line")

-- A gatherable corpse: the same, by the skill the corpse's line names and the level it has.
local corpse = Tooltip("target")
local corpseData =
	{ lines = { { leftText = "Plainstrider" }, { leftText = "Level 12 Beast" }, { leftText = "Skinnable" } } }
Reset()
unitPost(corpse, corpseData)
equal(calls.PlayerProfessions, 1, "a corpse line reads your professions once")
equal(corpse.lines[1] and corpse.lines[1].left, "Skinning", "the corpse line names Skinning")
Reset()
unitPost(corpse, corpseData)
equal(calls.PlayerProfessions, 0, "setting the same corpse again reads the cache")
equal(corpse.lines[2] and corpse.lines[2].left, "Skinning", "and draws the same line")

-- A skill change moves the colour, so the answer is dropped.
ns.Changed("skill")
Reset()
unitPost(corpse, corpseData)
equal(calls.PlayerProfessions, 1, "a skill change drops the corpse's answer")
Reset()
unitPost(corpse, corpseData)
equal(calls.PlayerProfessions, 0, "and the new answer is cached too")

Client.report("tooltip_cache_spec")
