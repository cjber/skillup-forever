---@type string, SkillUpNamespace
local _, ns = ...

if ns.broken then
	return
end

-- The addon's lists draw what they hold the way the game draws its own items: a full-size icon in its
-- stock border, the item's name beside it in the item-name font and the supporting facts on the line
-- under it. A heading is a stock font line and a message is the list's own hint or empty state. The list
-- is the game's scroll box list, which pools the rows and keeps only the ones on screen, laid out by the
-- templates in UI/Shopping.xml.

local ICON_SIZE = 37
local ROW_HEIGHT = 46
-- A row with a have/need bar gives the bar its own line under the name.
local ROW_BAR_HEIGHT = 70
local BAR_HEIGHT = 29
local BAR_FILL_HEIGHT = 15
-- The client's own ColoredProgressBarTemplate draws these bar atlases: the frame has a rim, so the fill runs this
-- far inside it at each end, and a frame-sized mask gives the fill's ends the track's shape.
local BAR_INSET = 6
local SOURCE_SIZE = 16
local LINE_HEIGHT = 24
local LINE_ICON = 18
local BAND_HEIGHT = 30
local BAND_BAR_WIDTH = 170
local BAND_BAR_HEIGHT = 29
local HEADING_HEIGHT = 26
local MESSAGE_MIN_HEIGHT = 20
-- Room kept on the right for the scroll bar, so the rows line up with or without it.
local SCROLL_BAR_WIDTH = 18
-- Padding inside a message frame, left and right, so the text wraps where the frame does.
local MESSAGE_PADDING = 12

local ROW_TEMPLATE = "SkillUpForeverListRowTemplate"
local HEADING_TEMPLATE = "SkillUpForeverListHeadingTemplate"
local MESSAGE_TEMPLATE = "SkillUpForeverListMessageTemplate"
local BAND_TEMPLATE = "SkillUpForeverListBandTemplate"
local LINE_TEMPLATE = "SkillUpForeverListLineTemplate"

local L = ns.L

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

-- The parts a frame draws once, whichever element it later holds. The view pools the frames, so the
-- initializers draw a frame's parts only the first time they see it; a pooled frame is redrawn from the
-- element it is given. A weak key lets a released frame be collected.
local built = setmetatable({}, { __mode = "k" })

-- The hover, menu and click every list frame shares: its tooltip on hover, a right-click's menu when it has
-- one, and the frame's own click on any other button.
---@param frame SkillUpListRow|SkillUpListLine
local function Wire(frame)
	-- art-ok: the quest log's highlight bar, stretched over the row as a bar is
	frame:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	frame.UpdateTooltip = UpdateTooltip
	frame:SetScript("OnEnter", OnEnter)
	frame:SetScript("OnLeave", GameTooltip_Hide)
	frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	frame:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			if frame.menu then
				GameTooltip_Hide()
				ForeverCore.ContextMenu(frame, frame.menu)
			end
		elseif frame.click then
			frame.click(frame)
		end
	end)
end

---@param owner Frame
---@param fill Texture
---@param frame Texture the bar's common-stat-bar-BG frame
---@return MaskTexture
local function MaskBarFill(owner, fill, frame)
	local mask = owner:CreateMaskTexture()
	-- art-ok: the native bar mask stretches with the bar's frame, as the client's template draws it.
	mask:SetAtlas("common-stat-bar-Mask")
	mask:SetAllPoints(frame)
	fill:AddMaskTexture(mask)
	return mask
end

