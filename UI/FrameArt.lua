---@type string, SkillUpNamespace
local _, ns = ...

-- The Professions frame's art is authored for the client's 673-wide window: its 665-wide atlases plus their
-- insets. Profession-Background-Overview is anchored to both sides (PortraitFrameTemplate's Bg, which Camelot's
-- OverrideArt points at it), so it stretches as the frame grows; Profession-Background-Template2 is fixed at the
-- CraftingPage's TOPLEFT (3, -21) with useAtlasSize, so widening leaves the top band short (#343).
-- While the frame is wider, each is drawn in three pieces instead: the left art at native size, a seamless
-- leather column repeated at native scale across the extra width, and the right edge, with its own gutter,
-- re-anchored at the frame's right edge. The columns sit where a column and the one 32 units right of it match
-- on the 665-wide atlas, so one copy's edge meets the next's. The stock background is 4 units wider than its
-- atlas (2 of inset at each side); its right edge takes all 4 as extra native columns, so no piece stretches.
-- At the client's width the stock art comes back.
--
-- Nothing else of the frame's art stretches with the width: the schematic card is a fixed 360 wide and anchored
-- to the recipe list's right, so it moves with the list at its native size, its border is a nine-slice, and the
-- rank bar is fixed 451 wide at (110, -40).

---@class SkillUpFrameArtSpec
---@field atlas string
---@field width number the atlas's own width, in the columns the crops below are measured against
---@field height number
---@field left number the last native column before the repeated one
---@field column number how wide the repeated column is
---@field rightExtra number extra native columns the right edge takes, where the stock art is wider than the atlas
---@field top number the art's anchor below the frame's top
---@field leftInset number the art's anchor right of the frame's left edge
---@field rightInset number the art's right edge, inset from the frame's right edge
---@field bottomInset number? the background's bottom inset; nil for art drawn at its native height

---@type SkillUpFrameArtSpec
local BACKGROUND = {
	atlas = "Profession-Background-Overview",
	width = 665,
	height = 570,
	left = 129,
	column = 32,
	rightExtra = 4,
	top = 21,
	leftInset = 2,
	rightInset = 2,
	bottomInset = 2,
}

---@type SkillUpFrameArtSpec
local TEMPLATE = {
	atlas = "Profession-Background-Template2",
	width = 665,
	height = 570,
	left = 429,
	column = 32,
	rightExtra = 0,
	top = 21,
	leftInset = 3,
	rightInset = 5,
}

---@class SkillUpFrameArtPieces
---@field left? Texture
---@field right? Texture
---@field middles Texture[]

-- What we hid and drew, per spec, so the stock art returns when the extra width is 0.
---@type table<SkillUpFrameArtSpec, SkillUpFrameArtPieces>
local pieces = {}
---@type Texture?
local stockBackground
---@type Texture?
local stockTemplate
---@type Frame?
local templateOwner
-- The extra width now drawn, so a refresh that does not resize redraws nothing.
---@type number?
local currentExtra

---@param owner Frame
---@param atlas string
---@return Texture?
local function FindAtlas(owner, atlas)
	if not owner.GetRegions then
		return nil
	end
	for _, region in ipairs({ owner:GetRegions() }) do
		---@cast region Texture
		if region.GetAtlas and region:GetAtlas() == atlas then
			return region
		end
	end
	return nil
end

-- Draw source columns [from, to) of the atlas into a texture, at native scale.
---@param texture Texture
---@param spec SkillUpFrameArtSpec
---@param from number
---@param to number
local function Crop(texture, spec, from, to)
	texture:SetAtlas(spec.atlas) -- art-ok: the atlas member itself, cropped at native scale
	-- Some clients read SetTexCoord as fractions of the atlas member, others as fractions of its sheet. The
	-- coordinates SetAtlas left behind say which: the whole member (0..1) or the member's place on the sheet.
	local ulX, ulY, _, _, urX, _, _, lrY = 0, 0, 0, 1, 1, 0, 1, 1
	if texture.GetTexCoord then
		ulX, ulY, _, _, urX, _, _, lrY = texture:GetTexCoord()
	end
	local fromPart, toPart = from / spec.width, to / spec.width
	if math.abs(ulX) < 0.001 and math.abs(urX - 1) < 0.001 and math.abs(ulY) < 0.001 and math.abs(lrY - 1) < 0.001 then
		texture:SetTexCoord(fromPart, toPart, 0, 1)
	else
		local span = urX - ulX
		texture:SetTexCoord(ulX + span * fromPart, ulX + span * toPart, ulY, lrY)
	end
end

