-- Run from the repository root: luajit tests/changes_spec.lua
-- What each change makes stale: the real caches of Prices, Plan and the public API, driven by game
-- events on Core/Changes.lua's frame and by the writers, with a recorder standing in for each view.
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local SHIRT, CLOTH, SHIRT_ITEM, BOLT = 1, 10, 11, 12
local frames, fire, timers, dbUpdate = 0, nil, {}, nil
local names, merchant, sell = {}, {}, 5
local env = setmetatable({
	CreateFrame = function()
		frames = frames + 1
		return {
			RegisterEvent = function() end,
			SetScript = function(_, _, fn)
				fire = function(event)
					fn(nil, event)
				end
			end,
		}
	end,
	C_Timer = {
		After = function(_, fn)
			timers[#timers + 1] = fn
		end,
	},
	Enum = { CraftingReagentType = { Basic = 0 } },
	C_TradeSkillUI = {
		GetRecipeSchematic = function()
			return {
				reagentSlotSchematics = { { reagentType = 0, quantityRequired = 1, reagents = { { itemID = CLOTH } } } },
				outputItemID = SHIRT_ITEM,
				quantityMin = 1,
			}
		end,
	},
	C_Item = {
		GetItemInfo = function()
			return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, sell
		end,
		RequestLoadItemDataByID = function() end,
		GetItemNameByID = function(id)
			return names[id]
		end,
		GetItemCount = function()
			return 0
		end,
	},
	C_Spell = { GetSpellName = function() end },
	Auctionator = {
		API = {
			v1 = {
				GetAuctionPriceByItemID = function() end,
				RegisterForDBUpdate = function(_, fn)
					dbUpdate = fn
				end,
			},
		},
	},
	GetMerchantNumItems = function()
		return #merchant
	end,
	GetMerchantItemID = function(index)
		return merchant[index].itemID
	end,
	C_MerchantFrame = {
		GetItemInfo = function(index)
			return merchant[index]
		end,
	},
	PlaySound = function() end,
	SOUNDKIT = {},
}, { __index = _G })

local tailoring = { skillLine = 197, name = "Tailoring", base = 50, skill = 50, modifier = 0, max = 75 }
local professions = { [197] = tailoring }
local learned = { [SHIRT] = true }
local ns = {
	db = {
		vendor = {},
		trainer = {},
		routeTargets = {},
		trackedProfessions = {},
		craftValue = "vendor",
		gatherFree = true,
	},
	Thresholds = { [SHIRT] = { 1, 60, 70, 80 }, [BOLT] = { 1, 90, 100, 110 } },
	RecipeData = { [SHIRT] = { skillLine = 197, reagents = {} }, [BOLT] = { skillLine = 197, reagents = {} } },
	VendorPrices = { [CLOTH] = 10 },
	-- Skinning, which this character lacks: asking is what makes Prices remember its professions.
	GatheredBy = { [CLOTH] = 393 },
	TrainerFees = {},
	TrainerRanks = {},
	PlayerProfessions = function()
		local copy = {}
		for skillLine, profession in pairs(professions) do
			copy[skillLine] = profession
		end
		return copy
	end,
	IsLearned = function(id)
		return learned[id] == true
	end,
	FormatNet = function(copper)
		return copper .. "c"
	end,
	NearestVendor = function() end,
}
for _, file in ipairs({
	"Locales/enUS.lua",
	"Core/Model.lua",
	"Core/Changes.lua",
	"Core/Plan.lua",
	"Integrations/Prices.lua",
	"UI/Shopping.lua",
	"Core/API.lua",
}) do
	setfenv(assert(loadfile(file)), env)("SkillUpForever", ns)
end
ns.InitPrices()
equal(frames, 1, "the game's events arrive on one frame")

local redrawn = {}
for _, view in ipairs({ "tracker", "routeTab", "recipeList", "trainer", "route" }) do
	ns.WhenStale(view, function()
		redrawn[#redrawn + 1] = view
	end)
end

-- Each cache hands back the table it kept until it is dropped.
local CACHES = { "schematics", "prices", "plans", "api" }
local function Kept()
	return {
		schematics = ns.Reagents(SHIRT),
		prices = ns.Price(CLOTH),
		plans = ns.PlanRoute(tailoring),
		api = env.SkillUpForever.API.Professions(),
	}
end

-- What `change` dropped and redrew, as "caches | views" in the order they went.
local function Stale(change)
	local before = Kept()
	redrawn = {}
	change()
	local views = table.concat(redrawn, " ")
	local after, dropped = Kept(), {}
	for _, cache in ipairs(CACHES) do
		if after[cache] ~= before[cache] then
			dropped[#dropped + 1] = cache
		end
	end
	return table.concat(dropped, " ") .. " | " .. views
end

local function Event(event)
	return function()
		fire(event)
	end
end
local function Changed(kind)
	return function()
		ns.Changed(kind)
	end
end

equal(#ns.PlanRoute(tailoring).crafts > 0, true, "the plan under test has crafts")
equal(Stale(function() end), " | ", "nothing changes on its own")

-- The public list was built without the reagent's name, so item data arriving rebuilds it once.
equal(Stale(Event("ITEM_DATA_LOAD_RESULT")), "api | route tracker", "item data the public list waited on")
names[CLOTH] = "Linen Cloth"
fire("BAG_UPDATE_DELAYED")
equal(Stale(Event("ITEM_DATA_LOAD_RESULT")), " | route tracker", "item data nothing waited on")

for _, case in ipairs({
	{ "TRADE_SKILL_DATA_SOURCE_CHANGED", "schematics plans api | route tracker" },
	{ "NEW_RECIPE_LEARNED", "schematics plans api | route tracker" },
	{ "TRADE_SKILL_SHOW", "schematics plans api | route tracker" },
	{ "TRADE_SKILL_LIST_UPDATE", "schematics plans api | route tracker" },
	{ "SKILL_LINES_CHANGED", "plans api | route tracker" },
	{ "BAG_UPDATE_DELAYED", "api | route tracker" },
	{ "PLAYER_LEVEL_UP", "api | " },
	{ "ZONE_CHANGED_NEW_AREA", "api | " },
	{ "MERCHANT_SHOW", " | tracker" },
	{ "MERCHANT_UPDATE", " | tracker" },
	{ "MERCHANT_CLOSED", " | tracker" },
	{ "GET_ITEM_INFO_RECEIVED", " | " },
}) do
	equal(Stale(Event(case[1])), case[2], case[1])
end

-- A recipe learned with no recipe list update after it (the window closed) still reaches the plan.
local function Plans(recipeID)
	for _, craft in ipairs(ns.PlanRoute(tailoring).crafts) do
		if craft.recipeID == recipeID then
			return true
		end
	end
	return false
end
equal(Plans(BOLT), false, "an unlearned recipe is not planned")
learned[BOLT] = true
fire("NEW_RECIPE_LEARNED")
equal(Plans(BOLT), true, "a newly learned recipe is planned at once")

-- One event that means two things is still one pass: every cache and view once.
professions[182] = { skillLine = 182, name = "Herbalism" }
equal(
	Stale(Event("SKILL_LINES_CHANGED")),
	"prices plans api | route recipeList tracker",
	"a skill change that is a new profession"
)
merchant = { { itemID = CLOTH, price = 40, stackCount = 5 } }
equal(
	Stale(Event("MERCHANT_SHOW")),
	"prices plans api | route recipeList tracker",
	"a merchant with a price not seen before"
)
equal(ns.Price(CLOTH).copper, 8, "which is the price now")
equal(Stale(Event("MERCHANT_UPDATE")), " | tracker", "the same merchant again")

-- A sell price the client had not loaded: one re-price after the burst of item data.
sell = nil
ns.CraftValue(SHIRT)
sell, timers = 5, {}
equal(Stale(Event("GET_ITEM_INFO_RECEIVED")), " | ", "item info a craft's value waited on changes nothing yet")
equal(#timers, 1, "it waits out the burst")
equal(Stale(timers[1]), "prices plans api | route recipeList tracker", "then prices changed")

-- What the writers report.
equal(Stale(dbUpdate), "prices plans api | route recipeList tracker", "an Auctionator scan")
equal(Stale(Changed("fees")), "plans api | ", "fees recorded at a trainer")
equal(Stale(Changed("target")), "plans api | route tracker", "a new target")
equal(
	Stale(function()
		ns.SetTracked(197, true)
	end),
	"api | route tracker",
	"tracking a profession"
)
equal(
	Stale(Changed("settings")),
	"prices plans api | route recipeList tracker trainer routeTab",
	"a setting: every view, once each, in the order they were always refreshed"
)
equal(pcall(ns.Changed, "typo"), false, "an unknown change is an error, not a silent no-op")

print("changes_spec: " .. checks .. " checks passed")
