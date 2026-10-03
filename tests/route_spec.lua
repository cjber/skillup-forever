-- Run from the repository root: luajit tests/route_spec.lua
-- The route page drawn from a real plan; the plan itself is plan_spec's.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local function FirstAid(skill)
	return { skillLine = 129, name = "First Aid", skill = skill, base = skill, max = 75, modifier = 0 }
end

-- The route page, drawn into stub frames: every frame method is a no-op but the
-- scripts, which run, and the lists, which record their rows.
local function Stub()
	local scripts = {}
	return setmetatable({}, {
		__index = function(self, key)
			local value
			if key == "SetScript" or key == "HookScript" then
				value = function(_, name, fn)
					local previous = key == "HookScript" and scripts[name]
					scripts[name] = previous and function(...)
						previous(...)
						fn(...)
					end or fn
				end
			elseif key == "SetChecked" then
				value = function(frame, checked)
					rawset(frame, "checked", checked)
				end
			elseif key == "Event" then
				value = function(frame, event)
					scripts.OnEvent(frame, event)
				end
			elseif key == "SetCustomOnMouseUpHandler" then
				value = function(_, fn)
					scripts.OnMouseUp = fn
				end
			elseif key == "Show" then
				value = function(frame)
					rawset(frame, "shown", true)
					if scripts.OnShow then
						scripts.OnShow(frame)
					end
				end
			elseif key == "IsShown" then
				value = function(frame)
					return rawget(frame, "shown") == true
				end
			elseif key == "Click" then
				value = function(frame)
					scripts.OnMouseUp(frame, "LeftButton", true)
				end
			else
				value = Stub()
			end
			rawset(self, key, value)
			return value
		end,
		__call = function()
			return Stub()
		end,
		__add = function()
			return 0
		end,
	})
end
local requested, lists = {}, {}
local page = {
	db = { trainer = {}, routeTargets = { [129] = 100 }, showRouteTab = true },
	COLORS = {},
	IsLearned = function(id)
		return id == 3275
	end,
	NetCost = function() end,
	Reagents = function()
		return { { itemID = 2589, quantity = 1 } }
	end,
	Price = function() end,
	-- One scroll nothing prices, to carry the route on.
	RecipeSuggestions = function()
		return { { recipeID = 3276, source = { item = 6454 }, reach = 115, kindText = "vendor" } }
	end,
	ScrollPrice = function() end,
	PriceSource = function(itemID)
		return ({ "gather", "vendor", "auctionator" })[itemID]
	end,
	PlayerProfessions = function()
		return { [129] = FirstAid(1) }
	end,
	HasAuctionator = function()
		return false
	end,
	IsTracked = function()
		return false
	end,
	CreateList = function()
		local list = { rows = {}, scrollBox = Stub() }
		function list:Add(row)
			self.rows[#self.rows + 1] = row
		end
		list.Message, list.Finish = function() end, function() end
		lists[#lists + 1] = list
		return list
	end,
}
local timers = {}
local pageEnv = setmetatable({
	C_Timer = {
		After = function(_, callback)
			timers[#timers + 1] = callback
		end,
	},
	hooksecurefunc = function()
		error("route tab must not hook native profession methods")
	end,
	C_Item = {
		GetItemNameByID = function() end,
		GetItemIconByID = function() end,
		RequestLoadItemDataByID = function(id)
			requested[id] = true
		end,
	},
	Professions = false,
}, {
	__index = function(_, key)
		local value = _G[key]
		if value == nil then
			return Stub()
		end
		return value
	end,
})
-- Core/Changes.lua's frame is the only one made while the files load: the game's events arrive on it.
local eventFrame
pageEnv.CreateFrame = function()
	eventFrame = Stub()
	return eventFrame
end
for _, file in ipairs({
	"Locales/enUS.lua",
	"Data/Thresholds.lua",
	"Data/Recipes.lua",
	"Data/Trainer.lua",
	"Core/Model.lua",
	"Core/Changes.lua",
	"Core/Plan.lua",
	"UI/Route.lua",
}) do
	setfenv(assert(loadfile(file)), pageEnv)("SkillUpForever", page)
end
local tabs = {}
pageEnv.CreateFrame = function()
	local frame = Stub()
	tabs[#tabs + 1] = frame
	return frame
end
page.AttachRoute()
local routeTab = tabs[#tabs] -- the side tab, the last frame the page creates
routeTab:Click()
local reagentList = lists[2]
equal(reagentList.rows[1] and reagentList.rows[1].text, "item 2589", "an unpriced reagent is listed")
equal(requested[2589], true, "and its name is asked for")
equal(routeTab.checked, true, "opening the route selects its tab")
eventFrame:Event("SKILL_LINES_CHANGED")
routeTab:SetChecked(false) -- Blizzard handles the same event after the addon.
for _, callback in ipairs(timers) do
	callback()
end
equal(routeTab.checked, true, "deferred skill update restores the visible route tab")

-- With only Linen Bandage priced, the route runs out and suggests a scroll nothing prices.
page.NetCost = function(recipeID)
	return recipeID == 3275 and 10 or nil
end
page.FormatNet = function(copper)
	return tostring(copper)
end
-- And one reagent from every shopping bucket, each labelled with where it comes from.
page.Reagents = function()
	local reagents = {}
	for index in ipairs(page.Model.SHOPPING_SOURCES) do
		reagents[index] = { itemID = index, quantity = 1 }
	end
	return reagents
end
page.Have = function()
	return 0
end
page.Changed("prices")
routeTab:Click()
local routeList = lists[#lists - 1]
local suggestion = routeList.rows[#routeList.rows]
equal(suggestion and suggestion.values[1], "?", "an unpriced scroll shows ?")
local labels = {}
for _, row in ipairs(lists[#lists].rows) do
	labels[row.text] = row.values[2]
end
for index, source in ipairs(page.Model.SHOPPING_SOURCES) do
	equal(type(labels["item " .. index]), "string", source .. " is listed with a source label")
end

Client.report("route_spec")
