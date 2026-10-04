---@type string, SkillUpNamespace
local _, ns = ...

-- The addon's lists draw what they hold the way the game draws its own items: a full-size icon in its
-- stock border, the item's name beside it in the item-name font and the supporting facts on the line
-- under it. A heading is a stock font line and a message is the list's own hint or empty state. The
-- list scrolls with Blizzard's own scroll box and minimal scroll bar, and keeps its frames between
-- renders.

local ICON_SIZE = 37
local ROW_HEIGHT = 46
local HEADING_HEIGHT = 26
local MESSAGE_MIN_HEIGHT = 20
-- Room kept on the right for the scroll bar, so the rows line up with or without it.
local SCROLL_BAR_WIDTH = 18

-- Item data that arrives after a hover makes the game rebuild the item's tooltip, which drops the lines a row
-- added under it. The tooltip asks its owner for a fresh one first (`owner:UpdateTooltip()`), so a hovered
-- row draws its own again once new data has come. Shift does the same: it changes what an item's tooltip
-- shows, and the redraw that follows is of the item alone. A read of where a vendor, quest or trainer is
-- arrives late the same way, so the sources change marks the tooltip stale too.
local staleTooltip = false
local function Stale()
	staleTooltip = true
end
ns.WhenEvent("TOOLTIP_DATA_UPDATE", Stale)
ns.WhenEvent("MODIFIER_STATE_CHANGED", Stale)
ns.WhenStale("tooltip", Stale)

---@param row SkillUpListRow
local function ShowTooltip(row)
	staleTooltip = false
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	row.tooltip(GameTooltip)
	GameTooltip:Show()
end

---@param row SkillUpListRow
local function OnEnter(row)
	if row.tooltip then
		ShowTooltip(row)
	end
end

-- Called by the tooltip this row owns, a few times a second.
---@param row SkillUpListRow
local function UpdateTooltip(row)
	if staleTooltip and row.tooltip then
		ShowTooltip(row)
	end
end

-- A list in the game's own scroll box: rows the game draws its items with, headings and messages. A
-- caller fills it between Begin and Finish; the list hides the frames a later render does not use.
---@param parent Frame
---@return SkillUpList
function ns.CreateList(parent)
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

	---@class SkillUpList
	local list = { rows = {}, height = 0, scrollBox = scrollBox }
	---@type table<"row"|"heading"|"message", Frame[]>
	local pools = { row = {}, heading = {}, message = {} }
	---@type table<"row"|"heading"|"message", integer>
	local used = { row = 0, heading = 0, message = 0 }

	---@return SkillUpListRow
	local function CreateRow()
		local row = CreateFrame("Button", nil, content) --[[@as SkillUpListRow]]
		row.kind = "row"
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
		row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		row.Text:SetJustifyH("LEFT")
		row.Text:SetPoint("TOPLEFT", row.Icon, "TOPRIGHT", 8, -2)
		row.Text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
		row.Detail = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		row.Detail:SetJustifyH("LEFT")
		row.Detail:SetPoint("TOPLEFT", row.Text, "BOTTOMLEFT", 0, -2)
		row.Detail:SetPoint("RIGHT", row, "RIGHT", -8, 0)
		return row
	end

	---@return SkillUpListHeading
	local function CreateHeading()
		local heading = CreateFrame("Frame", nil, content) --[[@as SkillUpListHeading]]
		heading.kind = "heading"
		heading.Text = heading:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		heading.Text:SetPoint("BOTTOMLEFT", heading, "BOTTOMLEFT", 6, 4)
		return heading
	end

	---@return SkillUpListMessage
	local function CreateMessage()
		local message = CreateFrame("Frame", nil, content) --[[@as SkillUpListMessage]]
		message.kind = "message"
		message.Text = message:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		message.Text:SetWordWrap(true)
		message.Text:SetJustifyH("LEFT")
		message.Text:SetPoint("TOPLEFT", message, "TOPLEFT", 6, -4)
		message.Text:SetPoint("RIGHT", message, "RIGHT", -6, 0)
		return message
	end

	---@param kind "row"|"heading"|"message"
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

	---@param self SkillUpList
	---@param frame SkillUpListFrame
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
		local heading = Take("heading", CreateHeading) --[[@as SkillUpListHeading]]
		heading.Text:SetText(text)
		heading.Text:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
		Place(self, heading, HEADING_HEIGHT)
	end

	---@param text string
	---@param color ColorMixin?
	function list:Message(text, color)
		local message = Take("message", CreateMessage) --[[@as SkillUpListMessage]]
		message.Text:SetText(text)
		message.Text:SetTextColor((color or GRAY_FONT_COLOR):GetRGB())
		local width = self.scrollBox:GetWidth() - 12
		if width > 0 then
			message.Text:SetWidth(width)
		end
		Place(self, message, math.max(MESSAGE_MIN_HEIGHT, message.Text:GetStringHeight() + 8))
	end

	---@param entry SkillUpListEntry
	function list:Add(entry)
		local row = Take("row", CreateRow) --[[@as SkillUpListRow]]
		row.entry = entry
		row.Icon:SetTexture(entry.icon)
		row.Icon:SetShown(entry.icon ~= nil)
		row.IconBorder:SetShown(entry.icon ~= nil)
		if entry.iconColor then
			row.IconBorder:SetVertexColor(entry.iconColor:GetRGB())
		else
			row.IconBorder:SetVertexColor(1, 1, 1)
		end
		row.Text:SetText(entry.text)
		row.Text:SetTextColor((entry.color or HIGHLIGHT_FONT_COLOR):GetRGB())
		row.Detail:SetText(entry.detail or "")
		row.Detail:SetShown(entry.detail ~= nil)
		row.Detail:SetTextColor((entry.detailColor or GRAY_FONT_COLOR):GetRGB())
		row.tooltip = entry.tooltip
		row.click = entry.click
		row:EnableMouse(entry.tooltip ~= nil or entry.click ~= nil)
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
