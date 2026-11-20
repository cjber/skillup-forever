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
---@return number?
function ns.IsLimitedStock(itemID)
	local seen = ns.db.stock and ns.db.stock[itemID]
	local bundled = ns.LimitedStock and ns.LimitedStock[itemID]
	if not (seen or bundled) then
		return nil
	end
	local vendor = ns.NearestVendor(itemID, true)
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
-- that beats buying it. Cost recurses three levels, memoised per item, and a recipe that would need
-- the item it makes is skipped rather than followed, so no cycle can recurse or hang.

local MAX_SUB_DEPTH = 3
---@type table<integer, number|false>
local obtainCost = {}
---@type table<integer, {recipeID: integer, quantity: number}|false>
local subCraft = {}
---@type table<integer, number|false>
local heldCost = {}
---@type table<integer, integer[]>?
local craftMakers

local function ResetCraftCosts()
	obtainCost, subCraft, heldCost = {}, {}, {}
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
	local quantity, reagents = OutputQuantity(recipeID), ns.Reagents(recipeID)
	local skipped = ns.IsSkipped ~= nil and ns.IsSkipped(recipeID)
	return ns.IsLearned(recipeID)
		and not skipped
		and quantity ~= nil
		and quantity > 0
		and reagents ~= nil
		and #reagents > 0
end
ns.UsableMaker = UsableMaker

---@param itemID integer
---@param depth integer
---@param stack table<integer, true>?
---@return number?
local function ObtainCost(itemID, depth, stack)
	if depth <= 0 then
		local price = ns.Price(itemID)
		return price and not price.unknown and WithSaleFloor(itemID, price.copper) or nil
	end
	local cached = obtainCost[itemID]
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
				local each = ObtainCost(reagent.itemID, depth - 1, stack)
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
		obtainCost[itemID] = false
		return nil
	end
	local cost = assert(best)
	obtainCost[itemID] = cost
	if bestRecipe then
		subCraft[itemID] = { recipeID = bestRecipe, quantity = assert(OutputQuantity(bestRecipe)) }
	end
	return cost
end

-- What one unit of `itemID` costs to obtain: the cheaper of buying it and crafting it, the same number
-- `ReagentCost` totals. The tooltip prices each line with it so the lines and the Reagents total agree (#360).
---@param itemID integer
---@return number?
function ns.ObtainCost(itemID)
	return ObtainCost(itemID, MAX_SUB_DEPTH)
end

-- The recipe that makes `itemID` for less than buying it, with one craft's output; nil when buying
-- is cheaper, nothing learned makes it, or one of its own reagents has no price.
---@param itemID integer
---@return {recipeID: integer, quantity: number}?
function ns.SubCraft(itemID)
	ObtainCost(itemID, MAX_SUB_DEPTH)
	local maker = subCraft[itemID]
	return maker or nil
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
		local obtain = ObtainCost(itemID, MAX_SUB_DEPTH)
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

-- Copper for one craft's reagents, or nil when any has no known price: a partial sum would rank a
-- recipe as cheap only because we can't price its reagents. A reagent a known recipe makes is priced
-- at the cheaper of buying and crafting it.
---@param reagents SkillUpReagent[]?
---@return number?
local function ReagentCost(reagents)
	if not reagents then
		return nil
	end
	local total = 0
	for _, reagent in ipairs(reagents) do
		local each = ObtainCost(reagent.itemID, MAX_SUB_DEPTH)
		if not each then
			return nil
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
	local cost = ReagentCost(ns.Reagents(recipeID))
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
	local changed, stocked, evidence, sold = false, false, false, {}
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
		if npcID and RecordEvidence(itemID, npcID, info) then
			evidence = true
		end
	end
	evidence = ns.MerchantOffers.Replace(offers) or evidence
	local seen = ns.SeeVendor(sold)
	if evidence then
		ns.Changed("sourceEvidence")
	end
	return changed and "prices" or (seen or stocked) and "sources" or nil
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
	ns.WhenStale("prices", function()
		priceCache = {}
		professions = nil
		ResetCraftCosts()
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
