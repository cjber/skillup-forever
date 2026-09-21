local addonName, ns = ...

-- Our own scan is trusted for an hour before a visit to the auction house rescans it.
local SCAN_MAX_AGE = 3600
local KEYS_PER_SEARCH = 50
-- Blizzard runs its own search as the auction house opens; ours waits for it.
local SCAN_DELAY = 2
local SEARCH_TIMEOUT = 10

local recipes = {} -- [recipeID] = { reagents = {...}, output = { itemID, quantity } } or false
local priceCache = {}
local auctionsTable -- this realm and faction's scanned prices: [itemID] = { copper = n?, time = t }
-- pending: the current search's items still without a result; asked: all of them.
local queue, pending, asked, scanning = {}, nil, nil, false
local scanned = 0

local function Table(parent, key)
	if type(parent[key]) ~= "table" then
		parent[key] = {}
	end
	return parent[key]
end

-- Resolved on first use: the realm and faction aren't reliable while addons load.
local function Auctions()
	if not auctionsTable then
		local realm, faction = GetNormalizedRealmName(), UnitFactionGroup("player")
		if not (realm and faction) then
			return {}
		end
		auctionsTable = Table(Table(ns.db, "auctions"), realm .. "-" .. faction)
	end
	return auctionsTable
end

local function PricesChanged()
	priceCache = {}
	ns.RefreshRecipeList()
end

local function AuctionatorPrice(itemID)
	local api = Auctionator and Auctionator.API and Auctionator.API.v1
	if not (api and api.GetAuctionPriceByItemID) then
		return nil
	end
	local ok, copper = pcall(api.GetAuctionPriceByItemID, addonName, itemID)
	return ok and type(copper) == "number" and copper or nil
end

-- Cheapest known unit price and where it came from: "vendor", "scan" or "auctionator".
-- A price seen at a vendor beats the bundled list, since it includes any reputation discount.
function ns.Price(itemID)
	local cached = priceCache[itemID]
	if cached == nil then
		local vendor = ns.db.vendor[itemID] or ns.VendorPrices[itemID]
		local entry = Auctions()[itemID]
		local scan = entry and entry.copper
		local ah, ahSource = scan, "scan"
		if not ah then
			ah, ahSource = AuctionatorPrice(itemID), "auctionator"
		end
		if vendor and (not ah or vendor <= ah) then
			cached = { copper = vendor, source = "vendor" }
		elseif ah then
			cached = { copper = ah, source = ahSource, time = scan and entry.time }
		else
			cached = false
		end
		priceCache[itemID] = cached
	end
	return cached or nil
end

local function UnitPrice(itemID)
	local price = ns.Price(itemID)
	return price and price.copper
end

