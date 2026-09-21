local addonName, ns = ...

-- Our own scan is trusted for an hour before a visit to the auction house rescans it.
local SCAN_MAX_AGE = 3600
local KEYS_PER_SEARCH = 50
-- Blizzard runs its own search as the auction house opens; ours waits for it.
local SCAN_DELAY = 2
local SEARCH_TIMEOUT = 10

-- [recipeID] = live schematic, else bundled data, else false; cleared when profession data changes.
local recipes = {}
local reagentIndex
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

local DAY = 86400

-- This character's professions, for what it gathers; kept while priceCache is.
local professions

local function PricesChanged()
	priceCache = {}
	professions = nil
	ns.InvalidatePlans()
	ns.RefreshRecipeList()
	ns.RefreshRoute()
	ns.RefreshTracker()
end
ns.PricesChanged = PricesChanged

-- Skill-ups fire SKILL_LINES_CHANGED too; only learning or dropping a profession
-- changes what counts as gathered.
local function ProfessionsChanged()
	if not professions then
		return false
	end
	local now = ns.PlayerProfessions()
	for skillLine in pairs(now) do
		if not professions[skillLine] then
			return true
		end
	end
	for skillLine in pairs(professions) do
		if not now[skillLine] then
			return true
		end
	end
	return false
end

local function AuctionatorAPI()
	local api = Auctionator and Auctionator.API and Auctionator.API.v1
	return api and api.GetAuctionPriceByItemID and api
end

-- Auctionator's price, and whole days since it was seen (nil past three weeks).
local function AuctionatorPrice(itemID)
	local api = AuctionatorAPI()
	if not api then
		return nil
	end
	local ok, copper = pcall(api.GetAuctionPriceByItemID, addonName, itemID)
	if not (ok and type(copper) == "number") then
		return nil
	end
	local okAge, days = pcall(api.GetAuctionAgeByItemID, addonName, itemID)
	return copper, okAge and type(days) == "number" and days or nil
end

-- Nothing for our scan to add: Auctionator already priced it today.
local function AuctionatorSawToday(itemID)
	local copper, days = AuctionatorPrice(itemID)
	return copper ~= nil and days == 0
end

-- The fresher of our own scan and Auctionator's: { copper, source, time | days }.
local function AuctionPrice(itemID)
	local entry = Auctions()[itemID]
	local ours = entry and entry.copper and { copper = entry.copper, source = "scan", time = entry.time }
	local copper, days = AuctionatorPrice(itemID)
	if not copper then
		return ours
	end
	-- Auctionator counts whole days, and stops counting after three weeks.
	if ours and (days == nil or time() - ours.time < days * DAY) then
		return ours
	end
	return { copper = copper, source = "auctionator", days = days }
end

-- With the setting on, what another of your professions gathers costs nothing.
local function Gathered(itemID)
	local skillLine = ns.db.gatherFree and ns.GatheredBy[itemID]
	if not skillLine then
		return nil
	end
	professions = professions or ns.PlayerProfessions()
	local profession = professions[skillLine]
	return profession and { copper = 0, source = "gather", profession = profession.name }
end

-- Cheapest known unit price and where it came from: "gather", "vendor", "scan" or
-- "auctionator". A price seen at a vendor beats the bundled list, since it includes
-- any reputation discount.
function ns.Price(itemID)
	local cached = priceCache[itemID]
	if cached == nil then
		local vendor = ns.db.vendor[itemID] or ns.VendorPrices[itemID]
		local ah = AuctionPrice(itemID)
		cached = Gathered(itemID)
		if cached then
			priceCache[itemID] = cached
			return cached
		elseif vendor and (not ah or vendor <= ah.copper) then
			cached = { copper = vendor, source = "vendor" }
		elseif ah then
			cached = ah
		else
			cached = false
		end
		priceCache[itemID] = cached
	end
	return cached or nil
end

