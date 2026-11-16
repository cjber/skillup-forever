---@type string, SkillUpNamespace
local _, ns = ...
if ns.broken then
	return
end

-- Session-only source ownership. Quotes establish transaction contents only.
-- Every future law is an explicit, dated assumption scoped to an exact offer.
local Owner = {}
---@type table<string, SkillUpDeclaredSource>
local declared = {}
---@type table<string, SkillUpAdaptiveDeclaredSource>
local adaptive = {}
local revision = 0
local transaction
local function Notify()
	if transaction then
		transaction.changed = true
	else
		ns.Changed("sourceEvidence")
	end
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
	for _, record in pairs(adaptive) do
		if record.valid then
			record.valid, changed = false, true
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
-- Adaptive declarations stay separate from the compatible fixed-refill laws.
---@type SkillUpAdaptiveEconomics?
local economics
-- Weak keys retain only configurations still owned by RouteDemand.
local adaptiveReaders = setmetatable({}, { __mode = "k" })
local ADAPTIVE_FIELDS = { "access", "price", "vendor", "ceiling", "stock", "initialDelivery", "futureDelivery" }
local ECONOMIC_MAPS =
	{ "initialVisitMoney", "refillVisitMoney", "initialVisitValue", "refillVisitValue", "tokenValues", "terminalCarry" }
local function Value(value)
	return type(value) == "number" and value >= 0 and value < math.huge
end
-- Canonical solver coordinate grammar, not an item-name/content heuristic.
local function Typed(key)
	if type(key) ~= "string" then
		return false
	end
	local kind, id = key:match("^(%a+):(%d+)$")
	local number = tonumber(id)
	return (kind == "item" or kind == "currency")
		and Integer(number, 1)
		and key == kind .. ":" .. string.format("%.0f", number)
end
---@param offer SkillUpObservedMerchantOffer?
---@param version integer
---@param field string
---@param law SkillUpSourceLaw
---@return SkillUpSourceAssumption
local function Evidence(offer, version, field, law)
	return {
		offerID = offer and Identity(offer) or "economics",
		field = field,
		revision = version,
		provenance = law.provenance,
		scope = law.scope,
		observedAt = offer and offer.observedAt or GetServerTime(),
		observationRevision = offer and offer.sourceRevision or "explicit-economics",
		session = offer and offer.session or 0,
		index = offer and offer.index or 0,
		clientBuild = offer and type(offer.build) == "string" and offer.build or nil,
		projectID = offer and Integer(offer.projectID, 1) and offer.projectID or nil,
	}
end

