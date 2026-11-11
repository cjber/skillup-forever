---@type string, SkillUpNamespace
local _, ns = ...

if ns.broken then
	return
end
local L = ns.L

local BAR_WIDTH = 250
local MIN_LABEL_GAP = 18
-- ProfessionsRankBarTemplate's art is 451 by 29, with a fill 439 by 18 inside it. The band fill is 10 high
-- native, so the art is scaled by 10/18 to about 250.6 wide and the bands run across the fill's 439 * 10/18.
local BAR_SCALE = 10 / 18
local BAR_HEIGHT = 18 * BAR_SCALE
local BAR_FILL_WIDTH = 439 * BAR_SCALE
-- The client's cooldown manager fill, 124 by 10 native: it stays 10 high and only its width varies, so the
-- bands do too. Tinted per difficulty band.
local BAND_ATLAS = "UI-HUD-CoolDownManager-Bar"
-- Forever's rested-XP pip, taller than it is wide.
local MARKER_ATLAS = "ui-hud-experiencebar-frame-pip-camelot"
local MARKER_HEIGHT = BAR_HEIGHT * 1.3
-- The bar frame's height, its gap below the line above, and the blank lines that make room for both:
-- GameTooltipText is 12 high with 2 between lines, as GameTooltip_InsertFrame counts them.
local BAR_FRAME_HEIGHT = BAR_HEIGHT + 30
local BAR_PADDING = 4
local BAR_LINES = math.ceil(math.floor(BAR_FRAME_HEIGHT + BAR_PADDING + 0.5) / (12 + 2))

-- The profession window's header skill bar (ProfessionsRankBarTemplate art), scaled down to tooltip size at its
-- own aspect. The tooltip and the crafting page's details pane each ask ns.LayoutSkillBar for one of these.
---@return SkillUpBar
function ns.CreateSkillBar()
	local frame = CreateFrame("Frame", nil, UIParent) --[[@as SkillUpBar]]
	frame:SetSize(BAR_WIDTH, BAR_FRAME_HEIGHT)

	local track = CreateFrame("Frame", nil, frame)
	track:SetPoint("TOPLEFT")
	track:SetSize(BAR_WIDTH, BAR_HEIGHT)
	frame.track = track

	local bg = track:CreateTexture(nil, "BACKGROUND")
	ns.Art.Fit(bg, "Professions-skillbar-bg", 451 * BAR_SCALE, 29 * BAR_SCALE)
	bg:SetPoint("TOPLEFT", -5 * BAR_SCALE, 3 * BAR_SCALE)
	local border = track:CreateTexture(nil, "OVERLAY")
	ns.Art.Fit(border, "Professions-skillbar-frame", 451 * BAR_SCALE, 29 * BAR_SCALE)
	border:SetPoint("TOPLEFT", -5 * BAR_SCALE, 3 * BAR_SCALE)

	frame.segments = {}
	for i, color in ipairs({ "orange", "yellow", "green", "grey" }) do
		local seg = track:CreateTexture(nil, "ARTWORK", nil, 1)
		seg:SetAtlas(BAND_ATLAS) -- art-ok: a bar fill, at its native 10 high; only its width follows the band
		seg:SetVertexColor(ns.COLORS[color]:GetRGB())
		seg:SetHeight(BAR_HEIGHT)
		frame.segments[i] = seg
	end

	frame.labels = {}
	for i = 1, 4 do
		frame.labels[i] = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	end

	frame.marker = track:CreateTexture(nil, "OVERLAY", nil, 7)
	ns.Art.Fit(frame.marker, MARKER_ATLAS, MARKER_HEIGHT, MARKER_HEIGHT)

	frame.you = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame:Hide()
	return frame
end

