local Client = dofile("tests/client.lua")
local equal = Client.equal

--[[ Sub-crafting: a reagent a learned recipe makes for less than buying it. ]]

local LEATHER, HIDE, GOODS = 20, 10, 30
local c3 = Client.load({
	data = {
		Thresholds = {
			[200] = { 80, 80, 100, 120 },
			[201] = { 1, 40, 55, 70 },
		},
		RecipeData = {
			[200] = {
				skillLine = 129,
				reagents = { { itemID = HIDE, quantity = 2 } },
				output = { itemID = LEATHER, quantity = 1 },
			},
			[201] = {
				skillLine = 129,
				reagents = { { itemID = LEATHER, quantity = 1 } },
				output = { itemID = GOODS, quantity = 1 },
			},
		},
		VendorPrices = { [HIDE] = 100, [LEATHER] = 300 },
		ItemSellPrices = {},
		TrainerFees = {},
		TrainerRanks = {},
		GatheredBy = {},
	},
})
local ns3 = c3.ns
c3.professions = { { name = "First Aid", rank = 1, max = 300, id = 129 } }
c3.known[200], c3.known[201] = true, true
-- The crafted output sells for nothing, so both recipes have a price and the route can rank them.
c3.items[LEATHER] = { name = "Cured Light Hide", sell = 0 }
c3.items[GOODS] = { name = "Cured Goods", sell = 0 }

