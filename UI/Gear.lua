---@type string, SkillUpNamespace
local _, ns = ...
local L = ns.L

-- The crafted gear page: one side tab on the Professions window listing, per equipment slot, the
-- newest items this character can equip. The listing rule is Core/Gear.lua's; this draws it as the
-- game draws its own items: a full icon with its stock quality border, the item's name beside it and
-- its profession, skill and state on the line under it.

---@type SkillUpGearPage
local page
---@type SkillUpSideTab
local tab

local ICON_SIZE = 37
local ROW_HEIGHT = 46
local HEADING_HEIGHT = 26
local SCROLL_BAR_WIDTH = 18

---@param itemID integer
---@return ColorMixin?
local function QualityColor(itemID)
	local quality = C_Item.GetItemQualityByID(itemID)
	if not quality then
		return nil
	end
	local red, green, blue = C_Item.GetItemQualityColor(quality)
	return CreateColor(red, green, blue)
end

-- What the character can do with the recipe: knows it, could learn it now, has to reach the
-- skill, or needs another crafter.
---@param item SkillUpGearItem
---@return string
local function Status(item)
	if item.state == "known" then
		return L["You know it"]
	elseif item.state == "trainable" then
		return L["Can learn it"]
	elseif item.state == "needs" then
		return string.format(L["Needs %s %d"], item.profession, item.skill)
	end
	return L["Another crafter"]
end

-- The line under the item's name: its profession and the skill its recipe is learned at, then what
-- the character can do with it. A recipe short of its skill already names both in the status.
---@param item SkillUpGearItem
---@return string
local function Detail(item)
	if item.state == "needs" then
		return string.format(L["Needs %s %d"], item.profession, item.skill)
	end
	return string.format(L["%s, %d. %s"], item.profession, item.skill, Status(item))
end

-- Where a trainable recipe is learned, else nil: the trainer or the scroll's source, read the way
-- the route page reads them.
---@param item SkillUpGearItem
---@param profession SkillUpProfession?
---@return integer?
local function RecipeNPC(item, profession)
	return profession and ns.RecipeNPC(profession, item.recipeID) or nil
end

---@param item SkillUpGearItem
---@param profession SkillUpProfession?
---@return fun(tooltip: GameTooltip)
local function ItemTooltip(item, profession)
	return function(tooltip)
		tooltip:SetItemByID(item.itemID)
		GameTooltip_AddBlankLineToTooltip(tooltip)
		if item.state ~= "needs" then
			GameTooltip_AddNormalLine(tooltip, string.format(L["%s, %d"], item.profession, item.skill))
		end
		GameTooltip_AddNormalLine(tooltip, Status(item))
		if item.state == "known" then
			GameTooltip_AddInstructionLine(tooltip, L["Click to open the recipe."])
		elseif item.state == "trainable" and profession then
			if ns.TrainingFor(profession, item.recipeID) then
				ns.AddNearest(tooltip, L["Nearest trainer"], RecipeNPC(item, profession))
			else
				local source = ns.Catalogue.Recipe(item.recipeID)
				if source then
					ns.AddSourceLines(tooltip, source)
				end
				local npcID = RecipeNPC(item, profession)
				if npcID then
					ns.AddNearest(tooltip, L["Source"], npcID)
				end
			end
		end
	end
end

-- A known recipe opens on the crafting page; a trainable one sets a waypoint to where it is
-- learned. A row the character cannot make yet does nothing.
---@param item SkillUpGearItem
---@param profession SkillUpProfession?
---@return fun()?
local function ItemClick(item, profession)
	if item.state == "known" then
		return function()
			C_TradeSkillUI.OpenRecipe(item.recipeID)
		end
	end
	if item.state == "trainable" and profession then
		return function()
			local npcID = RecipeNPC(item, profession)
			if npcID then
				ns.SetWaypoint(npcID)
			end
		end
	end
end

-- Item data that arrives after a hover makes the game rebuild the item's tooltip, which drops the
-- lines a row added under it. The tooltip asks its owner for a fresh one first, so a hovered row
-- draws its own again once new data has come.
local staleTooltip = false
local function Stale()
	staleTooltip = true
