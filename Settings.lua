---@type string, SkillUpNamespace
local _, ns = ...

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

function ns.RegisterSettings()
	category = Settings.RegisterVerticalLayoutCategory(ns.TITLE)

	Checkbox(
		"showRowText",
		"Show skill on recipe rows",
		"Skill-up chance and cost per skill-up at the right of each recipe."
	)

	Checkbox(
		"showSkill",
		"Show required skill on rows",
		"Add the skill each recipe needs. Recipes you can't make yet always show it."
	)

	Checkbox(
		"showTooltip",
		"Show thresholds tooltip",
		"Orange, yellow, green and grey thresholds when hovering a recipe."
	)

	Checkbox(
		"showCost",
		"Show cost per skill-up",
		"Reagent cost divided by skill-up chance, on recipe rows and in the tooltip. "
			.. "Prices come from vendors you've visited, the auction house, or Auctionator."
	)

	Dropdown("craftValue", "Count what crafts sell for", {
		{ "none", "Don't count it" },
		{ "vendor", "Vendor sell price" },
		{ "auction", "Auction price if higher" },
	}, "Subtract what the crafted item sells for from its cost. Auction prices are after the 5% cut, and may not sell.")

	Checkbox(
		"scanAuctions",
		"Scan the auction house",
		"Search the auction house for known reagents when you open it (at most once an hour). "
			.. "Type /su scan to rescan. Items Auctionator priced today are skipped, and its prices are used."
	)

	Checkbox(
		"gatherFree",
		"Reagents you gather are free",
		"Price what another of your professions gathers (Light Leather with Skinning, ore with Mining, "
			.. "herbs with Herbalism) at nothing, so routes use it and the shopping list says to gather it."
	)

	Checkbox(
		"showRouteTab",
		"Show the levelling route tab",
		"A side tab on the Professions window with a route to your target skill and its reagents. "
			.. "Tracked professions stay in the objective tracker either way."
	)

	Checkbox(
		"showTrainer",
		"Annotate trainer recipes",
		"Required skill, skill-up chance and cost on profession trainer recipes, "
			.. "and which one is best to train next for your route."
	)

	Dropdown(
		"reagentTooltip",
		"Reagent tooltips",
		ns.REAGENT_TOOLTIP_OPTIONS,
		"What hovering an item says about your professions: how much of it your tracked routes need "
			.. "(hold Shift for every recipe that uses it), every such recipe and its colour, or nothing."
	)

	Dropdown(
		"sortMode",
		"Sort recipes",
		ns.SORT_OPTIONS,
		"Sort recipes in one list, learned first, then unlearned. Default restores categories."
	)

	Settings.RegisterAddOnCategory(category)
end

-- Through the setting, so the settings panel and its change callback stay in step.
---@param mode string
function ns.SetSortMode(mode)
	Settings.SetValue("SkillUpForever_sortMode", mode)
end

function ns.OpenSettings()
	Settings.OpenToCategory(category:GetID())
end