-- The parts a row draws once, whatever entry it later holds.
---@param row SkillUpListRow
local function BuildRow(row)
	row.kind = "row"
	Wire(row)
	-- The row that is the next thing to do keeps a gold highlight of its own, so the name can stay in the
	-- recipe's difficulty colour (#574).
	row.Current = row:CreateTexture(nil, "BACKGROUND")
	row.Current:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight") -- art-ok: a highlight bar over the whole row
	row.Current:SetVertexColor(NORMAL_FONT_COLOR:GetRGB())
	row.Current:SetAlpha(0.55)
	row.Current:SetAllPoints(row)
	row.Current:Hide()
	row.Icon = row:CreateTexture(nil, "ARTWORK")
	row.Icon:SetSize(ICON_SIZE, ICON_SIZE)
	row.Icon:SetPoint("LEFT", 6, 0)
	row.IconBorder = row:CreateTexture(nil, "OVERLAY")
	row.IconBorder:SetTexture("Interface\\Common\\WhiteIconFrame") -- art-ok: a square border in the ICON_SIZE square
	row.IconBorder:SetSize(ICON_SIZE, ICON_SIZE)
	row.IconBorder:SetPoint("LEFT", row.Icon, "LEFT", 0, 0)
	row.Source = row:CreateTexture(nil, "OVERLAY")
	row.Source:SetSize(SOURCE_SIZE, SOURCE_SIZE)
	row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.Text:SetJustifyH("LEFT")
	row.Text:SetPoint("TOPLEFT", row.Icon, "TOPRIGHT", 8, -2)
	row.Text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	row.Detail = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.Detail:SetJustifyH("LEFT")
	row.Detail:SetPoint("TOPLEFT", row.Text, "BOTTOMLEFT", 0, -2)
	row.Detail:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	row.BarBg = row:CreateTexture(nil, "BACKGROUND")
	-- art-ok: native progress-bar background stretches across the reagent row.
	row.BarBg:SetAtlas("common-stat-bar-BG")
	row.Bar = CreateFrame("StatusBar", nil, row) --[[@as StatusBar]]
	local fill = row.Bar:CreateTexture(nil, "ARTWORK")
	-- art-ok: native progress fill stretches to represent a quantity.
	fill:SetAtlas("common-stat-bar-white")
	row.Bar:SetStatusBarTexture(fill)
	row.BarMask = MaskBarFill(row.Bar, fill, row.BarBg)
	row.BarText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.BarText:SetPoint("CENTER", row.Bar, "CENTER", 0, 0)
	row.BarBg:Hide()
	row.Bar:Hide()
	row.BarText:Hide()
	row.Source:Hide()
end

---@param row SkillUpListRow
---@param elementData SkillUpListElement
local function InitializeRow(row, elementData)
	if not built[row] then
		built[row] = true
		BuildRow(row)
	end
	local entry = elementData.entry --[[@as SkillUpListEntry]]
	row.entry = entry
	row.Icon:ClearAllPoints()
	if entry.bar then
		row.Icon:SetPoint("TOPLEFT", row, "TOPLEFT", 6, 0)
	else
		row.Icon:SetPoint("LEFT", 6, 0)
	end
	-- art-ok: a square file icon in the ICON_SIZE square; the texture never draws an atlas
	row.Icon:SetTexture(entry.icon)
	row.Icon:SetShown(entry.icon ~= nil)
	row.IconBorder:SetShown(entry.icon ~= nil)
	if entry.iconColor then
		row.IconBorder:SetVertexColor(entry.iconColor:GetRGB())
	else
		row.IconBorder:SetVertexColor(1, 1, 1)
	end
	row.Text:ClearAllPoints()
	row.Text:SetPoint("TOPLEFT", row.Icon, "TOPRIGHT", 8, -2)
	row.Text:SetPoint("RIGHT", row, "RIGHT", entry.sourceIcon and -(SOURCE_SIZE + 12) or -8, 0)
	row.Text:SetText(entry.text)
	row.Text:SetTextColor((entry.color or HIGHLIGHT_FONT_COLOR):GetRGB())
	row.Current:SetShown(entry.current == true)
	if entry.sourceIcon then
		row.Source:Show()
		row.Source:ClearAllPoints()
		row.Source:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -2)
		ns.Art.Fit(row.Source, entry.sourceIcon, SOURCE_SIZE, SOURCE_SIZE)
	else
		row.Source:Hide()
	end
	row.Detail:ClearAllPoints()
	if entry.bar then
		row.BarBg:Show()
		row.Bar:Show()
		row.BarText:Show()
		row.BarBg:ClearAllPoints()
		row.BarBg:SetPoint("TOPLEFT", row.Text, "BOTTOMLEFT", 0, -3)
		row.BarBg:SetPoint("RIGHT", row, "RIGHT", -8, 0)
		row.BarBg:SetHeight(BAR_HEIGHT)
		row.Bar:ClearAllPoints()
		row.Bar:SetPoint("LEFT", row.BarBg, "LEFT", BAR_INSET, 0)
		row.Bar:SetPoint("RIGHT", row.BarBg, "RIGHT", -BAR_INSET, 0)
		row.Bar:SetHeight(BAR_FILL_HEIGHT)
		local need = math.max(entry.bar.need or 0, 0)
		local have = math.min(entry.bar.have or 0, need)
		row.Bar:SetMinMaxValues(0, math.max(need, 1))
		row.Bar:SetValue(have)
		row.Bar:SetStatusBarColor((entry.barColor or HIGHLIGHT_FONT_COLOR):GetRGB())
		row.BarText:SetFormattedText("%d/%d", have, need)
		row.barHave, row.barNeed = have, need
		row.Detail:SetPoint("TOPLEFT", row.BarBg, "BOTTOMLEFT", 0, -3)
		row.Detail:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	else
		row.BarBg:Hide()
		row.Bar:Hide()
		row.BarText:Hide()
		row.barHave, row.barNeed = nil, nil
		row.Detail:SetPoint("TOPLEFT", row.Text, "BOTTOMLEFT", 0, -2)
		row.Detail:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	end
	row.Detail:SetText(entry.detail or "")
	row.Detail:SetShown(entry.detail ~= nil)
	row.Detail:SetTextColor((entry.detailColor or GRAY_FONT_COLOR):GetRGB())
	row.tooltip = entry.tooltip
	row.click = entry.click
	row.menu = entry.menu
	row.current = entry.current
	row:EnableMouse(entry.tooltip ~= nil or entry.click ~= nil or entry.menu ~= nil)