end
ns.WhenEvent("TOOLTIP_DATA_UPDATE", Stale)
ns.WhenEvent("MODIFIER_STATE_CHANGED", Stale)
ns.WhenStale("tooltip", Stale)

---@param row SkillUpGearRow
local function ShowTooltip(row)
	staleTooltip = false
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	row.tooltip(GameTooltip)
	GameTooltip:Show()
end

---@param row SkillUpGearRow
local function OnEnter(row)
	if row.tooltip then
		ShowTooltip(row)
	end
end

-- Called by the tooltip this row owns, a few times a second.
---@param row SkillUpGearRow
local function UpdateTooltip(row)
	if staleTooltip and row.tooltip then
		ShowTooltip(row)
	end
end

---@param row SkillUpGearRow
---@param item SkillUpGearItem
---@param profession SkillUpProfession?
local function FillItem(row, item, profession)
	row.kind = "item"
	row.item = item
	row.Icon:SetTexture(C_Item.GetItemIconByID(item.itemID))
	local color = QualityColor(item.itemID)
	if color then
		row.IconBorder:SetVertexColor(color:GetRGB())
		row.IconBorder:Show()
		row.Name:SetTextColor(color:GetRGB())
	else
		row.IconBorder:Hide()
		row.Name:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
	end
	local name = item.name
	if not name then
		-- ITEM_DATA_LOAD_RESULT redraws once the name arrives.
		C_Item.RequestLoadItemDataByID(item.itemID)
		name = string.format(L["item %d"], item.itemID)
	end
	row.Name:SetText(name)
	row.Detail:SetText(Detail(item))
	row.Detail:SetTextColor((item.state == "known" and ns.COLORS.green or GRAY_FONT_COLOR):GetRGB())
	row.tooltip = ItemTooltip(item, profession)
	row.click = ItemClick(item, profession)
end

