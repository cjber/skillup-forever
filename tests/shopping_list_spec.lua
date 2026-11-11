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
		LootedFrom = {},
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
c.ns.SetCollectMode("gather")
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
equal(api.minor, 6, "API minor version")
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

-- #553: a refresh redraws the same headings, row frames and empty state. Nothing from an earlier draw stays
-- on the body, so text cannot pile up and each refresh leaks no frame.
c.Fire("PLAYER_ENTERING_WORLD")
c.Fire("VARIABLES_LOADED")
c.Advance(0)
c.ns.OpenShoppingList()
local window = c.G.SkillUpForeverShoppingList
local function Find(root, match)
	for _, child in ipairs({ root:GetChildren() }) do
		if match(child) then
			return child
		end
		local found = Find(child, match)
		if found then
			return found
		end
	end
end
local body = Find(window, function(region)
	return region.width == 550
end)
assert(body, "the shopping list body was built")
local function WithText(key)
	local found = {}
	for _, child in ipairs({ body:GetChildren() }) do
		if child.text == key then
			found[#found + 1] = child
		end
	end
	return found
end
local headingTexts = {
	c.ns.L["Gather"],
	c.ns.L["Vendor"],
	c.ns.L["Auction house"],
	c.ns.L["Unknown"],
}
for _, key in ipairs(headingTexts) do
	equal(#WithText(key), 1, "one " .. key .. " heading after the first refresh")
end
equal(#WithText(c.ns.L["No tracked profession"]), 0, "no empty text while rows show")

local tracked = c.ns.db.trackedProfessions
c.ns.db.trackedProfessions = {}
c.ns.Changed("tracking")
equal(#WithText(c.ns.L["No tracked profession"]), 1, "one empty text region, not one per refresh")
equal(WithText(c.ns.L["No tracked profession"])[1]:IsShown(), true, "the empty text shows with no rows")
for _, key in ipairs(headingTexts) do
	equal(#WithText(key), 1, "the " .. key .. " heading is reused by an empty refresh")
	equal(WithText(key)[1]:IsShown(), false, "and hidden when it has no rows")
end
local pooled = #body.children

c.ns.db.trackedProfessions = tracked
c.ns.Changed("tracking")
equal(#body.children, pooled, "a refresh with rows again leaks no frame")
for _, key in ipairs(headingTexts) do
	equal(#WithText(key), 1, "one " .. key .. " heading after the second refresh with rows")
	equal(WithText(key)[1]:IsShown(), true, "and the heading shows again")
end
equal(#WithText(c.ns.L["No tracked profession"]), 1, "one empty text region after both states")
equal(WithText(c.ns.L["No tracked profession"])[1]:IsShown(), false, "empty text hidden when rows show again")

-- The copy window has its own title and opens beside the list it copies.
local copyButton
for _, child in ipairs({ window:GetChildren() }) do
	if child.text == c.ns.L["Copy list"] then
		copyButton = child
	end
end
assert(copyButton, "the Copy list button was built")
copyButton.scripts.OnClick(copyButton)
local copyWindow = c.G.SkillUpForeverShoppingCopy
assert(copyWindow, "the copy window was built")
equal(copyWindow.title, c.ns.L["Copy shopping list"], "the copy window has its own title")
local anchor = copyWindow.points[1]
equal(anchor[1], "TOPLEFT", "the copy window anchors from its top left")
equal(anchor[2], window, "to the shopping list window")
equal(anchor[3], "TOPRIGHT", "beside it")
equal(anchor[4], 8, "with a small gap")
equal(anchor[5], 0, "level with its top")

-- The client calls an OnDragStart handler as handler(self, button). Handing it a bare StartMoving reference made
-- the button string its alwaysStartFromMouse argument, so each window's handler starts the move with no argument.
local function MovesWithoutArguments(target, label)
	local started = {}
	target.StartMoving = function(self, ...)
		started[#started + 1] = { self = self, args = { ... } }
	end
	target.scripts.OnDragStart(target, "LeftButton")
	target.StartMoving = nil
	equal(#started, 1, label .. " starts a move when the client begins a drag")
	equal(started[1].self, target, label .. " moves itself")
	equal(#started[1].args, 0, label .. " passes StartMoving no argument")
end
MovesWithoutArguments(window, "the shopping list")
MovesWithoutArguments(copyWindow, "the copy window")

-- #622: focusing the copy box selects the list. The client calls the focus handler as handler(self, isUserInput),
-- so a bare HighlightText reference took the flag as its start index, raised, and left the list unselected.
local copyEdit = Find(copyWindow, function(region)
	return region.scripts.OnEditFocusGained ~= nil
end)
assert(copyEdit, "the copy box gains focus through a script")
copyEdit.highlighted = nil
copyEdit.scripts.OnEditFocusGained(copyEdit, true)
equal(copyEdit.highlighted, copyEdit.text, "the focus handler selects the whole list")
copyEdit:ClearFocus()
copyEdit.highlighted = nil
copyEdit:SetFocus()
equal(copyEdit.highlighted, copyEdit.text, "gaining focus through the client selects the whole list")

-- #566: opening from a route page shows only that profession's plan, and a profession with nothing tracked
-- says so instead of showing another tracked profession's materials.
local LEATHERWORKING, COOKING, BLACKSMITHING = 165, 185, 164
local LW_RECIPE, COOK_RECIPE = 11, 12
local LW_ITEM, COOK_ITEM = 1101, 1201
local scoped = Client.load({
	boot = false,
	saved = {
		routeTargets = { [LEATHERWORKING] = 60, [COOKING] = 70 },
		trackedProfessions = { [LEATHERWORKING] = true, [COOKING] = true },
	},
	data = {
		Thresholds = { [LW_RECIPE] = { 1, 30, 45, 60 }, [COOK_RECIPE] = { 1, 30, 45, 60 } },
		RecipeData = {
			[LW_RECIPE] = { skillLine = LEATHERWORKING, reagents = { { itemID = LW_ITEM, quantity = 1 } } },
			[COOK_RECIPE] = { skillLine = COOKING, reagents = { { itemID = COOK_ITEM, quantity = 1 } } },
		},
		TrainerFees = {},
		TrainerRanks = {},
		RankBooks = {},
		ItemSellPrices = {},
		GatheredBy = {},
		LootedFrom = {},
		VendorPrices = {},
		ProfessionTrainers = {},
		ScrollDrops = {},
		WorldDrops = {},
	},
})
scoped.professions = {
	{ name = "Leatherworking", rank = 50, max = 75, id = 8165 },
	{ name = "Cooking", rank = 50, max = 75, id = 8185 },
	{ name = "Blacksmithing", rank = 50, max = 75, id = 8164 },
}
scoped.spells[LW_RECIPE], scoped.spells[COOK_RECIPE] = "Cured Leather", "Cooked Meat"
scoped.known[LW_RECIPE], scoped.known[COOK_RECIPE] = true, true
scoped.items[LW_ITEM], scoped.items[COOK_ITEM] = { name = "Light Leather" }, { name = "Raw Meat" }
scoped.auction[LW_ITEM], scoped.auction[COOK_ITEM] = 10, 20
scoped.Boot()
scoped.Fire("PLAYER_ENTERING_WORLD")
scoped.Fire("VARIABLES_LOADED")
scoped.Advance(0)
local function VisibleTexts(root)
	local texts = {}
	local function Walk(frame, visible)
		visible = visible and frame:IsShown()
		if visible and frame.text then
			texts[#texts + 1] = frame.text
		end
		for _, child in ipairs({ frame:GetChildren() }) do
			Walk(child, visible)
		end
	end
	Walk(root, root:IsShown())
	return table.concat(texts, "\n")
end
scoped.ns.OpenShoppingList(LEATHERWORKING)
local scopedWindow = scoped.G.SkillUpForeverShoppingList
local scopedBody = Find(scopedWindow, function(region)
	return region.width == 550
end)
assert(scopedBody, "the scoped shopping list body was built")
local scopedText = VisibleTexts(scopedBody)
equal(scopedText:find("Light Leather", 1, true) ~= nil, true, "the asked-for profession's row shows")
equal(scopedText:find("Raw Meat", 1, true), nil, "another tracked profession's row stays out")
local summaryText = VisibleTexts(scopedWindow)
equal(
	summaryText:find(string.format(scoped.ns.L["%s to %d"], "Leatherworking", 60), 1, true) ~= nil,
	true,
	"the summary names the asked-for profession"
)
equal(summaryText:find("Cooking", 1, true), nil, "and not another tracked profession")
scoped.ns.OpenShoppingList(BLACKSMITHING)
local untrackedText = VisibleTexts(scopedWindow)
equal(
	untrackedText:find(string.format(scoped.ns.L["Nothing is tracked for %s."], "Blacksmithing"), 1, true) ~= nil,
	true,
	"an untracked profession says nothing is tracked for it"
)
equal(untrackedText:find("Raw Meat", 1, true), nil, "and no Cooking rows show")
equal(untrackedText:find(scoped.ns.L["No tracked profession"], 1, true) ~= nil, true, "the empty message shows")

-- The Shopping list's Auction house section says how the Auctionator list works (#554): its name, where it
-- lives, and that each row is a click. With Buy reagents off it says turning it on writes the list, and
-- without Auctionator it says the bar searches the game's own box.
local offNote = c.ns.AuctionListNote({ "SkillUp: Tester-Realm: Tailoring" })
equal(
	offNote:find("Turning Buy reagents on writes an Auctionator list", 1, true) ~= nil,
	true,
	"with Buy reagents off the section says how to get the list"
)
c.ns.SetCollectMode("auction")
local onNote = c.ns.AuctionListNote({ "SkillUp: Tester-Realm: Tailoring", "SkillUp: Tester-Realm: Blacksmithing" })
equal(onNote:find("Auctionator list: SkillUp: Tester-Realm: Tailoring", 1, true) ~= nil, true, "it names the list")
equal(onNote:find("Open the auction house, Shopping tab, pick it and Search", 1, true) ~= nil, true, "where it is")
equal(onNote:find("buy each row with a click", 1, true) ~= nil, true, "and that buying stays one click a row")
local noAuctionator = Client.load({ auctionator = false, boot = false })
equal(
	noAuctionator.ns.AuctionListNote(nil):find("game's own auction box one reagent at a time", 1, true) ~= nil,
	true,
	"without Auctionator it says the bar searches the game's own box one at a time"
)
Client.report("shopping list")
