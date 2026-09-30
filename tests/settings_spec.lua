-- Run from the repository root: luajit tests/settings_spec.lua
-- Options → AddOns → SkillUp Forever is an index page (one button per group) over a stock subpage each.
-- Settings rows must reach their layout only through Settings.RegisterInitializer, which inserts them from
-- Blizzard's secure attribute delegate. A row inserted from addon code (Settings.CreateCheckbox/CreateDropdown
-- or layout:AddInitializer, which insert from the caller) taints the settings search, and a restricted button
-- in its results (Social's Discord Sign In) is then blocked and blamed on this addon.
local registered = {}

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
		RegisterAddOnSetting = function(target, variable, key, _, varType, name, default)
			return {
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
		end,
		CreateCheckbox = Tainted,
		CreateDropdown = Tainted,
		CreateCheckboxInitializer = function(setting, options, tooltip)
			assert(setting.varType == "boolean" and options == nil)
			return Initializer("checkbox", setting, tooltip)
		end,
		CreateDropdownInitializer = function(setting, options, tooltip)
			assert(setting.varType == "string" and options)
			local initializer = Initializer("dropdown", setting, tooltip)
			initializer.options = options
			return initializer
		end,
		CreateControlTextContainer = function()
			local data = {}
			return {
				Add = function(_, value, text)
					data[#data + 1] = { value = value, text = text }
				end,
				GetData = function()
					return data
				end,
			}
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
	DEFAULTS = setmetatable({}, {
		__index = function(_, key)
			return "default:" .. key
		end,
	}),
	REAGENT_TOOLTIP_OPTIONS = { { "route", "Route" } },
	SORT_OPTIONS = { { "default", "Default" } },
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
	{ "Prices", "dropdown:craftValue checkbox:gatherFree" },
	{ "Route and trainer", "checkbox:showRouteTab checkbox:showTrainer" },
	{ "Tooltips and sorting", "dropdown:reagentTooltip dropdown:sortMode" },
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
	craftValue.initializer.setting.variable == "SkillUpForever_craftValue"
		and craftValue.initializer.setting.default == "default:craftValue"
)
assert(craftValue.initializer.options()[3].value == "auction" and craftValue.initializer.tooltip:find("5%% cut"))
assert(Row("sortMode").initializer.options()[1].text == "Default")
assert(Row("showRowText").initializer.tooltip:find("Skill%-up chance"))
Row("showRowText").initializer.setting.changed()
assert(refreshed == 4, "a change refreshes prices, the recipe list, the trainer and the route tab")
print("settings: ok")
