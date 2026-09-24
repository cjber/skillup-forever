-- Run from the repository root: luajit tests/settings_spec.lua
-- Settings rows must reach their layout only through Settings.RegisterInitializer, which inserts them from
-- Blizzard's secure attribute delegate. A row inserted from addon code (Settings.CreateCheckbox/CreateDropdown
-- or layout:AddInitializer, which insert from the caller) taints the settings search, and a restricted button
-- in its results (Social's Discord Sign In) is then blocked and blamed on this addon.
local registered = {}

local function Tainted()
	error("addon code inserted a row into a settings layout; use Settings.RegisterInitializer")
end

local category = {
	GetID = function()
		return 1
	end,
}

local function Initializer(kind, setting, tooltip)
	return { kind = kind, setting = setting, tooltip = tooltip }
end

local env = setmetatable({
	Settings = {
		VarType = { Boolean = "boolean", String = "string", Number = "number" },
		RegisterVerticalLayoutCategory = function()
			return category, { AddInitializer = Tainted }
		end,
		RegisterAddOnSetting = function(_, variable, key, _, varType, name, default)
			return {
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
			assert(target == category)
			registered[#registered + 1] = initializer
		end,
		RegisterAddOnCategory = function(target)
			assert(target == category)
		end,
	},
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
	PricesChanged = Refresh,
	RefreshRecipeList = Refresh,
	RefreshTrainer = Refresh,
	RefreshRouteTab = Refresh,
}
setfenv(assert(loadfile("Settings.lua")), env)("SkillUpForever", ns)
ns.RegisterSettings()

local rows = {}
for index, initializer in ipairs(registered) do
	rows[index] = initializer.kind .. ":" .. initializer.setting.key
end
local expected = "checkbox:showRowText checkbox:showSkill checkbox:showTooltip checkbox:showCost "
	.. "dropdown:craftValue checkbox:scanAuctions checkbox:gatherFree checkbox:showRouteTab "
	.. "checkbox:showTrainer dropdown:reagentTooltip dropdown:sortMode"
assert(table.concat(rows, " ") == expected, table.concat(rows, " "))

local craftValue = registered[5]
assert(
	craftValue.setting.variable == "SkillUpForever_craftValue" and craftValue.setting.default == "default:craftValue"
)
assert(craftValue.options()[3].value == "auction" and craftValue.tooltip:find("5%% cut"))
assert(registered[11].options()[1].text == "Default")
assert(registered[1].tooltip:find("Skill%-up chance"))
registered[1].setting.changed()
assert(refreshed == 4, "a change refreshes prices, the recipe list, the trainer and the route tab")
print("settings: ok")
