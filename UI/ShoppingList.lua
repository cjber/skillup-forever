---@type string, SkillUpNamespace
local addonName, ns = ...

if ns.broken then
	return
end
local L = ns.L
local frame
-- The profession the window was opened for, or nil for every tracked plan. Refresh reads it, so a redraw
-- keeps the scope the page asked for.
---@type integer?
local scope
local body, scroll, copyWindow, copyEdit, shown, footer, summary
-- The body's headings, rows and empty state, made once and reused: a refresh shows what it needs and hides the
-- rest, so nothing from an earlier draw is left on the window (#553).
---@type table<string, FontString>
local headingPool = {}
---@type table<string, FontString>
local notePool = {}
---@type { frame: Frame, icon: Texture, name: FontString, detail: FontString }[]
local rowPool = {}
---@type FontString?
local emptyText

local function Name(itemID)
	local name = C_Item.GetItemNameByID(itemID)
	if not name then
		C_Item.RequestLoadItemDataByID(itemID)
		return string.format(L["item %d"], itemID)
	end
	return name
end

local function Copy(text)
	if not copyWindow then
		copyWindow = CreateFrame("Frame", addonName .. "ShoppingCopy", UIParent, "PortraitFrameTemplate")
		table.insert(UISpecialFrames, addonName .. "ShoppingCopy")
		copyWindow:SetSize(460, 380)
		copyWindow:SetFrameStrata("DIALOG")
		copyWindow:SetToplevel(true)
		copyWindow:SetClampedToScreen(true)
		copyWindow:SetMovable(true)
		copyWindow:EnableMouse(true)
		copyWindow:RegisterForDrag("LeftButton")
		copyWindow:SetScript("OnDragStart", function(self)
			self:StartMoving()
		end)
		copyWindow:SetScript("OnDragStop", copyWindow.StopMovingOrSizing)
		copyWindow:SetTitle(L["Copy shopping list"])
		ns.Art.Icon(copyWindow:GetPortrait(), ns.ICON, 62)
		-- Beside the list it copies, not over the Professions window it may cover.
		copyWindow:SetPoint("TOPLEFT", frame, "TOPRIGHT", 8, 0)
		local hint = copyWindow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		hint:SetPoint("TOPLEFT", 70, -32)
		hint:SetPoint("RIGHT", -16, 0)
		hint:SetJustifyH("LEFT")
		hint:SetText(L["The text is selected. Press Ctrl+C (Cmd+C on a Mac) to copy it."])
		local inset = CreateFrame("Frame", nil, copyWindow, "InsetFrameTemplate")
		inset:SetPoint("TOPLEFT", 10, -64)
		inset:SetPoint("BOTTOMRIGHT", -10, 10)
		local sf = CreateFrame("ScrollFrame", nil, inset, "ScrollFrameTemplate")
		sf:SetPoint("TOPLEFT", 8, -8)
		sf:SetPoint("BOTTOMRIGHT", -28, 8)
		copyEdit = CreateFrame("EditBox", nil, sf)
		copyEdit:SetMultiLine(true)
		copyEdit:SetAutoFocus(false)
		copyEdit:SetFontObject("ChatFontNormal")
		copyEdit:SetWidth(390)
		copyEdit:SetMaxLetters(0)
		copyEdit:SetScript("OnTextChanged", function(self, userInput)
			if userInput then
				self:SetText(shown)
				self:SetFocus()
				self:HighlightText()
			end
		end)
		-- The client calls a focus handler as handler(self, isUserInput), so passing the method bare would land the
		-- flag in HighlightText's start index (#622, the same shape as #269).
		copyEdit:SetScript("OnEditFocusGained", function(self)
			self:HighlightText()
		end)
		copyEdit:SetScript("OnEscapePressed", function()
			copyWindow:Hide()
		end)
		sf:SetScrollChild(copyEdit)
	end
	shown = text
	copyEdit:SetText(text)
	copyWindow:Show()
	copyEdit:SetFocus()
	copyEdit:HighlightText()
end

-- The one heading this source draws, made on its first row and reused after.
---@param source string
---@return FontString
local function Heading(source)
	local heading = headingPool[source]
	if not heading then
		heading = body:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		headingPool[source] = heading
	end
	return heading
end

-- The note under a source's heading, made on its first draw and reused after, like a heading (#554).
---@param source string
---@return FontString
local function Note(source)
	local note = notePool[source]
	if not note then
		note = body:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		note:SetWidth(520)
		note:SetJustifyH("LEFT")
		note:SetWordWrap(true)
		notePool[source] = note
	end
	return note
end

-- A row's parts, drawn once when the pool needs another row.
---@return { frame: Frame, icon: Texture, name: FontString, detail: FontString }
local function NewRow()
	local item = CreateFrame("Frame", nil, body)
	item:SetSize(520, 48)
	local icon = item:CreateTexture(nil, "ARTWORK")
	icon:SetSize(32, 32)
	icon:SetPoint("LEFT", 0, 0)
	local name = item:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 0)
	name:SetWidth(460)
	local detail = item:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	detail:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, 0)
	detail:SetWidth(460)
	detail:SetHeight(28)
	detail:SetWordWrap(true)
	return { frame = item, icon = icon, name = name, detail = detail }
