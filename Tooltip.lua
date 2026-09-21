local _, ns = ...

local BAR_WIDTH, BAR_HEIGHT = 250, 14
local MIN_LABEL_GAP = 18
-- The fill Blizzard's own profession rank bars use (ProfessionsStatusBarArtTemplate).
local BAR_TEXTURE = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar"

local bar

-- Built on Blizzard's profession rank bar template so the border and fill match
-- the category bars in the recipe list; the template's own fill is emptied and
-- the four colour bands are drawn with the same texture, tinted.
local function CreateBar()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(BAR_WIDTH, BAR_HEIGHT + 30)

	local status = CreateFrame("StatusBar", nil, frame, "ProfessionsStatusBarArtTemplate")
	status:SetPoint("TOPLEFT")
	status:SetSize(BAR_WIDTH, BAR_HEIGHT)
	status:SetValue(0)
	frame.status = status

	local background = status:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0, 0, 0, 0.6)

	frame.segments = {}
	for i, color in ipairs({ "orange", "yellow", "green", "grey" }) do
		local seg = status:CreateTexture(nil, "ARTWORK", nil, 1)
		seg:SetTexture(BAR_TEXTURE)
		seg:SetVertexColor(ns.COLORS[color]:GetRGB())
		seg:SetHeight(BAR_HEIGHT)
		frame.segments[i] = seg
	end

	frame.labels = {}
	for i = 1, 4 do
		frame.labels[i] = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	end

	frame.marker = status:CreateTexture(nil, "OVERLAY", nil, 2)
	frame.marker:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	frame.marker:SetBlendMode("ADD")
	frame.marker:SetSize(16, BAR_HEIGHT * 2.2)

	frame.you = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	return frame
end

-- Lays the four colour bands out over [orange, grey + tail]; the tail keeps the
-- grey band visible and gives the marker somewhere to sit once a recipe is grey.
local function LayoutBar(t, skill)
	bar = bar or CreateBar()
	local lo = t[1]
	local hi = t[4] + math.max(3, math.floor((t[4] - t[1]) * 0.12 + 0.5))
	local function X(value)
		return (math.min(math.max(value, lo), hi) - lo) / (hi - lo) * BAR_WIDTH
	end

	local edges = { t[1], t[2], t[3], t[4], hi }
	for i, seg in ipairs(bar.segments) do
		local left, right = X(edges[i]), X(edges[i + 1])
		seg:SetShown(right > left)
		seg:SetPoint("TOPLEFT", bar.status, "TOPLEFT", left, 0)
		seg:SetWidth(math.max(right - left, 0.1))
	end

	local lastX = -math.huge
	for i, label in ipairs(bar.labels) do
		local x = X(t[i])
		label:SetText(t[i])
		label:ClearAllPoints()
		label:SetPoint("TOP", bar, "TOPLEFT", x, -BAR_HEIGHT - 4)
		label:SetShown(x - lastX >= MIN_LABEL_GAP)
		if label:IsShown() then
			lastX = x
		end
	end
	bar.labels[1]:ClearAllPoints()
	bar.labels[1]:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -BAR_HEIGHT - 4)

	local mx = X(skill)
	bar.marker:SetPoint("CENTER", bar, "TOPLEFT", mx, -BAR_HEIGHT / 2)
	bar.you:SetText("You: " .. skill)
	bar.you:ClearAllPoints()
	bar.you:SetPoint("TOP", bar, "TOPLEFT", math.min(math.max(mx, 24), BAR_WIDTH - 24), -BAR_HEIGHT - 16)
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