end

---@param heading SkillUpListHeading
---@param elementData SkillUpListElement
local function InitializeHeading(heading, elementData)
	if not built[heading] then
		built[heading] = true
		heading.kind = "heading"
		heading.Text = heading:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		heading.Text:SetPoint("BOTTOMLEFT", heading, "BOTTOMLEFT", 6, 4)
	end
	heading.Text:SetText(elementData.text)
	heading.Text:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
end

---@param message SkillUpListMessage
---@param elementData SkillUpListElement
local function InitializeMessage(message, elementData)
	if not built[message] then
		built[message] = true
		message.kind = "message"
		message.Text = message:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		message.Text:SetWordWrap(true)
		message.Text:SetJustifyH("LEFT")
		message.Text:SetPoint("TOPLEFT", message, "TOPLEFT", 6, -4)
		message.Text:SetPoint("RIGHT", message, "RIGHT", -6, 0)
	end
	message.Text:SetText(elementData.text)
	message.Text:SetTextColor((elementData.color or GRAY_FONT_COLOR):GetRGB())
end

-- A skill band's slim header: its rank and range, with the route's progress through it in the client's own
-- bar art, so the page reads as the bands it is walked in.
---@param band SkillUpListBand
local function BuildBand(band)
	band.kind = "band"
	band.Name = band:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	band.Name:SetPoint("LEFT", 6, 0)
	band.Range = band:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	band.Range:SetPoint("LEFT", band.Name, "RIGHT", 6, 0)
	band.BarBg = band:CreateTexture(nil, "BACKGROUND")
	-- art-ok: native progress-bar background stretches across the skill band.
	band.BarBg:SetAtlas("common-stat-bar-BG")
	band.BarFill = band:CreateTexture(nil, "ARTWORK")
	-- art-ok: native progress fill stretches to represent skill completion.
	band.BarFill:SetAtlas("common-stat-bar-white")
	band.BarFill:SetVertexColor(ns.COLORS.green:GetRGB())
	band.BarMask = MaskBarFill(band, band.BarFill, band.BarBg)
	band.BarWidth, band.BarHeight = BAND_BAR_WIDTH, BAND_BAR_HEIGHT
	band.BarText = band:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	band.BarText:SetPoint("CENTER", band.BarBg, "CENTER", 0, 0)
end

---@param band SkillUpListBand
---@param elementData SkillUpListElement
local function InitializeBand(band, elementData)
	if not built[band] then
		built[band] = true
		BuildBand(band)
	end
	band.Name:SetText(elementData.name)
	band.Range:SetFormattedText(L["%d to %d"], elementData.from, elementData.cap)
	band.BarBg:ClearAllPoints()
	band.BarBg:SetPoint("RIGHT", band, "RIGHT", -6, 0)
	band.BarBg:SetSize(band.BarWidth, band.BarHeight)
	local span = math.max(elementData.cap - elementData.from, 0)
	local done = math.max(0, math.min(elementData.skill or 0, elementData.cap) - elementData.from)
	local filled = span > 0 and (band.BarWidth - 2 * BAR_INSET) * math.min(done / span, 1) or 0
	band.BarFill:ClearAllPoints()
	band.BarFill:SetPoint("LEFT", band.BarBg, "LEFT", BAR_INSET, 0)
	band.BarFill:SetSize(filled, BAR_FILL_HEIGHT)
	band.BarText:SetFormattedText("%d/%d", done, span)
end

-- A train or buy step: one gold line with its small icon, the price on the right and its tooltip below.
---@param line SkillUpListLine
local function BuildLine(line)
	line.kind = "line"
	Wire(line)
	line.Icon = line:CreateTexture(nil, "ARTWORK")
	line.Icon:SetPoint("LEFT", 8, 0)
	line.Text = line:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	line.Text:SetJustifyH("LEFT")
	line.Text:SetPoint("LEFT", line.Icon, "RIGHT", 8, 0)
	line.Text:SetPoint("RIGHT", line, "RIGHT", -8, 0)
	line.Detail = line:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	line.Detail:SetJustifyH("RIGHT")
	line.Detail:SetPoint("RIGHT", line, "RIGHT", -8, 0)
