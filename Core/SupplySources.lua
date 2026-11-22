---@type string, SkillUpNamespace
local _, ns = ...
if ns.broken then
	return
end

-- Session-only source ownership. Quotes establish offer contents only. Nothing declares a source law, so
-- the current merchant window's evidence is always "unavailable" with each missing law named.
local Owner = {}
local FIELDS = { "access", "price", "stock", "vendor", "ceiling", "initialVisit", "refillVisit" }
local function Identity(offer)
	return tostring(offer.session) .. ":" .. tostring(offer.index)
end
local function Missing(code, offerID, field)
	return { code = code, offerID = offerID, field = field }
end

-- Every law of every offer of the products in the current window is missing; a product with no offer is too.
---@param products table<integer, true> Explicit product universe; all current competing offers are required.
---@return SkillUpSourceUnavailable[]
local function Unavailable(products)
	if type(products) ~= "table" or next(products) == nil then
		return { Missing("explicit-product-universe-required") }
	end
	local window = ns.MerchantOffers.current
	if not window then
		return { Missing("merchant-window-unavailable") }
	end
	if #window.offers == 0 then
		return { Missing("merchant-offers-unavailable") }
	end
	local missing, observedProducts = {}, {}
	for _, offer in ipairs(window.offers) do
		if products[offer.itemID] then
			observedProducts[offer.itemID] = true
			local id = Identity(offer)
			for _, field in ipairs(FIELDS) do
				missing[#missing + 1] = Missing("missing-law", id, field)
			end
		end
	end
	for itemID in pairs(products) do
		if not observedProducts[itemID] then
			missing[#missing + 1] = Missing("product-offers-unavailable", nil, tostring(itemID))
		end
	end
	return missing
end

local function CopyRecord(record)
	local copy = {}
	for key, value in pairs(record) do
		copy[key] = value
	end
	return copy
end

---@param evidence SkillUpSourceEvidence
---@return SkillUpSourceEvidence
local function CopyInspection(evidence)
	local missing, assumptions = {}, {}
	for index, record in ipairs(evidence.missing) do
		missing[index] = CopyRecord(record)
	end
	for index, record in ipairs(evidence.assumptions) do
		assumptions[index] = CopyRecord(record)
	end
	return {
		status = evidence.status,
		scope = evidence.scope,
		sourceRevision = evidence.sourceRevision,
		missing = missing,
		assumptions = assumptions,
	}
end

-- The API asks for evidence on every rebuild. The assembly is owned by this file for one window and product
-- universe, and each ask still receives its own records: a caller can change what it was given. A new merchant
-- session drops every assembled record; a new product universe gets its own.
---@type table<string, SkillUpSourceEvidence>
local inspected = {}
local inspectedSession
---@param window SkillUpMerchantOfferWindow?
---@param products table<integer, true>
---@return string
local function EvidenceKey(window, products)
	local ids = {}
	for itemID in pairs(products) do
		ids[#ids + 1] = tostring(itemID)
	end
	table.sort(ids)
	local key = tostring(window and window.session or 0)
	if window then
		for index, offer in ipairs(window.offers) do
			key = key .. "|" .. index .. ":" .. tostring(offer) .. ":" .. tostring(offer.itemID)
		end
	end
	return key .. "#" .. table.concat(ids, ",")
end

-- Evidence discovery does not need a confidence target or start a solver. Its
-- scope is deliberately the current window, never every source in the world.
---@param products table<integer, true>
---@return SkillUpSourceEvidence
function Owner.Inspect(products)
	local window = ns.MerchantOffers.current
	local session = window and window.session or 0
	if inspectedSession ~= session then
		inspected, inspectedSession = {}, session
	end
	local key = EvidenceKey(window, products)
	local cached = inspected[key]
	if cached then
		return CopyInspection(cached)
	end
	local evidence = {
		status = "unavailable",
		scope = "current-merchant-window",
		sourceRevision = 0,
		missing = Unavailable(products),
		assumptions = {},
	}
	inspected[key] = evidence
	return CopyInspection(evidence)
end

---@cast Owner SkillUpSupplySourceOwner
ns.SupplySources = Owner
