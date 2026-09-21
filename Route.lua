local _, ns = ...

local WIDTH = 270
local MAX_LINES = 12
local LINE_HEIGHT = 16
local MAX_REAGENTS = 10

local panel, tab
local route
local pending = false

-- Learned recipes of the open profession that can still skill up, as the pure
-- model's snapshot. Target and skills are effective (base + racial bonus).
local function Snapshot(ctx, target)
	local recipes, netCosts = {}, {}
	for _, recipeID in ipairs(C_TradeSkillUI.GetAllRecipeIDs()) do
		local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
		if info and info.learned then
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
-- A target already reached gives way to the default, and nothing passes the cap.
function ns.RouteTarget(skillLine, base, max)
	local saved = ns.db.routeTargets[skillLine]
	return math.min(saved and saved > base and saved or base + 25, max)
end

local function RecipeName(recipeID)
	local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
	return info and info.name or C_Spell.GetSpellName(recipeID) or ("recipe " .. recipeID)
end

local function Money(copper)
	return ns.FormatNet(ns.Model.RoundMoney(math.abs(copper)), copper < 0)
end

local function SetLine(index, text, color, count, countColor)
	local line = panel.lines[index]
	if not line then
		line = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		line:SetJustifyH("LEFT")
		line:SetWordWrap(false)
		line:SetPoint("TOPLEFT", panel.Label, "BOTTOMLEFT", 0, -12 - (index - 1) * LINE_HEIGHT)
		line.Count = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		line.Count:SetPoint("TOP", line, "TOP")
		line.Count:SetPoint("RIGHT", panel, "RIGHT", -12, 0)
		panel.lines[index] = line
	end
	line:SetPoint("RIGHT", panel, "RIGHT", count and -56 or -12, 0)
	line:SetText(text)
	line:SetTextColor((color or HIGHLIGHT_FONT_COLOR):GetRGB())
	line.Count:SetText(count or "")
	line.Count:SetTextColor((countColor or HIGHLIGHT_FONT_COLOR):GetRGB())
	line:Show()
	line.Count:Show()
end

-- The drawer opens beside the tab column, level with our tab's bottom, and
-- drops as far as needed to stay inside the window's height.
local function Place()
	local tabBottom, frameTop = tab:GetBottom(), ProfessionsFrame:GetTop()
	panel:ClearAllPoints()
	if tabBottom and frameTop and tabBottom + panel:GetHeight() > frameTop then
		panel:SetPoint("TOP", ProfessionsFrame, "TOP")
	else
		panel:SetPoint("BOTTOM", tab, "BOTTOM")
	end
	panel:SetPoint("LEFT", tab, "RIGHT", 0, 0)
end

