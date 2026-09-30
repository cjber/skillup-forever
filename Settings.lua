---@type string, SkillUpNamespace
local _, ns = ...
local L = ns.L

-- Options → AddOns → SkillUp Forever: a short index page, then a stock subpage per group so no page grows
-- tall. Every row goes in through Settings.RegisterInitializer, which inserts it from Blizzard's secure delegate.
-- Settings.CreateCheckbox/CreateDropdown insert from our code instead, and the settings search reads every
-- layout, so that tainted it: a restricted button in the results (Social's Discord Sign In) was then blocked
-- and blamed on us.
local category

---@param target SkillUpCategory
local function Register(target, key, varType, name)
	local setting =
		Settings.RegisterAddOnSetting(target, "SkillUpForever_" .. key, key, ns.db, varType, name, ns.DEFAULTS[key])
	setting:SetValueChangedCallback(function()
		ns.PricesChanged()
		ns.RefreshRecipeList()
		ns.RefreshTrainer()
		ns.RefreshRouteTab()
	end)
	return setting
end

---@param target SkillUpCategory
local function Checkbox(target, key, name, tooltip)
	Settings.RegisterInitializer(
		target,
		Settings.CreateCheckboxInitializer(Register(target, key, Settings.VarType.Boolean, name), nil, tooltip)
	)
end

-- options: { value, label } pairs, in menu order.
---@param target SkillUpCategory
local function Dropdown(target, key, name, options, tooltip)
	local setting = Register(target, key, Settings.VarType.String, name)
	Settings.RegisterInitializer(
		target,
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

	-- Rows are grouped onto a stock subpage each; the category itself is the index, one button per group. A
	-- button goes in through Settings.RegisterInitializer too, and stays out of search (addSearchTags false),
	-- which finds the settings themselves.
	local function Section(name, rows)
		local subcategory = Settings.RegisterVerticalLayoutSubcategory(category, name)
		rows(subcategory)
		Settings.RegisterInitializer(
			category,
			CreateSettingsButtonInitializer(name, L["Open"], function()
				Settings.OpenToCategory(subcategory:GetID())
			end, nil, false)
		)
	end

	Section(L["Recipe rows"], function(rows)
		Checkbox(
			rows,
			"showRowText",
			L["Show skill on recipe rows"],
			L["Skill-up chance and cost per skill-up at the right of each recipe."]
		)

		Checkbox(
			rows,
			"showSkill",
			L["Show required skill on rows"],
			L["Add the skill each recipe needs. Recipes you can't make yet always show it."]
		)

		Checkbox(
			rows,
			"showTooltip",
			L["Show thresholds tooltip"],
			L["Orange, yellow, green and grey thresholds when hovering a recipe."]
		)

		Checkbox(
			rows,
			"showCost",
			L["Show cost per skill-up"],
			L["Reagent cost divided by skill-up chance, on recipe rows and in the tooltip. Common vendor reagents are priced from the start and updated at merchants you visit, reagents you gather are free, and auction prices need Auctionator."]
		)
	end)

	Section(L["Prices"], function(rows)
		Dropdown(
			rows,
			"craftValue",
			L["Count what crafts sell for"],
			ns.CRAFT_VALUE_OPTIONS,
			L["Subtract what the crafted item sells for from its cost. Auction prices need Auctionator, are after the 5% cut, and may not sell."]
		)

		Checkbox(
			rows,
			"gatherFree",
			L["Reagents you gather are free"],
			L["Price what another of your professions gathers (Light Leather with Skinning, ore with Mining, herbs with Herbalism) at nothing, so routes use it and the shopping list says to gather it."]
		)
	end)

	Section(L["Route and trainer"], function(rows)
		Checkbox(
			rows,
			"showRouteTab",
			L["Show the levelling route tab"],
			L["A side tab on the Professions window with a route to your target skill and its reagents. Tracked professions stay in the objective tracker either way."]
		)

		Checkbox(
			rows,
			"showTrainer",
			L["Annotate trainer recipes"],
			L["Required skill, skill-up chance and cost on profession trainer recipes, and which one is best to train next for your route."]
		)
	end)

	Section(L["Tooltips and sorting"], function(rows)
		Dropdown(
			rows,
			"reagentTooltip",
			L["Reagent tooltips"],
			ns.REAGENT_TOOLTIP_OPTIONS,
			L["What hovering an item says about your professions: how much of it your tracked routes need (hold Shift for every recipe that uses it), every such recipe and its colour, or nothing."]
		)

		Dropdown(
			rows,
			"sortMode",
			L["Sort recipes"],
			ns.SORT_OPTIONS,
			L["Sort recipes in one list, learned first, then unlearned. Default restores categories."]
		)
	end)

	Section(L["Addon"], function(rows)
		Checkbox(
			rows,
			"companionHints",
			L["Suggest companion addons"],
			L["Waypoint tooltips say when Shortest Path Forever, not installed or turned off, would plot the route."]
		)

		Checkbox(
			rows,
			"whatsNew",
			L["Tell me what's new after an update"],
			L["One line in chat the first time a new version loads."]
		)
	end)

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
