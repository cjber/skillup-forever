-- Run from the repository root: luajit tests/shopping_spec.lua
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local BANDAGE, HEAVY, SILK = 1, 2, 3
local module
local afterEvents, deferred, attached
local env = setmetatable({
	ObjectiveTrackerManager = setmetatable({}, {
		__index = function()
			error("native tracker accessed")
		end,
	}),
	ObjectiveTrackerFrame = {},
	OBJECTIVE_TRACKER_COLOR = { Complete = "complete" },
	CreateFrame = function(_, name)
		local frame = {
			RegisterEvent = function() end,
			SetScript = function() end,
			SetHeader = function() end,
			MarkDirty = function() end,
		}
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
	TrackerHost = {
		Attach = function(owner)
			attached = { owner }
		end,
		IsAttached = function(owner)
			return attached and attached[1] == owner
		end,
	},
	db = { trainer = {}, routeTargets = { [129] = 80 }, trackedProfessions = { [129] = true } },
	-- First Aid in miniature: a known bandage, a better one to train at 40, and Journeyman from 50.
	Thresholds = { [BANDAGE] = { 1, 30, 45, 60 }, [HEAVY] = { 40, 50, 75, 100 } },
	RecipeData = { [BANDAGE] = { skillLine = 129 }, [HEAVY] = { skillLine = 129 } },
	TrainerFees = { [HEAVY] = { 100, 40 } },
	TrainerRanks = { [129] = { { 150, 500, 50, 0 } } },
	IsLearned = function(id)
		return id == BANDAGE
	end,
	Reagents = function()
		return { { itemID = SILK, quantity = 1 } }
	end,
	PriceSource = function() end,
	NearestTrainer = function() end,
	NearestVendor = function() end,
}
env.ForeverTrackerHost = ns.TrackerHost
local FILES = { "Locales/enUS.lua", "Core/Model.lua", "Core/Changes.lua", "Core/Plan.lua", "UI/Shopping.lua" }
for _, file in ipairs(FILES) do
	setfenv(assert(loadfile(file)), env)("SkillUpForever", ns)
end
ns.InitShopping()
equal(attached[1], module, "attaches to private host immediately")
afterEvents()
equal(attached[1], module, "native initialization cannot change private ownership")
env.ForeverTrackerHost = nil
attached = nil
deferred()
equal(attached, nil, "missing private host remains inert")
env.ForeverTrackerHost = ns.TrackerHost
afterEvents()
equal(attached, nil, "late host waits for the deferred callback")
deferred()
equal(attached[1], module, "deferred callback attaches after late host publication")
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
local costs = { [BANDAGE] = 10, [HEAVY] = 20 }
ns.NetCost = function(id)
	return costs[id]
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

-- Journeyman is allowed from 50, but the plan trains Heavy Linen Bandage at 45 first, where it
-- becomes the cheaper point: the tracker leads with the page's first training step.
Layout()
local walked = ns.PlanRoute(profession).steps
equal(walked[2].training and walked[2].training.recipeID, HEAVY, "the route page trains the recipe first")
equal(walked[4].rank and walked[4].rank.name, "Journeyman", "and the rank after")
equal(objectives[1].key, "Train", "the tracker leads with training")
equal(objectives[1].text, "Train Heavy Linen Bandage at 45 |cff808080(+1 more)|r", "the same training")

-- Nothing priced to craft: the tracker says why, not that the reagents are in hand.
costs = {}
ns.Changed("prices")
Layout()
equal(#objectives, 1, "one line")
equal(objectives[1].key, "Blocked", "a blocked route says so")
equal(
	objectives[1].text,
	"These reagents have no vendor price. Auction prices need Auctionator.",
	"with the route page's reason"
)

-- Exercise the actual merchant button and purchase callback, including missing stack data.
local merchant, purchased, merchantButton = {}, {}, nil
ns.TrackedNeeds = function()
	return { { items = { { itemID = SILK, need = 7 } } } }
end
env.MerchantFrame = {
	IsShown = function()
		return true
	end,
}
env.GetMerchantNumItems = function()
	return #merchant
end
env.GetMerchantItemID = function(index)
	return merchant[index].itemID
end
env.C_MerchantFrame = {
	GetItemInfo = function(index)
		return merchant[index]
	end,
}
env.C_CurrencyInfo = {
	GetCoinTextureString = function(cost)
		return tostring(cost)
	end,
}
env.GetMoney = function()
	return 10000
end
env.GetMerchantItemMaxStack = function()
	return 20
end
env.BuyMerchantItem = function(index, count)
	purchased[#purchased + 1] = { index, count }
end
env.CreateFrame = function()
	merchantButton = {
		scripts = {},
		shown = false,
		SetScript = function(self, name, callback)
			self.scripts[name] = callback
		end,
		SetPoint = function() end,
		SetSize = function() end,
		SetText = function(self, value)
			self.text = value
		end,
		GetTextWidth = function()
			return 100
		end,
		Show = function(self)
			self.shown = true
		end,
		Hide = function(self)
			self.shown = false
		end,
	}
	return merchantButton
end
merchant = { { itemID = SILK, price = 100, stackCount = 5 } }
ns.Changed("merchant")
equal(merchantButton.shown, true, "known merchant stack enables purchasing")
equal(merchantButton.text, "Buy tracked reagents  200", "purchase price accounts for whole stacks")
merchantButton.scripts.OnClick()
equal(purchased[1][2], 10, "purchase callback buys complete stacks in units")
for _, invalid in ipairs({ false, 0, -1 }) do
	merchant[1].stackCount = invalid or nil
	purchased = {}
	ns.Changed("merchant")
	equal(merchantButton.shown, false, "unknown or invalid stack hides purchase action")
	merchantButton.scripts.OnClick()
	equal(#purchased, 0, "unknown or invalid stack cannot buy invented units")
end

print("shopping_spec: " .. checks .. " checks passed")