-- The rows, in the game's own scroll box: an item icon and name, then the profession, skill and
-- state. A slot heading is a stock font line; a message is the page's own hint or empty state.
-- The list keeps its rows between renders and hides the ones a later render does not use.
---@param parent Frame
---@return SkillUpGearList
local function CreateList(parent)
	local scrollBox = CreateFrame("Frame", nil, parent, "WowScrollBox") --[[@as SkillUpScrollBox]]
	scrollBox:SetPoint("TOPLEFT", 4, -4)
	scrollBox:SetPoint("BOTTOMRIGHT", -SCROLL_BAR_WIDTH, 4)
	local scrollBar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar") --[[@as SkillUpScrollBar]]
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)
	scrollBar:SetHideIfUnscrollable(true)
	local content = CreateFrame("Frame", nil, scrollBox) --[[@as SkillUpScrollContent]]
	content.scrollable = true
	content:SetSize(1, 1)
	local view = CreateScrollBoxLinearView()
	view:SetPanExtent(ROW_HEIGHT)
	ScrollUtil.InitScrollBoxWithScrollBar(scrollBox, scrollBar, view)

	---@class SkillUpGearList
	local list = { rows = {}, height = 0, scrollBox = scrollBox }
	---@type table<"item"|"heading"|"message", Frame[]>
	local pools = { item = {}, heading = {}, message = {} }
	---@type table<"item"|"heading"|"message", integer>
	local used = { item = 0, heading = 0, message = 0 }

	---@return SkillUpGearRow
	local function CreateItem()
		local row = CreateFrame("Button", nil, content) --[[@as SkillUpGearRow]]
		row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		row.UpdateTooltip = UpdateTooltip
		row:SetScript("OnEnter", OnEnter)
		row:SetScript("OnLeave", GameTooltip_Hide)
		row:SetScript("OnClick", function()
			if row.click then
				row.click()
			end
		end)
		row.Icon = row:CreateTexture(nil, "ARTWORK")
		row.Icon:SetSize(ICON_SIZE, ICON_SIZE)
		row.Icon:SetPoint("LEFT", 6, 0)
		row.IconBorder = row:CreateTexture(nil, "OVERLAY")
		row.IconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
		row.IconBorder:SetSize(ICON_SIZE, ICON_SIZE)
		row.IconBorder:SetPoint("LEFT", row.Icon, "LEFT", 0, 0)
		row.Name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		row.Name:SetJustifyH("LEFT")
		row.Name:SetPoint("TOPLEFT", row.Icon, "TOPRIGHT", 8, -2)
		row.Name:SetPoint("RIGHT", row, "RIGHT", -8, 0)
		row.Detail = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		row.Detail:SetJustifyH("LEFT")
		row.Detail:SetPoint("TOPLEFT", row.Name, "BOTTOMLEFT", 0, -2)
		row.Detail:SetPoint("RIGHT", row, "RIGHT", -8, 0)
		return row
	end

	---@return SkillUpGearHeading
	local function CreateHeading()
		local heading = CreateFrame("Frame", nil, content) --[[@as SkillUpGearHeading]]
		heading.kind = "heading"
		heading.Text = heading:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		heading.Text:SetPoint("BOTTOMLEFT", heading, "BOTTOMLEFT", 6, 4)
		return heading
	end

	---@return SkillUpGearMessage
	local function CreateMessage()
		local message = CreateFrame("Frame", nil, content) --[[@as SkillUpGearMessage]]
		message.kind = "message"
		message.Text = message:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		message.Text:SetWordWrap(true)
		message.Text:SetJustifyH("LEFT")
		message.Text:SetPoint("TOPLEFT", message, "TOPLEFT", 6, -4)
		message.Text:SetPoint("RIGHT", message, "RIGHT", -6, 0)
		return message
	end

	---@param kind "item"|"heading"|"message"
	---@param create fun(): Frame
	---@return Frame
	local function Take(kind, create)
		used[kind] = used[kind] + 1
		local frame = pools[kind][used[kind]]
		if not frame then
			frame = create()
			pools[kind][used[kind]] = frame
		end
		return frame
	end

	---@param self SkillUpGearList
	---@param frame SkillUpGearListRow
	---@param height number
	local function Place(self, frame, height)
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", 0, -self.height)
		frame:SetPoint("RIGHT")
		frame:SetHeight(height)
		self.height = self.height + height
		self.rows[#self.rows + 1] = frame
		frame:Show()
	end

	function list:Begin()
		self.rows, self.height = {}, 0
	end

	---@param text string
	function list:Heading(text)
		local heading = Take("heading", CreateHeading) --[[@as SkillUpGearHeading]]
		heading.Text:SetText(text)
		heading.Text:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
		Place(self, heading, HEADING_HEIGHT)
	end

	---@param text string
	---@param color ColorMixin?
	function list:Message(text, color)
		local message = Take("message", CreateMessage) --[[@as SkillUpGearMessage]]
		message.Text:SetText(text)
		message.Text:SetTextColor((color or GRAY_FONT_COLOR):GetRGB())
		local width = self.scrollBox:GetWidth() - 12
		if width > 0 then
			message.Text:SetWidth(width)
		end
		Place(self, message, math.max(20, message.Text:GetStringHeight() + 8))
	end

	---@param item SkillUpGearItem
	---@param profession SkillUpProfession?
	function list:Item(item, profession)
		local row = Take("item", CreateItem) --[[@as SkillUpGearRow]]
		FillItem(row, item, profession)
		Place(self, row, ROW_HEIGHT)
	end

	function list:Finish()
		for kind, pool in pairs(pools) do
			for index = used[kind] + 1, #pool do
				pool[index]:Hide()
			end
			used[kind] = 0
		end
		content:SetHeight(math.max(self.height, 1))
		scrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
	end
	return list
end

local function Render()
	local _, _, classID = UnitClass("player")
	local professions = ns.PlayerProfessions()
	local slots = ns.CraftedGear(UnitLevel("player"), classID)
	page.ShowAll:SetChecked(ns.ShowAllGear())
	local list = page.List
	list:Begin()
	if #slots == 0 then
		list:Message(
			ns.ShowAllGear() and L["No crafted gear for your level and class yet."]
				or L["No crafted gear you can make yet. Tick the box below to see gear you cannot make."]
		)
		list:Finish()
		return
	end
	list:Message(L["The newest item you can craft and wear in each slot, not a best-in-slot list."])
	for _, slot in ipairs(slots) do
		list:Heading(slot.name)
		for _, item in ipairs(slot.items) do
			list:Item(item, professions[item.skillLine])
		end
	end
	list:Finish()
end

local SyncChecks

local function SelectPage()
	ns.HideRoute()
	ProfessionsFrame.CraftingPage:Hide()
	ProfessionsFrame.BookPage:Hide()
	page:Show()
	ProfessionsFrame:RightTabSelected(tab)
	-- RightTabSelected checks Blizzard's tabs only, and a second click does not fire OnShow.
	SyncChecks()
end

-- Blizzard's own tabs show their page explicitly, which hands the window back.
local function Deselect()
	page:Hide()
	tab:SetChecked(false)
end
ns.HideGear = Deselect

-- Blizzard reselects its profession tab on skill updates; keep ours checked while our page shows.
function SyncChecks()
	local shown = page:IsShown()
	tab:SetChecked(shown)
	if shown then
		ProfessionsFrame.ProfessionsOverviewTab:SetChecked(false)
		for _, professionTab in ipairs(ProfessionsFrame.rightProfessionTabs or {}) do
			professionTab:SetChecked(false)
		end
		if ns.RouteTab then
			ns.RouteTab:SetChecked(false)
		end
	end
end

-- Directly under the route tab, or under the last profession tab when that is off.
local function PlaceTab()
	local above = ProfessionsFrame.ProfessionsOverviewTab
	if ns.RouteTab and ns.RouteTab:IsShown() then
		above = ns.RouteTab
	else
		for _, professionTab in ipairs(ProfessionsFrame.rightProfessionTabs or {}) do
			if professionTab:IsShown() then
				above = professionTab
			end
		end
	end
	tab:ClearAllPoints()
	tab:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -2)
