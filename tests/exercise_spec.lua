-- Run from the repository root: luajit tests/exercise_spec.lua
-- Opens every surface the addon registers, under an error trap: the login and world-entry events, every slash
-- command its dispatch lists, every top-level window and tab, every event a frame registered, and all of it again
-- in combat and after a /reload. Any Lua error, anything ns.SafeCall caught, anything handed to geterrorhandler or a
-- protected frame changed in combat fails the spec.
local Client = dofile("tests/client.lua")

local ADDON = "SkillUpForever"
local equal = Client.equal

-- The client state a surface needs to draw something real: one known profession with a recipe, a vendor and a
-- merchant, and the profession window's own frames. None of it is the real client's data.
local DATA = {
	Thresholds = { [1] = { 1, 30, 45, 60 } },
	RecipeData = {
		[1] = {
			skillLine = 129,
			reagents = { { itemID = 3, quantity = 1 } },
			output = { itemID = 50, quantity = 1 },
		},
	},
	TrainerFees = {},
	TrainerRanks = { [129] = {} },
	ItemSellPrices = {},
	GatheredBy = {},
	VendorPrices = { [3] = 10 },
	ProfessionTrainers = {},
}

local function Prepare(c)
	local G = c.G
	c.professions = { { name = "First Aid", icon = 1, rank = 40, max = 75, id = 129 } }
	c.spells[1] = "Linen Bandage"
	c.known[1] = true
	c.items[3] = { name = "Linen Cloth", sell = 10 }
	c.items[50] = { name = "Linen Bandage", sell = 5 }
	c.live[1] = {
		info = {
			recipeID = 1,
			name = "Linen Bandage",
			learned = true,
			maxTrivialLevel = 60,
			numSkillUps = 1,
			relativeDifficulty = G.Enum.TradeskillRelativeDifficulty.Optimal,
			canSkillUp = true,
		},
		requirements = {},
	}
	c.skillLines = {
		{ skillID = 0, name = "Weapons", isHeader = true, isCollapsed = false, rank = 0 },
		{ skillID = 43, name = "One-Handed Swords", isHeader = false, isCollapsed = false, rank = 1 },
	}
	c.maps[c.player.instance] = { mapID = 1414, name = "Durotar" }
	c.areas[1414] = "Durotar"
	c.merchant = { { itemID = 3, price = 10, stackCount = 1, numAvailable = 5 } }
	c.npc = { id = 123, name = "Vendor" }

	-- Native trainer decoration is safe to accept here: the addon reads trainer buttons, never hooks an object.
	G.hooksecurefunc = function()
		return true
	end

	local function Frame(name, parent, template)
		return G.CreateFrame("Frame", name, parent, template)
	end

	local frame = Frame("ProfessionsFrame", G.UIParent)
	local crafting = Frame("CraftingPage", frame)
	local book = Frame("BookPage", frame)
	local recipeList = Frame(nil, crafting)
	recipeList.ScrollBox = Frame(nil, recipeList)
	recipeList.ScrollBox.GetDataProvider = function()
		return nil
	end
	recipeList.ScrollBox.RegisterCallback = function(self, event, callback)
		self.callbacks = self.callbacks or {}
		self.callbacks[event] = callback
	end
	recipeList.IsVisible = function(self)
		return self:IsShown()
	end
	crafting.RecipeList = recipeList
	crafting.SchematicForm = {
		GetRecipeInfo = function()
			return c.live[1].info
		end,
	}
	crafting.CreateAllButton = Frame(nil, crafting)
	frame.CraftingPage, frame.BookPage = crafting, book
	frame.ProfessionsOverviewTab = Frame(nil, frame)
	frame.rightProfessionTabs = {}
	frame.professionInfo = { professionID = 129, professionName = "First Aid" }
	frame.RefreshRightTabs = function() end
	G.ProfessionsFrame = frame

	G.Professions = {
		GetProfessionInfo = function()
			return {
				skillLevel = 40,
				maxSkillLevel = 75,
				displayName = "First Aid",
				skillModifier = 0,
				professionName = "First Aid",
				professionID = 129,
				parentProfessionName = "First Aid",
				parentProfessionID = 129,
			}
		end,
		GetHighestLearnedRecipe = function(info)
			return info
		end,
	}

	local trainer = Frame("ClassTrainerFrame", G.UIParent)
	trainer:Hide()
	trainer.ScrollBox = { ForEachFrame = function() end }
	trainer.skillStepButton = Frame(nil, trainer)
	trainer.skillStepButton:Hide()
	G.ClassTrainerFrame = trainer

	local auctionHouse = Frame("AuctionHouseFrame", G.UIParent)
	auctionHouse:Hide()
	G.AuctionHouseFrame = auctionHouse

	local tooltip = Frame("GameTooltip", G.UIParent)
	tooltip.AddLine = function() end
	tooltip.AddDoubleLine = function() end
	tooltip.SetOwner = function() end
	tooltip.SetMinimumWidth = function() end
	tooltip.GetItem = function()
		return nil
	end
	tooltip.GetOwner = function()
		return nil
	end
	tooltip.IsForbidden = function()
		return false
	end
	G.GameTooltip = tooltip
