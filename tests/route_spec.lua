-- Run from the repository root: luajit tests/route_spec.lua
-- The route page drawn from a real plan; the plan itself is plan_spec's.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local GATHER_TOOLTIP = table.concat({
	"On, a reagent you could gather, fish or loot from creatures is priced at a vendor or the auction house. ",
	"Off, getting it yourself costs nothing.",
})
local NOTHING_TOOLTIP = "Nothing on this route can be gathered, fished or looted by you, "
	.. "so the switch changes nothing for it."

local function FirstAid(skill)
	return { skillLine = 129, name = "First Aid", skill = skill, base = skill, max = 75, modifier = 0 }
end

-- What a secure frame must not be asked to change while the player is in combat. A redraw that touches one of
-- these is the ADDON_ACTION_BLOCKED the route's craft button must not cause.
local inCombat = false
local secureCalls = {}
local function TouchSecure(frame, method)
	if inCombat and rawget(frame, "secure") then
		secureCalls[#secureCalls + 1] = method
	end
end

-- The route page, drawn into stub frames: every frame method is a no-op but the
-- scripts, which run, and the lists, which record their rows.
local function Stub()
	local scripts = {}
	return setmetatable({}, {
		__index = function(self, key)
			local value
			if key == "SetScript" or key == "HookScript" then
				value = function(frame, name, fn)
					local previous = key == "HookScript" and scripts[name]
					scripts[name] = previous and function(...)
						previous(...)
						fn(...)
					end or fn
					rawset(frame, "scripts", scripts)
				end
			elseif key == "SetText" then
				value = function(frame, text)
					rawset(frame, "text", text)
				end
			elseif key == "GetText" then
				value = function(frame)
					return rawget(frame, "text")
				end
			elseif key == "SetAttribute" then
				value = function(frame, name, attribute)
					TouchSecure(frame, "SetAttribute")
					local attributes = rawget(frame, "attributes") or {}
					attributes[name] = attribute
					rawset(frame, "attributes", attributes)
				end
			elseif key == "RegisterForClicks" then
				value = function(frame, ...)
					rawset(frame, "clicks", { ... })
				end
			elseif key == "GetAttribute" then
				value = function(frame, name)
					local attributes = rawget(frame, "attributes") or {}
					return attributes[name]
				end
			elseif key == "SetChecked" then
				value = function(frame, checked)
					rawset(frame, "checked", checked)
				end
			elseif key == "SetEnabled" then
				value = function(frame, enabled)
					TouchSecure(frame, "SetEnabled")
					rawset(frame, "enabled", enabled and true or false)
				end
			elseif key == "SetSize" then
				value = function(frame, width, height)
					TouchSecure(frame, "SetSize")
					rawset(frame, "width", width)
					rawset(frame, "height", height)
				end
			elseif key == "IsEnabled" then
				value = function(frame)
					return rawget(frame, "enabled") ~= false
				end
			elseif key == "Enable" then
				value = function(frame)
					rawset(frame, "enabled", true)
				end
			elseif key == "Disable" then
				value = function(frame)
					rawset(frame, "enabled", false)
				end
			elseif key == "Enter" then
				value = function(frame)
					if scripts.OnEnter then
						scripts.OnEnter(frame)
					end
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
					TouchSecure(frame, "SetShown")
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
local page
local routeTab
page = {
	auctionAutoscan = nil,
	db = { trainer = {}, trainerRanks = {}, routeTargets = { [129] = 100 }, showRouteTab = true, vendor = {} },
	-- The tab bar is UI/Pages.lua's own subject (tests/pages_spec.lua and route_layout_spec.lua); this spec
	-- shows the route page directly and needs only the registration handshake.
	Pages = {
		Register = function(spec)
			page.routeSpec = spec
		end,
		Close = function() end,
		Sync = function()
			if routeTab then
				routeTab.checked = page.routeSpec ~= nil and page.routeSpec.page:IsShown()
			end
		end,
		Select = function()
			local spec = page.routeSpec
			if spec then
				spec.prepare()
				spec.page:Show()
			end
			if routeTab then
				routeTab.checked = true
			end
		end,
	},
	LastSkillUpPage = function()
		return "route"
	end,
	SetLastSkillUpPage = function() end,
	PlaceSideTabs = function() end,
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
		-- A reagent another profession gathers is free while the switch is off and bought while it is on.
		if page.CanGather(itemID) then
			return page.CollectMode() == "gather" and "gather" or "vendor"
		end
		return ({ "vendor", "vendor", "auctionator" })[itemID]
	end,
	-- One reagent per bucket, the first one this character's First Aid gathers.
	GatheredBy = { [1] = 129 },
	LootedFrom = {},
	CanGather = function(itemID)
		if page.LootedFrom[itemID] then
			return "loot"
		end
		local skillLine = page.GatheredBy[itemID]
		local profession = skillLine and page.PlayerProfessions()[skillLine]
		return profession and profession.name or nil
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
	HasTradeSkillMaster = function()
		return false
	end,
	AuctionatorAutoscan = function()
		return page.auctionAutoscan
	end,
	AuctionListName = function(profession)
		return not page.identityMissing and ("SkillUp: Tester-Realm: " .. profession) or nil
	end,
	IsTracked = function()
		return false
	end,
	CreateList = function()
		local list = { rows = {}, scrollBox = Stub() }
		function list:Add(row)
			self.rows[#self.rows + 1] = row
		end
		list.messages, list.Begin, list.Finish = {}, function() end, function() end
		function list:Message(text)
			self.messages[#self.messages + 1] = text
		end
		lists[#lists + 1] = list
		return list
	end,
	-- The route page hides the gear page when it takes over; this spec loads the route file alone.
	-- The profession picker's gamepad wrapper comes from Core/Core.lua, which this spec leaves out.
	StepDropdownUnderGamepad = function() end,
	-- Recipes this character said Not this recipe to: none until a spec skips one.
	PinPreference = function(id)
		return page.pins and page.pins[id] or 0
	end,
	PinnedRecipes = function()
		return page.pinned or {}
	end,
	SetPinned = function(id, pin)
		page.setPinned = { id, pin }
	end,
	SkippedRecipes = function()
		return page.skipped or {}
	end,
	SetSkipped = function(recipeID, skip)
		page.setSkipped = { recipeID, skip }
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
local disabledLines = {}
local craftCalls = 0
-- The client's recipe selection, its own Create buttons and what its craft API answers, which the route's
-- button reads when it arms itself.
local shownRecipeID, openedRecipes = nil, {}
local createReady, createAllReady, craftableCount = true, true, 0
local previousRecipe = {}
local eventCallbacks = {}
local pageEnv = setmetatable({
	-- SafeCall hands a caught error to the game's handler: here it fails the spec.
	geterrorhandler = function()
		return function(message)
			io.stderr:write("error handler: ", tostring(message), "\n")
			os.exit(1)
		end
	end,
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
		GetItemQualityByID = function() end,
		GetItemQualityColor = function() end,
		RequestLoadItemDataByID = function(id)
			requested[id] = true
		end,
	},
	Professions = false,
	ProfessionsFrame = Stub(),
	-- The protected API the addon must never call itself: only the client's secure macro may.
	C_TradeSkillUI = {
		CraftRecipe = function()
			craftCalls = craftCalls + 1
		end,
		GetCraftableCount = function()
			return craftableCount
		end,
		GetRecipeInfo = function(recipeID)
			return { learned = true, recipeID = recipeID, previousRecipeID = previousRecipe[recipeID] }
		end,
		OpenRecipe = function(recipeID)
			openedRecipes[#openedRecipes + 1] = recipeID
		end,
	},
	C_Spell = {
		GetSpellName = function(id)
			return "Spell " .. id
		end,
		GetSpellTexture = function() end,
	},
	EventRegistry = {
		RegisterCallback = function(_, event, callback)
			eventCallbacks[event] = callback
		end,
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
pageEnv.GameTooltip_AddDisabledLine = function(_, text)
	disabledLines[#disabledLines + 1] = text
end
pageEnv.issecretvalue = function()
	return false
end
pageEnv.InCombatLockdown = function()
	return inCombat
end
pageEnv.UnitLevel = function()
	return 60
end
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
	"Core/SafeCall.lua",
	"Core/Changes.lua",
	"Core/Plan.lua",
	"Core/Gear.lua",
	"UI/PageParts.lua",
	"UI/Route.lua",
}) do
	setfenv(assert(loadfile(file)), pageEnv)("SkillUpForever", page)
end
local tabs = {}
local children = {}
local function SideTab(left, top)
	local frame = Stub()
	frame.left, frame.top, frame.width, frame.height = left, top, 32, 32
	frame.GetLeft = function(self)
		return self.left
	end
	frame.GetTop = function(self)
		return self.top
	end
	frame.GetBottom = function(self)
		return self.top - self.height
	end
	frame.GetHeight = function(self)
		return self.height
	end
	frame.SetPoint = function(self, point, relativeTo, relativePoint, x, y)
		self.point = { point, relativeTo, relativePoint, x, y }
		self.left = relativeTo:GetLeft() + (x or 0)
		self.top = relativeTo:GetBottom() + (y or 0)
	end
	frame.ClearAllPoints = function(self)
		self.point = nil
	end
	frame.GetNumPoints = function(self)
		return self.point and 1 or 0
	end
	frame.GetPoint = function(self)
		return unpack(self.point)
	end
	frame:Show()
	return frame
end
local professionTab = SideTab(100, 600)
local occupiedTab = SideTab(100, professionTab:GetBottom() - 2)
children[#children + 1] = professionTab
children[#children + 1] = occupiedTab
pageEnv.ProfessionsFrame.ProfessionsOverviewTab = Stub()
pageEnv.ProfessionsFrame.rightProfessionTabs = { professionTab }
pageEnv.ProfessionsFrame.GetChildren = function()
	return unpack(children)
end
local collect, vendor, targetBox, craftButton = nil, nil, nil, nil
local buttons = {}
pageEnv.CreateFrame = function(_, _, _, template)
	local frame = template == "LargeSideTabButtonTemplate" and SideTab(0, 0) or Stub()
	tabs[#tabs + 1] = frame
	children[#children + 1] = frame
	if template == "UICheckButtonTemplate" then
		collect = frame
	elseif template == "SharedButtonSmallTemplate" then
		vendor = vendor or frame
		buttons[#buttons + 1] = frame
	elseif template == "InputBoxTemplate" then
		targetBox = frame
	elseif template and template:find("SecureActionButtonTemplate", 1, true) then
		craftButton = frame
		rawset(frame, "secure", true)
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
-- The client's own crafting frames: the route's button may read the shown recipe and the buttons' enabled
-- state, and reach the buttons only through its secure attributes. A write, or any other call, fails here:
-- that is the taint of Blizzard's craft path this button must not cause (#313, #327, #350).
local nativeWrites = {}
local function Native(readers)
	return setmetatable({}, {
		__index = function(_, key)
			if readers[key] then
				return readers[key]
			end
			error("the craft path touched Blizzard's " .. tostring(key))
		end,
		__newindex = function(_, key)
			nativeWrites[#nativeWrites + 1] = tostring(key)
			error("the craft path wrote Blizzard's " .. tostring(key))
		end,
	})
end
local nativePage = pageEnv.ProfessionsFrame.CraftingPage
local nativeForm = Native({
	GetRecipeInfo = function()
		return shownRecipeID
				and {
					recipeID = shownRecipeID,
					learned = true,
					previousRecipeID = previousRecipe[shownRecipeID],
				}
			or nil
	end,
})
local nativeCreate = Native({
	IsEnabled = function()
		return createReady
	end,
})
local nativeCreateAll = Native({
	IsEnabled = function()
		return createAllReady
	end,
})
nativePage.SchematicForm = nativeForm
nativePage.CreateButton = nativeCreate
nativePage.CreateAllButton = nativeCreateAll
page.AttachRoute()
routeTab = {
	Click = function()
		page.Pages.Select("route")
	end,
	SetChecked = function(self, checked)
		self.checked = checked
	end,
}
routeTab:Click()
local reagentList = lists[2]
equal(reagentList.rows[1] and reagentList.rows[1].text, "item 2589", "an unpriced reagent is listed")
equal(requested[2589], true, "and its name is asked for")

-- #189: leaving the level box with the number it already holds changes nothing.
local changedKinds = {}
local realChanged = page.Changed
page.Changed = function(kind)
	changedKinds[#changedKinds + 1] = kind
	return realChanged(kind)
end
targetBox:SetText("100")
targetBox.scripts.OnEditFocusLost(targetBox)
equal(#changedKinds, 0, "an unchanged target asks for no change")
targetBox:SetText("110")
targetBox.scripts.OnEditFocusLost(targetBox)
equal(changedKinds[1], "target", "a changed target asks for one")
page.db.routeTargets[129] = 100
realChanged("target")
page.Changed = realChanged
-- A route with nothing this character gathers cannot be switched to buying, but the switch stays clickable and
-- says what it does to it (#190: a box drawn checked while disabled could never be turned off again).
equal(collect.enabled, true, "a route with nothing to gather leaves the switch enabled")
equal(collect.checked, false, "and it shows gathering")
collect:Enter()
equal(disabledLines[#disabledLines], NOTHING_TOOLTIP, "the switch's tooltip says it changes nothing here")
-- A reagent a creature drops is one anyone can loot, so it gives the switch something to change.
local savedLootPlan, savedLootReagents, savedLootHave = page.PlanRoute, page.RouteReagents, page.Have
page.Have = function()
	return 0
end
page.PlanRoute = function(profession)
	return {
		profession = profession,
		target = 100,
		crafts = {},
		steps = {},
		ranks = {},
		cost = 0,
		unpriced = 0,
		unpricedRecipes = {},
		reached = 1,
	}
end
page.RouteReagents = function()
	return { { itemID = 2589, need = 1, source = "gather" } }
end
local normalLines = {}
local savedNormal = pageEnv.GameTooltip_AddNormalLine
pageEnv.GameTooltip_AddNormalLine = function(_, text)
	normalLines[#normalLines + 1] = text
end
page.LootedFrom[2589] = true
routeTab:Click()
collect:Enter()
equal(
	normalLines[#normalLines],
	GATHER_TOOLTIP,
	"a route whose reagent can be looted gives the switch something to change"
)
page.LootedFrom[2589] = nil
routeTab:Click()
local disabled = #disabledLines
collect:Enter()
equal(#disabledLines, disabled + 1, "and one nothing can be looted for says it changes nothing again")
pageEnv.GameTooltip_AddNormalLine = savedNormal
page.PlanRoute, page.RouteReagents, page.Have = savedLootPlan, savedLootReagents, savedLootHave
collect:Click()
equal(page.collectMode, "auction", "so a click still turns buying on")
equal(collect.checked, true, "and the switch shows it")
collect:Click()
equal(page.collectMode, "gather", "and clicking again turns it off, whatever the route holds")
equal(collect.enabled, true, "the switch never disables itself")
equal(collect.checked, false, "and shows gathering again")
-- Turned on, the switch stays enabled even on a route with nothing to gather, so it can always be turned off
-- again (#162: it stuck on, disabled, once every recipe was left out of the route).
page.collectMode = "auction"
routeTab:Click()
equal(collect.enabled, true, "a switch that is on stays enabled")
equal(collect.checked, true, "and shows on")
collect:Click()
equal(page.collectMode, "gather", "so a click turns it off")
routeTab:Click()
equal(collect.enabled, true, "and off, with nothing to gather, it is still clickable")
equal(collect.checked, false, "and shows gathering")
page.collectMode = nil
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
equal(suggestion and suggestion.detail:find("?", 1, true) ~= nil, true, "an unpriced scroll shows ?")
equal(suggestion.text, "Spell 3276", "a suggested scroll's row is named for its recipe alone")
equal(suggestion.detail:find("vendor", 1, true), 1, "with where it comes from on the line under the name")
equal(
	table.concat(routeList.messages, " | "):find("Install both.", 1, true) ~= nil,
	true,
	"where the route stops, a missing provider is named"
)
local labels = {}
for _, row in ipairs(lists[#lists].rows) do
	labels[row.text] = row.detail
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

-- A route with nothing to craft, nothing to train and no reason to stop still says so in the list rather than
-- drawing it blank (#190: buying on with nothing priced left the route empty).
local savedPlan, savedReagents = page.PlanRoute, page.Reagents
page.PlanRoute = function(profession)
	return {
		profession = profession,
		target = 100,
		crafts = {},
		steps = {},
		ranks = {},
		cost = 0,
		unpriced = 0,
		unpricedRecipes = {},
		reached = 1,
	}
end
page.Reagents = function()
	return {}
end
routeTab:Click()
local emptyMessages = table.concat(lists[1].messages, " | ")
equal(
	emptyMessages:find("No step yet: learn or train a First Aid recipe that skills up.", 1, true) ~= nil,
	true,
	"a route with no step and no reason says why in the list"
)
page.PlanRoute, page.Reagents = savedPlan, savedReagents

-- The collect switch: gather by default, auction after a click, and back. Always clickable, so the tooltip
-- carries whether the switch changes this route (#190).
equal(collect.enabled, true, "the switch is always clickable")
equal(collect.checked, false, "the switch starts on gathering")
local explained
pageEnv.GameTooltip_AddNormalLine = function(_, text)
	explained = text
end
local savedRouteReagents = page.RouteReagents
page.RouteReagents = function()
	return { { itemID = 1, need = 1, source = "gather" } }
end
routeTab:Click()
collect:Enter()
equal(explained, GATHER_TOOLTIP, "the switch's tooltip explains what it does when the route gathers a reagent")
page.RouteReagents = savedRouteReagents
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
for _, button in ipairs(buttons) do
	if button.text == "Nearest vendor" then
		vendor = button
	end
end
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

-- A route with crafts shows the switch's effect in the source column: the gathered reagent is free while
-- the switch is off and bought once it is on.
local realPlan = page.PlanRoute
page.PlanRoute = function(profession)
	return {
		profession = profession,
		target = 100,
		crafts = { { recipeID = 3275, crafts = 5, from = 1, to = 5, color = "green" } },
		steps = {},
		ranks = {},
		cost = 0,
		unpriced = 0,
	}
end
page.Reagents = function()
	return { { itemID = 1, quantity = 1 }, { itemID = 2, quantity = 1 } }
end
pageEnv.C_Item.GetItemNameByID = function(itemID)
	return "Reagent " .. itemID
end
local before = #lists[2].rows
routeTab:Click()
local gathered = lists[2].rows[before + 1]
equal(gathered.text, "Reagent 1", "the route's reagents are listed")
equal(
	gathered.detail:find("gather", 1, true) ~= nil,
	true,
	"a reagent this character gathers shows gather while the switch is off"
)
collect:Click()
equal(
	lists[2].rows[#lists[2].rows - 1].detail:find("vendor", 1, true) ~= nil,
	true,
	"and shows its bought source once the switch is on, so the change is plain"
)
collect:Click()
equal(
	lists[2].rows[#lists[2].rows - 1].detail:find("gather", 1, true) ~= nil,
	true,
	"and gather again when the switch is off"
)
page.PlanRoute = realPlan

local function Drain()
	local count = #timers
	for index = 1, count do
		local callback = timers[index]
		if callback then
			callback()
		end
	end
	for index = 1, count do
		timers[index] = nil
	end
end

-- A bag update and a skill change both redraw the reagent have/need while the page is open.
local have = 0
page.Have = function(itemID)
	return itemID == 1 and have or 0
end
page.RouteReagents = function()
	return { { itemID = 1, need = 9, source = "auction" } }
end
routeTab:Click()
Drain()
local function LastReagentDetail()
	for index = #lists[2].rows, 1, -1 do
		local detail = lists[2].rows[index].detail
		if detail and detail:find("/9", 1, true) then
			return detail
		end
	end
end
local function LastListItem()
	return lists[2].rows[#lists[2].rows]
end
equal(LastReagentDetail(), "AH, 0/9", "the reagent list shows what the bags hold")
have = 8
eventFrame:Event("BAG_UPDATE_DELAYED")
Drain()
equal(LastReagentDetail(), "AH, 8/9", "a bag update redraws the have count")
page.RouteReagents = function()
	return { { itemID = 1, need = 9, source = "auction" }, { itemID = 2, need = 4, source = "vendor" } }
end
eventFrame:Event("SKILL_LINES_CHANGED")
Drain()
equal(LastListItem().detail, "vendor, 0/4", "a skill change redraws the plan's reagents")

-- With Auctionator's scan-on-open option known to be off, the page says where to turn it on; with
-- the option unread, it says nothing.
page.auctionAutoscan = false
lists[2].messages = {}
eventFrame:Event("BAG_UPDATE_DELAYED")
Drain()
equal(
	table.concat(lists[2].messages, " | "):find("Auctionator's scan when the auction house opens is off", 1, true)
		~= nil,
	true,
	"the page says where to turn on Auctionator's own scan"
)
page.auctionAutoscan = nil
lists[2].messages = {}
eventFrame:Event("BAG_UPDATE_DELAYED")
Drain()
equal(
	table.concat(lists[2].messages, " | "):find("Auctionator's scan", 1, true),
	nil,
	"an unread scan option says nothing"
)

-- The reagent list names the Auctionator shopping list it keeps up to date.
page.HasAuctionator = function()
	return true
end
page.collectMode = "auction"
lists[2].messages = {}
eventFrame:Event("BAG_UPDATE_DELAYED")
Drain()
equal(
	table
		.concat(lists[2].messages, " | ")
		:find("Kept in the Auctionator list 'SkillUp: Tester-Realm: First Aid'.", 1, true) ~= nil,
	true,
	"the reagent list names the Auctionator list"
)
page.identityMissing = true
lists[2].messages = {}
eventFrame:Event("BAG_UPDATE_DELAYED")
Drain()
equal(
	table.concat(lists[2].messages, " | "):find("Kept in the Auctionator list", 1, true),
	nil,
	"an unknown character has no saved-list message"
)
page.identityMissing = nil
page.HasAuctionator = function()
	return false
end
page.collectMode = nil

-- The route's Craft button presses the Professions window's own Create button as the client's own code:
-- a type="spell" cast does nothing on Forever, and calling CraftRecipe from here taints the craft path
-- (#313, #327, #350, #385). A click makes one, Shift makes all the bags allow, and when the step fits in
-- the bags a click makes all of it too.
page.NextCraft = function()
	return { recipeID = 3275, count = 3, planned = 5, to = 20, text = "Craft 3 of 5× Spell 3275" }
end
shownRecipeID, craftableCount = 3275, 8
openedRecipes = {}
routeTab:Click()
Drain()
for index = #timers, 1, -1 do
	timers[index] = nil
end
equal(craftButton ~= nil, true, "the route's Craft button is a secure action button")
equal(table.concat(craftButton.clicks, ","), "AnyUp,AnyDown", "it hears both the down and the up click")
equal(craftButton.attributes.type, "click", "and clicks a button rather than casting a recipe")
equal(craftButton.attributes.clickbutton, nativeCreate, "pressing the Professions window's own Create button")
equal(craftButton.attributes["shift-type1"], "click", "with Shift also a click")
equal(craftButton.attributes["shift-clickbutton1"], nativeCreateAll, "on its Create All button")
equal(craftButton.attributes.spell, nil, "and no recipe spell attribute")
equal(craftButton.text, "Craft 1 of 3× Spell 3275", "its label says a click makes one")
equal(craftButton.enabled, true, "the route's recipe is shown and the game's Craft button is ready")
equal(#openedRecipes, 0, "a recipe already shown is not reopened")
craftButton:Click()
equal(craftCalls, 0, "the addon never calls the protected craft API itself")
equal(#timers > 0, true, "a craft click schedules a redraw")
equal(#nativeWrites, 0, "the craft path writes nothing into Blizzard's crafting frames")

-- When the route's count fits in the bags, a plain click is Create All, so one click makes the step and
-- not one craft of it.
page.NextCraft = function()
	return { recipeID = 3275, count = 3, planned = 3, to = 20, text = "Craft 3× Spell 3275" }
end
craftableCount = 3
routeTab:Click()
Drain()
equal(craftButton.attributes.clickbutton, nativeCreateAll, "a step that fits in the bags clicks Create All")
equal(craftButton.text, "Craft 3× Spell 3275", "and its label keeps the route's own wording")
equal(craftButton.enabled, true, "and the button is ready")

-- The recipe list shows a rank chain's first recipe and its schematic the highest learned rank, so a higher
-- rank of the route's recipe still arms the button.
previousRecipe[3276] = 3275
shownRecipeID, craftableCount = 3276, 8
page.NextCraft = function()
	return { recipeID = 3275, count = 3, planned = 5, to = 20, text = "Craft 3 of 5× Spell 3275" }
end
routeTab:Click()
Drain()
equal(craftButton.enabled, true, "a higher rank of the route's recipe still arms the button")
equal(craftButton.attributes.type, "click", "as a click")
equal(#openedRecipes, 0, "and the page showing its chain is not reopened")
previousRecipe[3276] = nil
shownRecipeID = 3275

-- A recipe the game cannot batch keeps the single Create button, and Shift has nothing more to make.
createAllReady = false
craftableCount = 8
page.NextCraft = function()
	return { recipeID = 3275, count = 3, planned = 5, to = 20, text = "Craft 3 of 5× Spell 3275" }
end
routeTab:Click()
Drain()
equal(craftButton.attributes.clickbutton, nativeCreate, "a recipe the game cannot batch keeps Create")
equal(craftButton.attributes["shift-clickbutton1"], nil, "and Shift has nothing more to make")
createAllReady = true

-- A secure button's attributes, enabled state, size and visibility are protected in combat, yet bag and skill
-- events still redraw the page. The latest wanted craft waits, one update, for PLAYER_REGEN_ENABLED.
page.NextCraft = function()
	return { recipeID = 3275, count = 3, planned = 5, to = 20, text = "Craft 3 of 5× Spell 3275" }
end
shownRecipeID, craftableCount = 3275, 8
routeTab:Click()
Drain()
local settled = {
	type = craftButton.attributes.type,
	clickbutton = craftButton.attributes.clickbutton,
	shift = craftButton.attributes["shift-clickbutton1"],
	enabled = craftButton.enabled,
	width = craftButton.width,
	shown = craftButton.shown,
}
inCombat = true
page.NextCraft = function()
	return { recipeID = 3276, count = 7, planned = 7, to = 30, text = "Craft 7× Spell 3276" }
end
eventFrame:Event("BAG_UPDATE_DELAYED")
Drain()
equal(#secureCalls, 0, "a redraw in combat makes no protected call on the craft button")
equal(craftButton.attributes.type, settled.type, "the click type waits for combat to end")
equal(craftButton.attributes.clickbutton, settled.clickbutton, "the button it presses waits")
equal(craftButton.attributes["shift-clickbutton1"], settled.shift, "the Shift button waits")
equal(craftButton.enabled, settled.enabled, "the enabled state waits")
equal(craftButton.width, settled.width, "the size waits")
equal(craftButton.shown, settled.shown, "the visibility waits")
page.NextCraft = function()
	return { recipeID = 3277, count = 2, planned = 4, to = 40, text = "Craft 2 of 4× Spell 3277" }
end
eventFrame:Event("SKILL_LINES_CHANGED")
Drain()
equal(#secureCalls, 0, "a second redraw in combat still makes no protected call")
shownRecipeID, craftableCount = 3277, 3
inCombat = false
eventFrame:Event("PLAYER_REGEN_ENABLED")
equal(#secureCalls, 0, "the queued update is applied once combat ends")
equal(craftButton.attributes.type, "click", "the latest craft of the combat redraws wins")
equal(craftButton.attributes.clickbutton, nativeCreate, "on the game's Create button")
equal(craftButton.text, "Craft 1 of 2× Spell 3277", "and says one click makes one")
equal(craftButton.enabled, true, "and the button is ready to craft")

-- A step with nothing to craft disables the button and clears every secure attribute, so a later click cannot
-- repeat the recipe that was armed before it.
page.NextCraft = function()
	return { text = "Craft next", reason = "Nothing to craft on this route." }
end
routeTab:Click()
Drain()
equal(craftButton.attributes.type, nil, "a disabled craft button carries no click type")
equal(craftButton.attributes.clickbutton, nil, "and no button to press")
equal(craftButton.attributes["shift-type1"], nil, "and no Shift click")
equal(craftButton.attributes["shift-clickbutton1"], nil, "and no Shift button")
equal(craftButton.enabled, false, "and is disabled")

-- The crafting page showing another recipe disables the button and clears its attributes. The button asks
-- the client to open the route's recipe, and the client's own RecipeSelected event arms it once the page
-- shows it. Nothing here selects, shows or Initialises Blizzard's page (#350).
page.NextCraft = function()
	return { recipeID = 3275, count = 3, planned = 5, to = 20, text = "Craft 3 of 5× Spell 3275" }
end
shownRecipeID, craftableCount = 9999, 8
openedRecipes = {}
routeTab:Click()
Drain()
equal(craftButton.attributes.type, nil, "another recipe on the page clears the click type")
equal(craftButton.attributes.clickbutton, nil, "and the button it presses")
equal(craftButton.attributes["shift-clickbutton1"], nil, "and the Shift button")
equal(craftButton.enabled, false, "and the button is disabled")
equal(openedRecipes[#openedRecipes], 3275, "the client is asked to open the route's recipe")
equal(craftButton.reason, "The game's Craft button is not ready for this recipe.", "and the tooltip says why")
shownRecipeID = 3275
eventCallbacks["Professions.RecipeSelected"]()
equal(craftButton.attributes.type, "click", "the client showing the recipe arms the button again")
equal(craftButton.attributes.clickbutton, nativeCreate, "on its Create button")
equal(craftButton.enabled, true, "and it is ready")
equal(#nativeWrites, 0, "with no write into Blizzard's crafting frames")

-- A route with crafts and an unpriced reagent is marked incomplete, and the reagent it left out is
-- still named in the reagent list.
page.PlanRoute = function(profession)
	return {
		profession = profession,
		target = 100,
		crafts = { { recipeID = 3275, crafts = 5, from = 1, to = 5, color = "green" } },
		steps = {},
		ranks = {},
		cost = 10,
		unpriced = 2,
		unpricedRecipes = { 3277, 3278 },
	}
end
page.RouteReagents = function()
	return { { itemID = 1, need = 9, source = "vendor" } }
end
page.UnpricedReagents = function()
	return { 2589 }
end
pageEnv.C_Item.GetItemNameByID = function(itemID)
	return "Reagent " .. itemID
end
routeTab:Click()
Drain()
equal(
	table.concat(lists[1].messages, " | "):find("Route incomplete: 2 recipes left out", 1, true) ~= nil,
	true,
	"a route with an unpriced reagent is marked incomplete"
)
local listed = {}
for _, row in ipairs(lists[2].rows) do
	if row.text then
		listed[row.text] = row.detail
	end
end
equal(listed["Reagent 2589"], "no price", "and the reagent it left out is listed as unpriced")

-- Not this recipe: a right-click on a step offers it, and what the route leaves out by choice is one row
-- under it, whose menu shows each recipe again.
---@return table
local function MenuRoot()
	local root = { buttons = {} }
	function root.CreateTitle(_, text)
		root.title = text
	end
	function root.CreateButton(_, text, action)
		root.buttons[#root.buttons + 1] = { text = text, action = action }
	end
	function root.SetScrollMode(_, extent)
		root.scrollExtent = extent
	end
	return root
end
local skipCraft = { recipeID = 3275, crafts = 5, from = 1, to = 5, color = "green" }
page.PlanRoute = function(profession)
	return {
		profession = profession,
		target = 100,
		crafts = { skipCraft },
		steps = { { craft = skipCraft } },
		ranks = {},
		cost = 50,
		unpriced = 0,
		unpricedRecipes = {},
	}
end
page.skipped = { { recipeID = 3276, name = "Heavy Linen Bandage" } }
routeTab:Click()
Drain()
local craftRow = lists[1].rows[1]
local instructions = {}
pageEnv.GameTooltip_AddInstructionLine = function(_, text)
	instructions[#instructions + 1] = text
end
craftRow.tooltip(Stub())
equal(instructions[#instructions], "Right-click to pin or skip this recipe.", "a step's tooltip says how to skip it")
local craftMenu = MenuRoot()
craftRow.menu(nil, craftMenu)
equal(craftMenu.title, "Spell 3275", "a step's menu is titled with its recipe")
equal(craftMenu.buttons[1].text, "Not this recipe", "and offers Not this recipe")
craftMenu.buttons[1].action()
equal(page.setSkipped[1] == 3275 and page.setSkipped[2], true, "which skips that recipe")
equal(craftMenu.buttons[2].text, "Pin for skill-ups", "a step offers pinning")
craftMenu.buttons[2].action()
equal(page.setPinned[1] == 3275 and page.setPinned[2], true, "pinning selects that recipe")
page.pins = { [3275] = 1 }
local pinnedMenu = MenuRoot()
craftRow.menu(nil, pinnedMenu)
equal(pinnedMenu.buttons[2].text, "Unpin recipe", "a pinned step offers unpinning")
pinnedMenu.buttons[2].action()
equal(page.setPinned[1] == 3275 and page.setPinned[2], false, "unpinning restores automatic choices")
local skippedRow = lists[1].rows[#lists[1].rows]
equal(skippedRow.text, "Skipped (1)", "the skipped recipes are one row under the route")
local skippedMenu = MenuRoot()
skippedRow.menu(nil, skippedMenu)
equal(skippedMenu.buttons[1].text, "Show again: Heavy Linen Bandage", "its menu shows each one again")
equal(skippedMenu.scrollExtent, 400, "and scrolls past 20 rows")
skippedMenu.buttons[1].action()
equal(page.setSkipped[1] == 3276 and page.setSkipped[2], false, "by unskipping it")
page.skipped = nil
routeTab:Click()
Drain()
equal(lists[1].rows[#lists[1].rows].text ~= "Skipped (1)", true, "nothing skipped, no row")

-- Pins remain visible with a reason even when the route cannot use them.
page.pinned = { { recipeID = 3275, name = "Linen Bandage" } }
routeTab:Click()
Drain()
local pinRow = lists[1].rows[#lists[1].rows]
equal(pinRow.text, "Pinned: Linen Bandage", "the route lists its saved pin")
equal(pinRow.detail, "Pinned for skill-ups.", "the pin says when this route uses it")
page.pinned = { { recipeID = 3276, name = "Heavy Linen Bandage" } }
routeTab:Click()
Drain()
equal(lists[1].rows[#lists[1].rows].detail, "Requires skill 40.", "a waiting pin explains its skill requirement")
page.pinned = nil

-- The page names the latest auction source and flags old prices.
page.Price = function()
	return { copper = 10, source = "auctionator" }
end
page.PriceAge = function()
	return 0
end
routeTab:Click()
Drain()
equal(
	table.concat(lists[2].messages, " | "):find("Latest Auctionator prices.", 1, true) ~= nil,
	true,
	"the reagent list names the latest price source"
)
page.PriceAge = function()
	return 90000
end
routeTab:Click()
Drain()
equal(
	table.concat(lists[2].messages, " | "):find("Latest Auctionator prices: rescan to update old prices.", 1, true)
		~= nil,
	true,
	"an old price asks for a rescan"
)

-- A rank's book you already have (#121): the step only asks for it to be read, and neither the row,
-- the total nor the tooltip sends you to buy it again (api_spec covers where a click goes).
local UNDER_WRAPS = 16084
local savedHave, savedNormalLine, savedItemName =
	page.Have, pageEnv.GameTooltip_AddNormalLine, pageEnv.C_Item.GetItemNameByID
local bookRank = { name = "Expert", book = UNDER_WRAPS, cap = 225, reqSkill = 125, fee = 10000, level = 0 }
local bookCraft = { recipeID = 3275, crafts = 5, from = 125, to = 130, color = "orange" }
page.PlanRoute = function(profession)
	return {
		profession = profession,
		target = 130,
		crafts = { bookCraft },
		steps = { { rank = bookRank }, { craft = bookCraft } },
		ranks = { bookRank },
		cost = 10500,
		unpriced = 0,
		unpricedRecipes = {},
	}
end
pageEnv.UnitLevel = function()
	return 60
end
pageEnv.C_Item.GetItemNameByID = function(itemID)
	return itemID == UNDER_WRAPS and "Expert First Aid - Under Wraps" or nil
end
local nearestShown = 0
page.NearestForRank = function()
	return 77, "Nearest vendor"
end
page.AddNearest = function()
	nearestShown = nearestShown + 1
end
local heldBook = 0
page.Have = function(itemID)
	return itemID == UNDER_WRAPS and heldBook or 0
end
local tooltipLines = {}
pageEnv.GameTooltip_AddNormalLine = function(_, text)
	tooltipLines[#tooltipLines + 1] = text
end
-- The stub list keeps every row and message it was given, so a redraw's are the ones after the count before it.
local function BookPage()
	local rows, said = #lists[1].rows, #lists[1].messages
	routeTab:Click()
	Drain()
	tooltipLines = {}
	return lists[1].rows[rows + 1], lists[1].messages[said + 1]
end
local bookRow, messages = BookPage()
equal(bookRow.text, "Buy and read Expert First Aid - Under Wraps at 125", "a book not yet bought is bought and read")
equal(bookRow.click ~= nil, true, "and a click goes to its vendor")
equal(bookRow.detail:find("Price 10000", 1, true) ~= nil, true, "at its price")
equal(messages, "Total 10500", "and the total pays for it")
bookRow.tooltip(Stub())
equal(nearestShown, 1, "its tooltip names the nearest vendor")
heldBook = 1
bookRow, messages = BookPage()
equal(bookRow.text, "Read Expert First Aid - Under Wraps at 125", "a book in the bags is only read")
equal(bookRow.detail, "You have it, requires First Aid (125)", "with no price on the row")
equal(messages, "Total 500", "and the total no longer pays for it")
bookRow.tooltip(Stub())
equal(tooltipLines[#tooltipLines], "You have this book: read it.", "its tooltip says you have it")
equal(nearestShown, 1, "and names no vendor")
equal(bookRow.click, nil, "and a click goes nowhere")
-- Only an Artisan quest step's tooltip carries the Adventure Guide Forever hint (waypoint_spec covers when it shows).
local chainHints = 0
page.AddQuestChainHint = function()
	chainHints = chainHints + 1
end
bookRow.tooltip(Stub())
equal(chainHints, 0, "a book step has no quest chain hint")
local questRank = { name = "Artisan", quest = 6622, cap = 300, reqSkill = 225, fee = 0, level = 35 }
page.PlanRoute = function(profession)
	return {
		profession = profession,
		target = 130,
		crafts = { bookCraft },
		steps = { { rank = questRank }, { craft = bookCraft } },
		ranks = { questRank },
		cost = 500,
		unpriced = 0,
		unpricedRecipes = {},
	}
end
local savedQuest = page.Catalogue.Quest
page.Catalogue.Quest = function()
	return nil
end
local questRow = BookPage()
equal(questRow.text:find("the Artisan quest", 1, true) ~= nil, true, "the quest step is drawn")
questRow.tooltip(Stub())
equal(chainHints, 1, "a quest step's tooltip offers the quest chain hint once")
page.AddQuestChainHint, page.Catalogue.Quest = nil, savedQuest
page.PlanRoute, page.Have, page.NearestForRank, page.AddNearest = realPlan, savedHave, nil, nil
pageEnv.GameTooltip_AddNormalLine, pageEnv.C_Item.GetItemNameByID = savedNormalLine, savedItemName

-- Opening a recipe hands it to the client. Selecting it in Blizzard's list from addon code wrote the list's
-- selection and the schematic as ours, and the craft path reads them (#350).
local selected, openedRecipe
local craftingPage = Stub()
craftingPage.RecipeList = {
	SelectRecipe = function()
		selected = true
	end,
}
pageEnv.ProfessionsFrame.CraftingPage = craftingPage
pageEnv.C_TradeSkillUI.GetRecipeInfo = function()
	return { learned = true, recipeID = 3275 }
end
pageEnv.C_TradeSkillUI.OpenRecipe = function(recipeID)
	openedRecipe = recipeID
end
page.ShowRecipe(3275, true)
equal(selected, nil, "opening a recipe does not select it in Blizzard's list from addon code")
equal(openedRecipe, 3275, "the client opens its own recipe")

-- A burst of window events, as a profession opening or a craft session sends, schedules one deferred pass
-- rather than one per event.
for index = #timers, 1, -1 do
	timers[index] = nil
end
for _ = 1, 10 do
	eventFrame:Event("SKILL_LINES_CHANGED")
end
equal(#timers, 2, "a burst of skill updates schedules one route pass and one tracker refresh, not one per event")

Client.report("route_spec")
