---@type string, SkillUpNamespace
local _, ns = ...

local category

function ns.RegisterSettings()
	category = Settings.RegisterVerticalLayoutCategory(ns.TITLE)

	local function Register(key, varType, name)
		local setting = Settings.RegisterAddOnSetting(
			category,
			"SkillUpForever_" .. key,
			key,
			ns.db,
			varType,
			name,
			ns.DEFAULTS[key]
		)
		setting:SetValueChangedCallback(function()
			ns.PricesChanged()
			ns.RefreshRecipeList()
			ns.RefreshTrainer()
			ns.RefreshRouteTab()
		end)
		return setting
	end

	Settings.CreateCheckbox(
		category,
		Register("showRowText", Settings.VarType.Boolean, "Show skill on recipe rows"),
		"Skill-up chance and cost per skill-up at the right of each recipe."
	)

	Settings.CreateCheckbox(
		category,
		Register("showSkill", Settings.VarType.Boolean, "Show required skill on rows"),
		"Add the skill each recipe needs. Recipes you can't make yet always show it."
	)

	Settings.CreateCheckbox(
		category,
		Register("showTooltip", Settings.VarType.Boolean, "Show thresholds tooltip"),
		"Orange, yellow, green and grey thresholds when hovering a recipe."
	)

	Settings.CreateCheckbox(
		category,
		Register("showCost", Settings.VarType.Boolean, "Show cost per skill-up"),
		"Reagent cost divided by skill-up chance, on recipe rows and in the tooltip. "
			.. "Prices come from vendors you've visited, the auction house, or Auctionator."
	)

	Settings.CreateDropdown(
		category,
		Register("craftValue", Settings.VarType.String, "Count what crafts sell for"),
		function()
			local container = Settings.CreateControlTextContainer()
			container:Add("none", "Don't count it")
			container:Add("vendor", "Vendor sell price")
			container:Add("auction", "Auction price if higher")
			return container:GetData()
		end,
		"Subtract what the crafted item sells for from its cost. Auction prices are after the 5% cut, and may not sell."
	)

	Settings.CreateCheckbox(
		category,
		Register("scanAuctions", Settings.VarType.Boolean, "Scan the auction house"),
		"Search the auction house for known reagents when you open it (at most once an hour). "
			.. "Type /su scan to rescan. Items Auctionator priced today are skipped, and its prices are used."
	)

	Settings.CreateCheckbox(
		category,
		Register("gatherFree", Settings.VarType.Boolean, "Reagents you gather are free"),
		"Price what another of your professions gathers (Light Leather with Skinning, ore with Mining, "
			.. "herbs with Herbalism) at nothing, so routes use it and the shopping list says to gather it."
	)

	Settings.CreateCheckbox(
		category,
		Register("showRouteTab", Settings.VarType.Boolean, "Show the levelling route tab"),
		"A side tab on the Professions window with a route to your target skill and its reagents. "
			.. "Tracked professions stay in the objective tracker either way."
	)

	Settings.CreateCheckbox(
		category,
		Register("showTrainer", Settings.VarType.Boolean, "Annotate trainer recipes"),
		"Required skill, skill-up chance and cost on profession trainer recipes, "
			.. "and which one is best to train next for your route."
	)

	Settings.CreateDropdown(
		category,
		Register("reagentTooltip", Settings.VarType.String, "Reagent tooltips"),
		function()
			local container = Settings.CreateControlTextContainer()
			for _, option in ipairs(ns.REAGENT_TOOLTIP_OPTIONS) do
				container:Add(option[1], option[2])
			end
			return container:GetData()
		end,
		"What hovering an item says about your professions: how much of it your tracked routes need "
			.. "(hold Shift for every recipe that uses it), every such recipe and its colour, or nothing."
	)

	Settings.CreateDropdown(category, Register("sortMode", Settings.VarType.String, "Sort recipes"), function()
		local container = Settings.CreateControlTextContainer()
		for _, option in ipairs(ns.SORT_OPTIONS) do
			container:Add(option[1], option[2])
		end
		return container:GetData()
	end, "Sort recipes in one list, learned first, then unlearned. Default restores categories.")

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