local function Render(ctx)
	local count = 0
	local function Add(text, color, right, rightColor)
		count = count + 1
		SetLine(count, text, color, right, rightColor)
	end

	route = nil
	local reagents = {}
	if not ctx then
		Add("Open a profession to plan a route.", GRAY_FONT_COLOR)
	elseif C_TradeSkillUI.IsTradeSkillLinked() or C_TradeSkillUI.IsTradeSkillGuild() then
		-- Someone else's recipes: neither a route nor a record of what you know.
		Add("Routes are planned for your own professions.", GRAY_FONT_COLOR)
	elseif ctx.capped then
		Add(string.format("At the %d cap: train the next rank to continue.", ctx.max), GRAY_FONT_COLOR)
	else
		local target = ns.RouteTarget(ctx.skillLine, ctx.base, ctx.max)
		if not panel.Target:HasFocus() then
			panel.Target:SetText(tostring(target))
		end
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
					"%d× %s to %d  %s",
					segment.crafts,
					RecipeName(segment.recipeID),
					segment.toSkill - ctx.modifier,
					Money(netCosts[segment.recipeID] * segment.expectedCrafts)
				),
				ns.COLORS[ns.Model.Color(t, segment.fromSkill)]
			)
		end
		if #route.segments > 0 then
			Add("Total  " .. Money(route.expectedCost), NORMAL_FONT_COLOR)
			reagents = ns.RouteReagents(route)
		end
		if #route.segments == 0 and route.excluded.unpriced > 0 then
			Add("Price reagents at a vendor or the AH.", GRAY_FONT_COLOR)
		elseif route.stopReason == "no_recipe" then
			local known = route.excluded.unpriced > 0 and "Nothing priced you know" or "Nothing you know"
			Add(string.format("%s skills up past %d.", known, route.reachedSkill - ctx.modifier), RED_FONT_COLOR)
		end
		if #route.segments > 0 and route.excluded.unpriced > 0 then
			Add(string.format("%d recipes skipped: reagents not priced yet.", route.excluded.unpriced), GRAY_FONT_COLOR)
		end
	end
	if #reagents > 0 then
		Add(" ")
		Add("Reagents", NORMAL_FONT_COLOR, "have", NORMAL_FONT_COLOR)
		for i, item in ipairs(reagents) do
			if i == MAX_REAGENTS then
				Add(string.format("+%d more reagents", #reagents - i + 1), GRAY_FONT_COLOR)
				break
			end
			local text, have, color = ns.ReagentText(item)
			Add(text, nil, have, color)
		end
		-- A pinned list follows the route it came from as skill and bags change.
		if ns.db.pinned and ns.db.pinned.profession == route.profession then
			ns.PinShopping(route)
		end
	end
	panel.Pin:SetEnabled(#reagents > 0)
	panel.Auctionator:SetEnabled(#reagents > 0)
	for i = count + 1, #panel.lines do
		panel.lines[i]:Hide()
		panel.lines[i].Count:Hide()
	end
	panel:SetHeight(108 + count * LINE_HEIGHT)
	Place()
end

local function CommitTarget(editBox)
	local ctx = ns.SkillContext()
	local value = tonumber(editBox:GetText())
	if ctx and ctx.skillLine and value then
		ns.db.routeTargets[ctx.skillLine] = value
	end
	ns.RefreshRoute()
end

local function CreatePanel()
	panel = CreateFrame("Frame", nil, ProfessionsFrame.CraftingPage, "DefaultPanelFlatTemplate")
	panel:SetWidth(WIDTH)
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

	local pin = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	pin:SetText("Pin list")
	pin:SetScript("OnClick", function()
		ns.PinShopping(route)
	end)
	panel.Pin = pin

	-- Only auction house reagents still missing go to the Auctionator list.
	local auctionator = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	auctionator:SetText("To Auctionator")
	auctionator:SetScript("OnClick", function()
		ns.SendToAuctionator(route.profession, ns.RouteReagents(route))
	end)
	panel.Auctionator = auctionator

	if ns.HasAuctionator() then
		pin:SetSize((WIDTH - 36) / 2, 22)
		pin:SetPoint("BOTTOMLEFT", 16, 12)
		auctionator:SetSize((WIDTH - 36) / 2, 22)
		auctionator:SetPoint("BOTTOMRIGHT", -16, 12)
	else
		pin:SetSize(WIDTH - 32, 22)
		pin:SetPoint("BOTTOM", 0, 12)
		auctionator:Hide()
	end
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

function ns.SetShowRoute(shown)
	ns.db.showRoute = shown
	tab:SetChecked(shown)
	ns.RefreshRoute()
end

-- Directly under the last profession tab Forever shows, in the same tab art.
local function PlaceTab()
	local last = ProfessionsFrame.ProfessionsOverviewTab
	for _, professionTab in ipairs(ProfessionsFrame.rightProfessionTabs or {}) do
		if professionTab:IsShown() then
			last = professionTab
		end
	end
	tab:ClearAllPoints()
	tab:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -2)
end

local function CreateTab()
	tab = CreateFrame("Frame", nil, ProfessionsFrame.CraftingPage, "LargeSideTabButtonTemplate")
	tab.Icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
	tab:SetFillToInterior(true)
	tab.tooltipText = "Levelling route"
	tab:EnableMouse(true)
	tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
		if button == "LeftButton" and upInside then
			ns.SetShowRoute(not ns.db.showRoute)
		end
	end)
	tab:SetChecked(ns.db.showRoute)
	PlaceTab()
	hooksecurefunc(ProfessionsFrame, "RefreshRightTabs", PlaceTab)
end

function ns.AttachRoute()
	CreateTab()
	ProfessionsFrame:HookScript("OnShow", ns.RefreshRoute)
	local events = CreateFrame("Frame")
	events:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
	events:RegisterEvent("SKILL_LINES_CHANGED")
	events:RegisterEvent("BAG_UPDATE_DELAYED")
	events:RegisterEvent("ITEM_DATA_LOAD_RESULT")
	events:SetScript("OnEvent", ns.RefreshRoute)
end