-- Lays the four colour bands out over [orange, grey + tail]; the tail keeps the
-- grey band visible and gives the marker somewhere to sit once a recipe is grey.
---@param bar SkillUpBar a frame ns.CreateSkillBar made
---@param t number[]
---@param skill number
---@return SkillUpBar
function ns.LayoutSkillBar(bar, t, skill)
	local height = BAR_HEIGHT
	local lo = t[1]
	local hi = t[4] + math.max(3, math.floor((t[4] - t[1]) * 0.12 + 0.5))
	local function X(value)
		return (math.min(math.max(value, lo), hi) - lo) / (hi - lo) * BAR_FILL_WIDTH
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
	bar.you:SetText(string.format(L["You: %d"], skill))
	bar.you:ClearAllPoints()
	bar.you:SetPoint("TOP", bar, "TOPLEFT", math.min(math.max(mx, 24), BAR_WIDTH - 24), -height - 16)
	return bar
end

-- The one bar a tooltip has, made the first time it needs it and kept afterwards.
---@type SkillUpBar?
local bar

-- The tooltips whose clearing has been hooked, so the bar hides and the lines kept for a tooltip are dropped.
---@type table<GameTooltip, true>
local hooked = {}

-- What each tooltip last drew, so the client asking for the same item on the same tooltip again is only a
-- lookup. The client clears a tooltip before it sets it again, and that clear drops this.
---@class SkillUpTooltipDrawn
---@field itemID integer
---@field mode string
---@field shifted boolean
---@field lines SkillUpTooltipLine[]
---@field index table<integer, { entry: SkillUpTracked, item: SkillUpNeededItem }[]>
---@field bags integer

---@type table<GameTooltip, SkillUpTooltipDrawn>
local drawn = {}

-- Moved on every bag change: a route line reads the bags' count when it is drawn, so a count can only move
-- with one of these.
local bags = 0

-- Cleared for anything else, the tooltip no longer has the bar's blank lines or the lines kept for it.
---@param tooltip GameTooltip
local function Cleared(tooltip)
	if not ns.Usable(tooltip) then
		return
	end
	drawn[tooltip] = nil
	if bar then
		bar:Hide()
	end
end

---@param tooltip GameTooltip
local function HookCleared(tooltip)
	if hooked[tooltip] then
		return
	end
	hooked[tooltip] = true
	if type(tooltip.HookScript) == "function" then
		tooltip:HookScript("OnTooltipCleared", Cleared)
	end
end