---@param offer SkillUpObservedMerchantOffer
---@param version integer
---@param laws SkillUpAdaptiveSourceLaws
---@return boolean, SkillUpSourceUnavailable[]?
function Owner.DeclareAdaptive(offer, version, laws)
	if type(offer) ~= "table" or not Current(offer) then
		return false, { Missing("observation-replaced") }
	end
	local id = Identity(offer)
	if not Integer(version, 1) or (adaptive[id] and version <= adaptive[id].revision) then
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
	laws = type(laws) == "table" and laws or {}
	local missing, evidence = {}, {}
	for _, field in ipairs(ADAPTIVE_FIELDS) do
		if not Provenance(laws[field]) then
			missing[#missing + 1] = Missing("law-provenance-and-scope-required", id, field)
		else
			evidence[#evidence + 1] = Evidence(offer, version, field, laws[field])
		end
	end
	if #missing > 0 then
		return false, missing
	end
	local stock, delivery = laws.stock.value, laws.futureDelivery.value
	local valid = {
		access = type(laws.access.value) == "boolean",
		price = laws.price.value == "fixed",
		vendor = Text(laws.vendor.value),
		ceiling = Integer(laws.ceiling.value, 1),
		initialDelivery = laws.initialDelivery.value == "certain",
		futureDelivery = type(delivery) == "table" and Value(delivery.chance) and delivery.chance <= 1 and type(
			delivery.payOnFailure
		) == "boolean",
		stock = type(stock) == "table"
			and Text(stock.key)
			and Text(stock.unit)
			and Integer(stock.available, 0)
			and Integer(stock.perBundle, 1)
			and stock.law == "finite-no-restock"
			and (stock.restriction == nil or Text(stock.restriction)),
	}
	for _, field in ipairs(ADAPTIVE_FIELDS) do
		if not valid[field] then
			missing[#missing + 1] = Missing("missing-law", id, field)
		end
	end
	if #missing > 0 then
		return false, missing
	end
	local function Conflict(code, field)
		missing[#missing + 1] = Missing(code, id, field)
	end
	if type(offer.isPurchasable) ~= "boolean" then
		Conflict("purchase-eligibility-unavailable", "access")
	elseif laws.access.value and not offer.isPurchasable then
		Conflict("native-access-conflict", "access")
	end
	if not Integer(offer.maxPurchaseItems, 0) then
		Conflict("native-ceiling-unavailable", "ceiling")
	elseif laws.ceiling.value > math.floor(offer.maxPurchaseItems / quote.units) then
		Conflict("native-ceiling-conflict", "ceiling")
	end
	-- This conversion is an explicit scoped law, not a native stock inference.
	if
		stock.observedUnits ~= "items"
		and stock.observedUnits ~= "bundles"
		and stock.observedUnits ~= "finite-domain-restriction"
	then
		Conflict("stock-unit-law-missing", "stock")
	elseif not Integer(offer.numAvailable, -1) then
		Conflict("native-stock-unavailable", "stock")
	elseif offer.numAvailable == 0 and stock.available > 0 then
		Conflict("native-stock-conflict", "stock")
	elseif stock.observedUnits ~= "finite-domain-restriction" then
		local bundles = stock.available / stock.perBundle
		local observed = stock.observedUnits == "items" and bundles * quote.units or bundles
		if offer.numAvailable < 0 or bundles % 1 ~= 0 or observed ~= offer.numAvailable then
			Conflict("native-stock-unit-conflict", "stock")
		end
	elseif offer.numAvailable ~= -1 then
		Conflict("stock-unit-law-missing", "stock")
	elseif not Text(stock.restriction) then
		Conflict("finite-domain-scope-required", "stock")
	end
	if #missing > 0 then
		return false, missing
	end
	for _, entry in ipairs(evidence) do
		if entry.field == "stock" then
			entry.poolUnit, entry.observedUnits, entry.restriction = stock.unit, stock.observedUnits, stock.restriction
		end
	end
	adaptive[id] = {
		offer = offer,
		revision = version,
		evidence = evidence,
		valid = true,
		quote = quote,
		stock = {
			key = stock.key,
			unit = stock.unit,
			perBundle = stock.perBundle,
			available = stock.available,
			observedUnits = stock.observedUnits,
			restriction = stock.restriction,
		},
		access = laws.access.value,
		vendor = laws.vendor.value,
		ceiling = laws.ceiling.value,
		delivery = { chance = delivery.chance, payOnFailure = delivery.payOnFailure },
	}
	revision = revision + 1
	Notify()
	return true
end

---@param version integer
---@param laws SkillUpAdaptiveEconomicLaws
---@return boolean, SkillUpSourceUnavailable[]?
function Owner.DeclareEconomics(version, laws)
	local window = ns.MerchantOffers.current
	if not window then
		return false, { Missing("merchant-window-unavailable") }
	end
	if not Integer(version, 1) or (economics and version <= economics.revision) then
		return false, { Missing("newer-economic-revision-required") }
	end
	if type(laws) ~= "table" then
		return false, { Missing("economic-laws-required") }
	end
	---@type SkillUpAdaptiveEconomicMaps
	local maps = {
		initialVisitMoney = {},
		refillVisitMoney = {},
		initialVisitValue = {},
		refillVisitValue = {},
		tokenValues = {},
		terminalCarry = {},
	}
	---@type SkillUpSourceAssumption[]
	local evidence = {}
	local missing = {}
	for _, field in ipairs(ECONOMIC_MAPS) do
		local law = laws[field]
		if not Provenance(law) or type(law.value) ~= "table" or getmetatable(law.value) ~= nil then
			missing[#missing + 1] = Missing("economic-map-required", nil, field)
		else
			maps[field] = {}
			for key, value in pairs(law.value) do
				local typed = field == "tokenValues" or field == "terminalCarry"
				local money = field == "initialVisitMoney" or field == "refillVisitMoney"
				if
					not (typed and Typed(key) or not typed and Text(key))
					or not Value(value)
					or (money and not Integer(value, 0))
				then
					missing[#missing + 1] = Missing("invalid-economic-coordinate", nil, field)
				else
					maps[field][key] = value
				end
			end
			evidence[#evidence + 1] = Evidence(nil, version, field, law)
		end
	end
	if not Provenance(laws.failureLoss) or not Value(laws.failureLoss.value) then
		missing[#missing + 1] = Missing("failure-loss-required", nil, "failureLoss")
	else
		evidence[#evidence + 1] = Evidence(nil, version, "failureLoss", laws.failureLoss)
	end
	if #missing > 0 then
		return false, missing
	end
	economics = {
		revision = version,
		session = window.session,
		evidence = evidence,
		failureLoss = laws.failureLoss.value,
		initialVisitMoney = maps.initialVisitMoney,
		refillVisitMoney = maps.refillVisitMoney,
		initialVisitValue = maps.initialVisitValue,
		refillVisitValue = maps.refillVisitValue,
		tokenValues = maps.tokenValues,
		terminalCarry = maps.terminalCarry,
	}
	revision = revision + 1
	Notify()
	return true
end

-- Returned records are owned by the caller. Reader assembly has an explicit
-- operation bound; RouteDemand still owns budgeted deep copying and native reads.
---@param options SkillUpAdaptiveSourceOptions
---@param products table<integer, true>
---@param crafted SkillUpCraftedSourceToken?
---@return SkillUpAdaptiveSupplyRequest?, SkillUpSourceUnavailable[]
function Owner.ReadAdaptive(options, products, crafted)
	if
		crafted ~= nil
		and (
			type(crafted) ~= "table"
			or crafted.version ~= "crafted-adapter-v1"
			or not Integer(crafted.revision, 1)
			or not Integer(crafted.skillLine, 1)
		)
	then
		return nil, { Missing("explicit-crafted-token-required") }
	end
	if type(products) ~= "table" or next(products) == nil then
		return nil, { Missing("explicit-product-universe-required") }
	end
	local window = ns.MerchantOffers.current
	if not window then
		return nil, { Missing("merchant-window-unavailable") }
	end
	if type(options) ~= "table" or not Integer(options.workLimit, 1) then
		return nil, { Missing("explicit-reader-work-budget-required") }
	end
	local currentEconomics = economics and economics.session == window.session and economics or nil
	local work, missing = 0, {}
	local function Tick()
		work = work + 1
		return work <= options.workLimit
	end
	---@type SkillUpAdaptiveEconomicMaps
	local maps = {
		initialVisitMoney = {},
		refillVisitMoney = {},
		initialVisitValue = {},
		refillVisitValue = {},
		tokenValues = {},
		terminalCarry = {},
	}
	---@type SkillUpSourceAssumption[]
	local assumptions = {}
	---@type SkillUpFiniteSource[]
	local sources = {}
	local policy = {
		sources = sources,
		stock = {},
		assumptions = assumptions,
	}
	for _, field in ipairs({ "workLimit", "stateLimit", "coordinateLimit", "limbLimit" }) do
		if not Integer(options[field], 1) then
			missing[#missing + 1] = Missing("explicit-solver-budget-required", nil, field)
		end
	end
	---@param records SkillUpSourceAssumption[]
	local function CopyEvidence(records)
		for _, entry in ipairs(records) do
			---@type SkillUpSourceAssumption
			local copy = {
				observedAt = entry.observedAt,
				observationRevision = entry.observationRevision,
				session = entry.session,
				index = entry.index,
				offerID = entry.offerID,
				field = entry.field,
				revision = entry.revision,
				provenance = entry.provenance,
				scope = entry.scope,
			}
			for key, value in pairs(entry) do
				if not Tick() then
					return false
				end
				copy[key] = value
			end
			policy.assumptions[#policy.assumptions + 1] = copy
		end
		return true
	end
	if not currentEconomics then
		for _, field in ipairs(ECONOMIC_MAPS) do
			missing[#missing + 1] = Missing("economic-map-required", nil, field)
		end
		missing[#missing + 1] = Missing("failure-loss-required", nil, "failureLoss")
	else
		for _, field in ipairs(ECONOMIC_MAPS) do
			maps[field] = {}
			for key, value in pairs(currentEconomics[field]) do
				if not Tick() then
					return nil, { Missing("reader-work-budget-exhausted") }
				end
				maps[field][key] = value
			end
		end
		if not CopyEvidence(currentEconomics.evidence) then
			return nil, { Missing("reader-work-budget-exhausted") }
		end
	end
	local seen, pools = {}, {}
	for _, offer in ipairs(window.offers) do
		if not Tick() then
			return nil, { Missing("reader-work-budget-exhausted") }
		end
		if products[offer.itemID] then
			seen[offer.itemID] = true
			local id = Identity(offer)
			local record = adaptive[id]
			if not record then
				missing[#missing + 1] = Missing("stock-unit-law-missing", id, "stock")
				if not ns.MerchantOffers.Quote(offer, 1) then
					missing[#missing + 1] = Missing("complete-dated-quote-required", id)
				end
				if type(offer.isPurchasable) ~= "boolean" then
					missing[#missing + 1] = Missing("purchase-eligibility-unavailable", id, "access")
				end
				if not Integer(offer.maxPurchaseItems, 0) then
					missing[#missing + 1] = Missing("native-ceiling-unavailable", id, "ceiling")
				end
				for _, field in ipairs(ADAPTIVE_FIELDS) do
					missing[#missing + 1] = Missing("missing-law", id, field)
				end
			elseif record.offer ~= offer then
				missing[#missing + 1] = Missing("observation-replaced", id)
			elseif not record.valid then
				missing[#missing + 1] = Missing("reconciliation-required", id, "stock")
			else
				local stock = record.stock
				local prior = pools[stock.key]
				if
					prior
					and (
						prior.available ~= stock.available
						or prior.unit ~= stock.unit
						or prior.observedUnits ~= stock.observedUnits
						or prior.restriction ~= stock.restriction
					)
				then
					missing[#missing + 1] = Missing("inconsistent-shared-pool-law", id, "stock")
				end
				pools[stock.key], policy.stock[stock.key] = stock, stock.available
				local costs = {}
				for key, quantity in pairs(record.quote.costs) do
					if not Tick() then
						return nil, { Missing("reader-work-budget-exhausted") }
					end
					costs[key] = quantity
					if currentEconomics and currentEconomics.tokenValues[key] == nil then
						missing[#missing + 1] = Missing("missing-token-value", id, key)
					end
				end
				if currentEconomics then
					for _, field in ipairs({
						"initialVisitMoney",
						"refillVisitMoney",
						"initialVisitValue",
						"refillVisitValue",
					}) do
						if currentEconomics[field][record.vendor] == nil then
							missing[#missing + 1] = Missing("missing-vendor-economic-law", id, field)
						end
					end
				end
				policy.sources[#policy.sources + 1] = {
					offerID = id,
					npcID = offer.npcID,
					itemID = offer.itemID,
					bundleUnits = record.quote.units,
					moneyCopper = record.quote.moneyCopper,
					costs = costs,
					maxBundles = record.ceiling,
					stockKey = stock.key,
					stockPerBundle = stock.perBundle,
					vendor = record.vendor,
					access = record.access,
					priceLaw = "fixed",
					futureDelivery = { chance = record.delivery.chance, payOnFailure = record.delivery.payOnFailure },
				}
				if not CopyEvidence(record.evidence) then
					return nil, { Missing("reader-work-budget-exhausted") }
				end
			end
		end
	end
	for itemID, included in pairs(products) do
		if not Tick() then
			return nil, { Missing("reader-work-budget-exhausted") }
		end
		if not Integer(itemID, 1) or included ~= true then
			missing[#missing + 1] = Missing("explicit-product-identity-required")
		elseif not seen[itemID] then
			missing[#missing + 1] = Missing("product-offers-unavailable", nil, tostring(itemID))
		end
	end
	if currentEconomics then
		local function Carry(key)
			if currentEconomics.terminalCarry[key] == nil then
				missing[#missing + 1] = Missing("missing-terminal-carry", nil, key)
			end
		end
		for _, source in ipairs(policy.sources) do
			Carry("item:" .. source.itemID)
			for key in pairs(source.costs) do
				Carry(key)
			end
		end
		for key in pairs(currentEconomics.tokenValues) do
			Carry(key)
		end
	end
	if #missing > 0 or not currentEconomics then
		return nil, missing
	end
	local token = crafted and { version = crafted.version, revision = crafted.revision, skillLine = crafted.skillLine }
	return {
		inventoryScope = "bags-only",
		crafted = token,
		policy = {
			service = "adaptive-finite",
			journey = "independent-round-trips",
			delivery = "independent-bundle-outcomes",
			objective = "expected-expenditure-plus-terminal-carry-plus-failure-loss",
			route = { legs = {}, held = {}, buy = {} },
			walletCopper = 0,
			currencies = {},
			sources = policy.sources,
			stock = policy.stock,
			initialOrders = {},
			assumptions = policy.assumptions,
			sourceRevision = revision,
			options = {
				workLimit = options.workLimit,
				stateLimit = options.stateLimit,
				coordinateLimit = options.coordinateLimit,
				limbLimit = options.limbLimit,
			},
			failureLoss = currentEconomics.failureLoss,
			initialVisitMoney = maps.initialVisitMoney,
			refillVisitMoney = maps.refillVisitMoney,
			initialVisitValue = maps.initialVisitValue,
			refillVisitValue = maps.refillVisitValue,
			tokenValues = maps.tokenValues,
			terminalCarry = maps.terminalCarry,
		},
	},
		missing
end

---@param products table<integer, true>
---@param workLimit integer
---@return SkillUpSourceEvidence
function Owner.InspectAdaptive(products, workLimit)
	-- No alpha, native balance reads, reader registration or solver invocation.
	local request, missing =
		Owner.ReadAdaptive({ workLimit = workLimit, stateLimit = 1, coordinateLimit = 1, limbLimit = 1 }, products)
	return {
		status = request and "conditional" or "unavailable",
		scope = "current-merchant-window",
		sourceRevision = revision,
		missing = missing,
		assumptions = request and request.policy.assumptions or {},
	}
end

---@param skillLine integer
---@param alpha number
---@param options SkillUpAdaptiveSourceOptions
---@param products table<integer, true>
---@param crafted SkillUpCraftedSourceToken?
---@return boolean, string?
function Owner.ConfigureAdaptive(skillLine, alpha, options, products, crafted)
	if type(options) ~= "table" or type(products) ~= "table" then
		return false, "explicit adaptive source inputs required"
	end
	if type(alpha) ~= "number" or not (alpha >= 0 and alpha <= 1) then
		return false, "explicit starting coverage in [0,1] required"
	end
	if
		crafted ~= nil
		and (
			type(crafted) ~= "table"
			or crafted.version ~= "crafted-adapter-v1"
			or not Integer(crafted.revision, 1)
			or not Integer(crafted.skillLine, 1)
		)
	then
		return false, "explicit crafted token required"
	end
	local frozenProducts = {}
	for _, field in ipairs({ "workLimit", "stateLimit", "coordinateLimit", "limbLimit" }) do
		if not Integer(options[field], 1) then
			return false, "explicit positive solver budgets required"
		end
	end
	---@type SkillUpAdaptiveSourceOptions
	local frozenOptions = {
		workLimit = options.workLimit,
		stateLimit = options.stateLimit,
		coordinateLimit = options.coordinateLimit,
		limbLimit = options.limbLimit,
	}
	for itemID, included in pairs(products) do
		if not Integer(itemID, 1) or included ~= true then
			return false, "explicit product identity set required"
		end
		frozenProducts[itemID] = true
	end
	if next(frozenProducts) == nil then
		return false, "explicit product universe required"
	end
	local token = crafted and { version = crafted.version, revision = crafted.revision, skillLine = crafted.skillLine }
	local cell = { options = frozenOptions, products = frozenProducts, crafted = token }
	cell.request, cell.missing = Owner.ReadAdaptive(frozenOptions, frozenProducts, token)
	local ok, reason = ns.RouteDemand.ConfigureAdaptiveSupply(skillLine, function()
		-- Producer revisions assemble owned requests outside reader dispatch. The
		-- existing shared frame only receives a prepared immutable request here.
		return cell.request, cell.missing[1] and cell.missing[1].code
	end, alpha)
	if ok then
		adaptiveReaders[cell] = true
	end
	return ok, reason
end

ns.WhenStaleObserver("sourceEvidence", function()
	for cell in pairs(adaptiveReaders) do
		cell.request, cell.missing = Owner.ReadAdaptive(cell.options, cell.products, cell.crafted)
	end
end)

-- Run a group of declarations and configuration as one producer transaction.
-- Public declaration validators remain canonical; failed later records cannot
-- leave an earlier law or revision visible.
---@param owned SkillUpSupplyDraft
---@return boolean, table[]?
function Owner._ApplyDraft(owned)
	if transaction then
		return false, { Missing("nested-source-transaction") }
	end
	local oldDeclared, oldAdaptive = {}, {}
	for key, value in pairs(declared) do
		oldDeclared[key] = value
	end
	for key, value in pairs(adaptive) do
		oldAdaptive[key] = value
	end
	local oldEconomics, oldRevision = economics, revision
	local pending = { changed = false }
	transaction = pending
	local ok, result, detail = pcall(function()
		if owned.economics then
			local accepted, missing = Owner.DeclareEconomics(owned.economics.version, owned.economics.laws)
			if not accepted then
				return false, missing
			end
		end
		for _, declaration in ipairs(owned.offers or {}) do
			local accepted, missing = Owner.Declare(declaration.offer, declaration.version, declaration.laws)
			if not accepted then
				return false, missing
			end
		end
		for _, declaration in ipairs(owned.adaptiveOffers or {}) do
			local accepted, missing = Owner.DeclareAdaptive(declaration.offer, declaration.version, declaration.laws)
			if not accepted then
				return false, missing
			end
		end
		if owned.fixed then
			local input, missing = Owner.Read(owned.fixed.options, owned.fixed.refillOrders, owned.products)
			if not input then
				return false, missing
			end
			return Owner.Configure(
				owned.skillLine,
				owned.alpha,
				owned.fixed.options,
				owned.fixed.refillOrders,
				owned.products
			)
		elseif owned.adaptive then
			local input, missing = Owner.ReadAdaptive(owned.adaptive.options, owned.products, owned.adaptive.crafted)
			if not input then
				return false, missing
			end
			return Owner.ConfigureAdaptive(
				owned.skillLine,
				owned.alpha,
				owned.adaptive.options,
				owned.products,
				owned.adaptive.crafted
			)
		end
		return false, { Missing("policy-section-required") }
	end)
	transaction = nil
	if not ok or result == false then
		declared, adaptive, economics, revision = oldDeclared, oldAdaptive, oldEconomics, oldRevision
		if not ok then
			return false, { Missing("source-transaction-failed") }
		end
		if type(detail) == "string" then
			return false, { Missing(detail) }
		end
		return false, detail or result
	end
	if pending.changed then
		ns.Changed("sourceEvidence")
	end
	return true
end

---@cast Owner SkillUpSupplySourceOwner
ns.SupplySources = Owner
