---@type string, SkillUpNamespace
local _, ns = ...
if ns.broken then
	return
end

-- Session-only source ownership. Quotes establish offer contents only.
-- Every future law is an explicit, dated assumption scoped to an exact offer.
local Owner = {}
---@type table<string, SkillUpDeclaredSource>
local declared = {}
local revision = 0
local function Notify()
	ns.Changed("sourceEvidence")
end
local FIELDS = { "access", "price", "stock", "vendor", "ceiling", "initialVisit", "refillVisit" }
local function Integer(value, minimum)
	return type(value) == "number" and value >= minimum and value <= 2 ^ 52 - 1 and value % 1 == 0
end
local function Text(value)
	return type(value) == "string" and value ~= ""
end
local function Identity(offer)
	return tostring(offer.session) .. ":" .. tostring(offer.index)
end
local function Current(offer)
	local window = ns.MerchantOffers.current
	return window and window.session == offer.session and window.offers[offer.index] == offer
end
local function Provenance(law)
	return type(law) == "table" and Text(law.provenance) and Text(law.scope)
end
local function Missing(code, offerID, field)
	return { code = code, offerID = offerID, field = field }
end

---@param options SkillUpPolicyOptions
---@return SkillUpPolicyOptions
local function CopyOptions(options)
	return {
		probabilityTolerance = options.probabilityTolerance,
		costTolerance = options.costTolerance,
		visitTolerance = options.visitTolerance,
		workLimit = options.workLimit,
		stateLimit = options.stateLimit,
		coordinateLimit = options.coordinateLimit,
	}
end

