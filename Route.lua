local _, ns = ...

local LINE_HEIGHT = 16
local MAX_LINES = 24

local page, tab
local selected -- skill line shown on the page
local pending = false

-- The chosen target in base skill, per profession; the trainer plans to it too.
-- A target already reached gives way to the default, and nothing passes the cap.
function ns.RouteTarget(skillLine, base, max)
	local saved = ns.db.routeTargets[skillLine]
	return math.min(saved and saved > base and saved or base + 25, max)
end

-- The cheapest route to the target from the recipes this character knows, for
-- any of its professions: bundled recipe data plus the learned record, so the
-- profession needn't be open. `known` adds recipes the caller knows are
-- learned (the trainer's "used" services). Skills are effective (base + bonus).
function ns.RouteSnapshot(profession, known)
	local recipes = {}
	for recipeID, recipe in pairs(ns.RecipeData) do
		local thresholds = recipe.skillLine == profession.skillLine and ns.Model.Get(recipeID)
		if thresholds and (known and known[recipeID] or ns.IsLearned(recipeID)) then
			recipes[#recipes + 1] = { recipeID = recipeID, thresholds = thresholds, netCost = ns.NetCost(recipeID) }
		end
	end
	local target = ns.RouteTarget(profession.skillLine, profession.base, profession.max)
	return { skill = profession.skill, target = target + profession.modifier, recipes = recipes }
end

-- Trainer-taught recipes of this profession not yet learned that could skill up
-- somewhere between here and the target, at what a trainer was seen to charge or
-- else the bundled base fee. Nothing is used before the trainer would teach it:
-- the thresholds' first value is where a recipe turns orange, not where it's taught.
local function Trainable(profession, snapshot)
	local services = {}
	local seen = ns.db.trainer[profession.skillLine] or {}
	for recipeID, recipe in pairs(ns.RecipeData) do
		local training = recipe.skillLine == profession.skillLine and (seen[recipeID] or ns.TrainerFees[recipeID])
		local t = training and not ns.IsLearned(recipeID) and ns.Model.Get(recipeID)
		if t then
			local taught = { math.max(t[1], training[2] + profession.modifier), t[2], t[3], t[4] }
			if taught[1] <= snapshot.target and t[4] > snapshot.skill then
				services[#services + 1] =
					{ recipeID = recipeID, thresholds = taught, netCost = ns.NetCost(recipeID), fee = training[1] }
			end
		end
	end
	table.sort(services, function(a, b)
		return a.recipeID < b.recipeID
	end)
	return services
end

-- Planning with training re-plans once per candidate, so plans are kept until
-- prices, recipes, fees or targets change; skill is part of the key.
local plans = {}

function ns.InvalidatePlans()
	plans = {}
end

function ns.PlanRoute(profession)
	local target = ns.RouteTarget(profession.skillLine, profession.base, profession.max)
	local key = profession.skill .. ":" .. target
	local cached = plans[profession.skillLine]
	if cached and cached.key == key then
		return cached.route
	end
	local snapshot = ns.RouteSnapshot(profession)
	local route = ns.Model.PlanWithTraining(snapshot, Trainable(profession, snapshot))
	route.profession = profession.name
	route.target = target
	plans[profession.skillLine] = { key = key, route = route }
	return route
end

local function RecipeName(recipeID)
	return C_Spell.GetSpellName(recipeID) or ("recipe " .. recipeID)
end

local function Money(copper)
	return ns.FormatNet(ns.Model.RoundMoney(math.abs(copper)), copper < 0)
end

-- A column of text lines, each with an optional right-aligned value.
local function CreateList(parent)
	local list = { lines = {}, count = 0 }
	function list:Add(text, color, value, valueColor)
		self.count = self.count + 1
		local line = self.lines[self.count]
		if not line then
			line = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			line:SetJustifyH("LEFT")
			line:SetWordWrap(false)
			line:SetPoint("TOPLEFT", 12, -12 - (self.count - 1) * LINE_HEIGHT)
			line.Value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			line.Value:SetPoint("TOP", line, "TOP")
			line.Value:SetPoint("RIGHT", parent, "RIGHT", -12, 0)
			self.lines[self.count] = line
		end
		line:SetPoint("RIGHT", parent, "RIGHT", value and -64 or -12, 0)
		line:SetText(text)
		line:SetTextColor((color or HIGHLIGHT_FONT_COLOR):GetRGB())
		line.Value:SetText(value or "")
		line.Value:SetTextColor((valueColor or HIGHLIGHT_FONT_COLOR):GetRGB())
		line:Show()
		line.Value:Show()
	end
	function list:Finish()
		for i = self.count + 1, #self.lines do
			self.lines[i]:Hide()
			self.lines[i].Value:Hide()
		end
		self.count = 0
	end
	return list
end

local function RenderRoute(list, profession, route)
	if profession.capped then
		list:Add(string.format("At the %d cap: train the next rank to continue.", profession.max), GRAY_FONT_COLOR)
		return
	end
	local training = {}
	for _, step in ipairs(route.training) do
		training[step.recipeID] = step
	end
	for i, segment in ipairs(route.segments) do
		if list.count >= MAX_LINES - 4 then
			list:Add(string.format("+%d more steps", #route.segments - i + 1), GRAY_FONT_COLOR)
			break
		end
		local step = training[segment.recipeID]
		if step then
			training[segment.recipeID] = nil
			list:Add("Train " .. RecipeName(step.recipeID), NORMAL_FONT_COLOR, Money(step.fee), NORMAL_FONT_COLOR)
		end
		list:Add(
			string.format(
				"%d× %s to %d",
				segment.crafts,
				RecipeName(segment.recipeID),
				segment.toSkill - profession.modifier
			),
			ns.COLORS[ns.Model.Color(ns.Model.Get(segment.recipeID), segment.fromSkill)],
			Money(ns.NetCost(segment.recipeID) * segment.expectedCrafts)
		)
	end
	if #route.segments > 0 then
		list:Add("Total", NORMAL_FONT_COLOR, Money(route.expectedCost + route.trainingCost), NORMAL_FONT_COLOR)
	end
	if #route.segments == 0 and route.excluded.unpriced > 0 then
		list:Add("Price reagents at a vendor or the AH.", GRAY_FONT_COLOR)
	elseif route.stopReason == "no_recipe" then
		local known = route.excluded.unpriced > 0 and "Nothing priced you know" or "Nothing you know"
		list:Add(
			string.format("%s skills up past %d.", known, route.reachedSkill - profession.modifier),
			RED_FONT_COLOR
		)
	end
	if #route.segments > 0 and route.excluded.unpriced > 0 then
		list:Add(
			string.format("%d recipes skipped: reagents not priced yet.", route.excluded.unpriced),
			GRAY_FONT_COLOR
		)
	end
end

local function RenderReagents(list, reagents)
	if #reagents == 0 then
		list:Add("Nothing to buy for this route.", GRAY_FONT_COLOR)
		return
	end
	for i, item in ipairs(reagents) do
		if i == MAX_LINES then
			list:Add(string.format("+%d more reagents", #reagents - i + 1), GRAY_FONT_COLOR)
			break
		end
		local text, have, color = ns.ReagentText(item)
		list:Add(text, nil, have, color)
	end
end

local function Render()
	local profession = selected and ns.PlayerProfessions()[selected]
	page.Profession:GenerateMenu()
	page.Skill:SetShown(profession ~= nil)
	page.Target:SetShown(profession ~= nil)
	page.Track:SetEnabled(profession ~= nil)
	page.Auctionator:Disable()
	if not profession then
		page.RouteList:Add("Learn a profession to plan a route.", GRAY_FONT_COLOR)
		page.RouteList:Finish()
		page.ReagentList:Finish()
		return
	end
	page.Skill:SetFormattedText("Skill  %d/%d     Target", profession.base, profession.max)
	local route = ns.PlanRoute(profession)
	if not page.Target:HasFocus() then
		page.Target:SetText(tostring(route.target))
	end
	local reagents = profession.capped and {} or ns.RouteReagents(route)
	RenderRoute(page.RouteList, profession, route)
	RenderReagents(page.ReagentList, reagents)
	page.RouteList:Finish()
	page.ReagentList:Finish()
	page.Track:SetText(ns.IsTracked(selected) and "Stop tracking" or "Track")
	page.Auctionator:SetEnabled(#reagents > 0)
end

-- Coalesces bursts of list/skill/price/bag updates into one plan.
function ns.RefreshRoute()
	if pending or not (page and page:IsShown()) then
		return
	end
	pending = true
	C_Timer.After(0.2, function()
		pending = false
		if page:IsShown() then
			Render()
		end
	end)
end

local function CommitTarget(editBox)
	local value = tonumber(editBox:GetText())
	if selected and value then
		ns.db.routeTargets[selected] = value
		ns.InvalidatePlans()
		ns.RefreshTracker()
	end
	ns.RefreshRoute()
end

local function CreateInset(name)
	local inset = CreateFrame("Frame", nil, page, "InsetFrameTemplate")
	local title = inset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("BOTTOMLEFT", inset, "TOPLEFT", 4, 4)
	title:SetText(name)
	return inset
end

local function CreateHeader()
	local dropdown = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
	dropdown:SetWidth(180)
	dropdown:SetPoint("TOPLEFT", 20, -32)
	dropdown:SetupMenu(function(_, root)
		for skillLine, profession in pairs(ns.PlayerProfessions()) do
			root:CreateRadio(profession.name, function()
				return skillLine == selected
			end, function()
				selected = skillLine
				Render()
			end)
		end
	end)
	page.Profession = dropdown

	local skill = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	skill:SetPoint("LEFT", dropdown, "RIGHT", 16, 0)
	page.Skill = skill

	local target = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
	target:SetSize(40, 20)
	target:SetPoint("LEFT", skill, "RIGHT", 10, 0)
	target:SetNumeric(true)
	target:SetMaxLetters(3)
	target:SetAutoFocus(false)
	target:SetScript("OnEnterPressed", target.ClearFocus)
	target:SetScript("OnEditFocusLost", CommitTarget)
	target:SetScript("OnEscapePressed", function(editBox)
		editBox:SetText("")
		editBox:ClearFocus()
	end)
	page.Target = target
end

local function CreateButtons()
	local track = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	track:SetSize(130, 22)
	track:SetScript("OnClick", function()
		ns.SetTracked(selected, not ns.IsTracked(selected))
		Render()
	end)
	page.Track = track

	-- Only auction house reagents still missing go to the Auctionator list.
	local auctionator = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	auctionator:SetSize(130, 22)
	auctionator:SetText("To Auctionator")
	auctionator:SetScript("OnClick", function()
		local profession = ns.PlayerProfessions()[selected]
		ns.SendToAuctionator(profession.name, ns.RouteReagents(ns.PlanRoute(profession)))
	end)
	auctionator:SetShown(ns.HasAuctionator())
	page.Auctionator = auctionator
end

-- Occupies the crafting page's place, as the overview page does.
local function CreatePage()
	page = CreateFrame("Frame", nil, ProfessionsFrame)
	page:SetAllPoints(ProfessionsFrame.CraftingPage)
	page:SetFrameLevel(ProfessionsFrame.CraftingPage:GetFrameLevel())
	page:Hide()
	CreateHeader()
	CreateButtons()

	local route = CreateInset("Route")
	route:SetPoint("TOPLEFT", 16, -88)
	route:SetPoint("BOTTOMRIGHT", page, "BOTTOM", -6, 44)
	page.RouteList = CreateList(route)

	local reagents = CreateInset("Reagents  (have / need)")
	reagents:SetPoint("TOPLEFT", page, "TOP", 6, -88)
	reagents:SetPoint("BOTTOMRIGHT", -16, 44)
	page.ReagentList = CreateList(reagents)

	page.Track:SetPoint("TOPRIGHT", reagents, "BOTTOMRIGHT", 0, -10)
	page.Auctionator:SetPoint("RIGHT", page.Track, "LEFT", -8, 0)
	page:SetScript("OnShow", Render)
end

-- The profession on show in the crafting page, when it is one of this character's.
local function OpenSkillLine()
	local info = Professions.GetProfessionInfo()
	local skillLine = info and (info.parentProfessionID or info.professionID)
	return skillLine and ns.PlayerProfessions()[skillLine] and skillLine
end

local function SelectPage()
	selected = OpenSkillLine() or selected or next(ns.PlayerProfessions())
	ProfessionsFrame.CraftingPage:Hide()
	ProfessionsFrame.BookPage:Hide()
	page:Show()
	ProfessionsFrame:RightTabSelected(tab)
end

-- Blizzard's own tabs show their page explicitly, which hands the window back.
local function Deselect()
	page:Hide()
	tab:SetChecked(false)
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

-- RightTabSelected knows only Blizzard's tabs, and RefreshRightTabs re-selects
-- the open profession's tab; while our page shows, ours is the checked one.
local function SyncChecks()
	local shown = page:IsShown()
	tab:SetChecked(shown)
	if shown then
		ProfessionsFrame.ProfessionsOverviewTab:SetChecked(false)
		for _, professionTab in ipairs(ProfessionsFrame.rightProfessionTabs or {}) do
			professionTab:SetChecked(false)
		end
	end
end

local function CreateTab()
	tab = CreateFrame("Frame", nil, ProfessionsFrame, "LargeSideTabButtonTemplate")
	tab.Icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
	tab:SetFillToInterior(true)
	tab.tooltipText = "Levelling route"
	tab:EnableMouse(true)
	tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
		if button == "LeftButton" and upInside then
			SelectPage()
		end
	end)
	PlaceTab()
	hooksecurefunc(ProfessionsFrame, "RefreshRightTabs", PlaceTab)
	hooksecurefunc(ProfessionsFrame, "RightTabSelected", SyncChecks)
end

function ns.AttachRoute()
	CreatePage()
	CreateTab()
	ProfessionsFrame.CraftingPage:HookScript("OnShow", Deselect)
	ProfessionsFrame.BookPage:HookScript("OnShow", Deselect)
	-- A reopened window starts on the crafting page, as Blizzard expects.
	ProfessionsFrame:HookScript("OnHide", function()
		if page:IsShown() then
			Deselect()
			ProfessionsFrame.CraftingPage:Show()
		end
	end)
	local events = CreateFrame("Frame")
	for _, event in ipairs({
		"TRADE_SKILL_LIST_UPDATE",
		"SKILL_LINES_CHANGED",
		"BAG_UPDATE_DELAYED",
		"ITEM_DATA_LOAD_RESULT",
	}) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", ns.RefreshRoute)
end
