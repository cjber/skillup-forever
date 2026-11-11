---@type string, SkillUpNamespace
local _, ns = ...

if ns.broken then
	return
end
local L = ns.L
local Parts = ns.PageParts

-- The buffs page: which buff consumables this profession makes, and when. One row per buff effect, each
-- item on a skill axis at the skill its recipe is learned, in the talent tree's own square nodes. The
-- page's title is the inset's heading; the selected node fills a detail strip under the legend.

local NODE = 40
local NODE_GAP = 4
local COLUMN_GAP = 16
local LABEL_WIDTH = 128
local ICON = 37
-- The row viewport reserves space for the skill axis, the horizontal scrollbar, and the legend and detail.
-- Five whole rows fill the remaining height.
local FRAME_HEIGHT = 594
local INSET_TOP = 88
local INSET_BOTTOM = 24
local ROWS_TOP = 44
local HSCROLL_HEIGHT = 17
local HSCROLL_BOTTOM = 132
local ROWS_BOTTOM = HSCROLL_BOTTOM + HSCROLL_HEIGHT + 6
local VISIBLE_ROWS = 5
local VIEW_HEIGHT = FRAME_HEIGHT - INSET_TOP - INSET_BOTTOM - ROWS_TOP - ROWS_BOTTOM
local ROW_HEIGHT = VIEW_HEIGHT / VISIBLE_ROWS
local FADE_WIDTH = 18
local LEGEND_BOTTOM = 100
local DETAIL_BOTTOM = 24
local DETAIL_HEIGHT = 74
-- The row's label starts at the inset's left edge plus this; the rows themselves start 8 in from it, and
-- their node track starts after the label column.
local LABEL_X = 10
local AXIS_X = 18 + LABEL_WIDTH
local TRACK_X = AXIS_X - 8
-- Leave room for the vertical scrollbar and its arrow buttons.
local VIEW_RIGHT = 26

-- The four node states, in the client's talent-tree art.
local NODE_ATLAS = {
	known = "talents-node-square-green",
	trainable = "talents-node-square-yellow",
	later = "talents-node-square-gray",
	locked = "talents-node-square-locked",
}
-- The two edge colours: the talent tree's lit line for a step the character can take, its dull one otherwise.
local EDGE_ATLAS = {
	["true"] = "talents-arrow-line-yellow",
	["false"] = "talents-arrow-line-gray",
}

-- The professions with a specialization page of their own, whose art the page draws behind the timeline.
-- First Aid, Inscription and Jewelcrafting have none on this client; they keep the inset's marble.
local BACKGROUNDS = {
	Alchemy = "Professions-Specializations-Background-Alchemy",
	Blacksmithing = "Professions-Specializations-Background-Blacksmithing",
	Cooking = "Professions-Specializations-Background-Cooking",
	Enchanting = "Professions-Specializations-Background-Enchanting",
	Engineering = "Professions-Specializations-Background-Engineering",
	Fishing = "Professions-Specializations-Background-Fishing",
	Herbalism = "Professions-Specializations-Background-Herbalism",
	Leatherworking = "Professions-Specializations-Background-Leatherworking",
	Mining = "Professions-Specializations-Background-Mining",
	Skinning = "Professions-Specializations-Background-Skinning",
	Tailoring = "Professions-Specializations-Background-Tailoring",
}

---@type SkillUpBuffsPage
local page
local professions = {} -- the character's own, by skill line
local rows = {} -- the last render
local hi = 25
local columns = {} -- the last render's timeline
local contentWidth, viewWidth = 0, 0
local offset = 0
local openedLine -- the profession the sideways view was last opened for
local selectedItemID

-- The next rank above this character's cap and the skill that trains it, in the client's words.
---@param profession SkillUpContext
---@return string?
local function NextRank(profession)
	local name, skill = ns.BuffNextRank(profession)
	return name and skill and string.format(L["%s at %d"], name, skill) or nil
end

-- Fill `texture` with an atlas at its native aspect, cropped to cover the box (never stretched): the
-- source is cut to the box's aspect and centred, so the draw is uniform.
---@param texture Texture
---@param atlas string
---@param width number
---@param height number
---@return boolean
local function Cover(texture, atlas, width, height)
	local info = C_Texture.GetAtlasInfo(atlas)
	if not (info and info.width > 0 and info.height > 0) or width <= 0 or height <= 0 then
		texture:Hide()
		return false
	end
	-- art-ok: the source is cropped to the box's aspect just below, so the cover draw is uniform
	texture:SetAtlas(atlas)
	texture:SetSize(width, height)
	local atlasAspect, boxAspect = info.width / info.height, width / height
	if boxAspect > atlasAspect then
		local share = atlasAspect / boxAspect
		texture:SetTexCoord(0, 1, (1 - share) / 2, (1 + share) / 2)
	else
		local share = boxAspect / atlasAspect
		texture:SetTexCoord((1 - share) / 2, (1 + share) / 2, 0, 1)
	end
	texture:Show()
	return true
end

-- A wheel notch scrolls the rows vertically, or the timeline sideways while Shift is held.
local VERTICAL_STEP = 0.15
local SIDEWAYS_STEP = 60

