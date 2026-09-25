---@type string, SkillUpNamespace
local addonName, ns = ...

-- [recipeID] = live schematic, else bundled data, else false; cleared when profession data changes.
---@type table<integer, SkillUpSchematic|false>
local recipes = {}
---@type table<integer, integer[]>?
local reagentIndex
---@type table<integer, SkillUpPrice|false>
local priceCache = {}

local function Table(parent, key)
	if type(parent[key]) ~= "table" then
		parent[key] = {}
	end
	return parent[key]
end

-- This character's professions, for what it gathers; kept while priceCache is.
---@type table<integer, SkillUpProfession>?
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
---@param itemID integer
---@return number?
---@return number?
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

-- Auction prices come only from Auctionator: { copper, source, days }.
---@param itemID integer
---@return SkillUpPrice?
local function AuctionPrice(itemID)
	local copper, days = AuctionatorPrice(itemID)
	return copper and { copper = copper, source = "auctionator", days = days }
end

-- With the setting on, what another of your professions gathers costs nothing.
---@param itemID integer
---@return SkillUpPrice?
local function Gathered(itemID)
	local skillLine = ns.db.gatherFree and ns.GatheredBy[itemID]
	if not skillLine then
		return nil
	end
	professions = professions or ns.PlayerProfessions()
	local profession = professions[skillLine]
	return profession and { copper = 0, source = "gather", profession = profession.name }
end

-- Cheapest known unit price and where it came from: "gather", "vendor" or
-- "auctionator". A price seen at a vendor beats the bundled list, since it includes
-- any reputation discount.
---@param itemID integer
---@return SkillUpPrice?
function ns.Price(itemID)
	---@type SkillUpPrice|false|nil
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

---@param itemID integer
---@return SkillUpPriceSource?
function ns.PriceSource(itemID)
	local price = ns.Price(itemID)
	return price and price.source
end

---@param itemID integer
---@return number?
local function UnitPrice(itemID)
	local price = ns.Price(itemID)
	return price and price.copper
end

-- Basic reagents only: optional and finishing slots don't have to be filled.
---@param recipeID integer
---@return SkillUpSchematic?
local function Recipe(recipeID)
	---@type SkillUpSchematic|false|nil
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
		-- look like: use the bundled reagents, or leave the cost unknown, never free.
		local bundled = ns.RecipeData and ns.RecipeData[recipeID]
		if not recipe or #recipe.reagents == 0 then
			recipe = bundled or false
		end
		recipes[recipeID] = recipe
	end
	return recipe or nil
end

---@param recipeID integer
---@return SkillUpReagent[]?
function ns.Reagents(recipeID)
	local recipe = Recipe(recipeID)
	return recipe and recipe.reagents
end

---@param itemID integer
---@return integer[]
function ns.UsedIn(itemID)
	if not reagentIndex and ns.RecipeData then
		reagentIndex = ns.Model.BuildReagentIndex(ns.RecipeData)
	end
	return reagentIndex and reagentIndex[itemID] or {}
end

local itemInfoPending = false

-- Live vendor sell price wins, including zero. Bundled prices cover uncached
-- outputs while the item-data request and eventual refresh are still pending.
---@param itemID integer
---@return number?
local function SellPrice(itemID)
	local sell = select(11, C_Item.GetItemInfo(itemID))
	if sell == nil then
		itemInfoPending = true
		C_Item.RequestLoadItemDataByID(itemID)
	end
	return sell or (ns.ItemSellPrices and ns.ItemSellPrices[itemID])
end

-- What one craft sells for: { copper, source, quantity } or nil.
---@param recipeID integer
---@return SkillUpValue?
function ns.CraftValue(recipeID)
	local recipe = Recipe(recipeID)
	local output = recipe and recipe.output
	if not output then
		return nil
	end
	local ah = AuctionPrice(output.itemID)
	local auction = ah and ah.copper
	local each, source = ns.Model.CraftValue(SellPrice(output.itemID), auction, ns.db.craftValue)
	if not (each and source) then
		return nil
	end
	return { copper = each * output.quantity, source = source, quantity = output.quantity }
end

---@param recipeID integer
---@return number?
function ns.RecipeCost(recipeID)
	return ns.Model.RecipeCost(ns.Reagents(recipeID), UnitPrice)
end

---@param recipeID integer
---@return number?
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
	elseif event == "GET_ITEM_INFO_RECEIVED" and itemInfoPending then
		-- Items arrive in bursts; one redraw covers the burst.
		itemInfoPending = false
		C_Timer.After(0.5, PricesChanged)
	end
end)

function ns.InitPrices()
	Table(ns.db, "vendor")
	for _, event in ipairs({
		"TRADE_SKILL_DATA_SOURCE_CHANGED",
		"TRADE_SKILL_LIST_UPDATE",
		"TRADE_SKILL_SHOW",
		"NEW_RECIPE_LEARNED",
		"SKILL_LINES_CHANGED",
		"MERCHANT_SHOW",
		"MERCHANT_UPDATE",
		"GET_ITEM_INFO_RECEIVED",
	}) do
		frame:RegisterEvent(event)
	end
	local api = AuctionatorAPI()
	if api and api.RegisterForDBUpdate then
		api.RegisterForDBUpdate(addonName, PricesChanged)
	end
end
