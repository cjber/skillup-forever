-- Run from the repository root: luajit tests/shopping_spec.lua
-- The objective tracker's lines and the merchant's buy button, with the whole addon loaded: what they show
-- follows the client's prices, bags and merchant through the plan.
local Client = dofile("tests/client.lua")
local equal = Client.equal
local function noop() end

local BANDAGE, HEAVY, SILK = 1, 2, 3
local BOOK = 5000
local c = Client.load({
	saved = { routeTargets = { [129] = 80 }, trackedProfessions = { [129] = true } },
	-- First Aid in miniature: a known bandage, a better one to train at 40, and Journeyman from 50.
	data = {
		Thresholds = { [BANDAGE] = { 1, 30, 45, 60 }, [HEAVY] = { 40, 50, 75, 100 } },
		RecipeData = {
			[BANDAGE] = { skillLine = 129, reagents = { { itemID = SILK, quantity = 1 } } },
			[HEAVY] = { skillLine = 129, reagents = { { itemID = SILK, quantity = 2 } } },
		},
		TrainerFees = { [HEAVY] = { 100, 40 } },
		TrainerRanks = { [129] = { { 150, 500, 50, 0 } } },
		ItemSellPrices = {},
		GatheredBy = {},
		VendorPrices = {},
		ProfessionTrainers = {},
	},
})
local ns = c.ns
ns.SetCollectMode("gather")
local module = c.G.SkillUpForeverObjectiveTracker
equal(c.host.IsAttached(module), false, "the section waits for the world to load")
c.EnterWorld()
c.Advance(0)
equal(c.host.IsAttached(module), true, "then joins the shared host")
-- ForeverCore's own quest section attaches to the shared host too; this is about the addon's module keeping one place.
local attached = 0
for _, tracked in ipairs(c.tracker) do
	if tracked == module then
		attached = attached + 1
	end
end
equal(attached, 1, "and keeps its place through native initialization")

c.level = 20
c.spells[HEAVY] = "Heavy Linen Bandage"
c.items[SILK] = { name = "Linen Cloth" }
c.known[BANDAGE] = true
c.auction[SILK] = 10
c.professions = { { name = "First Aid", rank = 40, max = 75, id = 129 } }

-- Heavy Linen Bandage is certain at 40 where the bandage's falling chance already costs more a
-- point, so the plan trains it at once: the tracker leads with the page's first training step.
local lines = c.Tracker()[1].lines
local walked = ns.PlanRoute(ns.RouteProfessions()[129]).steps
equal(walked[1].training and walked[1].training.recipeID, HEAVY, "the route page trains the recipe first")
equal(walked[3].rank and walked[3].rank.name, "Journeyman", "and the rank after")
equal(lines[1].key, "Train", "the tracker leads with training")
equal(lines[1].text, "Train Heavy Linen Bandage at 40 |cff808080(+1 more to train)|r", "the same training")
equal(lines[2].key, SILK, "then the reagent still missing")