---@param offer SkillUpObservedMerchantOffer
---@param version integer Strictly increasing for this session/slot, including reconciliation.
---@param laws SkillUpSourceLaws
---@return boolean
---@return SkillUpSourceUnavailable[]?
function Owner.Declare(offer, version, laws)
	if type(offer) ~= "table" or not Current(offer) then
		return false, { Missing("observation-replaced") }
	end
	local id = Identity(offer)
	if not Integer(version, 1) or (declared[id] and version <= declared[id].revision) then
		return false, { Missing("newer-law-revision-required", id) }
	end
	local quote = ns.MerchantOffers.Quote(offer, 1)
	if
		not quote
		or not Integer(offer.itemID, 1)
		or not Integer(offer.observedAt, 0)
		or not Integer(offer.session, 1)
		or not Integer(offer.index, 1)
		or not Text(offer.sourceRevision)
	then
		return false, { Missing("complete-dated-quote-required", id) }
	end
	if type(laws) ~= "table" then
		return false, { Missing("missing-law", id) }
	end
	local stock = type(laws.stock) == "table" and laws.stock.value
	local valid = {
		access = type(laws.access) == "table" and type(laws.access.value) == "boolean",
		price = type(laws.price) == "table" and laws.price.value == "fixed",
		vendor = type(laws.vendor) == "table" and Text(laws.vendor.value),
		ceiling = type(laws.ceiling) == "table" and Integer(laws.ceiling.value, 1),
		stock = type(stock) == "table"
			and Text(stock.key)
			and Integer(stock.perBundle, 1)
			and (
				(stock.law == "finite-no-restock" and Integer(stock.available, 0))
				or (stock.law == "unlimited" and stock.available == "unlimited")
			),
	}
	for _, field in ipairs({ "initialVisit", "refillVisit" }) do
		local value = type(laws[field]) == "table" and laws[field].value
		valid[field] = type(value) == "number" and value >= 0 and value < math.huge
	end
	local missing, evidence = {}, {}
	local function Evidence(field, law)
		if not Provenance(law) then
			missing[#missing + 1] = Missing("law-provenance-and-scope-required", id, field)
		else
			evidence[#evidence + 1] = {
				offerID = id,
				field = field,
				revision = version,
				provenance = law.provenance,
				scope = law.scope,
				observedAt = offer.observedAt,
				observationRevision = offer.sourceRevision,
				session = offer.session,
				index = offer.index,
			}
		end
	end
	for _, field in ipairs(FIELDS) do
		if not valid[field] then
			missing[#missing + 1] = Missing("missing-law", id, field)
		end
		Evidence(field, laws[field])
	end
	local values = {}
	for key in pairs(quote.costs) do
		local law = type(laws.tokenValues) == "table" and laws.tokenValues[key]
		local value = type(law) == "table" and law.value
		if type(value) ~= "number" or not (value >= 0 and value < math.huge) then
			missing[#missing + 1] = Missing("missing-token-value", id, key)
		end
		Evidence(key, law)
		values[key] = value
	end
	if #missing > 0 then
		return false, missing
	end
	declared[id] = {
		offer = offer,
		revision = version,
		evidence = evidence,
		valid = true,
		quote = quote,
		tokenValues = values,
		stock = { key = stock.key, perBundle = stock.perBundle, available = stock.available, law = stock.law },
		access = laws.access.value,
		vendor = laws.vendor.value,
		ceiling = laws.ceiling.value,
		initialVisit = laws.initialVisit.value,
		refillVisit = laws.refillVisit.value,
	}
	revision = revision + 1
	Notify()
	return true
end

---@param options SkillUpPolicyOptions
---@param refillOrders SkillUpSourceRefillOrder[]
---@param products table<integer, true> Explicit product universe; all current competing offers are required.
---@return SkillUpResupplyInput?
---@return SkillUpSourceUnavailable[]
function Owner.Read(options, refillOrders, products)
	if type(products) ~= "table" or next(products) == nil then
		return nil, { Missing("explicit-product-universe-required") }
	end
	local window = ns.MerchantOffers.current
	if not window then
		return nil, { Missing("merchant-window-unavailable") }
	end
	if #window.offers == 0 then
		return nil, { Missing("merchant-offers-unavailable") }
	end
	local copiedOptions = CopyOptions(options)
	---@type SkillUpResupplyInput
	local input = {
		service = "fixed-batch",
		journey = "independent-round-trips",
		route = { legs = {}, held = {}, buy = {} },
		walletCopper = 0,
		currencies = {},
		sources = {},
		stock = {},
		tokenValues = {},
		initialOrders = {},
		refillOrders = {},
		initialVisitCosts = {},
		refillVisitCosts = {},
		options = copiedOptions,
		sourceRevision = revision,
		assumptions = {},
	}

	local missing, sourceIndices, observedProducts = {}, {}, {}
	for _, offer in ipairs(window.offers) do
		if products[offer.itemID] then
			observedProducts[offer.itemID] = true
			local id = Identity(offer)
			local record = declared[id]
			if not record then
				for _, field in ipairs(FIELDS) do
					missing[#missing + 1] = Missing("missing-law", id, field)
				end
			elseif record.offer ~= offer then
				missing[#missing + 1] = Missing("observation-replaced", id)
			elseif not record.valid then
				missing[#missing + 1] = Missing("reconciliation-required", id, "stock")
			else
				local stock, vendor = record.stock, record.vendor
				if
					(input.stock[stock.key] ~= nil and input.stock[stock.key] ~= stock.available)
					or (input.initialVisitCosts[vendor] ~= nil and input.initialVisitCosts[vendor] ~= record.initialVisit)
					or (input.refillVisitCosts[vendor] ~= nil and input.refillVisitCosts[vendor] ~= record.refillVisit)
				then
					missing[#missing + 1] = Missing("inconsistent-shared-source-law", id)
				end
				input.stock[stock.key] = stock.available
				input.initialVisitCosts[vendor], input.refillVisitCosts[vendor] =
					record.initialVisit, record.refillVisit
				local costs = {}
				for key, quantity in pairs(record.quote.costs) do
					costs[key] = quantity
					if input.tokenValues[key] ~= nil and input.tokenValues[key] ~= record.tokenValues[key] then
						missing[#missing + 1] = Missing("inconsistent-token-value", id, key)
					end
					input.tokenValues[key] = record.tokenValues[key]
				end
				sourceIndices[id] = #input.sources + 1
				input.sources[#input.sources + 1] = {
					offerID = id,
					npcID = offer.npcID,
					itemID = offer.itemID,
					bundleUnits = record.quote.units,
					moneyCopper = record.quote.moneyCopper,
					costs = costs,
					maxBundles = record.ceiling,
					vendor = vendor,
					access = record.access,
					priceLaw = "fixed",
					stockKey = stock.key,
					stockPerBundle = stock.perBundle,
				}
				for _, evidence in ipairs(record.evidence) do
					input.assumptions[#input.assumptions + 1] = {
						offerID = evidence.offerID,
						field = evidence.field,
						revision = evidence.revision,
						provenance = evidence.provenance,
						scope = evidence.scope,
						observedAt = evidence.observedAt,
						observationRevision = evidence.observationRevision,
						session = evidence.session,
						index = evidence.index,
					}
				end
			end
		end
	end
	for itemID in pairs(products) do
		if not observedProducts[itemID] then
			missing[#missing + 1] = Missing("product-offers-unavailable", nil, tostring(itemID))
		end
	end
	for _, order in ipairs(refillOrders) do
		local source = sourceIndices[order.offerID]
		if not source then
			missing[#missing + 1] = Missing("selected-refill-offer-unavailable", order.offerID)
		else
			input.refillOrders[#input.refillOrders + 1] = { source = source, bundles = order.bundles }
		end
	end
	if #missing > 0 then
		return nil, missing
	end
	return input, missing
end

---@param record table
---@return table
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

-- The API asks for evidence on every rebuild. The assembly is owned by this file for one revision, window and
-- product universe, and each ask still receives its own records: a caller can change what it was given. A new
-- declaration or merchant session drops every assembled record; a new product universe gets its own.
---@type table<string, SkillUpSourceEvidence>
local inspected = {}
local inspectedRevision, inspectedSession
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
	if inspectedRevision ~= revision or inspectedSession ~= session then
		inspected, inspectedRevision, inspectedSession = {}, revision, session
	end
	local key = EvidenceKey(window, products)
	local cached = inspected[key]
	if cached then
		return CopyInspection(cached)
	end
	-- This contract is discarded after evidence collection. Zero solver budgets
	-- make it unusable for optimization even if this path is accidentally reused.
	local input, missing = Owner.Read({
		probabilityTolerance = 0,
		costTolerance = 0,
		visitTolerance = 0,
		workLimit = 0,
		stateLimit = 0,
		coordinateLimit = 0,
	}, {}, products)
	local evidence = {
		status = input and "conditional" or "unavailable",
		scope = "current-merchant-window",
		sourceRevision = revision,
		missing = missing,
		assumptions = input and input.assumptions or {},
	}
	inspected[key] = evidence
	return CopyInspection(evidence)
end

---@param skillLine integer
---@param alpha number No default.
---@param options SkillUpPolicyOptions
---@param refillOrders SkillUpSourceRefillOrder[]
---@param products table<integer, true> Explicit product universe; all current competing offers are required.
---@return boolean
---@return string?
function Owner.Configure(skillLine, alpha, options, refillOrders, products)
	if type(options) ~= "table" or type(refillOrders) ~= "table" or type(products) ~= "table" then
		return false, "explicit source policy inputs required"
	end
	local frozenOptions = CopyOptions(options)
	local frozenOrders, frozenProducts = {}, {}
	for _, value in pairs(options) do
		if type(value) ~= "number" then
			return false, "plain numeric policy options required"
		end
	end
	for _, order in ipairs(refillOrders) do
		frozenOrders[#frozenOrders + 1] = { offerID = order.offerID, bundles = order.bundles }
	end
	for itemID, included in pairs(products) do
		if not Integer(itemID, 1) or included ~= true then
			return false, "explicit product identity set required"
		end
		frozenProducts[itemID] = true
	end
	return ns.RouteDemand.ConfigureSupply(skillLine, function()
		local input, missing = Owner.Read(frozenOptions, frozenOrders, frozenProducts)
		return input, missing[1] and missing[1].code
	end, alpha)
end

-- A resource revision does not identify which shared pool was purchased from.
-- Require an explicitly reconciled newer declaration rather than restoring any
-- finite balance. Unchanged unlimited laws still bind the exact observation.
local function Reconcile()
	local changed = false
	for _, record in pairs(declared) do
		if record.valid and record.stock.law == "finite-no-restock" then
			record.valid = false
			changed = true
		end
	end
	if changed then
		revision = revision + 1
		Notify()
	end
end
ns.WhenStaleObserver("bags", Reconcile)
for _, event in ipairs({
	"PLAYER_MONEY",
	"CURRENCY_DISPLAY_UPDATE",
	"PLAYERBANKSLOTS_CHANGED",
	"BANKFRAME_OPENED",
	"BANKFRAME_CLOSED",
}) do
	ns.WhenEvent(event, Reconcile)
end
---@cast Owner SkillUpSupplySourceOwner
ns.SupplySources = Owner
