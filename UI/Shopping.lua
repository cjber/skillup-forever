---@type string, SkillUpNamespace
local _, ns = ...

if ns.broken then
	return
end
local L = ns.L

local CALLER = "SkillUp Forever"
-- Missing reagents shown per profession before "...".
local MAX_OBJECTIVES = 6
-- The header menu lists each missing vendor item, so it scrolls past 20 rows of 20 px (WFA-36).
local MENU_EXTENT = 20 * 20

---@type SkillUpTrackerModule?
local module

---@return boolean
function ns.HasAuctionator()
	local api = Auctionator and Auctionator.API and Auctionator.API.v1
	return api and api.CreateShoppingList and api.ConvertToSearchString and true or false
end

-- The last count the client let us read per item, for when it hands over a secret one.
local lastCounts = {}

-- Bags and bank: the client knows bank counts once the bank has been opened. A secret count would turn every
-- sum, comparison and cache it reaches secret until a reload, so it reads as the last count seen instead.
---@param itemID integer
---@return number
function ns.Have(itemID)
	local count = ns.Readable(C_Item.GetItemCount(itemID, true))
	if count then
		lastCounts[itemID] = count
		return count
	end
	return lastCounts[itemID] or 0
end

-- What your other characters on this realm and faction hold (bags, bank, mail),
-- most first, when Syndicator is installed: they can mail it over.
---@param itemID integer
---@return {name: string, count: number}[]
function ns.AltCounts(itemID)
	local api = Syndicator and Syndicator.API
	if not (api and api.GetInventoryInfoByItemID and api.IsReady and api.IsReady()) then
		return {}
	end
	local info = api.GetInventoryInfoByItemID(itemID, true, true)
	local me, realm = UnitName("player"), ns.NormalizedRealm()
	local alts = {}
	for _, character in ipairs(info and info.characters or {}) do
		local count = character.bags + character.bank + character.mail
		if count > 0 and not (character.character == me and character.realmNormalized == realm) then
			alts[#alts + 1] = { name = character.character, count = count }
		end
	end
	table.sort(alts, function(a, b)
		return a.count > b.count
	end)
	return alts
end

-- Auctionator searches by name, and names of unseen items arrive asynchronously.
---@param items SkillUpShoppingItem[]
---@param callback fun()
local function WithNames(items, callback)
	local container = ContinuableContainer:Create()
	for _, item in ipairs(items) do
		container:AddContinuable(Item:CreateFromItemID(item.itemID))
	end
	container:ContinueOnLoad(callback)
end
ns.WithItemNames = WithNames

-- Auctionator replaces same-named lists account-wide, so each character owns its own namespace.
---@param profession string
---@return string?
function ns.AuctionListName(profession)
	local character = ns.CharacterKey()
	return character and ("SkillUp: " .. character .. ": " .. profession) or nil
end

-- What the Shopping list says under Auction house, and the auction bar's Search tooltip says in one line (#554).
-- `names` are the Auctionator lists this character's tracked routes write, in the window's order.
---@param names string[]?
---@return string
function ns.AuctionListNote(names)
	if not ns.HasAuctionator() then
		return L["Without Auctionator, a recipe's Search button fills the game's own auction box one reagent at a time."]
	end
	if ns.CollectMode() ~= "auction" then
		return L["Turning Buy reagents on writes an Auctionator list with every auction reagent still missing."]
	end
	local listed = names and #names > 0 and table.concat(names, ", ") or L["SkillUp's list"]
	return string.format(
		L["Auctionator list: %s. Open the auction house, Shopping tab, pick it and Search; buy each row with a click."],
		listed
	)
end

-- Auctionator's own "scan when the auction house opens" option, read through its config table. nil
-- when it cannot be read: it is not part of Auctionator's public API.
---@return boolean?
function ns.AuctionatorAutoscan()
	local ok, value = pcall(function()
		local config = Auctionator and Auctionator.Config
		if not (config and config.Options) then
			return nil
		end
		return config.Get(config.Options.AUTO_LIST_SEARCH)
	end)
	if ok and type(value) == "boolean" then
		return value
	end
	return nil
end

-- The auction house reagents a route still needs: what no vendor sells and this character buys. Written only
-- with Buy reagents on, where a material you gather shows as gathered only while nothing prices it.
---@param items SkillUpNeededItem[]
---@return SkillUpShoppingItem[]
local function MissingFromAuction(items)
	local missing = {}
	for _, item in ipairs(items) do
		local count = item.need - ns.Have(item.itemID)
		if (item.source == "auction" or item.source == "unknown" or item.source == "gather") and count > 0 then
			missing[#missing + 1] = { itemID = item.itemID, count = count }
		end
	end
	return missing
end

---@param name string
---@param missing SkillUpShoppingItem[]
local function WriteAuctionList(name, missing)
	local api = Auctionator.API.v1
	if #missing == 0 then
		api.CreateShoppingList(CALLER, name, {})
		return
	end
	WithNames(missing, function()
		local searches = {}
		for _, item in ipairs(missing) do
			searches[#searches + 1] = api.ConvertToSearchString(CALLER, {
				-- WithNames fires only after every item record is cached.
				searchString = assert(C_Item.GetItemNameByID(item.itemID)),
				isExact = true,
				quantity = item.count,
			})
		end
		api.CreateShoppingList(CALLER, name, searches)
	end)
end

-- The list last written for each profession, so an unchanged need leaves Auctionator alone.
local auctionLists = {}

---@param missing SkillUpShoppingItem[]
---@return string
local function AuctionSignature(missing)
	local parts = {}
	for index, item in ipairs(missing) do
		parts[index] = item.itemID .. "x" .. item.count
	end
	return table.concat(parts, ",")
end

-- Keep every tracked route's Auctionator list up to date with what it still buys, empties one it no
-- longer needs, and leaves an unchanged list alone. Gather mode buys nothing, so it is left as it is.
local function SyncAuctionator()
	if not ns.HasAuctionator() or ns.CollectMode() ~= "auction" or ns.db.auctionSearch == false then
		return
	end
	for _, entry in ipairs(ns.TrackedNeeds()) do
		local name = ns.AuctionListName(entry.plan.profession.name)
		local missing = MissingFromAuction(entry.items)
		local signature = AuctionSignature(missing)
		if name and auctionLists[name] ~= signature then
			auctionLists[name] = signature
			WriteAuctionList(name, missing)
		end
	end
end

---@param skillLine integer?
---@return boolean
function ns.IsTracked(skillLine)
	return ns.db.trackedProfessions[skillLine] == true
end

-- Starts tracking the profession the player just opened, its own window or a trainer that teaches it,
-- when its route still has steps, so the tracker and the where-to-train hints arrive without a hunt.
-- A saved true (tracked) or false (stopped by hand) is a decision already made and is left alone.
---@param skillLine integer?
---@return boolean started
function ns.AutoTrack(skillLine)
	if not skillLine or ns.db.trackedProfessions[skillLine] ~= nil then
		return false
	end
	local profession = ns.RouteProfessions()[skillLine]
	if not profession or #ns.PlanRoute(profession).steps == 0 then
		return false
	end
	ns.db.trackedProfessions[skillLine] = true
	ns.Changed("tracking")
	return true
end

-- The tracked routes' material lists. A plan change, a price or a merchant's stock drops them: RouteReagents
-- reads those without asking for a new plan, so the plan alone is not the whole key. Item data drops nothing
-- here: it arrives for any item, from any addon, and the one item-data input this list reads is a vendor sell
-- price (Integrations/Prices.lua's SellPrice), which reports `prices` when it arrives. A bag change is the
-- one input whose effect the key can tell apart: it reads each plan and the tools the bags still lack, so a
-- tool picked up rebuilds the list while a bag of unrelated loot leaves it alone. The tracker, the merchant
-- tab, the public API and the tooltip index share one build.
---@type { key: string, tracked: SkillUpTracked[] }?
local trackedNeeds

ns.WhenStale("trackedNeeds", function()
	trackedNeeds = nil
end)

-- The plan of every tracked profession of this character with the reagents it
-- still needs, so it follows skill, target and prices.
---@return SkillUpTracked[]
function ns.TrackedNeeds()
	local professions = ns.RouteProfessions()
	local tracked, key = {}, {}
	for skillLine, profession in pairs(professions) do
		if ns.IsTracked(skillLine) then
			tracked[#tracked + 1] = profession
		end
	end
	table.sort(tracked, function(a, b)
		return a.name < b.name
	end)
	for index, profession in ipairs(tracked) do
		local plan = ns.PlanRoute(profession)
		tracked[index] = { plan = plan }
		key[#key + 1] = tostring(plan)
		key[#key + 1] = table.concat(ns.MissingToolItems(plan), ",")
	end
	local signature = table.concat(key, ";")
	if trackedNeeds and trackedNeeds.key == signature then
		return trackedNeeds.tracked
	end
	for _, entry in ipairs(tracked) do
		entry.items = ns.RouteReagents(entry.plan)
	end
	trackedNeeds = { key = signature, tracked = tracked }
	return tracked
end

-- What the open merchant sells for gold of the tracked reagents still missing,
-- and its cost. Two professions sharing a reagent need both amounts.
local function MerchantPurchases()
	local missing = {}
	for _, entry in ipairs(ns.TrackedNeeds()) do
		for _, item in ipairs(entry.items) do
			missing[item.itemID] = (missing[item.itemID] or -ns.Have(item.itemID)) + item.need
		end
	end
	local purchases, cost = {}, 0
	for index = 1, GetMerchantNumItems() do
		local itemID = GetMerchantItemID(index)
		local info = C_MerchantFrame.GetItemInfo(index)
		local count = itemID and missing[itemID]
		if
			count
			and count > 0
			and info
			and info.price
			and info.price > 0
			and info.stackCount
			and info.stackCount > 0
			and not info.hasExtendedCost
		then
			local stack = info.stackCount
			count = math.ceil(count / stack) * stack
			if info.numAvailable and info.numAvailable >= 0 then
				count = math.min(count, info.numAvailable * stack)
			end
			if count > 0 then
				local itemCost = info.price * count / stack
				purchases[#purchases + 1] = { index = index, count = count, stack = stack, cost = itemCost }
				cost = cost + itemCost
			end
		end
	end
	return purchases, cost
end

-- BuyMerchantItem is protected: called from addon code it taints the client's merchant path, and the
-- player's own purchases can then be refused until /reload (#327). This client has no secure attribute
-- that buys a chosen quantity, so the addon does not buy at all: the button lists what the route still
-- needs and the player buys it from the merchant's own window.

-- What is missing here, for the prompt: the first few items by name and how many more.
local LISTED_PURCHASES = 4

---@param purchases {index: integer, count: integer}[]
---@return string
local function PurchaseList(purchases)
	local parts = {}
	for index, purchase in ipairs(purchases) do
		if index > LISTED_PURCHASES then
			parts[#parts + 1] = string.format(L["%d more"], #purchases - LISTED_PURCHASES)
			break
		end
		local info = C_MerchantFrame.GetItemInfo(purchase.index)
		local name = info and info.name or C_Item.GetItemNameByID(GetMerchantItemID(purchase.index)) or UNKNOWN
		parts[#parts + 1] = string.format(L["%d %s"], purchase.count, name)
	end
	return table.concat(parts, ", ")
end

-- What the tracked routes still need here, on the merchant's window so it goes when the merchant does.
-- The player buys it from the merchant's own window; the addon only shows what and how much.
---@class SkillUpBuyConfirm : Frame
---@field Text FontString
---@field Close Button
---@field cost number?
---@type SkillUpBuyConfirm?
local confirm

local function HideConfirm()
	if confirm then
		confirm.cost = nil
		confirm:Hide()
	end
end

---@return SkillUpBuyConfirm
local function Confirm()
	if confirm then
		return confirm
	end
	local frame = CreateFrame("Frame", nil, MerchantFrame) --[[@as SkillUpBuyConfirm]]
	frame:SetSize(320, 112)
	frame:SetPoint("TOP", MerchantFrame, "TOP", 0, -72)
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	CreateFrame("Frame", nil, frame, "DialogBorderOpaqueTemplate"):SetAllPoints()
	frame.Text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	frame.Text:SetPoint("TOPLEFT", 20, -18)
	frame.Text:SetPoint("TOPRIGHT", -20, -18)
	frame.Text:SetJustifyH("CENTER")
	frame.Close = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate") --[[@as Button]]
	frame.Close:SetSize(110, 22)
	frame.Close:SetPoint("BOTTOM", frame, "BOTTOM", 0, 16)
	frame.Close:SetText(L["Close"])
	frame.Close:SetScript("OnClick", HideConfirm)
	frame:Hide()
	confirm = frame
	return frame
end

-- What is missing here and what it costs; the player buys it from the merchant's own window.
local function AskToBuy()
	local purchases, cost = MerchantPurchases()
	if #purchases == 0 then
		return
	end
	local frame = Confirm()
	frame.cost = cost
	frame.Text:SetText(
		string.format(
			"%s  %s  %s",
			L["Reagents still needed"],
			PurchaseList(purchases),
			C_CurrencyInfo.GetCoinTextureString(cost)
		)
	)
	frame:Show()
end

-- The merchant's own Reagents tab: a third tab in the same bottom art as Merchant and Buyback, shown only while
-- this merchant sells something a tracked route still needs. Its page draws item cells over the merchant's item
-- grid and puts Buy all where the page row was. The stock tabs and their content are only ever hidden by alpha:
-- Blizzard still decides what is shown, so leaving the tab puts the window back exactly as it was.

---@class SkillUpMerchantItemButton : Button
---@field icon Texture # The intrinsic ItemButton's icon; the older ItemButtonTemplate calls it Icon.
---@field Count FontString
---@field SplitStack fun()?
---@field merchantIndex integer?

---@class SkillUpMerchantItemFrame : Frame
---@field Name FontString
---@field ItemButton SkillUpMerchantItemButton

---@class SkillUpMerchantCell
---@field frame SkillUpMerchantItemFrame
---@field button SkillUpMerchantItemButton
---@field icon Texture
---@field name FontString
---@field price FontString

---@class SkillUpMerchantPage : Frame
---@field Items SkillUpMerchantCell[]

-- Two columns of five merchant cells, at the stock item frame's own size and gaps.
-- The template the merchant window's own tabs inherit in the client's Mainline MerchantFrame.xml. The Vanilla
-- CharacterFrameTabButtonTemplate is not loaded by the Forever client, so CreateFrame would fail on every open.
local TAB_TEMPLATE = "PanelTabButtonTemplate"
local CELLS_PER_PAGE = 10
local CELL_WIDTH, CELL_HEIGHT = 153, 44
local COLUMN_GAP, ROW_GAP = 12, 8
local CELL_LEFT, CELL_TOP = 4, -9
-- The stock window's page row, which the page covers. The buyback cell stays: it sits in the bottom bar with the
-- repair buttons, outside the page, where a cell hidden by alpha alone would still buy back on a click.
local STOCK_CONTENT = { "MerchantPageText", "MerchantPrevPageButton", "MerchantNextPageButton" }

---@type SkillUpMerchantPage?
local merchantPage
---@type Button?
local merchantTab
---@type Button?
local merchantBuyAll
---@type Button?
local merchantCover
---@type Frame?
local coveredTab
local merchantSelected, merchantShown = false, false
---@type {index: integer, count: integer, cost: number}[]
local merchantPurchases = {}
local merchantTotal = 0
local merchantPageIndex, merchantPageCount = 1, 1

---@type fun(selected: boolean)
local SelectMerchantTab

-- The cover over the stock tab that was selected before this one. It is our own copy in the unselected art, so
-- Merchant and Buyback never look selected beside Reagents, and a click on it returns to that tab.
local function HideCover()
	if coveredTab then
		coveredTab:SetAlpha(1)
		coveredTab = nil
	end
	if merchantCover then
		merchantCover:Hide()
	end
end

---@param tabID integer
local function ShowCover(tabID)
	local native = _G["MerchantFrameTab" .. tabID] --[[@as Button?]]
	if not (native and native:IsShown()) then
		HideCover()
		return
	end
	if not merchantCover then
		local cover = CreateFrame("Button", "SkillUpForeverMerchantTabCover", MerchantFrame, TAB_TEMPLATE)
		merchantCover = cover --[[@as Button]]
		merchantCover:Hide()
		merchantCover:SetScript("OnClick", function()
			SelectMerchantTab(false)
		end)
	end
	if coveredTab and coveredTab ~= native then
		coveredTab:SetAlpha(1)
	end
	merchantCover:SetText(native:GetText() or "")
	PanelTemplates_DeselectTab(merchantCover)
	merchantCover:Show()
	if merchantCover.SetFrameLevel then
		merchantCover:SetFrameLevel(native:GetFrameLevel() + 1)
	end
	merchantCover:ClearAllPoints()
	merchantCover:SetPoint("TOPLEFT", native, "TOPLEFT")
	merchantCover:SetSize(native:GetWidth(), native:GetHeight())
	native:SetAlpha(0)
	coveredTab = native
end

-- The stock content frames stay where Blizzard put them; alpha keeps which ones Blizzard shows and leaves the
-- window's height, page and scroll alone when the player goes back.
---@param hidden boolean
local function HideStockContent(hidden)
	local alpha = hidden and 0 or 1
	for index = 1, 12 do
		local item = _G["MerchantItem" .. index]
		if item then
			item:SetAlpha(alpha)
		end
	end
	for _, name in ipairs(STOCK_CONTENT) do
		local frame = _G[name]
		if frame then
			frame:SetAlpha(alpha)
		end
	end
end

---@param selected boolean
SelectMerchantTab = function(selected)
	if selected and (not ns.db.merchantButton or #merchantPurchases == 0 or not merchantTab) then
		selected = false
	end
	if selected == merchantSelected then
		return
	end
	merchantSelected = selected
	if selected then
		---@cast merchantTab Button
		---@cast merchantPage SkillUpMerchantPage
		PanelTemplates_SelectTab(merchantTab)
		HideStockContent(true)
		merchantPage:Show()
		ShowCover(MerchantFrame.selectedTab or 1)
	else
		if merchantPage then
			merchantPage:Hide()
		end
		HideCover()
		HideStockContent(false)
		if merchantTab then
			PanelTemplates_DeselectTab(merchantTab)
		end
	end
end

---@param index integer
---@return SkillUpMerchantCell
local function CreateMerchantCell(index)
	-- The merchant's own item cell: its slot, label art, name and item button. Its click buys, which the addon
	-- never does, so the scripts the template brought are replaced by a tooltip only.
	-- Named, as the template names its regions and item button after the cell ("$parentName").
	local name = "SkillUpForeverMerchantItem" .. index
	local frame = CreateFrame("Frame", name, merchantPage, "MerchantItemTemplate") --[[@as SkillUpMerchantItemFrame]]
	frame:SetSize(CELL_WIDTH, CELL_HEIGHT)
	local button = frame.ItemButton --[[@as SkillUpMerchantItemButton]]
	-- The template's own money frame and alternate currency frame are not used: the cost of the whole stack is
	-- one coin string under the name.
	for _, child in ipairs({ frame:GetChildren() }) do
		if child ~= button and child ~= frame.Name then
			child:Hide()
		end
	end
	button:SetScript("OnClick", nil)
	button:SetScript("OnDragStart", nil)
	button.SplitStack = nil
	button:SetScript("OnEnter", function(self)
		if not self.merchantIndex then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetMerchantItem(self.merchantIndex)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	-- The template's ItemButton is the client's intrinsic ItemButton, whose icon region is `icon` (lowercase, named
	-- $parentIconTexture), where the older ItemButtonTemplate called it `Icon`. The client's own reader finds either,
	-- so the cell keeps the region itself instead of a key the template may not have (#447).
	local icon = GetItemButtonIconTexture(button) --[[@as Texture]]
	local price = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	price:SetPoint("TOPLEFT", frame.Name, "BOTTOMLEFT", 0, 0)
	return { frame = frame, button = button, icon = icon, name = frame.Name, price = price }
end

local RenderMerchantPage

local function EnsureMerchantFrames()
	if merchantTab then
		return
	end
	-- Selecting either stock tab leaves our page; the stock click runs first, so its content is already back.
	for index = 1, 2 do
		local stock = _G["MerchantFrameTab" .. index]
		if stock then
			stock:HookScript("OnClick", function()
				SelectMerchantTab(false)
			end)
		end
	end
	local tab = CreateFrame("Button", "SkillUpForeverMerchantTab", MerchantFrame, TAB_TEMPLATE)
	merchantTab = tab --[[@as Button]]
	merchantTab:SetID(3)
	merchantTab:SetText(L["Reagents"])
	merchantTab:SetPoint("LEFT", _G["MerchantFrameTab2"], "RIGHT", -16, 0)
	merchantTab:SetScript("OnClick", function()
		SelectMerchantTab(true)
	end)
	PanelTemplates_DeselectTab(merchantTab)

	merchantPage = CreateFrame("Frame", "SkillUpForeverMerchantPage", MerchantFrame) --[[@as SkillUpMerchantPage]]
	merchantPage:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", 7, -60)
	merchantPage:SetPoint("BOTTOMRIGHT", MerchantFrame, "BOTTOMRIGHT", -7, 52)
	merchantPage:SetFrameLevel(MerchantFrame:GetFrameLevel() + 10)
	merchantPage:EnableMouse(true)
	merchantPage:EnableMouseWheel(true)
	merchantPage:SetScript("OnMouseWheel", function(_, delta)
		if merchantPageCount <= 1 then
			return
		end
		local page = math.max(1, math.min(merchantPageCount, merchantPageIndex + (delta > 0 and -1 or 1)))
		if page ~= merchantPageIndex then
			merchantPageIndex = page
			RenderMerchantPage()
		end
	end)
	merchantPage:Hide()
	merchantPage.Items = {}
	for index = 1, CELLS_PER_PAGE do
		local cell = CreateMerchantCell(index)
		local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
		cell.frame:SetPoint(
			"TOPLEFT",
			merchantPage,
			"TOPLEFT",
			CELL_LEFT + column * (CELL_WIDTH + COLUMN_GAP),
			CELL_TOP - row * (CELL_HEIGHT + ROW_GAP)
		)
		merchantPage.Items[index] = cell
	end

	local buy = CreateFrame("Button", "SkillUpForeverMerchantBuyAll", merchantPage, "SharedButtonSmallTemplate")
	merchantBuyAll = buy --[[@as Button]]
	merchantBuyAll:SetPoint("BOTTOM", merchantPage, "BOTTOM", 0, 33)
	merchantBuyAll:SetScript("OnClick", AskToBuy)
end

-- The page shows what the merchant sells that the routes still need, whole stacks and all, at the cost of those
-- stacks. More than ten kinds page with the wheel so every one is reachable; the page row itself is Buy all.
RenderMerchantPage = function()
	merchantPageCount = math.max(1, math.ceil(#merchantPurchases / CELLS_PER_PAGE))
	if merchantPageIndex > merchantPageCount then
		merchantPageIndex = merchantPageCount
	end
	---@cast merchantPage SkillUpMerchantPage
	local first = (merchantPageIndex - 1) * CELLS_PER_PAGE
	for index, cell in ipairs(merchantPage.Items) do
		local purchase = merchantPurchases[first + index]
		if purchase then
			local itemID = GetMerchantItemID(purchase.index)
			local info = C_MerchantFrame.GetItemInfo(purchase.index)
			cell.name:SetText((info and info.name) or C_Item.GetItemNameByID(itemID) or UNKNOWN)
			cell.price:SetText(C_CurrencyInfo.GetCoinTextureString(purchase.cost))
			cell.button.merchantIndex = purchase.index
			local icon = (info and info.texture) or C_Item.GetItemIconByID(itemID)
			if icon then
				cell.icon:SetTexture(icon) -- art-ok: an item icon keeps its own square shape
			else
				cell.icon:SetTexture(nil) -- art-ok: clears another item's icon, so no shape is drawn
			end
			cell.button.Count:SetText(purchase.count > 1 and tostring(purchase.count) or "")
			cell.frame:Show()
		else
			cell.button.merchantIndex = nil
			cell.button.Count:SetText("")
			cell.frame:Hide()
		end
	end
	---@cast merchantBuyAll Button
	merchantBuyAll:SetText(L["Buy all"] .. "  " .. C_CurrencyInfo.GetCoinTextureString(merchantTotal))
	merchantBuyAll:SetSize(merchantBuyAll:GetTextWidth() + 32, 22)
end

local function RefreshMerchant()
	local shown = MerchantFrame ~= nil and MerchantFrame:IsShown()
	if shown ~= merchantShown then
		if not shown then
			SelectMerchantTab(false)
		end
		merchantShown = shown
	end
	local purchases, cost = {}, 0
	if ns.db.merchantButton and shown then
		purchases, cost = MerchantPurchases()
	end
	merchantPurchases, merchantTotal = purchases, cost
	-- Whatever the player agreed to is out of date once the merchant, the bags or the route change.
	if confirm and confirm.cost ~= cost then
		HideConfirm()
	end
	if #purchases == 0 then
		SelectMerchantTab(false)
		if merchantTab then
			merchantTab:Hide()
		end
		if merchantPage then
			merchantPage:Hide()
		end
		return
	end
	EnsureMerchantFrames()
	RenderMerchantPage()
	---@cast merchantTab Button
	merchantTab:Show()
	if merchantSelected then
		---@cast merchantPage SkillUpMerchantPage
		merchantPage:Show()
		HideStockContent(true)
		ShowCover(MerchantFrame.selectedTab or 1)
	end
end

---@return boolean
function ns.TrackerAttached()
	return module ~= nil and ForeverCore.TrackerHost.IsAttached(module)
end

-- A burst of bag, skill or recipe events marks the tracker dirty many times in one frame; the host already
-- lays it out once, and the merchant tab is rebuilt once too, after the burst, so each event is not a
-- replan of every tracked route. A closed merchant takes the immediate path, since there is nothing to draw.
local merchantPending = false
local function RefreshTracker()
	SyncAuctionator()
	if module and ns.db.showTracker then
		module:MarkDirty()
	end
	if not (ns.db.merchantButton and MerchantFrame ~= nil and MerchantFrame:IsShown()) then
		RefreshMerchant()
		return
	end
	if merchantPending then
		return
	end
	merchantPending = true
	C_Timer.After(0, function()
		merchantPending = false
		RefreshMerchant()
	end)
end

-- The saved choice itself, without the client's click sound: the public API sets it quietly.
---@param skillLine integer
---@param tracked boolean
function ns.SetTracked(skillLine, tracked)
	-- false is kept, not dropped: it is the player saying stop, which AutoTrack honours.
	ns.db.trackedProfessions[skillLine] = tracked
	ns.Changed("tracking")
end

-- The player's own click on a Track button: the same choice, with the checkbox sound.
---@param skillLine integer
---@param tracked boolean
function ns.SetTrackedByPlayer(skillLine, tracked)
	ns.SetTracked(skillLine, tracked)
	PlaySound(tracked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
end

---@class SkillUpModuleMixin : SkillUpTrackerModule
local ModuleMixin = { headerText = L["Profession reagents"] }

---@param block SkillUpTrackerBlock
function ModuleMixin:OnBlockHeaderClick(block)
	ForeverCore.ContextMenu(self:GetContextMenuParent(), function(_, root)
		root:SetScrollMode(MENU_EXTENT)
		root:CreateTitle(block.profession)
		-- Only while this profession is open: the client crafts from the open one.
		local craft = ns.NextCraft(block.plan)
		local recipeID = craft.recipeID
		if recipeID then
			---@cast recipeID integer
			-- A menu callback runs as addon code, so calling the protected craft API here taints the client's
			-- craft path (#313). Open the recipe instead: its own Craft button then crafts securely.
			root:CreateButton(craft.text, function()
				ns.ShowRecipe(recipeID, true)
			end)
		end
		-- The layout picked by straight line; a click ranks by travel time.
		local first = block.steps[1]
		local npc = first and first.nearest()
		if npc then
			local label = first.book and string.format(L["Waypoint to a vendor: %s"], first.book)
				or first.quest and string.format(L["Waypoint to the quest giver: %s"], first.quest)
				or L["Waypoint to a trainer"]
			root:CreateButton(label, function()
				ns.SetWaypoint((first.nearest(true)) or npc)
			end)
		end
		for _, item in ipairs(block.vendorMissing) do
			root:CreateButton(string.format(L["Waypoint to a vendor: %s"], item.name), function()
				ns.SetWaypoint(ns.NearestVendor(item.itemID, true) or item.vendor)
			end)
		end
		-- Recipes left out with Not this recipe on the route page, each with Show again.
		local pinned = #ns.PinnedRecipes(block.id)
		if pinned > 0 then
			ns.AddPinnedMenu(root:CreateButton(string.format(L["Pinned (%d)"], pinned)), block.id)
		end
		local skipped = #ns.SkippedRecipes(block.id)
		if skipped > 0 then
			ns.AddSkippedMenu(root:CreateButton(string.format(L["Skipped (%d)"], skipped)), block.id)
		end
		root:CreateButton(L["Stop tracking"], function()
			ns.SetTrackedByPlayer(block.id, false)
		end)
	end)
end

-- ForeverCore's shared line template: an objective line that takes the mouse, in a template of its own so the
-- tracker's pooling never mixes these lines with Blizzard's or another section's.
local LINE_TEMPLATE = "ForeverTrackerInteractiveLineTemplate"

-- A left click on the line sets a waypoint to the NPC `nearest` picks, by travel
-- time, and hovering names it. `steps` lists the training steps, so the tooltip can name the rest under
-- *Also train* (#557). Picked when used, never while the tracker redraws.
---@param line Frame
---@param title string
---@param label string
---@param nearest fun(): integer?
---@param quest? boolean an Artisan quest step
---@param steps? SkillUpTrackerStep[] the training steps, the rest listed on the tooltip
local function Waypointed(line, title, label, nearest, quest, steps)
	ForeverCore.TrackerLine.SetInteractive(line, {
		onClick = function()
			local npcID = nearest()
			if npcID then
				ns.SetWaypoint(npcID)
			end
		end,
		tooltip = function(self)
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			GameTooltip_SetTitle(GameTooltip, title)
			ns.AddNearest(GameTooltip, label, nearest())
			if quest then
				ns.AddQuestChainHint(GameTooltip)
			end
			if steps and #steps > 1 then
				GameTooltip_AddBlankLineToTooltip(GameTooltip)
				GameTooltip_AddNormalLine(GameTooltip, L["Also train"])
				for index = 2, #steps do
					GameTooltip_AddNormalLine(GameTooltip, steps[index].text)
				end
			end
			GameTooltip:Show()
		end,
	})
end

-- The item names the tracker draws. One that has not loaded is asked for and remembered, so item data that names
-- it redraws the section once; item data for anything else, which every tooltip hover raises, leaves it alone (#526).
---@type table<integer, true>
local waitingNames = {}
---@param itemID integer
---@return string?
local function TrackerName(itemID)
	local name = C_Item.GetItemNameByID(itemID)
	if not name then
		waitingNames[itemID] = true
		C_Item.RequestLoadItemDataByID(itemID)
	end
	return name
end

-- Only a name the section is waiting for changes what it shows; the rest of a hover's item data is no reason to
-- lay the tracker out again.
ns.WhenEvent("ITEM_DATA_LOAD_RESULT", function()
	local arrived = false
	for itemID in pairs(waitingNames) do
		if C_Item.GetItemNameByID(itemID) then
			waitingNames[itemID] = nil
			arrived = true
		end
	end
	return arrived and "trackerNames" or nil
end)

-- The ranks and recipes to train, in the order the route page lists them, each with where to go for it:
-- a trainer, or the vendor of a rank's book.
---@param plan SkillUpPlan
---@return SkillUpTrackerStep[]
local function TrainingSteps(plan)
	local steps = {}
	local profession = plan.profession
	for _, step in ipairs(plan.steps) do
		local rank, training = step.rank, step.training
		if rank then
			if rank.book then
				TrackerName(rank.book)
			end
			steps[#steps + 1] = {
				text = ns.RankText(rank),
				book = rank.book and ns.RankBookName(rank),
				quest = rank.quest and ns.RankQuestName(rank),
				nearest = function(byTravel)
					return ns.NearestForRank(profession, rank, byTravel)
				end,
			}
		elseif training then
			local name = C_Spell.GetSpellName(training.recipeID) or string.format(L["recipe %d"], training.recipeID)
			if training.scroll then
				local scroll = training.scroll
				---@cast scroll integer
				local scrollName = TrackerName(scroll)
				if not scrollName then
					scrollName = string.format(L["item %d"], scroll)
				end
				steps[#steps + 1] = {
					text = string.format(L["Buy %s at %d"], scrollName, training.usedAt),
					nearest = function(byTravel)
						return ns.NearestScrollVendor(training.recipeID, byTravel), L["Nearest vendor"]
					end,
				}
			else
				steps[#steps + 1] = {
					text = string.format(L["Train %s at %d"], name, training.usedAt),
					nearest = function(byTravel)
						return ns.NearestTrainer(profession, training.cap, byTravel), L["Nearest trainer"]
					end,
				}
			end
		end
	end
	return steps
end

-- Compact, quest style, under "Tailoring to 125": the next thing to train, then
-- only the reagents still missing, as "12/20 Linen Cloth". The page has the rest.
---@param self SkillUpTrackerModule
---@param entry SkillUpTracked
---@return boolean
local function LayoutEntry(self, entry)
	local plan = entry.plan
	local info = plan.profession
	local block = self:GetBlock(info.skillLine)
	block.profession, block.items = info.name, entry.items
	block.vendorMissing, block.plan = {}, plan
	block:SetHeader(string.format(L["%s to %d"], info.name, plan.target))
	local steps = TrainingSteps(plan)
	block.steps = steps
	if #steps > 0 then
		local more = #steps > 1
				and string.format(" |cff808080(%s)|r", string.format(L["+%d more to train"], #steps - 1))
			or ""
		local first = steps[1]
		local npc, label = first.nearest()
		local line = block:AddObjective("Train", first.text .. more, npc and LINE_TEMPLATE or nil)
		if npc then
			Waypointed(line, first.text, label, function()
				return (first.nearest(true))
			end, first.quest and true, steps)
		end
	end
	local shown = 0
	for _, item in ipairs(entry.items) do
		local have = ns.Have(item.itemID)
		if have < item.need then
			if shown == MAX_OBJECTIVES then
				block:AddObjective("Extra", "...", nil, nil, OBJECTIVE_DASH_STYLE_HIDE)
				break
			end
			shown = shown + 1
			local name = TrackerName(item.itemID)
			if not name then
				name = string.format(L["item %d"], item.itemID)
			end
			local gather = item.source == "gather" and string.format(" |cff808080(%s)|r", L["gather"]) or ""
			local vendor = item.source == "vendor" and ns.NearestVendor(item.itemID)
			local text = string.format("%d/%d %s%s", have, item.need, name, gather)
			local line = block:AddObjective(item.itemID, text, vendor and LINE_TEMPLATE or nil)
			if vendor then
				local itemID = item.itemID
				Waypointed(line, name, L["Nearest vendor"], function()
					return ns.NearestVendor(itemID, true)
				end)
				block.vendorMissing[#block.vendorMissing + 1] = { name = name, itemID = item.itemID, vendor = vendor }
			end
		end
	end
	local blocked = ns.RouteBlocked(plan)
	if blocked then
		block:AddObjective("Blocked", blocked)
	elseif shown == 0 then
		block:AddObjective("Ready", L["Reagents in hand"], nil, nil, nil, OBJECTIVE_TRACKER_COLOR.Complete)
	end
	return self:LayoutBlock(block)
end

function ModuleMixin:LayoutContents()
	-- What this layout draws is what the section can now be waiting for; names from an earlier layout are gone.
	for itemID in pairs(waitingNames) do
		waitingNames[itemID] = nil
	end
	if not ns.db.showTracker then
		return
	end
	-- A route that cannot be drawn raises through the shared host, which records the failure in SkillUp's journal
	-- and still lays out the sections below this one.
	for _, entry in ipairs(ns.TrackedNeeds()) do
		if not LayoutEntry(self, entry) then
			return
		end
	end
end

local function CreateModule()
	-- ForeverCore builds and attaches the section after saved variables load, so no tracker frame, no shared host
	-- and no old table is this file's problem: core records the first two and offers the third once. The column's
	-- scale, Lock and position were SkillUp's before Forever Core kept them, so the player keeps the layout they
	-- chose.
	local created = ForeverCore.TrackerSection.Create("SkillUpForeverObjectiveTracker", ModuleMixin, {
		header = ModuleMixin.headerText,
		legacy = function()
			return ns.db
		end,
		legacyKey = "trackerHost",
		safeCall = ns.core.SafeCall,
		onUnattached = function()
			ns.Print(L["couldn't add tracked reagents to the objective tracker; please report it."])
		end,
	})
	if not created then
		return
	end
	---@cast created SkillUpTrackerModule
	module = created
	-- A fresh session writes each tracked route's Auctionator list once.
	EventUtil.ContinueAfterAllEvents(function()
		C_Timer.After(0, SyncAuctionator)
	end, "PLAYER_ENTERING_WORLD", "VARIABLES_LOADED")
end

function ns.InitShopping()
	CreateModule()
	ns.WhenStale("tracker", RefreshTracker)
end
