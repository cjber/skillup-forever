-- The stub game client the specs share: `local Client = dofile("tests/client.lua")`, from the repository root.
-- Client.load loads ForeverCore first, as the client does, then the files SkillUpForever.toc lists, in its order,
-- against stubs of the client API the addons call, and returns a handle. A spec sets what the client holds
-- (professions, bags, a merchant, Auctionator's prices, the clock), fires the game's events, and asserts on what the
-- addon produces. Nothing on `ns` is faked.
local Client = {}
local ForeverCore = dofile("tests/forever_core.lua")

local ADDON = "SkillUpForever"

-- The addon's TOC fields, as C_AddOns.GetAddOnMetadata reports them: a spec reads the same declared values the
-- client gives the addon at load.
---@return table<string, string>
function Client.TocMetadata()
	local metadata = {}
	local file = io.open(ADDON .. ".toc", "r")
	if not file then
		return metadata
	end
	for line in file:lines() do
		local key, value = line:match("^##%s*([^:]+):%s*(.-)%s*$")
		if key then
			metadata[key] = value
		end
	end
	file:close()
	return metadata
end

local TOC = Client.TocMetadata()

local checks = 0
function Client.equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

---@param spec string
function Client.report(spec)
	print(spec .. ": " .. checks .. " checks passed")
end

local function noop() end

-- A synthetic QuestieDB with the public shape Integrations/Questie.lua reads; none of it is the real
-- database's data. `db` is what it knows, and a spec may change it between reads:
--   items = { [id] = { vendors, quests, drops, class, teaches } }
--   npcs = { [id] = { name, spawns = { [area] = { { x, y } } }, zone, side } }, side "A", "H", "AH" or nil
--   quests = { [id] = { name, races, starts } }, starts the NPCs who give it
--   areas = { [area] = uiMapID }, parents = { [area] = parent area }; contract (2 unless set); a field
--   named in `without` is left out of the schema. `db.reads` counts the records read.
function Client.QuestieDB(db)
	db.reads = 0
	local function Keys(fields)
		local keys = {}
		for index, field in ipairs(fields) do
			keys[field] = db.without ~= field and index or nil
		end
		return keys
	end
	local function Source(map)
		local parts = {}
		for key, value in pairs(map or {}) do
			parts[#parts + 1] = string.format("[%d]=%d", key, value)
		end
		return "return {" .. table.concat(parts, ",") .. "}"
	end
	local function Entity(rows, read)
		return {
			GetAll = function(id, fields)
				db.reads = db.reads + 1
				local row = rows()[id]
				if not row then
					return nil
				end
				local values = { n = #fields }
				for index, field in ipairs(fields) do
					values[index] = read(row, field)
				end
				return values
			end,
			GetAllIds = function()
				local ids = {}
				for id in pairs(rows()) do
					ids[#ids + 1] = id
				end
				table.sort(ids)
				return ids
			end,
		}
	end
	local item = { vendors = "vendors", questRewards = "quests", npcDrops = "drops", teachesSpell = "teaches" }
	local npc = { name = "name", spawns = "spawns", zoneID = "zone", friendlyToFaction = "side" }
	local quest = { name = "name", requiredRaces = "races" }
	return {
		RequireContract = function(required)
			return required == (db.contract or 2), "QuestieDB contract mismatch"
		end,
		Meta = {
			ItemMeta = { itemKeys = Keys({ "vendors", "questRewards", "npcDrops", "class", "teachesSpell" }) },
			NpcMeta = { npcKeys = Keys({ "name", "spawns", "zoneID", "friendlyToFaction" }) },
			QuestMeta = { questKeys = Keys({ "name", "startedBy", "requiredRaces" }) },
		},
		Support = {
			Get = function(name)
				return name == "ZoneDB"
						and {
							private = {
								areaIdToUiMapId = Source(db.areas),
								subZoneToParentZone = Source(db.parents),
							},
						}
					or nil
			end,
		},
		Item = Entity(function()
			return db.items or {}
		end, function(row, field)
			return field == "class" and (row.class or 9) or row[item[field]]
		end),
		Npc = Entity(function()
			return db.npcs or {}
		end, function(row, field)
			return row[npc[field]]
		end),
		Quest = Entity(function()
			return db.quests or {}
		end, function(row, field)
			if field == "startedBy" then
				return { row.starts }
			end
			return row[quest[field]]
		end),
	}
end

-- A synthetic AtlasLoot: `db.recipes` = { [scroll item] = { profession, skill, recipe } } as its recipe
-- module keeps them (one scroll a recipe when asked by recipe: the highest item wins, as its reverse map
-- overwrites), and `db.drops` = { [npc] = { [item] = chance % } }.
function Client.AtlasLoot(db)
	return {
		Data = {
			Recipe = {
				GetRecipeData = function(itemID)
					return db.recipes[itemID]
				end,
				GetRecipeForSpell = function(spellID)
					local found
					for itemID, row in pairs(db.recipes) do
						if row[3] == spellID and (not found or itemID > found) then
							found = itemID
						end
					end
					return found
				end,
			},
			Droprate = {
				GetData = function(_, npcID, itemID)
					return db.drops and db.drops[npcID] and db.drops[npcID][itemID]
				end,
			},
		},
	}
end

-- options: data (ns tables that replace the bundled Data/*.lua ones of the same name), saved (SkillUpForeverDB),
-- auctionator (false for a client without it), trackerManager (false for a client without Blizzard's tracker
-- manager), boot (false to stop before the addon's ADDON_LOADED; c.Boot() then runs it), questie and atlasLoot
-- (what a synthetic QuestieDB and AtlasLoot hold, as Client.QuestieDB and Client.AtlasLoot take it; a client
-- has neither without them), build (the client build GetBuildInfo reports).
-- Globals the addon reads by plain name that the harness does not stub: each is optional, so a client without it
-- reads nil. Each entry says who defines it. Anything else the addon reads must be stubbed in this file first, so a
-- client API it calls is either here or in the pinned annotations.
local OPTIONAL_GLOBALS = {
	-- Core/Core.lua: the Legacy talent API, which only a client with the Legacy system has.
	C_Traits = true,
	-- ForeverCore's saved table, made by its own ADDON_LOADED handler.
	ForeverCoreDB = true,
	-- ForeverCore's one tracker column: present only when an addon that still vendors an older copy loaded first,
	-- which its own UI/TrackerHost.lua then adopts instead of drawing a second column.
	ForeverTrackerHost = true,
	-- ForeverCore's tracker host: the client's Edit Mode frame, present only once Edit Mode has loaded.
	EditModeManagerFrame = true,
	-- ForeverCore's context menu and minimap button: frames present only once their Blizzard addon has loaded.
	WorldMapFrame = true,
	Minimap = true,
	MinimapCluster = true,
	-- Core/SafeCall.lua: BugGrabber, when that error display is installed, so its captures join the journal.
	BugGrabber = true,
	-- SavedVariables: the addon's own table, nil before the client loads it or when its file is missing.
	SkillUpForeverDB = true,
	-- Questie: its addon table and database, present only when Questie is installed and enabled.
	Questie = true,
	LibQuestieDB = true,
	-- AtlasLoot: its addon table, present only when AtlasLoot Classic is installed and enabled.
	AtlasLoot = true,
	-- Auctionator: its addon table, present only when Auctionator is installed and enabled.
	Auctionator = true,
	-- TradeSkillMaster: its public API table, present only when TSM is installed and enabled.
	TSM_API = true,
	-- TomTom: its addon table, present only when TomTom is installed and enabled.
	TomTom = true,
	-- Shortest Path Forever: its addon table, present only when that Forever addon is installed.
	ShortestPathForever = true,
	-- Syndicator: its addon table, present only when Syndicator is installed and enabled.
	Syndicator = true,
	-- AuctionHouseFrame: Blizzard's auction house frame, present once Blizzard_AuctionHouseUI loads.
	AuctionHouseFrame = true,
}

-- A global the addon reads that this stub never set is a spec failure, not nil. Lua's own standard library stays
-- readable through the host's _G; only names that exist there are handed on.
---@param _ table
---@param key string
local function ReadGlobal(_, key)
	local value = rawget(_G, key)
	if value ~= nil then
		return value
	end
	if OPTIONAL_GLOBALS[key] then
		return nil
	end
	error("unknown global read by the addon: " .. tostring(key), 2)
end

function Client.load(options)
	options = options or {}
	-- The host's globals are copied in once, so the addon's reads of the standard library are plain table reads and
	-- the bench times the addon rather than this lookup; ReadGlobal only runs for a name the copy lacks.
	local G = {}
	for key, value in pairs(_G) do
		G[key] = value
	end
	setmetatable(G, { __index = ReadGlobal })
	local c = {
		G = G,
		ns = {},
		now = 0,
		build = options.build or "70205",
		frames = {},
		chat = {},
		-- { name, icon, rank, max, id, modifier } in spellbook order; `id` is what the client reports for it.
		professions = {},
		spells = {}, -- [spellID] = name
		spellDescriptions = {}, -- [spellID] = the game's own description of its effect
		spellCached = {}, -- [spellID] = true: the client's spell data has loaded
		spellLoads = {}, -- [spellID] = the callbacks waiting for that data
		known = {}, -- [spellID] = true: in the spellbook
		skillLines = {}, -- { skillID, name, isHeader, rank, ... } in the client's skill-line order
		traitConfigs = {}, -- [treeID] = configID: the Legacy talent tree's saved config
		traitNodes = {}, -- [configID] = { [nodeID] = { activeRank, currentRank, maxRanks } }
		items = {}, -- [itemID] = { name, sell }; a missing field is item data the client has not loaded
		bags = {}, -- [itemID] = count
		schematics = {}, -- [recipeID] = { reagents = { { itemID, quantity } }, output = itemID }: the open window's
		-- [recipeID] = { info = { maxTrivialLevel, numSkillUps, learned, relativeDifficulty }, requirements = { ... } }:
		-- what the client's own recipe read answers, empty for a recipe it says nothing about.
		live = {},
		craftable = 999, -- what C_TradeSkillUI.GetCraftableCount answers
		auction = {}, -- [itemID] = copper, as Auctionator last saw it
		auctionAge = 0, -- whole days
		auctionAutoscan = nil, -- Auctionator's "scan when the auction house opens" option
		shoppingLists = {}, -- [list name] = the searches Auctionator was last given
		auctionSearches = {}, -- each MultiSearchAdvanced call's searches, in order
		merchant = nil, -- { { itemID, price, stackCount, numAvailable, ... } } while a merchant window is open
		npc = nil, -- { id, name }: who the player is dealing with, the client's "npc" unit
		money = 1000000,
		level = 60,
		player = { name = "Tester", realm = "Realm", faction = "Alliance", x = 0, y = 0, instance = 0 },
		maps = {}, -- [world instance] = { mapID, name }: the continent's one zone map
		areas = {}, -- [areaID] = name
		opened = {}, -- profession IDs passed to OpenTradeSkill
		purchased = {}, -- { index, count } per BuyMerchantItem call
		requested = {}, -- [itemID] = true: item data asked for
		tradeSkillNames = {}, -- [skillLine] = the display name the client gives a profession
		tracker = {}, -- modules attached to the shared tracker host
	}
	G._G = G

	--[[ Frames ]]

	-- Scripts, events, visibility and text are kept; any other setter is accepted and ignored. A method that is
	-- none of those is nil, so a new client call the addon makes fails here until it is stubbed on purpose.
	local Methods = {}
	local frameMeta = {
		__index = function(_, key)
			if Methods[key] then
				return Methods[key]
			elseif type(key) == "string" and (key:find("^Set") or key:find("^Clear") or key:find("^Enable")) then
				return noop
			end
		end,
	}
	local function NewFrame(name, parent)
		local frame = setmetatable({
			name = name,
			parent = parent,
			scripts = {},
			hooks = {},
			children = {},
			events = {},
			shown = true,
		}, frameMeta)
		if parent and parent.children then
			parent.children[#parent.children + 1] = frame
		end
		c.frames[#c.frames + 1] = frame
		if name then
			G[name] = frame
		end
		return frame
	end
	-- A protected frame's visibility, enabled state and attributes cannot change in combat; a write is recorded so
	-- the exercise spec can fail on it.
	local function Guarded(frame)
		if frame.protected and c.combat then
			c.protectedCalls = c.protectedCalls or {}
			c.protectedCalls[#c.protectedCalls + 1] = frame
		end
	end
	-- The client calls an edit box's focus-gained handler with the player-input flag as a second argument, so a
	-- bare widget method handed to SetScript receives it in its own first parameter (#269, #622).
	local SCRIPT_ARGS = { OnEditFocusGained = { true } }
	local function Scripts(frame, name)
		local args = SCRIPT_ARGS[name]
		local function Call(handler)
			if args then
				handler(frame, unpack(args))
			else
				handler(frame)
			end
		end
		local script = frame.scripts[name]
		if script then
			Call(script)
		end
		for _, hooked in ipairs((frame.hooks or {})[name] or {}) do
			Call(hooked)
		end
	end
	function Methods:RegisterEvent(event)
		self.events[event] = true
	end
	function Methods:UnregisterEvent(event)
		self.events[event] = nil
	end
	function Methods:UnregisterAllEvents()
		self.events = {}
	end
	function Methods:SetScript(name, fn)
		self.scripts[name] = fn
	end
	function Methods:GetScript(name)
		return self.scripts[name]
	end
	function Methods:IsVisible()
		return self.shown ~= false
	end
	function Methods:IsMouseOver()
		return self.mouseOver == true
	end
	-- A scroll bar's percentage, and the callbacks ScrollBarMixin triggers when it moves.
	function Methods:SetScrollPercentage(percentage)
		self.scrollPercentage = percentage
	end
	function Methods:GetScrollPercentage()
		return self.scrollPercentage or 0
	end
	function Methods:RegisterCallback(event, callback, owner)
		self.callbacks = self.callbacks or {}
		self.callbacks[event] = self.callbacks[event] or {}
		table.insert(self.callbacks[event], { callback = callback, owner = owner })
	end
	function Methods:HookScript(name, fn)
		self.hooks[name] = self.hooks[name] or {}
		table.insert(self.hooks[name], fn)
	end
	function Methods:Show()
		Guarded(self)
		local was = self.shown
		self.shown = true
		if not was then
			Scripts(self, "OnShow")
		end
	end
	function Methods:Hide()
		Guarded(self)
		local was = self.shown
		self.shown = false
		if was then
			Scripts(self, "OnHide")
		end
	end
	function Methods:SetShown(shown)
		if shown then
			self:Show()
		else
			self:Hide()
		end
	end
	-- Alpha is how the addon hides Blizzard's own merchant content without changing what Blizzard shows.
	function Methods:SetAlpha(alpha)
		self.alpha = alpha
	end
	function Methods:GetAlpha()
		return self.alpha or 1
	end
	function Methods:SetID(id)
		self.id = id
	end
	function Methods:GetID()
		return self.id
	end
	function Methods:IsShown()
		return self.shown
	end
	function Methods:SetEnabled(enabled)
		Guarded(self)
		self.disabled = not enabled
	end
	function Methods:IsEnabled()
		return not self.disabled
	end
	function Methods.IsAnchoringRestricted()
		return false
	end
	function Methods:SetAttribute(name, value)
		Guarded(self)
		self.attributes = self.attributes or {}
		self.attributes[name] = value
	end
	function Methods:SetText(text)
		self.text = text
	end
	function Methods:GetFontString()
		self.fontString = self.fontString or NewFrame(nil, self)
		return self.fontString
	end
	function Methods.GetTextWidth()
		return 100
	end
	function Methods.GetStringWidth()
		return 100
	end
	function Methods.GetStringHeight()
		return 20
	end
	function Methods:SetChecked(checked)
		self.checked = checked and true or false
	end
	function Methods:GetChecked()
		return self.checked == true
	end
	function Methods:IsChecked()
		return self.checked == true
	end
	-- A font string keeps its text like a frame does.
	function Methods:CreateFontString()
		return NewFrame(nil, self)
	end
	function Methods:CreateTexture()
		return NewFrame(nil, self)
	end
	-- A mask is a region too; a texture keeps the masks drawn over it, and a status bar its fill texture, so a spec
	-- can check what shapes a fill.
	function Methods:CreateMaskTexture()
		return NewFrame(nil, self)
	end
	function Methods:AddMaskTexture(mask)
		self.masks = self.masks or {}
		self.masks[#self.masks + 1] = mask
	end
	function Methods:SetStatusBarTexture(texture)
		self.statusBarTexture = texture
	end
	function Methods:GetStatusBarTexture()
		return self.statusBarTexture
	end
	-- The atlas a texture was given, so a spec can check which art it draws.
	function Methods:GetAtlas()
		return self.atlas
	end
	function Methods:SetTexCoord(...)
		self.texCoord = { ... }
	end
	function Methods:SetAtlas(atlas)
		self.atlas = atlas
	end
	function Methods:SetTexture(texture)
		self.texture = texture
	end
	function Methods:GetTexture()
		self.texture = self.texture or NewFrame(nil, self)
		return self.texture
	end
	function Methods:GetText()
		return self.text or ""
	end
	-- Anchors as { point, relativeTo, relativePoint, x, y }, the latest first visit a frame's point is set.
	function Methods:SetPoint(point, relativeTo, relativePoint, x, y)
		if type(relativeTo) == "number" then
			point, relativeTo, relativePoint, x, y = point, nil, nil, relativeTo, relativePoint
		end
		self.points = self.points or {}
		table.insert(self.points, 1, { point, relativeTo, relativePoint, x or 0, y or 0 })
	end
	function Methods:ClearAllPoints()
		self.points = {}
	end
	function Methods:SetWidth(width)
		self.width = width
	end
	function Methods:SetHeight(height)
		self.height = height
	end
	function Methods:SetSize(width, height)
		self.width, self.height = width, height
	end
	function Methods:GetParent()
		return self.parent
	end
	function Methods:GetName()
		return self.name
	end
	function Methods:GetChildren()
		return unpack(self.children or {})
	end
	function Methods:SetParent(parent)
		self.parent = parent
	end
	function Methods:GetWidth()
		return self.width or 100
	end
	function Methods:GetHeight()
		return self.height or 20
	end
	function Methods:GetSize()
		return self:GetWidth(), self:GetHeight()
	end
	function Methods:GetLeft()
		return self.left or 0
	end
	function Methods:GetTop()
		return self.top or self:GetHeight()
	end
	function Methods:GetRight()
		return self:GetLeft() + self:GetWidth()
	end
	function Methods:GetBottom()
		return self:GetTop() - self:GetHeight()
	end
	function Methods:GetCenter()
		return self:GetLeft() + self:GetWidth() / 2, self:GetTop() - self:GetHeight() / 2
	end
	function Methods:GetNumPoints()
		return self.points and #self.points or 0
	end
	function Methods:GetPoint(index)
		local point = self.points and self.points[index or 1]
		return point and unpack(point) or nil
	end
	function Methods:GetFrameLevel()
		return self.level or 1
	end
	function Methods:SetFrameLevel(level)
		self.level = level
	end
	function Methods:GetFrameStrata()
		return self.strata or "MEDIUM"
	end
	function Methods:SetFrameStrata(strata)
		self.strata = strata
	end
	function Methods:GetScale()
		return self.scale or 1
	end
	function Methods:GetEffectiveScale()
		return self.scale or 1
	end
	-- The click handler a side tab's template calls on a left mouse-up.
	function Methods:SetCustomOnMouseUpHandler(fn)
		self.mouseUp = fn
	end
	-- A dropdown's menu builder: the client calls it when the player opens the menu, with a root to fill.
	function Methods:SetupMenu(fn)
		self.menuSetup = fn
	end
	function Methods:GenerateMenu()
		if self.menuSetup then
			self.menuSetup(self, {
				SetScrollMode = noop,
				CreateRadio = noop,
				CreateDivider = noop,
				CreateButton = noop,
				CreateTitle = noop,
			})
		end
	end
	-- The report window's stock frame and edit box: its title, portrait, focus and selection. c.focus is the edit
	-- box with the keyboard focus, and `highlighted` the text selected in it.
	function Methods:SetTitle(title)
		self.title = title
	end
	function Methods:GetPortrait()
		self.portrait = self.portrait or NewFrame(nil, self)
		return self.portrait
	end
	-- Focusing fires the client's own focus-gained script, as the game does, so a spec exercises the handler
	-- rather than only setting the method's reference (#622).
	function Methods:SetFocus()
		local was = self.focused == true
		c.focus = self
		self.focused = true
		if not was then
			Scripts(self, "OnEditFocusGained")
		end
	end
	function Methods:HasFocus()
		return self.focused == true
	end
	function Methods:ClearFocus()
		self.focused = false
	end
	-- HighlightText takes an optional start and stop character index; the client validates both, so a handler's
	-- own second argument passed here as `start` raises instead of passing silently (#622).
	function Methods:HighlightText(start, stop)
		if start ~= nil and type(start) ~= "number" then
			error("bad argument #2 to 'HighlightText' (outside of expected range -2147483648 to 2147483647)", 2)
		end
		if stop ~= nil and type(stop) ~= "number" then
			error("bad argument #3 to 'HighlightText' (outside of expected range -2147483648 to 2147483647)", 2)
		end
		self.highlighted = self.text
	end
	Methods.RegisterForDrag, Methods.StartMoving, Methods.StopMovingOrSizing = noop, noop, noop
	function Methods:RegisterForClicks(...)
		self.clicks = { ... }
	end

	-- What the tracker section's stock template gives it; the shared host lays it out with these.
	local TrackerModule = {}
	function TrackerModule:MarkDirty()
		self.dirty = (self.dirty or 0) + 1
	end
	-- Blizzard's ObjectiveTrackerModuleMixin:Update: no layout in combat, then the section draws its rows.
	function TrackerModule:Update(availableHeight)
		if not self:CanUpdate() then
			return
		end
		self.availableHeight = availableHeight or 0
		self:LayoutContents()
	end
	function TrackerModule:GetContentsHeight()
		return self.contentsHeight or 0
	end
	function TrackerModule:GetBlock(id)
		local block = { id = id, lines = {}, SetHeader = noop }
		function block.AddObjective(_, key, text)
			local frame = NewFrame()
			block.lines[#block.lines + 1] = { key = key, text = text, frame = frame }
			return frame
		end
		self.blocks[#self.blocks + 1] = block
		return block
	end
	function TrackerModule.LayoutBlock()
		return true
	end

	-- The templates this harness knows: the stock ones it builds, plus the virtual templates an addon's XML defines
	-- as ForeverCore.load registers them. A template registered from XML is built as the stock template it inherits,
	-- which is what the client's own template loader gives a frame.
	local TEMPLATES = {
		-- Blizzard's objective line, the stock template ForeverCore's interactive line inherits.
		ObjectiveTrackerLineTemplate = { type = "Frame" },
	}
	---@param template { name: string, type: string, inherits?: string }
	function G.RegisterTemplate(template)
		TEMPLATES[template.name] = { type = template.type, inherits = template.inherits }
	end

	-- Templates the Forever client never loads, so CreateFrame fails on them as the game does. The list holds the
	-- templates an addon has reached for, not the client's whole Vanilla-only set; add one when a Mainline file no
	-- longer defines what an older file did.
	local MISSING_TEMPLATES = {
		-- Vanilla only: the Mainline MerchantFrame's MerchantFrameTab1/2 inherit PanelTabButtonTemplate (#437).
		CharacterFrameTabButtonTemplate = true,
	}
	G.CreateFrame = function(_, name, parent, template)
		if type(template) == "string" then
			for inherited in template:gmatch("[^,]+") do
				inherited = inherited:match("^%s*(.-)%s*$")
				if MISSING_TEMPLATES[inherited] then
					error(string.format("CreateFrame(): Couldn't find inherited node '%s'", inherited), 2)
				end
			end
		end
		local stock = template
		if type(template) == "string" and TEMPLATES[template] then
			stock = TEMPLATES[template].inherits or template
		end
		local frame = NewFrame(name, parent)
		frame.template = template
		-- NumericInputSpinnerTemplate's XML gives its box the two arrow buttons and their wheel catcher.
		if template == "NumericInputSpinnerTemplate" then
			frame.IncrementButton = NewFrame(nil, frame)
			frame.DecrementButton = NewFrame(nil, frame)
			frame.MouseWheelCatcher = NewFrame(nil, frame)
		end
		if stock == "ObjectiveTrackerModuleTemplate" then
			for key, method in pairs(TrackerModule) do
				frame[key] = method
			end
		elseif stock == "LargeSideTabButtonTemplate" then
			frame.Icon = NewFrame(nil, frame)
		elseif stock == "PanelTabButtonTemplate" then
			-- The regions PanelTemplates_SelectTab and PanelTemplates_DeselectTab toggle, and the text they anchor.
			frame.Text = NewFrame(nil, frame)
			for _, key in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive" }) do
				frame[key] = NewFrame(nil, frame)
			end
		elseif stock == "WowScrollBoxList" then
			function frame:SetDataProvider(provider)
				self.provider = provider
			end
			-- The rows the client would create for a provider: a spec calls this when it needs the row frames.
			function frame:RenderRows()
				if not (frame.elementFactory and frame.provider and frame.provider.rows) then
					return
				end
				for _, elementData in ipairs(frame.provider.rows) do
					frame.elementFactory(function(rowTemplate, initialize)
						local row = NewFrame(nil, self)
						row.template = rowTemplate
						if initialize then
							initialize(row, elementData)
						end
					end, elementData)
				end
			end
		elseif stock == "ScrollFrameTemplate" then
			-- The template's own scroll bar child, which the shared context menu shows when it overflows.
			frame.ScrollBar = NewFrame(nil, frame)
		elseif stock == "MinimalScrollBar" then
			-- The minimal bar's own parts, which a horizontal bar re-anchors and the client's mixin drives.
			frame.Track = NewFrame(nil, frame)
			for _, key in ipairs({ "Begin", "End", "Middle" }) do
				frame.Track[key] = NewFrame(nil, frame.Track)
			end
			frame.Track.Thumb = NewFrame(nil, frame.Track)
			for _, key in ipairs({ "Begin", "End", "Middle" }) do
				frame.Track.Thumb[key] = NewFrame(nil, frame.Track.Thumb)
			end
			frame.Back = NewFrame(nil, frame)
			frame.Back.Texture = NewFrame(nil, frame.Back)
			frame.Forward = NewFrame(nil, frame)
			frame.Forward.Texture = NewFrame(nil, frame.Forward)
			frame.Track.Thumb.isLocalScrollControl = true
			frame.Back.isLocalScrollControl = true
			frame.Forward.isLocalScrollControl = true
		elseif stock == "ItemButtonTemplate" then
			frame.Icon = NewFrame(nil, frame)
			frame.Count = NewFrame(nil, frame)
		elseif stock == "MerchantItemTemplate" then
			frame.Name = NewFrame(nil, frame)
			local button = NewFrame(nil, frame)
			-- The Mainline template's <ItemButton> is the client's intrinsic ItemButton: its icon is `icon`
			-- (lowercase), named $parentIconTexture, not the older ItemButtonTemplate's `Icon` (#447).
			button.icon = NewFrame(nil, button)
			button.Count = NewFrame(nil, button)
			frame.ItemButton = button
		end
		if type(template) == "string" and template:find("SecureActionButtonTemplate", 1, true) then
			frame.protected = true
		end
		return frame
	end
	-- Blizzard_ItemButton/Shared/ItemButtonTemplate.lua: the icon region an item button carries, whether the
	-- template gave it the Icon key, the intrinsic ItemButton's icon key or only its $parentIconTexture name.
	G.GetItemButtonIconTexture = function(button)
		local name = button:GetName()
		return button.Icon or button.icon or (name and G[name .. "IconTexture"])
	end
	G.UIParent = NewFrame("UIParent")
	G.UIParent:SetPoint("CENTER")
	G.ObjectiveTrackerFrame = NewFrame("ObjectiveTrackerFrame")
	G.MerchantFrame = NewFrame("MerchantFrame")
	G.MerchantFrame.IsShown = function()
		return c.merchant ~= nil
	end
	G.MerchantFrame.selectedTab = 1
	for index = 1, 2 do
		local tab = NewFrame("MerchantFrameTab" .. index, G.MerchantFrame)
		tab:SetID(index)
		tab:SetText(index == 1 and "Merchant" or "Buyback")
	end
	for index = 1, 12 do
		NewFrame("MerchantItem" .. index, G.MerchantFrame)
	end
	NewFrame("MerchantBuyBackItem", G.MerchantFrame)
	NewFrame("MerchantPageText", G.MerchantFrame)
	NewFrame("MerchantPrevPageButton", G.MerchantFrame)
	NewFrame("MerchantNextPageButton", G.MerchantFrame)
	-- The client's tab state: the art and text a PanelTabButtonTemplate carries are what these functions toggle,
	-- so a tab built from another template fails here as it would in game.
	G.PanelTemplates_SelectTab = function(tab)
		tab.selected = true
		tab.Left:Hide()
		tab.Middle:Hide()
		tab.Right:Hide()
		tab.Text:SetPoint("CENTER", tab, "CENTER", 0, tab.selectedTextY or -3)
		tab.LeftActive:Show()
		tab.MiddleActive:Show()
		tab.RightActive:Show()
	end
	G.PanelTemplates_DeselectTab = function(tab)
		tab.selected = false
		tab.Left:Show()
		tab.Middle:Show()
		tab.Right:Show()
		tab.Text:SetPoint("CENTER", tab, "CENTER", 0, tab.deselectedTextY or 2)
		tab.LeftActive:Hide()
		tab.MiddleActive:Hide()
		tab.RightActive:Hide()
	end
	-- The client's own tab sizer: the text's width plus the side art, then the tab is that wide.
	G.PanelTemplates_TabResize = function(tab, padding)
		local width = tab.Text:GetStringWidth() + 20 + (padding or 0)
		tab.Text:SetWidth(math.max(0, width - 40))
		tab:SetWidth(width)
	end
	G.PanelTemplates_SetNumTabs = function(frame, count)
		frame.numTabs = count
	end
	G.DEFAULT_CHAT_FRAME = {
		AddMessage = function(_, message)
			c.chat[#c.chat + 1] = message
		end,
	}
	-- The gamepad interface starts off; a spec turns it on the way the client's own check would report it.
	G.InputUtil = {
		IsGamepadUIEnabled = function()
			return false
		end,
	}
	-- Blizzard's tracker manager is never entered, and no native method is hooked.
	if options.trackerManager ~= false then
		G.ObjectiveTrackerManager = setmetatable({}, {
			__index = function()
				error("native tracker accessed")
			end,
		})
	end
	G.hooksecurefunc = function(target, method, callback)
		if type(target) == "table" and target.isLocalScrollControl and method == "OnButtonStateChanged" then
			target[method] = callback
			return
		end
		error("native methods must stay unhooked")
	end
	G.OBJECTIVE_TRACKER_COLOR = { Complete = "complete" }
	-- Blizzard's quest-tracker mixin and header, which ForeverCore's own optional quest section extends.
	G.QuestObjectiveTrackerMixin = {}
	G.TRACKER_HEADER_QUESTS = "Quests"
	-- The addon-owned frame pools the tracker host builds, and the template reader it asks for a name.
	G.CreateFramePoolCollection = function()
		return {
			GetOrCreatePool = function()
				return {
					Acquire = function()
						return NewFrame(), true
					end,
					Release = noop,
				}
			end,
			Release = noop,
		}
	end
	G.C_XMLUtil = {
		GetTemplateInfo = function(name)
			local template = TEMPLATES[name]
			if template then
				return { type = template.type, inherits = template.inherits }
			end
			return { type = "Frame" }
		end,
	}

	-- The attached sections laid out now: { { id, lines = { { key, text } } } }, top to bottom.
	function c.Tracker()
		local blocks = {}
		for _, module in ipairs(c.tracker) do
			module.blocks = blocks
			module:LayoutContents()
		end
		return blocks
	end

	--[[ Events and time ]]

	-- An event reaches only the frames that registered for it.
	function c.Fire(event, ...)
		for _, frame in ipairs(c.frames) do
			if frame.events[event] and frame.scripts.OnEvent then
				frame.scripts.OnEvent(frame, event, ...)
			end
		end
	end

	-- A click on one of the merchant window's own tabs: it selects the tab, as Blizzard's script does, then runs
	-- the scripts and hooks the addon attached.
	function c.ClickTab(id)
		local tab = G["MerchantFrameTab" .. id]
		G.MerchantFrame.selectedTab = id
		Scripts(tab, "OnClick")
	end

	---@return integer frames how many frames the addon made registered for the event
	function c.Listeners(event)
		local count = 0
		for index = c.coreFrames + 1, #c.frames do
			local frame = c.frames[index]
			count = count + (frame.events[event] and 1 or 0)
		end
		return count
	end

	local timers = {}
	G.GetTime = function()
		return c.now
	end
	-- The mouse cursor in physical pixels; a drag divides it by the dragged area's effective scale.
	G.GetCursorPosition = function()
		return 0, 0
	end
	-- The client's own date for the shared log's lines (Core/Log.lua), fixed so its specs are deterministic.
	G.date = function()
		return "2026-11-08 12:00:00"
	end
	G.GetServerTime = function()
		return 1700000000 + math.floor(c.now)
	end
	G.C_Timer = {
		After = function(delay, fn)
			timers[#timers + 1] = { at = c.now + delay, fn = fn }
		end,
	}

	-- Moves the clock on and runs the timers that came due, earliest first; Advance(0) is the next frame.
	function c.Advance(seconds)
		c.now = c.now + seconds
		while true do
			local due
			for index, timer in ipairs(timers) do
				if timer.at <= c.now and (not due or timer.at < timers[due].at) then
					due = index
				end
			end
			if not due then
				return
			end
			table.remove(timers, due).fn()
		end
	end

	local addons, waiting, afterEvents = {}, {}, {}
	G.EventUtil = {
		ContinueOnAddOnLoaded = function(name, fn)
			if addons[name] then
				fn()
			else
				waiting[name] = waiting[name] or {}
				table.insert(waiting[name], fn)
			end
		end,
		ContinueAfterAllEvents = function(fn)
			afterEvents[#afterEvents + 1] = fn
		end,
	}
	-- A load-on-demand addon (Blizzard_Professions, Blizzard_TrainerUI) arriving.
	function c.LoadAddOn(name)
		addons[name] = true
		for _, fn in ipairs(waiting[name] or {}) do
			fn()
		end
		waiting[name] = nil
	end
	-- The login events everything deferred with ContinueAfterAllEvents waits on.
	function c.EnterWorld()
		for _, fn in ipairs(afterEvents) do
			fn()
		end
	end

	--[[ The character ]]

	G.UnitName = function(unit)
		if unit == "npc" then
			return c.npc and c.npc.name
		end
		return c.player.name
	end
	G.UnitRace = function()
		return "Orc", "Orc"
	end
	G.UnitClass = function()
		return c.player.className or "Shaman", c.player.classFile or "SHAMAN", c.player.classID or 64
	end
	G.UnitGUID = function(unit)
		return unit == "npc" and c.npc and string.format("Creature-0-1-0-0-%d-0000000001", c.npc.id) or nil
	end
	G.GetNormalizedRealmName = function()
		return c.player.realm
	end
	G.GetRealmName = function()
		return c.player.realm
	end
	G.UnitFactionGroup = function()
		return c.player.faction
	end
	G.UnitLevel = function()
		return c.level
	end
	G.IsInGroup = function()
		return c.group ~= nil
	end
	G.IsInRaid = function()
		return c.raid == true
	end
	G.IsInGuild = function()
		return c.guild == true
	end
	G.GetNumGroupMembers = function()
		return c.groupMembers or 0
	end
	G.UnitPosition = function()
		return c.player.x, c.player.y, 0, c.player.instance
	end
	G.InCombatLockdown = function()
		return c.combat == true
	end
	G.GetMoney = function()
		return c.money
	end
	G.GetProfessions = function()
		local indices = {}
		for index in ipairs(c.professions) do
			indices[index] = index
		end
		return unpack(indices)
	end
	G.GetProfessionInfo = function(index)
		local p = c.professions[index]
		return p.name, p.icon, p.rank, p.max, nil, nil, p.id, p.modifier
	end
	G.C_Spell = {
		GetSpellName = function(id)
			return c.spells[id]
		end,
		GetSpellDescription = function(id)
			return c.spellDescriptions[id]
		end,
		GetSpellTexture = function(id)
			return c.spellIcons and c.spellIcons[id] or nil
		end,
	}
	-- The client's spell data handle: its data is cached once a spec says so, and waiters run when it loads.
	G.Spell = {
		CreateFromSpellID = function(_, id)
			return {
				IsSpellDataCached = function()
					return c.spellCached[id] == true
				end,
				ContinueOnSpellLoad = function(_, callback)
					c.spellLoads[id] = c.spellLoads[id] or {}
					table.insert(c.spellLoads[id], callback)
				end,
			}
		end,
	}
	-- The client finished loading a spell's data: its description reads, and the addon's waiters run.
	function c.LoadSpellData(id)
		c.spellCached[id] = true
		local callbacks = c.spellLoads[id] or {}
		c.spellLoads[id] = nil
		for _, callback in ipairs(callbacks) do
			callback()
		end
	end
	G.C_SpellBook = {
		IsSpellKnown = function(id)
			return c.known[id] == true
		end,
	}
	-- The Legacy talent tree: [treeID] = configID, and [configID] = { [nodeID] = node info }.
	G.C_Traits = {
		GetConfigIDByTreeID = function(treeID)
			return c.traitConfigs[treeID]
		end,
		GetNodeInfo = function(configID, nodeID)
			return c.traitNodes[configID] and c.traitNodes[configID][nodeID]
		end,
	}
	G.C_TradeSkillUI = {
		GetRecipeSchematic = function(recipeID)
			local schematic = c.schematics[recipeID]
			if not schematic then
				return nil
			end
			local slots = {}
			for index, reagent in ipairs(schematic.reagents) do
				slots[index] =
					{ reagentType = 0, quantityRequired = reagent[2], reagents = { { itemID = reagent[1] } } }
			end
			return { reagentSlotSchematics = slots, outputItemID = schematic.output, quantityMin = 1 }
		end,
		OpenTradeSkill = function(id)
			c.opened[#c.opened + 1] = id
			return true
		end,
		OpenRecipe = function(recipeID)
			c.opened[#c.opened + 1] = recipeID
		end,
		-- No profession window is open.
		IsTradeSkillLinked = function()
			return false
		end,
		IsTradeSkillGuild = function()
			return false
		end,
		GetBaseProfessionInfo = noop,
		GetAllRecipeIDs = function()
			local ids = {}
			for recipeID in pairs(c.live) do
				ids[#ids + 1] = recipeID
			end
			table.sort(ids)
			return ids
		end,
		GetRecipeInfo = function(recipeID)
			return c.live[recipeID] and c.live[recipeID].info
		end,
		GetRecipeRequirements = function(recipeID)
			return c.live[recipeID] and c.live[recipeID].requirements or {}
		end,
		GetCraftableCount = function()
			return c.craftable
		end,
		-- The client's own name for a profession's skill line, nil for one it does not know.
		GetTradeSkillDisplayName = function(skillLine)
			return c.tradeSkillNames[skillLine]
		end,
	}

	--[[ Items, bags and the merchant ]]

	G.C_Item = {
		GetItemInfo = function(id)
			local item = c.items[id] or {}
			return item.name, nil, nil, nil, nil, nil, nil, nil, nil, nil, item.sell
		end,
		GetItemNameByID = function(id)
			return c.items[id] and c.items[id].name
		end,
		GetItemIconByID = function(id)
			return c.items[id] and c.items[id].icon
		end,
		GetItemQualityByID = function(id)
			return c.items[id] and c.items[id].quality
		end,
		GetItemQualityColor = function()
			return 1, 1, 1, "ffffff"
		end,
		GetItemCount = function(id)
			return c.bags[id] or 0
		end,
		RequestLoadItemDataByID = function(id)
			c.requested[id] = true
		end,
		-- A tool requirement is a localized item name; the client resolves it back to the item.
		GetItemInfoInstant = function(itemInfo)
			if type(itemInfo) == "number" then
				return itemInfo
			end
			for itemID, item in pairs(c.items) do
				if item.name == itemInfo then
					return itemID
				end
			end
		end,
	}
	G.C_CurrencyInfo = {
		GetCoinTextureString = function(copper)
			return copper .. "c"
		end,
	}
	G.C_PaperDollInfo = {
		GetInventorySlotInfo = function()
			return 0, 134400
		end,
	}
	G.GetMerchantNumItems = function()
		return c.merchant and #c.merchant or 0
	end
	G.GetMerchantItemID = function(index)
		return c.merchant[index].itemID
	end
	G.C_MerchantFrame = {
		GetItemInfo = function(index)
			return c.merchant[index]
		end,
	}
	G.GetMerchantItemMaxStack = function()
		return 20
	end
	G.BuyMerchantItem = function(index, count)
		c.purchased[#c.purchased + 1] = { index = index, count = count }
	end

	--[[ Auctionator ]]

	-- The client's addon-message channel, which peer stats shares totals on.
	G.C_ChatInfo = {
		RegisterAddonMessagePrefix = function()
			return true
		end,
		SendAddonMessage = function()
			return 0
		end,
	}

	local scanned = {}
	-- Item:CreateFromItemID and ContinuableContainer are what Auctionator's name lookups need; the
	-- container calls back at once, as it does when every name is already known.
	G.Item = {
		CreateFromItemID = function(itemID)
			return itemID
		end,
	}
	G.ContinuableContainer = {
		Create = function()
			local items = {}
			return {
				AddContinuable = function(_, item)
					items[#items + 1] = item
				end,
				ContinueOnLoad = function(_, callback)
					callback()
				end,
			}
		end,
	}
	if options.auctionator ~= false then
		G.Auctionator = {
			API = {
				v1 = {
					GetAuctionPriceByItemID = function(_, itemID)
						return c.auction[itemID]
					end,
					GetAuctionAgeByItemID = function(_, itemID)
						if type(c.auctionAge) == "table" then
							return c.auctionAge[itemID]
						end
						return c.auctionAge
					end,
					RegisterForDBUpdate = function(_, fn)
						scanned[#scanned + 1] = fn
					end,
					CreateShoppingList = function(_, name, searches)
						c.shoppingLists[name] = searches
					end,
					ConvertToSearchString = function(_, request)
						return string.format("%sx%d", request.searchString, request.quantity)
					end,
					MultiSearchAdvanced = function(_, searches)
						local formatted = {}
						for index, request in ipairs(searches) do
							assert(type(request) == "table", "Auctionator advanced search requires records")
							assert(type(request.searchString) == "string", "Auctionator requires searchString")
							assert(request.isExact == true, "reagent searches must be exact")
							formatted[index] = string.format("%sx%d", request.searchString, request.quantity)
						end
						c.auctionSearches[#c.auctionSearches + 1] = formatted
					end,
				},
			},
			-- Auctionator's own config table, which has no public API contract.
			Config = {
				Options = { AUTOSCAN = "autoscan_2" },
				Get = function()
					return c.auctionAutoscan
				end,
			},
		}
	end
	-- options.tsm = { [itemID] = copper }, what TSM's AuctionDB holds; a spec may change it through c.tsm.
	c.tsm = options.tsm
	if options.tsm then
		G.TSM_API = {
			GetCustomPriceValue = function(_, itemString)
				local copper = c.tsm[tonumber(itemString:match("^i:(%d+)$"))]
				if copper then
					return copper
				end
				return nil, "no value"
			end,
		}
	end
	-- Auctionator finished a scan: its prices are now what c.auction holds.
	function c.AuctionatorScan()
		for _, fn in ipairs(scanned) do
			fn()
		end
	end

	--[[ The map: every spawn of a world instance is the middle of that instance's one zone map ]]

	local function Middle()
		return {
			GetXY = function()
				return 0.5, 0.5
			end,
		}
	end
	local function MapInfo(mapID)
		for _, map in pairs(c.maps) do
			if map.mapID == mapID then
				return { mapID = mapID, name = map.name, mapType = G.Enum.UIMapType.Zone, parentMapID = 0 }
			end
		end
	end
	G.C_Map = {
		-- A zone map covers its continent: a map point is the same numbers as a world one.
		GetWorldPosFromMapPos = function(mapID, point)
			for instance, map in pairs(c.maps) do
				if map.mapID == mapID then
					return instance, {
						GetXY = function()
							return point.x, point.y
						end,
					}
				end
			end
		end,
		GetMapInfo = MapInfo,
		GetAreaInfo = function(areaID)
			return c.areas[areaID]
		end,
		GetBestMapForUnit = function()
			return c.maps[c.player.instance] and c.maps[c.player.instance].mapID
		end,
		GetPlayerMapPosition = Middle,
	}
	G.CreateVector2D = function(x, y)
		return { x = x, y = y }
	end

	-- The client's input interface switch: the harness has the mouse UI on, so the Forever addons page is a canvas.
	G.InputUtil = {
		IsGamepadUIEnabled = function()
			return false
		end,
	}

	--[[ Settings: the stock panel as a table of settings; a change runs the addon's own callback ]]

	local settings = {}
	local function Setting(variable, get, set)
		local setting = { GetValue = get }
		function setting:SetValueChangedCallback(fn)
			self.changed = fn
		end
		function setting.SetValue(_, value)
			set(value)
			if setting.changed then
				setting.changed()
			end
		end
		settings[variable] = setting
		return setting
	end
	local categories = 0
	local function Category()
		categories = categories + 1
		local id = categories
		return {
			GetID = function()
				return id
			end,
		}
	end
	G.Settings = {
		VarType = { Boolean = "boolean", String = "string", Number = "number" },
		RegisterVerticalLayoutCategory = Category,
		RegisterVerticalLayoutSubcategory = Category,
		RegisterCanvasLayoutSubcategory = Category,
		RegisterAddOnCategory = noop,
		RegisterAddOnSetting = function(_, variable, key, db)
			return Setting(variable, function()
				return db[key]
			end, function(value)
				db[key] = value
			end)
		end,
		RegisterProxySetting = function(_, variable, _, _, _, get, set)
			return Setting(variable, get, set)
		end,
		RegisterInitializer = noop,
		CreateCheckbox = noop,
		CreateCheckboxInitializer = noop,
		CreateSliderInitializer = noop,
		CreateSliderOptions = function()
			return { SetLabelFormatter = noop }
		end,
		SetValue = function(variable, value)
			settings[variable]:SetValue(value)
		end,
		NotifyUpdate = noop,
		-- Blizzard's own wrapper runs the restricted client opener in the addon's taint, which the client refuses
		-- and blames on the addon (cjber/forever-core#333); the addon asks the shared secure opener instead.
		OpenToCategory = function()
			error("Settings.OpenToCategory called straight from addon code")
		end,
	}
	-- The client's own restricted settings opener, reached through Core/OpenSettings.lua's secure delegate.
	G.C_SettingsUtil = {
		OpenSettingsPanel = function(categoryID, element)
			c.settingsOpened = categoryID
			c.settingsElement = element
			c.settingsOpens = (c.settingsOpens or 0) + 1
		end,
	}
	-- CreateSecureDelegate wraps a Lua function so a call from addon code runs as the client: count the calls so a
	-- spec can tell the shared opener from the restricted function run directly.
	G.CreateSecureDelegate = function(fn)
		return function(...)
			c.secureSettingsCalls = (c.secureSettingsCalls or 0) + 1
			return fn(...) -- multi-value: the wrapped client function's results pass through
		end
	end
	-- ForeverCore 1.8.0 dispatches the restricted openers through securecallfunction; count those calls the same way.
	G.securecallfunction = function(fn, ...)
		c.secureSettingsCalls = (c.secureSettingsCalls or 0) + 1
		return fn(...) -- multi-value: the client function's results pass through
	end
	G.CreateSettingsButtonInitializer = noop
	G.MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }
	-- The player changing one of the addon's settings in the options panel.
	function c.SetSetting(key, value)
		G.Settings.SetValue(ADDON .. "_" .. key, value)
	end

	--[[ The rest of what the files touch as they load and initialise ]]

	G.Enum = {
		TradeskillRelativeDifficulty = { Optimal = 1, Medium = 2, Easy = 3, Trivial = 4 },
		CraftingReagentType = { Basic = 0 },
		RecipeRequirementType = { SpellFocus = 0, Totem = 1, Area = 2 },
		TooltipDataType = { Item = 0, Unit = 2, Object = 4 },
		UIMapType = { Continent = 2, Zone = 3, Dungeon = 4, Micro = 5 },
		TrainerType = { Tradeskills = 1 },
	}
	G.CreateColor = function(r, g, b)
		return {
			r = r,
			g = g,
			b = b,
			GetRGB = function(self)
				return self.r, self.g, self.b
			end,
		}
	end
	-- The client's own text colours, which Core/Model.lua and the row views read.
	G.RED_FONT_COLOR = G.CreateColor(1, 0.1, 0.1)
	G.DIFFICULT_DIFFICULTY_COLOR = G.CreateColor(1, 0.5, 0.25)
	G.FAIR_DIFFICULTY_COLOR = G.CreateColor(1, 1, 0)
	G.EASY_DIFFICULTY_COLOR = G.CreateColor(0.25, 0.75, 0.25)
	G.TRIVIAL_DIFFICULTY_COLOR = G.CreateColor(0.5, 0.5, 0.5)
	G.GRAY_FONT_COLOR = G.CreateColor(0.6, 0.6, 0.6)
	G.HIGHLIGHT_FONT_COLOR = G.CreateColor(1, 1, 1)
	G.NORMAL_FONT_COLOR = G.CreateColor(1, 0.82, 0)
	-- The client's tooltip helpers; a spec that checks a tooltip's lines replaces the ones it reads.
	G.GameTooltip_Hide = noop
	G.GameTooltip_AddColoredLine = noop
	G.GameTooltip_AddColoredDoubleLine = noop
	G.GameTooltip_AddNormalLine = noop
	G.GameTooltip_AddDisabledLine = noop
	G.GameTooltip_SetTitle = noop
	G.GameTooltip_AddBlankLineToTooltip = noop
	-- A boolean that is secret in a restricted context; nothing the harness creates is secret.
	G.issecretvalue = function()
		return false
	end
	-- [tooltip data type] = the post-calls the addon added, for a spec to run against its own tooltip.
	c.postCalls = {}
	G.TooltipDataProcessor = {
		AddTooltipPostCall = function(kind, call)
			c.postCalls[kind] = c.postCalls[kind] or {}
			table.insert(c.postCalls[kind], call)
		end,
	}
	-- The client's callback registry, which the addon joins from its own code.
	c.callbacks = {}
	G.EventRegistry = {
		RegisterCallback = function(_, event, callback, owner)
			c.callbacks[event] = c.callbacks[event] or {}
			table.insert(c.callbacks[event], { callback = callback, owner = owner })
		end,
		UnregisterCallback = noop,
	}
	-- A scroll box's initializer callback, called for each row as the client makes it.
	G.ScrollUtil = {
		AddInitializedFrameCallback = noop,
	}
	G.Menu = { ModifyMenu = noop }
	G.MenuUtil = { ModifyMenu = noop }
	-- The client's scroll-box list: a view the addon fills with row initialisers, and its data provider.
	G.CreateScrollBoxListLinearView = function()
		local view = {
			SetElementExtent = noop,
			SetElementExtentCalculator = noop,
			SetElementInitializer = noop,
			SetElementFactory = function(self, factory)
				self.elementFactory = factory
			end,
		}
		return view
	end
	G.CreateDataProvider = function(rows)
		return { rows = rows }
	end
	G.ScrollBoxConstants = { RetainScrollPosition = true }
	G.ScrollUtil.InitScrollBoxListWithScrollBar = function(box, _, view)
		box.elementFactory = view and view.elementFactory
	end
	G.GREEN_FONT_COLOR = G.CreateColor(0.1, 1, 0.1)
	G.tContains = function(list, value)
		for _, entry in ipairs(list) do
			if entry == value then
				return true
			end
		end
		return false
	end
	G.C_Trainer = {
		GetTrainerType = function()
			return G.Enum.TrainerType.Tradeskills
		end,
	}
	G.C_Texture = {
		GetAtlasInfo = function()
			return { width = 1, height = 1 }
		end,
	}
	-- The client's skill lines, with SkillLineAttributes' documented fields when a line sets them.
	G.C_SkillInfo = {
		GetNumSkillLines = function()
			return #c.skillLines
		end,
		GetSkillLineInfo = function(index)
			return c.skillLines[index]
		end,
	}
	c.locale = "enUS"
	G.GetLocale = function()
		return c.locale
	end
	G.UNIT_SKINNABLE_LEATHER = "Skinnable"
	G.UNIT_SKINNABLE_HERB, G.UNIT_SKINNABLE_ROCK = "Requires Herbalism", "Requires Mining"
	-- The client's own words for the stat and resistance effects a buff row can name.
	G.SPELL_STAT1_NAME, G.SPELL_STAT2_NAME = "Strength", "Agility"
	G.SPELL_STAT3_NAME, G.SPELL_STAT4_NAME, G.SPELL_STAT5_NAME = "Stamina", "Intellect", "Spirit"
	G.STAT_ATTACK_POWER, G.STAT_ARMOR, G.RESISTANCE_LABEL = "Attack Power", "Armor", "Resistance"
	G.STAT_SPELLDAMAGE, G.STAT_SPELLHEALING = "Spell Damage", "Spell Healing"
	G.STAT_CRITICAL_STRIKE, G.STAT_MOVEMENT_SPEED = "Critical Strike", "Movement Speed"
	G.RESISTANCE1_NAME, G.RESISTANCE2_NAME, G.RESISTANCE3_NAME =
		"Holy Resistance", "Fire Resistance", "Nature Resistance"
	G.RESISTANCE4_NAME, G.RESISTANCE5_NAME, G.RESISTANCE6_NAME =
		"Frost Resistance", "Shadow Resistance", "Arcane Resistance"
	G.SlashCmdList = {}
	-- The game's error handler: one current function, which seterrorhandler replaces and geterrorhandler returns.
	-- Before an addon installs one, the default records the error where the specs look, and an error SafeCall caught
	-- still fails the spec, as it would reach BugSack in game. Dispatching says that default is already recording an
	-- error, so a handler that saves it and forwards to it in the same dispatch records that error once, not twice.
	c.errors = {}
	local dispatching = false
	local function DefaultHandler(message)
		if dispatching then
			return
		end
		dispatching = true
		local text = tostring(message)
		c.errors[#c.errors + 1] = text
		if not c.allowErrors then
			io.stderr:write("error handler: ", text, "\n")
			os.exit(1)
		end
		dispatching = false
	end
	local currentHandler = DefaultHandler
	G.geterrorhandler = function()
		return currentHandler
	end
	G.seterrorhandler = function(handler)
		currentHandler = handler
	end
	G.UISpecialFrames = {}
	G.strtrim = function(text)
		return (text:gsub("^%s+", ""):gsub("%s+$", ""))
	end
	G.PlaySound = noop
	G.SOUNDKIT = {}
	G.DEFAULT, G.OFF, G.UNKNOWN = "Default", "Off", "Unknown"
	G.debugprofilestop = function()
		return 0
	end
	-- The client's stack reader: debug.traceback text from the caller `start` levels up, as the game's debugstack is.
	G.debugstack = function(start)
		return debug.traceback("", tonumber(start) or 1)
	end
	G.time = function()
		return c.now
	end
	G.GetBuildInfo = function()
		return "1.60.1", c.build, "Sep 24 2026", 16001, "wow", "1.60.1." .. c.build
	end
	-- c.addons: the other loaded addons, { name, version }, in the AddOns list after this one.
	c.addons = {}
	G.C_AddOns = {
		GetAddOnMetadata = function(addon, field)
			if addon == ADDON then
				-- The packager fills Version into a release; the checkout keeps its keyword.
				if field == "Version" then
					return "1.2.3"
				end
				return TOC[field]
			end
			if field == "Version" then
				for _, other in ipairs(c.addons) do
					if other[1] == addon then
						return other[2]
					end
				end
			end
			return field == "X-Flavor" and "Forever" or nil
		end,
		IsAddOnLoaded = function(addon)
			return type(addon) == "number" and addon <= #c.addons + 1
		end,
		GetNumAddOns = function()
			return #c.addons + 1
		end,
		GetAddOnInfo = function(index)
			local name = index == 1 and ADDON or (c.addons[index - 1] or {})[1]
			return name, name
		end,
		DoesAddOnExist = function()
			return false
		end,
	}
	G.LibQuestieDB = options.questie and Client.QuestieDB(options.questie)
	G.AtlasLoot = options.atlasLoot and Client.AtlasLoot(options.atlasLoot)
	G.APPRENTICE, G.JOURNEYMAN, G.EXPERT, G.ARTISAN = "Apprentice", "Journeyman", "Expert", "Artisan"
	G.Mixin = function(target, source)
		for key, value in pairs(source) do
			target[key] = value
		end
		return target
	end

	--[[ ForeverCore, then the addon ]]

	-- ForeverCore loads first: its TOC's files into this client, then its own ADDON_LOADED, as the client does for a
	-- dependency. The tests never fake its host or its shared tables, so a spec exercises the real ones.
	ForeverCore.load(G)
	c.Fire("ADDON_LOADED", "ForeverCore")
	-- Frames made so far belong to ForeverCore; the addon's own start at the next index.
	c.coreFrames = #c.frames
	c.host = G.ForeverCore.TrackerHost
	if c.host then
		local attach = c.host.Attach
		-- ForeverCore's own quest section joins the same column from v1.2.0, and it lays itself out through
		-- Update rather than LayoutContents. c.tracker holds this addon's own sections, which the specs drive.
		function c.host.Attach(module, show)
			attach(module, show)
			local name = module:GetName()
			local own = type(name) ~= "string" or not name:find("^ForeverCore")
			if own and not G.tContains(c.tracker, module) and c.host.IsAttached(module) then
				c.tracker[#c.tracker + 1] = module
			end
		end
	end

	G.SkillUpForeverDB = options.saved
	local data = options.data
	for line in io.lines(ADDON .. ".toc") do
		local file = line:match("^([%w_\\]+%.lua)%s*$")
		if file then
			-- The fixtures stand in for the bundled tables before any addon file reads them; the two broken checks
			-- (Core/ForeverRequire.lua and Core/Require.lua) and the locale files read no data.
			local warning = file == "Core\\ForeverRequire.lua" or file == "Core\\Require.lua"
			if data and not file:find("^Locales\\") and not file:find("^Data\\") and not warning then
				for name, value in pairs(data) do
					c.ns[name] = value
				end
				data = nil
			end
			setfenv(assert(loadfile((file:gsub("\\", "/")))), G)(ADDON, c.ns)
		end
	end
	function c.Boot()
		c.LoadAddOn(ADDON)
	end
	if options.boot ~= false then
		c.Boot()
	end
	return c
end

return Client
