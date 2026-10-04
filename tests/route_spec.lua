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
			elseif key == "SetShown" then
				value = function(frame, shown)
					rawset(frame, "shown", shown == true)
				end
			elseif key == "IsShown" then
				value = function(frame)
					return rawget(frame, "shown") == true
				end
			elseif key == "Click" then
				value = function(frame)
					if scripts.OnClick then
						scripts.OnClick(frame)
					else
						scripts.OnMouseUp(frame, "LeftButton", true)
					end
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
	db = { trainer = {}, trainerRanks = {}, routeTargets = { [129] = 100 }, showRouteTab = true },
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
	-- No Questie or AtlasLoot: the one line saying what to install.
	Catalogue = {
		Hint = function()
			return "Install both."
		end,
	},
	PriceSource = function(itemID)
		return ({ "gather", "vendor", "auctionator" })[itemID]
	end,
	PlayerProfessions = function()
		return { [129] = FirstAid(1) }
	end,
	ProfessionSkillLine = function(_, reported)
		return reported
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
		list.messages, list.Finish = {}, function() end
		function list:Message(text)
			self.messages[#self.messages + 1] = text
		end
		lists[#lists + 1] = list
		return list
	end,
}
-- The client-side seams the page reads: a character that gathers, and no vendor named until a spec says so.
page.CollectMode = function()
	return page.collectMode or "gather"
end
page.SetCollectMode = function(mode)
	page.collectMode = mode
end
page.NearestVendor = function()
	return nil
end
page.NearestNPC = function()
	return nil
end
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
	ProfessionsFrame = Stub(),
	C_Spell = {
		GetSpellName = function(id)
			return "Spell " .. id
		end,
		GetSpellTexture = function() end,
	},
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
local collect, vendor
pageEnv.CreateFrame = function(_, _, _, template)
	local frame = Stub()
	tabs[#tabs + 1] = frame
	if template == "UICheckButtonTemplate" then
		collect = frame
	elseif template == "UIPanelButtonTemplate" then
		vendor = frame
	end
	return frame
end
-- Opening a profession's window asks to track it: the route event defers the ask to the open profession.
local asked = {}
page.AutoTrack = function(skillLine)
	asked[#asked + 1] = skillLine
end
pageEnv.ProfessionsFrame:Show()
pageEnv.Professions = {
	GetProfessionInfo = function()
		return { professionName = "First Aid", professionID = 129 }
	end,
}
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

for index = #timers, 1, -1 do
	timers[index] = nil
end
asked = {}
eventFrame:Event("TRADE_SKILL_SHOW")
for _, callback in ipairs(timers) do
	callback()
end
equal(asked[#asked], 129, "opening First Aid's window asks to track it")
pageEnv.Professions = false

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
equal(suggestion.text, "Spell 3276", "a suggested scroll's row is named for its recipe alone")
equal(suggestion.note, "vendor", "with where it comes from apart, so cutting the name leaves it whole")
equal(
	table.concat(routeList.messages, " | "):find("Install both.", 1, true) ~= nil,
	true,
	"where the route stops, a missing provider is named"
)
local labels = {}
for _, row in ipairs(lists[#lists].rows) do
	labels[row.text] = row.values[2]
end
for index, source in ipairs(page.Model.SHOPPING_SOURCES) do
	equal(type(labels["item " .. index]), "string", source .. " is listed with a source label")
end

-- The scroll's tooltip opens with the crafted item's own, which already names it.
page.ScrollSkill = function()
	return 1
end
page.RecipeBands = function()
	return {}
end
page.AddSourceLines, page.SuggestionNPC = function() end, function() end
local titles = {}
pageEnv.GameTooltip_AddNormalLine = function(_, text)
	titles[#titles + 1] = text
end
local itemTooltip = { SetItemByID = function() end }
pageEnv.C_Item.GetItemNameByID = function()
	return "Spell 3276"
end
suggestion.tooltip(itemTooltip)
equal(#titles, 0, "a recipe named as its item is does not repeat the name under the item's tooltip")
pageEnv.C_Item.GetItemNameByID = function()
	return "Heavy Linen Bandage"
end
suggestion.tooltip(itemTooltip)
equal(titles[1], "Spell 3276", "a recipe named otherwise is still named there")

-- The collect switch: gather by default, auction after a click, and back.
equal(collect.checked, false, "the switch starts on gathering")
collect:Click()
equal(page.collectMode, "auction", "clicking asks for auction mode")
equal(collect.checked, true, "and the switch shows it")
collect:Click()
equal(page.collectMode, "gather", "clicking again asks for gathering")
equal(collect.checked, false, "and the switch shows that")

-- The nearest vendor of the route's missing vendor reagents, one click from the page.
local candidates, waypointed = nil, nil
page.NearestVendor = function(itemID)
	return itemID == 2 and 555 or nil
end
page.NearestNPC = function(npcIDs, byTravel)
	candidates, page.travel = npcIDs, byTravel
	return npcIDs[1]
end
page.SetWaypoint = function(npcID)
	waypointed = npcID
	return true
end
routeTab:Click()
equal(vendor.shown, true, "a missing vendor reagent shows the nearest-vendor button")
vendor:Click()
equal(page.travel, true, "the vendor is ranked by the travel integration")
equal(candidates[1], 555, "the nearest vendor of the missing reagent")
equal(waypointed, 555, "and clicking sets the waypoint to that vendor")

page.Reagents = function()
	return { { itemID = 1, quantity = 1 } }
end
routeTab:Click()
equal(vendor.shown, false, "a route with no vendor reagent hides the button")

Client.report("route_spec")
