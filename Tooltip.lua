local _, ns = ...

local BAR_WIDTH = 250
local MIN_LABEL_GAP = 18
local WHITE = "Interface\\Buttons\\WHITE8X8"

-- Each style supplies the band texture/height and dresses the bar's frame; the
-- bands, labels and marker are shared.
local STYLES = {
	-- Blizzard's recipe-list category rank bar (ProfessionsStatusBarArtTemplate).
	rank = {
		height = 14,
		texture = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
		dress = function(parent, height)
			local status = CreateFrame("StatusBar", nil, parent, "ProfessionsStatusBarArtTemplate")
			status:SetPoint("TOPLEFT")
			status:SetSize(BAR_WIDTH, height)
			status:SetValue(0)
			return status
		end,
	},
	-- The profession window's header skill bar, scaled down to tooltip size.
	header = {
		height = 12,
		texture = "Interface\\TargetingFrame\\UI-StatusBar",
		dress = function(parent, height)
			local scale = height / 18
			local holder = CreateFrame("Frame", nil, parent)
			holder:SetPoint("TOPLEFT")
			holder:SetSize(BAR_WIDTH, height)
			local bg = holder:CreateTexture(nil, "BACKGROUND")
			bg:SetAtlas("Professions-skillbar-bg")
			bg:SetPoint("TOPLEFT", -5 * scale, 3 * scale)
			bg:SetSize(BAR_WIDTH + 12 * scale, 29 * scale)
			local border = holder:CreateTexture(nil, "OVERLAY")
			border:SetAtlas("Professions-skillbar-frame")
			border:SetPoint("TOPLEFT", -5 * scale, 3 * scale)
			border:SetSize(BAR_WIDTH + 10 * scale, 29 * scale)
			return holder
		end,
	},
	flat = {
		height = 8,
		texture = WHITE,
		dress = function(parent, height)
			local holder = CreateFrame("Frame", nil, parent)
			holder:SetPoint("TOPLEFT")
			holder:SetSize(BAR_WIDTH, height)
			local border = holder:CreateTexture(nil, "BACKGROUND")
			border:SetColorTexture(0, 0, 0, 0.9)
			border:SetPoint("TOPLEFT", -1, 1)
			border:SetPoint("BOTTOMRIGHT", 1, -1)
			return holder
		end,
	},
}

local bars = {}

local function CreateBar(style)
	local frame = CreateFrame("Frame", nil, UIParent)
	local height = style.height
	frame:SetSize(BAR_WIDTH, height + 30)
	frame.height = height

	local track = style.dress(frame, height)
	frame.track = track

	frame.segments = {}
	for i, color in ipairs({ "orange", "yellow", "green", "grey" }) do
		local seg = track:CreateTexture(nil, "ARTWORK", nil, 1)
		seg:SetTexture(style.texture)
		seg:SetVertexColor(ns.COLORS[color]:GetRGB())
		seg:SetHeight(height)
		frame.segments[i] = seg
	end

	frame.labels = {}
	for i = 1, 4 do
		frame.labels[i] = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	end

	frame.marker = track:CreateTexture(nil, "OVERLAY", nil, 7)
	frame.marker:SetColorTexture(1, 1, 1)
	frame.marker:SetSize(2, height + 6)

	frame.you = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	return frame
end

-- Lays the four colour bands out over [orange, grey + tail]; the tail keeps the
-- grey band visible and gives the marker somewhere to sit once a recipe is grey.
local function LayoutBar(t, skill)
	local styleKey = STYLES[ns.db.barStyle] and ns.db.barStyle or "rank"
	bars[styleKey] = bars[styleKey] or CreateBar(STYLES[styleKey])
	local bar = bars[styleKey]
	local height = bar.height
	local lo = t[1]
	local hi = t[4] + math.max(3, math.floor((t[4] - t[1]) * 0.12 + 0.5))
	local function X(value)
		return (math.min(math.max(value, lo), hi) - lo) / (hi - lo) * BAR_WIDTH
	end

	local edges = { t[1], t[2], t[3], t[4], hi }
	for i, seg in ipairs(bar.segments) do
		local left, right = X(edges[i]), X(edges[i + 1])
		seg:SetShown(right > left)
		seg:SetPoint("TOPLEFT", bar.track, "TOPLEFT", left, 0)
		seg:SetWidth(math.max(right - left, 0.1))
	end

	local lastX = -math.huge
	for i, label in ipairs(bar.labels) do
		local x = X(t[i])
		label:SetText(t[i])
		label:ClearAllPoints()
		label:SetPoint("TOP", bar, "TOPLEFT", x, -height - 4)
		label:SetShown(x - lastX >= MIN_LABEL_GAP)
		if label:IsShown() then
			lastX = x
		end
	end
	bar.labels[1]:ClearAllPoints()
	bar.labels[1]:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -height - 4)

	local mx = X(skill)
	bar.marker:SetPoint("CENTER", bar, "TOPLEFT", mx, -height / 2)
	bar.you:SetText("You: " .. skill)
	bar.you:ClearAllPoints()
	bar.you:SetPoint("TOP", bar, "TOPLEFT", math.min(math.max(mx, 24), BAR_WIDTH - 24), -height - 16)
	return bar
end

function ns.ShowRecipeTooltip(_, row, data)
	if not ns.db.showTooltip or not data.recipeInfo then
		return
	end
	local recipeInfo = Professions.GetHighestLearnedRecipe(data.recipeInfo) or data.recipeInfo
	local ctx = ns.SkillContext()
	local d = ns.Describe(recipeInfo, ctx)

	local tooltip = GameTooltip
	tooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip_SetTitle(tooltip, recipeInfo.name)
	local t = d.thresholds
	if t then
		local reqColor = ctx.skill < t[1] and RED_FONT_COLOR or HIGHLIGHT_FONT_COLOR
		GameTooltip_AddColoredLine(tooltip, string.format("Requires %s (%d)", ctx.name or "", t[1]), reqColor)
		GameTooltip_InsertFrame(tooltip, LayoutBar(t, ctx.skill), 4)
		if d.chance then
			GameTooltip_AddColoredLine(
				tooltip,
				string.format("Skill-up chance: %d%%", math.floor(d.chance * 100 + 0.5)),
				ns.COLORS[d.color]
			)
		end
	else
		GameTooltip_AddDisabledLine(tooltip, "No skill data for this recipe yet.")
	end
	tooltip:Show()
end