end

---@param line SkillUpListLine
---@param elementData SkillUpListElement
local function InitializeLine(line, elementData)
	if not built[line] then
		built[line] = true
		BuildLine(line)
	end
	local entry = elementData.entry --[[@as SkillUpListEntry]]
	line.entry = entry
	if entry.icon then
		ns.Art.Icon(line.Icon, entry.icon, LINE_ICON)
		line.Icon:Show()
	else
		line.Icon:Hide()
	end
	line.Text:SetText(entry.text)
	line.Text:SetTextColor((entry.color or NORMAL_FONT_COLOR):GetRGB())
	line.Detail:SetText(entry.detail or "")
	line.Detail:SetShown(entry.detail ~= nil)
	line.Detail:SetTextColor((entry.detailColor or GRAY_FONT_COLOR):GetRGB())
	line.tooltip = entry.tooltip
	line.click = entry.click
	line.menu = entry.menu
	line:EnableMouse(entry.tooltip ~= nil or entry.click ~= nil or entry.menu ~= nil)
end

-- A list in the game's own scroll box list: rows the game draws its items with, headings and messages. A
-- caller fills it between Begin and Finish; the game pools the frames and shows only the ones on screen.
---@param parent Frame
---@return SkillUpList
function ns.CreateList(parent)
	local scrollBox = CreateFrame("Frame", nil, parent, "WowScrollBoxList") --[[@as SkillUpScrollBox]]
	scrollBox:SetPoint("TOPLEFT", 4, -4)
	scrollBox:SetPoint("BOTTOMRIGHT", -SCROLL_BAR_WIDTH, 4)
	local scrollBar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar") --[[@as SkillUpScrollBar]]
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)
	scrollBar:SetHideIfUnscrollable(true)

	-- A message's height is its wrapped text's, so one line string measures every message at the width the
	-- list has now, and the scroll box lays the frames out from that.
	local measure = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	measure:SetWordWrap(true)
	measure:Hide()

	local view = CreateScrollBoxListLinearView() --[[@as SkillUpScrollView]]
	view:SetElementExtentCalculator(function(_, elementData)
		if elementData.kind == "row" then
			return elementData.entry.bar and ROW_BAR_HEIGHT or ROW_HEIGHT
		elseif elementData.kind == "band" then
			return BAND_HEIGHT
		elseif elementData.kind == "line" then
			return LINE_HEIGHT
		elseif elementData.kind == "heading" then
			return HEADING_HEIGHT
		end
		local width = scrollBox:GetWidth() - MESSAGE_PADDING
		if width > 0 then
			measure:SetWidth(width)
		end
		measure:SetText(elementData.text)
		return math.max(MESSAGE_MIN_HEIGHT, measure:GetStringHeight() + 8)
	end)
	view:SetElementFactory(function(factory, elementData)
		if elementData.kind == "row" then
			factory(ROW_TEMPLATE, InitializeRow)
		elseif elementData.kind == "band" then
			factory(BAND_TEMPLATE, InitializeBand)
		elseif elementData.kind == "line" then
			factory(LINE_TEMPLATE, InitializeLine)
		elseif elementData.kind == "heading" then
			factory(HEADING_TEMPLATE, InitializeHeading)
		else
			factory(MESSAGE_TEMPLATE, InitializeMessage)
		end
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

	---@class SkillUpList
	local list = { rows = {}, scrollBox = scrollBox }

	function list:Begin()
		self.rows = {}
	end

	---@param text string
	function list:Heading(text)
		self.rows[#self.rows + 1] = { kind = "heading", text = text }
	end

	---@param text string
	---@param color ColorMixin?
	function list:Message(text, color)
		self.rows[#self.rows + 1] = { kind = "message", text = text, color = color }
	end

	---@param name string
	---@param from number
	---@param cap number
	---@param skill number
	function list:Band(name, from, cap, skill)
		self.rows[#self.rows + 1] = { kind = "band", name = name, from = from, cap = cap, skill = skill }
	end

	---@param entry SkillUpListEntry
	function list:Line(entry)
		self.rows[#self.rows + 1] = { kind = "line", entry = entry }
	end

	---@param entry SkillUpListEntry
	function list:Add(entry)
		self.rows[#self.rows + 1] = { kind = "row", entry = entry }
	end

	function list:Finish()
		self.scrollBox:SetDataProvider(CreateDataProvider(self.rows), ScrollBoxConstants.RetainScrollPosition)
	end
	return list
end