-- Move the timeline's labels, divider, nodes and edges by the current sideways offset.
local function PlaceContent()
	local axis = page.AxisContent
	if axis then
		axis:ClearAllPoints()
		axis:SetPoint("TOPLEFT", page.Axis, "TOPLEFT", -offset, 0)
	end
	for _, row in ipairs(page.RowFrames or {}) do
		row.Content:ClearAllPoints()
		row.Content:SetPoint("TOPLEFT", row.Track, "TOPLEFT", -offset, 0)
	end
end

-- Keep the sideways bar and the edge fades on the timeline's current offset: the bar follows Shift+wheel and
-- a drag, and a fade shows only while more lies beyond that edge (#565).
---@param fromScrollbar? boolean
local function SyncHorizontal(fromScrollbar)
	local maxOffset = math.max(contentWidth - viewWidth, 0)
	-- Setting the thumb fires OnScroll immediately. Do not write its position back from that callback.
	if page.HScroll and not fromScrollbar then
		page.HScroll:SetVisibleExtentPercentage(contentWidth > 0 and math.min(viewWidth / contentWidth, 1) or 1)
		page.HScroll:SetScrollPercentage(
			maxOffset > 0 and offset / maxOffset or 0,
			ScrollBoxConstants.NoScrollInterpolation
		)
	end
	if page.FadeLeft and page.FadeRight then
		page.FadeLeft:SetShown(offset > 0)
		page.FadeRight:SetShown(offset < maxOffset)
	end
end

-- Show the timeline at `value` content units in, as far as the content and the view allow.
---@param value number
---@param fromScrollbar? boolean
local function SetOffset(value, fromScrollbar)
	offset = math.max(0, math.min(value, math.max(contentWidth - viewWidth, 0)))
	page.ScrollOffset = offset
	PlaceContent()
	SyncHorizontal(fromScrollbar)
end

-- The cursor's x in the area's own units, the way the client reports it while a frame is dragged.
---@param area Frame
---@return number
local function CursorX(area)
	local scale = area:GetEffectiveScale()
	return GetCursorPosition() / (scale and scale > 0 and scale or 1)
end

-- Drag to pan, the talent tree's own gesture: the timeline follows the cursor, clamped to its ends.
local dragging, dragX, dragOffset

---@param area Frame
local function PanUpdate(area)
	if not dragging then
		return
	end
	SetOffset(dragOffset - (CursorX(area) - dragX))
end

---@param area Frame
local function PanStart(area)
	if contentWidth - viewWidth <= 0 then
		return
	end
	dragging = true
	dragX = CursorX(area)
	dragOffset = offset
	area:SetScript("OnUpdate", PanUpdate)
end

---@param area Frame
local function PanStop(area)
	if not dragging then
		return
	end
	PanUpdate(area)
	dragging = false
	area:SetScript("OnUpdate", nil)
end

-- An area the player drags sideways: the rows and the axis above them, and every node on the rows.
---@param area Frame
local function EnablePan(area)
	area:EnableMouse(true)
	area:RegisterForDrag("LeftButton")
	area:SetScript("OnDragStart", PanStart)
	area:SetScript("OnDragStop", PanStop)
end

-- One wheel notch sideways, the same direction as the row's vertical wheel.
---@param delta number
local function ScrollSideways(delta)
	if contentWidth - viewWidth <= 0 then
		return
	end
	SetOffset(offset - delta * SIDEWAYS_STEP)
end

---@param _ Frame
---@param delta number
local function OnWheel(_, delta)
	if IsShiftKeyDown() then
		ScrollSideways(delta)
	elseif page.Rows then
		page.Rows:SetScrollPercentage(
			page.Rows:GetScrollPercentage() - delta * VERTICAL_STEP,
			ScrollBoxConstants.NoScrollInterpolation
		)
	end
end

-- The profession the page shows: the one picked last, else the window's when it makes buffs, else the
-- character's first buff profession, else the first other crafter.
local selectedLine
local Render

---@param line integer
local function Select(line)
	selectedLine = line
	openedLine = nil
	ns.SetLastBuffProfession(line)
	Render()
end

---@return SkillUpContext? profession
---@return SkillUpContext[] own
---@return SkillUpContext[] others
local function Selected()
	local own, others = ns.BuffProfessions(professions)
	for _, list in ipairs({ own, others }) do
		for _, profession in ipairs(list) do
			if profession.skillLine == selectedLine then
				return profession, own, others
			end
		end
	end
	local profession = ns.BuffProfessionDefault(own, others, ns.LastBuffProfession(), ns.OpenSkillLine())
	selectedLine = profession and profession.skillLine or nil
	return profession, own, others
end

-- The page's dropdown: the character's own buff professions, then the other crafters, each by name.
---@param root RootMenuDescriptionProxy
local function BuildMenu(root)
	root:SetScrollMode(Parts.MENU_EXTENT)
	local own, others = ns.BuffProfessions(ns.PlayerProfessions())
	for _, profession in ipairs(own) do
		local line = profession.skillLine --[[@as integer]]
		root:CreateRadio(profession.name, function()
			return line == selectedLine
		end, function()
			Select(line)
		end)
	end
	if #others > 0 then
		root:CreateDivider()
		root:CreateTitle(L["Other crafters"])
		for _, profession in ipairs(others) do
			local line = profession.skillLine --[[@as integer]]
			root:CreateRadio(profession.name, function()
				return line == selectedLine
			end, function()
				Select(line)
			end)
		end
	end
end

-- Where a recipe is learned and what it takes, in one line: its source and skill, then its reagents.
---@param item SkillUpBuffItem
---@param profession SkillUpContext
---@return string
local function LearnLine(item, profession)
	local source = ns.LearnSource(profession, item.recipeID)
	local parts = { source and ns.LearnSourceText(source) or L["Source unknown"] }
	local reagents = {}
	for _, reagent in ipairs(ns.Reagents(item.recipeID) or {}) do
		local name = C_Item.GetItemNameByID(reagent.itemID)
		if not name then
			C_Item.RequestLoadItemDataByID(reagent.itemID)
			name = string.format(L["item %d"], reagent.itemID)
		end
		reagents[#reagents + 1] = name
	end
	if #reagents > 0 then
		parts[#parts + 1] = table.concat(reagents, ", ")
	end
	return table.concat(parts, ". ")
end

-- The selected item, or the first one the character can use or learn in the view the page opens at: a known
-- node first, then a learnable one, preferring a node on a row and in a column the reader can see.
---@return SkillUpBuffItem?
local function SelectedItem()
	local first, known, trainable, visibleKnown, visibleTrainable
	local rowIndex = 0
	for _, row in ipairs(rows) do
		rowIndex = rowIndex + 1
		local xs = ns.BuffRowX(row.items, columns, NODE, NODE_GAP)
		for index, item in ipairs(row.items) do
			if item.itemID == selectedItemID then
				return item
			end
			first = first or item
			if not item.locked and (item.state == "known" or item.state == "trainable") then
				local visible = rowIndex <= VISIBLE_ROWS
					and xs[index] + NODE > offset
					and xs[index] < offset + viewWidth
				if item.state == "known" then
					known = known or item
					if visible then
						visibleKnown = visibleKnown or item
					end
				else
					trainable = trainable or item
					if visible then
						visibleTrainable = visibleTrainable or item
					end
				end
			end
		end
	end
	return visibleKnown or visibleTrainable or known or trainable or first
end

---@param detail SkillUpBuffDetail
---@param item SkillUpBuffItem?
---@param profession SkillUpContext?
local function RenderDetail(detail, item, profession)
	detail:SetShown(item ~= nil)
	if not item then
		return
	end
	local color = Parts.QualityColor(item.itemID)
	-- art-ok: a square item icon in its ICON square; the texture never draws an atlas
	detail.Icon:SetTexture(C_Item.GetItemIconByID(item.itemID))
	detail.Border:SetVertexColor((color or HIGHLIGHT_FONT_COLOR):GetRGB())
	detail.Name:SetText(Parts.ItemName(item))
	detail.Name:SetTextColor((color or HIGHLIGHT_FONT_COLOR):GetRGB())
	local buff = ns.BuffText(item.itemID)
	detail.Buff:SetText(buff or "")
	detail.Buff:SetShown(buff ~= nil)
	detail.Learn:SetText(profession and LearnLine(item, profession) or "")
	local text, enabled, click, reason = Parts.BuffAction(item, professions)
	detail.Action:SetText(text)
	-- As wide as its label, so a translated one fits.
	detail.Action:SetWidth(math.max(130, detail.Action:GetTextWidth() + 32))
	detail.Action:SetEnabled(enabled)
	detail.Action.click = click
	detail.Action.reason = reason
end

-- The parts a row frame draws once: its fixed label, the clipped track its nodes scroll in, and the pools
-- of nodes and edge tiles.
---@param row SkillUpBuffRowFrame
local function BuildRow(row)
	row.Label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.Label:SetJustifyH("LEFT")
	row.Label:SetJustifyV("MIDDLE")
	row.Label:SetWordWrap(false)
	row.Label:SetSize(LABEL_WIDTH, NODE)
	row.Label:SetPoint("TOPLEFT", row, "TOPLEFT", LABEL_X, 0)
	row.Track = CreateFrame("Frame", nil, row)
	row.Track:SetPoint("TOPLEFT", row, "TOPLEFT", TRACK_X, 0)
	row.Track:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	row.Track:SetClipsChildren(true)
	row.Content = CreateFrame("Frame", nil, row.Track)
	row.Content:SetPoint("TOPLEFT", row.Track, "TOPLEFT", -offset, 0)
	row.Content:SetSize(1, ROW_HEIGHT)
	page.RowFrames[#page.RowFrames + 1] = row
	row.Nodes = {}
	row.Edges = {}
end

-- A row's node: a square talent node holding the item's icon, with the lock on one above the character's level.
---@param row SkillUpBuffRowFrame
---@param index integer
---@return SkillUpBuffNode
local function Node(row, index)
	local node = row.Nodes[index]
	if node then
		return node
	end
	node = CreateFrame("Button", nil, row.Content) --[[@as SkillUpBuffNode]]
	node:SetSize(NODE, NODE)
	node.Shadow = node:CreateTexture(nil, "BACKGROUND")
	node.Shadow:SetAtlas("talents-node-square-shadow", true)
	node.Shadow:SetPoint("CENTER")
	node.Icon = node:CreateTexture(nil, "ARTWORK")
	-- The icon's own bevel is cropped off, the same on both axes: 0.08 to 0.92 of a square file icon.
	node.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	node.Icon:SetSize(34, 34)
	node.Icon:SetPoint("CENTER")
	node.Frame = node:CreateTexture(nil, "OVERLAY")
	node.Frame:SetAllPoints()
	node.Lock = node:CreateTexture(nil, "OVERLAY")
	node.Lock:SetAtlas("Talents-lock-c60", true)
	node.Lock:SetPoint("BOTTOMRIGHT", node, "BOTTOMRIGHT", -3, 3)
	node.Select = node:CreateTexture(nil, "OVERLAY")
	node.Select:SetAtlas("Profession-square-frame-glow") -- art-ok: a square glow over the square NODE
	node.Select:SetBlendMode("ADD")
	node.Select:SetAllPoints()
	node:SetScript("OnEnter", function(self)
		if self.item then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			Parts.ItemTooltip(self.item, professions)(GameTooltip)
			GameTooltip:Show()
		end
	end)
	node:SetScript("OnLeave", GameTooltip_Hide)
	node:SetScript("OnClick", function(self)
		if self.item then
			selectedItemID = self.item.itemID
			Render()
		end
	end)
	-- A drag that starts on a node pans the timeline; a click without one still selects the node.
	node:RegisterForDrag("LeftButton")
	node:SetScript("OnDragStart", function()
		PanStart(page.Rows)
	end)
	node:SetScript("OnDragStop", function()
		PanStop(page.Rows)
	end)
	row.Nodes[index] = node
	return node
end

---@param row SkillUpBuffRowFrame
---@param index integer
---@return Texture
local function EdgeTile(row, index)
	local tile = row.Edges[index]
	if not tile then
		tile = row.Content:CreateTexture(nil, "ARTWORK")
		row.Edges[index] = tile
	end
	return tile
end

-- Draw a row: its label, its edge tiles and its nodes.
---@param row SkillUpBuffRowFrame
---@param data SkillUpBuffRowData
local function FillRow(row, data)
	row.Label:SetText(data.row.label)
	row.Content:SetWidth(math.max(contentWidth, 1))
	row.Content:ClearAllPoints()
	row.Content:SetPoint("TOPLEFT", row.Track, "TOPLEFT", -offset, 0)
	local used = 0
	local xs = ns.BuffRowX(data.row.items, data.columns, NODE, NODE_GAP)
	local previous
	for index, item in ipairs(data.row.items) do
		local x = xs[index]
		if previous then
			local lit = ns.BuffNodeState(item) == "known" or ns.BuffNodeState(item) == "trainable"
			local tileX = previous + NODE
			while tileX < x - 0.5 do
				used = used + 1
				local tile = EdgeTile(row, used)
				tile:SetAtlas(EDGE_ATLAS[tostring(lit)], true) -- art-ok: a tile of the talent line, at its native size
				tile:ClearAllPoints()
				tile:SetPoint("TOPLEFT", row.Content, "TOPLEFT", tileX, -(NODE / 2 - tile:GetHeight() / 2))
				tile:Show()
				local step = tile:GetWidth()
				if step <= 0 then
					break
				end
				tileX = tileX + step
			end
		end
		previous = x
		local node = Node(row, index)
		node.item = item
		node:ClearAllPoints()
		node:SetPoint("TOPLEFT", row.Content, "TOPLEFT", x, 0)
		local state = ns.BuffNodeState(item)
		-- art-ok: a square file icon in the 34 square; the crop above is even on both axes
		node.Icon:SetTexture(C_Item.GetItemIconByID(item.itemID))
		node.Icon:SetDesaturated(state == "later" or state == "locked")
		node.Frame:SetAtlas(NODE_ATLAS[state]) -- art-ok: the square node art in the square NODE
		node.Lock:SetShown(state == "locked")
		node.Select:SetShown(item.itemID == selectedItemID)
		node:Show()
	end
	for index = #data.row.items + 1, #row.Nodes do
		row.Nodes[index]:Hide()
	end
	for index = used + 1, #row.Edges do
		row.Edges[index]:Hide()
	end
	row:Show()
end

---@param row SkillUpBuffRowFrame
---@param data SkillUpBuffRowData
local function InitializeRow(row, data)
	if not row.Label then
		BuildRow(row)
	end
	FillRow(row, data)
end

-- One row's frame in the scroll box, and its own pool of node and edge frames.
---@param inset Frame
local function CreateRows(inset)
	page.RowFrames = {}
	local scrollBox = CreateFrame("Frame", nil, inset, "WowScrollBoxList") --[[@as SkillUpScrollBox]]
	scrollBox:SetPoint("TOPLEFT", inset, "TOPLEFT", 8, -ROWS_TOP)
	scrollBox:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -VIEW_RIGHT, ROWS_BOTTOM)
	local scrollBar = CreateFrame("EventFrame", nil, inset, "MinimalScrollBar") --[[@as SkillUpScrollBar]]
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)
	scrollBar:SetHideIfUnscrollable(true)
	local view = CreateScrollBoxListLinearView() --[[@as SkillUpScrollView]]
	view:SetElementExtentCalculator(function()
		return ROW_HEIGHT
	end)
	view:SetElementFactory(function(factory, _)
		factory("SkillUpForeverBuffRowTemplate", InitializeRow)
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
	scrollBox:EnableMouseWheel(true)
	scrollBox:SetScript("OnMouseWheel", OnWheel)
	EnablePan(scrollBox)
	page.Rows = scrollBox
end

-- Rotate the MinimalScrollBar art inside horizontal texture bounds.
local function RotateScrollTexture(texture)
	texture:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
end

local function LayoutHorizontalScrollArt(owner)
	local begin, middle, finish = owner.Begin, owner.Middle, owner.End
	RotateScrollTexture(begin)
	RotateScrollTexture(middle)
	RotateScrollTexture(finish)
	local beginAtlas = C_Texture.GetAtlasInfo(begin:GetAtlas())
	local endAtlas = C_Texture.GetAtlasInfo(finish:GetAtlas())
	begin:SetSize(beginAtlas.height, beginAtlas.width)
	finish:SetSize(endAtlas.height, endAtlas.width)

	middle:SetHeight(8)
end

local function OrientHorizontalScrollArt(owner)
	owner.Begin:ClearAllPoints()
	owner.Begin:SetPoint("LEFT")
	owner.End:ClearAllPoints()
	owner.End:SetPoint("RIGHT")
	owner.Middle:ClearAllPoints()
	owner.Middle:SetPoint("LEFT", owner.Begin, "RIGHT")
	owner.Middle:SetPoint("RIGHT", owner.End, "LEFT")
	LayoutHorizontalScrollArt(owner)
end

-- Keep the Blizzard track, thumb, and steppers, with their art laid out left to right.
local function OrientHorizontalScrollbar(bar)
	bar.isHorizontal = true
	bar.thumbAnchor = "LEFT"

	local track = bar.Track
	track:ClearAllPoints()
	track:SetPoint("LEFT", bar, "LEFT", 19, 0)
	track:SetPoint("RIGHT", bar, "RIGHT", -19, 0)
	track:SetHeight(8)
	OrientHorizontalScrollArt(track)

	local thumb = track.Thumb
	thumb.isHorizontal = true
	thumb:SetScript("OnSizeChanged", nil)
	thumb:SetHeight(8)
	OrientHorizontalScrollArt(thumb)
	hooksecurefunc(thumb, "OnButtonStateChanged", LayoutHorizontalScrollArt)

	for _, stepper in ipairs({ bar.Back, bar.Forward }) do
		stepper:ClearAllPoints()
		stepper:SetPoint(stepper == bar.Back and "LEFT" or "RIGHT")
		stepper:SetSize(11, 17)
		local function UpdateArt(button)
			RotateScrollTexture(button.Texture)
			button.Texture:SetSize(11, 17)
		end
		hooksecurefunc(stepper, "OnButtonStateChanged", UpdateArt)
		UpdateArt(stepper)
	end
end

---@param inset Frame
local function CreateHorizontalBar(inset)
	local bar = CreateFrame("EventFrame", nil, inset, "MinimalScrollBar") --[[@as SkillUpScrollBar]]
	bar:SetHeight(HSCROLL_HEIGHT)
	OrientHorizontalScrollbar(bar)
	bar:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", AXIS_X, HSCROLL_BOTTOM)
	bar:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -VIEW_RIGHT, HSCROLL_BOTTOM)
	bar:SetHideIfUnscrollable(true)
	bar:RegisterCallback("OnScroll", function(_, percentage)
		SetOffset((percentage or 0) * math.max(contentWidth - viewWidth, 0), true)
	end, bar)
	bar:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip_SetTitle(GameTooltip, L["Timeline"])
		GameTooltip_AddNormalLine(GameTooltip, L["Shift + wheel, or drag, scrolls the timeline sideways."])
		GameTooltip:Show()
	end)
	bar:SetScript("OnLeave", GameTooltip_Hide)
	page.HScroll = bar
end

-- A soft dark edge over the timeline where it is clipped: the left one while the view is scrolled in, the right
-- one while more lies beyond it. A fade is a gradient fill, so stretching it is its job.
---@param inset Frame
---@param left boolean
---@return Frame
local function CreateFade(inset, left)
	local fade = CreateFrame("Frame", nil, inset)
	fade:SetFrameLevel(inset:GetFrameLevel() + 10)
	if left then
		fade:SetPoint("TOPLEFT", inset, "TOPLEFT", AXIS_X, -2)
		fade:SetPoint("BOTTOMRIGHT", inset, "BOTTOMLEFT", AXIS_X + FADE_WIDTH, ROWS_BOTTOM)
	else
		fade:SetPoint("TOPLEFT", inset, "TOPRIGHT", -(VIEW_RIGHT + FADE_WIDTH), -2)
		fade:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -VIEW_RIGHT, ROWS_BOTTOM)
	end
	local gradient = fade:CreateTexture(nil, "OVERLAY")
	gradient:SetAllPoints()
	gradient:SetColorTexture(0, 0, 0, 1)
	local from, to = CreateColor(0, 0, 0, 0.7), CreateColor(0, 0, 0, 0)
	if not left then
		from, to = to, from
	end
	gradient:SetGradient("HORIZONTAL", from, to)
	fade:Hide()
	return fade
