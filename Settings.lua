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
			ns.RefreshRecipeList()
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

	Settings.CreateCheckbox(
		category,
		Register("scanAuctions", Settings.VarType.Boolean, "Scan the auction house"),
		"Search the auction house for known reagents when you open it (at most once an hour). "
			.. "Type /su scan to rescan."
	)

	Settings.CreateDropdown(category, Register("sortMode", Settings.VarType.String, "Sort recipes"), function()
		local container = Settings.CreateControlTextContainer()
		for _, option in ipairs(ns.SORT_OPTIONS) do
			container:Add(option[1], option[2])
		end
		return container:GetData()
	end, "Order of recipes within each category.")

	Settings.RegisterAddOnCategory(category)
end

-- Through the setting, so the settings panel and its change callback stay in step.
function ns.SetSortMode(mode)
	Settings.SetValue("SkillUpForever_sortMode", mode)
end

function ns.OpenSettings()
	Settings.OpenToCategory(category:GetID())
end
