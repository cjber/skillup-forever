---@type string, SkillUpNamespace
local addonName, ns = ...

if ns.broken then
	return
end

-- [recipeID] = live schematic, else bundled data, else false.
---@type table<integer, SkillUpSchematic|false>
local recipes = {}
-- [recipeID] = true while recipes holds the bundled data or false for it: the client had no schematic of its
-- own then, as it has none for a profession whose window is closed.
---@type table<integer, true>
local fromBundle = {}
---@type table<integer, integer[]>?
local reagentIndex
---@type table<integer, SkillUpPrice|false>
local priceCache = {}

-- This character's professions, for what it gathers; kept while priceCache is.
---@type table<integer, SkillUpProfession>?
local professions

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

-- Auctionator supplies its latest recorded buyout and the age of that observation.
---@param itemID integer
---@return SkillUpPrice?
local function AuctionatorPrice(itemID)
	local api = AuctionatorAPI()
	if not api then
		return nil
	end
	local ok, live = pcall(api.GetAuctionPriceByItemID, addonName, itemID)
	if not (ok and type(live) == "number") then
		return nil
	end
	local okAge, age = pcall(api.GetAuctionAgeByItemID, addonName, itemID)
	return {
		copper = live,
		source = "auctionator",
		days = okAge and type(age) == "number" and age or nil,
		ageUnavailable = not okAge,
	}
end

-- AuctionDB's market value of the latest snapshot, which one underpriced listing does not move; the snapshot's
-- lowest buyout, then the 14-day value, for an item the first has nothing for.
local TSM_PRICE = "first(DBRecent, DBMinBuyout, DBMarket)"

---@return boolean
function ns.HasTradeSkillMaster()
	return TSM_API and TSM_API.GetCustomPriceValue and true or false
end

-- TradeSkillMaster's AuctionDB, which its desktop app refreshes. TSM_API does not say how old the data is.
---@param itemID integer
---@return SkillUpPrice?
local function TradeSkillMasterPrice(itemID)
	if not ns.HasTradeSkillMaster() then
		return nil
	end
	local ok, value = pcall(TSM_API.GetCustomPriceValue, TSM_PRICE, "i:" .. itemID)
	if not (ok and type(value) == "number") then
		return nil
	end
	return { copper = value, source = "tsm" }
end

---@return boolean
function ns.HasAHDB()
	return type(AuctionDB) == "table"
		and type(AuctionDB.LastPrice) == "function"
		and type(AuctionDB.ViewHouse) == "function"
end

---@return boolean
function ns.HasNaowhForever()
	return type(NaowhForever) == "table" and type(NaowhForever.AuctionPrice) == "function"
end

---@param value any
---@return boolean
local function ValidPrice(value)
	return type(value) == "number" and value == value and value >= 0 and value < math.huge
end

local function ObservationDays(at)
	if ValidPrice(at) then
		return math.max(0, math.floor((GetServerTime() - at) / 86400))
	end
	return nil
end

---@param itemID integer
---@return SkillUpPrice?
local function AHDBPrice(itemID)
	if not ns.HasAHDB() then
		return nil
	end
	local ok, point = pcall(function()
		return AuctionDB:LastPrice(itemID, AuctionDB:ViewHouse())
	end)
	if not (ok and type(point) == "table" and ValidPrice(point[2])) then
		return nil
	end
	return { copper = point[2], source = "ahdb", days = ObservationDays(point[1]) }
end

---@param itemID integer
---@return SkillUpPrice?
local function NaowhPrice(itemID)
	if not ns.HasNaowhForever() then
		return nil
	end
	local ok, value, at = pcall(NaowhForever.AuctionPrice, itemID)
	if not (ok and type(value) == "number" and ValidPrice(value)) then
		return nil
	end
	return { copper = value, source = "naowh", days = ObservationDays(at) }
end

local PROVIDERS = { auctionator = AuctionatorPrice, tsm = TradeSkillMasterPrice, ahdb = AHDBPrice, naowh = NaowhPrice }
local PROVIDER_ORDER = { "auctionator", "tsm", "ahdb", "naowh" }
-- Looked up on each call: the detectors are replaced after load when an addon is installed late, and in specs.
local INSTALLED = {
	auctionator = function()
		return ns.HasAuctionator()
	end,
	tsm = function()
		return ns.HasTradeSkillMaster()
	end,
	ahdb = function()
		return ns.HasAHDB()
	end,
	naowh = function()
		return ns.HasNaowhForever()
	end,
}

-- The installed auction price addon a missing price is up to: the chosen one, else the first in fallback order.
---@return "auctionator"|"tsm"|"ahdb"|"naowh"|nil
function ns.AuctionProvider()
	local selected = ns.db.priceSource
	if INSTALLED[selected] and INSTALLED[selected]() then
		return selected
	end
	for _, source in ipairs(PROVIDER_ORDER) do
		if INSTALLED[source]() then
			return source
		end
	end
end

-- The chosen observation wins; every other installed provider fills gaps in a fixed order.
---@param itemID integer
---@return SkillUpPrice?
local function AuctionPrice(itemID)
	local selected = ns.db.priceSource
	local chosen = PROVIDERS[selected]
	local price = chosen and chosen(itemID)
	if price then
		return price
	end
	for _, source in ipairs(PROVIDER_ORDER) do
		if source ~= selected then
			price = PROVIDERS[source](itemID)
			if price then
				return price
			end
		end
	end
	return nil
end

-- TradeSkillMaster's regional sale average, from the sale and purchase accounting its desktop app collects in the
-- player's region. It is not a listing and not this character's own sales. TSM records an auction sale net of the
-- auction house cut (bid less the cut over the quantity, Ledger/Mail.lua), while purchases record the bid. The
-- combined average has no documented gross-price normalization, so use it as reported without another cut.
-- A zero, absent or invalid answer is unknown:
-- TSM itself answers nil for a value it has none of.
local TSM_SALE = "DBRegionSaleAvg"
local TSM_VOLUME = "DBRegionSoldPerDay"

---@param itemID integer
---@return number?
local function TradeSkillMasterSale(itemID)
	if not ns.HasTradeSkillMaster() then
		return nil
	end
	local ok, value = pcall(TSM_API.GetCustomPriceValue, TSM_SALE, "i:" .. itemID)
	if not (ok and type(value) == "number" and value == value and value > 0 and value < math.huge) then
		return nil
	end
	return value
end

---@param itemID integer
---@return number?
local function TradeSkillMasterSoldPerDay(itemID)
	if not ns.HasTradeSkillMaster() then
		return nil
	end
	local ok, value = pcall(TSM_API.GetCustomPriceValue, TSM_VOLUME, "i:" .. itemID)
	if not (ok and type(value) == "number" and value == value and value >= 0 and value < math.huge) then
		return nil
	end
	return value
end