end

local function Fire(c, event, ...)
	c.Fire(event, ...)
	c.Advance(0)
end

-- The payload the game hands the event. A payload is a list, or a function that reads the client's state.
local EVENT_ARGS = {
	ADDON_LOADED = function()
		return ADDON, true
	end,
	PLAYER_LOGIN = {},
	VARIABLES_LOADED = {},
	PLAYER_ENTERING_WORLD = { false, false },
	PLAYER_REGEN_DISABLED = {},
	PLAYER_REGEN_ENABLED = {},
	TRADE_SKILL_SHOW = {},
	TRADE_SKILL_LIST_UPDATE = {},
	TRADE_SKILL_DATA_SOURCE_CHANGED = {},
	NEW_RECIPE_LEARNED = { 1 },
	SKILL_LINES_CHANGED = {},
	BAG_UPDATE_DELAYED = {},
	ITEM_DATA_LOAD_RESULT = { 3, true },
	PLAYER_LEVEL_UP = { 40, 0, 0, 0, 0 },
	ZONE_CHANGED_NEW_AREA = {},
	MERCHANT_SHOW = {},
	MERCHANT_UPDATE = {},
	MERCHANT_CLOSED = {},
	SPELLS_CHANGED = {},
	TRAIT_CONFIG_UPDATED = { 1 },
	TRAIT_NODE_CHANGED = { 1 },
	DISPLAY_SIZE_CHANGED = {},
	UI_SCALE_CHANGED = {},
	MODIFIER_STATE_CHANGED = { "LSHIFT", "DOWN" },
	GUILD_ROSTER_UPDATE = {},
	GROUP_ROSTER_UPDATE = {},
	PLAYER_MONEY = {},
	TRAINER_CLOSED = {},
	GET_ITEM_INFO_RECEIVED = { 3, true },
	TOOLTIP_DATA_UPDATE = {},
	AUCTION_HOUSE_SHOW = function(c)
		c.G.AuctionHouseFrame:Show()
	end,
	AUCTION_HOUSE_CLOSED = function(c)
		c.G.AuctionHouseFrame:Hide()
	end,
	CHAT_MSG_ADDON = { "WFAStats", "", "GUILD", "Tester" },
	PLAYER_GUILD_UPDATE = {},
	-- Core/SafeCall.lua's frame: another addon's blocked action is not ours to record, and a plain Lua warning names
	-- no folder of ours either, so both pass through the exercise without joining the journal.
	ADDON_ACTION_BLOCKED = { "SomeOtherAddon", "SomeFunction" },
	ADDON_ACTION_FORBIDDEN = { "SomeOtherAddon", "SomeFunction" },
	-- The client's interface style did not change: both sides are the mouse and keyboard style.
	INPUT_DEVICE_INTERFACE_TRANSITION = { 0, 0 },
	LUA_WARNING = { "a harmless warning" },
}

