---@type string, SkillUpNamespace
local _, ns = ...
local L = ns.L

-- Every row goes in through Settings.RegisterInitializer, which inserts it from Blizzard's secure delegate.
-- Settings.CreateCheckbox/CreateDropdown insert from our code instead, and the settings search reads every
-- layout, so that tainted it: a restricted button in the results (Social's Discord Sign In) was then blocked
-- and blamed on us.
local category

local function Register(key, varType, name)
	local setting =
		Settings.RegisterAddOnSetting(category, "SkillUpForever_" .. key, key, ns.db, varType, name, ns.DEFAULTS[key])
	setting:SetValueChangedCallback(function()
		ns.PricesChanged()
		ns.RefreshRecipeList()
		ns.RefreshTrainer()
		ns.RefreshRouteTab()
	end)
	return setting
end

local function Checkbox(key, name, tooltip)
	Settings.RegisterInitializer(
		category,
		Settings.CreateCheckboxInitializer(Register(key, Settings.VarType.Boolean, name), nil, tooltip)
	)
end

-- options: { value, label } pairs, in menu order.
local function Dropdown(key, name, options, tooltip)
	local setting = Register(key, Settings.VarType.String, name)
	Settings.RegisterInitializer(
		category,
		Settings.CreateDropdownInitializer(setting, function()
			local container = Settings.CreateControlTextContainer()
			for _, option in ipairs(options) do
				container:Add(option[1], option[2])
			end
			return container:GetData()
		end, tooltip)
	)
end

-- A phrase is one key however long, so its line may run past the limit.
-- luacheck: push no max line length
function ns.RegisterSettings()
	category = Settings.RegisterVerticalLayoutCategory(ns.TITLE)

	Checkbox(
		"showRowText",
		L["Show skill on recipe rows"],
		L["Skill-up chance and cost per skill-up at the right of each recipe."]
	)

	Checkbox(
		"showSkill",
		L["Show required skill on rows"],
		L["Add the skill each recipe needs. Recipes you can't make yet always show it."]
	)

	Checkbox(
		"showTooltip",
		L["Show thresholds tooltip"],
		L["Orange, yellow, green and grey thresholds when hovering a recipe."]
	)

	Checkbox(
		"showCost",
		L["Show cost per skill-up"],
		L["Reagent cost divided by skill-up chance, on recipe rows and in the tooltip. Prices come from vendors you've visited and from Auctionator. Auction prices need Auctionator."]
	)

	Dropdown(
		"craftValue",
		L["Count what crafts sell for"],
		{
			{ "none", L["Don't count it"] },
			{ "vendor", L["Vendor sell price"] },
			{ "auction", L["Auction price if higher"] },
		},
		L["Subtract what the crafted item sells for from its cost. Auction prices need Auctionator, are after the 5% cut, and may not sell."]
	)

	Checkbox(
		"gatherFree",
		L["Reagents you gather are free"],
		L["Price what another of your professions gathers (Light Leather with Skinning, ore with Mining, herbs with Herbalism) at nothing, so routes use it and the shopping list says to gather it."]
	)

	Checkbox(
		"showRouteTab",
		L["Show the levelling route tab"],
		L["A side tab on the Professions window with a route to your target skill and its reagents. Tracked professions stay in the objective tracker either way."]
	)

	Checkbox(
		"showTrainer",
		L["Annotate trainer recipes"],
		L["Required skill, skill-up chance and cost on profession trainer recipes, and which one is best to train next for your route."]
	)

	Dropdown(
		"reagentTooltip",
		L["Reagent tooltips"],
		ns.REAGENT_TOOLTIP_OPTIONS,
		L["What hovering an item says about your professions: how much of it your tracked routes need (hold Shift for every recipe that uses it), every such recipe and its colour, or nothing."]
	)

	Dropdown(
		"sortMode",
		L["Sort recipes"],
		ns.SORT_OPTIONS,
		L["Sort recipes in one list, learned first, then unlearned. Default restores categories."]
	)

	Checkbox(
		"companionHints",
		L["Suggest companion addons"],
		L["Waypoint tooltips say when Shortest Path Forever, not installed or turned off, would plot the route."]
	)

	Checkbox(
		"whatsNew",
		L["Tell me what's new after an update"],
		L["One line in chat the first time a new version loads."]
	)

	Settings.RegisterAddOnCategory(category)
end
-- luacheck: pop

-- Through the setting, so the settings panel and its change callback stay in step.
---@param mode string
function ns.SetSortMode(mode)
	Settings.SetValue("SkillUpForever_sortMode", mode)
end

function ns.OpenSettings()
	Settings.OpenToCategory(category:GetID())
end
