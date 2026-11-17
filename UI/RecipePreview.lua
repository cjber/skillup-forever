---@type string, SkillUpNamespace
local addonName, ns = ...

if ns.broken then
	return
end
local L = ns.L
local OUTPUT_ICON_SIZE = 53
local REAGENT_ICON_SIZE = 33
-- Match Blizzard's (28, -28) output anchor in the expanded pane, with gutter for the icon rim.
local SCROLL_TOP = 14
local CONTENT_LEFT, CONTENT_TOP = 28, 28 - SCROLL_TOP
local TITLE_GAP, TITLE_RIGHT, TITLE_RISE = 14, 6, 17

---@class SkillUpPreviewIcon : Button
---@field Icon Texture
---@field Count FontString
---@field CountShadow Texture

---@class SkillUpPreviewReagentIcon : SkillUpPreviewIcon
---@field SetReagent fun(self: SkillUpPreviewReagentIcon, reagent: { itemID: integer })

---@class SkillUpPreviewItem : Button
---@field Button SkillUpPreviewIcon
---@field Name FontString
---@field itemID? integer
---@field spellID? integer

---@class SkillUpPreviewClick : Button
---@field data? SkillUpRecipeNodeData
---@field Hover Texture
---@field Selection? Texture

---@class SkillUpRecipePreview : Frame
---@field page SkillUpCraftingPage
---@field Scroll ScrollFrame
---@field Body Frame
---@field Content Frame
---@field Output SkillUpPreviewItem
---@field Status FontString
---@field Description FontString
---@field Requirements FontString
---@field Skill SkillUpBar
---@field Chance FontString
---@field Reagents FontString
---@field Cost FontString
---@field Rows SkillUpPreviewItem[]

---@type SkillUpRecipePreview?
local preview
---@type TradeSkillRecipeInfo?
local selected
local requestedItems = {}
---@type GameTooltip?
local itemTooltip
---@type table<Region, number>
local nativeAlpha = {}
---@type table<SkillUpRecipeRow, SkillUpPreviewClick>
local clicks = setmetatable({}, { __mode = "k" })

function ns.IsRecipePreviewShown()
	return selected ~= nil
end

---@param widget Region?
---@param masked boolean
local function SetMasked(widget, masked)
	if not widget then
		return
	end
	local originalAlpha = nativeAlpha[widget]
	if masked then
		local alpha = widget:GetAlpha()
		if originalAlpha == nil then
			nativeAlpha[widget] = alpha
		end
		if alpha ~= 0 then
			widget:SetAlpha(0)
		end
	elseif originalAlpha ~= nil then
		widget:SetAlpha(originalAlpha)
		nativeAlpha[widget] = nil
	end
end

---@param row SkillUpRecipeRow
---@param info? TradeSkillRecipeInfo
local function UpdateRowSelection(row, info)
	local native = row.SelectedOverlay
	if not native then
		return
	end
	-- Blizzard keeps the selected recipe behind the preview. Change the artwork with alpha
	-- so a native selection update can still set its own shown state.
	SetMasked(native, selected ~= nil and info ~= nil)
	local button = clicks[row]
	local overlay = button and button.Selection
	if overlay then
		local active = selected ~= nil
			and info ~= nil
			and info.learned == false
			and info.recipeID == selected.recipeID
			and info.favoritesInstance == selected.favoritesInstance
		if active then
			-- art-ok: Use the atlas at its intrinsic size as the native recipe row does.
			overlay:SetAtlas(native:GetAtlas() or "Professions_Recipe_Active", true)
			-- The client's vertex alpha can include the mask applied to the native overlay.
			local r, g, b = native:GetVertexColor()
			overlay:SetVertexColor(r, g, b, 1)
		end
		overlay:SetShown(active)
		button.Hover:SetShown(not active)
	end
end

