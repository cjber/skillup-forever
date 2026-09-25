---@type string, SkillUpNamespace
local addonName, ns = ...
local L = ns.L

---@type SkillUpDefaults
local DEFAULTS = {
	showRowText = true,
	showSkill = false,
	showTooltip = true,
	showCost = true,
	craftValue = "vendor", -- "none" | "vendor" | "auction"
	sortMode = "blizzard", -- "blizzard" | "skill" | "chance" | "cost"
	showTrainer = true,
	showRouteTab = true,
	reagentTooltip = "route",
	gatherFree = true,
	vendor = {}, -- [itemID] = copper per unit, observed at merchants
	routeTargets = {}, -- [profession skill line] = target base skill
	learned = {}, -- ["Name-Realm"] = { [recipeID] = true }
	professionIDs = {}, -- [localized profession name] = skill line, seen with the profession open
	trackedProfessions = {}, -- [profession skill line] = true: reagents shown in the objective tracker
	trainer = {}, -- [skill line] = { [recipeID] = { fee, required base skill } }, recorded at trainers
}

ns.DEFAULTS = DEFAULTS
ns.SORT_OPTIONS = {
	{ "blizzard", DEFAULT },
	{ "skill", L["Required skill"] },
	{ "chance", L["Skill-up chance"] },
	{ "cost", L["Cheapest skill-up"] },
}
ns.REAGENT_TOOLTIP_OPTIONS = {
	{ "off", OFF },
	{ "route", L["Tracked routes (Shift for all)"] },
	{ "full", L["Every recipe that uses it"] },
}
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

---@param msg string
function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. ns.TITLE .. "|r " .. msg)
end

-- Forever's SavedVariables often fail to load (forever-bugs#34), so defaults
-- are always the base and whatever did load is merged over them.
local function LoadDB()
	local loaded = type(SkillUpForeverDB) == "table" and SkillUpForeverDB or {}
	-- Reagent tooltips were on or off before they had a compact mode.
	if loaded.showReagentTooltip == false then
		loaded.reagentTooltip = "off"
	end
	loaded.showReagentTooltip = nil
	-- Auction prices come from Auctionator now; drop what SkillUp's own scanner saved.
	loaded.scanAuctions, loaded.tracked, loaded.auctions = nil, nil, nil
	for key, value in pairs(DEFAULTS) do
		if type(loaded[key]) ~= type(value) then
			loaded[key] = type(value) == "table" and {} or value
		end
	end
	local mode = loaded.reagentTooltip
	local valid = false
	for _, option in ipairs(ns.REAGENT_TOOLTIP_OPTIONS) do
		valid = valid or option[1] == mode
	end
	if not valid then
		loaded.reagentTooltip = DEFAULTS.reagentTooltip
	end
	SkillUpForeverDB = loaded
	ns.db = loaded
end

local KNOWN_SKILL_LINES = {}
for _, skillLine in pairs(ns.ProfessionSkillLines or {}) do
	KNOWN_SKILL_LINES[skillLine] = true
end

-- The skill line recipe data uses for a profession. Forever's profession APIs
-- report other IDs (GetProfessionInfo gave 8167, 8175, ...), so the name is the
-- key: the bundled enUS names, or the pairing seen when the profession was open.
local warned = {}

---@param name string?
---@param reported integer?
---@return integer?
function ns.ProfessionSkillLine(name, reported)
	local skillLine = ns.ProfessionSkillLines[name] or ns.db.professionIDs[name]
	if skillLine then
		return skillLine
	end
	if KNOWN_SKILL_LINES[reported] then
		return reported
	end
	if name and not warned[name] then
		warned[name] = true
		ns.Print(string.format(L["can't identify the profession %s (%s); please report it."], name, tostring(reported)))
	end
end