end

local function Refresh()
	if not frame or not frame:IsShown() then
		return
	end
	for _, heading in pairs(headingPool) do
		heading:Hide()
	end
	for _, note in pairs(notePool) do
		note:Hide()
	end
	local lists = ns.ShoppingList(scope)
	-- The window groups by source, not profession, so the header names every plan it is buying for: the
	-- profession the page asked for, or every tracked plan when none did.
	local plans = {}
	local summaryText
	for _, list in ipairs(lists) do
		plans[#plans + 1] = string.format(L["%s to %d"], list.profession, list.target)
	end
	if #plans > 0 then
		summaryText = string.format(L["Buying for %s"], table.concat(plans, ", "))
	elseif scope then
		local profession = ns.RouteProfessions()[scope] or ns.PlayerProfessions()[scope]
		summaryText = string.format(
			L["Nothing is tracked for %s."],
			profession and profession.name or string.format(L["profession %d"], scope)
		)
	else
		summaryText = ""
	end
	summary:SetText(summaryText)
	local top, any, total, unpriced, drawn = -10, false, 0, 0, 0
	local headings =
		{ gather = L["Gather"], vendor = L["Vendor"], auction = L["Auction house"], unknown = L["Unknown"] }
	for _, source in ipairs(ns.Model.SHOPPING_SOURCES) do
		local entries = {}
		for _, list in ipairs(lists) do
			for _, row in ipairs(list.items) do
				if row.source == source and row.missing > 0 then
					entries[#entries + 1] = { list = list, row = row }
				end
			end
		end
		if #entries > 0 then
			any = true
			local heading = Heading(source)
			heading:ClearAllPoints()
			heading:SetPoint("TOPLEFT", 8, top)
			heading:SetText(headings[source])
			heading:Show()
			top = top - 28
			if source == "auction" then
				local names, seen = {}, {}
				for _, entry in ipairs(entries) do
					local name = ns.AuctionListName(entry.list.profession)
					if name and not seen[name] then
						seen[name] = true
						names[#names + 1] = name
					end
				end
				local note = Note(source)
				note:ClearAllPoints()
				note:SetPoint("TOPLEFT", 8, top)
				note:SetText(ns.AuctionListNote(names))
				note:Show()
				top = top - 46
			end
			for _, entry in ipairs(entries) do
				drawn = drawn + 1
				local pooled = rowPool[drawn]
				if not pooled then
					pooled = NewRow()
					rowPool[drawn] = pooled
				end
				local row = entry.row
				local item = pooled.frame
				item:ClearAllPoints()
				item:SetPoint("TOPLEFT", 8, top)
				item:Show()
				pooled.icon:SetTexture(C_Item.GetItemIconByID(row.itemID)) -- art-ok: square item icons keep their native aspect.
				pooled.name:SetText(
					string.format(L["%s (%s to %d)"], Name(row.itemID), entry.list.profession, entry.list.target)
				)
				local alt = row.alt[1] and string.format(L["on %s"], row.alt[1].name) or ""
				local unit = row.price and ns.FormatNet(ns.Model.RoundMoney(row.price), false) or L["price unknown"]
				local cost = row.cost and ns.FormatNet(ns.Model.RoundMoney(row.cost), false) or "-"
				pooled.detail:SetText(
					string.format(
						L["Need %d, have %d, missing %d  %s  %s each  %s"],
						row.need,
						row.have,
						row.missing,
						alt,
						unit,
						cost
					)
				)
				if row.cost then
					total = total + row.cost
				elseif row.missing > 0 then
					unpriced = unpriced + 1
				end
				top = top - 50
			end
		end
	end
	for index = drawn + 1, #rowPool do
		rowPool[index].frame:Hide()
	end
	if not any then
		if not emptyText then
			emptyText = body:CreateFontString(nil, "ARTWORK", "GameFontNormal")
			emptyText:SetPoint("CENTER")
		end
		emptyText:SetText(#lists == 0 and L["No tracked profession"] or L["Nothing to buy"])
		emptyText:Show()
	elseif emptyText then
		emptyText:Hide()
	end
	body:SetHeight(math.max(1, -top + 20))
	footer:SetText(
		L["Total for priced items: "]
			.. ns.FormatNet(ns.Model.RoundMoney(total), false)
			.. (unpriced > 0 and string.format(L["  %d items have no price yet"], unpriced) or "")
	)
end

local function Create()
	if frame then
		return frame
	end
	frame = CreateFrame("Frame", addonName .. "ShoppingList", UIParent, "PortraitFrameTemplate")
	table.insert(UISpecialFrames, addonName .. "ShoppingList")
	frame:SetSize(620, 500)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetTitle(L["Shopping list"])
	ns.Art.Icon(frame:GetPortrait(), ns.ICON, 62)
	-- Clear of the portrait, which overhangs the top-left corner, and above the list.
	summary = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	summary:SetPoint("TOPLEFT", 82, -36)
	summary:SetPoint("RIGHT", -16, 0)
	summary:SetJustifyH("LEFT")
	summary:SetHeight(28)
	local inset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", 10, -70)
	inset:SetPoint("BOTTOMRIGHT", -10, 48)
	scroll = CreateFrame("ScrollFrame", nil, inset, "ScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 8, -8)
	scroll:SetPoint("BOTTOMRIGHT", -28, 8)
	body = CreateFrame("Frame", nil, scroll)
	body:SetWidth(550)
	scroll:SetScrollChild(body)
	footer = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	footer:SetPoint("BOTTOMRIGHT", -16, 18)
	footer:SetJustifyH("RIGHT")
	footer:SetWidth(330)
	footer:SetHeight(30)
	footer:SetWordWrap(true)
	local copy = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate")
	copy:SetSize(110, 24)
	copy:SetPoint("BOTTOMLEFT", 16, 14)
	copy:SetText(L["Copy list"])
	copy:SetScript("OnClick", function()
		Copy(ns.ShoppingText())
	end)
	local trip = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate")
	trip:SetSize(130, 24)
	trip:SetPoint("LEFT", copy, "RIGHT", 8, 0)
	trip:SetText(L["Plan buy trip"])
	local api = ShortestPathForever and ShortestPathForever.API
	trip:SetEnabled(api and type(api.NavigateRoute) == "function")
	trip:SetScript("OnClick", function()
		ns.ShoppingTrip()
	end)
	trip:SetScript("OnEnter", function(self)
		if not self:IsEnabled() then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip_SetTitle(GameTooltip, L["A buy trip needs Shortest Path Forever."])
			GameTooltip:Show()
		end
	end)
	trip:SetScript("OnLeave", GameTooltip_Hide)
	frame:SetScript("OnShow", Refresh)
	frame:Hide()
	return frame
end

local ready, enteredWorld, variablesLoaded, pendingOpen, pendingScope = false, false, false, false, nil
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("VARIABLES_LOADED")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_ENTERING_WORLD" then
		enteredWorld = true
	else
		variablesLoaded = true
	end
	if not (enteredWorld and variablesLoaded) or ready then
		return
	end
	ready = true
	C_Timer.After(0, function()
		Create()
		if pendingOpen then
			scope = pendingScope
			frame:Show()
			Refresh()
			pendingOpen, pendingScope = false, nil
		end
	end)
end)

---@param skillLine integer? show only this profession's plan; nil shows every tracked plan
function ns.OpenShoppingList(skillLine)
	if not ready then
		pendingOpen, pendingScope = true, skillLine
		return
	end
	local window = Create()
	scope = skillLine
	window:Show()
	Refresh()
end
ns.WhenStale("shoppingList", Refresh)
