-- Run from the repository root: luajit tests/settings_spec.lua
-- Options > AddOns > SkillUp Forever is an index page (one button per group) over a stock subpage each.
-- Settings rows must reach their layout only through Settings.RegisterInitializer, which inserts them from
-- Blizzard's secure attribute delegate. A row inserted from addon code (Settings.CreateCheckbox/CreateDropdown
-- or layout:AddInitializer, which insert from the caller) taints the settings search, and a restricted button
-- in its results (Social's Discord Sign In) is then blocked and blamed on this addon.
local registered, settings, notified = {}, {}, {}

local function Tainted()
	error("addon code inserted a row into a settings layout; use Settings.RegisterInitializer")
end

local secure = false
local function RequireSecure(fn)
	return function(...)
		assert(secure, "the dropdown must be built through the client's secure delegate")
		return fn(...) -- multi-value: pass through the client function's results
	end
end

local categories = 0
local function Category(name, parent)
	categories = categories + 1
	local id = categories
	return {
		name = name,
		parent = parent,
		GetID = function()
			return id
		end,
	}
end

local category

local function Initializer(kind, setting, tooltip)
	return { kind = kind, setting = setting, tooltip = tooltip }
end

local function ResetSetting(setting)
	setting.SetValueToDefault = function(self)
		self:SetValue(self.default)
	end
	return setting
end

local opened, addOnCategory
-- Calls to ForeverCore's shared settings opener.
local opens = 0

local callbacks = {}
local function TheseSettings(selected)
	for _, setting in pairs(settings) do
		if setting.category == selected then
			setting:SetValue(setting.default)
		end
	end
	local callback = callbacks["Settings.CategoryDefaulted"]
	if callback then
		callback.fn(callback.owner, selected)
	end
end

local env = setmetatable({
	securecallfunction = function(fn, ...)
		return fn(...) -- multi-value: pass through the client function's results
	end,
	CreateSecureDelegate = function(fn)
		return function(...)
			secure = true
			local result = fn(...)
			secure = false
			return result
		end
	end,
	GenerateClosure = RequireSecure(function(fn, owner)
		return function(...)
			return fn(owner, ...)
		end
	end),
	EventRegistry = {
		RegisterCallback = function(_, event, fn, owner)
			callbacks[event] = { fn = fn, owner = owner }
		end,
	},
	Settings = {
		VarType = { Boolean = "boolean", String = "string", Number = "number" },
		RegisterVerticalLayoutCategory = function(name)
			category = Category(name)
			return category, { AddInitializer = Tainted }
		end,
		RegisterVerticalLayoutSubcategory = function(parent, name)
			assert(parent == category, "a subpage belongs to the addon's category")
			return Category(name, parent), { AddInitializer = Tainted }
		end,
		RegisterAddOnSetting = function(target, variable, key, db, varType, _name, default)
			if db[key] == nil then
				db[key] = default
			end
			local setting = {
				variable = variable,
				category = target,
				key = key,
				GetValue = function()
					return db[key]
				end,
				varType = varType,
				default = default,
				SetValueChangedCallback = function(self, callback)
					self.changed = callback
				end,
			}
			setting.SetValue = function(_, value)
				db[key] = value
				if setting.changed then
					setting.changed()
				end
			end
			settings[variable] = ResetSetting(setting)
			return setting
		end,
		RegisterProxySetting = function(target, variable, varType, _name, default, get, set)
			local setting = {
				variable = variable,
				category = target,
				key = variable:match("SkillUpForever_(.*)"),
				varType = varType,
				default = default,
				GetValue = get,
				SetValue = function(_, value)
					set(value)
				end,
			}
			settings[variable] = ResetSetting(setting)
			return setting
		end,
		SetValue = function(variable, value)
			settings[variable]:SetValue(value)
		end,
		NotifyUpdate = function(variable)
			notified[#notified + 1] = variable
		end,
		CreateCheckbox = Tainted,
		CreateDropdown = Tainted,
		CreateCheckboxInitializer = function(setting, options, tooltip)
			assert(setting.varType == "boolean" and options == nil)
			return Initializer("checkbox", setting, tooltip)
		end,
		CreateControlTextContainer = RequireSecure(function()
			local options = {}
			return {
				Add = RequireSecure(function(_, value, label)
					options[#options + 1] = { value = value, text = label }
				end),
				GetData = function()
					return options
				end,
			}
		end),
		CreateDropdownInitializer = RequireSecure(function(setting, options, tooltip)
			assert(setting.varType == "string")
			local initializer = Initializer("dropdown", setting, tooltip)
			initializer.options = options
			return initializer
		end),
		CreateSliderOptions = function(minimum, maximum, step)
			return {
				minimum = minimum,
				maximum = maximum,
				step = step,
				SetLabelFormatter = function(self, _label, formatter)
					self.formatter = formatter
				end,
			}
		end,
		CreateSliderInitializer = function(setting, options, tooltip)
			assert(setting.varType == "number" and options.step and options.step > 0)
			local initializer = Initializer("slider", setting, tooltip)
			initializer.options = options
			return initializer
		end,
		RegisterInitializer = function(target, initializer)
			registered[#registered + 1] = { category = target, initializer = initializer }
		end,
		RegisterAddOnCategory = function(target)
			assert(target == category and target.parent == nil, "the addon registers its own category")
			addOnCategory = target
		end,
		-- The restricted route: the client refuses this call from addon code and blames the addon, so reaching it
		-- fails the spec (cjber/forever-core#333).
		OpenToCategory = function()
			error("Settings.OpenToCategory called straight from addon code")
		end,
	},
	-- ForeverCore's shared opener, which SkillUp asks instead of the client's restricted function.
	ForeverCore = {
		OpenSettingsPanel = function(categoryID)
			opens = opens + 1
			opened = categoryID
			return true
		end,
	},
	InCombatLockdown = function()
		return false
	end,
	MinimalSliderWithSteppersMixin = { Label = { Right = 2 } },
	CreateSettingsButtonInitializer = function(name, _buttonText, onClick, _tooltip, addSearchTags)
		assert(addSearchTags == false, "index buttons stay out of search")
		return { kind = "button", name = name, onClick = onClick }
	end,
}, { __index = _G })

env._G = env

-- Core's own settings helpers, so the shared attach row is the one every Forever addon registers.
local coreNs = {}
for _, path in ipairs({ "Locales/enUS.lua", "UI/SettingsPage.lua", "UI/SettingsSections.lua" }) do
	local chunk = assert(loadfile(dofile("tests/forever_core.lua").directory() .. "/" .. path), path)
	setfenv(chunk, env)
	chunk("ForeverCore", coreNs)
end
env.ForeverCore.SettingsSections = coreNs.SettingsSections

local refreshed = 0
local trackerState = { attached = true, locked = false, scale = 1 }
local attachmentChanged
env.ForeverCore.TrackerHost = {
	GetSettings = function()
		return trackerState
	end,
	SetAttached = function(value)
		trackerState.attached = value
		attachmentChanged()
	end,
	SetLocked = function(value)
		trackerState.locked = value
	end,
	GetScale = function()
		return trackerState.scale
	end,
	SetScale = function(value)
		trackerState.scale = value
	end,
	OnAttachmentChanged = function(callback)
		attachmentChanged = callback
	end,
}
coreNs.TrackerHost = env.ForeverCore.TrackerHost
local ns = {
	core = {
		SafeCall = function(_, fn, ...)
			return pcall(fn, ...)
		end,
	},
	TITLE = "SkillUp Forever",
	db = {},
	DEFAULTS = {
		priceSource = "auctionator",
		restockCost = 0,
		craftValue = "vendor",
		reagentTooltip = "route",
		recipeTooltip = "window",
		rowCost = "skillup",
		sortMode = "default",
		unlearnedSortMode = "skill",
		showRowText = true,
		showUnlearned = false,
		buffsOnly = false,
		valueGathered = false,
		gatheredValueSeen = true,
		auctionOnly = false,
		showBuffsTab = true,
		auctionShoppingLists = true,
	},
	RECIPE_TOOLTIP_OPTIONS = { { "window", "Beside" }, { "cursor", "Cursor" }, { "row", "Row" } },
	ROW_COST_OPTIONS = { { "skillup", "Per skill-up" }, { "craft", "Per craft" } },
	PRICE_SOURCE_OPTIONS = { { "auctionator", "Auctionator" }, { "tsm", "TradeSkillMaster" } },
	REAGENT_TOOLTIP_OPTIONS = { { "off", "Off" }, { "route", "Route" }, { "full", "Every recipe" } },
	SORT_OPTIONS = { { "default", "Default" }, { "skill", "Skill" }, { "chance", "Chance" }, { "cost", "Cost" } },
	UNLEARNED_SORT_OPTIONS = { { "skill", "Skill" }, { "newest", "Newest" } },
	CRAFT_VALUE_OPTIONS = {
		{ "none", "None" },
		{ "vendor", "Vendor" },
		{ "auction", "Auction" },
		{ "sale", "Region sale" },
	},
	SetIncludeWorkingOvertime = function() end,
	SyncAuctionShoppingLists = function() end,
	Changed = function(kind)
		assert(kind == "settings")
		refreshed = refreshed + 1
	end,
}
assert(loadfile("Locales/enUS.lua"))("SkillUpForever", ns)
-- The shared opener is ForeverCore's: the settings page asks it, not Settings.OpenToCategory.
setfenv(assert(loadfile("UI/Settings.lua")), env)("SkillUpForever", ns)
ns.OpenSettings() -- before registration, as when an update's files are missing: no error
assert(opens == 0, "no settings open before the category is registered")
ns.RegisterSettings()

---@param key string
local function Row(key)
	for _, entry in ipairs(registered) do
		if entry.initializer.setting and entry.initializer.setting.key == key then
			return entry
		end
	end
	error("no setting row registered for " .. key)
end

---@param name string
local function Button(name)
	for _, entry in ipairs(registered) do
		if entry.initializer.kind == "button" and entry.initializer.name == name then
			return entry
		end
	end
	error("no index button registered for " .. name)
end

---@param name string
local function Subpage(name)
	for _, entry in ipairs(registered) do
		if entry.initializer.setting and entry.category.name == name then
			return entry.category
		end
	end
	error("no subpage registered for " .. name)
end

-- Blizzard resets the selected category's settings before emitting Settings.CategoryDefaulted.
local game = { keybinding = "SHIFT-Z" }
env.Settings.RegisterAddOnSetting(Category("Keybindings"), "GameBinding", "keybinding", game, "string", "Z")
env.Settings.SetValue("SkillUpForever_showRowText", false)
env.Settings.SetValue("SkillUpForever_priceSource", "tsm")
env.Settings.SetValue("SkillUpForever_restockCost", 2000)
trackerState.scale = 1.25
TheseSettings(Subpage("Prices"))
assert(ns.db.priceSource == "auctionator" and ns.db.restockCost == 0, "These Settings restores the Prices rows")
assert(ns.db.showRowText == false, "Prices leaves Recipe rows alone")
assert(game.keybinding == "SHIFT-Z" and trackerState.scale == 1.25, "Prices preserves game and shared tracker settings")
env.Settings.SetValue("SkillUpForever_priceSource", "tsm")
env.Settings.SetValue("SkillUpForever_restockCost", 2000)
TheseSettings(addOnCategory)
assert(
	ns.db.showRowText == true and ns.db.priceSource == "auctionator" and ns.db.restockCost == 0,
	"These Settings on the index restores SkillUp defaults across subpages"
)
assert(game.keybinding == "SHIFT-Z" and trackerState.scale == 1.25, "Index preserves game and shared tracker settings")
trackerState.scale = 1
refreshed = 0

-- Every subpage's rows, then the index's button to it, in the order the groups appear.
local groups = {
	{
		"Recipe rows",
		"checkbox:includeWorkingOvertime checkbox:showUnlearned checkbox:buffsOnly checkbox:showRowText"
			.. " checkbox:showRowPrices dropdown:rowCost checkbox:showSkill checkbox:showTooltip"
			.. " checkbox:detailsBar dropdown:recipeTooltip dropdown:unlearnedSortMode",
	},
	{
		"Prices",
		"dropdown:priceSource dropdown:craftValue checkbox:valueGathered checkbox:auctionOnly slider:restockCost",
	},
	{
		"Route and trainer",
		"checkbox:showTracker checkbox:trackerAttached slider:trackerScale checkbox:trackerLocked"
			.. " checkbox:showRouteTab"
			.. " checkbox:showGearTab checkbox:showBuffsTab"
			.. " checkbox:merchantButton checkbox:auctionSearch checkbox:auctionShoppingLists checkbox:showTrainer",
	},
	{
		"Tooltips and sorting",
		"dropdown:reagentTooltip checkbox:showTooltipRoute checkbox:gatherTooltip dropdown:sortMode",
	},
	{ "Addon", "checkbox:whatsNew" },
}
local kinds, expected = {}, {}
for _, group in ipairs(groups) do
	local name, rows = group[1], group[2]
	for kind in rows:gmatch("%S+") do
		expected[#expected + 1] = kind .. "@" .. name
	end
	expected[#expected + 1] = "button@" .. addOnCategory.name
	local button = Button(name)
	assert(button.category == addOnCategory, name .. "'s index row is on the category itself")
	local before = opens
	button.initializer.onClick()
	assert(opens == before + 1, name .. "'s button opens through the client's own opener")
	assert(opened == Subpage(name):GetID(), name .. "'s button opens its subpage")
end
for _, entry in ipairs(registered) do
	local kind = entry.initializer.kind
	if entry.initializer.setting then
		kind = kind .. ":" .. entry.initializer.setting.key
	end
	kinds[#kinds + 1] = kind .. "@" .. entry.category.name
end
assert(table.concat(kinds, " ") == table.concat(expected, " "), table.concat(kinds, " "))

local priceSource = Row("priceSource")
assert(
	priceSource.initializer.setting.variable == "SkillUpForever_priceSource"
		and priceSource.initializer.setting.default == "auctionator",
	"the auction source dropdown defaults to Auctionator"
)
assert(priceSource.initializer.options()[1].text == "Auctionator", "the first source is Auctionator")
assert(priceSource.initializer.options()[2].text == "TradeSkillMaster", "the second is TradeSkillMaster")
assert(priceSource.initializer.tooltip:find("the others fill gaps", 1, true), "the setting explains its fallback")
local craftValue = Row("craftValue")
assert(
	craftValue.initializer.setting.variable == "SkillUpForever_craftValue"
		and craftValue.initializer.setting.default == "vendor"
)
assert(craftValue.initializer.options()[3].text == "Auction" and craftValue.initializer.tooltip:find("5%% cut"))
assert(craftValue.initializer.options()[4].text == "Region sale")
assert(craftValue.initializer.tooltip:find("regional sales", 1, true), "the sales source is explained")
assert(Row("sortMode").initializer.options()[1].text == "Default")
assert(Row("auctionShoppingLists").initializer.setting.default == true, "persistent lists start on")
assert(Row("showUnlearned").initializer.setting.default == false, "unlearned recipes start off")
assert(Row("showUnlearned").initializer.tooltip:find("greyed"), "the unlearned list explains how it draws")
assert(Row("buffsOnly").initializer.setting.default == false, "the buff filter starts off")
assert(Row("buffsOnly").initializer.tooltip:find("Highest required level first"), "the buff filter explains its order")
assert(Row("valueGathered").initializer.tooltip:find("vendor sell price if that is more"), "gathered value floor")
assert(
	Row("auctionOnly").initializer.tooltip:find("stays unpriced rather than free"),
	"market-priced self-supplied reagents never fall back to free"
)
assert(
	Row("detailsBar").initializer.tooltip:find("reagents"),
	"the details bar can be turned off when it covers the reagents"
)
assert(Row("showRowText").initializer.tooltip:find("Skill%-up chance"))
Row("showRowText").initializer.setting.changed()
assert(refreshed == 1, "a change is reported once")
for _, key in ipairs({ "priceSource", "craftValue", "sortMode", "reagentTooltip", "recipeTooltip", "rowCost" }) do
	local row = Row(key)
	local options = ns[({
		priceSource = "PRICE_SOURCE_OPTIONS",
		craftValue = "CRAFT_VALUE_OPTIONS",
		sortMode = "SORT_OPTIONS",
		reagentTooltip = "REAGENT_TOOLTIP_OPTIONS",
		recipeTooltip = "RECIPE_TOOLTIP_OPTIONS",
		rowCost = "ROW_COST_OPTIONS",
	})[key]]
	assert(row.initializer.setting:GetValue() == row.initializer.setting.default, "saved default restored")
	for index, option in ipairs(options) do
		local before = refreshed
		local item = row.initializer.options()[index]
		row.initializer.setting:SetValue(item.value)
		assert(ns.db[key] == option[1], "dropdown writes the original saved string")
		assert(item.text == option[2], "dropdown labels every choice")
		assert(refreshed == before + 1, "one choice is reported once")
	end
end
ns.SetSortMode("skill")
assert(Row("sortMode").initializer.setting:GetValue() == "skill", "recipe list sorting updates settings dropdown")
print("settings: native dropdowns, saved values, defaults, labels, callbacks and external sorting: ok")

local attachment = settings.SkillUpForever_trackerAttached
assert(attachment:GetValue() == true, "tracker starts attached")
attachment:SetValue(false)
assert(attachment:GetValue() == false, "toggle detaches shared host")
assert(notified[#notified] == "SkillUpForever_trackerAttached", "attachment change refreshes shared proxy")
trackerState.attached = true
attachmentChanged()
assert(attachment:GetValue() == true, "another addon reattaches the same host")

-- The shared host owns its scale: the slider mirrors it as a percentage and writes it back, so the rows can
-- be made as large as the game's own tracker.
local trackerScale = Row("trackerScale")
assert(trackerScale.initializer.kind == "slider", "the settings page has a Tracker scale slider")
assert(trackerScale.initializer.setting.default == 100, "tracker scale defaults to 100%")
assert(
	trackerScale.initializer.options.minimum == 50
		and trackerScale.initializer.options.maximum == 200
		and trackerScale.initializer.options.step == 10,
	"tracker scale runs from 50% to 200% in 10% steps"
)
assert(trackerScale.initializer.options.formatter(150) == "150%", "the tracker slider shows a percent")
assert(trackerScale.initializer.tooltip:find("shared Forever tracker"), "the slider says it scales the shared tracker")
assert(settings.SkillUpForever_trackerScale:GetValue() == 100, "the slider reads the shared host scale")
trackerState.scale = 1.26
assert(settings.SkillUpForever_trackerScale:GetValue() == 126, "a host scale reads back rounded to a percent")
settings.SkillUpForever_trackerScale:SetValue(150)
assert(trackerState.scale == 1.5, "the tracker slider drives the shared host scale")

-- Lock starts off, sits under the attach row, and drives the shared host rather than a copy of its own.
local lock = settings.SkillUpForever_trackerLocked
assert(lock:GetValue() == false, "the shared tracker starts unlocked")
lock:SetValue(true)
assert(trackerState.locked == true and lock:GetValue(), "locking writes the shared host settings")
lock:SetValue(false)
assert(trackerState.locked == false and not lock:GetValue(), "unlocking writes them back")

-- /skillup and the compartment button use the same route, not Blizzard's restricted wrapper.
ns.Pages = {
	Unlocked = function()
		return true
	end,
}
local before = opens
ns.OpenSettings()
assert(opens == before + 1, "OpenSettings opens through the client's own opener")
assert(opened == category:GetID(), "OpenSettings opens the addon's own category")

-- The loader adopts an installed standalone ForeverCore as it is, even when it is older than the pinned release.
-- ForeverCore 1.15.3 has no SettingsSections.RegisterTrackerAttach (added in 1.15.4): the page goes without the
-- Attach row, and every other row still registers.
local function Keys()
	local keys = {}
	for _, entry in ipairs(registered) do
		if entry.initializer.setting then
			keys[entry.initializer.setting.key] = true
		end
	end
	return keys
end
local withAttach = Keys()
local olderSections = {}
for name, member in pairs(coreNs.SettingsSections) do
	olderSections[name] = member
end
olderSections.RegisterTrackerAttach = nil
env.ForeverCore.SettingsSections = olderSections
for index = #registered, 1, -1 do
	registered[index] = nil
end
ns.RegisterSettings()
local after = Keys()
local missing = {}
for key in pairs(withAttach) do
	if not after[key] then
		missing[#missing + 1] = key
	end
end
table.sort(missing)
assert(
	table.concat(missing, " ") == "trackerAttached",
	"only the Attach row is missing: " .. table.concat(missing, " ")
)
assert(after.trackerLocked and after.trackerScale, "Lock and scale still register with an older core")
print("settings: an older ForeverCore without the Attach row: ok")
