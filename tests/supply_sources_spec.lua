-- Source-owner checks use plain records only, with no client or runtime startup.
local ns = {
	Readable = function(value)
		return value
	end,
}
local environment = setmetatable({
	GetServerTime = function()
		return 42
	end,
}, { __index = _G })
local function Load(path)
	return setfenv(assert(loadfile(path)), environment)
end
local observers = {}
ns.WhenStaleObserver = function(kind, callback)
	observers[kind] = callback
end
ns.WhenEvent = function(kind, callback)
	observers[kind] = callback
end
local changes = 0
ns.Changed = function(kind)
	assert(kind == "sourceEvidence")
	changes = changes + 1
end
ns.RouteDemand = {
	ConfigureSupply = function(_, read, alpha)
		assert(alpha == 0.7)
		if ns.failConfiguration then
			return false, "configuration-rejected"
		end
		ns.reader = read
		return true
	end,
	ConfigureAdaptiveSupply = function(_, read)
		ns.adaptiveReader = read
		return true
	end,
}
Load("Integrations/MerchantOffers.lua")("SkillUpForever", ns)
Load("Core/SupplySources.lua")("SkillUpForever", ns)
local checks = 0
local function Check(value, message)
	checks = checks + 1
	assert(value, message)
end
local callOK, configured = pcall(ns.SupplySources.Configure, 197, 0.5, nil, {}, {})
Check(callOK and configured == false, "missing fixed provider inputs are refused")
callOK, configured = pcall(ns.SupplySources.ConfigureAdaptive, 197, 0.5, nil, {})
Check(callOK and configured == false, "missing adaptive provider inputs are refused")
local offer = {
	session = 1,
	index = 1,
	itemID = 10,
	npcID = 123,
	observedAt = 42,
	sourceRevision = "synthetic",
	requirementsComplete = true,
	price = 3,
	stackCount = 2,
	costs = { { kind = "item", id = 20, quantity = 1 } },
}
ns.MerchantOffers.current = { session = 1, offers = { offer } }
local contract, missing = ns.SupplySources.Read({}, {}, { [10] = true })
Check(contract == nil and missing[1].code == "missing-law", "default owner must report missing laws")
local inspection = ns.SupplySources.Inspect({ [10] = true })
Check(inspection.status == "unavailable" and inspection.missing[1].code == "missing-law", "inspection needs no alpha")
Check(inspection.scope == "current-merchant-window", "inspection does not claim every source was observed")

-- The API asks for evidence on every rebuild. One unchanged revision, window and product universe assembles it
-- once, and each caller still owns the records it was given.
local readCalls = 0
local realRead = ns.SupplySources.Read
ns.SupplySources.Read = function(...)
	readCalls = readCalls + 1
	return realRead(...)
end
local first = ns.SupplySources.Inspect({ [10] = true, [11] = true })
local second = ns.SupplySources.Inspect({ [10] = true, [11] = true })
Check(readCalls == 1, "unchanged evidence assembles once")
Check(first ~= second and first.missing ~= second.missing, "each inspection owns its tables")
first.missing[1].code = "mutated"
Check(
	ns.SupplySources.Inspect({ [10] = true, [11] = true }).missing[1].code ~= "mutated",
	"a changed inspection record never reaches the next caller"
)
ns.SupplySources.Inspect({ [11] = true })
Check(readCalls == 2, "a different product universe reassembles")
ns.SupplySources.Read = realRead
local function Law(value)
	return { value = value, provenance = "synthetic explicit assumption", scope = "this finite run" }
end
local function Laws()
	return {
		access = Law(true),
		price = Law("fixed"),
		vendor = Law("V"),
		ceiling = Law(1),
		stock = Law({ key = "S", perBundle = 1, available = 2, law = "finite-no-restock" }),
		initialVisit = Law(5),
		refillVisit = Law(7),
		tokenValues = { ["item:20"] = Law(2) },
	}
