local _, ns = ...

local WIDTH = 270
local MAX_LINES = 12
local LINE_HEIGHT = 16

local panel
local route
local pending = false

-- Learned recipes of the open profession that can still skill up, as the pure
-- model's snapshot. Target and skills are effective (base + racial bonus).
local function Snapshot(ctx, target)
	local recipes, netCosts = {}, {}
	for _, recipeID in ipairs(C_TradeSkillUI.GetAllRecipeIDs()) do
		local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
		if info and info.learned then
			ns.NoteLearned(recipeID)
			local thresholds = info.canSkillUp ~= false and ns.Model.Get(recipeID)
			if thresholds then
				local netCost = ns.NetCost(recipeID)
				netCosts[recipeID] = netCost
				recipes[#recipes + 1] = { recipeID = recipeID, thresholds = thresholds, netCost = netCost }
			end
		end
	end
	return { skill = ctx.skill, target = target + ctx.modifier, recipes = recipes }, netCosts
end

-- The chosen target in base skill, per profession; the trainer plans to it too.
function ns.RouteTarget(profession, base, max)
	local target = ns.db.routeTargets[profession] or base + 25
	return math.max(base + 1, math.min(target, max))
end

local function RecipeName(recipeID)
	local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
	return info and info.name or C_Spell.GetSpellName(recipeID) or ("recipe " .. recipeID)
end

local function Money(copper)
	return ns.FormatNet(ns.Model.RoundMoney(math.abs(copper)), copper < 0)
end

local function SetLine(index, text, color)
	local line = panel.lines[index]
	if not line then
		line = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		line:SetJustifyH("LEFT")
		line:SetWordWrap(false)
		line:SetPoint("TOPLEFT", panel.Label, "BOTTOMLEFT", 0, -12 - (index - 1) * LINE_HEIGHT)
		line:SetPoint("RIGHT", panel, "RIGHT", -12, 0)
		panel.lines[index] = line
	end
	line:SetText(text)
	line:SetTextColor((color or HIGHLIGHT_FONT_COLOR):GetRGB())
	line:Show()
end

local function Render(ctx)
	local count = 0
	local function Add(text, color)
		count = count + 1
		SetLine(count, text, color)
	end

	route = nil
	panel.Shop:Disable()
	if not ctx then
		Add("Open a profession to plan a route.", GRAY_FONT_COLOR)
	elseif C_TradeSkillUI.IsTradeSkillLinked() or C_TradeSkillUI.IsTradeSkillGuild() then
		-- Someone else's recipes: neither a route nor a record of what you know.
		Add("Routes are planned for your own professions.", GRAY_FONT_COLOR)
	elseif ctx.capped then
		Add(string.format("At the %d cap: train the next rank to continue.", ctx.max), GRAY_FONT_COLOR)
	else
		local target = ns.RouteTarget(ctx.name, ctx.base, ctx.max)
		panel.Target:SetText(tostring(target))
		local snapshot, netCosts = Snapshot(ctx, target)
		route = ns.Model.PlanRoute(snapshot)
		route.profession = ctx.name
		for i, segment in ipairs(route.segments) do
			if i == MAX_LINES then
				Add(string.format("+%d more steps", #route.segments - i + 1), GRAY_FONT_COLOR)
				break
			end
			local t = ns.Model.Get(segment.recipeID)
			Add(
				string.format(
					"~%d× %s → %d  %s",
					segment.crafts,
					RecipeName(segment.recipeID),
					segment.toSkill - ctx.modifier,
					Money(netCosts[segment.recipeID] * segment.expectedCrafts)
				),
				ns.COLORS[ns.Model.Color(t, segment.fromSkill)]
			)
		end
		if #route.segments > 0 then
			Add("Total  ~" .. Money(route.expectedCost), NORMAL_FONT_COLOR)
			panel.Shop:Enable()
		end
		if route.stopReason == "no_recipe" then
			Add(string.format("Nothing you know skills up past %d.", route.reachedSkill - ctx.modifier), RED_FONT_COLOR)
		end
		if route.excluded.unpriced > 0 then
			Add(string.format("%d recipes skipped: reagents not priced yet.", route.excluded.unpriced), GRAY_FONT_COLOR)
		end
	end
	for i = count + 1, #panel.lines do
		panel.lines[i]:Hide()
	end
	panel:SetHeight(108 + count * LINE_HEIGHT)
end

local function CommitTarget(editBox)
	local ctx = ns.SkillContext()
	local value = tonumber(editBox:GetText())
	if ctx and value then
		ns.db.routeTargets[ctx.name] = value
	end
	ns.RefreshRoute()
end

local function CreatePanel()
	panel = CreateFrame("Frame", nil, ProfessionsFrame.CraftingPage, "DefaultPanelFlatTemplate")
	panel:SetWidth(WIDTH)
	panel:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 2, 0)
	panel:SetTitle("Levelling route")
	panel.lines = {}

	local close = CreateFrame("Button", nil, panel, "UIPanelCloseButtonDefaultAnchors")
	close:SetScript("OnClick", function()
		ns.SetShowRoute(false)
	end)

	local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("TOPLEFT", 16, -36)
	label:SetText("Target skill")
	panel.Label = label

	local target = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
	target:SetSize(40, 20)
	target:SetPoint("LEFT", label, "RIGHT", 12, 0)
	target:SetNumeric(true)
	target:SetMaxLetters(3)
	target:SetAutoFocus(false)
	target:SetScript("OnEnterPressed", target.ClearFocus)
	target:SetScript("OnEditFocusLost", CommitTarget)
	target:SetScript("OnEscapePressed", function(editBox)
		editBox:SetText("")
		editBox:ClearFocus()
	end)
	panel.Target = target

	local shop = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	shop:SetSize(WIDTH - 32, 22)
	shop:SetPoint("BOTTOM", 0, 12)
	shop:SetText(ns.HasAuctionator() and "Send reagents to Auctionator" or "Print shopping list")
	shop:SetScript("OnClick", function()
		ns.ExportShopping(route)
	end)
	shop:SetScript("OnEnter", function(button)
		ns.ShowShoppingTooltip(button, route)
	end)
	shop:SetScript("OnLeave", GameTooltip_Hide)
	panel.Shop = shop
end

-- Coalesces bursts of list/skill/price updates into one plan.
function ns.RefreshRoute()
	if pending or not ns.db then
		return
	end
	pending = true
	C_Timer.After(0.2, function()
		pending = false
		if not (ProfessionsFrame and ProfessionsFrame:IsShown()) then
			return
		end
		if not ns.db.showRoute then
			if panel then
				panel:Hide()
			end
			return
		end
		if not panel then
			CreatePanel()
		end
		panel:Show()
		Render(ns.SkillContext())
	end)
end

function ns.AttachRoute()
	ProfessionsFrame:HookScript("OnShow", ns.RefreshRoute)
	local events = CreateFrame("Frame")
	events:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
	events:RegisterEvent("SKILL_LINES_CHANGED")
	events:SetScript("OnEvent", ns.RefreshRoute)
end
