-- Run from the repository root: luajit tests/auction_search_spec.lua
-- The auction house reagent search from the Professions window (#142): how many crafts it searches for, what
-- the bags and bank still lack for them, and how it searches with Auctionator and without.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local BANDAGE, HEAVY, LINEN, THREAD, SALT = 1, 2, 3, 4, 5
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
					reagents = {
						{ itemID = LINEN, quantity = 2 },
						{ itemID = THREAD, quantity = 1 },
						{ itemID = SALT, quantity = 1 },
					},
				},
			},
			TrainerFees = {},
			TrainerRanks = {},
			ItemSellPrices = {},
			GatheredBy = {},
			-- Salt is a vendor's: it is never searched for at the auction house.
			VendorPrices = { [SALT] = 5 },
			ProfessionTrainers = {},
		},
	})
	c.items[LINEN] = { name = "Linen Cloth" }
	c.items[THREAD] = { name = "Coarse Thread" }
	c.items[SALT] = { name = "Salt" }
	local open = true
	c.G.AuctionHouseFrame = {
		IsShown = function()
			return open
		end,
		SetSearchText = function(self, text)
			self.searched[#self.searched + 1] = text
			return self.buyTab
		end,
		searched = {},
		buyTab = true,
	}
	function c.CloseAuctionHouse()
		open = false
	end
	c.known[BANDAGE] = true
	c.auction[LINEN] = 10
	c.professions = { { name = "First Aid", rank = 1, max = 75, id = 129 } }
	return c
end

local c = Load({})
local ns = c.ns
ns.SetCollectMode("gather")
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
local short, elsewhere = ns.ReagentShortfall(HEAVY, 4)
equal(#short, 2, "both auction reagents are short for four, and the vendor's salt is left out")
equal(elsewhere, 1, "the salt is counted as short elsewhere")
equal(short[1].itemID == LINEN and short[1].count, 3, "eight linen, less the five you hold")
equal(short[2].itemID == THREAD and short[2].count, 4, "four thread")
-- A material this character gathers is left out while it gathers; with Buy reagents on and nothing pricing it,
-- it is an auction price unknown so the route keeps it (#162), and it is still searched for (#559).
ns.GatheredBy[THREAD] = 186
c.professions[2] = { name = "Mining", rank = 1, max = 75, id = 186 }
c.Fire("SKILL_LINES_CHANGED")
ns.Changed("prices")
equal(#ns.ReagentShortfall(HEAVY, 4), 1, "thread this character gathers is not searched")
ns.SetCollectMode("auction")
equal(ns.PriceSource(THREAD), "auction", "with Buy reagents on and no price, it is still bought there")
equal(ns.Price(THREAD).unknown, true, "as a price unknown")
equal(#ns.ReagentShortfall(HEAVY, 4), 2, "but searched for")
ns.SetCollectMode("gather")
ns.GatheredBy[THREAD], c.professions[2] = nil, nil
c.Fire("SKILL_LINES_CHANGED")
ns.Changed("prices")
c.bags[THREAD] = 10
equal(#ns.ReagentShortfall(HEAVY, 4), 1, "thread you already hold is not searched")

-- With Auctionator: one list of exact names with quantities, searched at once.
local personalList = { "Personal supplies" }
c.shoppingLists["SkillUp: crafting"] = personalList
c.player.name = nil
equal((ns.SearchReagents(HEAVY, 4)), "auctionator", "an unknown character can still search without saving a list")
equal(#c.auctionSearches, 1, "the search needs no persistent list")
equal(c.shoppingLists["SkillUp: crafting"], personalList, "an unknown character cannot replace the old list")
c.auctionSearches = {}
c.player.name = "Tester"
local how = ns.SearchReagents(HEAVY, 4)
equal(how, "auctionator", "Auctionator does the search")
equal(c.shoppingLists["SkillUp: crafting"], personalList, "the old crafting list remains untouched")
equal(c.shoppingLists["SkillUp: Tester-Realm: crafting"][1], "Linen Clothx3", "the list asks for what is missing")
equal(#c.shoppingLists["SkillUp: Tester-Realm: crafting"], 1, "and nothing you have")
equal(c.auctionSearches[1] and c.auctionSearches[1][1], "Linen Clothx3", "and is searched with its quantities")
c.bags[LINEN] = 8
equal((ns.SearchReagents(HEAVY, 4)), "elsewhere", "with only the vendor's salt short, nothing is searched")
c.bags[SALT] = 10
equal((ns.SearchReagents(HEAVY, 4)), "none", "nothing is searched when the bags hold enough")
equal(#c.auctionSearches, 1, "so Auctionator is not asked again")
equal(ns.db.auctionSearch, true, "the search is on by default")
c.bags[LINEN], c.bags[SALT] = 0, 0
c.CloseAuctionHouse()
ns.SearchReagents(HEAVY, 4)
equal(#c.auctionSearches, 1, "Auctionator is not asked once the auction house has closed")

-- Without Auctionator: the game's own search box gets the next missing reagent on each click, and nothing more.
c = Load({ auctionator = false })
ns = c.ns
local searched = c.G.AuctionHouseFrame.searched
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
-- Off the Buy tab the game declines the text: the round stays on that reagent and says why.
c.G.AuctionHouseFrame.buyTab = false
equal((ns.SearchReagents(HEAVY, 3)), "unfilled", "a declined search box is reported")
c.G.AuctionHouseFrame.buyTab = true
ns.SearchReagents(HEAVY, 3)
equal(searched[6], "Coarse Thread", "and the next click retries the same reagent")
-- Buying a reagent changes what is short, so the round starts again from the first one still missing.
c.bags[LINEN] = 6
ns.SearchReagents(HEAVY, 3)
equal(searched[7], "Coarse Thread", "linen bought, thread is now first")
-- A reagent whose name the client hasn't loaded yet is asked for, and the click says so rather than blaming the tab.
c.items[THREAD] = nil
equal((ns.SearchReagents(HEAVY, 3)), "loading", "an unloaded name is still loading")
equal(#searched, 7, "and the box is left alone")
c.items[THREAD] = { name = "Coarse Thread" }
c.CloseAuctionHouse()
equal((ns.SearchReagents(HEAVY, 3)), "unfilled", "nothing is written while the auction house is closed")
equal(#searched, 7, "so the box is left alone")

-- The first auction-house visit prices the tracked route, including vendor fallbacks.
c = Load({})
ns = c.ns
ns.SetCollectMode("auction")
c.auction[LINEN] = nil
ns.VendorPrices[LINEN] = 5
ns.Changed("prices")
equal(ns.PriceSource(LINEN), "vendor", "the route has a vendor fallback before its first auction price")
c.Fire("AUCTION_HOUSE_SHOW")
c.Advance(0)
equal(#c.auctionSearches, 1, "opening the auction house searches the unpriced tracked route")
equal(c.auctionSearches[1][1]:match("^Linen Clothx") ~= nil, true, "the route search uses exact reagent names")
c.Fire("AUCTION_HOUSE_SHOW")
c.Advance(0)
equal(#c.auctionSearches, 1, "duplicate show events do not repeat the visit search")
c.Fire("AUCTION_HOUSE_CLOSED")
c.auction[LINEN], c.auctionAge = 10, 0
c.Fire("AUCTION_HOUSE_SHOW")
c.Advance(0)
equal(#c.auctionSearches, 1, "today's recorded prices need no search")
c.Fire("AUCTION_HOUSE_CLOSED")
c.auctionAge = 1
c.Fire("AUCTION_HOUSE_SHOW")
c.Advance(0)
equal(#c.auctionSearches, 2, "a later visit refreshes older recorded prices")
c.Fire("AUCTION_HOUSE_CLOSED")
ns.db.auctionSearch = false
c.Fire("AUCTION_HOUSE_SHOW")
c.Advance(0)
equal(#c.auctionSearches, 2, "disabled reagent searching never starts an automatic query")
c.Fire("AUCTION_HOUSE_CLOSED")
ns.db.auctionSearch = true
c.Fire("AUCTION_HOUSE_SHOW")
c.CloseAuctionHouse()
c.Advance(0)
equal(#c.auctionSearches, 2, "closing before the deferred visit leaves Auctionator alone")

c = Load({})
ns = c.ns
ns.SetCollectMode("gather")
c.auction[LINEN] = nil
c.Fire("AUCTION_HOUSE_SHOW")
c.Advance(0)
equal(#c.auctionSearches, 0, "gather mode starts no auction search")

Client.report("auction_search_spec")
