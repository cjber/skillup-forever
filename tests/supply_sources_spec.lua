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
ns.WhenStaleObserver = function() end
ns.WhenEvent = function() end
local changes = 0
ns.Changed = function(kind)
	assert(kind == "sourceEvidence")
	changes = changes + 1
end
Load("Integrations/MerchantOffers.lua")("SkillUpForever", ns)
Load("Core/SupplySources.lua")("SkillUpForever", ns)
local checks = 0
local function Check(value, message)
	checks = checks + 1
	assert(value, message)
end
local missing = ns.SupplySources.Inspect({})
Check(
	missing.status == "unavailable" and missing.missing[1].code == "explicit-product-universe-required",
	"a product universe is required"
)
missing = ns.SupplySources.Inspect({ [10] = true })
Check(missing.missing[1].code == "merchant-window-unavailable", "no merchant window")
ns.MerchantOffers.current = { session = 1, offers = {} }
missing = ns.SupplySources.Inspect({ [10] = true })
Check(missing.missing[1].code == "merchant-offers-unavailable", "no offers in the window")
local offer = { session = 1, index = 1, itemID = 10, npcID = 123 }
ns.MerchantOffers.current = { session = 1, offers = { offer } }
local inspection = ns.SupplySources.Inspect({ [10] = true, [11] = true })
Check(inspection.status == "unavailable", "inspection needs no alpha")
Check(inspection.scope == "current-merchant-window", "inspection does not claim every source was observed")
Check(inspection.sourceRevision == 0 and #inspection.assumptions == 0, "nothing declares a source law")
Check(#inspection.missing == 8, "seven missing laws for the offer and one missing product")
Check(inspection.missing[1].code == "missing-law" and inspection.missing[1].offerID == "1:1", "offer laws come first")
Check(inspection.missing[1].field == "access" and inspection.missing[7].field == "refillVisit", "every law is named")
Check(inspection.missing[8].code == "product-offers-unavailable" and inspection.missing[8].field == "11", "product")

-- The API asks for evidence on every rebuild; each caller owns the records it was given.
local second = ns.SupplySources.Inspect({ [10] = true, [11] = true })
Check(inspection ~= second and inspection.missing ~= second.missing, "each inspection owns its tables")
inspection.missing[1].code = "mutated"
Check(
	ns.SupplySources.Inspect({ [10] = true, [11] = true }).missing[1].code == "missing-law",
	"a changed inspection record never reaches the next caller"
)
print("supply_sources_spec: " .. checks .. " checks passed")