-- Source columns [from, to) of the atlas, at native scale, in a texture `width` units wide.
---@param spec SkillUpFrameArtSpec
---@param from number
---@param to number
---@param width number
---@param height number
---@param owner Frame
---@param layer DrawLayer
---@param subLevel integer
---@return Texture
local function Piece(spec, from, to, width, height, owner, layer, subLevel)
	local texture = owner:CreateTexture(nil, layer, nil, subLevel)
	Crop(texture, spec, from, to)
	texture:SetSize(width, height)
	texture:Hide()
	return texture
end

---@param spec SkillUpFrameArtSpec
---@return number
local function ArtHeight(spec)
	if spec.bottomInset and ProfessionsFrame then
		return ProfessionsFrame:GetHeight() - spec.top - spec.bottomInset
	end
	return spec.height
end

-- Lay the three pieces out across the frame: the left one at native size, one repeated column per copy, and
-- the right edge at the frame's right edge. The right edge starts inside the repeated column by the remainder
-- the copies overshoot by, so its first pixels join the last copy's edge.
---@param spec SkillUpFrameArtSpec
---@param owner Frame
---@param layer DrawLayer
---@param subLevel integer
---@param extra number
local function Layout(spec, owner, layer, subLevel, extra)
	local state = pieces[spec]
	if not state then
		state = { middles = {} }
		pieces[spec] = state
	end
	local height = ArtHeight(spec)
	local copies = math.ceil(extra / spec.column)
	local rightFrom = spec.left + copies * spec.column - extra
	local leftWidth = spec.left
	local rightWidth = spec.width - rightFrom + spec.rightExtra

	local left, right = state.left, state.right
	if not (left and right) then
		left = Piece(spec, 0, spec.left, leftWidth, height, owner, layer, subLevel)
		right = Piece(spec, spec.left, spec.width, rightWidth, height, owner, layer, subLevel)
		state.left, state.right = left, right
	end
	left:SetSize(leftWidth, height)
	left:ClearAllPoints()
	left:SetPoint("TOPLEFT", ProfessionsFrame, "TOPLEFT", spec.leftInset, -spec.top)
	left:Show()

	for index = 1, copies do
		local middle = state.middles[index]
		if not middle then
			middle = Piece(spec, spec.left, spec.left + spec.column, spec.column, height, owner, layer, subLevel)
			state.middles[index] = middle
		end
		middle:SetSize(spec.column, height)
		middle:ClearAllPoints()
		middle:SetPoint(
			"TOPLEFT",
			ProfessionsFrame,
			"TOPLEFT",
			spec.leftInset + leftWidth + (index - 1) * spec.column,
			-spec.top
		)
		middle:Show()
	end
	for index = copies + 1, #state.middles do
		state.middles[index]:Hide()
	end

	Crop(right, spec, rightFrom - spec.rightExtra, spec.width)
	right:SetSize(rightWidth, height)
	right:ClearAllPoints()
	right:SetPoint("TOPRIGHT", ProfessionsFrame, "TOPRIGHT", -spec.rightInset, -spec.top)
	right:Show()
end

-- The stock art returns, and every piece we drew goes away.
local function Restore()
	if stockBackground then
		stockBackground:Show()
	end
	if stockTemplate then
		stockTemplate:Show()
	end
	for _, state in pairs(pieces) do
		if state.left then
			state.left:Hide()
		end
		if state.right then
			state.right:Hide()
		end
		for _, middle in ipairs(state.middles) do
			middle:Hide()
		end
	end
	currentExtra = 0
end

-- Draw the frame's art for `extra` units of widening; 0 puts the client's own art back.
---@param extra number
function ns.FitFrameArt(extra)
	if not ProfessionsFrame then
		return
	end
	extra = math.max(0, extra)
	if currentExtra and math.abs(extra - currentExtra) < 0.5 then
		return
	end
	if extra < 1 then
		Restore()
		return
	end

	local page = ProfessionsFrame.CraftingPage
	if not (page and ProfessionsFrame.Bg and page.GetRegions) then
		return
	end
	stockBackground = stockBackground or ProfessionsFrame.Bg
	stockTemplate = stockTemplate or FindAtlas(page, TEMPLATE.atlas)
	if not stockTemplate then
		return
	end
	-- The splits above are columns of the 665-wide art. If this client's atlas is another size, leave its own
	-- art alone rather than cut the seam somewhere else.
	if C_Texture and C_Texture.GetAtlasInfo then
		local info = C_Texture.GetAtlasInfo(TEMPLATE.atlas)
		if info and info.width and info.width > 0 and math.abs(info.width - TEMPLATE.width) > 0.5 then
			return
		end
	end
	templateOwner = templateOwner or page

	stockBackground:Hide()
	stockTemplate:Hide()
	Layout(BACKGROUND, ProfessionsFrame, "BACKGROUND", -6, extra)
	Layout(TEMPLATE, templateOwner, "BACKGROUND", -3, extra)
	currentExtra = extra
end
