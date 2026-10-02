-- The stub game client the specs share: `local Client = dofile("tests/client.lua")`, from the repository root.
-- Client.load loads the files SkillUpForever.toc lists, in its order, against stubs of the client API the addon
-- calls, and returns a handle. A spec sets what the client holds (professions, bags, a merchant, Auctionator's
-- prices, the clock), fires the game's events, and asserts on what the addon produces. Nothing on `ns` is faked.
local Client = {}

local ADDON = "SkillUpForever"

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

-- options: data (ns tables that replace the bundled Data/*.lua ones of the same name), saved (SkillUpForeverDB),
-- auctionator (false for a client without it), boot (false to stop before the addon's ADDON_LOADED; c.Boot()
-- then runs it).
function Client.load(options)
	options = options or {}
	local G = setmetatable({}, { __index = _G })
	local c = {
		G = G,
		ns = {},
		now = 0,
		frames = {},
		chat = {},
		-- { name, icon, rank, max, id, modifier } in spellbook order; `id` is what the client reports for it.
		professions = {},
		spells = {}, -- [spellID] = name
		known = {}, -- [spellID] = true: in the spellbook
		items = {}, -- [itemID] = { name, sell }; a missing field is item data the client has not loaded
		bags = {}, -- [itemID] = count
		schematics = {}, -- [recipeID] = { reagents = { { itemID, quantity } }, output = itemID }: the open window's
		auction = {}, -- [itemID] = copper, as Auctionator last saw it
		auctionAge = 0, -- whole days
		merchant = nil, -- { { itemID, price, stackCount, ... } } while a merchant window is open
		money = 1000000,
		level = 60,
		player = { name = "Tester", realm = "Realm", faction = "Alliance", x = 0, y = 0, instance = 0 },
		maps = {}, -- [world instance] = { mapID, name }: the one zone map the client places its spawns on
		opened = {}, -- profession IDs passed to OpenTradeSkill
		purchased = {}, -- { index, count } per BuyMerchantItem call
		requested = {}, -- [itemID] = true: item data asked for
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
	local function NewFrame(frameType, name, parent, template)
		local frame = setmetatable({
			frameType = frameType,
			name = name,
			parent = parent,
			template = template,
			scripts = {},
			events = {},
			shown = true,
		}, frameMeta)
		c.frames[#c.frames + 1] = frame
		if name then
			G[name] = frame
		end
		return frame
	end
	function Methods:RegisterEvent(event)
		self.events[event] = true
	end
	function Methods:SetScript(name, fn)
		self.scripts[name] = fn
	end
	function Methods:Show()
		self.shown = true
	end
	function Methods:Hide()
		self.shown = false
	end
	function Methods:SetShown(shown)
		self.shown = shown and true or false
	end
	function Methods:IsShown()
		return self.shown
	end
	function Methods:SetText(text)
		self.text = text
	end
	function Methods.GetTextWidth()
		return 100
	end

	-- What the tracker section's stock template gives it; the shared host lays it out with these.
	local TrackerModule = {}
	function TrackerModule:SetHeader(text)
		self.header = text
	end
	function TrackerModule:MarkDirty()
		self.dirty = (self.dirty or 0) + 1
	end
	function TrackerModule:GetBlock(id)
		local block = { id = id, lines = {} }
		function block.SetHeader(_, text)
			block.header = text
		end
		function block.AddObjective(_, key, text, template)
			block.lines[#block.lines + 1] = { key = key, text = text }
			return NewFrame("Frame", nil, nil, template)
		end
		self.blocks[#self.blocks + 1] = block
		return block
	end
	function TrackerModule.LayoutBlock()
		return true
	end

	G.CreateFrame = function(frameType, name, parent, template)
		local frame = NewFrame(frameType, name, parent, template)
		if template == "ObjectiveTrackerModuleTemplate" then
			for key, method in pairs(TrackerModule) do
				frame[key] = method
			end
		end
		return frame
	end
	G.UIParent = NewFrame("Frame", "UIParent")
	G.ObjectiveTrackerFrame = NewFrame("Frame", "ObjectiveTrackerFrame")
	G.MerchantFrame = NewFrame("Frame", "MerchantFrame")
	G.MerchantFrame.IsShown = function()
		return c.merchant ~= nil
	end
	G.DEFAULT_CHAT_FRAME = {
		AddMessage = function(_, message)
			c.chat[#c.chat + 1] = message
		end,
	}
	-- Blizzard's tracker manager is never entered, and no native method is hooked.
	G.ObjectiveTrackerManager = setmetatable({}, {
		__index = function()
			error("native tracker accessed")
		end,
	})
	G.hooksecurefunc = function()
		error("native methods must stay unhooked")
	end
	G.OBJECTIVE_TRACKER_COLOR = { Complete = "complete" }

	-- The tracker host another Forever addon already published; UI/TrackerHost.lua adopts it instead of
	-- building its own, whose frames tracker_host_spec covers.
	c.host = {
		Attach = function(module)
			if not c.host.IsAttached(module) then
				c.tracker[#c.tracker + 1] = module
			end
		end,
		IsAttached = function(module)
			for _, attached in ipairs(c.tracker) do
				if attached == module then
					return true
				end
			end
			return false
		end,
	}
	G.ForeverTrackerHost = c.host

	-- The attached sections laid out now: { { id, header, lines = { { key, text } } } }, top to bottom.
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

	---@return integer frames how many frames registered for the event
	function c.Listeners(event)
		local count = 0
		for _, frame in ipairs(c.frames) do
			count = count + (frame.events[event] and 1 or 0)
		end
		return count
	end

	local timers = {}
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

	G.UnitName = function()
		return c.player.name
	end
	G.GetNormalizedRealmName = function()
		return c.player.realm
	end
	G.UnitFactionGroup = function()
		return c.player.faction
	end
	G.UnitLevel = function()
		return c.level
	end
	G.UnitPosition = function()
		return c.player.x, c.player.y, 0, c.player.instance
	end
	G.InCombatLockdown = function()
		return false
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
	}
	G.C_SpellBook = {
		IsSpellKnown = function(id)
			return c.known[id] == true
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
		-- No profession window is open.
		IsTradeSkillLinked = function()
			return false
		end,
		IsTradeSkillGuild = function()
			return false
		end,
		GetBaseProfessionInfo = noop,
		GetAllRecipeIDs = function()
			return {}
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
		GetItemCount = function(id)
			return c.bags[id] or 0
		end,
		RequestLoadItemDataByID = function(id)
			c.requested[id] = true
		end,
	}
	G.C_CurrencyInfo = {
		GetCoinTextureString = function(copper)
			return copper .. "c"
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

	local scanned = {}
	if options.auctionator ~= false then
		G.Auctionator = {
			API = {
				v1 = {
					GetAuctionPriceByItemID = function(_, itemID)
						return c.auction[itemID]
					end,
					GetAuctionAgeByItemID = function()
						return c.auctionAge
					end,
					RegisterForDBUpdate = function(_, fn)
						scanned[#scanned + 1] = fn
					end,
					CreateShoppingList = noop,
					ConvertToSearchString = noop,
				},
			},
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
		GetMapPosFromWorldPos = function(instance)
			local map = c.maps[instance]
			if map then
				return map.mapID, Middle()
			end
		end,
		GetMapInfo = MapInfo,
		GetMapInfoAtPosition = MapInfo,
		GetBestMapForUnit = function()
			return c.maps[c.player.instance] and c.maps[c.player.instance].mapID
		end,
		GetPlayerMapPosition = Middle,
	}
	G.CreateVector2D = function(x, y)
		return { x = x, y = y }
	end

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
		CreateCheckboxInitializer = noop,
		CreateSliderInitializer = noop,
		CreateSliderOptions = function()
			return { SetLabelFormatter = noop }
		end,
		SetValue = function(variable, value)
			settings[variable]:SetValue(value)
		end,
		NotifyUpdate = noop,
		OpenToCategory = noop,
	}
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
		TooltipDataType = { Item = 0 },
		UIMapType = { Continent = 2, Zone = 3, Dungeon = 4, Micro = 5 },
	}
	G.CreateColor = function(r, g, b)
		return { r = r, g = g, b = b }
	end
	G.TooltipDataProcessor = { AddTooltipPostCall = noop }
	G.SlashCmdList = {}
	G.PlaySound = noop
	G.SOUNDKIT = {}
	G.DEFAULT, G.OFF = "Default", "Off"
	G.APPRENTICE, G.JOURNEYMAN, G.EXPERT, G.ARTISAN = "Apprentice", "Journeyman", "Expert", "Artisan"
	G.Mixin = function(target, source)
		for key, value in pairs(source) do
			target[key] = value
		end
		return target
	end

	--[[ The addon ]]

	G.SkillUpForeverDB = options.saved
	local data = options.data
	for line in io.lines(ADDON .. ".toc") do
		local file = line:match("^([%w_\\]+%.lua)%s*$")
		if file then
			-- The fixtures stand in for the bundled tables before any file reads them.
			if data and not file:find("^Locales\\") and not file:find("^Data\\") then
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
