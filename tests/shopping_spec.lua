-- Run from the repository root: luajit tests/shopping_spec.lua
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local BANDAGE, HEAVY, SILK = 1, 2, 3
local module
local afterEvents, deferred, attached
local nativeReady = false
local env = setmetatable({
	ObjectiveTrackerManager = {
		SetModuleContainer = function(_, owner, container)
			if nativeReady then
				attached = { owner, container }
			end
		end,
		GetContainerForModule = function()
			return attached and attached[2]
		end,
	},
	ObjectiveTrackerFrame = {},
	OBJECTIVE_TRACKER_COLOR = { Complete = "complete" },
	CreateFrame = function(_, name)
		local frame = { RegisterEvent = function() end, SetScript = function() end, SetHeader = function() end }
		if name then
			module = frame
		end
		return frame
	end,
	Mixin = function(target, source)
		for key, value in pairs(source) do
			target[key] = value
		end
	end,
	hooksecurefunc = function()
		error("native tracker methods must stay unhooked")
	end,
	EventUtil = {
		ContinueAfterAllEvents = function(callback)
			afterEvents = callback
		end,
	},
	C_Timer = {
		After = function(delay, callback)
			if delay == 0 then
				deferred = callback
			end
		end,
	},
	C_Spell = {
		GetSpellName = function(id)
			return ({ [HEAVY] = "Heavy Linen Bandage" })[id]
		end,
	},
	C_Item = {
		GetItemNameByID = function()
			return "Linen Cloth"
		end,
	},
	JOURNEYMAN = "Journeyman",
	UnitLevel = function()
		return 20
	end,
}, { __index = _G })

local ns = {
	db = { trainer = {}, routeTargets = {}, trackedProfessions = { [129] = true } },
	RecipeData = {},
	TrainerFees = { [HEAVY] = { 100, 60 } },
	Reagents = function()
		return { { itemID = SILK, quantity = 1 } }
	end,
	PriceSource = function() end,
	NearestTrainer = function() end,
	NearestVendor = function() end,
}
for _, file in ipairs({ "Locales/enUS.lua", "Model.lua", "Route.lua", "Shopping.lua" }) do
	setfenv(assert(loadfile(file)), env)("SkillUpForever", ns)
end
ns.InitShopping()
equal(attached, nil, "early load waits for native tracker")
afterEvents()
equal(attached, nil, "waits until native event callbacks finish")
nativeReady = true
deferred()
equal(attached[1], module, "attaches our module after native initialization")
-- Shopping.lua's own, which read the client.
ns.Have = function()
	return 0
end
ns.HasAuctionator = function()
	return false
end

local profession = { skillLine = 129, name = "First Aid", skill = 40, base = 40, max = 75, modifier = 0 }
ns.RouteProfessions = function()
	return { [129] = profession }
end
local route
ns.PlanRoute = function()
	return route
end

local objectives
local function Layout()
	objectives = {}
	local block = {
		SetHeader = function() end,
		AddObjective = function(_, key, text)
			objectives[#objectives + 1] = { key = key, text = text }
		end,
	}
	module.GetBlock = function()
		return block
	end
	module.LayoutBlock = function()
		return true
	end
	module:LayoutContents()
end

-- Journeyman is allowed from 50, but the route trains Heavy Linen Bandage at 55 first.
route = {
	profession = "First Aid",
	target = 80,
	segments = {
		{ recipeID = BANDAGE, fromSkill = 40, toSkill = 55, expectedCrafts = 15, crafts = 15 },
		{ recipeID = HEAVY, fromSkill = 55, toSkill = 75, expectedCrafts = 20, crafts = 20 },
		{ recipeID = HEAVY, fromSkill = 75, toSkill = 80, expectedCrafts = 5, crafts = 5 },
	},
	training = { { recipeID = HEAVY, fee = 100, atSkill = 55 } },
	ranks = { { name = "Journeyman", cap = 150, fee = 500, reqSkill = 50, level = 0 } },
	excluded = { unpriced = 0 },
}
Layout()
local walked = ns.RouteSteps(profession, route)
equal(walked[2].training and walked[2].training.recipeID, HEAVY, "the route page trains the recipe first")
equal(objectives[1].key, "Train", "the tracker leads with training")
equal(objectives[1].text, "Train Heavy Linen Bandage at 55 |cff808080(+1 more)|r", "the same training")

-- Nothing priced to craft: the tracker says why, not that the reagents are in hand.
route = {
	profession = "First Aid",
	target = 65,
	segments = {},
	training = {},
	ranks = {},
	reachedSkill = 40,
	stopReason = "no_recipe",
	excluded = { unpriced = 1 },
}
Layout()
equal(#objectives, 1, "one line")
equal(objectives[1].key, "Blocked", "a blocked route says so")
equal(
	objectives[1].text,
	"These reagents have no vendor price. Auction prices need Auctionator.",
	"with the route page's reason"
)

print("shopping_spec: " .. checks .. " checks passed")
