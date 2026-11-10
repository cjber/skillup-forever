---@type string, SkillUpNamespace
local addonName, ns = ...

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

-- Auctionator's own observation when it has one, so a player with both keeps the prices they had.
---@param itemID integer
---@return SkillUpPrice?
local function AuctionPrice(itemID)
	return AuctionatorPrice(itemID) or TradeSkillMasterPrice(itemID)
end

local itemInfoPending = false

-- Live vendor sell price wins, including zero. Bundled prices cover uncached
-- outputs while the item-data request and eventual refresh are still pending.
---@param itemID integer
---@return number?
local function SellPrice(itemID)
	local sell = ns.Readable((select(11, C_Item.GetItemInfo(itemID))))
	if sell == nil then
		itemInfoPending = true
		C_Item.RequestLoadItemDataByID(itemID)
	end
	return sell or (ns.ItemSellPrices and ns.ItemSellPrices[itemID])
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
	local worth, from, market = nil, nil, nil
	if ns.db.valueGathered or marketOnly then
		worth, from, market = SaleValue(itemID)
	end
	if marketOnly and not (worth and worth > 0) then
		-- No market price: leave it unknown, never a free material (issue #399).
		return nil
	end
	---@type SkillUpPrice
	local price = {
		copper = worth or 0,
		-- Priced from the market, a self-supplied reagent is bought there in the shopping list too.
		source = marketOnly and (from == "auction" and market or "vendor") or "gather",
		worth = from,
	}
	if source == "loot" then
		price.loot = true
	else
		price.profession = source
	end
	return price
end

-- Cheapest known unit price and where it came from: "gather", "vendor", "auctionator"
-- or "tsm". A price seen at a vendor beats the bundled list, since it includes
-- any reputation discount.
---@param itemID integer
---@return SkillUpPrice?
function ns.Price(itemID)
	---@type SkillUpPrice|false|nil
	local cached = priceCache[itemID]
	if cached == nil then
		local vendor = ns.db.vendor[itemID] or ns.VendorPrices[itemID]
		local ah = AuctionPrice(itemID)
		if ns.CollectMode() == "gather" then
			cached = Gathered(itemID)
		end
		if cached then
			priceCache[itemID] = cached
			return cached
		elseif vendor and (not ah or vendor <= ah.copper) then
			cached = { copper = vendor, source = "vendor" }
		elseif ah then
			cached = ah
		else
			-- With *Buy reagents* on, a material you gather that no vendor or auction prices is still yours to
			-- gather: priced as gathered rather than left out, which could empty the route (#162).
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
		local quantity = ((schematic.quantityMin or 1) + (schematic.quantityMax or schematic.quantityMin or 1)) / 2
		if quantity <= 0 then
			return nil
		end
		recipe.output = { itemID = schematic.outputItemID, quantity = quantity }
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
---@type table<integer, integer[]>?
local craftMakers

local function ResetCraftCosts()
	obtainCost, subCraft = {}, {}
end

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
	return craftMakers[itemID] or {}
end
ns.MakersOf = MakersOf

-- One craft of `recipeID` makes this many, or nil when the data does not say.
---@param recipeID integer
---@return number?
local function OutputQuantity(recipeID)
	local recipe = Recipe(recipeID)
	local output = recipe and recipe.output
	return output and output.quantity or nil
end

-- Copper for one unit of `itemID`: buying it, or the cheaper recipe that makes it. `stack` holds the
-- items already being priced, so a cycle reads as unpriced instead of recursing; nil at the top, made on the
-- first miss of the memo. Memoised per item.
---@param itemID integer
---@param depth integer
---@param stack table<integer, true>?
---@return number?
local function ObtainCost(itemID, depth, stack)
	if depth <= 0 then
		local price = ns.Price(itemID)
		return price and price.copper
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
	local best = buy and buy.copper
	---@type integer?
	local bestRecipe = nil
	stack[itemID] = true
	for _, recipeID in ipairs(MakersOf(itemID)) do
		local quantity, reagents = OutputQuantity(recipeID), ns.Reagents(recipeID)
		local skipped = ns.IsSkipped ~= nil and ns.IsSkipped(recipeID)
		if ns.IsLearned(recipeID) and not skipped and quantity and quantity > 0 and reagents and #reagents > 0 then
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

-- What one crafted item is worth under the craft value setting, and where that came from.
---@param sell number?
---@param auction number?
---@return number?
---@return 'vendor'|'auction'|nil
local function ItemValue(sell, auction)
	local mode = ns.db.craftValue
	if mode == "none" then
		return nil
	end
	local vendor = sell and sell > 0 and sell or nil
	local resale = mode == "auction" and auction and auction * (1 - AUCTION_CUT) or nil
	if resale and (not vendor or resale > vendor) then
		return resale, "auction"
	end
	return vendor, vendor and "vendor" or nil
end

-- What one craft sells for: { copper, source, quantity }, or nil when it counts for nothing. The
-- second result is true when that is only because the sell price isn't known (yet).
---@param recipeID integer
---@return SkillUpValue?
---@return boolean?
local function CraftValue(recipeID)
	local recipe = Recipe(recipeID)
	local output = recipe and recipe.output
	if not output then
		return nil
	end
	local ah = AuctionPrice(output.itemID)
	local sell = SellPrice(output.itemID)
	local each, source = ItemValue(sell, ah and ah.copper)
	if not (each and source) then
		return nil, sell == nil and ns.db.craftValue ~= "none"
	end
	return { copper = each * output.quantity, source = source, quantity = output.quantity }
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

-- What the open window shows this vendor sells at a time: the highest count seen as it restocks, or false
-- once it shows no limit. A count of zero says nothing about the stock, so it is not kept.
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
	elseif numAvailable > 0 and seen ~= false and (type(seen) ~= "number" or numAvailable > seen) then
		vendors[npcID] = numAvailable
		return true
	end
	return false
end

-- Vendor prices: recorded per unit for anything bought with plain money. Without a stack size the
-- unit price isn't known, so the last one seen stays. The vendor is noted as a seller of what it shows, and
-- as the latest word on its stock: what the window says replaces the bundled limit for that vendor.
---@return SkillUpChange?
local function RecordMerchant()
	local changed, stocked, sold = false, false, {}
	local npcID = MerchantNPC()
	for index = 1, GetMerchantNumItems() do
		local itemID = GetMerchantItemID(index)
		local info = C_MerchantFrame.GetItemInfo(index)
		sold[#sold + 1] = itemID
		if itemID and info then
			if npcID and type(info.numAvailable) == "number" and RecordStock(itemID, npcID, info.numAvailable) then
				stocked = true
			end
			if
				info.price
				and info.price > 0
				and info.stackCount
				and info.stackCount > 0
				and not info.hasExtendedCost
			then
				local each = info.price / info.stackCount
				if ns.db.vendor[itemID] ~= each then
					ns.db.vendor[itemID] = each
					changed = true
				end
			end
		end
	end
	local seen = ns.SeeVendor(sold)
	return changed and "prices" or (seen or stocked) and "sources" or nil
end

local function PricesChanged()
	ns.Changed("prices")
end

function ns.InitPrices()
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
	ns.WhenEvent("MERCHANT_SHOW", RecordMerchant)
	ns.WhenEvent("MERCHANT_UPDATE", RecordMerchant)
	ns.WhenEvent("GET_ITEM_INFO_RECEIVED", function()
		if itemInfoPending then
			-- Items arrive in bursts; one redraw covers the burst.
			itemInfoPending = false
			C_Timer.After(0.5, PricesChanged)
		end
	end)
	-- On this client Auctionator fires this after a search or a full scan has filed its prices.
	local api = AuctionatorAPI()
	if api and api.RegisterForDBUpdate then
		api.RegisterForDBUpdate(addonName, PricesChanged)
	end
	-- TradeSkillMaster reads its AuctionDB at login, so a price asked for before then came back empty.
	if ns.HasTradeSkillMaster() then
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
