---@type string, SkillUpNamespace
local _, ns = ...

local BAR_WIDTH = 250
local MIN_LABEL_GAP = 18
local BAR_HEIGHT = 12
-- The fill texture Blizzard's rank bars use; tinted per difficulty band.
local BAND_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
-- Forever's rested-XP pip, 10x14 native.
local MARKER_ATLAS = "ui-hud-experiencebar-frame-pip-camelot"
local MARKER_HEIGHT = BAR_HEIGHT * 1.3

---@type SkillUpBar
local bar

-- The profession window's header skill bar (ProfessionsRankBarTemplate art),
-- scaled from its native 18px height down to tooltip size.
local function CreateBar()
	local frame = CreateFrame("Frame", nil, UIParent) --[[@as SkillUpBar]]
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
---@param t number[]
---@param skill number
---@return SkillUpBar
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
		label:SetText(tostring(t[i]))
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

---@param copper number
---@return string
local function Money(copper)
	return C_CurrencyInfo.GetCoinTextureString(math.floor(copper + 0.5))
end

-- A profit reads as a green "+"; a cost is just the coins.
---@param copper number
---@param profit boolean
---@return string
function ns.FormatNet(copper, profit)
	return (profit and "|cff40ff40+|r" or "") .. Money(copper)
end

---@param timestamp number
---@return string
function ns.FormatAge(timestamp)
	local minutes = math.floor((time() - timestamp) / 60)
	if minutes < 60 then
		return minutes .. "m ago"
	elseif minutes < 48 * 60 then
		return math.floor(minutes / 60) .. "h ago"
	end
	return math.floor(minutes / 1440) .. "d ago"
end

local DAY = 86400

-- Seconds since an auction price was seen. Auctionator reports whole days, and
-- nothing past three weeks.
---@param price SkillUpPrice
---@return number
function ns.PriceAge(price)
	if price.source == "scan" then
		return time() - price.time
	elseif price.source == "auctionator" then
		return (price.days or 22) * DAY
	end
	error("not an auction price: " .. tostring(price.source))
end

---@param price SkillUpPrice
---@return string
function ns.PriceAgeText(price)
	if price.source == "scan" then
		return ns.FormatAge(price.time)
	elseif price.source ~= "auctionator" then
		error("not an auction price: " .. tostring(price.source))
	elseif price.days == nil then
		return "over 3 weeks ago"
	elseif price.days == 0 then
		return "today"
	end
	return price.days .. "d ago"
end

---@param price SkillUpPrice
---@return string
function ns.PriceSourceText(price)
	if price.source == "gather" then
		return "you gather it (" .. price.profession .. ")"
	elseif price.source == "vendor" then
		return "vendor"
	elseif price.source == "auctionator" then
		return "Auctionator, " .. ns.PriceAgeText(price)
	elseif price.source == "scan" then
		return "AH, " .. ns.PriceAgeText(price)
	end
	error("unknown price source: " .. tostring(price.source))
end

-- One line per reagent with its price and source, then the craft and per-skill-up totals.
---@param tooltip GameTooltip
---@param recipeID integer
---@param d SkillUpDescription
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
				string.format("%s |cff808080(%s)|r", Money(price.copper * reagent.quantity), ns.PriceSourceText(price)),
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
	if not d.cost then
		GameTooltip_AddDisabledLine(tooltip, "Visit the auction house or a vendor to price reagents.")
		return
	end
	tooltip:AddDoubleLine("Reagents", Money(d.cost), 1, 0.82, 0, 1, 1, 1)
	local net = d.net
	if d.value and net then
		local each = d.value.quantity ~= 1 and string.format(" x%g", d.value.quantity) or ""
		tooltip:AddDoubleLine(
			"Sells for" .. each,
			string.format(
				"%s |cff808080(%s)|r",
				Money(d.value.copper),
				d.value.source == "auction" and "AH" or "vendor"
			),
			1,
			0.82,
			0,
			1,
			1,
			1
		)
		tooltip:AddDoubleLine(
			net < 0 and "Profit per craft" or "Net per craft",
			Money(math.abs(net)),
			1,
			0.82,
			0,
			1,
			1,
			1
		)
	end
	local perSkillUp = d.perSkillUp
	if perSkillUp then
		local label = perSkillUp < 0 and "Profit per skill-up" or "Per skill-up"
		tooltip:AddDoubleLine(label, ns.FormatNet(math.abs(perSkillUp), perSkillUp < 0), 1, 0.82, 0, 1, 1, 1)
	end
end

---@param _ SkillUpNamespace
---@param row SkillUpRecipeRow
---@param data SkillUpRecipeNodeData
function ns.ShowRecipeTooltip(_, row, data)
	local info = data.recipeInfo
	if not ns.db.showTooltip or not info then
		return
	end
	local recipeInfo = Professions.GetHighestLearnedRecipe(info) or info
	local ctx = ns.SkillContext()
	local d = ns.Describe(recipeInfo, ctx)

	local tooltip = GameTooltip
	tooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip_SetTitle(tooltip, recipeInfo.name)
	local t = d.thresholds
	if t and ctx then
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

