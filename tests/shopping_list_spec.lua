-- Run from the repository root: luajit tests/shopping_list_spec.lua
local Client = dofile("tests/client.lua")
local equal = Client.equal
local c = Client.load({
	boot = false,
	saved = {
		routeTargets = { [197] = 60, [164] = 70 },
		trackedProfessions = { [197] = true, [164] = true },
	},
	data = {
		Thresholds = { [3] = { 40, 60, 70, 80 }, [4] = { 40, 60, 70, 80 } },
		RecipeData = {
			[3] = {
				skillLine = 197,
				reagents = {
					{ itemID = 4306, quantity = 1 },
					{ itemID = 2321, quantity = 2 },
					{ itemID = 2322, quantity = 1 },
					{ itemID = 444, quantity = 1 },
				},
			},
			[4] = { skillLine = 164, reagents = { { itemID = 4306, quantity = 2 } } },
		},
		TrainerFees = {},
		TrainerRanks = {},
		RankBooks = {},
		ItemSellPrices = {},
		GatheredBy = { [444] = 197 },
		VendorPrices = { [2321] = 20, [2322] = 30 },
		ProfessionTrainers = {},
		ScrollDrops = {},
		WorldDrops = {},
	},
	questie = {
		items = { [2321] = { class = 7, vendors = { 77 } }, [2322] = { class = 7, vendors = { 77 } } },
		npcs = { [77] = { name = "Thread Vendor", spawns = { [10] = { { 50, 50 } } }, side = "AH" } },
		areas = { [10] = 10 },
	},
})
c.professions = {
	{ name = "Tailoring", rank = 50, max = 75, id = 8197 },
	{ name = "Blacksmithing", rank = 50, max = 75, id = 8164 },
}
c.spells[3], c.spells[4] = "Silk Shirt", "Silk Belt"
c.known[3], c.known[4] = true, true
c.items[4306], c.items[2321], c.items[2322], c.items[444] =
	{ name = "Silk Cloth" }, { name = "Fine Thread" }, { name = "Heavy Thread" }, { name = "Gathered Herb" }
c.items[5956] = { name = "Blacksmith Hammer" }
c.live[3] = {
	info = { learned = true, maxTrivialLevel = 80, numSkillUps = 1, relativeDifficulty = 1 },
	requirements = { { name = "Blacksmith Hammer", type = c.G.Enum.RecipeRequirementType.Totem, met = false } },
}
c.auction[4306], c.auctionAge = 50, 3
c.bags = { [4306] = 2, [2321] = 1 }
equal(#c.G.SkillUpForever.API.ShoppingList(), 0, "no saved variables returns an empty list")
c.Boot()
c.maps = { [0] = { mapID = 10, name = "Darkshire" } }
c.ns.NearestVendor(2321)
c.ns.NearestVendor(2322)
c.Advance(0)
c.G.Syndicator = {
	API = {
		IsReady = function()
			return true
		end,
		GetInventoryInfoByItemID = function()
			return {
				characters = { { character = "Altname", realmNormalized = "Other", bags = 3, bank = 4, mail = 5 } },
			}
		end,
	},
}
local api = c.G.SkillUpForever.API
equal(api.minor, 3, "API minor version")
local lists = api.ShoppingList()
equal(#lists, 2, "both tracked professions are present")
equal(lists[1].profession, "Blacksmithing", "profession names sort deterministically")
equal(lists[2].profession, "Tailoring", "second profession remains separate")
equal(lists[1].target, 70, "the API carries the saved route target")
equal(lists[2].target, 60, "each profession keeps its own target")
local byID = {}
for _, row in ipairs(lists[2].items) do
	byID[row.itemID] = row
end
equal(byID[444].source, "gather", "gather bucket leads")
equal(byID[2321].source, "vendor", "vendor bucket follows")
equal(byID[4306].source, "auction", "auction bucket follows vendor")
equal(lists[2].items[2].itemID < lists[2].items[3].itemID, true, "item IDs sort inside the vendor bucket")
equal(byID[4306].priceAge, 3, "Auctionator age")
equal(byID[4306].missing >= 0, true, "have never makes missing negative")
equal(byID[4306].have, 2, "bags reduce the missing count")
equal(byID[2321].missing < byID[2321].need, true, "holdings reduce vendor missing count")
equal(byID[444].alt[1].name, "Altname", "largest alt is returned first")
equal(byID[444].alt[1].count, 12, "alt bag, bank and mail totals")
equal(byID[5956].source, "unknown", "unpriced route tools join the unknown bucket")
equal(lists[2].unpriced, 1, "unpriced missing item count")
equal(lists[2].total > 0, true, "priced rows contribute to the total")
local bsSilk
for _, row in ipairs(lists[1].items) do
	if row.itemID == 4306 then
		bsSilk = row
	end
end
equal(byID[4306].need ~= bsSilk.need, true, "a shared reagent keeps per-profession needs separate")
lists[2].items[1].missing = 0
equal(api.ShoppingList()[2].items[1].missing > 0, true, "each call is a fresh copy")
equal(api.ShoppingList(111)[1], nil, "an untracked skill line has no profession row")
local text = c.ns.ShoppingText()
equal(text:find("SkillUp Forever shopping list", 1, true) ~= nil, true, "text header")
equal(text:find("Auction house", 1, true) ~= nil, true, "text source heading")
equal(text:find("Silk Cloth", 1, true) ~= nil, true, "text item name")
equal(text:find("price unknown", 1, true) ~= nil, true, "text marks unpriced items")
equal(text:find("|T", 1, true), nil, "plain money contains no texture markup")
local routed
c.G.ShortestPathForever = {
	API = {
		Estimate = function()
			return 2
		end,
		NavigateRoute = function(_, stops)
			routed = stops
			return true
		end,
	},
}
equal(c.ns.ShoppingTrip(197), true, "Shortest Path accepts a material trip")
equal(routed[1].kind, "vendor", "the vendor is the first stop")
equal(routed[1].title:find("Fine Thread", 1, true) ~= nil, true, "the vendor stop names its items")
equal(routed[1].title:find("Heavy Thread", 1, true) ~= nil, true, "vendor title names all its items")
equal(#routed, 1, "one stop covers multiple items from the same vendor")
c.G.ShortestPathForever = nil
c.G.C_Map.CanSetUserWaypointOnMap = function()
	return true
end
c.G.C_Map.SetUserWaypoint = function(point)
	c.userWaypoint = point
end
c.G.C_SuperTrack = { SetSuperTrackedUserWaypoint = function() end }
c.G.UiMapPoint = {
	CreateFromCoordinates = function(map, x, y)
		return { map = map, x = x, y = y }
	end,
}
equal(c.ns.ShoppingTrip(197), false, "without Shortest Path, only the waypoint fallback runs")
equal(
	table.concat(c.chat, " "):find("setting a waypoint to the first vendor", 1, true) ~= nil,
	true,
	"fallback explains the single waypoint"
)
equal(c.ns.ShoppingTrip(111), false, "a route with nothing missing is refused")
Client.report("shopping list")