function ns.CloseRecipePreview()
	if not selected or not preview then
		return
	end
	selected = nil
	for row in pairs(clicks) do
		UpdateRowSelection(row)
	end
	-- The list can close us during the window's OnHide, before the preview itself receives OnHide.
	for widget in pairs(nativeAlpha) do
		SetMasked(widget, false)
	end
	if itemTooltip then
		itemTooltip:Hide()
	end
	preview:Hide()
	ns.Changed("preview")
end

---@param region Region
local function BackdropTexture(region)
	local layer = region:GetDrawLayer()
	return region:IsObjectType("Texture") and (layer == "BACKGROUND" or layer == "BORDER")
end

---@param frame Frame
local function BackdropFrame(frame)
	if frame:GetObjectType() ~= "Frame" then
		return false
	end
	local regions = { frame:GetRegions() }
	for _, region in ipairs(regions) do
		if not BackdropTexture(region) then
			return false
		end
	end
	local children = { frame:GetChildren() }
	for _, child in ipairs(children) do
		if not BackdropFrame(child) then
			return false
		end
	end
	return #regions > 0 or #children > 0
end

---@param page SkillUpCraftingPage
local function MaskNativeContent(page)
	local form = page.SchematicForm
	-- A skin can add its own backdrop frame. Keep texture-only backdrop groups while masking
	-- the native recipe content, including anything Blizzard adds during a refresh.
	for _, region in ipairs({ form:GetRegions() }) do
		SetMasked(region, not BackdropTexture(region))
	end
	for _, child in ipairs({ form:GetChildren() }) do
		SetMasked(child, child ~= form.NineSlice and not BackdropFrame(child))
	end
	SetMasked(page.CreateButton, true)
	SetMasked(page.CreateAllButton, true)
	SetMasked(page.CreateMultipleInputBox, true)
end

local function ItemName(itemID)
	local name = ns.Readable(C_Item.GetItemNameByID(itemID))
	if not name and not requestedItems[itemID] then
		requestedItems[itemID] = true
		C_Item.RequestLoadItemDataByID(itemID)
	end
	return name or string.format(L["item %d"], itemID)
end

local function Label(parent, template)
	local text = parent:CreateFontString(nil, "OVERLAY", template)
	text:SetJustifyH("LEFT")
	return text
end

---@param text FontString
---@param source FontString?
local function MatchFont(text, source)
	if not source then
		return
	end
	local object = source:GetFontObject()
	if object then
		text:SetFontObject(object)
	end
	-- Skins can change one FontString's face or size without changing its shared font object.
	local font, size, flags = source:GetFont()
	if font and size then
		text:SetFont(font, size, flags)
	end
end

local function ItemRow(parent, output)
	local row = CreateFrame("Button", nil, parent) --[[@as SkillUpPreviewItem]]
	-- Use the native item artwork and font templates on our own display widgets. The outer row
	-- owns the tooltip, and no native crafting or reagent-navigation scripts are attached.
	local icon
	if output then
		icon = CreateFrame("Button", nil, row, "ProfessionsOutputButtonTemplate") --[[@as SkillUpPreviewIcon]]
		icon.Icon:SetSize(OUTPUT_ICON_SIZE, OUTPUT_ICON_SIZE)
		row.Name = Label(row, "GameFontHighlightMed2")
		row:SetHeight(icon:GetHeight())
	else
		icon = CreateFrame("ItemButton", nil, row, "ProfessionsButtonTemplate") --[[@as SkillUpPreviewIcon]]
		icon.Icon:SetSize(REAGENT_ICON_SIZE, REAGENT_ICON_SIZE)
		icon.Icon:SetPoint("CENTER")
		row.Name = Label(row, "GameFontHighlight_NoShadow")
		row.Name:SetMaxLines(2)
		row.Name:SetPoint("LEFT", icon, "RIGHT", 7, 0)
		row.Name:SetPoint("RIGHT", row, "RIGHT")
		row:SetHeight(icon:GetHeight())
	end
	icon:SetPoint(output and "TOPLEFT" or "LEFT")
	icon:EnableMouse(false)
	icon:SetMouseMotionEnabled(false)
	row.Button = icon
	row:SetMouseMotionEnabled(true)
	row:SetScript("OnEnter", function()
		-- Filling the shared tooltip with client item data would write to state the bag UI reads.
		if not itemTooltip then
			local name = "SkillUpForeverRecipePreviewTooltip"
			itemTooltip = CreateFrame("GameTooltip", name, UIParent, "GameTooltipTemplate") --[[@as GameTooltip]]
		end
		itemTooltip:SetOwner(row, "ANCHOR_RIGHT")
		if row.itemID then
			itemTooltip:SetItemByID(row.itemID)
		elseif row.spellID then
			itemTooltip:SetSpellByID(row.spellID)
		end
		itemTooltip:Show()
	end)
	row:SetScript("OnLeave", function()
		if itemTooltip then
			itemTooltip:Hide()
		end
	end)
	return row