function ns.PriceSource(itemID)
	local price = ns.Price(itemID)
	return price and price.source
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
		if schematic and schematic.reagentSlotSchematics then
			recipe = { reagents = {} }
			for _, slot in ipairs(schematic.reagentSlotSchematics) do
				local first = slot.reagents and slot.reagents[1]
				if slot.reagentType == Enum.CraftingReagentType.Basic then
					if
						not (
							first
							and first.itemID
							and first.itemID > 0
							and slot.quantityRequired
							and slot.quantityRequired > 0
						)
					then
						recipe = nil
						break
					end
					recipe.reagents[#recipe.reagents + 1] = { itemID = first.itemID, quantity = slot.quantityRequired }
				end
			end
			if recipe and schematic.outputItemID and schematic.outputItemID > 0 then
				local quantity = ((schematic.quantityMin or 1) + (schematic.quantityMax or schematic.quantityMin or 1))
					/ 2
				if quantity > 0 then
					recipe.output = { itemID = schematic.outputItemID, quantity = quantity }
				else
					recipe = nil
				end
			end
		end
		-- An empty live schematic is what a recipe outside the open profession can
		-- look like; bundled reagents beat pricing it as free.
		local bundled = ns.RecipeData and ns.RecipeData[recipeID]
		if not recipe or (#recipe.reagents == 0 and bundled) then
			recipe = bundled or false
		end
		recipes[recipeID] = recipe
		if recipe then
			for _, reagent in ipairs(recipe.reagents) do
				ns.db.tracked[reagent.itemID] = true
			end
			if recipe.output then
				ns.db.tracked[recipe.output.itemID] = true
			end
		end
	end
	return recipe or nil
end

function ns.Reagents(recipeID)
	local recipe = Recipe(recipeID)
	return recipe and recipe.reagents
end

function ns.UsedIn(itemID)
	if not reagentIndex and ns.RecipeData then
		reagentIndex = ns.Model.BuildReagentIndex(ns.RecipeData)
	end
	return reagentIndex and reagentIndex[itemID] or {}
end

local itemInfoPending = false

-- Live vendor sell price wins, including zero. Bundled prices cover uncached
-- outputs while the item-data request and eventual refresh are still pending.
local function SellPrice(itemID)
	local sell = select(11, C_Item.GetItemInfo(itemID))
	if sell == nil then
		itemInfoPending = true
		C_Item.RequestLoadItemDataByID(itemID)
	end
	return sell or (ns.ItemSellPrices and ns.ItemSellPrices[itemID])
end

-- What one craft sells for: { copper, source, each, quantity } or nil.
function ns.CraftValue(recipeID)
	local recipe = Recipe(recipeID)
	local output = recipe and recipe.output
	if not output then
		return nil
	end
	local ah = AuctionPrice(output.itemID)
	local auction = ah and ah.copper
	local each, source = ns.Model.CraftValue(SellPrice(output.itemID), auction, ns.db.craftValue)
	if not each then
		return nil
	end
	return { copper = each * output.quantity, source = source, each = each, quantity = output.quantity }
end

-- The list only builds the rows on screen, so reagents are learned for the
-- whole profession up front; otherwise the scan misses anything not scrolled past.
function ns.LearnReagents()
	for _, recipeID in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
		ns.Reagents(recipeID)
	end
end

function ns.RecipeCost(recipeID)
	return ns.Model.RecipeCost(ns.Reagents(recipeID), UnitPrice)
end

function ns.NetCost(recipeID)
	local cost = ns.RecipeCost(recipeID)
	if cost == nil then
		return nil
	end
	local value = ns.CraftValue(recipeID)
	return cost - (value and value.copper or 0)
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
		if force or ((not last or now - last.time > SCAN_MAX_AGE) and not AuctionatorSawToday(itemID)) then
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
	if
		event == "TRADE_SKILL_DATA_SOURCE_CHANGED"
		or event == "TRADE_SKILL_LIST_UPDATE"
		or event == "TRADE_SKILL_SHOW"
		or event == "NEW_RECIPE_LEARNED"
	then
		recipes = {}
	elseif event == "SKILL_LINES_CHANGED" then
		if ProfessionsChanged() then
			PricesChanged()
		end
	elseif event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
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
		"TRADE_SKILL_DATA_SOURCE_CHANGED",
		"TRADE_SKILL_LIST_UPDATE",
		"TRADE_SKILL_SHOW",
		"NEW_RECIPE_LEARNED",
		"SKILL_LINES_CHANGED",
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
	local api = AuctionatorAPI()
	if api and api.RegisterForDBUpdate then
		api.RegisterForDBUpdate(addonName, PricesChanged)
	end
end
