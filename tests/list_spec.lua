-- Run from the repository root: luajit tests/list_spec.lua
-- The addon's list: the elements a caller adds, the height the game lays each one out at, and the frames
-- the game draws them with, a full-size item icon in its stock border, the name beside it and the
-- supporting facts on the line under it, all built from the element the scroll box hands the initializer.
local Client = dofile("tests/client.lua")
local equal = Client.equal

-- A frame or region that records its anchors, text, colour, visibility and size; anything else is accepted
-- and ignored. A font string reports a wrapped height for a long line, so the message height can be read.
local function Region()
	local methods = {
		SetPoint = function(self, ...)
			self.points[#self.points + 1] = { ... }
		end,
		ClearAllPoints = function(self)
			self.points = {}
		end,
		SetText = function(self, text)
			self.text = text
		end,
		SetFormattedText = function(self, format, ...)
			self.text = string.format(format, ...)
		end,
		SetTextColor = function(self, r, g, b)
			self.color = { r, g, b }
		end,
		SetAtlas = function(self, atlas, useAtlasSize, _, _, wrapHorizontal, wrapVertical)
			self.atlas = atlas
			self.useAtlasSize = useAtlasSize
			self.wrapHorizontal, self.wrapVertical = wrapHorizontal, wrapVertical
		end,
		SetTexCoord = function(self, left, right, top, bottom)
			self.texcoord = { left, right, top, bottom }
		end,
		SetStatusBarTexture = function(self, texture)
			self.statusBarTexture = texture
		end,
		SetMinMaxValues = function(self, minimum, maximum)
			self.minimum, self.maximum = minimum, maximum
		end,
		SetValue = function(self, value)
			self.value = value
		end,
		CreateMaskTexture = function(self)
			local mask = Region()
			mask.parent = self
			return mask
		end,
		AddMaskTexture = function(self, mask)
			self.mask = mask
		end,
		SetTexture = function(self, texture)
			self.texture = texture
		end,
		SetShown = function(self, shown)
			self.shown = shown
		end,
		Show = function(self)
			self.shown = true
		end,
		Hide = function(self)
			self.shown = false
		end,
		SetSize = function(self, width, height)
			self.width, self.height = width, height
		end,
		SetWidth = function(self, width)
			self.width = width
		end,
		SetHeight = function(self, height)
			self.height = height
		end,
		SetWordWrap = function(self, wrap)
			self.wordWrap = wrap
		end,
		SetScript = function(self, name, script)
			self.scripts[name] = script
		end,
		GetWidth = function(self)
			return rawget(self, "width") or 300
		end,
		GetStringHeight = function(self)
			return self.text and #self.text > 20 and 24 or 12
		end,
		CreateFontString = function(self, _, layer)
			local font = Region()
			font.parent, font.layer = self, layer
			return font
		end,
		CreateTexture = function(self, _, layer)
			local texture = Region()
			texture.parent, texture.layer = self, layer
			return texture
		end,
	}
	return setmetatable({ points = {}, scripts = {} }, {
		__index = function(_, key)
			return methods[key] or function() end
		end,
	})
end

local view, scrollBox, provider, retained

local function CreateFrame(_, _, _, template)
	local frame = Region()
	if template == "WowScrollBoxList" then
		scrollBox = frame
		frame.SetDataProvider = function(_, list, retain)
			provider, retained = list, retain
		end
	end
	return frame
end

local function CreateView()
	view = Region()
	function view:SetElementExtentCalculator(calculator)
		self.extent = calculator
	end
	function view:SetElementFactory(factory)
		self.factory = factory
	end
	return view
end

local color = { GetRGB = function() end }
local ns = {
	WhenEvent = function() end,
	WhenStale = function() end,
	COLORS = { green = color },
	L = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	}),
}
local env = setmetatable({
	GameTooltip = Region(),
	CreateFrame = CreateFrame,
	CreateScrollBoxListLinearView = CreateView,
	CreateDataProvider = function(elements)
		return { elements = elements }
	end,
	ScrollUtil = { InitScrollBoxListWithScrollBar = function() end },
	ScrollBoxConstants = { RetainScrollPosition = true },
	HIGHLIGHT_FONT_COLOR = color,
	GRAY_FONT_COLOR = color,
	NORMAL_FONT_COLOR = color,
}, { __index = _G })
setfenv(assert(loadfile("UI/List.lua")), env)("SkillUpForever", ns)