local MAX_USES = 5
local BAND_NAMES = { "orange", "yellow", "green" }

-- "yellow until 115": the band the recipe is in now and where it ends.
---@param t number[]
---@param skill number
---@return string
---@return ColorMixin
local function Band(t, skill)
	if skill < t[1] then
		return string.format("needs %d", t[1]), ns.COLORS.red
	end
	for i, band in ipairs(BAND_NAMES) do
		if skill < t[i + 1] then
			return string.format("%s until %d", band, t[i + 1]), ns.COLORS[band]
		end
	end
	return "grey", ns.COLORS.grey
end

-- Recipes of your professions that still skill up and use this item: learned
-- ones first, then by the skill they need.
---@param itemID integer
---@return SkillUpUse[]
local function Uses(itemID)
	local professions = ns.PlayerProfessions()
	local uses = {}
	for _, recipeID in ipairs(ns.UsedIn(itemID)) do
		local profession = professions[ns.RecipeData[recipeID].skillLine]
		local t = profession and ns.Model.Get(recipeID)
		if t and profession.skill < t[4] then
			uses[#uses + 1] = { recipeID = recipeID, t = t, skill = profession.skill, learned = ns.IsLearned(recipeID) }
		end
	end
	table.sort(uses, function(a, b)
		if a.learned ~= b.learned then
			return a.learned
		end
		if a.t[1] ~= b.t[1] then
			return a.t[1] < b.t[1]
		end
		return a.recipeID < b.recipeID
	end)
	return uses
end

-- "Route: 28/567 · Leatherworking to 150" for each tracked route that needs the item.
---@param tooltip GameTooltip
---@param itemID integer
---@return boolean
local function AddRouteNeeds(tooltip, itemID)
	local added = false
	for _, entry in ipairs(ns.TrackedNeeds()) do
		for _, item in ipairs(entry.items) do
			if item.itemID == itemID then
				if not added then
					GameTooltip_AddBlankLineToTooltip(tooltip)
					added = true
				end
				local have = ns.Have(itemID)
				local text = string.format(
					"Route: %d/%d · %s to %d",
					math.min(have, item.need),
					item.need,
					entry.route.profession,
					entry.route.target
				)
				GameTooltip_AddColoredLine(tooltip, text, have >= item.need and ns.COLORS.green or NORMAL_FONT_COLOR)
			end
		end
	end
	return added
end

---@param tooltip GameTooltip
---@param uses SkillUpUse[]
local function AddUsedIn(tooltip, uses)
	GameTooltip_AddBlankLineToTooltip(tooltip)
	GameTooltip_AddNormalLine(tooltip, "Used in")
	for i, use in ipairs(uses) do
		if i > MAX_USES then
			GameTooltip_AddDisabledLine(tooltip, string.format("+%d more", #uses - MAX_USES))
			break
		end
		local band, color = Band(use.t, use.skill)
		local name = C_Spell.GetSpellName(use.recipeID) or ("recipe " .. use.recipeID)
		local r, g, b = color:GetRGB()
		tooltip:AddDoubleLine(use.learned and name or name .. " (unlearned)", band, 1, 1, 1, r, g, b)
	end
end

---@param tooltip GameTooltip
---@param data TooltipData
local function AddUses(tooltip, data)
	local itemID = data and data.id
	local mode = ns.db.reagentTooltip
	if mode == "off" or not itemID or tooltip:IsForbidden() then
		return
	end
	if issecretvalue and issecretvalue(itemID) then
		return
	end
	local uses = Uses(itemID)
	if mode == "route" then
		local needed = AddRouteNeeds(tooltip, itemID)
		if IsShiftKeyDown() and #uses > 0 then
			AddUsedIn(tooltip, uses)
		elseif needed and #uses > 0 then
			GameTooltip_AddDisabledLine(tooltip, string.format("Shift: used in %d of your recipes", #uses))
		end
	elseif mode == "full" then
		AddRouteNeeds(tooltip, itemID)
		if #uses > 0 then
			AddUsedIn(tooltip, uses)
		end
	else
		error("unknown reagent tooltip mode: " .. tostring(mode))
	end
end

-- Shift changes what an item tooltip shows, so redraw the one on screen.
---@param key string
local function OnModifierChanged(_, _, key)
	if (key == "LSHIFT" or key == "RSHIFT") and ns.db.reagentTooltip == "route" and GameTooltip:IsShown() then
		local _, _, itemID = GameTooltip:GetItem()
		if itemID and GameTooltip.RefreshData then
			GameTooltip:RefreshData()
		end
	end
end

function ns.AttachItemTooltips()
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddUses)
	local events = CreateFrame("Frame")
	events:RegisterEvent("MODIFIER_STATE_CHANGED")
	events:SetScript("OnEvent", OnModifierChanged)
end