equal(ns3.SubCraft(LEATHER).recipeID, 200, "a cheaper recipe makes the reagent")
equal(ns3.SubCraft(HIDE), nil, "nothing makes the raw hide")
ns3.db.routeTargets[129] = 20
local sub = ns3.PlanRoute(ns3.PlayerProfessions()[129])
equal(sub.crafts[1].recipeID, 201, "the route levels with the recipe that uses the reagent")
equal(#sub.crafts[1].subcrafts, 1, "which carries its own sub-craft")
equal(sub.crafts[1].subcrafts[1].recipeID, 200, "the recipe that makes the reagent")
equal(sub.crafts[1].subcrafts[1].crafts, sub.crafts[1].crafts, "one sub-craft a craft of the parent")

c3.bags[HIDE] = 100
c3.Fire("TRADE_SKILL_SHOW")
c3.Advance(0)
c3.G.Professions = {
	GetProfessionInfo = function()
		return { professionName = "First Aid", professionID = 129 }
	end,
}
c3.G.C_TradeSkillUI.GetCraftableCount = function(id)
	return id == 200 and 50 or 0
end
equal(ns3.NextCraft(sub).recipeID, 200, "next craft selects the craftable prerequisite")
local planned = sub.crafts[1].crafts
equal(ns3.NextCraft(sub).count, planned, "prerequisite count is bounded by route demand")
c3.craftable = 2
c3.G.C_TradeSkillUI.GetCraftableCount = function()
	return c3.craftable
end
equal(ns3.NextCraft(sub).count, 2, "client resource rules limit the selected prerequisite")
equal(ns3.NextCraft(sub).text, "Craft 2 of " .. planned .. "× recipe 200", "partial count uses the translated phrase")
c3.craftable = 0
equal(ns3.NextCraft(sub).reason, "Missing reagents for this step.", "client zero count blocks crafting")
c3.bags[HIDE] = 0
equal(ns3.NextCraft(sub).missing.itemID, HIDE, "missing reagent belongs to the prerequisite")
c3.craftable = 999
c3.known[200] = nil
equal(ns3.NextCraft(sub).reason, "Train recipe 200 first.", "unlearned prerequisite blocks the ordered step")
c3.known[200] = true
c3.live[200] =
	{ requirements = { { name = "Curing tool", type = c3.G.Enum.RecipeRequirementType.Totem, met = false } } }
equal(ns3.NextCraft(sub).reason, "Need a Curing tool in your bags.", "selected prerequisite checks its tool")
c3.live[200] = nil
c3.live[201] =
	{ requirements = { { name = "Finishing tool", type = c3.G.Enum.RecipeRequirementType.Totem, met = false } } }
equal(ns3.NextCraft(sub).recipeID, 200, "a later parent tool does not block making its prerequisite")
c3.live[201] = nil
c3.bags[LEATHER] = planned
equal(ns3.NextCraft(sub).recipeID, 201, "held intermediates allow the parent next")
c3.known[201] = nil
equal(ns3.NextCraft(sub).reason, "Train recipe 201 first.", "parent still checks learned status")
c3.known[201] = true
c3.bags[LEATHER] = planned - 1
equal(ns3.NextCraft(sub).recipeID, 200, "one missing intermediate keeps the prerequisite first")
equal(ns3.NextCraft(sub).count, 1, "held intermediates reduce prerequisite demand")
sub.profession.capped = true
sub.ranks = { { name = "Journeyman" } }
equal(ns3.NextCraft(sub).reason, "Train Journeyman first: you're at your cap.", "cap blocks prerequisites too")
sub.profession.capped = false
sub.ranks = {}
sub.profession.max = 3
c3.bags[LEATHER] = 0
equal(ns3.NextCraft(sub).planned, 2, "parent cap limits prerequisite demand")
sub.profession.max = 300
c3.G.Professions.GetProfessionInfo = function()
	return { professionName = "Other", professionID = 164 }
end
equal(ns3.NextCraft(sub).reason, "Open First Aid to craft from here.", "wrong open profession blocks prerequisites")
-- A learned maker may belong to a different profession from the route it supplies.
ns3.RecipeData[200].skillLine = 165
c3.professions[2] = { name = "Leatherworking", rank = 100, max = 300, id = 165 }
c3.G.Professions.GetProfessionInfo = function()
	return { professionName = "First Aid", professionID = 129 }
end
equal(
	ns3.NextCraft(sub).reason,
	"Open Leatherworking to craft from here.",
	"parent window blocks the other profession's prerequisite"
)
c3.G.Professions.GetProfessionInfo = function()
	return { professionName = "Leatherworking", professionID = 165 }
end
equal(ns3.NextCraft(sub).recipeID, 200, "prerequisite can be crafted in its own profession")
equal(ns3.NextCraft(sub).count, planned, "cross-profession prerequisite retains route demand")
sub.profession.capped = true
sub.ranks = { { name = "Journeyman" } }
equal(
	ns3.NextCraft(sub).reason,
	"Train Journeyman first: you're at your cap.",
	"parent cap still blocks a different profession's prerequisite"
)
sub.profession.capped = false
sub.ranks = {}
c3.bags[LEATHER] = planned
equal(
	ns3.NextCraft(sub).reason,
	"Open First Aid to craft from here.",
	"completed prerequisite requires the parent profession"
)
c3.G.Professions.GetProfessionInfo = function()
	return { professionName = "First Aid", professionID = 129 }
end
equal(ns3.NextCraft(sub).recipeID, 201, "parent can be crafted after switching back")
-- Two branches consume the same intermediate, made two at a time. Bags and batch
-- surplus must be shared, rather than deducted independently for each occurrence.
local c4 = Client.load({
	data = {
		Thresholds = { [200] = { 80, 80, 100, 120 }, [202] = { 80, 80, 100, 120 }, [203] = { 1, 40, 55, 70 } },
		RecipeData = {
			[200] = {
				skillLine = 129,
				reagents = { { itemID = HIDE, quantity = 2 } },
				output = {
					itemID = LEATHER,
					quantity = 2,
				},
			},
			[202] = {
				skillLine = 129,
				reagents = { { itemID = LEATHER, quantity = 1 } },
				output = {
					itemID = 40,
					quantity = 1,
				},
			},
			[203] = {
				skillLine = 129,
				reagents = { { itemID = LEATHER, quantity = 1 }, { itemID = 40, quantity = 1 } },
				output = { itemID = GOODS, quantity = 1 },
			},
		},
		VendorPrices = { [HIDE] = 100, [LEATHER] = 300, [40] = 1000 },
		ItemSellPrices = {},
		TrainerFees = {},
		TrainerRanks = {},
		GatheredBy = {},
	},
})
c4.professions = { { name = "First Aid", rank = 1, max = 300, id = 129 } }
c4.known[200], c4.known[202], c4.known[203] = true, true, true
c4.items[LEATHER], c4.items[40], c4.items[GOODS] = { sell = 0 }, { sell = 0 }, { sell = 0 }
c4.G.Professions = {
	GetProfessionInfo = function()
		return { professionName = "First Aid", professionID = 129 }
	end,
}
c4.ns.db.routeTargets[129] = 3
local nested = c4.ns.PlanRoute(c4.ns.PlayerProfessions()[129])
equal(nested.crafts[1].recipeID, 203, "nested route selects the parent")
c4.bags[LEATHER] = 2
local selected = c4.ns.NextCraft(nested)
equal(selected.recipeID, 200, "held leather cannot satisfy both branches twice")
equal(selected.count, 1, "one two-output batch fills the shared shortfall")
c4.bags[LEATHER] = 4
equal(c4.ns.NextCraft(nested).recipeID, 202, "completed deepest prerequisite advances to the next ordered craft")
c4.bags[40] = 2
c4.bags[LEATHER] = 2
equal(c4.ns.NextCraft(nested).recipeID, 203, "held branch output removes its own prerequisite demand")
c4.bags[40], c4.bags[LEATHER] = 0, 0
nested.crafts[1].crafts = 1
selected = c4.ns.NextCraft(nested)
equal(selected.recipeID, 200, "shared batch surplus is produced before the branch that uses it")
equal(selected.count, 1, "one two-output batch supplies both branches")
print("next craft checks passed")
