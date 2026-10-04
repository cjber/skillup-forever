-- Run from the repository root: luajit tests/list_spec.lua
-- The addon's list rows: a full-size item icon in its stock border, the name beside it and the
-- supporting facts on the line under it, with headings and messages in stock fonts and the frames
-- reused between renders.
local Client = dofile("tests/client.lua")
local equal = Client.equal

-- A frame or region that records its anchors, text, colour and visibility; anything else is accepted and ignored.
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
		SetTextColor = function(self, r, g, b)
			self.color = { r, g, b }
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
		GetWidth = function()
			return 300
		end,
		GetStringHeight = function()
			return 12
		end,
		CreateFontString = function()
			return Region()
		end,
		CreateTexture = function()
			return Region()
		end,
	}
	return setmetatable({ points = {}, scripts = {} }, {
		__index = function(_, key)
			return methods[key] or function() end
		end,
	})
end

local color = { GetRGB = function() end }
local ns = { WhenEvent = function() end, WhenStale = function() end }
local env = setmetatable({
	GameTooltip = Region(),
	CreateFrame = Region,
	CreateScrollBoxLinearView = Region,
	ScrollUtil = { InitScrollBoxWithScrollBar = function() end },
	ScrollBoxConstants = {},
	HIGHLIGHT_FONT_COLOR = color,
	GRAY_FONT_COLOR = color,
	NORMAL_FONT_COLOR = color,
}, { __index = _G })
setfenv(assert(loadfile("UI/List.lua")), env)("SkillUpForever", ns)

local list = ns.CreateList(Region())

-- The anchor a region was last given at `point`: its arguments after the point's name.
local function Anchor(region, point)
	local found
	for _, anchor in ipairs(region.points) do
		if anchor[1] == point then
			found = anchor
		end
	end
	return found or {}
end

-- A row is the game's item: a 37px icon in the stock border, the name beside it, the facts under it.
list:Begin()
list:Add({ icon = 134400, text = "Heavy Linen Bandage", detail = "18 crafts to 90, 54s" })
local row = list.rows[1]
equal(row.kind, "row", "a row is the list's item row")
equal(Anchor(row.Icon, "LEFT")[2], 6, "the icon sits 6 in from the left")
equal(row.Icon.width, 37, "at the game's own item size")
equal(row.Icon.shown, true, "and is shown when the entry has one")
equal(row.IconBorder.shown, true, "with the stock item border over it")
equal(row.Text.text, "Heavy Linen Bandage", "the name is beside the icon")
equal(Anchor(row.Text, "TOPLEFT")[2], row.Icon, "anchored to the icon")
equal(Anchor(row.Text, "TOPLEFT")[3], "TOPRIGHT", "at its right")
equal(Anchor(row.Text, "RIGHT")[2], row, "and stops at the row's right")
equal(row.Detail.text, "18 crafts to 90, 54s", "the facts are on the line under the name")
equal(Anchor(row.Detail, "TOPLEFT")[2], row.Text, "under the name")
equal(Anchor(row.Detail, "TOPLEFT")[3], "BOTTOMLEFT", "at its bottom left")

-- A row with no facts shows none, as a total or a name-only line does.
list:Add({ text = "Total 54s" })
equal(list.rows[2].Detail.shown, false, "a row without facts shows no detail")

-- Headings and messages are the list's own stock lines.
list:Heading("Head")
local heading = list.rows[3]
equal(heading.kind, "heading", "a heading is its own kind")
equal(heading.Text.text, "Head", "with its text")
list:Message("Nothing to buy for this route.")
local message = list.rows[4]
equal(message.kind, "message", "a message is its own kind")
equal(message.Text.text, "Nothing to buy for this route.", "with its text")
equal(message.Text.wordWrap, true, "wrapped")
equal(message.Text.width, 288, "to the scroll box's width")
list:Finish()

-- The frames are reused between renders and the ones a later render does not use are hidden.
list:Begin()
list:Add({ text = "One" })
list:Add({ text = "Two" })
list:Finish()
local first, second = list.rows[1], list.rows[2]
list:Begin()
list:Add({ text = "One" })
list:Finish()
equal(list.rows[1], first, "a row is reused between renders")
equal(second.shown, false, "and the frame a later render does not use is hidden")

Client.report("list_spec")
