-- Run from the repository root: luajit tests/frameart_spec.lua
-- UI/FrameArt.lua widens the frame's art in three native pieces (left, a repeated column, right edge) and puts
-- the client's own background and Template2 back at zero extra width. The client's textures here are stubs.
local checks = 0
local function check(value, label)
	checks = checks + 1
	assert(value, label)
end

local function Texture()
	local texture = { shown = true, points = {} }
	function texture:SetAtlas(atlas)
		self.atlas = atlas
	end
	function texture:GetAtlas()
		return self.atlas
	end
	-- The atlas a SetAtlas leaves is the member's whole place on its texture: 0..1 here.
	function texture.GetTexCoord()
		return 0, 0, 0, 1, 1, 0, 1, 1
	end
	function texture:SetTexCoord(...)
		self.texcoord = { ... }
	end
	function texture:SetSize(width, height)
		self.width, self.height = width, height
	end
	function texture:SetPoint(...)
		table.insert(self.points, { ... })
	end
	function texture:ClearAllPoints()
		self.points = {}
	end
	function texture:Show()
		self.shown = true
	end
	function texture:Hide()
		self.shown = false
	end
	return texture
end

local created = {}
local stockBackground = Texture()
local stockTemplate = Texture()
stockTemplate:SetAtlas("Profession-Background-Template2")

local frame = { Bg = stockBackground, height = 594 }
function frame:GetHeight()
	return self.height
end
function frame.CreateTexture()
	local texture = Texture()
	created[#created + 1] = texture
	return texture
end
local page = { CreateTexture = frame.CreateTexture }
function page.GetRegions()
	return stockTemplate, Texture()
end
frame.CraftingPage = page

local ns = {}
setfenv(assert(loadfile("UI/FrameArt.lua")), setmetatable({ ProfessionsFrame = frame }, { __index = _G }))(
	"SkillUpForever",
	ns
)

-- At the client's width, the stock art stays and nothing is drawn.
ns.FitFrameArt(0)
check(stockBackground.shown and stockTemplate.shown, "stock art at zero extra width")
check(#created == 0, "no pieces at zero extra width")

-- 100 wider: both stock textures go away; the background gets 129 of left art, four 32-wide copies and a
-- 512-wide right edge (665 - (129 + 128 - 100) + the 4 units the stock background has beyond its atlas), so
-- the three kinds add up to the 669 the background box was at the client's width plus the 100.
ns.FitFrameArt(100)
check(not stockBackground.shown and not stockTemplate.shown, "stock art hidden while widened")
check(#created == 12, "left and right for both, four columns each")
check(created[1].width == 129 and created[1].height == 571, "the background's left art is native")
check(created[2].width == 512 and created[2].height == 571, "the background's right edge is native")
check(created[3].width == 32 and created[3].height == 571, "a background column is native")
check(created[7].width == 429 and created[7].height == 570, "Template2's left art is native")
check(created[8].width == 208 and created[8].height == 570, "Template2's right edge is native")
check(created[9].width == 32 and created[9].height == 570, "a Template2 column is native")
local backgroundRight = created[2].points[1]
check(
	backgroundRight[1] == "TOPRIGHT"
		and backgroundRight[2] == frame
		and backgroundRight[3] == "TOPRIGHT"
		and backgroundRight[4] == -2
		and backgroundRight[5] == -21,
	"the background's right edge sits at the frame's right"
)
local templateRight = created[8].points[1]
check(
	templateRight[1] == "TOPRIGHT"
		and templateRight[2] == frame
		and templateRight[3] == "TOPRIGHT"
		and templateRight[4] == -5
		and templateRight[5] == -21,
	"Template2's right edge sits at the frame's right"
)
local backgroundWidth = created[1].width + created[3].width * 4 + created[2].width
local templateWidth = created[7].width + created[9].width * 4 + created[8].width
check(backgroundWidth == 669 + 100, "the background pieces span the wider frame")
check(templateWidth == 665 + 100, "Template2 pieces span the wider frame")

-- A smaller widening reuses the pieces and hides the columns it no longer needs.
ns.FitFrameArt(40)
check(created[3].shown and created[4].shown, "two columns at 40 wider")
check(not created[5].shown and not created[6].shown, "the rest are hidden")
check(created[9].shown and created[10].shown and not created[11].shown, "Template2 columns likewise")
ns.FitFrameArt(0)
check(stockBackground.shown and stockTemplate.shown, "stock art restored at zero extra width")
check(not created[1].shown and not created[8].shown, "every piece is hidden")

print(("frameart_spec: %d checks passed"):format(checks))