local list = ns.CreateList(Region())

-- The anchors a region was last given at `point`: its arguments after the point's name.
local function Anchor(region, point)
	local found
	for _, anchor in ipairs(region.points) do
		if anchor[1] == point then
			found = anchor
		end
	end
	return found or {}
end

-- The list is the game's own scroll box, inset to leave room for the scroll bar.
equal(Anchor(scrollBox, "TOPLEFT")[2], 4, "the scroll box is inset 4 from the left")
equal(Anchor(scrollBox, "BOTTOMRIGHT")[2], -18, "and leaves room for the scroll bar")

-- Fills the list with one of each kind: a row with facts, a row without, a heading and two messages, one
-- short and one long enough to wrap to a second line.
local function Fill()
	list:Begin()
	list:Add({ icon = 134400, text = "Heavy Linen Bandage", detail = "18 crafts to 90, 54s" })
	list:Add({ text = "Total 54s" })
	list:Heading("Head")
	list:Message("Nothing to buy.")
	list:Message("A message long enough to wrap onto a second line in the list.")
	list:Finish()
end
Fill()

-- The elements are what the caller added, in order, and the scroll box was handed them to draw itself.
equal(#list.rows, 5, "the last render holds every element")
equal(list.rows[1].kind, "row", "a row is its own kind")
equal(list.rows[1].entry.text, "Heavy Linen Bandage", "with the entry the caller added")
equal(list.rows[2].kind, "row", "a second row is a row too")
equal(list.rows[3].kind, "heading", "a heading is its own kind")
equal(list.rows[3].text, "Head", "with its text")
equal(list.rows[4].kind, "message", "a message is its own kind")
equal(list.rows[4].text, "Nothing to buy.", "with its text")
equal(provider.elements, list.rows, "the scroll box draws the last render's elements")
equal(retained, true, "keeping the scroll position between renders")

-- Each kind is laid out at its own height; a message is as tall as its wrapped text, with a floor.
equal(view.extent(1, list.rows[1]), 46, "a row is the game's item height")
equal(view.extent(3, list.rows[3]), 26, "a heading is its stock line's height")
equal(view.extent(4, list.rows[4]), 20, "a one-line message keeps the minimum height")
equal(view.extent(5, list.rows[5]), 32, "a wrapped message is as tall as its lines")

-- The factory picks a template a kind, so the scroll box's pools stay apart.
local function Materialize(elementData, frame)
	local template, initializer
	view.factory(function(name, init)
		template, initializer = name, init
	end, elementData)
	frame = frame or Region()
	initializer(frame, elementData)
	return frame, template
end

-- A row is the game's item: a 37px icon in the stock border, the name beside it, the facts under it.
local row, rowTemplate = Materialize(list.rows[1])
equal(rowTemplate, "SkillUpForeverListRowTemplate", "a row is built from the row template")
equal(row.kind, "row", "and knows it is a row")
equal(Anchor(row.Icon, "LEFT")[2], 6, "the icon sits 6 in from the left")
equal(row.Icon.width, 37, "at the game's own item size")
equal(row.Icon.shown, true, "and is shown when the entry has one")
equal(row.IconBorder.shown, true, "with the stock item border over it")
equal(Anchor(row.IconBorder, "LEFT")[2], row.Icon, "the border sits on the icon")
equal(row.Text.text, "Heavy Linen Bandage", "the name is beside the icon")
equal(Anchor(row.Text, "TOPLEFT")[2], row.Icon, "anchored to the icon")
equal(Anchor(row.Text, "TOPLEFT")[3], "TOPRIGHT", "at its right")
equal(Anchor(row.Text, "RIGHT")[2], row, "and stops at the row's right")
equal(row.Detail.text, "18 crafts to 90, 54s", "the facts are on the line under the name")
equal(Anchor(row.Detail, "TOPLEFT")[2], row.Text, "under the name")
equal(Anchor(row.Detail, "TOPLEFT")[3], "BOTTOMLEFT", "at its bottom left")

equal(row.BarBg.atlas, "common-stat-bar-BG", "item progress uses the native bar background")
equal(row.Bar.statusBarTexture.atlas, "common-stat-bar-white", "item progress uses the native bar fill")
equal(row.BarMask.atlas, "common-stat-bar-Mask", "the client's bar mask")
equal(row.Bar.statusBarTexture.mask, row.BarMask, "shapes the fill to the frame's track")

-- The same pooled frame redrawn for a later element drops what the new element does not have.
local pooled = Region()
Materialize(list.rows[1], pooled)
local detail = pooled.Detail
row, rowTemplate = Materialize(list.rows[2], pooled)
equal(rowTemplate, "SkillUpForeverListRowTemplate", "the second row is built from the same template")
equal(row.kind, "row", "the redrawn frame is still a row")
equal(pooled.Detail, detail, "the scroll box's frame is reused")
equal(pooled.Detail.shown, false, "a row without facts shows no detail")

-- A heading is a stock line and a message is wrapped, measured text.
local heading, headingTemplate = Materialize(list.rows[3])
equal(headingTemplate, "SkillUpForeverListHeadingTemplate", "a heading is built from the heading template")
equal(heading.kind, "heading", "and knows it is a heading")
equal(heading.Text.text, "Head", "with its text")
local message, messageTemplate = Materialize(list.rows[5])
equal(messageTemplate, "SkillUpForeverListMessageTemplate", "a message is built from the message template")
equal(message.kind, "message", "and knows it is a message")
equal(message.Text.text, list.rows[5].text, "with its text")
equal(message.Text.wordWrap, true, "wrapped")

-- The row that is the next step keeps its own gold highlight; every other row leaves it hidden (#574).
list:Begin()
list:Add({ text = "Next", current = true })
list:Add({ text = "Later" })
list:Finish()
local current = Materialize(list.rows[1])
equal(current.Current.shown, true, "the current row shows its highlight")
equal(
	current.Current.texture,
	"Interface\\QuestFrame\\UI-QuestTitleHighlight",
	"drawn with the quest log's own highlight bar"
)
local later = Materialize(list.rows[2])
equal(later.Current.shown, false, "a row that is not the next step shows no highlight")

-- A left click is the row's own and a right-click opens its menu, from the row; a row with only a menu still
-- takes the mouse.
local menus, clicks = {}, {}
env.GameTooltip_Hide = function() end
env.MenuUtil = {
	CreateContextMenu = function(owner, generator)
		menus[#menus + 1] = { owner = owner, generator = generator }
	end,
}
-- ForeverCore is not loaded here: the row asks its shared menu, which asks the client's MenuUtil.
env.ForeverCore = {
	ContextMenu = function(owner, generator)
		return env.MenuUtil.CreateContextMenu(owner, generator)
	end,
}
local function Menu() end
list:Begin()
list:Add({
	text = "Linen Bandage",
	click = function(clicked)
		clicks[#clicks + 1] = clicked
	end,
	menu = Menu,
})
list:Add({ text = "Skipped (1)", menu = Menu })
list:Add({ text = "Total 54s" })
list:Finish()
local clickable = Materialize(list.rows[1])
local mouse
clickable.EnableMouse = function(_, enabled)
	mouse = enabled
end
Materialize(list.rows[1], clickable)
clickable.scripts.OnClick(clickable, "LeftButton")
equal(clicks[1], clickable, "a left click is the row's own, given the row")
equal(#menus, 0, "and opens no menu")
clickable.scripts.OnClick(clickable, "RightButton")
equal(#clicks, 1, "a right-click is not a left click")
equal(menus[1].owner, clickable, "it opens the menu on the row")
equal(menus[1].generator, Menu, "filled by the entry's menu")
Materialize(list.rows[2], clickable)
equal(mouse, true, "a row with only a menu takes the mouse")
Materialize(list.rows[3], clickable)
equal(mouse, false, "a row with nothing to do does not")

-- A train or buy line is wired through the same helper as a row: its own click and its menu.
local lineClicks = {}
local function LineMenu() end
list:Begin()
list:Line({
	text = "Train Journeyman",
	click = function(clicked)
		lineClicks[#lineClicks + 1] = clicked
	end,
	menu = LineMenu,
})
list:Finish()
local line = Materialize(list.rows[1])
equal(line.kind, "line", "a train step is a line")
line.scripts.OnClick(line, "LeftButton")
equal(lineClicks[1], line, "a line's left click is its own")
line.scripts.OnClick(line, "RightButton")
equal(#lineClicks, 1, "a line's right-click is not a left click")
equal(menus[#menus].owner, line, "a line opens its menu on itself")
equal(menus[#menus].generator, LineMenu, "filled by the line's menu")

-- The skill band follows the client's ColoredProgressBarTemplate: its fill keeps the progress as
-- its width and crops the texture to the same fraction, so an empty band draws nothing even where
-- the client ignores a zero width, and one pooled frame redraws every state.
local function Coords(texture)
	local coords = rawget(texture, "texcoord")
	return coords and table.concat(coords, ",") or ""
end

local function Shown(region)
	return rawget(region, "shown")
end

local function BarBand(skill, frame)
	list:Begin()
	list:Band("Expert", 150, 225, skill)
	list:Finish()
	return Materialize(list.rows[1], frame)
end

local pooledBand = Region()
local emptyBand = BarBand(150, pooledBand)
equal(Shown(emptyBand.BarFill), false, "a band with no progress draws no fill")
equal(Coords(emptyBand.BarFill), "0,0,1,0", "and crops its whole texture away")
equal(emptyBand.BarFill.width, 0, "with no width")
equal(emptyBand.BarText.text, "0/75", "while the band count reads zero")
local track = emptyBand.BarBg:GetWidth() - 12

local partialBand = BarBand(204, pooledBand)
equal(Shown(partialBand.BarFill), true, "a partial band shows its fill")
equal(partialBand.BarFill.texcoord[1], 0, "starting at the left of its texture")
equal(math.abs(partialBand.BarFill.texcoord[2] - 54 / 75) < 1e-9, true, "cropped at the band's fraction")
equal(
	math.abs(partialBand.BarFill.width - track * 54 / 75) < 1e-9,
	true,
	"and only as wide as that fraction of the track"
)
equal(partialBand.BarText.text, "54/75", "with the band count over it")

local fullBand = BarBand(225, pooledBand)
equal(Shown(fullBand.BarFill), true, "a full band shows its fill")
equal(Coords(fullBand.BarFill), "0,1,1,0", "cropped no further than the whole texture")
equal(math.abs(fullBand.BarFill.width - track) < 1e-9, true, "filling the track")
local overBand = BarBand(260, pooledBand)
equal(overBand.BarFill.width, track, "a band over its cap stays at the track's width")
equal(overBand.BarText.text, "75/75", "and clamps the count to the cap")
local emptyAgain = BarBand(150, pooledBand)
equal(Shown(emptyAgain.BarFill), false, "the pooled band hides its fill when it is empty again")
equal(emptyAgain.BarFill.width, 0, "with no width")
equal(Coords(emptyAgain.BarFill), "0,0,1,0", "and its texture cropped away")

-- A reagent row's count is drawn by its StatusBar, above the fill that would otherwise cover it;
-- the pooled row hides and shows that label with the bar.
local function BarRow(have, need, frame)
	list:Begin()
	list:Add({ text = "Silk Cloth", bar = { have = have, need = need } })
	list:Finish()
	return Materialize(list.rows[1], frame)
end

local pooledBarRow = Region()
local emptyRow = BarRow(0, 10, pooledBarRow)
equal(emptyRow.Bar.value, 0, "an empty reagent bar carries no progress")
equal(emptyRow.Bar.maximum, 10, "against its need")
equal(emptyRow.BarText.text, "0/10", "and still shows its count")
equal(emptyRow.BarText.parent, emptyRow.Bar, "the count is drawn by the bar, above its fill")
list:Begin()
list:Add({ text = "Total 54s" })
list:Finish()
local plainRow = Materialize(list.rows[1], pooledBarRow)
equal(Shown(plainRow.BarText), false, "a pooled row without a bar hides its count")
local partialRow = BarRow(5, 10, pooledBarRow)
equal(partialRow.Bar.value, 5, "a partial reagent bar carries its progress")
equal(partialRow.BarText.text, "5/10", "with its count shown again over the fill")
equal(Shown(partialRow.BarText), true, "after the pooled row had no bar")
local fullRow = BarRow(15, 10, pooledBarRow)
equal(fullRow.Bar.value, 10, "a met reagent bar clamps its progress to the need")
equal(fullRow.Bar.maximum, 10, "which stays its own need")
equal(fullRow.BarText.text, "10/10", "and its count is clamped too")
equal(fullRow.BarText.parent, fullRow.Bar, "still drawn by the bar itself")
local emptyAgainRow = BarRow(0, 10, pooledBarRow)
equal(emptyAgainRow.Bar.value, 0, "the pooled row carries no progress when empty again")
equal(emptyAgainRow.BarText.text, "0/10", "and shows its zero count")
equal(Shown(emptyAgainRow.BarText), true, "above the now empty bar")

Client.report("list_spec")