end

-- The fixed axis above the rows, the clipped content it and the divider scroll in, the legend and the
-- detail strip.
---@param inset Frame
local function CreateFurniture(inset)
	local axis = CreateFrame("Frame", nil, inset)
	axis:SetPoint("TOPLEFT", inset, "TOPLEFT", AXIS_X, -2)
	axis:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -VIEW_RIGHT, ROWS_BOTTOM)
	axis:SetClipsChildren(true)
	EnablePan(axis)
	page.Axis = axis
	page.AxisContent = CreateFrame("Frame", nil, axis)
	page.AxisContent:SetPoint("TOPLEFT", axis, "TOPLEFT")
	page.AxisContent:SetSize(1, 1)
	page.ColumnLabels = {}
	page.FadeLeft = CreateFade(inset, true)
	page.FadeRight = CreateFade(inset, false)
	CreateHorizontalBar(inset)

	page.Divider = page.AxisContent:CreateTexture(nil, "ARTWORK")
	page.Divider:SetAtlas("Professions-Specializations-Divider", true)
	local divider = C_Texture.GetAtlasInfo("Professions-Specializations-Divider")
	page.DividerNative = divider and divider.height or page.Divider:GetHeight()
	page.Divider:Hide()
	page.DividerLabel = page.AxisContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	page.DividerLabel:SetTextColor(GRAY_FONT_COLOR:GetRGB())
	page.DividerLabel:Hide()

	local legend = CreateFrame("Frame", nil, inset)
	legend:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 18, LEGEND_BOTTOM)
	legend:SetSize(1, 16)
	page.Legend = legend
	local x = 0
	for _, state in ipairs({ "known", "trainable", "later", "locked" }) do
		local art = legend:CreateTexture(nil, "ARTWORK")
		art:SetAtlas(NODE_ATLAS[state]) -- art-ok: the square state mark at 16
		art:SetSize(16, 16)
		art:SetPoint("TOPLEFT", legend, "TOPLEFT", x, 0)
		local label = legend:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		label:SetText(
			state == "known" and L["Known"]
				or state == "trainable" and L["Learn now"]
				or state == "later" and L["Later"]
				or L["Above your level"]
		)
		label:SetTextColor(GRAY_FONT_COLOR:GetRGB())
		label:SetPoint("LEFT", art, "RIGHT", 4, 0)
		x = x + 20 + label:GetStringWidth() + 12
	end

	local detail = CreateFrame("Frame", nil, inset) --[[@as SkillUpBuffDetail]]
	detail:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 10, DETAIL_BOTTOM)
	detail:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -10, DETAIL_BOTTOM)
	detail:SetHeight(DETAIL_HEIGHT)
	page.Detail = detail

	local header = CreateFrame("Frame", nil, detail)
	header:SetPoint("TOPLEFT", detail, "TOPLEFT")
	header:SetPoint("TOPRIGHT", detail, "TOPRIGHT")
	header:SetHeight(26)
	local left = header:CreateTexture(nil, "ARTWORK")
	left:SetAtlas("Professions-recipe-header-left", true)
	left:SetPoint("TOPLEFT")
	local right = header:CreateTexture(nil, "ARTWORK")
	right:SetAtlas("Professions-recipe-header-right", true)
	right:SetPoint("TOPRIGHT")
	local middle = header:CreateTexture(nil, "ARTWORK")
	middle:SetAtlas("Professions-recipe-header-middle") -- art-ok: a three-slice header's middle stretches by design
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("TOPRIGHT", right, "TOPLEFT")
	middle:SetHeight(left:GetHeight())
	detail.Header = header

	detail.Name = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	detail.Name:SetJustifyH("LEFT")
	detail.Name:SetPoint("LEFT", header, "LEFT", 12, 0)

	detail.Action = CreateFrame("Button", nil, header, "SharedButtonSmallTemplate") --[[@as SkillUpPageAction]]
	detail.Action:SetSize(130, 22)
	detail.Action:SetPoint("RIGHT", header, "RIGHT", -8, 0)
	detail.Action:SetScript("OnClick", function(self)
		if self.click then
			self.click()
		end
	end)
	detail.Action:SetMotionScriptsWhileDisabled(true)
	detail.Action:SetScript("OnEnter", function(self)
		if self.reason then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip_SetTitle(GameTooltip, self.reason)
			GameTooltip:Show()
		end
	end)
	detail.Action:SetScript("OnLeave", GameTooltip_Hide)
	detail.Name:SetPoint("RIGHT", detail.Action, "LEFT", -8, 0)

	local body = CreateFrame("Frame", nil, detail)
	body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
	body:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT")
	detail.Body = body
	detail.Icon = body:CreateTexture(nil, "BORDER")
	detail.Icon:SetSize(ICON, ICON)
	detail.Icon:SetPoint("TOPLEFT", 4, 0)
	detail.Border = body:CreateTexture(nil, "OVERLAY")
	detail.Border:SetTexture("Interface\\Common\\WhiteIconFrame") -- art-ok: a square border in the ICON square
	detail.Border:SetSize(ICON, ICON)
	detail.Border:SetPoint("TOPLEFT", detail.Icon, "TOPLEFT", 0, 0)
	detail.Buff = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	detail.Buff:SetJustifyH("LEFT")
	detail.Buff:SetPoint("TOPLEFT", body, "TOPLEFT", 50, -2)
	detail.Buff:SetPoint("RIGHT", body, "RIGHT", 0, 0)
	detail.Buff:SetTextColor(ns.COLORS.green:GetRGB())
	detail.Learn = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	detail.Learn:SetJustifyH("LEFT")
	detail.Learn:SetPoint("TOPLEFT", detail.Buff, "BOTTOMLEFT", 0, -2)
	detail.Learn:SetPoint("RIGHT", body, "RIGHT", 0, 0)