local function EventList(c)
	local events, list = {}, {}
	for _, frame in ipairs(c.frames) do
		for event in pairs(frame.events or {}) do
			if not events[event] then
				events[event] = true
				list[#list + 1] = event
			end
		end
	end
	table.sort(list)
	return list
end

local function Args(event, c)
	local value = EVENT_ARGS[event]
	assert(value, "the exercise spec has no payload for " .. tostring(event))
	if type(value) == "function" then
		return value(c)
	end
	return unpack(value)
end

-- Every action runs under this: a raised error, a SafeCall the addon caught, the client's error handler or a
-- protected write in combat all fail with the action that caused it.
local function Trapped(c, label, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		error(label .. ": " .. tostring(err), 0)
	end
	local caught = c.ns.CaughtErrors()
	if #caught > 0 then
		local last = caught[#caught]
		error(label .. ": SafeCall caught [" .. last.label .. "] " .. last.message, 0)
	end
	if #c.errors > 0 then
		error(label .. ": error handler got " .. c.errors[#c.errors], 0)
	end
	if c.protectedCalls and #c.protectedCalls > 0 then
		error(label .. ": a protected frame was changed in combat", 0)
	end
end

local function Run(c, label, fn, ...)
	Trapped(c, label, fn, ...)
end

-- Every slash command the addon registers. The table is the dispatch: its words, aliases and listed arguments are
-- the messages a player can send, and its help lines are what /su help prints.
local function Commands(c)
	local handlers = {}
	for key in pairs(c.G.SlashCmdList) do
		handlers[#handlers + 1] = key
	end
	table.sort(handlers)
	equal(#handlers > 0, true, "the addon registers a slash command")

	local commands = c.ns.SlashCommands
	equal(#commands > 0, true, "the slash dispatch has commands")

	local messages = {}
	for _, entry in ipairs(commands) do
		equal(type(entry.word) == "string" and type(entry.handler) == "function", true, "a slash entry has a word")
		messages[#messages + 1] = entry.word
		for _, alias in ipairs(entry.aliases or {}) do
			messages[#messages + 1] = alias
		end
		for _, argument in ipairs(entry.arguments or {}) do
			messages[#messages + 1] = entry.word .. " " .. argument
		end
	end
	messages[#messages + 1] = "not a command"

	for _, message in ipairs(messages) do
		Run(c, "slash " .. message, function()
			c.G.SlashCmdList.SKILLUPFOREVER(message)
		end)
	end

	-- Help is built from the same table, in its order, and prints every entry that carries a help line.
	local before = #c.chat
	Run(c, "slash help", function()
		c.G.SlashCmdList.SKILLUPFOREVER("help")
	end)
	local printed = {}
	for index = before + 1, #c.chat do
		printed[#printed + 1] = c.chat[index]
	end
	local documented = {}
	for _, entry in ipairs(commands) do
		if entry.help then
			documented[#documented + 1] = entry
		end
	end
	equal(#printed, #documented, "help prints one line per documented command")
	for index, entry in ipairs(documented) do
		equal(printed[index] and printed[index]:find(entry.help, 1, true) ~= nil, true, "help lists " .. entry.word)
	end

	-- Forever Leaderboards' own message is a board key, or empty to toggle; every board it has is a tab.
	local boards = { overall = true }
	local api = c.ns.Leaderboards
	if api and api.Boards then
		for _, board in ipairs(api:Boards()) do
			boards[board.key] = true
		end
	end
	local keys = {}
	for key in pairs(boards) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		Run(c, "slash /flb " .. key, function()
			c.G.SlashCmdList.FOREVERLEADERBOARDS(key)
		end)
	end
	Run(c, "slash /flb unknown", function()
		c.G.SlashCmdList.FOREVERLEADERBOARDS("not-a-board")
	end)
	Run(c, "slash /flb toggle", function()
		c.G.SlashCmdList.FOREVERLEADERBOARDS("")
	end)
end

-- The addon's own surfaces, opened and closed the way a click does it.
local function Surfaces(c)
	local ns, G = c.ns, c.G
	local function ButtonIn(frame, text)
		for _, child in ipairs({ frame:GetChildren() }) do
			if
				child.text
				and child.scripts
				and child.scripts.OnClick
				and (child.text == text or child.text:sub(1, #text) == text)
			then
				return child
			end
		end
	end

	-- The Professions window itself, then its one SkillUp side tab and the page tabs under it.
	Run(c, "professions window show", function()
		G.ProfessionsFrame:Show()
		assert(G.ProfessionsFrame:IsShown(), "the Professions window is shown")
	end)
	Run(c, "skillup side tab", function()
		local tab = ns.Pages.SideTab()
		assert(tab and tab.mouseUp, "the SkillUp side tab is created")
		tab.mouseUp(tab, "LeftButton", true)
		assert(tab:IsChecked(), "the SkillUp side tab is selected")
	end)
	Run(c, "page hide", function()
		ns.Pages.Close(ns.LastSkillUpPage() or "route")
		assert(not ns.Pages.SideTab():IsChecked(), "the side tab is cleared")
	end)
	Run(c, "route tab", function()
		local tab = ns.Pages.BottomTab("route")
		assert(tab and tab.scripts and tab.scripts.OnClick, "the route page tab is created")
		tab.scripts.OnClick(tab)
		assert(ns.Pages.SideTab():IsChecked(), "the side tab is selected")
	end)
	Run(c, "route page hide", function()
		ns.Pages.Close("route")
		assert(not ns.Pages.SideTab():IsChecked(), "the side tab is cleared")
	end)
	Run(c, "gear setting on", function()
		c.SetSetting("showGearTab", true)
	end)
	Run(c, "gear tab", function()
		local tab = ns.Pages.BottomTab("gear")
		assert(tab and tab.scripts and tab.scripts.OnClick, "the gear page tab is created")
		tab.scripts.OnClick(tab)
		assert(ns.Pages.SideTab():IsChecked(), "the side tab is selected")
	end)
	Run(c, "gear page hide", function()
		ns.Pages.Close("gear")
		assert(not ns.Pages.SideTab():IsChecked(), "the side tab is cleared")
	end)
	Run(c, "buffs tab", function()
		local tab = ns.Pages.BottomTab("buffs")
		assert(tab and tab.scripts and tab.scripts.OnClick, "the buffs page tab is created")
		tab.scripts.OnClick(tab)
		assert(ns.Pages.SideTab():IsChecked(), "the side tab is selected")
	end)
	Run(c, "buffs page hide", function()
		ns.Pages.Close("buffs")
		assert(not ns.Pages.SideTab():IsChecked(), "the side tab is cleared")
	end)

	-- The settings page, and the shared Forever addons page it carries.
	Run(c, "settings page", function()
		local before = c.settingsOpens or 0
		ns.OpenSettings()
		if c.combat then
			assert((c.settingsOpens or 0) == before, "the settings category waits for combat to end")
		else
			assert((c.settingsOpens or 0) == before + 1, "the settings category is opened through the shared opener")
			assert(c.secureSettingsCalls and c.secureSettingsCalls > 0, "the client's own opener ran securely")
		end
	end)
	Run(c, "family page", function()
		local panel = rawget(G, "ForeverFamilyPanel" .. ADDON)
		assert(panel, "the Forever addons page exists")
		panel:Show()
		assert(panel:IsShown(), "the Forever addons page is shown")
		panel:Hide()
	end)

	-- The report window and the issue composer.
	Run(c, "report window", function()
		ns.Report.Show("exercise report")
		local window = rawget(G, ADDON .. "Report")
		assert(window and window:IsShown(), "the report window is shown")
		window:Hide()
	end)
	Run(c, "issue composer", function()
		ns.Report.Compose("bug")
		local window = rawget(G, ADDON .. "Issue")
		assert(window and window:IsShown(), "the issue composer is shown")
		window:Hide()
	end)

	-- Forever Leaderboards, one tab at a time.
	Run(c, "leaderboards", function()
		ns.Stats.Open()
		local api = ns.Leaderboards
		assert(api and api:IsShown(), "the leaderboards window is shown")
		if api.window and api.window.tabs then
			for _, tab in ipairs(api.window.tabs) do
				if tab.mouseUp then
					tab.mouseUp(tab, "LeftButton", true)
				end
			end
		end
		api:Toggle()
		assert(not api:IsShown(), "the leaderboards window is hidden")
	end)

	-- The shopping list, its copy window, and the merchant's buy confirm.
	Run(c, "shopping list", function()
		ns.OpenShoppingList()
		local window = rawget(G, ADDON .. "ShoppingList")
		assert(window and window:IsShown(), "the shopping list is shown")
		local copy = ButtonIn(window, ns.L["Copy list"])
		assert(copy, "the shopping list's Copy list button exists")
		copy.scripts.OnClick(copy)
		local copied = rawget(G, ADDON .. "ShoppingCopy")
		assert(copied and copied:IsShown(), "the shopping list's copy window is shown")
		copied:Hide()
		window:Hide()
	end)
	Run(c, "merchant buy confirm", function()
		ns.db.trackedProfessions[129] = true
		c.bags[3] = 0
		ns.Changed("merchant")
		c.Advance(0)
		local tab = rawget(G, "SkillUpForeverMerchantTab")
		assert(tab and tab:IsShown(), "the merchant's Reagents tab exists")
		tab.scripts.OnClick(tab)
		local buy = rawget(G, "SkillUpForeverMerchantBuyAll")
		assert(buy and buy:IsShown(), "the tab's Buy all button is shown")
		buy.scripts.OnClick(buy)
		local confirm
		for _, child in ipairs({ G.MerchantFrame:GetChildren() }) do
			if child.Close then
				confirm = child
			end
		end
		assert(confirm and confirm:IsShown(), "the buy confirm is shown")
		confirm.Close.scripts.OnClick(confirm.Close)
		assert(not confirm:IsShown(), "the buy confirm is closed")
	end)

	-- The auction house's bar, drawn only while its own frame is shown.
	Run(c, "auction house", function()
		local auctionHouse = G.AuctionHouseFrame
		assert(auctionHouse, "the auction house frame is present")
		auctionHouse:Show()
		Fire(c, "AUCTION_HOUSE_SHOW")
		assert(auctionHouse:IsShown(), "the auction house is shown")
		auctionHouse:Hide()
		Fire(c, "AUCTION_HOUSE_CLOSED")
		assert(not auctionHouse:IsShown(), "the auction house is hidden")
	end)

	-- The family link windows.
	Run(c, "family link", function()
		local opened = ns.Family.ShowLink(ns.db, "exercise", ADDON, nil)
		local window = rawget(G, "ForeverFamilyLink")
		if c.combat then
			assert(opened == false, "a family link never opens in combat")
		else
			assert(opened and window and window:IsShown(), "the family link window is shown")
			window:Hide()
		end
	end)
	Run(c, "family support", function()
		local opened = ns.Family.ShowSupport()
		local window = rawget(G, "ForeverFamilyLink")
		if c.combat then
			assert(opened == false, "family support never opens in combat")
		else
			assert(opened and window and window:IsShown(), "the family support window is shown")
			window:Hide()
		end
	end)

	-- The objective tracker section the addon attaches.
	local module = rawget(G, "SkillUpForeverObjectiveTracker")
	Run(c, "tracker section show", function()
		assert(module, "the tracker section is created")
		module:Show()
		assert(module:IsShown(), "the tracker section is shown")
	end)
	Run(c, "tracker section hide", function()
		module:Hide()
		assert(not module:IsShown(), "the tracker section is hidden")
	end)

	Run(c, "professions window hide", function()
		G.ProfessionsFrame:Hide()
		assert(not G.ProfessionsFrame:IsShown(), "the Professions window is hidden")
	end)
end

local function Login(c)
	for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "VARIABLES_LOADED", "PLAYER_ENTERING_WORLD" }) do
		Run(c, "event " .. event, Fire, c, event, Args(event, c))
	end
	Run(c, "world entry callbacks", function()
		c.EnterWorld()
		c.Advance(0)
	end)
end

-- Every event any frame registered, once each, with the game's payload. A later event that registers a frame
-- with another event is picked up on the next pass.
local function Events(c)
	local fired = {
		ADDON_LOADED = true,
		PLAYER_LOGIN = true,
		VARIABLES_LOADED = true,
		PLAYER_ENTERING_WORLD = true,
	}
	while true do
		local progressed = false
		for _, event in ipairs(EventList(c)) do
			if not fired[event] then
				fired[event] = true
				progressed = true
				Run(c, "event " .. event, Fire, c, event, Args(event, c))
			end
		end
		if not progressed then
			return
		end
	end
end

-- One whole pass: commands, surfaces and events, out of combat and then in it.
local function Pass(c)
	Login(c)
	Surfaces(c)
	Commands(c)
	Events(c)

	c.combat = true
	Run(c, "combat began", Fire, c, "PLAYER_REGEN_DISABLED")
	Surfaces(c)
	Commands(c)
	c.combat = false
	Run(c, "combat ended", Fire, c, "PLAYER_REGEN_ENABLED")
end

local function ClientFor(saved)
	local c = Client.load({ saved = saved, boot = false, data = DATA })
	Prepare(c)
	c.allowErrors = true
	c.Boot()
	c.LoadAddOn("Blizzard_Professions")
	c.LoadAddOn("Blizzard_TrainerUI")
	return c
end

local c = ClientFor(nil)
Pass(c)

-- Reload: the table the addon saved is what the next load starts from.
local saved = c.G.SkillUpForeverDB
assert(type(saved) == "table", "the addon saved its settings")
local reloaded = ClientFor(saved)
Pass(reloaded)

Client.report("exercise")
