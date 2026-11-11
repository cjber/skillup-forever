---@type string, SkillUpNamespace
local _, ns = ...

if ns.broken then
	return
end

-- What goes stale when something changes. A writer says what changed with ns.Changed; the game's own
-- changes arrive as the events below. Only this file knows which caches that drops and which views it
-- redraws: each once per change, caches before views, in ORDER.

-- The route page only arms its redraw timer, so its place among the views is free. So is the hovered
-- tooltip's: it only marks the row for its next update, which the game asks for on its own.
---@type SkillUpStale[]
local ORDER = {
	"schematics",
	"prices",
	"plans",
	"replan",
	"bags",
	"trackedNeeds",
	"tooltipRoute",
	"tooltipRouteTools",
	"api",
	"route",
	"recipeList",
	"tracker",
	"trainer",
	"routeTab",
	"pages",
	"gear",
	"buffs",
	"tooltipCache",
	"tooltip",
	"auctionSearch",
	"detailsBar",
	"shoppingList",
}

---@type table<SkillUpChange, table<SkillUpStale, true>>
-- The item, node and corpse tooltip lines read recipes, skill and settings; the route index reads the tracked
-- routes and the tools the bags lack. The two are dropped separately, so a bag or item change that moves no
-- answer does not rebuild the lines a hover redraws.
local STALE = {
	-- What a profession's recipes are or need: a recipe learned, or the open window's scan finding a learned
	-- flag, a live grey, skill points or a schematic the plans were built without. The plan is built from all
	-- of it.
	recipes = {
		tooltipCache = true,
		tooltipRoute = true,
		schematics = true,
		plans = true,
		trackedNeeds = true,
		api = true,
		route = true,
		tracker = true,
		gear = true,
		buffs = true,
		auctionSearch = true,
		detailsBar = true,
		shoppingList = true,
	},
	-- The profession window opened or moved to another profession: what shows it follows, from plans kept as
	-- they are. A list update while it is open is qualified by Core/Live.lua's scan, which marks this only
	-- when the open profession, its skill or the known recipes actually moved.
	window = {
		tooltipCache = true,
		tooltipRoute = true,
		api = true,
		route = true,
		tracker = true,
		gear = true,
		buffs = true,
		auctionSearch = true,
		detailsBar = true,
		shoppingList = true,
	},
	-- A skill line moved: often a weapon or defense skill-up in combat, nothing a plan reads. A plan is keyed by
	-- its profession's skill, bonus and cap, so a profession's own skill-up rebuilds that one plan on its next ask.
	-- `trackedNeeds` is left to that plan key too: a weapon skill-up must not rebuild every tracked route.
	skill = {
		tooltipCache = true,
		tooltipRoute = true,
		api = true,
		route = true,
		tracker = true,
		detailsBar = true,
		buffs = true,
		shoppingList = true,
	},
	-- A Legacy talent changed what a skill-up is worth: every chance shown, planned or priced moves.
	talents = {
		tooltipCache = true,
		tooltipRoute = true,
		plans = true,
		trackedNeeds = true,
		api = true,
		route = true,
		recipeList = true,
		tracker = true,
		trainer = true,
		detailsBar = true,
		tooltip = true,
		shoppingList = true,
	},
	-- A profession learned or dropped changes what counts as gathered, so what things cost.
	professions = {
		tooltipCache = true,
		tooltipRoute = true,
		prices = true,
		plans = true,
		trackedNeeds = true,
		api = true,
		route = true,
		recipeList = true,
		tracker = true,
		gear = true,
		buffs = true,
		shoppingList = true,
	},
	prices = {
		tooltipCache = true,
		tooltipRoute = true,
		prices = true,
		plans = true,
		trackedNeeds = true,
		api = true,
		route = true,
		recipeList = true,
		tracker = true,
		shoppingList = true,
	},
	-- A bag change does not drop `trackedNeeds`: UI/Shopping.lua's plan and missing-tool key tells a tool
	-- that came or went from a bag of unrelated loot. The tooltip's item lines do not read the bags at all;
	-- only the route index does, and only when the tools a route lacks actually moved. `bags` is Plan.lua's own
	-- check, made when something next asks for the plan: a route a step can no longer afford to craft is planned
	-- afresh there, and any other bag change keeps it (#621).
	bags = { bags = true, tooltipRouteTools = true, api = true, route = true, tracker = true, shoppingList = true },
	-- Item data arrived; `names` when the public list was waiting on it. An item tooltip's lines hold no item
	-- name, and a route's tooltip lines hold no shopping source, so `tooltipCache` and `tooltipRoute` stay.
	-- `trackedNeeds` stays too: the one item-data input its list reads, a vendor sell price
	-- (Integrations/Prices.lua's SellPrice), reports `prices` when it arrives. Item data arrives for any item,
	-- from any addon, so dropping the list here rebuilt every tracked route on every hover. `tracker` stays for
	-- the same reason: UI/Shopping.lua keeps the names its section is waiting on and reports the tracker only
	-- when one of them arrives, so a tooltip hover draws no section (#526).
	items = {
		route = true,
		gear = true,
		buffs = true,
		shoppingList = true,
	},
	-- The name the tracker was waiting on arrived. Only that section draws item names, so only it redraws
	-- (UI/Shopping.lua); the item data event itself drops nothing for it (#526).
	trackerNames = { tracker = true },
	names = { api = true },
	level = {
		tooltipCache = true,
		tooltipRoute = true,
		api = true,
		route = true,
		recipeList = true,
		tracker = true,
		gear = true,
		buffs = true,
		shoppingList = true,
	},
	zone = { api = true },
	-- A merchant opened, restocked or closed: the tracker's buy button. A price it records reports `prices`.
	merchant = { tracker = true, shoppingList = true },
	-- Fees and requirements recorded at a trainer.
	fees = {
		tooltipCache = true,
		tooltipRoute = true,
		plans = true,
		trackedNeeds = true,
		api = true,
		route = true,
		tracker = true,
		shoppingList = true,
	},
	-- Where scrolls, vendors and trainers are, read from Questie and AtlasLoot or seen at a merchant's window.
	-- A vendor-sold recipe's scroll price is a plan input too (#358).
	sources = {
		tooltipCache = true,
		tooltipRoute = true,
		plans = true,
		trackedNeeds = true,
		api = true,
		route = true,
		tracker = true,
		tooltip = true,
		gear = true,
		buffs = true,
		shoppingList = true,
	},
	target = {
		tooltipCache = true,
		tooltipRoute = true,
		plans = true,
		trackedNeeds = true,
		api = true,
		route = true,
		tracker = true,
		shoppingList = true,
	},
	tracking = {
		tooltipCache = true,
		tooltipRoute = true,
		trackedNeeds = true,
		api = true,
		route = true,
		tracker = true,
		shoppingList = true,
	},
	settings = {
		tooltipCache = true,
		tooltipRoute = true,
		prices = true,
		plans = true,
		-- A setting is the player's own choice: the route they were following is planned again from it.
		replan = true,
		trackedNeeds = true,
		api = true,
		route = true,
		recipeList = true,
		tracker = true,
		trainer = true,
		routeTab = true,
		pages = true,
		gear = true,
		buffs = true,
		auctionSearch = true,
		detailsBar = true,
		shoppingList = true,
	},
	-- The page's Replan button: the player asked for this route afresh, so the one they were following is
	-- forgotten (`replan`) and every view that draws a plan goes with the plans. Nothing else moved.
	replan = {
		tooltipCache = true,
		tooltipRoute = true,
		plans = true,
		replan = true,
		trackedNeeds = true,
		api = true,
		route = true,
		recipeList = true,
		tracker = true,
		trainer = true,
		auctionSearch = true,
		shoppingList = true,
	},
}

---@type table<string, SkillUpChange>
local EVENTS = {
	TRADE_SKILL_DATA_SOURCE_CHANGED = "window",
	NEW_RECIPE_LEARNED = "recipes",
	TRADE_SKILL_SHOW = "window",
	SKILL_LINES_CHANGED = "skill",
	BAG_UPDATE_DELAYED = "bags",
	ITEM_DATA_LOAD_RESULT = "items",
	PLAYER_LEVEL_UP = "level",
	ZONE_CHANGED_NEW_AREA = "zone",
	MERCHANT_SHOW = "merchant",
	MERCHANT_UPDATE = "merchant",
	MERCHANT_CLOSED = "merchant",
}

-- The name each stale handler's failure is kept under for /skillup report, made once.
---@type table<SkillUpStale, string>
local LABELS = {}
for _, name in ipairs(ORDER) do
	LABELS[name] = "stale " .. name
end

---@type table<SkillUpStale, fun()>
local handlers = {}
---@type table<string, (fun(): SkillUpChange?)[]>
local watchers = {}

---@param kinds table<SkillUpChange, true>
local function Apply(kinds)
	local stale = {}
	for kind in pairs(kinds) do
		for name in pairs(STALE[kind]) do
			stale[name] = true
		end
	end
	for _, name in ipairs(ORDER) do
		local handler = stale[name] and handlers[name]
		if handler then
			-- One failing cache or view doesn't stop the rest; the error is kept for /skillup report.
			ns.core.SafeCall(LABELS[name], handler)
		end
	end
end

-- Something changed that no event below reports: a setting, a target, a price.
---@param kind SkillUpChange
function ns.Changed(kind)
	assert(STALE[kind], kind)
	Apply({ [kind] = true })
end

-- How the owner of a cache drops it, or of a view redraws it. A view registers once its frames exist;
-- until then it has nothing to redraw.
---@param name SkillUpStale
---@param handler fun()
function ns.WhenStale(name, handler)
	handlers[name] = handler
end

local frame = CreateFrame("Frame")
for event in pairs(EVENTS) do
	frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event)
	local kinds = {}
	if EVENTS[event] then
		kinds[EVENTS[event]] = true
	end
	for _, watcher in ipairs(watchers[event] or {}) do
		local ok, kind = ns.core.SafeCall(event, watcher)
		if ok and kind then
			kinds[kind] = true
		end
	end
	Apply(kinds)
end)

-- A file's own work on a game event, run before anything is dropped or redrawn for it. It returns
-- what else it found changed, which joins the event's own change in one pass.
---@param event WowEvent
---@param watcher fun(): SkillUpChange?
function ns.WhenEvent(event, watcher)
	watchers[event] = watchers[event] or {}
	table.insert(watchers[event], watcher)
	frame:RegisterEvent(event)
end