-- Effective skill for difficulty purposes includes racial bonuses; the cap is
-- on base skill, and at the cap nothing can skill up whatever its colour.
---@return SkillUpContext?
function ns.SkillContext()
	local info = Professions and Professions.GetProfessionInfo()
	if not info or not info.skillLevel then
		return nil
	end
	local modifier = info.skillModifier or 0
	local base = C_TradeSkillUI.GetBaseProfessionInfo()
	return {
		skillLine = base and ns.ProfessionSkillLine(base.professionName, base.professionID),
		skill = info.skillLevel + modifier,
		base = info.skillLevel,
		modifier = modifier,
		max = info.maxSkillLevel,
		name = info.displayName,
		capped = info.maxSkillLevel and info.maxSkillLevel > 0 and info.skillLevel >= info.maxSkillLevel,
	}
end

-- The player's professions by skill line, secondary ones included. GetProfessions
-- leaves nil gaps for empty slots, so walk its full return count.
---@return table<integer, SkillUpProfession>
function ns.PlayerProfessions()
	local professions = {}
	local function Add(...)
		for i = 1, select("#", ...) do
			local index = select(i, ...)
			if index then
				local name, icon, rank, maxRank, _, _, reported, modifier = GetProfessionInfo(index)
				local skillLine = ns.ProfessionSkillLine(name, reported)
				if skillLine then
					modifier = modifier or 0
					professions[skillLine] = {
						skillLine = skillLine,
						professionID = reported,
						name = name,
						icon = icon,
						base = rank,
						max = maxRank,
						modifier = modifier,
						skill = rank + modifier,
						capped = maxRank > 0 and rank >= maxRank,
					}
				end
			end
		end
	end
	Add(GetProfessions())
	return professions
end

-- Recipes this character has been seen to know in the Professions window, for
-- places (trainer, item tooltips) that can't ask it. C_SpellBook.IsSpellKnown covers
-- professions not opened yet, and every session while SavedVariables fail to load.
local function LearnedRecipes()
	local key = UnitName("player") .. "-" .. GetNormalizedRealmName()
	ns.db.learned[key] = ns.db.learned[key] or {}
	return ns.db.learned[key]
end

local function NoteLearnedRecipes()
	if not ns.db or C_TradeSkillUI.IsTradeSkillLinked() or C_TradeSkillUI.IsTradeSkillGuild() then
		return
	end
	-- A non-English client has no bundled name; learn it from the open profession.
	local base = C_TradeSkillUI.GetBaseProfessionInfo()
	if base and base.professionName and KNOWN_SKILL_LINES[base.professionID] then
		ns.db.professionIDs[base.professionName] = base.professionID
	end
	local learned = LearnedRecipes()
	for _, recipeID in ipairs(C_TradeSkillUI.GetAllRecipeIDs()) do
		local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
		if info then
			learned[recipeID] = info.learned or nil
		end
	end
end

-- An unlearned profession takes its recipes with it.
local function ForgetDroppedProfessions()
	if not ns.db then
		return
	end
	local professions = ns.PlayerProfessions()
	-- Skill lines can arrive empty at login; that is not every profession dropped.
	if not next(professions) then
		return
	end
	local learned = LearnedRecipes()
	for recipeID in pairs(learned) do
		local recipe = ns.RecipeData[recipeID]
		if recipe and not professions[recipe.skillLine] then
			learned[recipeID] = nil
		end
	end
end

---@param recipeID integer
---@return boolean
function ns.IsLearned(recipeID)
	return LearnedRecipes()[recipeID] or C_SpellBook.IsSpellKnown(recipeID)
end

local learnEvents = CreateFrame("Frame")
learnEvents:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
learnEvents:RegisterEvent("SKILL_LINES_CHANGED")
learnEvents:SetScript("OnEvent", function(_, event)
	if event == "SKILL_LINES_CHANGED" then
		ForgetDroppedProfessions()
	else
		NoteLearnedRecipes()
	end
	ns.InvalidatePlans()
end)

