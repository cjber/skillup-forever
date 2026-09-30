-- Run from the repository root: luajit tests/settings_spec.lua
-- Options → AddOns → SkillUp Forever is an index page (one button per group) over a stock subpage each.
-- Settings rows must reach their layout only through Settings.RegisterInitializer, which inserts them from
-- Blizzard's secure attribute delegate. A row inserted from addon code (Settings.CreateCheckbox/CreateDropdown
-- or layout:AddInitializer, which insert from the caller) taints the settings search, and a restricted button
-- in its results (Social's Discord Sign In) is then blocked and blamed on this addon.
local registered, settings, notified = {}, {}, {}

local function Tainted()
	error("addon code inserted a row into a settings layout; use Settings.RegisterInitializer")
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

local opened, addOnCategory

local env = setmetatable({
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
		RegisterAddOnSetting = function(target, variable, key, db, varType, name, default)
			if db[key] == nil then
				db[key] = default
			end
			local setting = {
				target = target,
				variable = variable,
				key = key,
				varType = varType,
				name = name,
				default = default,
				SetValueChangedCallback = function(self, callback)
					self.changed = callback
				end,
			}
			setting.GetValue = function()
				return db[key]
			end
			setting.SetValue = function(_, value)
				db[key] = value
				if setting.changed then
					setting.changed()
				end
			end
			settings[variable] = setting
			return setting
		end,
		RegisterProxySetting = function(target, variable, varType, name, default, get, set)
			local setting = {
				target = target,
				variable = variable,
				key = variable:match("SkillUpForever_(.*)_choice"),
				varType = varType,
				name = name,
				default = default,
				GetValue = get,
				SetValue = function(_, value)
					set(value)
				end,
			}
			settings[variable] = setting
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
		CreateDropdownInitializer = function()
			error("native settings menus crash in AcquireMenu")
		end,
		CreateSliderOptions = function(minimum, maximum, step)
			return {
				minimum = minimum,
				maximum = maximum,
				step = step,
				SetLabelFormatter = function(self, label, formatter)
					self.label = label
					self.formatter = formatter
				end,
			}
		end,
		CreateSliderInitializer = function(setting, options, tooltip)
			assert(setting.varType == "number" and options.step == 1)
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
		OpenToCategory = function(id)
			opened = id
		end,
	},
	MinimalSliderWithSteppersMixin = { Label = { Right = 2 } },
	CreateSettingsButtonInitializer = function(name, buttonText, onClick, tooltip, addSearchTags)
		assert(addSearchTags == false, "index buttons stay out of search")
		return { kind = "button", name = name, buttonText = buttonText, onClick = onClick, tooltip = tooltip }
	end,
}, { __index = _G })

local refreshed = 0
local function Refresh()
	refreshed = refreshed + 1
end
local ns = {
	TITLE = "SkillUp Forever",
	db = {},
	DEFAULTS = { craftValue = "vendor", reagentTooltip = "route", sortMode = "default", showRowText = true },
	REAGENT_TOOLTIP_OPTIONS = { { "off", "Off" }, { "route", "Route" }, { "full", "Every recipe" } },
	SORT_OPTIONS = { { "default", "Default" }, { "skill", "Skill" }, { "chance", "Chance" }, { "cost", "Cost" } },
	CRAFT_VALUE_OPTIONS = { { "none", "None" }, { "vendor", "Vendor" }, { "auction", "Auction" } },
	PricesChanged = Refresh,
	RefreshRecipeList = Refresh,
	RefreshTrainer = Refresh,
	RefreshRouteTab = Refresh,
}
assert(loadfile("Locales/enUS.lua"))("SkillUpForever", ns)
setfenv(assert(loadfile("Settings.lua")), env)("SkillUpForever", ns)
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

-- Every subpage's rows, then the index's button to it, in the order the groups appear.
local groups = {
	{ "Recipe rows", "checkbox:showRowText checkbox:showSkill checkbox:showTooltip checkbox:showCost" },
	{ "Prices", "slider:craftValue checkbox:gatherFree" },
	{ "Route and trainer", "checkbox:showRouteTab checkbox:showTrainer" },
	{ "Tooltips and sorting", "slider:reagentTooltip slider:sortMode" },
	{ "Addon", "checkbox:companionHints checkbox:whatsNew" },
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
	button.initializer.onClick()
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

-- A row sits on the subpage named for its group, never the index category.
for _, entry in ipairs(registered) do
	if entry.initializer.setting then
		assert(entry.category.parent == addOnCategory, entry.initializer.setting.key .. " is not on the index category")
	end
end

local craftValue = Row("craftValue")
assert(craftValue.category.name == "Prices")
assert(
	craftValue.initializer.setting.variable == "SkillUpForever_craftValue_choice"
		and craftValue.initializer.setting.default == 2
)
assert(craftValue.initializer.options.formatter(3) == "Auction" and craftValue.initializer.tooltip:find("5%% cut"))
assert(Row("sortMode").initializer.options.formatter(1) == "Default")
assert(Row("showRowText").initializer.tooltip:find("Skill%-up chance"))
Row("showRowText").initializer.setting.changed()
assert(refreshed == 4, "a change refreshes prices, the recipe list, the trainer and the route tab")
for _, key in ipairs({ "craftValue", "sortMode", "reagentTooltip" }) do
	local row = Row(key)
	local options = ns[({
		craftValue = "CRAFT_VALUE_OPTIONS",
		sortMode = "SORT_OPTIONS",
		reagentTooltip = "REAGENT_TOOLTIP_OPTIONS",
	})[key]]
	assert(row.initializer.setting:GetValue() == row.initializer.setting.default, "saved default restored")
	for index, option in ipairs(options) do
		local before = refreshed
		row.initializer.setting:SetValue(index)
		assert(ns.db[key] == option[1], "slider writes the original saved string")
		assert(row.initializer.options.formatter(index) == option[2], "slider labels every choice")
		assert(refreshed == before + 4, "one choice refreshes each surface once")
		assert(notified[#notified] == "SkillUpForever_" .. key .. "_choice", "canonical change notifies visible proxy")
	end
	row.initializer.setting:SetValue(0)
	assert(ns.db[key] == options[#options][1], "invalid slider position leaves value unchanged")
end
ns.SetSortMode("skill")
assert(Row("sortMode").initializer.setting:GetValue() == 2, "recipe list sorting updates settings slider")
print("settings: menu-free choices, saved values, defaults, labels, callbacks and external sorting: ok")
