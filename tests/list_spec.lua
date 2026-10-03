-- Run from the repository root: luajit tests/list_spec.lua
-- A list row's layout: where the name stops, and that a note beside it is the one kept whole.
local Client = dofile("tests/client.lua")
local equal = Client.equal

-- A frame or region that records its anchors, text and visibility; anything else is accepted and ignored.
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
		SetShown = function(self, shown)
			self.shown = shown
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
	return setmetatable({ points = {} }, {
		__index = function(_, key)
			return methods[key] or function() end
		end,
	})
end

local color = { GetRGB = function() end }
local ns = {}
local env = setmetatable({
	CreateFrame = Region,
	CreateScrollBoxLinearView = Region,
	ScrollUtil = { InitScrollBoxWithScrollBar = function() end },
	ScrollBoxConstants = {},
	HIGHLIGHT_FONT_COLOR = color,
	GRAY_FONT_COLOR = color,
}, { __index = _G })
setfenv(assert(loadfile("UI/List.lua")), env)("SkillUpForever", ns)

-- The route's columns, listed right to left: each is its width and an 8 gap left of the one before.
local list = ns.CreateList(Region(), {
	{ title = "Cost", width = 64 },
	{ title = "To", width = 28 },
	{ title = "Crafts", width = 36 },
})

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

list:Add({ text = "Heavy Linen Bandage", values = { "3", "80", "12" } })
local craft = list.rows[1]
equal(Anchor(craft.Text, "RIGHT")[2], -156, "a name stops short of the columns its row fills")
equal(craft.Note.shown, false, "a row without a note shows none")

list:Add({ text = "Brilliant Smallfish", note = "vendor", values = { "?", "85" } })
local scroll = list.rows[2]
equal(scroll.Note.text, "vendor", "a note is its own text")
equal(scroll.Note.shown, true, "and is shown")
equal(Anchor(scroll.Note, "RIGHT")[2], -112, "at the right of the room, the empty column's included")
equal(Anchor(scroll.Text, "RIGHT")[2], scroll.Note, "the name stops at the note")
equal(Anchor(scroll.Text, "RIGHT")[3], "LEFT", "so the name is cut, never the note")

Client.report("list_spec")