ns.db.showTracker = false
ns.Changed("settings")
equal(#c.Tracker(), 0, "hiding the tracker removes every profession block")
equal(ns.db.trackedProfessions[129], true, "hiding keeps the profession tracked")
equal(ns.db.routeTargets[129], 80, "hiding keeps the profession target")
ns.db.showTracker = true
ns.Changed("settings")
equal(#c.Tracker(), 1, "showing restores the tracked profession")

-- A rank no trainer teaches comes from a book (#121): the tracker's line points at a vendor, not a trainer.
local trainerRanks = ns.TrainerRanks[129]
ns.TrainerRanks[129], ns.RankBooks[129] = {}, { { 150, BOOK, 500, 50, 0 } }
c.known[HEAVY] = true
c.professions[1].rank = 74
c.items[BOOK] = { name = "Journeyman's Handbook" }
ns.Changed("fees")
lines = c.Tracker()[1].lines
equal(lines[1].key, "Train", "the book leads")
equal(lines[1].text, "Buy and read Journeyman's Handbook at 50", "bought and read")
ns.TrainerRanks[129], ns.RankBooks[129] = {}, nil

-- Journeyman from a quest instead: hovering the tracker's line adds the Adventure Guide Forever hint after the
-- quest giver (waypoint_spec covers when the hint itself shows); a book's line doesn't.
local hovered = {}
local nearestForRank, addNearest, addChain = ns.NearestForRank, ns.AddNearest, ns.AddQuestChainHint
ns.NearestForRank = function()
	return 77, "Quest giver"
end
ns.AddNearest = function()
	hovered[#hovered + 1] = "nearest"
end
ns.AddQuestChainHint = function()
	hovered[#hovered + 1] = "chain"
end
c.G.GameTooltip = { SetOwner = function() end, Show = function() end }
c.G.GameTooltip_SetTitle = function() end
ns.RankQuests = { [129] = { { 150, 9001, 50, 0, "A" }, { 150, 9002, 50, 0, "H" } } }
ns.Changed("fees")
lines = c.Tracker()[1].lines
equal(lines[1].text, "Complete the Journeyman quest at 50", "the quest leads")
lines[1].frame.scripts.OnEnter(lines[1].frame)
equal(table.concat(hovered, " "), "nearest chain", "its tooltip names the giver, then the quest chain hint")
ns.RankQuests, hovered = nil, {}
ns.RankBooks[129] = { { 150, BOOK, 500, 50, 0 } }
ns.Changed("fees")
lines = c.Tracker()[1].lines
lines[1].frame.scripts.OnEnter(lines[1].frame)
equal(table.concat(hovered, " "), "nearest", "a book's line has no quest chain hint")
ns.NearestForRank, ns.AddNearest, ns.AddQuestChainHint = nearestForRank, addNearest, addChain
c.G.GameTooltip, c.G.GameTooltip_SetTitle = nil, nil
ns.TrainerRanks[129], ns.RankBooks[129] = trainerRanks, nil
c.known[HEAVY] = nil
c.professions[1].rank = 40
ns.Changed("fees")

-- Auctionator loses the only price there was: the scan reaches the tracker, which redraws to say why
-- nothing can be crafted, not that the reagents are in hand.
local redraws = module.dirty or 0
c.auction[SILK] = nil
c.AuctionatorScan()
equal(module.dirty, redraws + 1, "a price change redraws the tracker once")
lines = c.Tracker()[1].lines
equal(#lines, 1, "one line")
equal(lines[1].key, "Blocked", "a blocked route says so")
equal(
	lines[1].text,
	"Auctionator hasn't seen these reagents yet: scan the auction house with it to price them.",
	"with the route page's reason"
)
c.auction[SILK] = 10
c.AuctionatorScan()

-- The merchant's own Reagents tab lists what the route still needs, including whole merchant stacks, in the
-- merchant's item cells, with Buy all where the page row was. The addon never buys: BuyMerchantItem is
-- protected, so the player buys from the merchant's own window (#327).
local function Needed()
	return ns.TrackedNeeds()[1].items[1].need
end
c.bags[SILK] = Needed() - 7
c.money = 10000
c.items[SILK].icon = 1234
c.merchant = { { itemID = SILK, name = "Linen Cloth", price = 100, stackCount = 5 } }
c.Fire("MERCHANT_SHOW")
c.Advance(0)
local tab = rawget(c.G, "SkillUpForeverMerchantTab")
local page = rawget(c.G, "SkillUpForeverMerchantPage")
equal(tab ~= nil, true, "the merchant window has a Reagents tab")
equal(tab.parent, c.G.MerchantFrame, "a Reagents tab belongs to the merchant window")
equal(tab.text, "Reagents", "named for the reagents")
equal(tab.template, "PanelTabButtonTemplate", "in the template the merchant's own tabs inherit")
-- It sits in the merchant's row exactly as its own tabs do: after Buyback, at the same gap.
local tabAnchor = tab.points[1]
equal(tabAnchor[1], "LEFT", "the Reagents tab follows the stock tabs")
equal(tabAnchor[2], c.G.MerchantFrameTab2, "after Buyback")
equal(tabAnchor[3], "RIGHT", "from its right edge")
equal(tabAnchor[4], -16, "at the stock tabs' own gap")
equal(tabAnchor[5], 0, "on the same line")
equal(tab.shown, true, "a known merchant stack shows the tab")
equal(page.shown, false, "its page waits for the tab")
-- The tab lists it in the merchant's own cells, and Buy all sits where the page row was.
tab.scripts.OnClick(tab)
equal(page.shown, true, "selecting the tab shows the page")
equal(tab.selected, true, "with the template's selected tab art")
equal(tab.Left.shown, false, "the unselected left piece goes")
equal(tab.LeftActive.shown, true, "and the active one shows")
equal(c.G.MerchantItem1.alpha, 0, "the stock item cells make way")
equal(c.G.MerchantPageText.alpha, 0, "the page row makes way")
equal(c.G.MerchantBuyBackItem.alpha ~= 0, true, "the buyback cell stays in sight, as it stays clickable")
equal(c.G.MerchantFrameTab1.alpha, 0, "the stock tab it came from reads unselected")
local cover = rawget(c.G, "SkillUpForeverMerchantTabCover")
equal(cover.shown, true, "and an unselected copy covers it")
equal(cover.template, "PanelTabButtonTemplate", "the cover is in the merchant's own tab template")
equal(cover.width, c.G.MerchantFrameTab1:GetWidth(), "the cover is the width of the tab it covers")
equal(cover.height, c.G.MerchantFrameTab1:GetHeight(), "and its height")
local cell = page.Items[1]
equal(cell.frame.shown, true, "the first reagent fills a merchant item cell")
equal(cell.name:GetText(), "Linen Cloth", "with its name")
equal(cell.price:GetText(), "200c", "and the cost of whole stacks")
equal(cell.icon, cell.button.icon, "and its icon, from the template's own icon region")
equal(cell.icon.texture, 1234, "with the item's texture")
local buy = rawget(c.G, "SkillUpForeverMerchantBuyAll")
equal(buy.text, "Buy all  200c", "Buy all has the total")
-- Buy all lists the need on a dialog of the addon's own on the merchant's window.
local function Dialog()
	for _, frame in ipairs(c.frames) do
		if frame.parent == c.G.MerchantFrame and frame.Close then
			return frame
		end
	end
end
equal(Dialog(), nil, "nothing shows before a click")
buy.scripts.OnClick()
local dialog = Dialog()
equal(dialog.shown, true, "a click lists what is missing")
equal(dialog.Text.text, "Reagents still needed  10 Linen Cloth  200c", "with the items and the total cost")
equal(#c.purchased, 0, "and buys nothing itself")
dialog.Close.scripts.OnClick()
equal(dialog.shown, false, "Close hides the list")
-- The need changes while it is open: what it showed is out of date, so it goes.
buy.scripts.OnClick()
c.bags[SILK] = c.bags[SILK] + 5
c.Fire("BAG_UPDATE_DELAYED")
c.Advance(0)
equal(dialog.shown, false, "a changed cost closes the list")
c.bags[SILK] = c.bags[SILK] - 5
c.Fire("BAG_UPDATE_DELAYED")
c.Advance(0)
equal(buy.text, "Buy all  200c", "the full need is back")
-- Merchant and Buyback work as before: selecting either one hides the page and puts the window back.
c.ClickTab(2)
equal(page.shown, false, "Buyback hides the addon page")
equal(cover.shown, false, "the cover goes with it")
equal(tab.Left.shown, true, "the Reagents tab returns to its unselected art")
equal(tab.LeftActive.shown, false, "with the active piece hidden")
equal(c.G.MerchantItem1.alpha, 1, "the stock item cells return")
equal(c.G.MerchantPageText.alpha, 1, "with their page row")
equal(c.G.MerchantFrameTab1.alpha, 1, "and the stock tab comes back")
tab.scripts.OnClick(tab)
equal(c.G.MerchantFrameTab2.alpha, 0, "the selected Buyback tab is the one covered")
cover.scripts.OnClick()
equal(page.shown, false, "the cover returns to Buyback")
equal(c.G.MerchantFrameTab2.alpha, 1, "and uncovers it")
-- Switching tabs keeps the window as it was and reuses the page, so its place in the list is kept.
c.G.MerchantFrame.width, c.G.MerchantFrame.height = 336, 444
tab.scripts.OnClick(tab)
c.ClickTab(1)
tab.scripts.OnClick(tab)
equal(rawget(c.G, "SkillUpForeverMerchantPage"), page, "the page is kept across tabs")
equal(c.G.MerchantFrame.width, 336, "switching tabs keeps the window width")
equal(c.G.MerchantFrame.height, 444, "and its height")
-- The player can do without the tab, and its page goes with it.
c.SetSetting("merchantButton", false)
equal(tab.shown, false, "the setting hides the tab")
equal(page.shown, false, "and closes its page")
equal(c.G.MerchantItem1.alpha, 1, "putting the merchant's cells back")
c.SetSetting("merchantButton", true)
c.Advance(0)
equal(tab.shown, true, "and brings it back")
equal(page.shown, false, "with the page still closed")
tab.scripts.OnClick(tab)
buy.scripts.OnClick()
equal(#c.purchased, 0, "the addon never calls the protected merchant buy function")
dialog.Close.scripts.OnClick()
for _, invalid in ipairs({ false, 0, -1 }) do
	c.merchant[1].stackCount = invalid or nil
	c.purchased = {}
	c.Fire("MERCHANT_UPDATE")
	c.Advance(0)
	equal(tab.shown, false, "unknown or invalid stack hides the tab")
	tab.scripts.OnClick(tab)
	equal(page.shown, false, "and cannot open its page")
	equal(#c.purchased, 0, "unknown or invalid stack cannot invent units")
end
c.merchant = nil
c.Fire("MERCHANT_CLOSED")
equal(tab.shown, false, "the tab goes with the merchant")
equal(#c.chat, 0, "and none of it says anything in chat")

-- The Auctionator list of what the tracked route still buys is kept up to date on its own: written
-- once, left alone while the need is the same, and emptied when the bags cover it.
equal(ns.AuctionListName("First Aid"), "SkillUp: Tester-Realm: First Aid", "the list is named for the profession")
equal(ns.AuctionatorAutoscan(), nil, "an unread option says nothing")
c.auctionAutoscan = false
equal(ns.AuctionatorAutoscan(), false, "the scan-on-open option reads as off")
equal(c.shoppingLists["SkillUp: Tester-Realm: First Aid"], nil, "gather mode writes no Auctionator list")
local personalList = { "Personal supplies" }
c.shoppingLists["SkillUp: First Aid"] = personalList
c.shoppingLists["SkillUp: Other-Realm: First Aid"] = personalList
c.player.name = nil
equal(ns.AuctionListName("First Aid"), nil, "an unknown character has no shared fallback list")
ns.SetCollectMode("auction")
equal(c.shoppingLists["SkillUp: Tester-Realm: First Aid"], nil, "no list is written before identity is ready")
c.player.name = "Tester"
ns.SetCollectMode("auction")
local list = c.shoppingLists["SkillUp: Tester-Realm: First Aid"]
equal(type(list), "table", "buying keeps an Auctionator list")
equal(c.shoppingLists["SkillUp: First Aid"], personalList, "the old generic list remains untouched")
equal(c.shoppingLists["SkillUp: Other-Realm: First Aid"], personalList, "another character's list remains untouched")
local realm = c.player.realm
c.player.realm = "OtherRealm"
equal(ns.AuctionListName("First Aid"), "SkillUp: Tester-OtherRealm: First Aid", "realms have separate list names")
c.player.realm = realm
equal(#list, 1, "with the route's one auction reagent")
equal(list[1], "Linen Clothx" .. (Needed() - ns.Have(SILK)), "and what the route still needs")
c.Fire("BAG_UPDATE_DELAYED")
equal(c.shoppingLists["SkillUp: Tester-Realm: First Aid"], list, "an unchanged need does not rewrite the list")
c.ns.db.auctionSearch = false
c.bags[SILK] = 1
c.Fire("BAG_UPDATE_DELAYED")
equal(c.shoppingLists["SkillUp: Tester-Realm: First Aid"], list, "disabled automatic search does not rewrite the list")
c.ns.db.auctionSearch = true
c.bags[SILK] = Needed()
c.Fire("BAG_UPDATE_DELAYED")
equal(#c.shoppingLists["SkillUp: Tester-Realm: First Aid"], 0, "a covered need empties the list")
local originalList = c.shoppingLists["SkillUp: Tester-Realm: First Aid"]
c.bags[SILK] = 0
c.player.name = "Alt"
ns.SetCollectMode("auction")
equal(type(c.shoppingLists["SkillUp: Alt-Realm: First Aid"]), "table", "another character gets its own route list")
equal(
	c.shoppingLists["SkillUp: Tester-Realm: First Aid"],
	originalList,
	"another character cannot rewrite the first list"
)
c.player.name = "Tester"

-- Disabling automatic list maintenance does not disable an explicit Search button query.
c.ns.db.auctionSearch = false
c.bags[SILK] = 0
equal(ns.SearchReagents(HEAVY, 1), "auctionator", "manual search still works when automatic search is disabled")

-- The section hangs on the shared host, never on Blizzard's tracker manager: a client without the manager
-- still gets it once the world loads.
local bare = Client.load({ trackerManager = false })
bare.EnterWorld()
bare.Advance(0)
equal(bare.host.IsAttached(bare.G.SkillUpForeverObjectiveTracker), true, "the section needs no tracker manager")
equal(#bare.chat, 0, "and says nothing about a missing tracker")

-- #557: three training stops. The count says they are stops to train, and hovering the line lists the two
-- that follow the first, each with the skill level TrainingSteps gave it.
c.spells[BANDAGE] = "Linen Bandage"
local trainingPlan = {
	profession = { name = "First Aid", skillLine = 129, capped = false },
	target = 150,
	steps = {
		{ training = { recipeID = BANDAGE, fee = 0, usedAt = 20, reqSkill = 20, cap = 21 } },
		{ training = { recipeID = HEAVY, fee = 0, usedAt = 60, reqSkill = 60, cap = 61 } },
		{ rank = { name = "Journeyman", cap = 150, reqSkill = 50, level = 0, fee = 500 } },
	},
	crafts = {},
	ranks = {},
	unpriced = 0,
}
local realTrackedNeeds, realNearestTrainer, realNearestForRank, realAddNearest =
	ns.TrackedNeeds, ns.NearestTrainer, ns.NearestForRank, ns.AddNearest
ns.TrackedNeeds = function()
	return { { plan = trainingPlan, items = {} } }
end
ns.NearestTrainer = function()
	return 77
end
ns.NearestForRank = function()
	return 77, "Nearest trainer"
end
ns.AddNearest = noop
local trainingLines = c.Tracker()[1].lines
local firstText = "Train Linen Bandage at 20"
local secondText = "Train Heavy Linen Bandage at 60"
local thirdText = "Train Journeyman at 50"
equal(trainingLines[1].key, "Train", "the training line leads")
equal(
	trainingLines[1].text,
	firstText .. string.format(" |cff808080(%s)|r", string.format(ns.L["+%d more to train"], 2)),
	"the suffix counts the other training stops"
)
local tooltipLines = {}
c.G.GameTooltip = { SetOwner = noop, Show = noop }
c.G.GameTooltip_SetTitle = function(_, text)
	tooltipLines[#tooltipLines + 1] = text
end
c.G.GameTooltip_AddBlankLineToTooltip = noop
c.G.GameTooltip_AddNormalLine = function(_, text)
	tooltipLines[#tooltipLines + 1] = text
end
c.G.GameTooltip_Hide = noop
trainingLines[1].frame.scripts.OnEnter(trainingLines[1].frame)
local joined = table.concat(tooltipLines, "\n")
equal(joined:find(firstText, 1, true) ~= nil, true, "the tooltip titles the first stop")
equal(joined:find(ns.L["Also train"], 1, true) ~= nil, true, "under the training heading")
equal(joined:find(secondText, 1, true) ~= nil, true, "and lists the second training stop")
equal(joined:find(thirdText, 1, true) ~= nil, true, "and the third")
ns.TrackedNeeds, ns.NearestTrainer, ns.NearestForRank, ns.AddNearest =
	realTrackedNeeds, realNearestTrainer, realNearestForRank, realAddNearest

Client.report("shopping_spec")