end

local function Place(label, text, parent, y)
	label:SetText(text)
	label:SetShown(text ~= nil and text ~= "")
	if not label:IsShown() then
		return y
	end
	label:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
	label:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -y)
	return y + label:GetStringHeight() + 6
end

local function Requirements(recipeID)
	local names = {}
	for _, requirement in ipairs(ns.RecipeRequirements(recipeID)) do
		if
			requirement.name
			and (
				requirement.type == Enum.RecipeRequirementType.Totem
				or requirement.type == Enum.RecipeRequirementType.SpellFocus
				or requirement.type == Enum.RecipeRequirementType.Area
			)
		then
			names[#names + 1] = requirement.met == false and RED_FONT_COLOR:WrapTextInColorCode(requirement.name)
				or requirement.name
		end
	end
	if #names > 0 then
		local label = _G["PROFESSIONS_REQUIRED_TOOLS"] or "%s"
		return label:format(table.concat(names, ", "))
	end
end

---@param description SkillUpDescription
local function PriceText(description)
	if not ns.db.showCost then
		return nil
	end
	if not description.cost then
		return L["Reagents not priced yet."]
	end
	-- The learned pane's Auctionator labels can be reused without reading its crafting transaction.
	local toCraft = _G["AUCTIONATOR_L_TO_CRAFT_COLON"] or (L["Per craft"] .. ":")
	local cost = HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(ns.FormatNet(description.cost, false))
	local text = toCraft .. " " .. cost
	local net = description.net
	if description.value and net then
		local profit = _G["AUCTIONATOR_L_PROFIT_COLON"] or (L["Profit per craft"] .. ":")
		local amount = ns.FormatNet(math.abs(net), false)
		if net > 0 then
			amount = RED_FONT_COLOR:WrapTextInColorCode("-" .. amount)
		else
			amount = HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(amount)
		end
		text = text .. "\n" .. profit .. " " .. amount
	end
	return text
end

local function Refresh()
	if not preview or not selected then
		return
	end
	local info = selected --[[@as SkillUpRecipeInfo]]
	local entry = info.skillUpUnlearned
	local ctx = ns.SkillContext()
	if entry and not ns.db.showUnlearned then
		ns.CloseRecipePreview()
		return
	end
	MaskNativeContent(preview.page)
	local recipeID = info.recipeID
	local body, outputRow = preview.Content, preview.Output
	local width = math.max(1, preview.Scroll:GetWidth())
	preview.Body:SetWidth(width)
	body:SetWidth(math.max(1, width - CONTENT_LEFT))
	local output = ns.RecipeOutput(recipeID)
	outputRow.itemID = output and output.itemID
	outputRow.spellID = recipeID
	local icon = output and C_Item.GetItemIconByID(output.itemID) or C_Spell.GetSpellTexture(recipeID)
	local quality = output and ns.Readable(C_Item.GetItemQualityByID(output.itemID)) or 0
	local quantityMin, quantityMax = output and output.quantityMin, output and output.quantityMax
	local outputButton = outputRow.Button
	Professions.SetupOutputIconCommon(
		outputButton,
		quantityMin or 1,
		quantityMax or 1,
		icon or 134400,
		outputRow.itemID,
		quality
	)
	if output and not quantityMax and output.quantity > 1 then
		-- Bundled data gives the average yield without the recipe's bounds.
		outputButton.Count:SetFormattedText("~%g", output.quantity)
		outputButton.CountShadow:Show()
	end
	local form = preview.page.SchematicForm
	MatchFont(outputRow.Name, form.OutputText)
	MatchFont(preview.Description, form.Description)
	MatchFont(preview.Requirements, form.RequiredTools)
	local reagentHeader = form.Reagents and form.Reagents.Label
	MatchFont(preview.Reagents, reagentHeader)
	local title = outputRow.Name
	local titleWidth = math.max(1, body:GetWidth() - outputRow.Button:GetWidth() - TITLE_GAP - TITLE_RIGHT)
	-- Keep the first line at the learned title's height when the localized name wraps.
	local titleRise = TITLE_RISE + title:GetLineHeight() / 2
	title:SetPoint("TOPLEFT", outputRow.Button, "RIGHT", TITLE_GAP, titleRise)
	title:SetWidth(titleWidth)
	title:SetText(string.format(L["%s (unlearned)"], info.name))
	local headerHeight = outputRow.Button:GetHeight() / 2 - titleRise + title:GetStringHeight()
	local barAnchor = title
	local requirements = preview.Requirements
	local required = Requirements(recipeID)
	requirements:SetText(required)
	requirements:SetShown(required ~= nil)
	if required then
		requirements:SetWidth(titleWidth)
		headerHeight = headerHeight + 2 + requirements:GetStringHeight()
		barAnchor = requirements
	end

	local d = ns.Describe(info, ctx)
	local bar = preview.Skill
	local thresholds, skill = ns.DetailsBar(d.thresholds, ctx and ctx.skill)
	if ns.db.detailsBar and thresholds and skill then
		bar:Show()
		local scale = math.min(1, titleWidth / bar:GetWidth())
		bar:SetScale(scale)
		ns.LayoutSkillBar(bar, thresholds, skill)
		bar:SetPoint("TOPLEFT", barAnchor, "BOTTOMLEFT", 0, -2)
		headerHeight = headerHeight + 2 + bar:GetHeight() * scale
	else
		bar:Hide()
	end
	headerHeight = math.max(OUTPUT_ICON_SIZE, headerHeight)

	local source = (ctx and ns.LearnSource(ctx, recipeID)) or entry
	local learn = source and ns.LearnSourceText(source)
	if not learn and C_TradeSkillUI.GetRecipeSourceText then
		learn = ns.Readable(C_TradeSkillUI.GetRecipeSourceText(recipeID))
	end
	if not learn or learn == "" then
		learn = L["Source unknown"]
	end
	if source and source.itemID then
		learn = string.format(L["%s: %s"], learn, ItemName(source.itemID))
	end
	local y = Place(preview.Status, learn, body, headerHeight + 8)
	local description = ns.Readable(C_TradeSkillUI.GetRecipeDescription(recipeID, {}))
	if not output and (not description or description == "") then
		description = ns.Readable(C_Spell.GetSpellDescription(recipeID))
	end
	y = Place(preview.Description, description, body, y)
	local chance = d.chance and string.format(L["Skill-up chance: %d%%"], math.floor(d.chance * 100 + 0.5))
	y = Place(preview.Chance, chance, body, y)
	local heading = (reagentHeader and ns.Readable(reagentHeader:GetText()))
		or _G["PROFESSIONS_REAGENT_CONTAINER_LABEL"]
		or (L["Reagents"] .. ":")
	y = Place(preview.Reagents, heading, body, y + 6)
	local reagents = ns.Reagents(recipeID)
	local columnGap, rowHeight = 10, 50
	local columnWidth = math.max(1, (body:GetWidth() - columnGap) / 2)
	local countFormat = _G["TRADESKILL_REAGENT_COUNT"] or "%s/%d"
	for i, reagent in ipairs(reagents or {}) do
		local row = preview.Rows[i]
		if not row then
			row = ItemRow(body, false)
			preview.Rows[i] = row
		end
		row.itemID = reagent.itemID
		local button = row.Button --[[@as SkillUpPreviewReagentIcon]]
		button:SetReagent({ itemID = reagent.itemID })
		button.Count:Hide()
		local have, need = ns.Have(reagent.itemID), reagent.quantity
		row.Name:SetText(countFormat:format(have, need) .. " " .. ItemName(reagent.itemID))
		local color = have >= need and HIGHLIGHT_FONT_COLOR or (_G["DISABLED_REAGENT_COLOR"] or GRAY_FONT_COLOR)
		row.Name:SetTextColor(color:GetRGB())
		local column, line = (i - 1) % 2, math.floor((i - 1) / 2)
		row:SetPoint("TOPLEFT", body, "TOPLEFT", column * (columnWidth + columnGap), -(y + line * rowHeight))
		row:SetWidth(columnWidth)
		row:Show()
	end
	local reagentCount = reagents and #reagents or 0
	y = y + math.ceil(reagentCount / 2) * rowHeight
	for i = reagentCount + 1, #preview.Rows do
		preview.Rows[i]:Hide()
	end
	local cost = reagents and PriceText(d)
	if not reagents then
		cost = "?"
	end
	y = Place(preview.Cost, cost, body, y)
	body:SetHeight(y)
	preview.Body:SetHeight(CONTENT_TOP + y)
end

---@class SkillUpPreviewSkin
---@field Button fun(button: Button)

---@class SkillUpPreviewEllesmereUI
---@field GetBlizzWindowStyle? fun(window: string): string
---@field RegisterSkin? fun(addon: string, apply: fun(skin: SkillUpPreviewSkin))

local function CreatePreview(page)
	local level = page:GetHighestFrameLevel(true)
	local panel = CreateFrame("Frame", nil, page) --[[@as SkillUpRecipePreview]]
	panel:SetPoint("TOPLEFT", page.SchematicForm, "TOPLEFT")
	-- Create, Create All and the quantity field sit below the schematic, as children of the crafting page.
	-- The preview covers those controls too. It owns no craft action and leaves Blizzard's transaction alone.
	panel:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -5, 5)
	panel:SetFrameLevel(level + 1)
	panel:EnableMouse(true)
	panel.page = page

	local close = CreateFrame("Button", nil, panel, "SharedButtonSmallTemplate") --[[@as Button]]
	local create = page.CreateButton
	if create then
		close:SetPoint("BOTTOMRIGHT", create, "BOTTOMRIGHT")
	else
		close:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -9, 7)
	end
	close:SetText(L["Close"])
	close:SetWidth(math.max(close:GetTextWidth() + 32, create and ns.Readable(create:GetWidth()) or 80))
	close:SetScript("OnClick", ns.CloseRecipePreview)

	-- Ellesmere's public skinning API applies the same button styling it uses for the Create controls.
	local ellesmere = _G.EllesmereUI --[[@as SkillUpPreviewEllesmereUI?]]
	if ellesmere and ellesmere.RegisterSkin then
		ellesmere.RegisterSkin(addonName, function(skin)
			local style = ellesmere.GetBlizzWindowStyle and ellesmere.GetBlizzWindowStyle("professions")
			if style == "eui" or style == "modern" then
				skin.Button(close)
			end
		end)
	end

	local scroll = CreateFrame("ScrollFrame", nil, panel) --[[@as ScrollFrame]]
	scroll:SetPoint("TOPLEFT", 0, -SCROLL_TOP)
	scroll:SetPoint("BOTTOMRIGHT", -17, 38)
	-- Keep mouse-wheel access to long recipes without putting a scrollbar in the crafting pane.
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local offset = self:GetVerticalScroll() - delta * 32
		self:SetVerticalScroll(math.max(0, math.min(offset, self:GetVerticalScrollRange())))
	end)
	scroll:SetScript("OnScrollRangeChanged", function(self, _, range)
		if self:GetVerticalScroll() > range then
			self:SetVerticalScroll(range)
		end
	end)
	local body = CreateFrame("Frame", nil, scroll)
	body:SetSize(1, 1)
	scroll:SetScrollChild(body)
	body:SetPoint("TOPLEFT", scroll, "TOPLEFT")
	scroll:SetScript("OnSizeChanged", Refresh)
	-- The output icon's native quality ring extends past its button. Let the viewport start
	-- outside the content insets so that the complete ring remains visible when scrolled to top.
	local content = CreateFrame("Frame", nil, body)
	content:SetPoint("TOPLEFT", CONTENT_LEFT, -CONTENT_TOP)
	panel.Scroll, panel.Body, panel.Content = scroll, body, content

	panel.Output = ItemRow(content, true)
	panel.Output:SetPoint("TOPLEFT")
	panel.Output:SetPoint("TOPRIGHT")
	panel.Status = Label(content, "GameFontNormalSmall")
	panel.Description = Label(content, "GameFontHighlightSmall2")
	panel.Requirements = Label(content, "GameFontHighlightSmall2")
	panel.Requirements:SetPoint("TOPLEFT", panel.Output.Name, "BOTTOMLEFT", 0, -2)
	panel.Skill = ns.CreateSkillBar()
	panel.Skill:SetParent(content)
	panel.Chance = Label(content, "GameFontHighlightSmall")
	panel.Reagents = Label(content, "GameFontNormalSmall")
	panel.Cost = Label(content, "GameFontNormal")
	panel.Rows = {}

	-- Station range can change without a recipe-list event. Read only the live requirements
	-- each frame, and redo layout only when their displayed value changes.
	panel:SetScript("OnUpdate", function()
		if selected and Requirements(selected.recipeID) ~= panel.Requirements:GetText() then
			Refresh()
		end
	end)
	panel:SetScript("OnHide", ns.CloseRecipePreview)
	panel:Hide()
	return panel
