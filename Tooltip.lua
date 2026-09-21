local _, ns = ...

local BAR_WIDTH = 250
local MIN_LABEL_GAP = 18
local BAR_HEIGHT = 12
-- The fill texture Blizzard's rank bars use; tinted per difficulty band.
local BAND_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
-- Forever's rested-XP pip, 10x14 native.
local MARKER_ATLAS = "ui-hud-experiencebar-frame-pip-camelot"
local MARKER_HEIGHT = BAR_HEIGHT * 1.3

local bar

-- The profession window's header skill bar (ProfessionsRankBarTemplate art),
-- scaled from its native 18px height down to tooltip size.
local function CreateBar()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(BAR_WIDTH, BAR_HEIGHT + 30)

	local track = CreateFrame("Frame", nil, frame)
	track:SetPoint("TOPLEFT")
	track:SetSize(BAR_WIDTH, BAR_HEIGHT)
	frame.track = track

	local scale = BAR_HEIGHT / 18
	local bg = track:CreateTexture(nil, "BACKGROUND")
	bg:SetAtlas("Professions-skillbar-bg")
	bg:SetPoint("TOPLEFT", -5 * scale, 3 * scale)
	bg:SetSize(BAR_WIDTH + 12 * scale, 29 * scale)
	local border = track:CreateTexture(nil, "OVERLAY")
	border:SetAtlas("Professions-skillbar-frame")
	border:SetPoint("TOPLEFT", -5 * scale, 3 * scale)
	border:SetSize(BAR_WIDTH + 10 * scale, 29 * scale)

	frame.segments = {}
	for i, color in ipairs({ "orange", "yellow", "green", "grey" }) do
		local seg = track:CreateTexture(nil, "ARTWORK", nil, 1)
		seg:SetTexture(BAND_TEXTURE)
		seg:SetVertexColor(ns.COLORS[color]:GetRGB())
		seg:SetHeight(BAR_HEIGHT)
		frame.segments[i] = seg
	end

	frame.labels = {}
	for i = 1, 4 do
		frame.labels[i] = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	end

	frame.marker = track:CreateTexture(nil, "OVERLAY", nil, 7)
	frame.marker:SetAtlas(MARKER_ATLAS)
	frame.marker:SetSize(MARKER_HEIGHT * 10 / 14, MARKER_HEIGHT)

	frame.you = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	return frame
end

-- Lays the four colour bands out over [orange, grey + tail]; the tail keeps the
-- grey band visible and gives the marker somewhere to sit once a recipe is grey.
local function LayoutBar(t, skill)
	bar = bar or CreateBar()
	local height = BAR_HEIGHT
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

local function Money(copper)
	return C_CurrencyInfo.GetCoinTextureString(math.floor(copper + 0.5))
end

local function SourceText(price)
	if price.source == "vendor" then
		return "vendor"
	elseif price.source == "auctionator" then
		return "Auctionator"
	end
	local minutes = math.floor((time() - price.time) / 60)
	if minutes < 60 then
		return "AH, " .. minutes .. "m ago"
	elseif minutes < 48 * 60 then
		return "AH, " .. math.floor(minutes / 60) .. "h ago"
	end
	return "AH, " .. math.floor(minutes / 1440) .. "d ago"
end

-- One line per reagent with its price and source, then the craft and per-skill-up totals.
local function AddCost(tooltip, recipeID, d)
	local reagents = ns.Reagents(recipeID)
	if not reagents or #reagents == 0 then
		return
	end
	GameTooltip_AddBlankLineToTooltip(tooltip)
	for _, reagent in ipairs(reagents) do
		local name = C_Item.GetItemNameByID(reagent.itemID) or ("item " .. reagent.itemID)
		local left = reagent.quantity > 1 and string.format("%s x%d", name, reagent.quantity) or name
		local price = ns.Price(reagent.itemID)
		if price then
			tooltip:AddDoubleLine(
				left,
				string.format("%s |cff808080(%s)|r", Money(price.copper * reagent.quantity), SourceText(price)),
				1,
				1,
				1,
				1,
				1,
				1
			)
		else
			tooltip:AddDoubleLine(left, "no price", 1, 1, 1, 0.5, 0.5, 0.5)
		end
	end
	if d.cost then
		tooltip:AddDoubleLine("Cost per craft", Money(d.cost), 1, 0.82, 0, 1, 1, 1)
	else
		GameTooltip_AddDisabledLine(tooltip, "Visit the auction house or a vendor to price reagents.")
	end
	if d.perSkillUp then
		tooltip:AddDoubleLine("Per skill-up", "~" .. Money(d.perSkillUp), 1, 0.82, 0, 1, 1, 1)
	end
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
	if ns.db.showCost then
		AddCost(tooltip, recipeInfo.recipeID, d)
	end
	tooltip:Show()
end
