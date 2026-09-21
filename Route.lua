local _, ns = ...

-- Retail list proportions: GameFontHighlight rows with 16px icons.
local LINE_HEIGHT = 20
local HEADER_HEIGHT = 26
local ICON_SIZE = 16
local COLUMN_GAP = 8
-- Room kept on the right for the scroll bar, so columns line up with or without it.
local SCROLL_BAR_WIDTH = 18
-- How far right of centre the route/reagents split sits.
local ROUTE_SHARE = 50
local TRAIN_ICON = "Interface\\Icons\\INV_Misc_Book_11"
-- A day-old scan is flagged: auction prices move that fast.
local STALE_AFTER = 24 * 3600

local page, tab
local selected -- skill line shown on the page
local pending = false

local RANK_NAMES = { [150] = "Journeyman", [225] = "Expert", [300] = "Artisan" }

-- The ranks a trainer teaches above the current cap, in order, and the highest cap
-- they reach. It stops at a gap: a rank that comes from a book or quest isn't known.
local function NextRanks(profession)
	local byCap = {}
	for _, rank in ipairs(ns.TrainerRanks[profession.skillLine] or {}) do
		byCap[rank[1]] = rank
	end
	local ranks, cap = {}, profession.max
	while byCap[cap + 75] do
		local rank = byCap[cap + 75]
		ranks[#ranks + 1] =
			{ name = RANK_NAMES[rank[1]], cap = rank[1], fee = rank[2], reqSkill = rank[3], level = rank[4] }
		cap = rank[1]
	end
	return ranks, cap
end

-- Levelled by gathering, not crafting: their few Forever recipes can't carry a route.
local GATHERING = { [182] = true, [356] = true, [393] = true } -- Herbalism, Fishing, Skinning

-- The player's professions a route can be planned for.
function ns.RouteProfessions()
	local professions = {}
	for skillLine, profession in pairs(ns.PlayerProfessions()) do
		if not GATHERING[skillLine] then
			professions[skillLine] = profession
		end
	end
	return professions
end

-- The chosen target in base skill, per profession; the trainer plans to it too.
-- A target already reached gives way to the default. Past the cap is fine up to
-- the last rank a trainer teaches; the route trains those ranks on the way.
function ns.RouteTarget(profession)
	local saved = ns.db.routeTargets[profession.skillLine]
	local _, ceiling = NextRanks(profession)
	return math.min(saved and saved > profession.base and saved or profession.base + 25, ceiling)
end

-- The cheapest route to the target from the recipes this character knows, for
-- any of its professions: bundled recipe data plus the learned record, so the
-- profession needn't be open. `known` adds recipes the caller knows are
-- learned (the trainer's "used" services). Skills are effective (base + bonus).
function ns.RouteSnapshot(profession, known)
	local recipes = {}
	for recipeID, recipe in pairs(ns.RecipeData) do
		local thresholds = recipe.skillLine == profession.skillLine and ns.Model.Get(recipeID)
		if thresholds and (known and known[recipeID] or ns.IsLearned(recipeID)) then
			recipes[#recipes + 1] = { recipeID = recipeID, thresholds = thresholds, netCost = ns.NetCost(recipeID) }
		end
	end
	local target = ns.RouteTarget(profession)
	return { skill = profession.skill, target = target + profession.modifier, recipes = recipes }
end

-- Trainer-taught recipes of this profession not yet learned that could skill up
-- somewhere between here and the target, at what a trainer was seen to charge or
-- else the bundled base fee. Nothing is used before the trainer would teach it:
-- the thresholds' first value is where a recipe turns orange, not where it's taught.
-- { fee, required base skill }: what a trainer was seen to charge, else the base fee.
function ns.TrainingFor(profession, recipeID)
	local seen = ns.db.trainer[profession.skillLine]
	return seen and seen[recipeID] or ns.TrainerFees[recipeID]
end

local function Trainable(profession, snapshot)
	local services = {}
	for recipeID, recipe in pairs(ns.RecipeData) do
		local training = recipe.skillLine == profession.skillLine and ns.TrainingFor(profession, recipeID)
		local t = training and not ns.IsLearned(recipeID) and ns.Model.Get(recipeID)
		if t then
			local taught = { math.max(t[1], training[2] + profession.modifier), t[2], t[3], t[4] }
			if taught[1] <= snapshot.target and t[4] > snapshot.skill then
				services[#services + 1] =
					{ recipeID = recipeID, thresholds = taught, netCost = ns.NetCost(recipeID), fee = training[1] }
			end
		end
	end
	table.sort(services, function(a, b)
		return a.recipeID < b.recipeID
	end)
	return services
end

-- Planning with training re-plans once per candidate, so plans are kept until
-- prices, recipes, fees or targets change; skill is part of the key.
local plans = {}

function ns.InvalidatePlans()
	plans = {}
end

function ns.PlanRoute(profession)
	local target = ns.RouteTarget(profession)
	local key = profession.skill .. ":" .. profession.max .. ":" .. target
	local cached = plans[profession.skillLine]
	if cached and cached.key == key then
		return cached.route
	end
	local snapshot = ns.RouteSnapshot(profession)
	local route = ns.Model.PlanWithTraining(snapshot, Trainable(profession, snapshot))
	route.profession = profession.name
	route.target = target
	-- Each rank is needed once the route passes the cap below it.
	route.ranks = {}
	for _, rank in ipairs(NextRanks(profession)) do
		if target > rank.cap - 75 then
			route.ranks[#route.ranks + 1] = rank
			route.trainingCost = route.trainingCost + rank.fee
		end
	end
	plans[profession.skillLine] = { key = key, route = route }
	return route
end

local function RecipeName(recipeID)
	return C_Spell.GetSpellName(recipeID) or ("recipe " .. recipeID)
end

local function Money(copper)
	return ns.FormatNet(ns.Model.RoundMoney(math.abs(copper)), copper < 0)
end

local function Output(recipeID)
	local recipe = ns.RecipeData[recipeID]
	return recipe and recipe.output
end

local function RecipeIcon(recipeID)
	local output = Output(recipeID)
	return output and C_Item.GetItemIconByID(output.itemID) or C_Spell.GetSpellTexture(recipeID)
end

-- A table: icon and name, then right-aligned value columns (listed right to left)
-- under fixed headers, scrolling with Blizzard's ScrollBox and minimal scroll bar
-- once it outgrows the inset. Each row can show a tooltip and act on a click.
local function CreateList(parent, columns)
	local list = { rows = {}, count = 0, height = 0 }
	local scrollBox = CreateFrame("Frame", nil, parent, "WowScrollBox")
	scrollBox:SetPoint("TOPLEFT", 4, -HEADER_HEIGHT)
	scrollBox:SetPoint("BOTTOMRIGHT", -SCROLL_BAR_WIDTH, 4)
	local scrollBar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)
	scrollBar:SetHideIfUnscrollable(true)
	-- Created before Init, which moves `scrollable` children into the scroll target;
	-- the view stretches it to the box's width.
	local content = CreateFrame("Frame", nil, scrollBox)
	content.scrollable = true
	content:SetSize(1, 1)
	local view = CreateScrollBoxLinearView()
	view:SetPanExtent(LINE_HEIGHT)
	ScrollUtil.InitScrollBoxWithScrollBar(scrollBox, scrollBar, view)
	list.scrollBox = scrollBox

	-- Headers sit on the inset, rows in the content: both measure from the same edge.
	local right = -4
	for _, column in ipairs(columns) do
		local header = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		header:SetPoint("TOPRIGHT", right - SCROLL_BAR_WIDTH, -8)
		header:SetWidth(column.width)
		header:SetJustifyH(column.justify or "RIGHT")
		header:SetText(column.title)
		column.right = right
		right = right - column.width - COLUMN_GAP
	end
	local textRight = right

	local function OnEnter(row)
		if row.entry.tooltip then
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			row.entry.tooltip(GameTooltip)
			GameTooltip:Show()
		end
	end

	local function OnClick(row)
		if row.entry.click then
			row.entry.click()
		end
	end

	local function CreateRow()
		local row = CreateFrame("Button", nil, content)
		row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		row:SetScript("OnEnter", OnEnter)
		row:SetScript("OnLeave", GameTooltip_Hide)
		row:SetScript("OnClick", OnClick)
		row.Icon = row:CreateTexture(nil, "ARTWORK")
		row.Icon:SetSize(ICON_SIZE, ICON_SIZE)
		row.Icon:SetPoint("LEFT", 6, 0)
		row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		row.Text:SetJustifyH("LEFT")
		row.Values = {}
		for i, column in ipairs(columns) do
			local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			value:SetPoint("RIGHT", column.right, 0)
			value:SetWidth(column.width)
			value:SetJustifyH(column.justify or "RIGHT")
			value:SetWordWrap(false)
			row.Values[i] = value
		end
		return row
	end

	-- entry: text, color, icon, values (per column), valueColor, tooltip(tooltip), click().
	function list:Add(entry)
		self.count = self.count + 1
		local row = self.rows[self.count] or CreateRow()
		self.rows[self.count] = row
		row.entry = entry
		row.Icon:SetTexture(entry.icon)
		row.Icon:SetShown(entry.icon ~= nil)
		row.Text:ClearAllPoints()
		row.Text:SetPoint("LEFT", entry.icon and ICON_SIZE + 12 or 6, 0)
		row.Text:SetWordWrap(entry.wrap == true)
		row.Text:SetText(entry.text)
		-- A wrapped message gets an explicit width, so its height is known now: as
		-- many lines as it needs. Anything else is one line cut at the columns.
		local height = LINE_HEIGHT
		local width = scrollBox:GetWidth() - 10
		if entry.wrap and width > 0 then
			row.Text:SetWidth(width)
			height = math.max(LINE_HEIGHT, row.Text:GetStringHeight() + 6)
		else
			row.Text:SetWidth(0)
			row.Text:SetPoint("RIGHT", entry.values and textRight or -4, 0)
		end
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, -self.height)
		row:SetPoint("RIGHT")
		row:SetHeight(height)
		self.height = self.height + height
		row.Text:SetTextColor((entry.color or HIGHLIGHT_FONT_COLOR):GetRGB())
		for i, value in ipairs(row.Values) do
			value:SetText(entry.values and entry.values[i] or "")
			value:SetTextColor((entry.valueColor or HIGHLIGHT_FONT_COLOR):GetRGB())
		end
		row:EnableMouse(entry.tooltip ~= nil or entry.click ~= nil)
		row:Show()
	end

	function list:Message(text, color)
		self:Add({ text = text, color = color or GRAY_FONT_COLOR, wrap = true })
	end

	function list:Finish()
		for i = self.count + 1, #self.rows do
			self.rows[i]:Hide()
		end
		content:SetHeight(math.max(self.height, 1))
		scrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
		self.count, self.height = 0, 0
	end
	return list
end

function ns.RankText(rank)
	local text = string.format("Train %s at %d", rank.name, rank.reqSkill)
	if rank.level > UnitLevel("player") then
		text = text .. string.format(" (level %d)", rank.level)
	end
	return text
end

local function AddLine(tooltip, left, right, rightColor)
	GameTooltip_AddColoredDoubleLine(tooltip, left, right, NORMAL_FONT_COLOR, rightColor or HIGHLIGHT_FONT_COLOR)
end

-- Not red when short: the route gets there before this step.
local function RequiresLine(tooltip, profession, reqSkill)
	AddLine(tooltip, "Requires", string.format("%s (%d)", profession.name, reqSkill))
end

-- The crafted item's own tooltip when there is one, else the recipe's name.
local function RecipeTitle(tooltip, recipeID, title)
	local output = Output(recipeID)
	if output then
		tooltip:SetItemByID(output.itemID)
		GameTooltip_AddBlankLineToTooltip(tooltip)
		GameTooltip_AddNormalLine(tooltip, title)
	else
		GameTooltip_SetTitle(tooltip, title)
	end
end

local BAND_NAMES = { "orange", "yellow", "green", "grey" }

-- "Colour from  120  132  145", each number in its band's colour, starting where
-- the recipe can be learned: the data's first threshold can sit far below that.
local function AddBands(tooltip, profession, recipeID)
	local t = ns.Model.Get(recipeID)
	if not t then
		return
	end
	local training = ns.TrainingFor(profession, recipeID)
	local scroll = ns.RecipeSources[recipeID]
	local learnAt = training and training[2] + profession.modifier
		or scroll and scroll.skill + profession.modifier
		or t[1]
	local parts, names = {}, {}
	for i, name in ipairs(BAND_NAMES) do
		local from = math.max(t[i], learnAt)
		if i == #BAND_NAMES or from < t[i + 1] then
			parts[#parts + 1] = ns.COLORS[name]:WrapTextInColorCode(tostring(from))
			names[#names + 1] = ns.COLORS[name]:WrapTextInColorCode(name)
		end
	end
	AddLine(tooltip, table.concat(names, " "), table.concat(parts, "  "))
end

local function CraftTooltip(tooltip, profession, segment)
	local recipeID, m = segment.recipeID, profession.modifier
	RecipeTitle(tooltip, recipeID, RecipeName(recipeID))
	AddLine(
		tooltip,
		"Crafts",
		string.format("%d, from %d to %d", segment.crafts, segment.fromSkill - m, segment.toSkill - m)
	)
	AddBands(tooltip, profession, recipeID)
	GameTooltip_AddBlankLineToTooltip(tooltip)
	for _, reagent in ipairs(ns.Reagents(recipeID) or {}) do
		local name = C_Item.GetItemNameByID(reagent.itemID) or ("item " .. reagent.itemID)
		local have = ns.Have(reagent.itemID)
		local need = reagent.quantity * segment.crafts
		local color = have >= need and ns.COLORS.green or HIGHLIGHT_FONT_COLOR
		GameTooltip_AddColoredDoubleLine(
			tooltip,
			name,
			string.format("%d/%d", math.min(have, need), need),
			HIGHLIGHT_FONT_COLOR,
			color
		)
	end
	AddLine(tooltip, "Cost", Money(ns.NetCost(recipeID) * segment.expectedCrafts))
	if ns.IsLearned(recipeID) and profession.skillLine == ns.OpenSkillLine() then
		GameTooltip_AddInstructionLine(tooltip, "Click to open the recipe.")
	end
end

local function TrainTooltip(tooltip, profession, step)
	RecipeTitle(tooltip, step.recipeID, "Train " .. RecipeName(step.recipeID))
	GameTooltip_AddHighlightLine(tooltip, string.format("Taught by %s trainers.", profession.name))
	AddLine(tooltip, "Fee", Money(step.fee))
	RequiresLine(tooltip, profession, step.reqSkill)
	AddLine(tooltip, "First used at", tostring(step.atSkill - profession.modifier))
	AddBands(tooltip, profession, step.recipeID)
	ns.AddNearest(tooltip, "Nearest trainer", ns.NearestTrainer(profession, step.reqSkill + 1))
end

local function RankTooltip(tooltip, profession, rank)
	GameTooltip_SetTitle(tooltip, string.format("%s %s", rank.name, profession.name))
	GameTooltip_AddHighlightLine(tooltip, string.format("Raises your skill cap to %d.", rank.cap))
	AddLine(tooltip, "Fee", Money(rank.fee))
	RequiresLine(tooltip, profession, rank.reqSkill)
	if rank.level > 0 then
		local color = UnitLevel("player") < rank.level and RED_FONT_COLOR or HIGHLIGHT_FONT_COLOR
		AddLine(tooltip, "Requires", string.format("level %d", rank.level), color)
	end
	ns.AddNearest(tooltip, "Nearest trainer", ns.NearestTrainer(profession, rank.cap))
end

-- A waypoint to the nearest trainer teaching up to `cap`.
local function TrainerClick(profession, cap)
	return function()
		local npcID = ns.NearestTrainer(profession, cap)
		if npcID then
			ns.SetWaypoint(npcID)
		end
	end
end

local function RecipeClick(recipeID)
	return function()
		if IsModifiedClick("CHATLINK") then
			ChatEdit_InsertLink(C_Spell.GetSpellLink(recipeID))
		else
			ns.ShowRecipe(recipeID)
		end
	end
end

local SUGGESTIONS_SHOWN = 8

local function SuggestionTooltip(tooltip, profession, suggestion)
	local recipeID = suggestion.recipeID
	RecipeTitle(tooltip, recipeID, RecipeName(recipeID))
	RequiresLine(tooltip, profession, suggestion.source.skill)
	AddBands(tooltip, profession, recipeID)
	local price = ns.ScrollPrice(suggestion.source)
	if price then
		AddLine(tooltip, "Scroll", Money(price))
	end
	GameTooltip_AddBlankLineToTooltip(tooltip)
	ns.AddSourceLines(tooltip, suggestion.source)
	if suggestion.npcID then
		GameTooltip_AddInstructionLine(tooltip, "Click for a waypoint to " .. ns.SourceNPCs[suggestion.npcID][1] .. ".")
	end
	GameTooltip_AddInstructionLine(tooltip, "Shift-click to link the scroll.")
end

local function SuggestionClick(suggestion)
	return function()
		if IsModifiedClick("CHATLINK") then
			local _, link = C_Item.GetItemInfo(suggestion.source.item)
			if link then
				ChatEdit_InsertLink(link)
			end
		elseif suggestion.npcID then
			ns.SetWaypoint(suggestion.npcID)
		end
	end
end

-- Where the known recipes run out: the scrolls that would carry the route on.
local function RenderSuggestions(list, profession, route)
	local suggestions = ns.RecipeSuggestions(profession, route.reachedSkill)
	if #suggestions == 0 then
		return
	end
	list:Message("Recipes from vendors, quests and drops that would carry it on:", NORMAL_FONT_COLOR)
	for i = 1, math.min(#suggestions, SUGGESTIONS_SHOWN) do
		local suggestion = suggestions[i]
		local t = ns.Model.Get(suggestion.recipeID)
		local price = ns.ScrollPrice(suggestion.source)
		list:Add({
			icon = C_Item.GetItemIconByID(suggestion.source.item),
			text = string.format("%s  |cff808080%s|r", RecipeName(suggestion.recipeID), suggestion.kindText),
			color = ns.COLORS[ns.Model.Color(t, route.reachedSkill)],
			values = { price and Money(price) or "", tostring(suggestion.reach - profession.modifier) },
			tooltip = function(tooltip)
				SuggestionTooltip(tooltip, profession, suggestion)
			end,
			click = SuggestionClick(suggestion),
		})
	end
end

local function RenderRoute(list, profession, route)
	if profession.capped and #route.ranks == 0 and #route.segments == 0 then
		list:Message(string.format("At the %d cap: no trainer teaches the next rank.", profession.max))
		return
	end
	local m = profession.modifier
	local nextRank = 1
	local function AddRanks(toSkill)
		local rank = route.ranks[nextRank]
		while rank and toSkill > rank.cap - 75 do
			local level = rank.level > UnitLevel("player") and string.format("  (level %d)", rank.level) or ""
			local shown = rank
			list:Add({
				icon = profession.icon,
				text = "Train " .. rank.name .. level,
				color = NORMAL_FONT_COLOR,
				values = { Money(rank.fee), tostring(rank.reqSkill) },
				tooltip = function(tooltip)
					RankTooltip(tooltip, profession, shown)
				end,
				click = TrainerClick(profession, shown.cap),
			})
			nextRank = nextRank + 1
			rank = route.ranks[nextRank]
		end
	end
	local training = {}
	for _, step in ipairs(route.training) do
		training[step.recipeID] = step
	end
	for _, segment in ipairs(route.segments) do
		AddRanks(segment.toSkill - m)
		local step = training[segment.recipeID]
		if step then
			training[segment.recipeID] = nil
			step.reqSkill = ns.TrainingFor(profession, step.recipeID)[2]
			list:Add({
				icon = TRAIN_ICON,
				text = "Train " .. RecipeName(step.recipeID),
				color = NORMAL_FONT_COLOR,
				values = { Money(step.fee), tostring(step.reqSkill) },
				tooltip = function(tooltip)
					TrainTooltip(tooltip, profession, step)
				end,
				click = TrainerClick(profession, step.reqSkill + 1),
			})
		end
		list:Add({
			icon = RecipeIcon(segment.recipeID),
			text = RecipeName(segment.recipeID),
			color = ns.COLORS[ns.Model.Color(ns.Model.Get(segment.recipeID), segment.fromSkill)],
			values = {
				Money(ns.NetCost(segment.recipeID) * segment.expectedCrafts),
				tostring(segment.toSkill - m),
				tostring(segment.crafts),
			},
			tooltip = function(tooltip)
				CraftTooltip(tooltip, profession, segment)
			end,
			click = RecipeClick(segment.recipeID),
		})
	end
	if #route.segments > 0 then
		list:Add({
			text = "Total",
			color = NORMAL_FONT_COLOR,
			values = { Money(route.expectedCost + route.trainingCost) },
			valueColor = NORMAL_FONT_COLOR,
		})
	end
	if #route.segments == 0 and route.excluded.unpriced > 0 then
		-- Auctionator knows only what it has scanned, so installing it isn't enough.
		local how = ns.HasAuctionator() and "open the auction house (or run Auctionator's Full Scan)"
			or "open the auction house"
		list:Message(
			string.format(
				"Neither SkillUp nor Auctionator has seen these reagents on the auction house yet: %s to price them.",
				how
			)
		)
	elseif route.stopReason == "no_recipe" then
		local known = route.excluded.unpriced > 0 and "Nothing priced you know" or "Nothing you know"
		list:Message(string.format("%s skills up past %d.", known, route.reachedSkill - m), RED_FONT_COLOR)
		RenderSuggestions(list, profession, route)
	end
	if #route.segments > 0 and route.excluded.unpriced > 0 then
		list:Message(string.format("%d recipes skipped: reagents not priced yet.", route.excluded.unpriced))
	end
end

local SOURCE_TEXT = { vendor = "vendor", auction = "AH", unknown = "no price" }

local function ReagentTooltip(tooltip, item)
	tooltip:SetItemByID(item.itemID)
	GameTooltip_AddBlankLineToTooltip(tooltip)
	local have = ns.Have(item.itemID)
	AddLine(tooltip, "Have (bags and bank)", tostring(have))
	AddLine(tooltip, "Route needs", tostring(item.need))
	local price = ns.Price(item.itemID)
	if not price then
		GameTooltip_AddDisabledLine(tooltip, "No price yet: visit a vendor or the auction house.")
		return
	end
	AddLine(tooltip, "Each", string.format("%s |cff808080(%s)|r", Money(price.copper), ns.PriceSourceText(price)))
	if have < item.need then
		AddLine(tooltip, "To buy", Money(price.copper * (item.need - have)))
	end
	if item.source == "vendor" then
		ns.AddNearest(tooltip, "Nearest vendor", ns.NearestVendor(item.itemID))
	end
end

-- Reagents of known recipes that still skill up but have no price, which is what
-- keeps them out of the route.
local function UnpricedReagents(profession)
	local snapshot = ns.RouteSnapshot(profession)
	local seen, items = {}, {}
	for _, recipe in ipairs(snapshot.recipes) do
		if recipe.netCost == nil and recipe.thresholds[4] > snapshot.skill then
			for _, reagent in ipairs(ns.Reagents(recipe.recipeID) or {}) do
				if not seen[reagent.itemID] and not ns.Price(reagent.itemID) then
					seen[reagent.itemID] = true
					items[#items + 1] = reagent.itemID
				end
			end
		end
	end
	table.sort(items)
	return items
end

local function RenderUnpriced(list, items)
	for _, itemID in ipairs(items) do
		list:Add({
			icon = C_Item.GetItemIconByID(itemID) or 134400,
			text = C_Item.GetItemNameByID(itemID) or ("item " .. itemID),
			values = { "", SOURCE_TEXT.unknown },
			tooltip = function(tooltip)
				tooltip:SetItemByID(itemID)
			end,
		})
	end
end

local function RenderReagents(list, reagents)
	if #reagents == 0 then
		list:Message("Nothing to buy for this route.")
		return
	end
	for _, item in ipairs(reagents) do
		local name = C_Item.GetItemNameByID(item.itemID)
		if not name then
			-- ITEM_DATA_LOAD_RESULT redraws once the name arrives.
			C_Item.RequestLoadItemDataByID(item.itemID)
			name = "item " .. item.itemID
		end
		local have = ns.Have(item.itemID)
		list:Add({
			icon = C_Item.GetItemIconByID(item.itemID) or 134400,
			text = name,
			values = { string.format("%d/%d", math.min(have, item.need), item.need), SOURCE_TEXT[item.source] },
			valueColor = have >= item.need and ns.COLORS.green or HIGHLIGHT_FONT_COLOR,
			tooltip = function(tooltip)
				ReagentTooltip(tooltip, item)
			end,
			click = function()
				local _, link = C_Item.GetItemInfo(item.itemID)
				local vendor = item.source == "vendor" and ns.NearestVendor(item.itemID)
				if link and IsModifiedClick() then
					HandleModifiedItemClick(link)
				elseif vendor then
					ns.SetWaypoint(vendor)
				end
			end,
		})
	end
end

-- How fresh the auction prices behind this route are: the oldest, since that is
-- the one most likely to be wrong.
local function PriceAge(reagents)
	local oldest
	for _, item in ipairs(reagents) do
		local price = ns.Price(item.itemID)
		if price and price.source ~= "vendor" and (not oldest or ns.PriceAge(price) > ns.PriceAge(oldest)) then
			oldest = price
		end
	end
	if not oldest then
		return "", GRAY_FONT_COLOR
	end
	local stale = ns.PriceAge(oldest) > STALE_AFTER
	local text = "AH prices from " .. ns.PriceAgeText(oldest) .. (stale and ": rescan at the auction house" or "")
	return text, stale and ns.COLORS.orange or GRAY_FONT_COLOR
end

local function Render()
	local profession = selected and ns.RouteProfessions()[selected]
	page.Profession:GenerateMenu()
	page.Skill:SetShown(profession ~= nil)
	page.Target:SetShown(profession ~= nil)
	page.Track:SetEnabled(profession ~= nil)
	page.Auctionator:Disable()
	if not profession then
		page.RouteList:Message("Learn a crafting profession to plan a route.")
		page.RouteList:Finish()
		page.ReagentList:Finish()
		return
	end
	ProfessionsFrame:SetPortraitToAsset(profession.icon)
	page.Skill:SetFormattedText("Skill  %d/%d     Target", profession.base, profession.max)
	local route = ns.PlanRoute(profession)
	if not page.Target:HasFocus() then
		page.Target:SetText(tostring(route.target))
	end
	local reagents = ns.RouteReagents(route)
	RenderRoute(page.RouteList, profession, route)
	if #route.segments == 0 and route.excluded.unpriced > 0 then
		RenderUnpriced(page.ReagentList, UnpricedReagents(profession))
	else
		RenderReagents(page.ReagentList, reagents)
	end
	local age, ageColor = PriceAge(reagents)
	page.PriceAge:SetText(age)
	page.PriceAge:SetTextColor(ageColor:GetRGB())
	page.RouteList:Finish()
	page.ReagentList:Finish()
	page.Track:SetText(ns.IsTracked(selected) and "Stop tracking" or "Track")
	page.Auctionator:SetEnabled(#reagents > 0)
end

-- Coalesces bursts of list/skill/price/bag updates into one plan.
function ns.RefreshRoute()
	if pending or not (page and page:IsShown()) then
		return
	end
	pending = true
	C_Timer.After(0.2, function()
		pending = false
		if page:IsShown() then
			Render()
		end
	end)
end

local function CommitTarget(editBox)
	local value = tonumber(editBox:GetText())
	if selected and value then
		ns.db.routeTargets[selected] = value
		ns.InvalidatePlans()
		ns.RefreshTracker()
	end
	ns.RefreshRoute()
end

local function CreateInset(name)
	local inset = CreateFrame("Frame", nil, page, "InsetFrameTemplate")
	local title = inset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("BOTTOMLEFT", inset, "TOPLEFT", 4, 4)
	title:SetText(name)
	return inset
end

local function CreateHeader()
	local dropdown = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
	dropdown:SetWidth(180)
	-- Clear of the portrait, which overhangs the top-left corner.
	dropdown:SetPoint("TOPLEFT", 76, -32)
	dropdown:SetupMenu(function(_, root)
		local professions = {}
		for _, profession in pairs(ns.RouteProfessions()) do
			professions[#professions + 1] = profession
		end
		table.sort(professions, function(a, b)
			return a.name < b.name
		end)
		for _, profession in ipairs(professions) do
			local skillLine = profession.skillLine
			root:CreateRadio(profession.name, function()
				return skillLine == selected
			end, function()
				selected = skillLine
				page.RouteList.scrollBox:ScrollToBegin()
				page.ReagentList.scrollBox:ScrollToBegin()
				Render()
			end)
		end
	end)
	page.Profession = dropdown

	local skill = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	skill:SetPoint("LEFT", dropdown, "RIGHT", 16, 0)
	page.Skill = skill

	local target = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
	target:SetSize(40, 20)
	target:SetPoint("LEFT", skill, "RIGHT", 10, 0)
	target:SetNumeric(true)
	target:SetMaxLetters(3)
	target:SetAutoFocus(false)
	target:SetScript("OnEnterPressed", target.ClearFocus)
	target:SetScript("OnEditFocusLost", CommitTarget)
	target:SetScript("OnEscapePressed", function(editBox)
		editBox:SetText("")
		editBox:ClearFocus()
	end)
	page.Target = target
end

local function CreateButtons()
	local track = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	track:SetSize(130, 22)
	track:SetScript("OnClick", function()
		local tracked = not ns.IsTracked(selected)
		ns.SetTracked(selected, tracked)
		Render()
		if tracked and not ns.TrackerAttached() then
			ns.Print("tracked, but the objective tracker section isn't attached; please report it.")
		end
	end)
	page.Track = track

	-- Only auction house reagents still missing go to the Auctionator list.
	local auctionator = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	auctionator:SetSize(130, 22)
	auctionator:SetText("To Auctionator")
	auctionator:SetScript("OnClick", function()
		local profession = ns.RouteProfessions()[selected]
		ns.SendToAuctionator(profession.name, ns.RouteReagents(ns.PlanRoute(profession)))
	end)
	auctionator:SetShown(ns.HasAuctionator())
	page.Auctionator = auctionator
end

-- Occupies the crafting page's place, as the overview page does.
local function CreatePage()
	page = CreateFrame("Frame", nil, ProfessionsFrame)
	page:SetAllPoints(ProfessionsFrame.CraftingPage)
	page:SetFrameLevel(ProfessionsFrame.CraftingPage:GetFrameLevel())
	page:Hide()
	CreateHeader()
	CreateButtons()

	local route = CreateInset("Route")
	route:SetPoint("TOPLEFT", 16, -88)
	-- The route gets the wider half: its names are longer and it has more columns.
	route:SetPoint("BOTTOMRIGHT", page, "BOTTOM", ROUTE_SHARE - 6, 44)
	page.RouteList = CreateList(route, {
		{ title = "Cost", width = 64 },
		{ title = "To", width = 28 },
		{ title = "Crafts", width = 36 },
	})

	local reagents = CreateInset("Reagents  (have / need)")
	reagents:SetPoint("TOPLEFT", page, "TOP", ROUTE_SHARE + 6, -88)
	reagents:SetPoint("BOTTOMRIGHT", -16, 44)
	page.ReagentList = CreateList(reagents, {
		{ title = "Have", width = 64 },
		{ title = "Source", width = 60, justify = "LEFT" },
	})

	page.PriceAge = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	page.PriceAge:SetPoint("TOPLEFT", route, "BOTTOMLEFT", 4, -14)

	page.Track:SetPoint("TOPRIGHT", reagents, "BOTTOMRIGHT", 0, -10)
	page.Auctionator:SetPoint("RIGHT", page.Track, "LEFT", -8, 0)
	-- The portrait follows the profession shown here, and is given back on the way out.
	local portrait
	page:SetScript("OnShow", function()
		portrait = ProfessionsFrame:GetPortrait():GetTexture()
		Render()
	end)
	page:SetScript("OnHide", function()
		if portrait then
			ProfessionsFrame:SetPortraitToAsset(portrait)
		end
	end)
end

-- The profession on show in the crafting page, when it is one of this character's.
function ns.OpenSkillLine()
	local info = Professions.GetProfessionInfo()
	local name = info and (info.parentProfessionName or info.professionName)
	local skillLine = name and ns.ProfessionSkillLine(name, info.parentProfessionID or info.professionID)
	return skillLine and ns.PlayerProfessions()[skillLine] and skillLine
end

local function SelectPage()
	local professions = ns.RouteProfessions()
	local open = ns.OpenSkillLine()
	selected = professions[open] and open or professions[selected] and selected or next(professions)
	ProfessionsFrame.CraftingPage:Hide()
	ProfessionsFrame.BookPage:Hide()
	page:Show()
	ProfessionsFrame:RightTabSelected(tab)
end

-- Blizzard's own tabs show their page explicitly, which hands the window back.
local function Deselect()
	page:Hide()
	tab:SetChecked(false)
end

-- Back to the crafting page, as its tab would, with the recipe selected.
function ns.ShowRecipe(recipeID)
	local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
	if not (info and info.learned and selected == ns.OpenSkillLine()) then
		return
	end
	local craftingPage = ProfessionsFrame.CraftingPage
	craftingPage:Show()
	ProfessionsFrame:RefreshRightTabs()
	if craftingPage.RecipeList and craftingPage.RecipeList.SelectRecipe then
		craftingPage.RecipeList:SelectRecipe(info, true)
	end
end

-- Directly under the last profession tab Forever shows, in the same tab art.
local function PlaceTab()
	local last = ProfessionsFrame.ProfessionsOverviewTab
	for _, professionTab in ipairs(ProfessionsFrame.rightProfessionTabs or {}) do
		if professionTab:IsShown() then
			last = professionTab
		end
	end
	tab:ClearAllPoints()
	tab:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -2)
end

-- RightTabSelected knows only Blizzard's tabs, and RefreshRightTabs re-selects
-- the open profession's tab; while our page shows, ours is the checked one.
local function SyncChecks()
	local shown = page:IsShown()
	tab:SetChecked(shown)
	if shown then
		ProfessionsFrame.ProfessionsOverviewTab:SetChecked(false)
		for _, professionTab in ipairs(ProfessionsFrame.rightProfessionTabs or {}) do
			professionTab:SetChecked(false)
		end
	end
end

-- The tab can be turned off in settings; an open page goes back to crafting.
function ns.RefreshRouteTab()
	if not tab then
		return
	end
	tab:SetShown(ns.db.showRouteTab)
	if not ns.db.showRouteTab and page:IsShown() then
		Deselect()
		ProfessionsFrame.CraftingPage:Show()
	end
end

local function CreateTab()
	tab = CreateFrame("Frame", nil, ProfessionsFrame, "LargeSideTabButtonTemplate")
	tab.Icon:SetTexture("Interface\\Icons\\INV_Scroll_03")
	tab:SetFillToInterior(true)
	tab.tooltipText = "Levelling route"
	tab:EnableMouse(true)
	tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
		if button == "LeftButton" and upInside then
			SelectPage()
		end
	end)
	PlaceTab()
	ns.RefreshRouteTab()
	hooksecurefunc(ProfessionsFrame, "RefreshRightTabs", PlaceTab)
	hooksecurefunc(ProfessionsFrame, "RightTabSelected", SyncChecks)
end

function ns.AttachRoute()
	CreatePage()
	CreateTab()
	ProfessionsFrame.CraftingPage:HookScript("OnShow", Deselect)
	ProfessionsFrame.BookPage:HookScript("OnShow", Deselect)
	-- A reopened window starts on the crafting page, as Blizzard expects.
	ProfessionsFrame:HookScript("OnHide", function()
		if page:IsShown() then
			Deselect()
			ProfessionsFrame.CraftingPage:Show()
		end
	end)
	local events = CreateFrame("Frame")
	for _, event in ipairs({
		"TRADE_SKILL_LIST_UPDATE",
		"SKILL_LINES_CHANGED",
		"BAG_UPDATE_DELAYED",
		"ITEM_DATA_LOAD_RESULT",
	}) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", ns.RefreshRoute)
end