end

---@param button SkillUpPreviewClick
local function OnRowEnter(button)
	local node = button.data
	if not node or not node.recipeInfo or not ns.Usable(GameTooltip) then
		return
	end
	local row = button:GetParent() --[[@as SkillUpRecipeRow]]
	if ns.db.showTooltip then
		ns.ShowRecipeTooltip(ns, row, node)
	elseif row.Label:IsTruncated() then
		GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
		GameTooltip_AddHighlightLine(GameTooltip, node.recipeInfo.name)
		GameTooltip:Show()
	end
end

---@param recipe TradeSkillRecipeInfo
local function HandleNativeRecipeShortcut(recipe)
	-- Preserve Blizzard's shortcuts without invoking the row's selection handler.
	if recipe.skillUpUnlearned then
		return
	end
	local id = recipe.recipeID
	local link = ns.Readable(C_TradeSkillUI.GetRecipeLink(id))
	if link and HandleModifiedItemClick(link) then
		return
	end
	if not IsModifiedClick("RECIPEWATCHTOGGLE") or not Professions.CanTrackRecipe(recipe) then
		return
	end
	local tracked = ns.Readable(C_TradeSkillUI.IsRecipeTracked(id, false))
	if tracked ~= nil then
		C_TradeSkillUI.SetRecipeTracked(id, not tracked, false)
	end