end

-- The tab can be turned off in settings; an open page goes back to crafting.
local function RefreshTab()
	tab:SetShown(ns.db.showGearTab)
	PlaceTab()
	if not ns.db.showGearTab and page:IsShown() then
		Deselect()
		ProfessionsFrame.CraftingPage:Show()
	end
end

local function Refresh()
	RefreshTab()
	if page:IsShown() then
		Render()
	end
end

-- Shows the rows a character cannot make yet; off, the list holds what it can make now.
---@return CheckButton
local function CreateShowAll()
	local showAll = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate") --[[@as CheckButton]]
	showAll:SetScript("OnClick", function(self)
		ns.SetShowAllGear(self:GetChecked())
		Render()
	end)
	local label = showAll:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("LEFT", showAll, "RIGHT", 4, 0)
	label:SetText(L["Show gear I cannot make yet"])
	page.ShowAllLabel = label
	return showAll
end

local function CreatePage()
	page = CreateFrame("Frame", nil, ProfessionsFrame) --[[@as SkillUpGearPage]]
	page:SetAllPoints(ProfessionsFrame.CraftingPage)
	page:SetFrameLevel(ProfessionsFrame.CraftingPage:GetFrameLevel())
	page:Hide()
	-- The inset's own heading is the page title, so it sits under the window's title bar and portrait.
	local inset = CreateFrame("Frame", nil, page, "InsetFrameTemplate") --[[@as Frame]]
	local title = inset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("BOTTOMLEFT", inset, "TOPLEFT", 4, 4)
	title:SetText(L["Crafted gear"])
	inset:SetPoint("TOPLEFT", 16, -88)
	inset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -16, 44)
	page.List = CreateList(inset)
	page.ShowAll = CreateShowAll()
	page.ShowAll:SetPoint("TOPLEFT", inset, "BOTTOMLEFT", 2, -10)
	page:SetScript("OnShow", Render)
end

local function CreateTab()
	tab = CreateFrame("Frame", nil, ProfessionsFrame, "LargeSideTabButtonTemplate") --[[@as SkillUpSideTab]]
	tab.Icon:SetTexture("Interface\\Icons\\INV_Chest_Chain_05")
	tab:SetFillToInterior(true)
	tab.tooltipText = L["Crafted gear"]
	tab:EnableMouse(true)
	tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
		if button == "LeftButton" and upInside then
			SelectPage()
		end
	end)
	PlaceTab()
	RefreshTab()
	ns.GearTab = tab
	ns.PlaceGearTab = PlaceTab
	ProfessionsFrame:HookScript("OnShow", PlaceTab)
	page:HookScript("OnShow", SyncChecks)
end

function ns.AttachGear()
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
	ns.WhenStale("gear", Refresh)
end
