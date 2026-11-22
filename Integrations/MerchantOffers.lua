---@type string, SkillUpNamespace
local _, ns = ...
if ns.broken then
	return
end

-- Source-only contract, not native stock or future supply certification.
local SOURCE = "bebcb6bf309cf41b41bd74f8ca651e6a105b2676"
local Offers = { session = 0 }
---@type SkillUpMerchantOfferWindow?
Offers.current = nil
-- The native readers the last scan used, one identity per capability. A replaced reader is another observation.
Offers.readers = {}

local function Integer(value, minimum)
	return type(value) == "number" and value == value and value < math.huge and value >= minimum and value % 1 == 0
end

-- Each capability can fail independently. Preserve holes in native tuples.
---@return any[]
local function Read(capabilities, name, fn, ...)
	if type(fn) ~= "function" then
		capabilities[name] = "missing"
		return {}
	end
	local values = { pcall(fn, ...) }
	if not values[1] then
		capabilities[name] = "failed"
		return {}
	end
	capabilities[name] = "available"
	for index = 2, 5 do
		local value = values[index]
		values[index] = ns.Readable(value)
		if type(value) ~= "nil" and values[index] == nil then
			capabilities[name] = "unreadable"
		end
	end
	return values
end

local function Same(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b or (type(a) == "number" and a ~= a and b ~= b)
	end
	for key, value in pairs(a) do
		if not Same(value, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

---@param index integer
---@param itemID integer?
---@param npcID integer?
---@return SkillUpObservedMerchantOffer
function Offers.Read(index, itemID, npcID)
	local caps = {}
	-- The readers this scan used, so Unchanged can tell a replaced one from the one it observed.
	local readers = Offers.readers
	readers.itemInfo = C_MerchantFrame and C_MerchantFrame.GetItemInfo
	readers.costCount = GetMerchantItemCostInfo
	readers.costSlot = GetMerchantItemCostItem
	readers.nativeMaximum = GetMerchantItemMaxStack
	readers.affordability = CanAffordMerchantItem
	local build = Read(caps, "build", GetBuildInfo)
	local raw = Read(caps, "itemInfo", C_MerchantFrame and C_MerchantFrame.GetItemInfo, index)[2]
	local info = type(raw) == "table" and raw or {}
	---@type SkillUpObservedMerchantOffer
	local offer = {
		index = index,
		itemID = Integer(itemID, 1) and itemID or nil,
		npcID = Integer(npcID, 1) and npcID or nil,
		session = Offers.session,
		observedAt = GetServerTime(),
		sourceRevision = SOURCE,
		version = build[2],
		build = build[3],
		interface = build[5],
		projectID = ns.Readable(WOW_PROJECT_ID),
		infoPresent = type(raw) == "table",
		rawInfo = {},
		capabilities = caps,
		costs = {},
		reasons = {},
		requirementsComplete = true,
	}
	for _, key in ipairs({
		"price",
		"stackCount",
		"numAvailable",
		"hasExtendedCost",
		"isPurchasable",
		"isUsable",
		"currencyID",
		"spellID",
	}) do
		offer[key] = ns.Readable(info[key])
		offer.rawInfo[key] = offer[key]
	end
	local function Incomplete(reason)
		offer.requirementsComplete = false
		offer.reasons[#offer.reasons + 1] = reason
	end
	if not Integer(offer.price, 0) then
		offer.price = nil
		Incomplete("money component unavailable")
	end
	if not Integer(offer.stackCount, 1) then
		offer.stackCount = nil
		Incomplete("bundle quantity unavailable")
	end
	if not Integer(offer.numAvailable, -1) then
		offer.numAvailable = nil
	end
	for _, key in ipairs({ "isPurchasable", "isUsable", "hasExtendedCost" }) do
		if type(offer[key]) ~= "boolean" then
			offer[key] = nil
		end
	end
	local count = Read(caps, "costCount", GetMerchantItemCostInfo, index)[2]
	offer.rawCostCount = count
	if not Integer(count, 0) then
		Incomplete("reported cost count unavailable")
	else
		if offer.hasExtendedCost == nil or offer.hasExtendedCost ~= (count > 0) then
			Incomplete("extended cost flag and count inconsistent")
		end
		for slot = 1, count do
			local slotCaps = {}
			local values = Read(slotCaps, "read", GetMerchantItemCostItem, index, slot)
			caps.costSlot = slotCaps.read
			local cost = {
				slot = slot,
				texture = values[2],
				quantity = values[3],
				link = values[4],
				currencyName = values[5],
				capabilities = slotCaps,
			}
			offer.costs[slot] = cost
			local link = type(cost.link) == "string" and cost.link or ""
			local currency = cost.currencyName ~= nil or link:match("^currency:") or link:find("|Hcurrency:", 1, true)
			local id
			if currency then
				cost.kind = "currency"
				if link:match("^currency:%d+") or link:match("|Hcurrency:%d+") then
					id = Read(slotCaps, "identity", C_CurrencyInfo and C_CurrencyInfo.GetCurrencyIDFromLink, link)[2]
				end
			elseif link:match("^item:%d+") or link:match("|Hitem:%d+") then
				cost.kind = "item"
				id = Read(slotCaps, "identity", C_Item and C_Item.GetItemInfoInstant, link)[2]
			end
			if Integer(id, 1) then
				cost.id = id
			else
				Incomplete("cost slot " .. slot .. " stable identity unavailable")
			end
			if not Integer(cost.quantity, 1) then
				Incomplete("cost slot " .. slot .. " quantity unavailable")
			end
		end
	end
	local maximum = Read(caps, "nativeMaximum", GetMerchantItemMaxStack, index)[2]
	offer.rawNativeMaximum = maximum
	offer.maxPurchaseItems = Integer(maximum, 0) and maximum or nil
	local affordable = Read(caps, "affordability", CanAffordMerchantItem, index)[2]
	offer.rawCanAfford = affordable
	if type(affordable) == "boolean" then
		offer.canAfford = affordable
	end
	return offer
end

-- Replace the whole current window. Slot identity is session-local, and duplicate
-- products remain separate rows. No saved historical record is promoted here.
---@param offers SkillUpObservedMerchantOffer[]?
---@return boolean
function Offers.Replace(offers)
	local current = offers and { session = Offers.session, offers = offers } or nil
	if not Same(Offers.current, current) then
		Offers.current = current
		return true
	end
	return false
end

function Offers.Open()
	Offers.session = Offers.session + 1
end

-- Whether the open window still shows exactly what the last scan observed: the same session, vendor, slots,
-- items and native values. MERCHANT_UPDATE also arrives for what this addon does not read, and a scan builds an
-- offer table per slot where the client's own reads are cheap; this is the cheap question a scan waits on. A
-- reader the scan saw as missing, failed or unreadable, or one replaced since, is another observation.
---@param npcID integer?
---@return boolean
function Offers.Unchanged(npcID)
	local window = Offers.current
	if not window then
		return false
	end
	local offers = window.offers
	if window.session ~= Offers.session then
		return false
	end
	local count = GetMerchantNumItems()
	if count ~= #offers then
		return false
	end
	local readers = Offers.readers
	local getInfo, costCountAt = readers.itemInfo, readers.costCount
	local costSlotAt, maxStackAt = readers.costSlot, readers.nativeMaximum
	local affordAt = readers.affordability
	if
		(C_MerchantFrame and C_MerchantFrame.GetItemInfo) ~= getInfo
		or GetMerchantItemCostInfo ~= costCountAt
		or GetMerchantItemCostItem ~= costSlotAt
		or GetMerchantItemMaxStack ~= maxStackAt
		or CanAffordMerchantItem ~= affordAt
	then
		return false
	end
	for index = 1, count do
		local seen = offers[index]
		if seen.npcID ~= npcID then
			return false
		end
		local itemID = GetMerchantItemID(index) --[[@as integer?]]
		if not Integer(itemID, 1) then
			itemID = nil
		end
		if itemID ~= seen.itemID then
			return false
		end
		local raw
		if getInfo then
			if seen.capabilities.itemInfo ~= "available" then
				return false
			end
			raw = getInfo(index)
		elseif seen.capabilities.itemInfo ~= "missing" then
			return false
		end
		local info = type(raw) == "table" and raw or nil
		if info then
			if not seen.infoPresent then
				return false
			end
			local known = seen.rawInfo
			if
				info.price ~= known.price
				or info.stackCount ~= known.stackCount
				or info.numAvailable ~= known.numAvailable
				or info.hasExtendedCost ~= known.hasExtendedCost
				or info.isPurchasable ~= known.isPurchasable
				or info.isUsable ~= known.isUsable
				or info.currencyID ~= known.currencyID
				or info.spellID ~= known.spellID
			then
				return false
			end
		elseif seen.infoPresent then
			return false
		end
		local rawCount
		if costCountAt then
			if seen.capabilities.costCount ~= "available" then
				return false
			end
			rawCount = costCountAt(index)
		elseif seen.capabilities.costCount ~= "missing" then
			return false
		end
		if rawCount ~= seen.rawCostCount then
			return false
		end
		for slot = 1, (Integer(rawCount, 0) and rawCount) or 0 do
			local cost = seen.costs[slot]
			if not cost then
				return false
			end
			local texture, quantity, link, currencyName
			if costSlotAt then
				if cost.capabilities.read ~= "available" then
					return false
				end
				texture, quantity, link, currencyName = costSlotAt(index, slot)
			elseif cost.capabilities.read ~= "missing" then
				return false
			end
			if
				texture ~= cost.texture
				or quantity ~= cost.quantity
				or link ~= cost.link
				or currencyName ~= cost.currencyName
			then
				return false
			end
			-- A resolver that went away is another observation even when the link it reads stayed the same.
			if type(cost.link) == "string" and cost.kind then
				local resolver
				if cost.kind == "currency" then
					resolver = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyIDFromLink
				elseif cost.kind == "item" then
					resolver = C_Item and C_Item.GetItemInfoInstant
				end
				if (type(resolver) == "function" and "available" or "missing") ~= cost.capabilities.identity then
					return false
				end
			end
		end
		local maximum
		if maxStackAt then
			if seen.capabilities.nativeMaximum ~= "available" then
				return false
			end
			maximum = maxStackAt(index)
		elseif seen.capabilities.nativeMaximum ~= "missing" then
			return false
		end
		if maximum ~= seen.rawNativeMaximum then
			return false
		end
		local affordable
		if affordAt then
			if seen.capabilities.affordability ~= "available" then
				return false
			end
			affordable = affordAt(index)
		elseif seen.capabilities.affordability ~= "missing" then
			return false
		end
		if affordable ~= seen.rawCanAfford then
			return false
		end
	end
	return true
end

-- Arithmetic only: integer bundles and a full conjunction. No availability,
-- access, travel or order-success claim is returned by either operation.
---@param offer SkillUpObservedMerchantOffer
---@param bundles integer
---@return SkillUpMerchantQuote?
---@return string?
function Offers.Quote(offer, bundles)
	if not offer.requirementsComplete or not Integer(bundles, 1) then
		return nil, "complete requirements and positive integral bundles required"
	end
	local quote = { units = offer.stackCount * bundles, moneyCopper = offer.price * bundles, costs = {} }
	if not Integer(quote.units, 1) or not Integer(quote.moneyCopper, 0) then
		return nil, "quote arithmetic overflow"
	end
	for _, cost in ipairs(offer.costs) do
		local key = cost.kind .. ":" .. cost.id
		quote.costs[key] = (quote.costs[key] or 0) + cost.quantity * bundles
		if not Integer(quote.costs[key], 1) then
			return nil, "quote arithmetic overflow"
		end
	end
	return quote
end

---@cast Offers SkillUpMerchantOffers
ns.MerchantOffers = Offers
