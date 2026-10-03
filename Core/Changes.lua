---@type string, SkillUpNamespace
local _, ns = ...

-- What goes stale when something changes. A writer says what changed with ns.Changed; the game's own
-- changes arrive as the events below. Only this file knows which caches that drops and which views it
-- redraws: each once per change, caches before views, in ORDER.

-- Caches first, so every view redraws from fresh data. The route page only arms its redraw timer, so
-- its place among the views is free; the rest keep the order they have always been refreshed in.
---@type SkillUpStale[]
local ORDER = { "schematics", "prices", "plans", "api", "route", "recipeList", "tracker", "trainer", "routeTab" }

---@type table<SkillUpChange, table<SkillUpStale, true>>
local STALE = {
	-- What a profession's recipes are or need: its window opened, its list or data source changed,
	-- or a recipe was learned. The plan is built from all of it.
	recipes = { schematics = true, plans = true, api = true, route = true, tracker = true },
	skill = { plans = true, api = true, route = true, tracker = true },
	-- A profession learned or dropped changes what counts as gathered, so what things cost.
	professions = { prices = true, plans = true, api = true, route = true, recipeList = true, tracker = true },
	prices = { prices = true, plans = true, api = true, route = true, recipeList = true, tracker = true },
	bags = { api = true, route = true, tracker = true },
	-- Item data arrived; `names` when the public list was waiting on it.
	items = { route = true, tracker = true },
	names = { api = true },
	level = { api = true, route = true, tracker = true },
	zone = { api = true },
	-- A merchant opened, restocked or closed: the tracker's buy button.
	merchant = { tracker = true },
	-- Fees and requirements recorded at a trainer.
	fees = { plans = true, api = true, route = true, tracker = true },
	target = { plans = true, api = true, route = true, tracker = true },
	tracking = { api = true, route = true, tracker = true },
	settings = {
		prices = true,
		plans = true,
		api = true,
		route = true,
		recipeList = true,
		tracker = true,
		trainer = true,
		routeTab = true,
	},
}

---@type table<string, SkillUpChange>
local EVENTS = {
	TRADE_SKILL_DATA_SOURCE_CHANGED = "recipes",
	NEW_RECIPE_LEARNED = "recipes",
	TRADE_SKILL_SHOW = "recipes",
	TRADE_SKILL_LIST_UPDATE = "recipes",
	SKILL_LINES_CHANGED = "skill",
	BAG_UPDATE_DELAYED = "bags",
	ITEM_DATA_LOAD_RESULT = "items",
	PLAYER_LEVEL_UP = "level",
	ZONE_CHANGED_NEW_AREA = "zone",
	MERCHANT_SHOW = "merchant",
	MERCHANT_UPDATE = "merchant",
	MERCHANT_CLOSED = "merchant",
}

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
			handler()
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
		local kind = watcher()
		if kind then
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
