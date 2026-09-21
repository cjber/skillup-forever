local addonName, ns = ...

local DEFAULTS = {
	showRowText = true,
	showTooltip = true,
	sortMode = "blizzard", -- "blizzard" | "skill" | "chance"
}

ns.DEFAULTS = DEFAULTS
ns.TITLE = "SkillUp Forever"

-- Classic difficulty colours, matching the retail recipe list's own palette.
ns.COLORS = {
	red = RED_FONT_COLOR or CreateColor(1, 0.1, 0.1),
	orange = DIFFICULT_DIFFICULTY_COLOR or CreateColor(1, 0.5, 0.25),
	yellow = FAIR_DIFFICULTY_COLOR or CreateColor(1, 1, 0),
	green = EASY_DIFFICULTY_COLOR or CreateColor(0.25, 0.75, 0.25),
	grey = TRIVIAL_DIFFICULTY_COLOR or CreateColor(0.5, 0.5, 0.5),
	unknown = GRAY_FONT_COLOR or CreateColor(0.6, 0.6, 0.6),
}

local LIVE_COLOR = {
	[Enum.TradeskillRelativeDifficulty.Optimal] = "orange",
	[Enum.TradeskillRelativeDifficulty.Medium] = "yellow",
	[Enum.TradeskillRelativeDifficulty.Easy] = "green",
	[Enum.TradeskillRelativeDifficulty.Trivial] = "grey",
}

function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. ns.TITLE .. "|r " .. msg)
end

-- Forever's SavedVariables often fail to load (forever-bugs#34), so defaults
-- are always the base and whatever did load is merged over them.
local function LoadDB()
	local loaded = type(SkillUpForeverDB) == "table" and SkillUpForeverDB or {}
	for key, value in pairs(DEFAULTS) do
		if type(loaded[key]) ~= type(value) then
			loaded[key] = value
		end
	end
	SkillUpForeverDB = loaded
	ns.db = loaded
end

-- Effective skill for difficulty purposes includes racial bonuses.
function ns.CurrentSkill()
	local info = Professions.GetProfessionInfo()
	if not info or not info.skillLevel then
		return nil, nil
	end
	return info.skillLevel + (info.skillModifier or 0), info.displayName
end

-- Everything a row or tooltip renders for one recipe at the current skill.
function ns.Describe(recipeInfo, skill)
	local thresholds = ns.Model.Get(recipeInfo.recipeID)
	local liveColor = LIVE_COLOR[recipeInfo.relativeDifficulty]
	if not thresholds or not skill then
		return { thresholds = nil, color = liveColor or "unknown" }
	end
	return {
		thresholds = thresholds,
		color = liveColor or ns.Model.Color(thresholds, skill),
		chance = ns.Model.Chance(thresholds, skill),
	}
end

local function Audit()
	local skill, professionName = ns.CurrentSkill()
	if not skill or not ProfessionsFrame or not ProfessionsFrame:IsShown() then
		ns.Print("open a profession first.")
		return
	end
	local checked, missing, mismatches = 0, 0, {}
	for _, recipeID in ipairs(C_TradeSkillUI.GetAllRecipeIDs()) do
		local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
		local live = info and info.learned and LIVE_COLOR[info.relativeDifficulty]
		if live then
			local t = ns.Model.Get(recipeID)
			if not t then
				missing = missing + 1
			else
				checked = checked + 1
				local predicted = ns.Model.Color(t, skill)
				local grey = info.maxTrivialLevel
				if predicted ~= live or (grey and grey > 0 and grey ~= t[4]) then
					mismatches[#mismatches + 1] = string.format(
						"%s (%d): table %d/%d/%d/%d says %s, game says %s, maxTrivialLevel %s",
						info.name,
						recipeID,
						t[1],
						t[2],
						t[3],
						t[4],
						predicted,
						live,
						tostring(grey)
					)
				end
			end
		end
	end
	ns.Print(
		string.format(
			"%s at %d: %d checked, %d mismatched, %d without data.",
			professionName or "?",
			skill,
			checked,
			#mismatches,
			missing
		)
	)
	for _, line in ipairs(mismatches) do
		ns.Print(line)
	end
end

SLASH_SKILLUPFOREVER1 = "/skillup"
SLASH_SKILLUPFOREVER2 = "/su"
SlashCmdList.SKILLUPFOREVER = function(msg)
	if strtrim(msg or ""):lower() == "audit" then
		Audit()
	else
		ns.OpenSettings()
	end
end

function SkillUpForever_OnAddonCompartmentClick()
	ns.OpenSettings()
end

EventUtil.ContinueOnAddOnLoaded(addonName, function()
	LoadDB()
	ns.RegisterSettings()
end)

EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", function()
	ns.AttachRecipeList()
end)