-- Puts the bar into the tooltip below line `after`. Blizzard's GameTooltip_InsertFrame measures the tooltip to
-- do this, and from our recipe-list handler those measurements are secret, so its arithmetic errored and the
-- error was blamed on SkillUp (#161). Here nothing reads the tooltip: the blank lines are our own, counted from
-- constants, and the bar hangs from the first of them, a line whose number we know.
---@param tooltip GameTooltip
---@param after integer the lines the tooltip has so far
---@param t number[]
---@param skill number
local function AddBar(tooltip, after, t, skill)
	bar = bar or ns.CreateSkillBar()
	local frame = ns.LayoutSkillBar(bar, t, skill)
	for _ = 1, BAR_LINES do
		GameTooltip_AddBlankLineToTooltip(tooltip)
	end
	frame:SetParent(tooltip)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", _G[tooltip:GetName() .. "TextLeft" .. (after + 1)], "TOPLEFT", 0, -BAR_PADDING)
	tooltip:SetMinimumWidth(BAR_WIDTH)
	frame:Show()
	HookCleared(tooltip)
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

-- A recipe's own money, on its row and tooltip: a profit leads with a green "+", a cost with a red "-"
-- (RED_FONT_COLOR's ff2020).
---@param copper number
---@param profit boolean
---@return string
function ns.FormatSigned(copper, profit)
	return (profit and "|cff40ff40+|r" or "|cffff2020-|r") .. Money(copper)
end

local DAY = 86400

-- Seconds since an auction price was seen. Auctionator reports whole days, and
-- nothing past three weeks.
---@param price SkillUpPrice
---@return number?
function ns.PriceAge(price)
	if price.source ~= "auctionator" then
		error("not an auction price: " .. tostring(price.source))
	end
	return not price.ageUnavailable and (price.days or 22) * DAY or nil
end

---@param price SkillUpPrice
---@return string
function ns.PriceAgeText(price)
	if price.source ~= "auctionator" then
		error("not an auction price: " .. tostring(price.source))
	elseif price.ageUnavailable then
		return L["unknown age"]
	elseif price.days == nil then
		return L["over 3 weeks ago"]
	elseif price.days == 0 then
		return L["today"]
	end
	return string.format(L["%dd ago"], price.days)
end

-- What to do about a reagent with no price: auction prices come only from Auctionator or TradeSkillMaster.
---@return string
function ns.UnpricedHint()
	if ns.HasAuctionator() then
		return L["Scan the auction house with Auctionator, or visit a vendor, to price reagents."]
	elseif ns.HasTradeSkillMaster() then
		return L["Update TradeSkillMaster's AuctionDB with the TSM desktop app, or visit a vendor, to price reagents."]
	end
	return L["Visit a vendor to price reagents. Auction prices need Auctionator or TradeSkillMaster."]
end

---@param price SkillUpPrice
---@return string
function ns.PriceSourceText(price)
	if price.loot and price.worth == "auction" then
		return L["you loot it from creatures, valued at its AH price"]
	elseif price.loot and price.worth == "vendor" then
		return L["you loot it from creatures, valued at its vendor sell price"]
	elseif price.loot then
		return L["you loot it from creatures"]
	elseif price.worth == "auction" then
		return string.format(L["you gather it (%s), valued at its AH price"], price.profession)
	elseif price.worth == "vendor" then
		return string.format(L["you gather it (%s), valued at its vendor sell price"], price.profession)
	elseif price.source == "gather" then
		return string.format(L["you gather it (%s)"], price.profession)
	elseif price.source == "vendor" then
		return L["vendor"]
	elseif price.source == "auctionator" then
		return string.format(L["Auctionator, %s"], ns.PriceAgeText(price))
	elseif price.source == "tsm" then
		return L["TradeSkillMaster"]
	elseif price.source == "auction" then
		return L["price unknown"]
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
		local name = C_Item.GetItemNameByID(reagent.itemID) or string.format(L["item %d"], reagent.itemID)
		local left = reagent.quantity > 1 and string.format("%s x%d", name, reagent.quantity) or name
		local price = ns.Price(reagent.itemID)
		-- The line and the Reagents total below must price a reagent the same way: the total counts what it
		-- costs to obtain, cheaper to craft where a known recipe beats buying it, so the line does too (#360).
		-- An unknown auction price costs nothing in the plan but is still no number to show.
		local each = price and not price.unknown and (ns.ObtainCost and ns.ObtainCost(reagent.itemID) or price.copper)
			or nil
		local maker = each and price and each < price.copper and ns.SubCraft and ns.SubCraft(reagent.itemID)
		if each then
			local source = maker and L["crafted"] or (price and ns.PriceSourceText(price) or L["crafted"])
			tooltip:AddDoubleLine(
				left,
				string.format("%s |cff808080(%s)|r", Money(each * reagent.quantity), source),
				1,
				1,
				1,
				1,
				1,
				1
			)
		else
			tooltip:AddDoubleLine(left, L["no price"], 1, 1, 1, 0.5, 0.5, 0.5)
		end
	end
	if not d.cost then
		GameTooltip_AddDisabledLine(tooltip, ns.UnpricedHint())
		return
	end
	tooltip:AddDoubleLine(L["Reagents"], Money(d.cost), 1, 0.82, 0, 1, 1, 1)
	local net = d.net
	if d.value and net then
		local sells = d.value.quantity ~= 1 and string.format(L["Sells for x%g"], d.value.quantity) or L["Sells for"]
		tooltip:AddDoubleLine(
			sells,
			string.format(
				"%s |cff808080(%s)|r",
				Money(d.value.copper),
				d.value.source == "auction" and L["AH"] or L["vendor"]
			),
			1,
			0.82,
			0,
			1,
			1,
			1
		)
		-- A loss carries the same red minus the per-skill-up line below uses, so the two rows read alike (#360).
		tooltip:AddDoubleLine(
			net < 0 and L["Profit per craft"] or L["Net per craft"],
			ns.FormatSigned(math.abs(net), net < 0),
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
		local label = perSkillUp < 0 and L["Profit per skill-up"] or L["Per skill-up"]
		tooltip:AddDoubleLine(label, ns.FormatSigned(math.abs(perSkillUp), perSkillUp < 0), 1, 0.82, 0, 1, 1, 1)
	end
end

-- What a buff recipe's tooltip says about the buff and its reagents: the buff in the game's own words, then the
-- nearest zone each reagent drops in, with Questie (#357).
---@param recipeID integer
---@return { text: string, color: ColorMixin }[]
local function BuffLines(recipeID)
	local lines = {}
	if ns.BuffLevel(recipeID) == nil then
		return lines
	end
	local recipe = ns.RecipeData[recipeID]
	local output = recipe and recipe.output
	local buff = output and output.itemID and ns.BuffText(output.itemID)
	if buff then
		lines[#lines + 1] = { text = buff, color = GREEN_FONT_COLOR }
	end
	for _, reagent in ipairs(ns.Reagents(recipeID) or {}) do
		local zone = ns.DropZone(reagent.itemID)
		if zone then
			local name = C_Item.GetItemNameByID(reagent.itemID) or string.format(L["item %d"], reagent.itemID)
			lines[#lines + 1] = { text = string.format(L["%s drops in %s"], name, zone), color = GRAY_FONT_COLOR }
		end
	end
	return lines
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
	-- Where an unlearned recipe is learned: the added row already carries the bundle's source, and one the
	-- client itself lists unlearned reads the same trainer and scroll tables, so a hover never walks the
	-- profession's recipes or rebuilds the route.
	---@type SkillUpLearnSource|SkillUpUnlearnedRecipe|nil
	local learn = recipeInfo.skillUpUnlearned
	if not learn and recipeInfo.learned == false and ctx then
		learn = ns.LearnSource(ctx, recipeInfo.recipeID)
	end

	local tooltip = GameTooltip
	local where = ns.db.recipeTooltip
	if where == "cursor" then
		tooltip:SetOwner(row, "ANCHOR_CURSOR")
	elseif where == "row" then
		tooltip:SetOwner(row, "ANCHOR_RIGHT")
	else
		-- Beside the window, past the side tabs on its right edge and level with the first: by the row, the
		-- tooltip covered the reagents (#163).
		tooltip:SetOwner(row, "ANCHOR_NONE")
		tooltip:SetPoint("TOPLEFT", ProfessionsFrame.ProfessionsOverviewTab or ProfessionsFrame, "TOPRIGHT", 4, 0)
	end
	GameTooltip_SetTitle(tooltip, recipeInfo.name)
	local t = d.thresholds
	if t and ctx then
		local reqColor = ctx.skill < t[1] and RED_FONT_COLOR or HIGHLIGHT_FONT_COLOR
		GameTooltip_AddColoredLine(tooltip, string.format(L["Skill range starts at %d"], t[1]), reqColor)
		-- The title and the line above: SetOwner cleared the tooltip.
		AddBar(tooltip, 2, t, ctx.skill)
		if d.chance then
			GameTooltip_AddColoredLine(
				tooltip,
				string.format(L["Skill-up chance: %d%%"], math.floor(d.chance * 100 + 0.5)),
				ns.COLORS[d.color]
			)
		end
	else
		GameTooltip_AddDisabledLine(tooltip, L["No skill data for this recipe yet."])
	end
	if learn then
		GameTooltip_AddDisabledLine(tooltip, string.format(L["Not learned · %s"], ns.LearnSourceText(learn)))
	end
	for _, buff in ipairs(BuffLines(recipeInfo.recipeID)) do
		GameTooltip_AddColoredLine(tooltip, buff.text, buff.color)
	end
	if ns.db.showCost then
		AddCost(tooltip, recipeInfo.recipeID, d)
	end
	tooltip:Show()
end

local MAX_USES = 5
local BAND_LABELS = { orange = L["orange"], yellow = L["yellow"], green = L["green"] }
-- The threshold each band ends at.
local BAND_END = { orange = 2, yellow = 3, green = 4 }

-- One line to draw later: what it is and everything it needs, so a cached answer costs only the drawing.
---@class SkillUpTooltipLine
---@field kind "blank"|"double"|"disabled"|"normal"|"route"|"shiftHint"
---@field text? string
---@field right? string
---@field r? number
---@field g? number
---@field b? number
---@field itemID? integer
---@field count? integer

---@return SkillUpTooltipLine
local function BlankLine()
	return { kind = "blank" }
end

---@param text string
---@return SkillUpTooltipLine
local function NormalLine(text)
	return { kind = "normal", text = text }
end

---@param text string
---@return SkillUpTooltipLine
local function DisabledLine(text)
	return { kind = "disabled", text = text }
end

---@param left string
---@param right string
---@param color ColorMixin
---@return SkillUpTooltipLine
local function DoubleLine(left, right, color)
	local r, g, b = color:GetRGB()
	return { kind = "double", text = left, right = right, r = r, g = g, b = b }
end

---@param itemID integer
---@return SkillUpTooltipLine
local function RouteLine(itemID)
	return { kind = "route", itemID = itemID }
end

---@param count integer
---@return SkillUpTooltipLine
local function ShiftHintLine(count)
	return { kind = "shiftHint", count = count }
end

-- Route lines are drawn from the tracked routes and the bags as they are now: declared before Draw, built
-- below from the route index.
local DrawRouteNeeds

---@param tooltip GameTooltip
---@param lines SkillUpTooltipLine[]
local function Draw(tooltip, lines)
	local anyDrawn = false
	for _, line in ipairs(lines) do
		if line.kind == "route" then
			local itemID = line.itemID
			if itemID then
				anyDrawn = DrawRouteNeeds(tooltip, itemID) or anyDrawn
			end
		elseif line.kind == "shiftHint" then
			local count = line.count
			if anyDrawn and count then
				GameTooltip_AddDisabledLine(tooltip, string.format(L["Shift: used in %d of your recipes"], count))
			end
		elseif line.kind == "blank" then
			GameTooltip_AddBlankLineToTooltip(tooltip)
			anyDrawn = true
		elseif line.kind == "double" then
			tooltip:AddDoubleLine(line.text, line.right, 1, 1, 1, line.r, line.g, line.b)
			anyDrawn = true
		elseif line.kind == "disabled" then
			GameTooltip_AddDisabledLine(tooltip, line.text)
			anyDrawn = true
		elseif line.kind == "normal" then
			GameTooltip_AddNormalLine(tooltip, line.text)
			anyDrawn = true
		else
			error("unknown tooltip line: " .. tostring(line.kind))
		end
	end
end

-- "yellow until 115": the band the recipe is in now and where it ends.
---@param t number[]
---@param skill number
---@return string
---@return ColorMixin
local function Band(t, skill)
	local band = ns.Model.Color(t, skill)
	if band == "red" then
		return string.format(L["Skill range starts at %d"], t[1]), ns.COLORS.red
	elseif band == "grey" then
		return L["grey"], ns.COLORS.grey
	end
	return string.format(L["%s until %d"], BAND_LABELS[band], t[BAND_END[band]]), ns.COLORS[band]
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
		local t = profession and ns.RangeThresholds(profession, recipeID)
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

-- The tracked routes' items, by item: built once after a change, so a hover across many items matches its
-- own instead of rebuilding every tracked route's material list each time.
---@type table<integer, { entry: SkillUpTracked, item: SkillUpNeededItem }[]>?
local routeNeeds
---@type SkillUpTracked[]?
local routeNeedsSource
---@return table<integer, { entry: SkillUpTracked, item: SkillUpNeededItem }[]>
local function RouteNeedsIndex()
	local index = routeNeeds
	if index then
		return index
	end
	routeNeedsSource = ns.TrackedNeeds()
	index = {}
	for _, entry in ipairs(routeNeedsSource) do
		for _, item in ipairs(entry.items) do
			local rows = index[item.itemID]
			if not rows then
				rows = {}
				index[item.itemID] = rows
			end
			rows[#rows + 1] = { entry = entry, item = item }
		end
	end
	routeNeeds = index
	return index
end

-- The route lines an item draws, by the route index and bag count they were worked out from, so a tooltip
-- the client cleared re-adds them without reading the bags or formatting them again.
---@class SkillUpRouteText
---@field index table<integer, { entry: SkillUpTracked, item: SkillUpNeededItem }[]>
---@field bags integer
---@field lines { text: string, good: boolean }[]
---@type table<integer, SkillUpRouteText>
local routeTexts = {}

---@param itemID integer
---@return { text: string, good: boolean }[]
local function RouteTexts(itemID)
	local index = RouteNeedsIndex()
	local cached = routeTexts[itemID]
	if cached and cached.index == index and cached.bags == bags then
		return cached.lines
	end
	local lines = {}
	local rows = index[itemID]
	if rows then
		local have = ns.Have(itemID)
		for _, row in ipairs(rows) do
			local item = row.item
			lines[#lines + 1] = {
				text = string.format(
					L["Route: %d/%d · %s to %d"],
					math.min(have, item.need),
					item.need,
					row.entry.plan.profession.name,
					row.entry.plan.target
				),
				good = have >= item.need,
			}
		end
	end
	routeTexts[itemID] = { index = index, bags = bags, lines = lines }
	return lines
end

-- "Route: 28/567 · Leatherworking to 150" for each tracked route that needs the item, with the count the
-- bags hold now. The item's cached lines hold only the marker for these, so looting does not rebuild them.
---@param tooltip GameTooltip
---@param itemID integer
---@return boolean drawn
DrawRouteNeeds = function(tooltip, itemID)
	local lines = RouteTexts(itemID)
	if #lines == 0 then
		return false
	end
	GameTooltip_AddBlankLineToTooltip(tooltip)
	for _, line in ipairs(lines) do
		GameTooltip_AddColoredLine(tooltip, line.text, line.good and ns.COLORS.green or NORMAL_FONT_COLOR)
	end
	return true
end

-- Which profession and skill make a buff consumable, from the maker with the lowest skill range start, ties to the
-- lower recipe ID (#357).
---@param itemID integer
---@return SkillUpTooltipLine[]
local function MadeByLines(itemID)
	local lines = {}
	if not ns.BuffItems[itemID] then
		return lines
	end
	local best, bestSkill, first
	local professions = ns.PlayerProfessions()
	for _, recipeID in ipairs(ns.MakersOf(itemID)) do
		local recipe = ns.RecipeData[recipeID]
		local name = recipe and C_TradeSkillUI.GetTradeSkillDisplayName(recipe.skillLine)
		if name then
			first = first or { name = name }
			local profession = professions[recipe.skillLine] or { skillLine = recipe.skillLine, modifier = 0 }
			local t = ns.RangeThresholds(profession, recipeID)
			local skill = t and t[1]
			if skill and (not best or skill < bestSkill) then
				best, bestSkill = { name = name }, skill
			end
		end
	end
	local maker = best or first
	if not maker then
		return lines
	end
	lines[1] = BlankLine()
	lines[2] = NormalLine(
		best and string.format(L["Made by %s %d"], maker.name, bestSkill) or string.format(L["Made by %s"], maker.name)
	)
	return lines
end

---@param uses SkillUpUse[]
---@return SkillUpTooltipLine[]
local function UsedInLines(uses)
	local lines = { BlankLine(), NormalLine(L["Used in"]) }
	for i, use in ipairs(uses) do
		if i > MAX_USES then
			lines[#lines + 1] = DisabledLine(string.format(L["+%d more"], #uses - MAX_USES))
			break
		end
		local band, color = Band(use.t, use.skill)
		local name = C_Spell.GetSpellName(use.recipeID) or string.format(L["recipe %d"], use.recipeID)
		lines[#lines + 1] = DoubleLine(use.learned and name or string.format(L["%s (unlearned)"], name), band, color)
	end
	return lines
end

-- What an item's tooltip says, by item and by what changes it (the mode and Shift), so the client setting the
-- same tooltip again only draws it. Anything that can move a line drops the lot (Core/Changes.lua).
---@type table<integer, table<string, SkillUpTooltipLine[]>>
local itemLines = {}
-- A gathering line, by the skill line it is for and the skill it asks; nil is an unknown requirement.
---@type table<string, SkillUpTooltipLine[]>
local gatherLines = {}

local function ClearTooltipLines()
	itemLines, gatherLines = {}, {}
	drawn = {}
end
ns.WhenStale("tooltipCache", ClearTooltipLines)

-- The routes that need an item are indexed once per route change. A bag change only drops the index when the
-- tools the routes lack actually moved, so looting unrelated loot does not rebuild it.
local function DropRouteNeeds()
	routeNeeds, routeNeedsSource = nil, nil
	routeTexts = {}
end
ns.WhenStale("tooltipRoute", DropRouteNeeds)

local function ValidateRouteNeeds()
	bags = bags + 1
	routeTexts = {}
	if routeNeeds and ns.TrackedNeeds() ~= routeNeedsSource then
		DropRouteNeeds()
	end
end
ns.WhenStale("tooltipRouteTools", ValidateRouteNeeds)

---@param itemID integer
---@param mode string
---@param shifted boolean
---@return SkillUpTooltipLine[]
local function ItemLines(itemID, mode, shifted)
	local variants = itemLines[itemID]
	if not variants then
		variants = {}
		itemLines[itemID] = variants
	end
	local key = mode .. (shifted and ":shift" or "")
	local lines = variants[key]
	if lines then
		return lines
	end
	local uses = Uses(itemID)
	lines = {}
	for _, line in ipairs(MadeByLines(itemID)) do
		lines[#lines + 1] = line
	end
	-- Drawn from the route index and the bags when the tooltip is set, never baked into this item's cache.
	lines[#lines + 1] = RouteLine(itemID)
	if mode == "route" then
		if shifted and #uses > 0 then
			for _, line in ipairs(UsedInLines(uses)) do
				lines[#lines + 1] = line
			end
		elseif not shifted and #uses > 0 then
			lines[#lines + 1] = ShiftHintLine(#uses)
		end
	elseif #uses > 0 then
		for _, line in ipairs(UsedInLines(uses)) do
			lines[#lines + 1] = line
		end
	end
	variants[key] = lines
	return lines
end

---@param tooltip GameTooltip
---@param data TooltipData
local function AddUses(tooltip, data)
	if not ns.Usable(tooltip) then
		return
	end
	local itemID = data and data.id
	-- Checked before anything tests the id: even its truth test errors while it is secret.
	if issecretvalue and issecretvalue(itemID) then
		return
	end
	local mode = ns.db.reagentTooltip
	if mode == "off" or not itemID then
		return
	end
	if mode ~= "route" and mode ~= "full" then
		error("unknown reagent tooltip mode: " .. tostring(mode))
	end
	local shifted = mode == "route" and IsShiftKeyDown()
	local lines = ItemLines(itemID, mode, shifted)
	local index = RouteNeedsIndex()
	local last = drawn[tooltip]
	if
		last
		and last.itemID == itemID
		and last.mode == mode
		and last.shifted == shifted
		and last.lines == lines
		and last.index == index
		and last.bags == bags
	then
		return
	end
	HookCleared(tooltip)
	Draw(tooltip, lines)
	drawn[tooltip] = {
		itemID = itemID,
		mode = mode,
		shifted = shifted,
		lines = lines,
		index = index,
		bags = bags,
	}
end

-- Shift changes what an item tooltip shows, so redraw the one on screen.
---@param key string
local function OnModifierChanged(_, _, key)
	if (key == "LSHIFT" or key == "RSHIFT") and ns.db.reagentTooltip == "route" and GameTooltip:IsShown() then
		-- Read through ns.Readable first, as AddUses does: a secret id errors even on its truth test.
		local itemID = ns.Readable((select(3, GameTooltip:GetItem())))
		if itemID and GameTooltip.RefreshData then
			GameTooltip:RefreshData()
		end
	end
end

-- Gathering (#122): the skill a herb or ore node asks, found by the name on its tooltip, and a gatherable
-- corpse's. Both are coloured from your live skill with Classic's gathering bands (Model.GatherThresholds).

-- "Mining 175" and how it colours at your skill, for a gathering profession you have; "?" for an unknown
-- requirement. Nothing for a profession you don't have. The line is kept by the skill it asks, so a repeated
-- tooltip set does not read your professions again.
---@param skillLine integer
---@param required number?
---@return SkillUpTooltipLine[]
local function GatherLines(skillLine, required)
	local key = string.format("%d:%s", skillLine, required and tostring(required) or "?")
	local lines = gatherLines[key]
	if lines then
		return lines
	end
	local profession = ns.PlayerProfessions()[skillLine]
	if not profession then
		lines = {}
	elseif not required then
		lines = { DoubleLine(profession.name, "?", ns.COLORS.unknown) }
	else
		local band, color = Band(ns.Model.GatherThresholds(required), profession.skill)
		lines = { DoubleLine(string.format(L["%s %d"], profession.name, required), band, color) }
	end
	gatherLines[key] = lines
	return lines
end

---@param tooltip GameTooltip
---@param skillLine integer
---@param required number?
local function AddGatherLine(tooltip, skillLine, required)
	Draw(tooltip, GatherLines(skillLine, required))
end

-- The first line of a tooltip's data, when it can be read.
---@param data TooltipData?
---@return string?
local function FirstLine(data)
	local lines = data and data.lines
	local first = lines and lines[1]
	return first and ns.Readable(first.leftText)
end

-- A herb or ore node, by its tooltip's name. The bundled names are classic-db's English ones, so another
-- client language shows nothing rather than a wrong match.
---@param tooltip GameTooltip
---@param data TooltipData
local function AddNodeSkill(tooltip, data)
	if not ns.Usable(tooltip) or not ns.db.gatherTooltip or GetLocale() ~= "enUS" then
		return
	end
	local name = FirstLine(data)
	local node = name and ns.NodeSkills[name]
	if node then
		AddGatherLine(tooltip, node[1], node[2])
	end
end

-- The line the client adds to a corpse something can be gathered from, in its own words in every language,
-- and the gathering skill each one is for: Skinning, Herbalism, Mining.
---@type table<string, integer>?
local corpseLines

---@return table<string, integer>
local function CorpseLines()
	if not corpseLines then
		corpseLines = {}
		for text, skillLine in pairs({
			[UNIT_SKINNABLE_LEATHER or false] = 393,
			[UNIT_SKINNABLE_HERB or false] = 182,
			[UNIT_SKINNABLE_ROCK or false] = 186,
		}) do
			if text then
				corpseLines[text] = skillLine
			end
		end
	end
	return corpseLines
end

---@param tooltip GameTooltip
---@param data TooltipData
local function AddCorpseSkill(tooltip, data)
	if not ns.Usable(tooltip) or not ns.db.gatherTooltip then
		return
	end
	local skillLine
	local lines = CorpseLines()
	for _, line in ipairs(data and data.lines or {}) do
		local text = ns.Readable(line.leftText)
		skillLine = text and lines[text]
		if skillLine then
			break
		end
	end
	if not skillLine then
		return
	end
	-- Read before any test: a secret unit token errors even on its truth test.
	local unit = ns.Readable((select(2, tooltip:GetUnit())))
	local level = unit and ns.Readable(UnitLevel(unit))
	AddGatherLine(tooltip, skillLine, ns.Model.CorpseSkill(level))
end

function ns.AttachItemTooltips()
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddUses)
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, AddNodeSkill)
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, AddCorpseSkill)
	local events = CreateFrame("Frame")
	events:RegisterEvent("MODIFIER_STATE_CHANGED")
	events:SetScript("OnEvent", OnModifierChanged)
end
