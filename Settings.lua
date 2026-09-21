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
		"Required skill and skill-up chance at the right of each recipe."
	)

	Settings.CreateCheckbox(
		category,
		Register("showTooltip", Settings.VarType.Boolean, "Show thresholds tooltip"),
		"Orange, yellow, green and grey thresholds when hovering a recipe."
	)

	Settings.CreateDropdown(category, Register("sortMode", Settings.VarType.String, "Sort recipes"), function()
		local container = Settings.CreateControlTextContainer()
		container:Add("blizzard", "Default")
		container:Add("skill", "Required skill")
		container:Add("chance", "Skill-up chance")
		return container:GetData()
	end, "Order of recipes within each category.")

	Settings.RegisterAddOnCategory(category)
end

function ns.OpenSettings()
	Settings.OpenToCategory(category:GetID())
end
