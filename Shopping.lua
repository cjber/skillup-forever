local _, ns = ...

local CALLER = "SkillUp Forever"
local ROW_HEIGHT = 16
local TRACKER_WIDTH = 250

local tracker

function ns.HasAuctionator()
	local api = Auctionator and Auctionator.API and Auctionator.API.v1
	return api and api.CreateShoppingList and api.ConvertToSearchString and true or false
end

-- Bags and bank: the client knows bank counts once the bank has been opened.
function ns.Have(itemID)
	return C_Item.GetItemCount(itemID, true)
end

-- Everything the route uses, as totals: what you have is compared live, so the
-- list stays right as you buy, craft or bank things.
function ns.RouteReagents(route)
	local list = ns.Model.ShoppingList(route.segments, ns.Reagents, function()
		return 0
	end, ns.PriceSource)
	local items = {}
	for _, source in ipairs({ "vendor", "auction", "unknown" }) do
		for _, item in ipairs(list[source]) do
			items[#items + 1] = { itemID = item.itemID, need = item.count, source = source }
		end
	end
	return items
end

local SOURCE_TEXT = { vendor = "vendor", auction = "AH", unknown = "no price" }

-- One reagent as "icon name (source)" and "have/need", green once covered.
function ns.ReagentText(item)
	local icon = C_Item.GetItemIconByID(item.itemID)
	local name = C_Item.GetItemNameByID(item.itemID)
	if not name then
		-- ITEM_DATA_LOAD_RESULT redraws once the name arrives.
		C_Item.RequestLoadItemDataByID(item.itemID)
		name = "item " .. item.itemID
	end
	local have = ns.Have(item.itemID)
	local left = string.format("|T%s:14|t %s |cff808080%s|r", icon or 134400, name, SOURCE_TEXT[item.source])
	local right = string.format("%d/%d", math.min(have, item.need), item.need)
	return left, right, have >= item.need and ns.COLORS.green or HIGHLIGHT_FONT_COLOR
end

-- Auctionator searches by name, and names of unseen items arrive asynchronously.
local function WithNames(items, callback)
	local container = ContinuableContainer:Create()
	for _, item in ipairs(items) do
		container:AddContinuable(Item:CreateFromItemID(item.itemID))
	end
	container:ContinueOnLoad(callback)
end

-- One list per profession, replaced on each export, of the auction house
-- reagents still missing (emptied when none are). Vendor reagents stay out: an
-- auction search for them would only find resellers.
function ns.SendToAuctionator(profession, items)
	local missing = {}
	for _, item in ipairs(items) do
		local count = item.need - ns.Have(item.itemID)
		if item.source ~= "vendor" and count > 0 then
			missing[#missing + 1] = { itemID = item.itemID, count = count }
		end
	end
	local api = Auctionator.API.v1
	local name = "SkillUp: " .. profession
	if #missing == 0 then
		api.CreateShoppingList(CALLER, name, {})
		ns.Print("nothing left to buy at the auction house.")
		return
	end
	WithNames(missing, function()
		local searches = {}
		for _, item in ipairs(missing) do
			searches[#searches + 1] = api.ConvertToSearchString(CALLER, {
				searchString = C_Item.GetItemNameByID(item.itemID),
				isExact = true,
				quantity = item.count,
			})
		end
		api.CreateShoppingList(CALLER, name, searches)
		ns.Print(string.format("sent %d reagents to the Auctionator list '%s'.", #searches, name))
	end)
end

-- What the open merchant sells for gold from the pinned list, and its cost.
local function MerchantPurchases()
	local pinned = ns.db.pinned
	if not (pinned and MerchantFrame and MerchantFrame:IsShown()) then
		return {}, 0
	end
	local need = {}
	for _, item in ipairs(pinned.items) do
		need[item.itemID] = item.need - ns.Have(item.itemID)
	end
	local purchases, cost = {}, 0
	for index = 1, GetMerchantNumItems() do
		local itemID = GetMerchantItemID(index)
		local info = C_MerchantFrame.GetItemInfo(index)
		local missing = itemID and need[itemID]
		if missing and missing > 0 and info and info.price and info.price > 0 and not info.hasExtendedCost then
			local stack = math.max(info.stackCount or 1, 1)
			local count = math.ceil(missing / stack) * stack
			if info.numAvailable and info.numAvailable >= 0 then
				count = math.min(count, info.numAvailable * stack)
			end
			if count > 0 then
				purchases[#purchases + 1] = { index = index, count = count, stack = stack }
				cost = cost + info.price * count / stack
			end
		end
	end
	return purchases, cost
end

-- BuyMerchantItem counts units, priced per merchant stack, and takes at most
-- GetMerchantItemMaxStack units a call (Blizzard's MerchantFrame does the same).
local function BuyMissing()
	local purchases, cost = MerchantPurchases()
	if cost > GetMoney() then
		ns.Print("not enough money for every missing reagent here.")
		return
	end
	for _, purchase in ipairs(purchases) do
		local perCall = math.max(math.floor(GetMerchantItemMaxStack(purchase.index) / purchase.stack), 1)
			* purchase.stack
		local remaining = purchase.count
		while remaining > 0 do
			local count = math.min(remaining, perCall)
			BuyMerchantItem(purchase.index, count)
			remaining = remaining - count
		end
	end
end

local function RenderTracker()
	local pinned = ns.db.pinned
	if not pinned then
		if tracker then
			tracker:Hide()
		end
		return
	end
	tracker:SetTitle("Shopping: " .. pinned.profession)
	for i, item in ipairs(pinned.items) do
		local row = tracker.rows[i]
		if not row then
			row = tracker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			row:SetPoint("TOPLEFT", 14, -30 - (i - 1) * ROW_HEIGHT)
			row:SetPoint("RIGHT", -60, 0)
			row:SetJustifyH("LEFT")
			row:SetWordWrap(false)
			row.Count = tracker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			row.Count:SetPoint("RIGHT", tracker, "RIGHT", -14, 0)
			row.Count:SetPoint("TOP", row, "TOP")
			tracker.rows[i] = row
		end
		local left, right, color = ns.ReagentText(item)
		row:SetText(left)
		row.Count:SetText(right)
		row.Count:SetTextColor(color:GetRGB())
		row:Show()
		row.Count:Show()
	end
	for i = #pinned.items + 1, #tracker.rows do
		tracker.rows[i]:Hide()
		tracker.rows[i].Count:Hide()
	end
	local purchases, cost = MerchantPurchases()
	local height = 44 + #pinned.items * ROW_HEIGHT
	if #purchases > 0 then
		tracker.Buy:SetText("Buy missing  " .. C_CurrencyInfo.GetCoinTextureString(cost))
		tracker.Buy:Show()
		height = height + 28
	else
		tracker.Buy:Hide()
	end
	tracker:SetHeight(height)
	tracker:Show()
end

local function CreateTracker()
	tracker = CreateFrame("Frame", "SkillUpForeverShopping", UIParent, "DefaultPanelFlatTemplate")
	tracker:SetWidth(TRACKER_WIDTH)
	tracker:SetPoint("RIGHT", UIParent, "RIGHT", -40, 120)
	tracker:SetMovable(true)
	tracker:SetClampedToScreen(true)
	tracker:EnableMouse(true)
	tracker:RegisterForDrag("LeftButton")
	tracker:SetScript("OnDragStart", tracker.StartMoving)
	tracker:SetScript("OnDragStop", tracker.StopMovingOrSizing)
	tracker.rows = {}

	local close = CreateFrame("Button", nil, tracker, "UIPanelCloseButtonDefaultAnchors")
	close:SetScript("OnClick", function()
		ns.db.pinned = nil
		RenderTracker()
	end)

	local buy = CreateFrame("Button", nil, tracker, "UIPanelButtonTemplate")
	buy:SetSize(TRACKER_WIDTH - 28, 22)
	buy:SetPoint("BOTTOM", 0, 12)
	buy:SetScript("OnClick", BuyMissing)
	tracker.Buy = buy

	local events = CreateFrame("Frame")
	for _, event in ipairs({
		"BAG_UPDATE_DELAYED",
		"ITEM_DATA_LOAD_RESULT",
		"MERCHANT_SHOW",
		"MERCHANT_UPDATE",
		"MERCHANT_CLOSED",
	}) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", RenderTracker)
end

function ns.PinShopping(route)
	ns.db.pinned = { profession = route.profession, items = ns.RouteReagents(route) }
	if not tracker then
		CreateTracker()
	end
	RenderTracker()
end

-- A list pinned in an earlier session comes back, when SavedVariables load.
function ns.InitShopping()
	if ns.db.pinned then
		CreateTracker()
		RenderTracker()
	end
end