end
local laws = Laws()
laws.tokenValues["item:20"] = Law(0 / 0)
Check(not ns.SupplySources.Declare(offer, 1, laws), "NaN cannot establish a token opportunity value")
laws = Laws()
offer.sourceRevision = nil
Check(not ns.SupplySources.Declare(offer, 1, laws), "undated observation provenance cannot establish laws")
offer.sourceRevision = "synthetic"
Check(ns.SupplySources.Declare(offer, 1, laws), "explicit revisioned laws accepted")
laws.stock.value.available = 99
contract, missing = ns.SupplySources.Read({}, { { offerID = "1:1", bundles = 1 } }, { [10] = true })
Check(contract ~= nil and #missing == 0, "complete explicit laws produce conditional input")
Check(contract.stock.S == 2, "owner freezes declared finite pool")
Check(
	contract.sources[1].moneyCopper == 3 and contract.sources[1].bundleUnits == 2,
	"dated quote provides original bundle"
)
Check(contract.sources[1].costs["item:20"] == 1, "quote typed payment preserved")
Check(
	contract.sources[1].offerID == "1:1" and contract.sources[1].npcID == 123,
	"owner retains exact offer and NPC identity"
)
Check(
	contract.refillVisitCosts.V == 7 and contract.initialVisitCosts.V == 5,
	"initial and later setup costs stay distinct"
)
contract.stock.S = 99
Check(ns.SupplySources.Read({}, {}, { [10] = true }).stock.S == 2, "reader never returns its owned state")
local previousChanges = changes
observers.bags()
Check(changes == previousChanges + 1, "resource reconciliation revokes production evidence reporting")
contract, missing = ns.SupplySources.Read({}, {}, { [10] = true })
Check(
	contract == nil and missing[1].code == "reconciliation-required",
	"purchase revision cannot restore old finite stock"
)
Check(not ns.SupplySources.Declare(offer, 1, Laws()), "same revision cannot reconcile a depleted pool")
laws = Laws()
laws.stock.value.available = 1
Check(ns.SupplySources.Declare(offer, 2, laws), "new explicitly reconciled pool accepted")
Check(ns.SupplySources.Read({}, {}, { [10] = true }).stock.S == 1, "reconciled balance used without replenishing")
local replacement = {}
for key, value in pairs(offer) do
	replacement[key] = value
end
ns.MerchantOffers.current.offers[1] = replacement
contract, missing = ns.SupplySources.Read({}, {}, { [10] = true })
Check(contract == nil and missing[1].code == "observation-replaced", "equal transient index cannot inherit old laws")
laws = Laws()
laws.price.scope = nil
Check(not ns.SupplySources.Declare(replacement, 3, laws), "a law without validity scope is unavailable")
Check(ns.SupplySources.Declare(replacement, 3, Laws()), "new exact observation can receive explicit laws")
Check(
	ns.SupplySources.Configure(197, 0.7, {}, {}, { [10] = true }),
	"explicit alpha configures the default owner reader"
)
Check(ns.reader() ~= nil, "configured callback reads owned source contract")

contract = assert(ns.reader())
Check(contract.assumptions[1].observedAt == 42, "certificate retains dated observation")
Check(contract.assumptions[1].observationRevision == "synthetic", "certificate retains observed source revision")
Check(
	contract.assumptions[1].revision == 3 and contract.assumptions[1].scope == "this finite run",
	"law revision and validity scope remain separate from observation"
)
local unrelated = { session = 1, index = 2, itemID = 999 }
ns.MerchantOffers.current.offers[2] = unrelated
Check(
	ns.SupplySources.Read({}, {}, { [10] = true }) ~= nil,
	"unrelated unknown offer does not suppress explicit product universe"
)
local competing = {}
for key, value in pairs(replacement) do
	competing[key] = value
end
competing.index = 3
ns.MerchantOffers.current.offers[3] = competing
contract, missing = ns.SupplySources.Read({}, {}, { [10] = true })
Check(contract == nil and missing[1].offerID == "1:3", "unknown relevant competing offer cannot silently disappear")
laws = Laws()
laws.stock.value.available = 1
Check(ns.SupplySources.Declare(competing, 1, laws), "second explicit offer accepted")
contract, missing = ns.SupplySources.Read({}, {}, { [10] = true })
Check(
	contract == nil and missing[1].code == "inconsistent-shared-source-law",
	"same shared pool cannot have conflicting balances"
)
laws.stock.value.available = 2
Check(ns.SupplySources.Declare(competing, 2, laws), "consistent shared pool reconciliation accepted")
contract = assert(ns.SupplySources.Read({}, { { offerID = "1:3", bundles = 1 } }, { [10] = true }))
Check(contract.refillOrders[1].source == 2, "explicit refill offer maps after unrelated rows are excluded")
contract, missing = ns.SupplySources.Read({}, { { offerID = "old-window:3", bundles = 1 } }, { [10] = true })
Check(
	contract == nil and missing[#missing].code == "selected-refill-offer-unavailable",
	"old offer identity never becomes a new source index"
)
contract, missing = ns.SupplySources.Read({}, {}, { [222] = true })
Check(
	contract == nil and missing[1].code == "product-offers-unavailable",
	"unobserved product is explicitly unavailable"
)
ns.MerchantOffers.current = nil
contract, missing = ns.SupplySources.Read({}, {}, { [10] = true })
Check(
	contract == nil and missing[1].code == "merchant-window-unavailable",
	"closing window revokes current source evidence"
)
assert(loadfile("Core/SupplyDraft.lua"))("SkillUpForever", ns)
local owned, draftErrors = ns.SupplyDraft.Validate({ skillLine = 197, alpha = 0, products = {} })
Check(owned == nil and draftErrors[1].code == "starting-coverage-required", "draft rejects missing target")
local draft = {
	skillLine = 197,
	alpha = 0.7,
	products = { [10] = true },
	offers = {},
	fixed = { options = {}, refillOrders = {} },
}
owned, draftErrors = ns.SupplyDraft.Validate(draft)
Check(owned ~= nil and #draftErrors == 0, "complete draft shape is accepted")
draft.products[10] = false
Check(owned.products[10] == true, "validated draft owns an immutable copy")
ns.MerchantOffers.current = { session = 1, offers = { offer } }
local applyDraft = {
	skillLine = 197,
	alpha = 0.7,
	products = { [10] = true },
	offers = { { offer = offer, version = 4, laws = Laws() } },
	fixed = { options = {}, refillOrders = {} },
}
local applied, applyMissing = ns.SupplyDraft.Apply(applyDraft)
Check(
	applied and not applyMissing,
	"fixed draft applies through the real source owner: "
		.. tostring(applyMissing and applyMissing[1] and applyMissing[1].code)
		.. ":"
		.. tostring(applyMissing and applyMissing[1] and applyMissing[1].field)
)
applyDraft.offers[1].laws.stock.value.available = 99
Check(ns.SupplySources.Read({}, {}, { [10] = true }).stock.S == 2, "applied laws are owned separately")
ns.MerchantOffers.current.offers[1] = {}
applied, applyMissing = ns.SupplyDraft.Apply(applyDraft)
Check(not applied and applyMissing[1].code == "observation-replaced", "stale fixed draft is rejected")
ns.MerchantOffers.current.offers[1] = offer
ns.MerchantOffers.current.offers = { offer, unrelated, competing }
local beforeApplyChanges = changes
local badSecondLaws = Laws()
badSecondLaws.ceiling.value = 0
local atomicDraft = {
	skillLine = 197,
	alpha = 0.7,
	products = { [10] = true },
	offers = {
		{ offer = offer, version = 5, laws = Laws() },
		{ offer = competing, version = 6, laws = badSecondLaws },
	},
	fixed = { options = {}, refillOrders = {} },
}
applied, applyMissing = ns.SupplyDraft.Apply(atomicDraft)
Check(
	not applied
		and applyMissing[1].code == "missing-law"
		and applyMissing[1].field == "ceiling"
		and changes == beforeApplyChanges,
	"semantic rejection leaves no partial source declaration"
)
Check(ns.SupplySources.Declare(offer, 5, Laws()), "rolled-back first declaration can be retried")
local oldReader = ns.reader
ns.failConfiguration = true
local configFailureDraft = {
	skillLine = 197,
	alpha = 0.7,
	products = { [10] = true },
	offers = { { offer = offer, version = 7, laws = Laws() } },
	fixed = { options = {}, refillOrders = {} },
}
applied, applyMissing = ns.SupplyDraft.Apply(configFailureDraft)
Check(
	not applied and applyMissing[1] and applyMissing[1].code == "configuration-rejected",
	"configuration failure is reported"
)
Check(ns.reader == oldReader, "configuration failure restores the prior route reader")
Check(ns.SupplySources.Read({}, {}, { [10] = true }).stock.S == 2, "configuration failure restores declarations")
ns.failConfiguration = false
local omitted = {}
for key, value in pairs(competing) do
	omitted[key] = value
end
omitted.index = 4
ns.MerchantOffers.current.offers[4] = omitted
local incompleteApply = {
	skillLine = 197,
	alpha = 0.7,
	products = { [10] = true },
	offers = { { offer = offer, version = 9, laws = Laws() } },
	fixed = { options = {}, refillOrders = {} },
}
applied, applyMissing = ns.SupplyDraft.Apply(incompleteApply)
Check(
	not applied and applyMissing[1].code == "missing-law" and applyMissing[1].offerID == "1:4",
	"Apply rejects an undeclared relevant competing offer"
)
Check(ns.reader == oldReader, "incomplete offer universe preserves the configured reader")
ns.MerchantOffers.current.offers[4] = nil
Check(ns.SupplySources.Declare(offer, 9, Laws()), "incomplete offer universe rolls back the draft revision")
for _, declarations in ipairs({ { [2] = applyDraft.offers[1] }, { unexpected = applyDraft.offers[1] }, true }) do
	local malformed = {
		skillLine = 197,
		alpha = 0.7,
		products = { [10] = true },
		offers = declarations,
		fixed = { options = {}, refillOrders = {} },
	}
	local valid = ns.SupplyDraft.Validate(malformed)
	Check(valid == nil, "malformed declaration lists are rejected before iteration")
end
local cyclic = {
	skillLine = 197,
	alpha = 0.7,
	products = { [10] = true },
	offers = {},
	fixed = { options = {}, refillOrders = {} },
}
cyclic.loop = cyclic
owned, draftErrors = ns.SupplyDraft.Validate(cyclic)
Check(owned == nil and draftErrors[1] and draftErrors[1].code == "cyclic-draft", "cyclic draft is rejected")
owned, draftErrors = ns.SupplyDraft.Validate({
	skillLine = 197,
	alpha = 0.7,
	products = {},
	offers = { {} },
	fixed = { options = {}, refillOrders = {} },
})
Check(
	owned == nil and draftErrors[1].code == "invalid-fixed-offer-declaration",
	"incomplete declaration is rejected before Apply"
)
owned, draftErrors = ns.SupplyDraft.Validate({
	skillLine = 197,
	alpha = 0.7,
	products = {},
	offers = {},
	fixed = { options = {}, refillOrders = {} },
})
Check(owned == nil and draftErrors[1].code == "product-universe-required", "empty product universe is rejected")
ns.MerchantOffers.current.offers = { offer }
offer.maxPurchaseItems, offer.numAvailable, offer.isPurchasable = 2, 2, true
local adaptiveLaw = function(value)
	return { value = value, provenance = "synthetic explicit assumption", scope = "this finite run" }
end
local adaptiveDraft = {
	skillLine = 197,
	alpha = 0.7,
	products = { [10] = true },
	adaptiveOffers = {
		{
			offer = offer,
			version = 8,
			laws = {
				access = adaptiveLaw(true),
				price = adaptiveLaw("fixed"),
				vendor = adaptiveLaw("V"),
				ceiling = adaptiveLaw(1),
				stock = adaptiveLaw({
					key = "AS",
					unit = "items",
					available = 1,
					perBundle = 1,
					observedUnits = "items",
					law = "finite-no-restock",
				}),
				initialDelivery = adaptiveLaw("certain"),
				futureDelivery = adaptiveLaw({ chance = 1, payOnFailure = false }),
			},
		},
	},
	economics = {
		version = 8,
		laws = {
			initialVisitMoney = adaptiveLaw({ V = 0 }),
			refillVisitMoney = adaptiveLaw({ V = 0 }),
			initialVisitValue = adaptiveLaw({ V = 0 }),
			refillVisitValue = adaptiveLaw({ V = 0 }),
			tokenValues = adaptiveLaw({ ["item:20"] = 0 }),
			terminalCarry = adaptiveLaw({ ["item:10"] = 0, ["item:20"] = 0 }),
			failureLoss = adaptiveLaw(0),
		},
	},
	adaptive = { options = { workLimit = 1000, stateLimit = 100, coordinateLimit = 100, limbLimit = 100 } },
}
local adaptiveCompetitor = {}
for key, value in pairs(offer) do
	adaptiveCompetitor[key] = value
end
adaptiveCompetitor.index = 2
ns.MerchantOffers.current.offers[2] = adaptiveCompetitor
local beforeAdaptiveChanges = changes
applied, applyMissing = ns.SupplyDraft.Apply(adaptiveDraft)
Check(
	not applied and applyMissing[1].code == "stock-unit-law-missing" and applyMissing[1].offerID == "1:2",
	"adaptive Apply rejects the exact undeclared competing offer"
)
Check(
	ns.adaptiveReader == nil and changes == beforeAdaptiveChanges,
	"rejected adaptive draft publishes no configuration or changes"
)
ns.MerchantOffers.current.offers[2] = nil
applied, applyMissing = ns.SupplyDraft.Apply(adaptiveDraft)
Check(
	applied and not applyMissing,
	"adaptive draft applies through the real source owner: "
		.. tostring(applyMissing and applyMissing[1] and applyMissing[1].code)
		.. ":"
		.. tostring(applyMissing and applyMissing[1] and applyMissing[1].field)
)

-- Inspection is assembled for one declaration revision, merchant session and product universe. A declaration, a
-- resource reconciliation and a new merchant session each reach the next Inspect call rather than a later frame.
ns.MerchantOffers.Open()
local sessionOffer = {}
for key, value in pairs(offer) do
	sessionOffer[key] = value
end
sessionOffer.session = ns.MerchantOffers.session
ns.MerchantOffers.current = { session = ns.MerchantOffers.session, offers = { sessionOffer } }
local beforeDeclare = ns.SupplySources.Inspect({ [10] = true })
Check(beforeDeclare.status == "unavailable", "a new merchant session is unknown to inspection")
Check(ns.SupplySources.Declare(sessionOffer, 20, Laws()), "a new session's offer takes a declaration")
local afterDeclare = ns.SupplySources.Inspect({ [10] = true })
Check(afterDeclare.status == "conditional", "a declaration reaches the next inspection")
Check(
	afterDeclare.assumptions[1] and afterDeclare.assumptions[1].session == ns.MerchantOffers.session,
	"fresh evidence names the current session"
)
local changesBeforeReconcile = changes
observers.bags()
Check(changes == changesBeforeReconcile + 1, "reconciliation reports its change")
local afterReconcile = ns.SupplySources.Inspect({ [10] = true })
Check(
	afterReconcile.status == "unavailable" and afterReconcile.missing[1].code == "reconciliation-required",
	"a reconciliation flip reaches the next inspection"
)
print("supply_sources_spec: " .. checks .. " checks passed")