end

-- One small grey number per column, centred over the column's first slot.
local function RenderAxis()
	local used = 0
	for _, column in ipairs(columns) do
		used = used + 1
		local label = page.ColumnLabels[used]
		if not label then
			label = page.AxisContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			label:SetTextColor(GRAY_FONT_COLOR:GetRGB())
			page.ColumnLabels[used] = label
		end
		label:SetText(tostring(column.skill))
		label:ClearAllPoints()
		label:SetPoint("TOP", page.AxisContent, "TOPLEFT", column.x + NODE / 2, -2)
		label:Show()
	end
	for index = used + 1, #page.ColumnLabels do
		page.ColumnLabels[index]:Hide()
	end
end

-- The rank divider in the gap after the last column the cap reaches, named by the next trainer rank.
---@param profession SkillUpContext
local function RenderDivider(profession)
	local x = ns.BuffDivider(columns, profession.max, NODE, NODE_GAP, COLUMN_GAP)
	local shown = x ~= nil and page.DividerNative > 0
	page.DividerX = x
	page.Divider:SetShown(shown)
	page.DividerLabel:SetShown(shown)
	if not shown then
		return
	end
	---@cast x number
	local height = math.min(page.DividerNative, math.max(1, page.Axis:GetHeight() - (ROWS_TOP - 2)))
	page.Divider:SetTexCoord(0, 1, 0, height / page.DividerNative)
	page.Divider:SetHeight(height)
	page.Divider:ClearAllPoints()
	page.Divider:SetPoint("TOP", page.AxisContent, "TOPLEFT", x, -(ROWS_TOP - 2))
	page.DividerLabel:SetText(NextRank(profession) or "")
	page.DividerLabel:ClearAllPoints()
	page.DividerLabel:SetPoint("BOTTOMLEFT", page.AxisContent, "TOPLEFT", x + 4, -(ROWS_TOP - 4))