-- Sell prices the client had not loaded when a price was made, each with the value used meanwhile (false for
-- none). Only one of these arriving with another value is a price change (#846): item data arrives for any
-- item, from any addon, on opening bags, at a merchant or as players come into view.
---@type table<integer, number|false>
local awaitingSell = {}

-- Live vendor sell price wins, including zero. Bundled prices cover uncached
-- outputs while the item-data request and eventual refresh are still pending.
---@param itemID integer
---@return number?
local function SellPrice(itemID)
	local sell = ns.Readable((select(11, C_Item.GetItemInfo(itemID))))
	local bundled = ns.ItemSellPrices and ns.ItemSellPrices[itemID]
	if sell == nil and awaitingSell[itemID] == nil then
		awaitingSell[itemID] = bundled or false
		ns.RequestItemData(itemID)
	end
	if sell == nil then
		return bundled
	end
	return sell
end

-- Auction value is net of the house's 5% cut and only counts when it beats the vendor.
local AUCTION_CUT = 0.05

-- What selling a gathered material would bring instead of crafting with it: its auction price after the
-- cut, with its vendor sell price as the floor. Nil when neither is known.
---@param itemID integer
---@return number?
---@return 'auction'|'vendor'|nil
---@return SkillUpPriceSource?
local function SaleValue(itemID)
	local ah = AuctionPrice(itemID)
	local resale = ah and ah.copper * (1 - AUCTION_CUT)
	local sell = SellPrice(itemID)
	if ah and resale and (not sell or resale > sell) then
		return resale, "auction", ah.source
	end
	return sell, sell and "vendor" or nil
end

-- Whether this character can get `itemID` without buying it: a creature anyone can kill drops it ("loot"), or
-- one of their professions gathers it (that profession's name). An item both a profession and a creature carry
-- is loot for a character without that profession. Nil when neither. One predicate for Prices and the route's
-- Buy reagents switch, so they cannot disagree.
---@param itemID integer
---@return string?
function ns.CanGather(itemID)
	local skillLine = ns.GatheredBy and ns.GatheredBy[itemID]
	if skillLine then
		professions = professions or ns.PlayerProfessions()
		local profession = professions[skillLine]
		if profession then
			return profession.name
		end
	end
	if ns.LootedFrom and ns.LootedFrom[itemID] then
		return "loot"
	end
	return nil
end

-- What another of your professions gathers, or any reagent creatures drop, costs nothing; or, with *Value
-- gathered materials* on, what it would sell for. With *Price self-supplied reagents at auction values* on it is
-- always a market price, and a material no market prices stays unpriced rather than free. Nil for one you cannot
-- get yourself, or one the setting leaves without a market price.
---@param itemID integer
---@return SkillUpPrice?
local function Gathered(itemID)
	local source = ns.CanGather(itemID)
	if not source then
		return nil
	end
	local marketOnly = ns.db.auctionOnly
	local worth, from, market = SaleValue(itemID)
	if marketOnly and not (worth and worth > 0) then
		-- No market price: leave it unknown, never a free material (issue #399).
		return nil
	end
	---@type SkillUpPrice
	local price = {
		copper = (ns.db.valueGathered or marketOnly) and worth or 0,
		unknown = (ns.db.valueGathered or marketOnly) and worth == nil or nil,
		sale = not (ns.db.valueGathered or marketOnly) and worth or nil,
		-- Priced from the market, a self-supplied reagent is bought there in the shopping list too.
		source = marketOnly and (from == "auction" and market or "vendor") or "gather",
		worth = (ns.db.valueGathered or marketOnly) and from or nil,
	}
	if source == "loot" then
		price.loot = true
	else
		price.profession = source
	end
	return price
end

-- These items have a source beyond vendors even when this character cannot gather or craft them.
-- A vendor-only reagent needs no auction observation to establish its cost.
---@param itemID integer
---@return boolean
local function MarketGood(itemID)
	return (ns.GatheredBy and ns.GatheredBy[itemID]) ~= nil
		or (ns.LootedFrom and ns.LootedFrom[itemID]) ~= nil
		or #ns.MakersOf(itemID) > 0
end

-- Cheapest known unit price and where it came from: "gather", "vendor", "auctionator"
-- "tsm", "ahdb" or "naowh". A price seen at a vendor beats the bundled list, since it includes
-- any reputation discount. With Buy reagents on, a market good without an auction observation stays
-- unknown with only a bundled vendor fallback. A price actually seen at a merchant is a known purchase
-- cost; it does not need an auction observation to establish what the player can pay (#559, #561).
---@param itemID integer
---@return SkillUpPrice?
function ns.Price(itemID)
	---@type SkillUpPrice|false|nil
	local cached = priceCache[itemID]
	if cached == nil then
		-- The professions are the baseline a later skill-line change is compared with, even when this item
		-- turns out not to be gatherable.
		if not professions and ns.PlayerProfessions then
			professions = ns.PlayerProfessions()
		end
		local observedVendor = ns.db.vendor[itemID]
		local vendor = observedVendor or ns.VendorPrices[itemID]
		local ah = AuctionPrice(itemID)
		if ns.CollectMode() == "gather" then
			cached = Gathered(itemID)
		end
		if not cached and not ah and not observedVendor and ns.CollectMode() == "auction" and MarketGood(itemID) then
			-- Keep the vendor fallback for display, but do not rank it as a known market cost before a scan.
			cached = { copper = vendor or 0, source = "auction", unknown = true }
		elseif not cached and vendor and (not ah or vendor <= ah.copper) then
			cached = { copper = vendor, source = "vendor" }
		elseif not cached and ah then
			cached = ah
		elseif not cached then
			cached = Gathered(itemID) or false
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

-- The stock the vendor the route sends the player to has of this item, when it limits it; nil when it does
-- not, or when nobody is known to sell it. What the window showed that vendor sell replaces the bundled
-- limit, and false there means unlimited. What the route says instead of implying a reagent list can be
-- bought in one visit (#358).
---@param itemID integer
---@param vendor integer?
---@return number?
function ns.IsLimitedStock(itemID, vendor)
	local seen = ns.db.stock and ns.db.stock[itemID]
	local bundled = ns.LimitedStock and ns.LimitedStock[itemID]
	if not (seen or bundled) then
		return nil
	end
	vendor = vendor or ns.NearestVendor(itemID, true)
	if not vendor then
		return nil
	end
	if seen then
		local stock = seen[vendor]
		if stock == false then
			return nil
		elseif stock ~= nil then
			return stock
		end
	end
	return bundled and bundled[vendor] or nil
end

-- Which seller supplied each stock-aware quote since the last price or catalogue change.
---@type table<integer, integer|false>
local stockVendors = {}

-- Cache the selected seller and both quotes together until merchant or catalogue evidence changes.
---@type table<integer, {stock: number, overflow: SkillUpPrice, vendor: SkillUpPrice}|false>
local limitedQuotes = {}

---@param itemID integer
---@return number? stock
---@return SkillUpPrice? overflow
---@return SkillUpPrice? vendorPrice
function ns.LimitedReagentPrice(itemID)
	local cached = limitedQuotes[itemID]
	if cached == nil then
		cached = false
		if
			(ns.db.stock[itemID] or (ns.LimitedStock and ns.LimitedStock[itemID]))
			and MarketGood(itemID)
			and not (ns.CollectMode() == "gather" and Gathered(itemID))
		then
			local npc = ns.NearestVendor(itemID, true)
			stockVendors[itemID] = npc or false
			local limit = npc and ns.IsLimitedStock(itemID, npc)
			if limit then
				local evidence = ns.db.merchantEvidence[npc]
				local observed = evidence and evidence[itemID]
				local available = observed and observed.numAvailable
				if available and available >= 0 then
					limit = math.min(limit, available)
				end
				local overflow = AuctionPrice(itemID)
				for seller in pairs(ns.db.stock[itemID] or {}) do
					local offers = ns.db.merchantEvidence[seller]
					local offer = offers and offers[itemID]
					local copper = offer and offer.unitCopper
					local tiedVendor = overflow and copper == overflow.copper and overflow.vendor
					if
						seller ~= npc
						and offer
						and offer.numAvailable == -1
						and copper
						and (not overflow or copper < overflow.copper or (tiedVendor and seller < tiedVendor))
						and ns.NearestNPC({ seller })
					then
						overflow = { copper = copper, source = "vendor", vendor = seller }
					end
				end
				local quote = observed and observed.unitCopper or ns.VendorPrices[itemID]
				if not quote and not evidence then
					quote = ns.db.vendor[itemID]
				end
				if quote then
					overflow = overflow or { copper = 0, source = "auction", unknown = true }
					cached = {
						stock = (overflow.unknown or quote <= overflow.copper) and limit or 0,
						overflow = overflow,
						vendor = { copper = quote, source = "vendor", vendor = npc },
					}
				end
			end
		end
		limitedQuotes[itemID] = cached
	end
	if cached then
		return cached.stock, cached.overflow, cached.vendor
	end
end

-- Returns the exact purchase split and, when given a route ledger, consumes only the vendor portion.
---@param itemID integer
---@param count number
---@param remaining table<integer, number>?
---@return number vendorCount
---@return SkillUpPrice?
---@return SkillUpPrice?
function ns.AllocateReagent(itemID, count, remaining)
	local stock, overflow, vendor = ns.LimitedReagentPrice(itemID)
	if stock and vendor then
		local left = remaining and remaining[itemID] or stock
		local units = math.min(left, count)
		if remaining then
			remaining[itemID] = left - units
		end
		return units, vendor, overflow
	end
	return 0, nil, ns.Price(itemID)
end

-- The client's own schematic, basic reagents only: optional and finishing slots don't have to be filled.
-- Nil when it has none with reagents, as for a recipe outside the open profession.
---@param recipeID integer
---@return SkillUpSchematic?
local function LiveRecipe(recipeID)
	local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
	if not (schematic and schematic.reagentSlotSchematics) then
		return nil
	end
	---@type SkillUpSchematic
	local recipe = { reagents = {} }
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
				return nil
			end
			recipe.reagents[#recipe.reagents + 1] = { itemID = first.itemID, quantity = slot.quantityRequired }
		end
	end
	if schematic.outputItemID and schematic.outputItemID > 0 then
		local minimum, maximum = schematic.quantityMin, schematic.quantityMax
		local quantity = ((minimum or 1) + (maximum or minimum or 1)) / 2
		if quantity <= 0 then
			return nil
		end
		---@type SkillUpRecipeOutput
		local output = { itemID = schematic.outputItemID, quantity = quantity }
		local recipeTypes = Enum.TradeskillRecipeType
		local recipeType = schematic.recipeType
		if
			recipeTypes
			and recipeType
			and (recipeType == recipeTypes.Salvage or recipeType == recipeTypes.Gathering)
		then
			-- The client's range describes reagent cost for these recipes.
			output.quantityMin, output.quantityMax = 1, 1
		elseif minimum and maximum and minimum >= 1 and maximum >= minimum then
			output.quantityMin, output.quantityMax = minimum, maximum
		end
		recipe.output = output
	end
	if #recipe.reagents == 0 then
		return nil
	end
	return recipe
end

---@param recipeID integer
---@return SkillUpSchematic?
local function Recipe(recipeID)
	---@type SkillUpSchematic|false|nil
	local recipe = recipes[recipeID]
	if recipe == nil then
		recipe = LiveRecipe(recipeID)
		-- An empty live schematic is what a recipe outside the open profession can
		-- look like: use the bundled reagents, or leave the cost unknown, never free.
		if not recipe then
			recipe = ns.RecipeData and ns.RecipeData[recipeID] or false
			fromBundle[recipeID] = true
		end
		recipes[recipeID] = recipe
	end
	return recipe or nil
end

-- Whether any of these recipes, taken from the bundle while the client had no schematic for it, has one of
-- its own now: its profession's window is open.
---@param recipeIDs integer[]
---@return boolean
function ns.LiveSchematicsArrived(recipeIDs)
	for _, recipeID in ipairs(recipeIDs) do
		if fromBundle[recipeID] and LiveRecipe(recipeID) then
			return true
		end
	end
	return false
end

---@param recipeID integer
---@return SkillUpReagent[]?
function ns.Reagents(recipeID)
	local recipe = Recipe(recipeID)
	return recipe and recipe.reagents
end

---@param recipeID integer
---@return SkillUpRecipeOutput?
function ns.RecipeOutput(recipeID)
	local recipe = Recipe(recipeID)
	return recipe and recipe.output or nil
end

---@param itemID integer
---@return integer[]
function ns.UsedIn(itemID)
	if not reagentIndex and ns.RecipeData then
		reagentIndex = ns.Model.BuildReagentIndex(ns.RecipeData)
	end
	return reagentIndex and reagentIndex[itemID] or {}
end

-- Sub-crafting: a reagent a recipe this character knows can make is obtained by crafting it when
-- that beats buying it. Cost recurses three levels, memoised per item, count and reachable stock, and a recipe
-- that would need the item it makes is skipped rather than followed, so no cycle can recurse or hang.

local MAX_SUB_DEPTH = 3
---@class SkillUpMakerChoice
---@field recipeID integer
---@field quantity number
---@field purchaseUnits number

-- ObtainCost by every input its answer reads: item, count, depth, purchase mode, and the ledger balance and
-- cycle-stack membership of each item its subtree can reach. A route prices the same subtree under the same
-- ledger many times over (every batch count, every stock split), so without this the recursion is exponential.
---@type table<string, {cost: number?, maker: SkillUpMakerChoice?, after: table<integer, number>?}>
local obtainCost = {}
-- The items ObtainCost can read below an item at a depth: the item, and each usable maker's reagents one level down.
---@type table<integer, table<integer, integer[]>>
local reaches = {}
-- The product of every usable maker's output quantity over the same reach: the period whole-batch rounding
-- repeats with.
---@type table<integer, table<integer, integer>>
local periods = {}
---@type table<integer, number|false>
local linearCosts = {}
---@type table<integer, number|false>
local unitCosts = {}
---@type table<integer, SkillUpMakerChoice>
local unitMakers = {}
---@type table<integer, number|false>
local heldCost = {}
---@type table<integer, integer[]>?
local craftMakers
---@type table<integer, table<integer, boolean>>
local stockSensitive = {}
---@type table<integer, boolean>
local recipeStock = {}

local function ResetCraftCosts()
	obtainCost, reaches, periods, heldCost, stockSensitive, unitCosts, unitMakers, recipeStock =
		{}, {}, {}, {}, {}, {}, {}, {}
end

-- An item no recipe makes shares this one empty list: MakersOf runs for every priced item, and callers only read it.
local NO_MAKERS = {}

-- The recipes that make `itemID`, lowest recipe ID first, from the bundled recipe data. Built once, like
-- the reagent index: the bundle does not change in a session.
---@param itemID integer
---@return integer[]
local function MakersOf(itemID)
	if not craftMakers then
		craftMakers = {}
		for recipeID, recipe in pairs(ns.RecipeData or {}) do
			local output = recipe.output
			if output then
				local makers = craftMakers[output.itemID]
				if not makers then
					makers = {}
					craftMakers[output.itemID] = makers
				end
				makers[#makers + 1] = recipeID
			end
		end
		for _, makers in pairs(craftMakers) do
			table.sort(makers)
		end
	end
	return craftMakers[itemID] or NO_MAKERS
end
ns.MakersOf = MakersOf

-- One craft of `recipeID` makes this many, or nil when the data does not say.
---@param recipeID integer
---@return number?
local function OutputQuantity(recipeID)
	local output = ns.RecipeOutput(recipeID)
	return output and output.quantity or nil
end

-- Copper for one unit of `itemID`: buying it, or the cheaper recipe that makes it. `stack` holds the
-- items already being priced, so a cycle reads as unpriced instead of recursing; nil at the top, made on the
-- first miss of the memo. Memoised per item.
--
-- A crafted intermediate is worth at least what selling it would bring: crafting a bolt from gathered cloth
-- costs nothing under the gathered-material setting, but using the bolt instead of selling it gives that sale
-- up, so it must not make the recipe that uses it look profitable (#598). A gathered material keeps the
-- setting's answer, free or its sale value. `MakersOf` is read both ways: an item no recipe makes is not an
-- intermediate, and one no recipe the character knows and can buy nowhere stays unpriced rather than guessed.
---@param itemID integer
---@param cost number?
---@return number?
local function WithSaleFloor(itemID, cost)
	if not cost or #MakersOf(itemID) == 0 or ns.CanGather(itemID) then
		return cost
	end
	local sale = SaleValue(itemID)
	if sale and sale > cost then
		return sale
	end
	return cost
end

-- Whether `recipeID` may make an intermediate: learned, not set aside with "Not this recipe", and with an output
-- and reagents the data names. Both the market choice here and the planner's held inputs (#858) ask this.
---@param recipeID integer
---@return boolean
local function UsableMaker(recipeID)
	if not ns.IsLearned(recipeID) or (ns.IsSkipped and ns.IsSkipped(recipeID)) then
		return false
	end
	local quantity, reagents = OutputQuantity(recipeID), ns.Reagents(recipeID)
	return quantity ~= nil and quantity > 0 and reagents ~= nil and #reagents > 0
end
ns.UsableMaker = UsableMaker

-- Only dependencies whose stock can be spent need an allocation ledger during pricing.
local UsesStock

---@param reagents SkillUpReagent[]?
---@param depth integer
---@return boolean
local function StockSensitive(reagents, depth)
	if reagents then
		for _, reagent in ipairs(reagents) do
			if UsesStock(reagent.itemID, depth) then
				return true
			end
		end
	end
	return false
end

---@param itemID integer
---@param depth integer
---@return boolean
UsesStock = function(itemID, depth)
	local cached = stockSensitive[depth]
	if not cached then
		cached = {}
		stockSensitive[depth] = cached
	end
	local limited = cached[itemID]
	if limited == nil then
		limited = ns.LimitedReagentPrice(itemID) ~= nil
		if not limited and depth > 0 then
			for _, maker in ipairs(MakersOf(itemID)) do
				if UsableMaker(maker) and StockSensitive(ns.Reagents(maker), depth - 1) then
					limited = true
					break
				end
			end
		end
		cached[itemID] = limited
	end
	return limited
end

---@param recipeID integer
---@return boolean
function ns.RecipeUsesStock(recipeID)
	local known = recipeStock[recipeID]
	if known == nil then
		known = StockSensitive(ns.Reagents(recipeID), MAX_SUB_DEPTH)
		recipeStock[recipeID] = known
	end
	return known
end

-- The per-unit cost of this quantity, averaging the vendor and overflow portions.
---@param itemID integer
---@param count number
---@return number?
---@return SkillUpPrice?
---@return boolean limited
function ns.ReagentBuyCost(itemID, count)
	local first, vendor, overflow = ns.AllocateReagent(itemID, count)
	if vendor and first == count then
		return vendor.copper, vendor, true
	end
	local each = overflow
		and not overflow.unknown
		and ((vendor and first * vendor.copper or 0) + (count - first) * overflow.copper) / count
	return each or nil, overflow, vendor ~= nil
end

---@param itemID integer
---@param depth integer
---@param stack table<integer, true>?
---@return number?
local function UnitCost(itemID, depth, stack)
	if depth <= 0 then
		local price = ns.Price(itemID)
		return price and not price.unknown and WithSaleFloor(itemID, price.copper) or nil
	end
	local cached = unitCosts[itemID]
	if cached == false then
		return nil
	elseif cached ~= nil then
		return cached
	end
	if stack == nil then
		stack = {}
	elseif stack[itemID] then
		return nil
	end
	local buy = ns.Price(itemID)
	local best = buy and not buy.unknown and buy.copper or nil
	---@type integer?
	local bestRecipe = nil
	stack[itemID] = true
	for _, recipeID in ipairs(MakersOf(itemID)) do
		if UsableMaker(recipeID) then
			local quantity, reagents = assert(OutputQuantity(recipeID)), ns.Reagents(recipeID) or {}
			---@type number?
			local total = 0
			for _, reagent in ipairs(reagents) do
				local each = UnitCost(reagent.itemID, depth - 1, stack)
				if not each then
					total = nil
					break
				end
				total = total + each * reagent.quantity
			end
			local unit = total and total / quantity
			-- A craft wins only when it is strictly cheaper than buying: on a tie the vendor wins.
			if unit and (not best or unit < best) then
				best, bestRecipe = unit, recipeID
			end
		end
	end
	stack[itemID] = nil
	best = WithSaleFloor(itemID, best)
	if best == nil then
		unitCosts[itemID] = false
		return nil
	end
	local cost = assert(best)
	unitCosts[itemID] = cost
	if bestRecipe then
		unitMakers[itemID] = { recipeID = bestRecipe, quantity = assert(OutputQuantity(bestRecipe)), purchaseUnits = 0 }
	end
	return cost
end

-- Every item ObtainCost(itemID, _, depth) can read, in a fixed order: the item, then what each usable maker's
-- reagents reach one level down. The memo key reads the ledger and stack at exactly these items.
---@param itemID integer
---@param depth integer
---@return integer[]
---@return integer period
local function Reach(itemID, depth)
	local byDepth = reaches[itemID]
	if not byDepth then
		byDepth = {}
		reaches[itemID] = byDepth
		periods[itemID] = {}
	end
	local list = byDepth[depth]
	if list then
		return list, periods[itemID][depth]
	end
	local seen = { [itemID] = true }
	local period = 1
	list = { itemID }
	if depth > 0 then
		for _, maker in ipairs(MakersOf(itemID)) do
			if UsableMaker(maker) then
				period = period * assert(OutputQuantity(maker))
				for _, reagent in ipairs(ns.Reagents(maker) or {}) do
					local below, belowPeriod = Reach(reagent.itemID, depth - 1)
					period = period * belowPeriod
					for _, id in ipairs(below) do
						if not seen[id] then
							seen[id] = true
							list[#list + 1] = id
						end
					end
				end
			end
		end
	end
	byDepth[depth] = list
	periods[itemID][depth] = period
	return list, period
end

-- The batch counts worth pricing for count units made quantity per batch. Testing every count instead repeats the
-- subtree's whole search per count at every depth, which froze the client on a long route (#899). The bound is exact:
--
-- cost(b) = Buy(count - b * quantity) + sum over reagents of Cost_i(need_i * b). Buy is linear in b except where the
-- vendor's units or the purchase run out (the two bends below). By induction on depth, past its stock window each
-- Cost_i is a minimum of functions that are linear in its count on every residue class modulo its period: a fixed
-- small batch count plus purchases, or a batch count tied to its own bends or end. A minimum of linear functions is
-- concave, so between bends cost(b) is concave on each residue class of b modulo `period`, and its minimum on a
-- segment lies within one period of the segment's ends, where the earliest tie also lies. Inside the stock window
-- stock can still bend some Cost_i, so every batch count there is priced; one stocked unit feeds at most `period`
-- batches, and each level below can put its own window and purchase bend in front, hence the (depth + 1) factor.
-- Checked against the full search on every bundled recipe (tests/price_recursion_spec.lua guards the work bound).
---@return integer[]
local function BatchCandidates(itemID, depth, ledger, firstBatch, lastBatch, quantity, count, first)
	local reach, period = Reach(itemID, depth)
	local stock = 0
	for _, id in ipairs(reach) do
		local units = ledger[id] or ns.LimitedReagentPrice(id)
		if units and units > 0 then
			stock = stock + units
		end
		-- Spare batch output bends a cost the same way stock does.
		stock = stock + math.max(ledger[-id] or 0, 0)
	end
	local wanted, list = {}, {}
	local function Span(from, to)
		for batches = math.max(firstBatch, from), math.min(lastBatch, to) do
			if not wanted[batches] then
				wanted[batches] = true
				list[#list + 1] = batches
			end
		end
	end
	Span(firstBatch, firstBatch + ((depth + 1) * stock + 1) * period)
	for _, units in ipairs({ count - first, count }) do
		local bend = math.floor(units / quantity)
		Span(bend - period, bend + period + 1)
	end
	Span(lastBatch - period, lastBatch)
	table.sort(list)
	return list
end

local ObtainCost

-- The most stock a subtree could use, across its buy and whole-batch craft options.
---@param itemID integer
---@param count number
---@param depth integer
---@param stack table<integer, true>
---@param ledger table<integer, number>
---@return table<integer, number>
local function StockDemand(itemID, count, depth, stack, ledger)
	local demand = {}
	if count <= 0 or stack[itemID] or not UsesStock(itemID, depth) then
		return demand
	end
	local available = ledger[itemID] or ns.LimitedReagentPrice(itemID)
	if available and available > 0 then
		demand[itemID] = math.min(available, count)
	end
	if depth > 0 then
		stack[itemID] = true
		for _, maker in ipairs(MakersOf(itemID)) do
			if UsableMaker(maker) then
				local batches = math.ceil(count / assert(OutputQuantity(maker)))
				local inputs = {}
				for _, reagent in ipairs(ns.Reagents(maker) or {}) do
					for id, units in
						pairs(StockDemand(reagent.itemID, reagent.quantity * batches, depth - 1, stack, ledger))
					do
						inputs[id] = (inputs[id] or 0) + units
					end
				end
				for id, units in pairs(inputs) do
					-- Buying part of the demand can coexist with making the rest.
					local own = id == itemID and math.min(available or 0, count) or 0
					demand[id] = math.max(demand[id] or 0, own + units)
				end
			end
		end
		stack[itemID] = nil
	end
	return demand
end

-- A stock ledger maps an item to the units its limited vendor has left (absent: the whole stock), and the negative
-- of an item to the spare units of it that whole batches already made (absent: none).
-- A sibling can use its share of contested items and the common balance of everything else.
---@param ledger table<integer, number>
---@param caps table<integer, number>?
---@return table<integer, number>
local function StockFor(ledger, caps)
	if not caps then
		return ledger
	end
	local stock = {}
	for id, balance in pairs(ledger) do
		stock[id] = balance
	end
	for id, units in pairs(caps) do
		stock[id] = units
	end
	return stock
end
ns.StockFor = StockFor

---@param ledger table<integer, number>
---@param stock table<integer, number>
---@param caps table<integer, number>?
local function SpendStock(ledger, stock, caps)
	if caps then
		for id, balance in pairs(stock) do
			local cap = caps[id]
			if cap then
				local available = ledger[id] or ns.LimitedReagentPrice(id) or 0
				ledger[id] = available - (cap - balance)
			else
				ledger[id] = balance
			end
		end
	end
end
ns.SpendStock = SpendStock

-- Only stock that multiple siblings can exhaust together needs a split. Test the possible shares
-- at this recipe, bounded by what its siblings could use. The rest stays in the common ledger. A split is scored as
-- the siblings are then obtained: in reagent order on one running ledger, so spare output an earlier sibling's
-- batch makes covers a later one, and by acquisition cost, since a sale floor is not money paid.
---@param reagents SkillUpReagent[]
---@param ledger table<integer, number>
---@param needs number[]?
---@param depth integer?
---@param stack table<integer, true>?
---@return table<integer, table<integer, number>>?
local function StockShares(reagents, ledger, needs, depth, stack)
	if #reagents < 2 then
		return nil
	end
	local limit, ancestors = depth or MAX_SUB_DEPTH, stack or {}
	local demand, total, owners, order, contested = {}, {}, {}, {}, {}
	for index, reagent in ipairs(reagents) do
		demand[index] =
			StockDemand(reagent.itemID, needs and needs[index] or reagent.quantity, limit, ancestors, ledger)
		order[index] = index
		for id, units in pairs(demand[index]) do
			total[id] = (total[id] or 0) + units
			owners[id] = (owners[id] or 0) + 1
		end
	end
	for id, units in pairs(total) do
		local balance = ledger[id] or ns.LimitedReagentPrice(id) or 0
		if owners[id] > 1 and units > balance then
			contested[#contested + 1] = id
		end
	end
	if #contested == 0 then
		return nil
	end
	table.sort(contested)
	table.sort(order, function(a, b)
		local left, right = reagents[a].itemID, reagents[b].itemID
		return left == right and a < b or left < right
	end)
	local shares = {}
	local best, selected
	for index in ipairs(reagents) do
		shares[index] = {}
	end
	local function Score()
		local running, cost = {}, 0
		for id, balance in pairs(ledger) do
			running[id] = balance
		end
		for index, reagent in ipairs(reagents) do
			local need = needs and needs[index] or reagent.quantity
			if need > 0 then
				local stock = StockFor(running, shares[index])
				local each = ObtainCost(reagent.itemID, need, limit, ancestors, stock, true, true)
				if not each then
					return
				end
				SpendStock(running, stock, shares[index])
				cost = cost + each * need
			end
		end
		if not best or cost < best then
			best, selected = cost, {}
			for index, share in ipairs(shares) do
				local caps = {}
				for id, units in pairs(share) do
					caps[id] = units
				end
				selected[index] = caps
			end
		end
	end
	local function Split(group, index, balance, wanted)
		local id = contested[group]
		local sibling = order[index]
		local maximum = demand[sibling][id] or 0
		local later = wanted - maximum
		for units = math.min(balance, maximum), math.max(0, balance - later), -1 do
			shares[sibling][id] = units
			if index < #order then
				Split(group, index + 1, balance - units, later)
			elseif contested[group + 1] then
				local nextID = contested[group + 1]
				Split(group + 1, 1, ledger[nextID] or ns.LimitedReagentPrice(nextID) or 0, total[nextID])
			else
				Score()
			end
		end
	end
	local first = contested[1]
	Split(1, 1, ledger[first] or ns.LimitedReagentPrice(first) or 0, total[first])
	return selected
end
ns.StockShares = StockShares

---@param itemID integer
---@param count number
---@param depth integer
---@param stack table<integer, true>?
---@param remaining table<integer, number>?
---@param take boolean?
---@param forPurchases boolean? Price whole batches for an acquisition decision.
---@return number?
---@return SkillUpMakerChoice?
ObtainCost = function(itemID, count, depth, stack, remaining, take, forPurchases)
	if stack and stack[itemID] then
		return nil
	end
	local linear = linearCosts[itemID]
	if linear ~= nil then
		return linear or nil
	end
	local makers = MakersOf(itemID)
	if #makers == 0 and not (ns.db.stock[itemID] or (ns.LimitedStock and ns.LimitedStock[itemID])) then
		local price = ns.Price(itemID)
		linear = price and not price.unknown and price.copper or false
		linearCosts[itemID] = linear
		return linear or nil
	end
	if not forPurchases and not UsesStock(itemID, depth) then
		local each = UnitCost(itemID, depth, stack)
		return each, depth > 0 and unitMakers[itemID] or nil
	end
	local reach = Reach(itemID, depth)
	local parts = { itemID .. ":" .. count .. ":" .. depth .. ":" .. (forPurchases and 1 or 0) }
	for _, id in ipairs(reach) do
		parts[#parts + 1] = (remaining and remaining[id] or "-")
			.. "+"
			.. (remaining and remaining[-id] or 0)
			.. (stack and stack[id] and "s" or "")
	end
	local key = table.concat(parts, ":")
	local cached = obtainCost[key]
	if cached then
		if take and remaining and cached.after then
			for id, balance in pairs(cached.after) do
				remaining[id] = balance
			end
		end
		return cached.cost, cached.maker
	end
	local ledger = remaining or {}
	-- Spare output an earlier whole batch made is paid for: it covers what it can before anything is bought or made.
	local spare = math.min(ledger[-itemID] or 0, count)
	local wanted = count - spare
	local stock, overflow, vendor = ns.LimitedReagentPrice(itemID)
	local available = (remaining and remaining[itemID]) or stock or 0
	local first = math.min(available, wanted)
	if not vendor then
		overflow = ns.Price(itemID)
	end
	local vendorCopper = vendor and vendor.copper or 0
	local left = wanted - first
	local buy = overflow and not overflow.unknown and overflow.copper
	local best = left == 0 and first * vendorCopper or (buy and first * vendorCopper + left * buy or nil)
	---@type SkillUpMakerChoice?
	local maker
	local chosenStock
	if depth > 0 and #makers > 0 and wanted > 0 then
		stack = stack or {}
		stack[itemID] = true
		for _, recipeID in ipairs(makers) do
			if UsableMaker(recipeID) then
				local quantity, reagents = assert(OutputQuantity(recipeID)), ns.Reagents(recipeID) or {}
				-- Test each whole batch count. The remaining demand buys the cheapest available units first.
				local lastBatch = math.ceil(wanted / quantity)
				local firstBatch = buy and 1 or math.max(1, math.ceil((wanted - first) / quantity))
				for _, batches in
					ipairs(BatchCandidates(itemID, depth, ledger, firstBatch, lastBatch, quantity, wanted, first))
				do
					local purchases = math.max(wanted - batches * quantity, 0)
					local vendorUnits = math.min(purchases, first)
					local rest = purchases - vendorUnits
					local trial = {}
					for id, balance in pairs(ledger) do
						trial[id] = balance
					end
					if vendor then
						trial[itemID] = available - vendorUnits
					end
					-- What is left of the old spare, plus what this whole batch makes beyond the need.
					trial[-itemID] = (ledger[-itemID] or 0) - spare + batches * quantity - (wanted - purchases)
					---@type number?
					local total = vendorUnits * vendorCopper + rest * (buy or 0)
					local needs = {}
					for index, reagent in ipairs(reagents) do
						needs[index] = reagent.quantity * batches
					end
					local shares = StockShares(reagents, trial, needs, depth - 1, stack)
					for index, reagent in ipairs(reagents) do
						local caps = shares and shares[index]
						local stockForReagent = StockFor(trial, caps)
						local each =
							ObtainCost(reagent.itemID, needs[index], depth - 1, stack, stockForReagent, true, true)
						if not each then
							total = nil
							break
						end
						SpendStock(trial, stockForReagent, caps)
						total = total + each * needs[index]
					end
					if total and (not best or total < best) then
						best, chosenStock = total, trial
						maker = {
							recipeID = recipeID,
							quantity = quantity,
							purchaseUnits = purchases,
						}
					end
				end
			end
		end
		stack[itemID] = nil
	end
	-- What this choice leaves of the stock its subtree can reach; the ledger outside it is untouched.
	local after
	if chosenStock then
		after = {}
		for _, id in ipairs(reach) do
			after[id], after[-id] = chosenStock[id], chosenStock[-id]
		end
	elseif vendor or spare > 0 then
		after = { [itemID] = vendor and available - first or nil, [-itemID] = (ledger[-itemID] or 0) - spare }
	end
	if take and remaining and after then
		for id, balance in pairs(after) do
			remaining[id] = balance
		end
	end
	local each = best and best / count
	if not forPurchases and (first == 0 or not vendor) then
		each = WithSaleFloor(itemID, each)
	end
	obtainCost[key] = { cost = each, maker = maker, after = after }
	return each, maker
end

---@param itemID integer
---@param count number?
---@return number?
function ns.ObtainCost(itemID, count)
	local each = ObtainCost(itemID, count or 1, MAX_SUB_DEPTH)
	return each
end

---@param itemID integer
---@param count number?
---@param remaining table<integer, number>?
---@param depth integer?
---@param stack table<integer, true>?
---@return SkillUpMakerChoice?
function ns.SubCraft(itemID, count, remaining, depth, stack)
	if not count then
		if linearCosts[itemID] ~= nil then
			return nil
		end
		local classified = stockSensitive[MAX_SUB_DEPTH]
		if classified and classified[itemID] == false and unitCosts[itemID] ~= nil then
			return unitMakers[itemID]
		end
	end
	local _, maker = ObtainCost(itemID, count or 1, depth or MAX_SUB_DEPTH, stack, remaining, nil, remaining ~= nil)
	return maker
end

-- What using one held unit of `itemID` gives up: the lesser of selling it (SaleValue: auction after the cut,
-- with the vendor's price as the floor) and obtaining another (ObtainCost). Selling and buying back never costs
-- more than replacing it, so a held copy is never worth more than its ordinary acquisition cost. A sale value
-- known to be zero makes the copy free to use; an unknown sale value falls back to ObtainCost, so unknown is
-- never free. Nil when neither is known.
---@param itemID integer
---@return number?
function ns.HeldCost(itemID)
	local cached = heldCost[itemID]
	if cached == nil then
		local obtain = ObtainCost(itemID, 1, MAX_SUB_DEPTH)
		local sale = SaleValue(itemID)
		if sale == nil then
			cached = obtain or false
		elseif obtain == nil then
			cached = sale
		else
			cached = math.min(sale, obtain)
		end
		heldCost[itemID] = cached
	end
	return cached or nil
end

---@param reagent SkillUpReagent
---@param remaining table<integer, number>?
---@return number?
---@return SkillUpMakerChoice?
---@return SkillUpPrice?
function ns.PriceRecipeReagent(reagent, remaining)
	local available, overflow, vendor = ns.LimitedReagentPrice(reagent.itemID)
	local balance = remaining and remaining[reagent.itemID] or available
	local price = vendor and ((balance or 0) >= reagent.quantity and vendor or overflow) or ns.Price(reagent.itemID)
	local each, maker = ObtainCost(reagent.itemID, reagent.quantity, MAX_SUB_DEPTH, nil, remaining, remaining ~= nil)
	return each, maker, price
end

-- Copper for one craft's reagents, or nil when any has no known price: a partial sum would rank a
-- recipe as cheap only because we can't price its reagents. A reagent a known recipe makes is priced
-- at the cheaper of buying and crafting it.
---@param recipeID integer
---@return number?
local function ReagentCost(recipeID)
	local reagents = ns.Reagents(recipeID)
	if not reagents then
		return nil
	end
	local total = 0
	local remaining = ns.RecipeUsesStock(recipeID) and {} or nil
	local shares = remaining and StockShares(reagents, remaining)
	for index, reagent in ipairs(reagents) do
		local caps = shares and shares[index]
		local stock = remaining and StockFor(remaining, caps)
		local each = ObtainCost(reagent.itemID, reagent.quantity, MAX_SUB_DEPTH, nil, stock, stock ~= nil)
		if not each then
			return nil
		end
		if remaining and stock then
			SpendStock(remaining, stock, caps)
		end
		total = total + each * reagent.quantity
	end
	return total
end

-- What one crafted item is worth under the craft value setting, and where that came from: the higher of the
-- vendor's guaranteed price and the market value the chosen source gives it. A listing is worth what it leaves
-- after the auction house's cut; the reported regional sale average is counted unchanged as an estimate.
---@param sell number?
---@param market number?
---@param source 'auction'|'sale'?
---@return number?
---@return 'vendor'|'auction'|'sale'|nil
local function ItemValue(sell, market, source)
	local mode = ns.db.craftValue
	if mode == "none" then
		return nil
	end
	local vendor = sell and sell > 0 and sell or nil
	local resale = market
	if resale and source == "auction" then
		resale = resale * (1 - AUCTION_CUT)
	end
	if resale and (not vendor or resale > vendor) then
		return resale, source
	end
	return vendor, vendor and "vendor" or nil
end

-- What one craft sells for: { copper, source, quantity }, or nil when it counts for nothing. The
-- second result is true when that is only because no price is known (yet). The sale mode asks only for the
-- regional sale average, never for a listing: a missing sale falls back to the vendor, or stays unknown.
---@param recipeID integer
---@return SkillUpValue?
---@return boolean?
local function CraftValue(recipeID)
	local output = ns.RecipeOutput(recipeID)
	if not output then
		return nil
	end
	local mode = ns.db.craftValue
	if mode == "none" then
		return nil
	end
	local sell = SellPrice(output.itemID)
	---@type number?
	local market = nil
	---@type 'auction'|'sale'?
	local marketSource = nil
	if mode == "auction" then
		local ah = AuctionPrice(output.itemID)
		market, marketSource = ah and ah.copper, "auction"
	elseif mode == "sale" then
		market, marketSource = TradeSkillMasterSale(output.itemID), "sale"
	end
	local each, source = ItemValue(sell, market, marketSource)
	if not (each and source) then
		return nil, not (sell or market)
	end
	local volume = TradeSkillMasterSoldPerDay(output.itemID)
	return { copper = each * output.quantity, source = source, quantity = output.quantity, volume = volume }
end

-- What one craft sells for at a vendor and at the auction house, both at once, for the tooltip's comparison:
-- the vendor's guaranteed price and the chosen auction source's listing after the house's cut. A zero vendor
-- price counts for nothing; an auction source's zero is still its answer, as in ItemValue. Disenchant value is
-- deliberately absent: #464 holds it until authoritative Forever yield data exists.
---@param recipeID integer
---@return { vendor?: SkillUpValue, auction?: SkillUpValue }
function ns.CraftSaleValues(recipeID)
	local recipe = Recipe(recipeID)
	local output = recipe and recipe.output
	if not output then
		return {}
	end
	local sell = SellPrice(output.itemID)
	local vendor = sell
			and sell > 0
			and { copper = sell * output.quantity, source = "vendor", quantity = output.quantity }
		or nil
	local ah = AuctionPrice(output.itemID)
	local auction = ah
			and {
				copper = ah.copper * (1 - AUCTION_CUT) * output.quantity,
				source = "auction",
				quantity = output.quantity,
			}
		or nil
	return { vendor = vendor, auction = auction }
end

-- What one craft costs, the one place that says so. Unknown is nil, never free.
---@param recipeID integer
---@return number? cost its reagents; nil, with value and net, when one has no price or the recipe no known reagents
---@return SkillUpValue? value what the result sells for; nil when that counts for nothing
---@return number? net cost less value, negative when each craft makes money; nil while the sell price isn't known
function ns.CraftCost(recipeID)
	local cost = ReagentCost(recipeID)
	if not cost then
		return nil
	end
	local value, unpriced = CraftValue(recipeID)
	return cost, value, not unpriced and cost - (value and value.copper or 0) or nil
end

---@param recipeID integer
---@return number?
function ns.NetCost(recipeID)
	local _, _, net = ns.CraftCost(recipeID)
	return net
end

-- The open merchant's NPC id, from its creature GUID: Creature-0-1-0-0-5001-0000000001. A GUID the client
-- keeps secret names no merchant.
---@return integer?
local function MerchantNPC()
	local guid = ns.Readable(UnitGUID("npc"))
	return guid and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
end

-- Accept only finite integral API amounts. Missing data never becomes a one-item bundle.
local function Integral(value, minimum)
	return type(value) == "number" and value == value and value < math.huge and value >= minimum and value % 1 == 0
end

local function MoneyQuote(info)
	if not info.hasExtendedCost and Integral(info.price, 0) and Integral(info.stackCount, 1) then
		return info.price / info.stackCount
	end
end

-- Raw offer components and API stock provenance: docs/merchant-evidence.md.
local function RecordEvidence(itemID, npcID, info)
	local vendors = ns.db.merchantEvidence
	local vendor = vendors[npcID] or {}
	vendors[npcID] = vendor
	local available = Integral(info.numAvailable, -1) and info.numAvailable or nil
	local extendedCost
	if type(info.hasExtendedCost) == "boolean" then
		extendedCost = info.hasExtendedCost
	end
	---@type SkillUpMerchantEvidence
	local observation = {
		price = Integral(info.price, 0) and info.price or nil,
		stackCount = Integral(info.stackCount, 1) and info.stackCount or nil,
		hasExtendedCost = extendedCost,
		numAvailable = available,
		stockSource = available and "C_MerchantFrame.GetItemInfo.numAvailable" or nil,
		stock = available == -1 and "unlimited" or available,
		unitCopper = MoneyQuote(info),
		observedAt = GetServerTime(),
	}
	local seen = vendor[itemID]
	if seen then
		local same = true
		for key, value in pairs(observation) do
			if seen[key] ~= value then
				same = false
			end
		end
		for key, value in pairs(seen) do
			if observation[key] ~= value then
				same = false
			end
		end
		if same then
			return false
		end
	end
	vendor[itemID] = observation
	return true
end

-- What the open window shows this vendor sells at a time: the highest count seen as it restocks, or false
-- once it shows no limit. A sold-out item shows zero, which proves a limit, so it is kept as at least one.
---@param itemID integer
---@param npcID integer
---@param numAvailable integer
---@return boolean changed
local function RecordStock(itemID, npcID, numAvailable)
	local vendors = ns.db.stock[itemID]
	if not vendors then
		vendors = {}
		ns.db.stock[itemID] = vendors
	end
	local seen = vendors[npcID]
	if numAvailable < 0 then
		if seen ~= false then
			vendors[npcID] = false
			return true
		end
		return false
	end
	local count = math.max(numAvailable, 1)
	if seen ~= false and (type(seen) ~= "number" or count > seen) then
		vendors[npcID] = count
		return true
	end
	return false
end

-- Vendor prices: recorded per unit for anything bought with plain money. Without a stack size the
-- unit price isn't known, so the last one seen stays. The vendor is noted as a seller of what it shows, and
-- as the latest word on its stock: what the window says replaces the bundled limit for that vendor.
---@return SkillUpChange?
local function RecordMerchant()
	local npcID = MerchantNPC()
	-- MERCHANT_UPDATE arrives for what this addon does not read too (another tab, a restock elsewhere). A
	-- window that still shows the last scan's offers has nothing to record, so nothing is rebuilt or notified.
	if ns.MerchantOffers.Unchanged(npcID) then
		return nil
	end
	local changed, stocked, evidence, availabilityChanged, sold = false, false, false, false, {}
	local offers, lastByItem = {}, {}
	for index = 1, GetMerchantNumItems() do
		local itemID = GetMerchantItemID(index)
		local info = ns.MerchantOffers.Read(index, itemID, npcID)
		offers[#offers + 1] = info
		sold[#sold + 1] = itemID
		if itemID and info.infoPresent then
			lastByItem[itemID] = info.rawInfo
			if npcID and Integral(info.numAvailable, -1) and RecordStock(itemID, npcID, info.numAvailable) then
				stocked = true
			end
			local each = MoneyQuote(info.rawInfo)
			if each and each > 0 and ns.db.vendor[itemID] ~= each then
				ns.db.vendor[itemID] = each
				changed = true
			end
		end
	end
	for itemID, info in pairs(lastByItem) do
		if npcID then
			local observations = ns.db.merchantEvidence[npcID]
			local previous = observations and observations[itemID]
			if RecordEvidence(itemID, npcID, info) then
				evidence = true
				if
					(
						(previous and previous.numAvailable or nil) ~= info.numAvailable
						or (previous and previous.unitCopper or nil) ~= MoneyQuote(info)
					) and (MarketGood(itemID) and ns.db.stock[itemID] ~= nil)
				then
					availabilityChanged = true
				end
			end
		end
	end
	evidence = ns.MerchantOffers.Replace(offers) or evidence
	local seen = ns.SeeVendor(sold)
	if evidence then
		ns.Changed("sourceEvidence")
	end
	return (changed or stocked or availabilityChanged) and "prices" or seen and "sources" or nil
end

local function PricesChanged()
	ns.Changed("prices")
end

function ns.InitPrices()
	if type(ns.db.merchantEvidence) ~= "table" then
		ns.db.merchantEvidence = {}
	end
	if type(ns.db.vendor) ~= "table" then
		ns.db.vendor = {}
	end
	if type(ns.db.stock) ~= "table" then
		ns.db.stock = {}
	end
	ns.WhenStale("schematics", function()
		-- A schematic the client gave stays: switching profession tabs must not send every other profession
		-- back to the bundle, to be read again when its tab opens. What came from the bundle goes.
		for recipeID in pairs(fromBundle) do
			recipes[recipeID] = nil
		end
		fromBundle = {}
		ResetCraftCosts()
	end)
	ns.WhenStale("craftCosts", function()
		stockVendors, limitedQuotes = {}, {}
		ResetCraftCosts()
	end)
	ns.WhenStale("prices", function()
		priceCache, linearCosts, stockVendors, limitedQuotes = {}, {}, {}, {}
		professions = nil
		ResetCraftCosts()
	end)
	ns.WhenEvent("ZONE_CHANGED_NEW_AREA", function()
		for itemID, previous in pairs(stockVendors) do
			if (ns.NearestVendor(itemID, true) or false) ~= previous then
				return "prices"
			end
		end
	end)
	ns.WhenEvent("SKILL_LINES_CHANGED", function()
		return ProfessionsChanged() and "professions" or nil
	end)
	-- The open window's own schematics for recipes priced from the bundle while it was closed join the window's
	-- event as a recipe change, so what draws the window draws it from them. A window with nothing new is no change.
	local function WindowSchematics()
		if not C_TradeSkillUI.GetAllRecipeIDs then
			return nil
		end
		return ns.LiveSchematicsArrived(C_TradeSkillUI.GetAllRecipeIDs()) and "recipes" or nil
	end
	for _, event in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_DATA_SOURCE_CHANGED", "TRADE_SKILL_LIST_UPDATE" }) do
		ns.WhenEvent(event, WindowSchematics)
	end
	ns.WhenEvent("MERCHANT_SHOW", function()
		ns.MerchantOffers.Open()
		return RecordMerchant()
	end)
	ns.WhenEvent("MERCHANT_CLOSED", function()
		if ns.MerchantOffers.Replace(nil) then
			ns.Changed("sourceEvidence")
		end
	end)
	ns.WhenEvent("MERCHANT_UPDATE", RecordMerchant)
	-- A sell price a price was made without arrived. It changes prices only when it differs from the value used
	-- meanwhile, and every arrival in a frame shares one change.
	local repricing = false
	local function Reprice()
		repricing = false
		PricesChanged()
	end
	ns.WhenEvent("GET_ITEM_INFO_RECEIVED", function(itemID, success)
		local used = awaitingSell[itemID]
		if used == nil then
			return nil
		end
		awaitingSell[itemID] = nil
		local sell = success and ns.Readable((select(11, C_Item.GetItemInfo(itemID))))
		if sell == nil or sell == used or repricing then
			return nil
		end
		repricing = true
		C_Timer.After(0, Reprice)
	end)
	-- On this client Auctionator fires this after a search or a full scan has filed its prices.
	local api = AuctionatorAPI()
	if api and api.RegisterForDBUpdate then
		api.RegisterForDBUpdate(addonName, PricesChanged)
	end
	-- Installed price addons finish loading their databases at login. Drop any early misses once on entering the world.
	if ns.HasAHDB() and type(AuctionDB.Listen) == "function" then
		pcall(AuctionDB.Listen, AuctionDB, "SCAN_DATA", PricesChanged)
		pcall(AuctionDB.Listen, AuctionDB, "HISTORY_MERGED", PricesChanged)
	end
	if api or ns.HasTradeSkillMaster() or ns.HasAHDB() or ns.HasNaowhForever() then
		local entered = false
		ns.WhenEvent("PLAYER_ENTERING_WORLD", function()
			if entered then
				return nil
			end
			entered = true
			return "prices"
		end)
	end
end