end

---@param page SkillUpCraftingPage
---@param extraScrollBox? SkillUpRecipeScrollBox
function ns.AttachRecipePreview(page, extraScrollBox)
	---@param button SkillUpPreviewClick
	local function OnRowClick(button)
		local node = button.data
		local recipe = node and node.recipeInfo
		if not recipe or ns.GamepadUI() or ForeverCore.ProfessionTabs.Selected() then
			return
		end
		if IsModifiedClick() then
			HandleNativeRecipeShortcut(recipe)
			return
		end
		local row = button:GetParent() --[[@as SkillUpRecipeRow]]
		if ns.Usable(GameTooltip) and GameTooltip:IsOwned(row) then
			GameTooltip:Hide()
		end
		if not preview then
			preview = CreatePreview(page)
		end
		local wasOpen = selected ~= nil
		selected = recipe
		local function UpdateSelection(visibleRow, visibleNode)
			local visibleData = visibleNode and visibleNode:GetData()
			UpdateRowSelection(visibleRow, visibleData and visibleData.recipeInfo)
		end
		page.RecipeList.ScrollBox:ForEachFrame(UpdateSelection)
		if extraScrollBox then
			extraScrollBox:ForEachFrame(UpdateSelection)
		end
		preview:Show()
		Refresh()
		preview.Scroll:SetVerticalScroll(0)
		if not wasOpen then
			ns.Changed("preview")
		end
	end

	-- An addon-owned click target sits on unlearned rows. Native scroll rows are pooled, so bind the
	-- current record on initialization and clear it on release, including when the same row is reused.
	---@param row SkillUpRecipeRow
	---@param data? SkillUpRecipeNodeData
	local function Bind(row, data)
		local info = data and data.recipeInfo
		local button = clicks[row]
		if not info or info.learned ~= false then
			UpdateRowSelection(row, info)
			if button then
				button.data = nil
				button:Hide()
			end
			return
		end
		if not button then
			button = CreateFrame("Button", nil, row) --[[@as SkillUpPreviewClick]]
			button:SetAllPoints()
			button:EnableMouse(true)
			button:RegisterForClicks("LeftButtonUp")
			button.Hover = button:CreateTexture(nil, "HIGHLIGHT")
			button.Hover:SetAllPoints()
			button.Hover:SetColorTexture(1, 1, 1, 0.1)
			if row.SelectedOverlay then
				button.Selection = row:CreateTexture(nil, "OVERLAY", nil, 2)
				button.Selection:SetPoint("CENTER", row, "CENTER", 0, -1)
				button.Selection:Hide()
			end
			button:SetScript("OnEnter", OnRowEnter)
			button:SetScript("OnLeave", GameTooltip_Hide)
			button:SetScript("OnClick", OnRowClick)
			clicks[row] = button
		end
		button.data = data
		button:SetShown(not ns.GamepadUI())
		UpdateRowSelection(row, info)
	end

	-- The native selection event only fires when the ID changes. A plain click on the already-selected
	-- learned recipe also returns to crafting, through the event the native row fires before selection.
	EventRegistry:RegisterCallback("ProfessionsDebug.CraftingRecipeListRecipeClicked", function(_, _, mouse, _, info)
		if mouse == "LeftButton" and not IsModifiedClick() and info and info.learned then
			ns.CloseRecipePreview()
		end
	end, clicks)
	for _, event in ipairs({
		"ProfessionsRecipeListMixin.Event.OnRecipeSelected",
		"Professions.ProfessionSelected",
		"ProfessionsFrame.TabSet",
	}) do
		EventRegistry:RegisterCallback(event, ns.CloseRecipePreview, clicks)
	end
	EventRegistry:RegisterCallback("Professions.CraftingDisplayRefresh", Refresh, clicks)
	page.RecipeList:HookScript("OnHide", ns.CloseRecipePreview)
	ns.WhenEvent("TRADE_SKILL_DATA_SOURCE_CHANGED", ns.CloseRecipePreview)
	ns.WhenEvent("NEW_RECIPE_LEARNED", ns.CloseRecipePreview)
	ns.WhenEvent("INPUT_DEVICE_INTERFACE_TRANSITION" --[[@as WowEvent]], function()
		local gamepad = ns.GamepadUI()
		if gamepad then
			ns.CloseRecipePreview()
		end
		for _, button in pairs(clicks) do
			button:SetShown(button.data ~= nil and not gamepad)
		end
	end)
	ns.WhenStale("recipePreview", Refresh)
	ScrollUtil.AddReleasedFrameCallback(page.RecipeList.ScrollBox, function(_, row)
		Bind(row)
	end, ns)
	return Bind
end