-- Basic reagents only: optional and finishing slots don't have to be filled.
-- Reagents and crafted items are both tracked, which is what the auction scan searches.
local function Recipe(recipeID)
	local recipe = recipes[recipeID]
	if recipe == nil then
		local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
		recipe = false
		if schematic and schematic.reagentSlotSchematics then
			recipe = { reagents = {} }
			for _, slot in ipairs(schematic.reagentSlotSchematics) do
				local first = slot.reagents and slot.reagents[1]
				if slot.reagentType == Enum.CraftingReagentType.Basic and first and first.itemID then
					recipe.reagents[#recipe.reagents + 1] = { itemID = first.itemID, quantity = slot.quantityRequired }
					ns.db.tracked[first.itemID] = true
				end
			end
			if schematic.outputItemID then
				local quantity = ((schematic.quantityMin or 1) + (schematic.quantityMax or schematic.quantityMin or 1))
					/ 2
				recipe.output = { itemID = schematic.outputItemID, quantity = quantity }
				ns.db.tracked[schematic.outputItemID] = true
			end
		end
		recipes[recipeID] = recipe
	end
	return recipe or nil
end

function ns.Reagents(recipeID)
	local recipe = Recipe(recipeID)
	return recipe and recipe.reagents
end

local itemInfoPending = false

-- Vendor sell price, or nil until the client has the item cached; the refresh
-- once it arrives redraws the rows.
local function SellPrice(itemID)
	local sell = select(11, C_Item.GetItemInfo(itemID))
	if sell == nil then
		itemInfoPending = true
		C_Item.RequestLoadItemDataByID(itemID)
	end
	return sell
end

-- What one craft sells for: { copper, source, each, quantity } or nil.
function ns.CraftValue(recipeID)
	local recipe = Recipe(recipeID)
	local output = recipe and recipe.output
	if not output then
		return nil
	end
	local entry = Auctions()[output.itemID]
	local auction = entry and entry.copper or AuctionatorPrice(output.itemID)
	local each, source = ns.Model.CraftValue(SellPrice(output.itemID), auction, ns.db.craftValue)
	if not each then
		return nil
	end
	return { copper = each * output.quantity, source = source, each = each, quantity = output.quantity }
end

-- The list only builds the rows on screen, so reagents are learned for the
-- whole profession up front; otherwise the scan misses anything not scrolled past.
function ns.LearnReagents()
	for _, recipeID in ipairs(C_TradeSkillUI.GetAllRecipeIDs()) do
		ns.Reagents(recipeID)
	end
end

function ns.RecipeCost(recipeID)
	return ns.Model.RecipeCost(ns.Reagents(recipeID), UnitPrice)
end

-- Vendor prices: recorded per unit for anything bought with plain money.
local function RecordMerchant()
	local changed = false
	for index = 1, GetMerchantNumItems() do
		local itemID = GetMerchantItemID(index)
		local info = C_MerchantFrame.GetItemInfo(index)
		if itemID and info and info.price and info.price > 0 and not info.hasExtendedCost then
			local each = info.price / math.max(info.stackCount or 1, 1)
			if ns.db.vendor[itemID] ~= each then
				ns.db.vendor[itemID] = each
				changed = true
			end
		end
	end
	if changed then
		PricesChanged()
	end
end

-- Harvests every browse result for a known reagent, so the player's own searches
-- keep prices fresh as well as ours.
local function HarvestBrowseResults()
	local auctions, now, changed = Auctions(), time(), false
	for _, result in ipairs(C_AuctionHouse.GetBrowseResults()) do
		local itemID = result.itemKey.itemID
		if ns.db.tracked[itemID] and result.minPrice and result.totalQuantity > 0 then
			auctions[itemID] = { copper = result.minPrice, time = now }
			changed = true
			if pending and pending[itemID] then
				pending[itemID] = nil
				scanned = scanned + 1
			end
		end
	end
	if changed then
		PricesChanged()
	end
end

local FinishScanIfDone

local function SendNextSearch()
	if pending or #queue == 0 or not C_AuctionHouse.IsThrottledMessageSystemReady() then
		return
	end
	local keys = {}
	pending, asked = {}, {}
	while #queue > 0 and #keys < KEYS_PER_SEARCH do
		local itemID = table.remove(queue)
		pending[itemID] = true
		asked[itemID] = true
		keys[#keys + 1] = C_AuctionHouse.MakeItemKey(itemID)
	end
	C_AuctionHouse.SearchForItemKeys(keys, {})
	-- A search superseded by the player's own never answers: give up on it without
	-- touching those prices, and carry on with the rest.
	local sent = pending
	C_Timer.After(SEARCH_TIMEOUT, function()
		if pending == sent then
			pending = nil
			SendNextSearch()
			FinishScanIfDone()
		end
	end)
end

-- Results answer our search only if every item in them is one we asked for;
-- anything else is Blizzard's or the player's own search.
local function IsOurSearch()
	for _, result in ipairs(C_AuctionHouse.GetBrowseResults()) do
		if not asked[result.itemKey.itemID] then
			return false
		end
	end
	return true
end

-- An item nobody has listed returns no result; its old price should not outlive
-- the search that found none.
local function FinishSearch()
	local auctions, now = Auctions(), time()
	for itemID in pairs(pending) do
		auctions[itemID] = { time = now }
	end
	pending = nil
end

function FinishScanIfDone()
	if scanning and not pending and #queue == 0 then
		scanning = false
		PricesChanged()
		ns.Print(string.format("priced %d reagents from the auction house.", scanned))
	end
end

function ns.ScanAuctions(force)
	if scanning then
		return
	end
	local auctions, now = Auctions(), time()
	queue, scanned = {}, 0
	for itemID in pairs(ns.db.tracked) do
		local last = auctions[itemID]
		if force or not last or now - last.time > SCAN_MAX_AGE then
			queue[#queue + 1] = itemID
		end
	end
	if #queue == 0 then
		if force then
			ns.Print("no reagents known yet; open a profession first.")
		end
		return
	end
	scanning = true
	SendNextSearch()
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event)
	if event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
		RecordMerchant()
	elseif event == "AUCTION_HOUSE_SHOW" then
		if ns.db.scanAuctions then
			C_Timer.After(SCAN_DELAY, function()
				if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
					ns.ScanAuctions(false)
				end
			end)
		end
	elseif event == "AUCTION_HOUSE_CLOSED" then
		scanning, pending, queue = false, nil, {}
	elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
		local ours = pending and IsOurSearch()
		HarvestBrowseResults()
		if not ours then
			return
		end
		if not C_AuctionHouse.HasFullBrowseResults() then
			C_AuctionHouse.RequestMoreBrowseResults()
			return
		end
		FinishSearch()
		SendNextSearch()
		FinishScanIfDone()
	elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
		SendNextSearch()
	elseif event == "GET_ITEM_INFO_RECEIVED" and itemInfoPending then
		-- Items arrive in bursts; one redraw covers the burst.
		itemInfoPending = false
		C_Timer.After(0.5, PricesChanged)
	end
end)

function ns.InitPrices()
	Table(ns.db, "vendor")
	Table(ns.db, "tracked")
	for _, event in ipairs({
		"MERCHANT_SHOW",
		"MERCHANT_UPDATE",
		"AUCTION_HOUSE_SHOW",
		"AUCTION_HOUSE_CLOSED",
		"AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
		"AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
		"AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
		"GET_ITEM_INFO_RECEIVED",
	}) do
		frame:RegisterEvent(event)
	end
end