end

-- The profession's own specialization art behind the timeline, at its native aspect and cropped to cover.
---@param profession SkillUpContext
local function RenderBackdrop(profession)
	local atlas = BACKGROUNDS[ns.Gear.ProfessionName(profession.skillLine)]
	local inset = page.Inset
	if atlas then
		Cover(page.Backdrop, atlas, inset:GetWidth() - 4, inset:GetHeight() - 4)
		page.Backdrop:ClearAllPoints()
		page.Backdrop:SetPoint("TOPLEFT", inset, "TOPLEFT", 2, -2)
	else
		page.Backdrop:Hide()
	end
end

-- The rows, the axis, the divider and the selected node's strip.
function Render()
	professions = ns.PlayerProfessions()
	local profession = Selected()
	local only = ns.OnlyBuffsForLevel()
	page.Title:SetText(profession and string.format(L["Buffs by %s skill"], profession.name) or L["Buffs"])
	page.Profession:SetText(profession and profession.name or "")
	page.Skill:SetShown(profession ~= nil and not profession.other)
	if profession and not profession.other then
		page.Skill:SetFormattedText(L["Skill  %d/%d"], profession.base or profession.skill, profession.max)
	end
	page.Level:SetChecked(only)
	page.LevelLabel:SetText(string.format(L["Only for level %d"], UnitLevel("player")))
	rows = profession and ns.BuffRows(profession, UnitLevel("player"), only) or {}
	hi = ns.BuffAxis(rows)
	viewWidth = math.max(1, page.Inset:GetWidth() - AXIS_X - VIEW_RIGHT)
	columns, contentWidth = ns.BuffColumns(rows, hi, viewWidth, NODE, NODE_GAP, COLUMN_GAP)
	page.RowsData = rows
	page.Hi = hi
	page.Columns = columns
	page.ContentWidth = contentWidth
	page.ViewWidth = viewWidth
	local item = SelectedItem()
	selectedItemID = item and item.itemID or nil
	page.SelectedItemID = selectedItemID
	page.Empty:SetShown(#rows == 0)
	page.Rows:SetShown(#rows > 0)
	page.Axis:SetShown(#rows > 0)
	page.Legend:SetShown(#rows > 0)
	if #rows == 0 then
		page.DividerX = nil
		page.Detail:Hide()
		page.Divider:Hide()
		page.DividerLabel:Hide()
		page.HScroll:Hide()
		page.FadeLeft:Hide()
		page.FadeRight:Hide()
		page.Empty:SetText(
			profession == nil and L["No profession here makes buff items."]
				or only and L["No buff items for your level yet."]
				or L["This profession makes no buff items."]
		)
		return
	end
	---@cast profession SkillUpContext
	RenderBackdrop(profession)
	page.AxisContent:SetSize(math.max(contentWidth, 1), page.Axis:GetHeight())
	if profession.other then
		page.DividerX = nil
		page.Divider:Hide()
		page.DividerLabel:Hide()
	else
		RenderDivider(profession)
	end
	RenderAxis()
	-- The page opens on the character's own place in the timeline; a redraw keeps where the player scrolled.
	if openedLine ~= profession.skillLine then
		openedLine = profession.skillLine
		offset = ns.BuffOpenOffset(columns, profession.other and 0 or profession.skill, contentWidth, viewWidth)
	else
		offset = math.min(offset, math.max(contentWidth - viewWidth, 0))
	end
	page.ScrollOffset = offset
	page.AxisContent:ClearAllPoints()
	page.AxisContent:SetPoint("TOPLEFT", page.Axis, "TOPLEFT", -offset, 0)
	local elements = {}
	for _, row in ipairs(rows) do
		elements[#elements + 1] = { row = row, columns = columns }
	end
	page.Rows:SetDataProvider(CreateDataProvider(elements), ScrollBoxConstants.RetainScrollPosition)
	PlaceContent()
	SyncHorizontal()
	RenderDetail(page.Detail, item, profession)
end

-- The "Only for level N" switch: the minimal checkbox and its label beside the inset's title, above the inset
-- and so clear of the skill axis and its tick labels at every window width (#599).
---@return CheckButton
local function CreateLevelCheck()
	local check = CreateFrame("CheckButton", nil, page, "MinimalCheckboxTemplate") --[[@as CheckButton]]
	check:SetScript("OnClick", function(self)
		ns.SetOnlyBuffsForLevel(self:GetChecked())
		Render()
	end)
	local label = check:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("LEFT", check, "RIGHT", 3, 0)
	label:SetText(string.format(L["Only for level %d"], UnitLevel("player")))
	-- Its bottom sits above the inset's top edge, level with the title's row; only its width depends on the
	-- label, so the axis below can never move under it.
	check:SetPoint("BOTTOMRIGHT", page.Inset, "TOPRIGHT", -(label:GetStringWidth() + 40), 7)
	page.LevelLabel = label
	return check
end

local function CreatePage()
	page = CreateFrame("Frame", nil, ProfessionsFrame) --[[@as SkillUpBuffsPage]]
	page:SetAllPoints(ProfessionsFrame.CraftingPage)
	page:SetFrameLevel(ProfessionsFrame.CraftingPage:GetFrameLevel())
	-- What's Training? paints its own page at the portrait container's level, over CraftingPage's, and never
	-- hides it when another tab is chosen. HIGH sits above that page and below dialogs, so this one keeps the
	-- clicks while both are open.
	page:SetFrameStrata("HIGH")
	page:Hide()
	local inset = CreateFrame("Frame", nil, page, "InsetFrameTemplate") --[[@as Frame]]
	page.Inset = inset
	page.Title = inset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	page.Title:SetPoint("BOTTOMLEFT", inset, "TOPLEFT", 4, 4)
	page.Title:SetText(L["Buffs"])
	inset:SetPoint("TOPLEFT", 16, -INSET_TOP)
	inset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -16, INSET_BOTTOM)
	-- The specialization art sits over the inset's marble, under the timeline.
	page.Profession, page.Skill = Parts.CreateHeader(page, BuildMenu)
	page.Backdrop = inset:CreateTexture(nil, "BACKGROUND")
	page.Empty = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	page.Empty:SetJustifyH("CENTER")
	page.Empty:SetWordWrap(true)
	page.Empty:SetPoint("LEFT", inset, "LEFT", 24, 0)
	page.Empty:SetPoint("RIGHT", inset, "RIGHT", -24, 0)
	page.Empty:SetPoint("TOP", inset, "TOP", 0, -60)
	CreateRows(inset)
	CreateFurniture(inset)
	inset:EnableMouseWheel(true)
	inset:SetScript("OnMouseWheel", OnWheel)
	page.Axis:EnableMouseWheel(true)
	page.Axis:SetScript("OnMouseWheel", OnWheel)
	page.Level = CreateLevelCheck()
	page:SetScript("OnShow", function()
		openedLine = nil
		Render()
	end)
end

function ns.AttachBuffs()
	CreatePage()
	ns.Pages.Register({
		id = "buffs",
		title = L["Buffs"],
		setting = function()
			return ns.db.showBuffsTab
		end,
		page = page,
	})
	ns.WhenStale("buffs", function()
		if page:IsShown() then
			Render()
		end
	end)
end