-- Everything a row or tooltip renders for one recipe at the current skill.
---@param recipeInfo TradeSkillRecipeInfo|SkillUpRecipeInfo
---@param ctx SkillUpContext?
---@return SkillUpDescription
function ns.Describe(recipeInfo, ctx)
	local thresholds = ns.Model.Get(recipeInfo.recipeID)
	local liveColor = LIVE_COLOR[recipeInfo.relativeDifficulty]
	local cost = ns.RecipeCost(recipeInfo.recipeID)
	local value = cost and ns.CraftValue(recipeInfo.recipeID)
	-- Net of what the craft sells for; negative means each craft makes money.
	local net = cost and cost - (value and value.copper or 0)
	if not thresholds or not ctx then
		return { thresholds = nil, color = liveColor or "unknown", cost = cost, value = value, net = net }
	end
	local chance = ns.Model.Chance(thresholds, ctx.skill)
	if chance and (ctx.capped or (recipeInfo.learned and recipeInfo.canSkillUp == false)) then
		chance = 0
	end
	return {
		thresholds = thresholds,
		color = liveColor or ns.Model.Color(thresholds, ctx.skill),
		chance = chance,
		cost = cost,
		value = value,
		net = net,
		perSkillUp = ns.Model.CostPerSkillUp(net, chance),
	}
end

-- The compact "skill · chance · cost" text of a recipe row or trainer service.
---@param d SkillUpDescription
---@return string
function ns.FormatRow(d)
	if not d.thresholds then
		return "?"
	end
	-- A recipe you can't make yet keeps its requirement: it's the only useful number.
	if not d.chance then
		return tostring(d.thresholds[1])
	end
	local parts = {}
	if ns.db.showSkill then
		parts[#parts + 1] = tostring(d.thresholds[1])
	end
	parts[#parts + 1] = string.format("%d%%", math.floor(d.chance * 100 + 0.5))
	local perSkillUp = d.perSkillUp
	if ns.db.showCost and perSkillUp then
		parts[#parts + 1] = ns.FormatNet(ns.Model.RoundMoney(math.abs(perSkillUp)), perSkillUp < 0)
	end
	return table.concat(parts, " · ")
end

---@param d SkillUpDescription
---@return ColorMixin
function ns.RowColor(d)
	return ns.COLORS[d.chance and d.color or (d.thresholds and "red" or "unknown")]
end

local function Audit()
	local ctx = ProfessionsFrame and ProfessionsFrame:IsShown() and ns.SkillContext()
	if not ctx then
		ns.Print("open a profession first.")
		return
	end
	local skill = ctx.skill
	local checked, missing, mismatches = 0, 0, {}
	for _, recipeID in ipairs(C_TradeSkillUI.GetAllRecipeIDs()) do
		local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
		local live = info and info.learned and LIVE_COLOR[info.relativeDifficulty]
		if info and live then
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
			ctx.name or "?",
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
	local command = strtrim(msg or ""):lower()
	if command == "audit" then
		Audit()
	else
		ns.OpenSettings()
	end
end

function SkillUpForever_OnAddonCompartmentClick()
	ns.OpenSettings()
end

-- Blizzard_Professions may already be loaded (another addon opened it), in which
-- case the continuation runs at once — so register it only after our own files
-- and SavedVariables are in place.
EventUtil.ContinueOnAddOnLoaded(addonName, function()
	-- /reload doesn't re-read the .toc, so files added by an update stay unloaded.
	if not (ns.RecipeData and ns.ProfessionSkillLines and ns.TrainerFees and ns.TrainerRanks and ns.RecipeSources) then
		ns.Print("|cffff4040" .. L["files are missing: restart the game (not /reload) after updating."] .. "|r")
		return
	end
	LoadDB()
	ns.InitPrices()
	ns.RegisterSettings()
	ns.AttachItemTooltips()
	ns.InitShopping()
	EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", ns.AttachRecipeList)
	EventUtil.ContinueOnAddOnLoaded("Blizzard_TrainerUI", ns.AttachTrainer)
end)
