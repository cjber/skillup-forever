---@type string, SkillUpNamespace
local _, ns = ...

-- Per trainer update: which recipe each service teaches, and the one to train next.
---@type SkillUpTrainerState?
local state

-- The service tooltip carries the taught spell when the client exposes it; the
-- name is the fallback. Only an ID we have data for counts as a recipe.
---@param index integer
---@return integer?
local function TooltipRecipe(index)
	local data = C_TooltipInfo and C_TooltipInfo.GetTrainerService(index)
	local id = data and data.id
	if not (issecretvalue and issecretvalue(id)) and id and ns.RecipeData[id] then
		return id
	end
end

---@param services SkillUpTrainerService[]
---@return integer?
local function TrainerSkillLine(services)
	for _, service in pairs(services) do
		if service.recipeID then
			return ns.RecipeData[service.recipeID].skillLine
		end
	end
	local professions = ns.PlayerProfessions()
	for index in pairs(services) do
		local skillName = GetTrainerServiceSkillReq(index)
		for skillLine, profession in pairs(professions) do
			if profession.name == skillName then
				return skillLine
			end
		end
	end
end

---@param services SkillUpTrainerService[]
---@return table<integer, boolean>
local function Known(services)
	local known = {}
	for _, service in pairs(services) do
		if service.recipeID and service.kind == "used" then
			known[service.recipeID] = true
		end
	end
	return known
end

---@param services SkillUpTrainerService[]
---@return SkillUpService[]
local function Candidates(services)
	local candidates = {}
	local money = GetMoney()
	for index, service in pairs(services) do
		local thresholds = service.recipeID and ns.Model.Get(service.recipeID)
		local fee = GetTrainerServiceCost(index)
		if thresholds and service.kind == "available" and not ns.IsLearned(service.recipeID) and fee <= money then
			candidates[#candidates + 1] = {
				recipeID = service.recipeID,
				thresholds = thresholds,
				netCost = ns.NetCost(service.recipeID),
				fee = fee,
			}
		end
	end
	table.sort(candidates, function(a, b)
		return a.recipeID < b.recipeID
	end)
	return candidates
end

---@return SkillUpTrainerState
local function BuildState()
	local services = {}
	for index = 1, GetNumTrainerServices() do
		local name, kind = GetTrainerServiceInfo(index)
		services[index] = { name = name, kind = kind, recipeID = TooltipRecipe(index) }
	end
	local skillLine = TrainerSkillLine(services)
	local rank, maxRank, modifier = GetTrainerTradeskillRankValues()
	if not (skillLine and rank and maxRank) then
		return { services = services }
	end
	local names = ns.RecipeNames[skillLine] or {}
	for _, service in pairs(services) do
		if not service.recipeID and service.name then
			local match = names[service.name]
			service.ambiguous = match == false
			service.recipeID = match or nil
		end
	end
	-- Every recipe this trainer teaches, its fee and required skill, for routes
	-- planned away from it (bundled base fees miss discounts and Forever changes).
	local seen = ns.db.trainer[skillLine] or {}
	ns.db.trainer[skillLine] = seen
	for index, service in pairs(services) do
		if service.recipeID then
			local _, required = GetTrainerServiceSkillReq(index)
			seen[service.recipeID] = { GetTrainerServiceCost(index), required or 0 }
		end
	end
	ns.InvalidatePlans()
	modifier = modifier or 0
	local ctx = {
		skillLine = skillLine,
		base = rank,
		skill = rank + modifier,
		modifier = modifier,
		max = maxRank,
		capped = maxRank > 0 and rank >= maxRank,
	}
	local best = not ctx.capped
		and ns.Model.RecommendTraining(ns.RouteSnapshot(ctx, Known(services)), Candidates(services))
	return { services = services, ctx = ctx, best = best and best.recipeID or nil }
end

---@param button SkillUpTrainerButton
---@param elementData SkillUpTrainerElement
local function Decorate(button, elementData)
	local text = button.SkillUpText
	if text then
		text:Hide()
	end
	elementData = elementData and (elementData.data or elementData)
	local index = elementData and elementData.skillIndex
	-- No state while a rebuild is pending; the rebuild redecorates.
	local current = state
	local service = current and index and current.services[index]
	if not (current and service and current.ctx and (service.recipeID or service.ambiguous)) then
		return
	end
	if not text then
		text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		text:SetPoint("BOTTOMRIGHT", -8, 6)
		text:SetJustifyH("RIGHT")
		button.SkillUpText = text
	end
	if service.recipeID then
		local d = ns.Describe({ recipeID = service.recipeID, learned = service.kind == "used" }, current.ctx)
		local best = service.recipeID == current.best and "|cffffd100Best next|r · " or ""
		text:SetText(best .. ns.FormatRow(d))
		text:SetTextColor(ns.RowColor(d):GetRGB())
	else
		text:SetText("?")
		text:SetTextColor(ns.COLORS.unknown:GetRGB())
	end
	text:Show()
end

local function DecorateAll()
	ClassTrainerFrame.ScrollBox:ForEachFrame(function(button)
		Decorate(button, button:GetElementData())
	end)
	local step = GetTrainerServiceStepIndex()
	if step and ClassTrainerFrame.skillStepButton:IsShown() then
		Decorate(ClassTrainerFrame.skillStepButton, { skillIndex = step })
	end
end

-- Blizzard updates once per service name that arrives, and redraws the buttons
-- inside each update; drop the old state at once and rebuild once, next frame.
local pending = false
function ns.RefreshTrainer()
	state = nil
	if pending or not (ClassTrainerFrame and ClassTrainerFrame:IsShown()) then
		return
	end
	pending = true
	C_Timer.After(0, function()
		pending = false
		local tradeskill = C_Trainer.GetTrainerType() == Enum.TrainerType.Tradeskills
		state = ns.db.showTrainer and tradeskill and ClassTrainerFrame:IsShown() and BuildState() or nil
		DecorateAll()
	end)
end

function ns.AttachTrainer()
	hooksecurefunc("ClassTrainerFrame_InitServiceButton", Decorate)
	hooksecurefunc("ClassTrainerFrame_Update", ns.RefreshTrainer)
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_MONEY")
	events:RegisterEvent("TRAINER_CLOSED")
	events:SetScript("OnEvent", ns.RefreshTrainer)
end
