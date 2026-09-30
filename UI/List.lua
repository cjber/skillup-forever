---@type string, SkillUpNamespace
local _, ns = ...

-- Retail list proportions: GameFontHighlight rows with 16px icons.
local LINE_HEIGHT = 20
local HEADER_HEIGHT = 26
local ICON_SIZE = 16
local COLUMN_GAP = 8
-- Room kept on the right for the scroll bar, so columns line up with or without it.
local SCROLL_BAR_WIDTH = 18

---@param parent Frame
---@return SkillUpScrollBox scrollBox
---@return SkillUpScrollContent content
local function CreateScrollArea(parent)
	local scrollBox = CreateFrame("Frame", nil, parent, "WowScrollBox") --[[@as SkillUpScrollBox]]
	scrollBox:SetPoint("TOPLEFT", 4, -HEADER_HEIGHT)
	scrollBox:SetPoint("BOTTOMRIGHT", -SCROLL_BAR_WIDTH, 4)
	local scrollBar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar") --[[@as SkillUpScrollBar]]
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)
	scrollBar:SetHideIfUnscrollable(true)
	-- Created before Init, which moves `scrollable` children into the scroll target;
	-- the view stretches it to the box's width.
	local content = CreateFrame("Frame", nil, scrollBox) --[[@as SkillUpScrollContent]]
	content.scrollable = true
	content:SetSize(1, 1)
	local view = CreateScrollBoxLinearView()
	view:SetPanExtent(LINE_HEIGHT)
	ScrollUtil.InitScrollBoxWithScrollBar(scrollBox, scrollBar, view)
	return scrollBox, content
end

-- Headers sit on the inset, rows in the content: both measure from the same edge.
-- Records each column's right offset for its row values.
---@param parent Frame
---@param columns SkillUpColumn[]
---@return number textRight where the name text must stop short of the columns
local function LayoutHeaders(parent, columns)
	local right = -4
	for _, column in ipairs(columns) do
		local header = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		header:SetPoint("TOPRIGHT", right - SCROLL_BAR_WIDTH, -8)
		header:SetWidth(column.width)
		header:SetJustifyH(column.justify or "RIGHT")
		header:SetText(column.title)
		column.right = right
		right = right - column.width - COLUMN_GAP
	end
	return right
end

-- A table: icon and name, then right-aligned value columns (listed right to left)
-- under fixed headers, scrolling with Blizzard's ScrollBox and minimal scroll bar
-- once it outgrows the inset. Each row can show a tooltip and act on a click.
---@param parent Frame
---@param columns SkillUpColumn[]
---@return SkillUpList
function ns.CreateList(parent, columns)
	---@class SkillUpList
	local list = { rows = {}, count = 0, height = 0 }
	local scrollBox, content = CreateScrollArea(parent)
	list.scrollBox = scrollBox
	local textRight = LayoutHeaders(parent, columns)

	---@param row SkillUpListRow
	local function OnEnter(row)
		if row.entry.tooltip then
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			row.entry.tooltip(GameTooltip)
			GameTooltip:Show()
		end
	end

	---@param row SkillUpListRow
	local function OnClick(row)
		if row.entry.click then
			row.entry.click()
		end
	end

	local function CreateRow()
		local row = CreateFrame("Button", nil, content) --[[@as SkillUpListRow]]
		row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		row:SetScript("OnEnter", OnEnter)
		row:SetScript("OnLeave", GameTooltip_Hide)
		row:SetScript("OnClick", OnClick)
		row.Icon = row:CreateTexture(nil, "ARTWORK")
		row.Icon:SetSize(ICON_SIZE, ICON_SIZE)
		row.Icon:SetPoint("LEFT", 6, 0)
		row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		row.Text:SetJustifyH("LEFT")
		row.Values = {}
		for i, column in ipairs(columns) do
			local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			value:SetPoint("RIGHT", column.right, 0)
			value:SetWidth(column.width)
			value:SetJustifyH(column.justify or "RIGHT")
			value:SetWordWrap(false)
			row.Values[i] = value
		end
		return row
	end

	---@param entry SkillUpListEntry
	function list:Add(entry)
		self.count = self.count + 1
		local row = self.rows[self.count] or CreateRow()
		self.rows[self.count] = row
		row.entry = entry
		row.Icon:SetTexture(entry.icon)
		row.Icon:SetShown(entry.icon ~= nil)
		row.Text:ClearAllPoints()
		row.Text:SetPoint("LEFT", entry.icon and ICON_SIZE + 12 or 6, 0)
		row.Text:SetWordWrap(entry.wrap == true)
		row.Text:SetText(entry.text)
		-- A wrapped message gets an explicit width, so its height is known now: as
		-- many lines as it needs. Anything else is one line cut at the columns.
		local height = LINE_HEIGHT
		local width = scrollBox:GetWidth() - 10
		if entry.wrap and width > 0 then
			row.Text:SetWidth(width)
			height = math.max(LINE_HEIGHT, row.Text:GetStringHeight() + 6)
		else
			row.Text:SetWidth(0)
			row.Text:SetPoint("RIGHT", entry.values and textRight or -4, 0)
		end
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, -self.height)
		row:SetPoint("RIGHT")
		row:SetHeight(height)
		self.height = self.height + height
		row.Text:SetTextColor((entry.color or HIGHLIGHT_FONT_COLOR):GetRGB())
		for i, value in ipairs(row.Values) do
			value:SetText(entry.values and entry.values[i] or "")
			value:SetTextColor((entry.valueColor or HIGHLIGHT_FONT_COLOR):GetRGB())
		end
		row:EnableMouse(entry.tooltip ~= nil or entry.click ~= nil)
		row:Show()
	end

	---@param text string
	---@param color ColorMixin?
	function list:Message(text, color)
		self:Add({ text = text, color = color or GRAY_FONT_COLOR, wrap = true })
	end

	function list:Finish()
		for i = self.count + 1, #self.rows do
			self.rows[i]:Hide()
		end
		content:SetHeight(math.max(self.height, 1))
		scrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
		self.count, self.height = 0, 0
	end
	return list
end
