local Client = dofile("tests/client.lua")
local equal = Client.equal
local c = Client.load({
	boot = false,
	saved = { routeTargets = { [197] = 2 }, trackedProfessions = { [197] = true } },
	data = {
		Thresholds = { [1] = { 0, 0, 0, 2 } },
		RecipeData = {
			[1] = {
				skillLine = 197,
				output = { itemID = 11, quantity = 1 },
				reagents = { { itemID = 10, quantity = 1 } },
			},
		},
		VendorPrices = { [10] = 3 },
		TrainerFees = {},
		TrainerRanks = {},
		ItemSellPrices = {},
	},
	questie = {
		items = { [10] = { class = 7, vendors = { 123, 456, 789 } } },
		npcs = {
			[123] = { name = "Selected First", spawns = { [10] = { { 50, 50 } } }, side = "AH" },
			[456] = { name = "Selected Second", spawns = { [10] = { { 60, 60 } } }, side = "AH" },
			[789] = { name = "Unselected Nearest", spawns = { [10] = { { 1, 1 } } }, side = "AH" },
		},
		areas = { [10] = 10 },
	},
})
c.professions = { { name = "Tailoring", icon = 1, rank = 1, max = 75, id = 8197 } }
c.known[1] = true
c.spells[1] = "Synthetic Cloth"
c.items[11] = { sell = 0 }
c.schematics = { [1] = { reagents = { { 10, 1 } }, output = 11 } }
c.money = 6
c.bags[20] = 4
c.items[90] = { name = "Synthetic Tool" }
c.auction[90] = 7
c.live[1] = { requirements = { { type = 1, name = "Synthetic Tool", met = false } } }
c.auction[10] = 3
c.Boot()
c.maps = { [0] = { mapID = 10, name = "Synthetic Zone" } }
local API = c.G.SkillUpForever.API

-- No supply selection exists: the API publishes no certificate and an unconfigured summary.
local entry = API.Professions()[1]
equal(entry.supply, nil, "no supply certificate is published")
equal(entry.recipeEvidence.status, "unsupported", "native production law absent")
equal(entry.recipeEvidence.missing[1].code, "recipe-production-law-missing", "recipe evidence stable missing code")
equal(entry.sourceEvidence.status, "unavailable", "source evidence is unavailable")
equal(entry.sourceEvidence.missing[1].code, "merchant-window-unavailable", "source evidence keeps structured reasons")
local shopping = API.ShoppingList(197)[1]
equal(shopping.supplySummary.status, "unconfigured", "shopping summary is unconfigured")
equal(shopping.items[1].acquisitions, nil, "shopping rows carry no selected transactions")
equal(shopping.items[1].inventoryScope, "bags-and-bank", "shopping rows count bags and bank")
for _, step in ipairs(entry.steps) do
	equal(step.acquisition, nil, "steps carry no selected transaction")
end

-- A merchant window names every missing law of each offer of a route product.
c.npc = { id = 123 }
c.merchant = {}
for _, reagent in ipairs(API.Professions()[1].reagents) do
	c.merchant[#c.merchant + 1] = {
		itemID = reagent.itemID,
		price = 1,
		stackCount = 1,
		numAvailable = 8,
		hasExtendedCost = false,
	}
end
c.Fire("MERCHANT_SHOW")
local evidence = API.Professions()[1].sourceEvidence
equal(evidence.status, "unavailable", "offers without declared laws are unavailable")
equal(evidence.missing[1].code, "missing-law", "each offer law is named missing")
equal(evidence.missing[1].field, "access", "the first missing law is access")
equal(evidence.sourceRevision, 0, "nothing declares a source law")
evidence.missing[1].code = "mutated"
equal(API.Professions()[1].sourceEvidence.missing[1].code, "missing-law", "evidence is an owned copy")
Client.report("Supply API")
