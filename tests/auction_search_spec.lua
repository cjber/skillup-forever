-- Run from the repository root: luajit tests/auction_search_spec.lua
-- The auction house reagent search from the Professions window (#142): how many crafts it searches for, what
-- the bags and bank still lack for them, and how it searches with Auctionator and without.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local BANDAGE, HEAVY, LINEN, THREAD = 1, 2, 3, 4
local function Load(options)
	local c = Client.load({
		auctionator = options.auctionator,
		saved = { routeTargets = { [129] = 60 }, trackedProfessions = { [129] = true } },
		data = {
			Thresholds = { [BANDAGE] = { 1, 30, 45, 60 }, [HEAVY] = { 40, 50, 75, 100 } },
			RecipeData = {
				[BANDAGE] = { skillLine = 129, reagents = { { itemID = LINEN, quantity = 1 } } },
				[HEAVY] = {
					skillLine = 129,
					reagents = { { itemID = LINEN, quantity = 2 }, { itemID = THREAD, quantity = 1 } },
				},
			},
			TrainerFees = {},
			TrainerRanks = {},
			ItemSellPrices = {},
			GatheredBy = {},
			VendorPrices = {},
			ProfessionTrainers = {},
		},
	})
	c.items[LINEN] = { name = "Linen Cloth" }
	c.items[THREAD] = { name = "Coarse Thread" }
	c.known[BANDAGE] = true
	c.auction[LINEN] = 10
	c.professions = { { name = "First Aid", rank = 1, max = 75, id = 129 } }
	return c
end

local c = Load({})
local ns = c.ns
-- The route crafts the bandage to 60, so that is the count offered for it; a recipe it doesn't craft gets one.
local planned = 0
for _, craft in ipairs(ns.PlanRoute(ns.RouteProfessions()[129]).crafts) do
	planned = planned + (craft.recipeID == BANDAGE and craft.crafts or 0)
end
equal(planned > 1, true, "the route crafts the bandage several times")
equal(ns.PlannedCrafts(BANDAGE), math.ceil(planned), "the count offered is what the route plans")
equal(ns.PlannedCrafts(HEAVY), 1, "a recipe the route doesn't craft starts at one")

-- Reagents for the count, less what the bags and bank hold; a reagent you have enough of is left out.
c.bags[LINEN] = 5
local short = ns.ReagentShortfall(HEAVY, 4)
equal(#short, 2, "both reagents are short for four")
equal(short[1].itemID == LINEN and short[1].count, 3, "eight linen, less the five you hold")
equal(short[2].itemID == THREAD and short[2].count, 4, "four thread")
c.bags[THREAD] = 10
equal(#ns.ReagentShortfall(HEAVY, 4), 1, "thread you already hold is not searched")

-- With Auctionator: one list of exact names with quantities, searched at once.
local how = ns.SearchReagents(HEAVY, 4)
equal(how, "auctionator", "Auctionator does the search")
equal(c.shoppingLists["SkillUp: crafting"][1], "Linen Clothx3", "the list asks for what is missing")
equal(#c.shoppingLists["SkillUp: crafting"], 1, "and nothing you have")
equal(c.auctionSearches[1] and c.auctionSearches[1][1], "Linen Clothx3", "and is searched with its quantities")
c.bags[LINEN] = 8
equal((ns.SearchReagents(HEAVY, 4)), "none", "nothing is searched when the bags hold enough")
equal(#c.auctionSearches, 1, "so Auctionator is not asked again")
equal(ns.db.auctionSearch, true, "the search is on by default")

-- Without Auctionator: the game's own search box gets the next missing reagent on each click, and nothing more.
c = Load({ auctionator = false })
ns = c.ns
local searched = {}
c.G.AuctionHouseFrame = {
	IsShown = function()
		return true
	end,
	SetSearchText = function(_, text)
		searched[#searched + 1] = text
		return true
	end,
}
local first, item = ns.SearchReagents(HEAVY, 2)
equal(first, "game", "the game's search box is used")
equal(searched[1], "Linen Cloth", "with the first missing reagent's name")
equal(item and item.count, 4, "and how many are still needed")
local _, second = ns.SearchReagents(HEAVY, 2)
equal(searched[2], "Coarse Thread", "the next click moves to the next reagent")
equal(second and second.count, 2, "with its own count")
ns.SearchReagents(HEAVY, 2)
equal(searched[3], "Linen Cloth", "and wraps around")
ns.SearchReagents(HEAVY, 3)
equal(searched[4], "Linen Cloth", "a new count starts from the first reagent")
c.G.AuctionHouseFrame.IsShown = function()
	return false
end
ns.SearchReagents(HEAVY, 3)
equal(#searched, 4, "nothing is written while the auction house is closed")

Client.report("auction_search_spec")
