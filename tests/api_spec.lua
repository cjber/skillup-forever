-- Run from the repository root: luajit tests/api_spec.lua
-- The public API over a small recipe set, with the whole addon loaded: every step, price and NPC comes from what
-- the client holds, through the same files the game runs.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local THREAD, LEATHER, SILK, BAR = 2321, 2319, 4306, 2840
local GLOVES, HILLMANS, LEATHER_RECIPE, SHIRT, BRACERS = 1, 2, 9, 3, 4
local GINA, TELONIS = 77, 88
-- A book that teaches Tailoring's 150 cap here (#121): no trainer rank is bundled in this spec.
local BOOK = 5000

local c = Client.load({
	boot = false,
	saved = { routeTargets = { [197] = 60, [164] = 20 }, trackedProfessions = { [197] = true } },
	data = {
		Thresholds = {
			[GLOVES] = { 125, 140, 155, 165 },
			[HILLMANS] = { 145, 155, 165, 175 },
			[SHIRT] = { 40, 60, 70, 80 },
			[BRACERS] = { 1, 20, 40, 60 },
		},
		RecipeData = {
			[GLOVES] = {
				skillLine = 165,
				reagents = { { itemID = LEATHER, quantity = 6 }, { itemID = THREAD, quantity = 2 } },
				output = { itemID = 4253, quantity = 1 },
			},
			[HILLMANS] = {
				skillLine = 165,
				reagents = { { itemID = LEATHER, quantity = 8 }, { itemID = THREAD, quantity = 1 } },
				output = { itemID = 4247, quantity = 1 },
			},
			[LEATHER_RECIPE] = { skillLine = 165, reagents = {}, output = { itemID = LEATHER, quantity = 1 } },
			[SHIRT] = { skillLine = 197, reagents = { { itemID = SILK, quantity = 1 } } },
			[BRACERS] = { skillLine = 164, reagents = { { itemID = BAR, quantity = 1 } } },
		},
		TrainerFees = { [HILLMANS] = { 1800, 145 } },
		TrainerRanks = {},
		RankBooks = { [197] = { { 150, BOOK, 500, 70, 0 } } },
		ItemSellPrices = {},
		GatheredBy = {},
		LootedFrom = {},
		VendorPrices = { [THREAD] = 100, [BAR] = 10 },
		ProfessionTrainers = { [165] = { { TELONIS, 300 } } },
		ScrollDrops = {},
		WorldDrops = {},
	},
	-- Who sells thread and where the trainer stands come from the player's QuestieDB.
	questie = {
		items = { [THREAD] = { class = 7, vendors = { GINA } }, [BOOK] = { class = 9, vendors = { GINA } } },
		npcs = {
			[GINA] = { name = "Gina", spawns = { [10] = { { 50, 50 } } }, side = "AH" },
			[TELONIS] = { name = "Telonis", spawns = { [141] = { { 50, 50 } } }, side = "AH" },
		},
		areas = { [10] = 10, [141] = 11 },
		-- A rank only a quest teaches (#121): the giver is QuestieDB's.
		quests = { [7002] = { name = "Leather Lesson", races = 77, starts = { TELONIS } } },
	},
})
local ns, API = c.ns, c.G.SkillUpForever.API
equal(API.version, 1, "version 1")
equal(API.minor, 6, "minor 6 adds tracking, the shopping trip, limits, stats and the leaderboard")
-- Publishing is discovery, not an API change (#594): the suite lists the addon with the API's own version and minor.
local published
for _, entry in ipairs(c.G.ForeverCore.APIKit.Addons()) do
	if entry.name == "SkillUpForever" then
		published = entry
	end
end
equal(published and published.version, 1, "the suite list carries the API's version")
equal(published and published.minor, 6, "and its minor")
equal(published and published.api, API, "and the addon's own API table")
-- Nothing to answer says why, so a caller can tell "ask again later" from "there is nothing to ask about".
local beforeLoad, beforeLoadReason = API.Professions()
equal(beforeLoad, nil, "nothing before the saved variables load")
equal(beforeLoadReason, "loading", "and the read says to ask again")
local noMaterials, noMaterialsReason = API.RequiredMaterials(999999)
equal(noMaterials, nil, "an unknown recipe has no materials")
equal(noMaterialsReason, "none", "and says there is nothing to answer")
local noParts, noPartsReason = API.SubComponents(999999)
equal(noParts, nil, "nor sub-components")
equal(noPartsReason, "none", "with the same reason")
local trackedBefore, trackedBeforeReason = API.IsTracked(165)
equal(trackedBefore, nil, "nothing is tracked before the saved variables load")
equal(trackedBeforeReason, "loading", "and tracking says to ask again")
local setBefore, setBeforeReason = API.SetTracked(165, true)
equal(setBefore, nil, "tracking cannot be set before the saved variables load")
equal(setBeforeReason, "loading", "with the same reason")

c.spells = {
	[GLOVES] = "Toughened Leather Gloves",
	[HILLMANS] = "Hillman's Leather Gloves",
	[BRACERS] = "Copper Bracers",
}
c.known = { [GLOVES] = true, [LEATHER_RECIPE] = true, [SHIRT] = true, [BRACERS] = true }
-- The gloves sell for nothing; Hillman's sell for most of their reagents, so they are the cheaper craft from
-- 145, where a trainer teaches them: 8 leather and a thread is 4100, less 3100.
c.items = {
	[THREAD] = { name = "Fine Thread" },
	[LEATHER] = { name = "Medium Leather" },
	[4253] = { sell = 0 },
	[4247] = { sell = 3100 },
}
c.bags = { [LEATHER] = 40, [SILK] = 20, [BAR] = 20 }
c.auction = { [LEATHER] = 500, [SILK] = 50 }
c.maps = { [0] = { mapID = 10, name = "Darkshire" }, [1] = { mapID = 11, name = "Darnassus" } }
-- Tailoring and Blacksmithing plan ten sure crafts; Leatherworking plans to its cap.
c.professions = {
	{ name = "Leatherworking", icon = 136247, rank = 142, max = 150, id = 8165 },
	{ name = "Tailoring", icon = 136247, rank = 50, max = 75, id = 8197 },
	{ name = "Blacksmithing", icon = 136247, rank = 10, max = 75, id = 8164 },
	{ name = "Alchemy", icon = 136247, rank = 0, max = 0, id = 8171 },
}
c.Boot()
ns.SetCollectMode("gather")
equal(#c.chat, 0, "the addon starts without a word")

-- Subscribe is ForeverCore's hub (docs/api.md): the frame after a change, once per burst, naming what moved.
local heard = {}
local unsubscribe = API.Subscribe(function(changes)
	heard[#heard + 1] = changes
end)
equal(#heard, 0, "subscribing sends nothing by itself")
c.Advance(0)
equal(#heard, 0, "nor on the next frame")
ns.Changed("target")
equal(#heard, 0, "a change waits for the frame after it")
c.Advance(0)
equal(#heard, 1, "then the callback runs")
equal(heard[1].professions, true, "naming the levelling answers")
equal(heard[1].shopping, true, "and the shopping list")
equal(heard[1].stop, nil, "and nothing it does not publish")
ns.Changed("target")
ns.Changed("prices")
ns.Changed("bags")
equal(#heard, 1, "a burst of changes is still one call")
c.Advance(0)
equal(#heard, 2, "sent on the frame after it")
unsubscribe()
unsubscribe()
ns.Changed("target")
c.Advance(0)
equal(#heard, 2, "an unsubscribed callback hears nothing, and unsubscribing twice is safe")

-- Tracking reads and sets the same saved choice the route page and tracker use, quietly from the API.
equal(API.IsTracked(197), true, "the saved tracked profession reads back")
equal(API.IsTracked(165), false, "and an untracked one is false")
local sounds = 0
local PlaySound = c.G.PlaySound
c.G.PlaySound = function()
	sounds = sounds + 1
end
equal(API.SetTracked(165, true), true, "tracking a learned profession changes the setting")
equal(API.IsTracked(165), true, "and reads back tracked")
equal(API.SetTracked(165, true), false, "setting the same value changes nothing")
equal(API.SetTracked(165, "yes"), false, "a non-boolean choice is refused")
equal(API.SetTracked(333, true), false, "an unlearned skill line is refused")
equal(API.SetTracked(999, true), false, "an unknown skill line is refused")
equal(API.SetTracked(165, false), true, "and it can be stopped again")
equal(sounds, 0, "no API call plays the checkbox sound")
ns.SetTrackedByPlayer(165, true)
equal(sounds, 1, "the player's own click keeps the checkbox sound")
ns.SetTracked(165, false)
c.G.PlaySound = PlaySound

-- A tracking change reaches subscribers like any other answer, once, on the next frame.
local trackingHeard = {}
local stopTracking = API.Subscribe(function(changes)
	trackingHeard[#trackingHeard + 1] = changes
end)
API.SetTracked(165, true)
equal(#trackingHeard, 0, "a tracking change waits for the frame after it")
c.Advance(0)
equal(#trackingHeard, 1, "then the subscriber hears it once")
equal(trackingHeard[1].professions, true, "naming the levelling answers")
equal(trackingHeard[1].shopping, true, "and the shopping list")
API.SetTracked(165, true)
c.Advance(0)
equal(#trackingHeard, 1, "a refused no-change sends nothing")
API.SetTracked(165, false)
c.Advance(0)
equal(#trackingHeard, 2, "stopping it is another single change")
stopTracking()

local list = API.Professions()
-- Until the vendors and trainers are read from QuestieDB, a step says what to find and routes nowhere.
local early = list[3].steps
equal(early[1].detail, "Vendor · 800c", "before the vendors are read a buy names none")
equal(early[1].nav, false, "and routes nowhere")
equal(early[3].detail, "Leatherworking trainer · 1800c", "nor does training name a trainer")
c.Advance(0)
list = API.Professions()
local rawInputs = API.RequiredMaterials(GLOVES, 2)
equal(#rawInputs, 2, "both unexpanded recipe inputs")
equal(rawInputs[1].itemID, LEATHER, "raw leather item")
equal(rawInputs[1].count, 12, "raw leather scales with requested crafts")
equal(rawInputs[2].itemID, THREAD, "raw thread item")
equal(rawInputs[2].count, 4, "raw thread scales with requested crafts")
local components = API.SubComponents(GLOVES, 2)
equal(#components, 0, "no valued sub-component recipes")
equal(API.RequiredMaterials(999999), nil, "unknown recipe returns nil")
-- Tracked first, then reagents in hand, then a purchase first, then nothing to do.
equal(#list, 4, "one entry per profession")
equal(list[1].name, "Tailoring", "a tracked profession leads")
equal(list[2].name, "Blacksmithing", "a craft ready to go beats a shopping trip")
equal(list[3].name, "Leatherworking", "a purchase first comes after")
equal(list[4].name, "Alchemy", "nothing to do comes last")

local lw = list[3]
equal(lw.skillLineID, 165, "skill line")
equal(lw.icon, 136247, "icon")
equal(lw.rank, 142, "rank is base skill")
equal(lw.maxRank, 150, "max rank is the cap")
equal(lw.title, "Journeyman", "the 150 cap is Journeyman")
equal(#lw.steps, 3, "at most three steps")

local buy, craft, train = lw.steps[1], lw.steps[2], lw.steps[3]
equal(buy.kind, "buy", "the thread the bags lack is bought first")
equal(buy.text, "Buy 8 Fine Thread", "buy text")
equal(buy.detail, "Gina, Darkshire · 800c", "buy detail names the nearest vendor and cost")
equal(buy.itemID, THREAD, "buy item")
equal(buy.count, 8, "buy count")
equal(buy.cost, 800, "buy cost")
equal(buy.nav, true, "a vendor can be routed to")
equal(craft.kind, "craft", "then the craft")
-- Three points at 23/25, 22/25 and 21/25 a craft: 3.4 crafts expected, so four.
equal(craft.text, "Craft 4 Toughened Leather Gloves", "craft text")
equal(craft.detail, "142 to 145", "craft detail is its skill range")
equal(craft.spellID, GLOVES, "craft spell")
equal(craft.itemID, 4253, "craft product")
equal(craft.count, 4, "craft count")
equal(craft.cost, nil, "the craft's cost is in its purchases")
equal(craft.nav, false, "a craft has nowhere to go")
equal(train.kind, "train", "then the recipe the route trains next")
equal(train.text, "Train Hillman's Leather Gloves", "train text")
equal(train.detail, "Telonis, Darnassus · 1800c", "train detail names the nearest trainer and fee")
equal(train.spellID, HILLMANS, "train spell")
equal(train.cost, 1800, "train fee")
equal(train.nav, true, "a trainer can be routed to")

equal(#lw.recipes, 2, "the route's crafts")
local gloves, hillmans = lw.recipes[1], lw.recipes[2]
equal(gloves.name, "Toughened Leather Gloves", "recipe name")
equal(gloves.spellID, GLOVES, "recipe spell")
equal(gloves.itemID, 4253, "recipe product")
equal(gloves.count, 4, "recipe crafts")
equal(gloves.fromRank, 142, "recipe from")
equal(gloves.toRank, 145, "recipe to")
equal(gloves.learned, true, "known recipe")
equal(gloves.color, "yellow", "colour at its first skill")
equal(gloves.trainAt, nil, "a known recipe needs no training")
equal(gloves.cost, nil, "and costs no fee")
equal(hillmans.learned, false, "a recipe still to train")
equal(hillmans.trainAt, 145, "trained where the route first uses it")
equal(hillmans.cost, 1800, "its fee")
equal(hillmans.color, "orange", "orange at 145")

local byItem = {}
for _, reagent in ipairs(lw.reagents) do
	byItem[reagent.itemID] = reagent
end
equal(byItem[THREAD].need, 13, "thread for the whole route")
equal(byItem[THREAD].have, 0, "thread in the bags")
equal(byItem[THREAD].source, "vendor", "thread from a vendor")
equal(byItem[LEATHER].need, 64, "leather for the whole route")
equal(byItem[LEATHER].have, 40, "leather in the bags")
equal(byItem[LEATHER].source, "craft", "a learned recipe makes the leather")

-- Limits trim each call's fresh copy; the cached answer is built at the largest size, so no limit rebuilds it.
local limited = API.Professions({ steps = 1, recipes = 1 })
equal(#limited[3].steps, 1, "a step limit trims the route")
equal(#limited[3].recipes, 1, "a recipe limit trims the crafts")
local stepsOnly = API.Professions({ steps = 1 })
equal(#stepsOnly[3].steps, 1, "a step limit alone trims the steps")
equal(#stepsOnly[3].recipes, 2, "and keeps the default recipe count")
local recipesOnly = API.Professions({ recipes = 1 })
equal(#recipesOnly[3].steps, 3, "a recipe limit alone keeps the default steps")
equal(#recipesOnly[3].recipes, 1, "and trims the recipes")
local defaults = API.Professions({})
equal(#defaults[3].steps, 3, "an empty table keeps the step default")
equal(#defaults[3].recipes, 2, "and the recipe one")
local full = API.Professions({ steps = 25, recipes = 25 })
equal(#full[3].steps > #defaults[3].steps, true, "25 is the largest limit allowed, with every step it has")
for _, bad in ipairs({ 0, 26, 1.5, "3", false }) do
	local value, reason = API.Professions({ steps = bad })
	equal(value, nil, "a bad step limit is refused: " .. tostring(bad))
	equal(reason, "invalid", "with an invalid reason")
end
local badRecipes, badRecipesReason = API.Professions({ recipes = 1.5 })
equal(badRecipes, nil, "a bad recipe limit is refused")
equal(badRecipesReason, "invalid", "with the same reason")
local badLimits, badLimitsReason = API.Professions("many")
equal(badLimits, nil, "a non-table limits argument is refused")
equal(badLimitsReason, "invalid", "with the same reason")

-- Nil where SkillUp can't tell: no name, no rank title, no price, nothing planned.
local tailoring = list[1]
equal(tailoring.steps[1].text, "Craft 10 recipe 3", "an unnamed recipe still reads")
equal(tailoring.recipes[1].name, nil, "an unnamed recipe has no name")
equal(tailoring.recipes[1].itemID, nil, "a recipe without a product has no item")
equal(tailoring.reagents[1].source, "auction", "a reagent only Auctionator prices is from the auction house")
local alchemy = list[4]
equal(alchemy.title, nil, "a cap no rank ends at has no title")
equal(#alchemy.steps, 0, "no steps")
equal(#alchemy.recipes, 0, "no recipes")
equal(#alchemy.reagents, 0, "no reagents")

-- Built once and kept until an event says otherwise, but every read is the caller's own table.
local second = API.Professions()
equal(second ~= list, true, "a second call is a fresh table")
equal(second[1].steps[1].text, list[1].steps[1].text, "with the same answers")
second[1].name, second[1].steps[1].text = "changed by the caller", "changed by the caller"
equal(API.Professions()[1].name, "Tailoring", "a caller's change never reaches the addon's cache")
equal(API.Professions()[1].steps[1].text ~= "changed by the caller", true, "nor its steps")
c.Fire("ITEM_DATA_LOAD_RESULT")
equal(#API.Professions(), 4, "item data with no name waiting keeps the answers")
c.Fire("BAG_UPDATE_DELAYED")
equal(API.Professions()[1].name, "Tailoring", "a bag update answers the same list")
ns.Changed("fees")
equal(API.Professions()[1].name, "Tailoring", "dropped plans answer again")

-- Steps route by travel time to the NPC they name.
local estimates, routed = 0, nil
c.G.ShortestPathForever = {
	API = {
		version = 1,
		Estimate = function()
			estimates = estimates + 1
			return 60
		end,
		Navigate = function(_, _, _, _, title)
			routed = title
			return true
		end,
	},
}
equal(API.Navigate(165, 1), true, "the vendor step routes")
equal(routed, "Gina", "to the vendor")
equal(estimates, 1, "picked by travel")
equal(API.Navigate(165, 3), true, "the training step routes")
equal(routed, "Telonis", "to the trainer")
equal(API.Navigate(165, 2), false, "a craft doesn't route")
equal(API.Navigate(999, 1), false, "an unknown profession doesn't route")

equal(API.OpenRecipes(165), true, "opens a profession")
equal(c.opened[1], 8165, "by the ID the client reported")
equal(API.OpenRecipes(999), false, "not one the character lacks")
-- A refused request is asked once more only by another ID.
local OpenTradeSkill = c.G.C_TradeSkillUI.OpenTradeSkill
c.G.C_TradeSkillUI.OpenTradeSkill = function(id)
	OpenTradeSkill(id)
	return false
end
c.opened = {}
equal(API.OpenRecipes(165), false, "a profession the client will not open")
equal(table.concat(c.opened, " "), "8165 165", "is asked by its own ID, then the skill line")
c.professions[1].id = 165
c.opened = {}
API.OpenRecipes(165)
equal(table.concat(c.opened, " "), "165", "and once when the client reports the skill line itself")
c.professions[1].id = 8165
c.G.C_TradeSkillUI.OpenTradeSkill = OpenTradeSkill

-- The shopping list's trip button, started through its own function.
local shoppingTrip = ns.ShoppingTrip
local tripArgument
ns.ShoppingTrip = function(skillLineID)
	tripArgument = skillLineID
	return true
end
equal(API.ShoppingTrip(165), true, "the API starts the shopping trip")
equal(tripArgument, 165, "for the profession it was given")
ns.ShoppingTrip = shoppingTrip

-- Stats exposes only this character's recipes-observed record.
local stats = API.Stats()
local startValue = stats[1].value
equal(#stats, 1, "one local activity row")
equal(stats[1].addon, "SkillUpForever", "this addon")
equal(stats[1].metric, "recipes_observed_learned", "the observed-recipes metric")
equal(stats[1].subject, "all", "for the whole record")
if startValue == 0 then
	equal(stats[1].eventUnix, 0, "no event time before the first observation")
end
ns.Stats.Observe(987654)
local observed = API.Stats()
equal(observed[1].value, startValue + 1, "a new observation raises this character's total")
equal(type(observed[1].eventUnix), "number", "with the observation's time")
observed[1].value = -1
equal(API.Stats()[1].value, startValue + 1, "a caller's change never reaches the record")

-- Tracking changes the order, so the next call rebuilds.
ns.SetTracked(165, true)
equal(API.Professions()[2].name, "Leatherworking", "tracking a profession rebuilds the list and moves it ahead")

-- What the client reports reaches the list through every file between: a merchant seen to sell thread for
-- less re-prices the purchase.
local function Leatherworking()
	for _, entry in ipairs(API.Professions()) do
		if entry.skillLineID == 165 then
			return entry
		end
	end
end
c.merchant = { { itemID = THREAD, price = 250, stackCount = 5 } }
c.Fire("MERCHANT_SHOW")
equal(Leatherworking().steps[1].cost, 400, "a cheaper vendor price reaches the buy step")
equal(Leatherworking().steps[1].detail, "Gina, Darkshire · 400c", "and its text")
c.merchant = nil
c.Fire("MERCHANT_CLOSED")
-- Thread in the bags: nothing to buy, so the craft leads.
c.bags[THREAD] = 8
c.Fire("BAG_UPDATE_DELAYED")
equal(Leatherworking().steps[1].kind, "craft", "reagents arriving in the bags drop the purchase")
-- Hillman's stays on the route even with its sale counted for nothing: the gloves' 0.8 chance needs two
-- crafts a point, which costs more than Hillman's certain one.
equal(#Leatherworking().recipes, 2, "Hillman's is on the route while its sale counts")
c.SetSetting("craftValue_choice", 1)
equal(ns.db.craftValue, "none", "the options panel's slider writes the saved choice")
equal(#Leatherworking().recipes, 2, "a setting changed in the options panel re-plans the public list")
equal(Leatherworking().recipes[1].spellID, GLOVES, "with the gloves first")
equal(Leatherworking().recipes[2].spellID, HILLMANS, "and Hillman's carrying the rest")

-- Past the 75 cap Tailoring needs its next rank, which here comes from a book: bought at a vendor and read.
ns.db.routeTargets[197] = 80
ns.Changed("target")
local function Tailoring()
	for _, entry in ipairs(API.Professions()) do
		if entry.skillLineID == 197 then
			return entry
		end
	end
end
-- The first ask starts reading who sells the book; it is named once read.
Tailoring()
c.Advance(0)
local book
for _, step in ipairs(Tailoring().steps) do
	if step.itemID == BOOK then
		book = step
	end
end
equal(book and book.kind, "buy", "a rank from a book is a purchase")
equal(book and book.text, "Buy and read the Journeyman book at 70", "read at the skill it asks")
equal(book and book.detail, "Gina, Darkshire · 500c", "from the nearest vendor, at the book's price")
equal(book and book.cost, 500, "costing the book")
equal(book and book.nav, true, "the vendor can be routed to")
-- Where the route page and the tracker send you for the rank: the book's vendor, until the book is in the bags.
local tailoringRoute = ns.RouteProfessions()[197]
local bookRank
for _, step in ipairs(ns.PlanRoute(tailoringRoute).steps) do
	bookRank = bookRank or (step.rank and step.rank.book and step.rank)
end
equal(bookRank and ns.NearestForRank(tailoringRoute, bookRank), GINA, "a book not yet bought is got at its vendor")
-- Bought and not yet read: nothing to buy, only the reading.
c.bags[BOOK] = 1
c.Fire("BAG_UPDATE_DELAYED")
equal(ns.NearestForRank(tailoringRoute, bookRank), nil, "a book in the bags is read where you stand")
book = nil
for _, step in ipairs(Tailoring().steps) do
	if step.itemID == BOOK then
		book = step
	end
end
equal(book and book.kind, "train", "a book in the bags is not bought again")
equal(book and book.text, "Read the Journeyman book at 70", "only read")
equal(book and book.cost, nil, "at no cost")
equal(book and book.nav, false, "with nowhere to go")
-- The book's name arriving rebuilds the list.
c.items[BOOK] = { name = "Journeyman's Handbook" }
c.Fire("ITEM_DATA_LOAD_RESULT")
book = nil
for _, step in ipairs(Tailoring().steps) do
	if step.itemID == BOOK then
		book = step
	end
end
equal(book and book.text, "Read Journeyman's Handbook at 70", "named once the item loads")

-- Past Leatherworking's 150 cap, here no trainer or book teaches Expert: a quest does, one for each side.
ns.RankQuests = { [165] = { { 225, 7002, 142, 0, "A" }, { 225, 7001, 142, 0, "H" } } }
ns.db.routeTargets[165] = 170
ns.Changed("target")
local quest
for _, entry in ipairs(API.Professions()) do
	for _, step in ipairs(entry.skillLineID == 165 and entry.steps or {}) do
		quest = quest or (step.questID and step)
	end
end
equal(quest and quest.questID, 7002, "a rank from a quest names your side's quest")
equal(quest and quest.kind, "train", "as a train step")
equal(quest and quest.text, "Complete Leather Lesson at 142", "by QuestieDB's title")
equal(quest and quest.detail, "Telonis, Darnassus", "at its nearest giver")
equal(quest and quest.cost, nil, "for no fee")
equal(quest and quest.nav, true, "who can be routed to")
local lwRoute = ns.RouteProfessions()[165]
local questRank
for _, step in ipairs(ns.PlanRoute(lwRoute).steps) do
	questRank = questRank or (step.rank and step.rank.quest and step.rank)
end
local giver, label = ns.NearestForRank(lwRoute, questRank)
equal(giver, TELONIS, "the route page and tracker send you to the quest's giver")
equal(label, "Quest giver", "labelled as such")

-- A recipe no trainer teaches, sold as a scroll at a vendor (#358): the training step buys that scroll, and
-- navigation names its vendor, never a trainer.
local COOKING, SCROLL, SCROLL_RECIPE, SCROLL_VENDOR = 185, 6329, 7754, 9001
local scrollClient = Client.load({
	auctionator = false,
	saved = { routeTargets = { [COOKING] = 60 } },
	data = {
		Thresholds = { [SCROLL_RECIPE] = { 50, 90, 110, 130 } },
		RecipeData = {
			[SCROLL_RECIPE] = {
				skillLine = COOKING,
				reagents = { { itemID = 2678, quantity = 1 }, { itemID = 6317, quantity = 1 } },
				output = { itemID = 6316, quantity = 1 },
			},
		},
		RecipeScrolls = { [SCROLL_RECIPE] = { SCROLL, 50 } },
		TrainerFees = {},
		TrainerRanks = {},
		RankBooks = {},
		ProfessionTrainers = {},
		RankQuests = {},
		VendorPrices = { [SCROLL] = 500, [2678] = 10, [6317] = 3 },
		ItemSellPrices = {},
		GatheredBy = {},
		ScrollDrops = {},
		WorldDrops = {},
	},
	questie = {
		items = { [SCROLL] = { class = 9, vendors = { SCROLL_VENDOR }, teaches = SCROLL_RECIPE } },
		npcs = {
			[SCROLL_VENDOR] = { name = "Fish Vendor", spawns = { [10] = { { 50, 50 } } }, side = "AH" },
		},
		areas = { [10] = 10 },
	},
})
local scrollNs = scrollClient.ns
scrollClient.level = 60
scrollClient.player.faction = "Alliance"
scrollClient.maps = { [0] = { mapID = 10, name = "Darkshire" } }
scrollClient.items[SCROLL] = { name = "Recipe: Loch Frenzy Delight" }
scrollClient.items[6316] = { name = "Loch Frenzy Delight", sell = 0 }
scrollClient.items[2678] = { name = "Mild Spices" }
scrollClient.items[6317] = { name = "Loch Frenzy" }
scrollClient.professions = { { name = "Cooking", icon = 1, rank = 50, max = 75, id = COOKING } }
scrollNs.db.routeTargets[COOKING] = 60
scrollNs.Catalogue.EnsureProfession(COOKING)
scrollClient.Advance(0)
local scrollAPI = scrollClient.G.SkillUpForever.API
local trainerAsked = false
local nearestTrainer = scrollNs.NearestTrainer
scrollNs.NearestTrainer = function(...)
	trainerAsked = true
	return nearestTrainer(...)
end
local scrollEntry
for _, entry in ipairs(scrollAPI.Professions()) do
	if entry.skillLineID == COOKING then
		scrollEntry = entry
	end
end
local scrollPlan = scrollNs.PlanRoute(scrollNs.RouteProfessions()[COOKING])
equal(scrollPlan.training[1] and scrollPlan.training[1].scroll, SCROLL, "the plan carries the scroll item")
local scrollStep = scrollEntry and scrollEntry.steps[1]
equal(scrollStep and scrollStep.text, "Buy Recipe: Loch Frenzy Delight", "the API step buys the scroll")
equal(scrollStep and scrollStep.itemID, SCROLL, "with the scroll as its item")
equal(scrollStep and scrollStep.spellID, SCROLL_RECIPE, "and the recipe it teaches")
equal(scrollStep and scrollStep.cost, 500, "at the scroll's price")
equal(scrollStep and scrollStep.nav, true, "the vendor can be routed to")
equal(trainerAsked, false, "a scroll step never asks for a trainer")
scrollClient.G.ShortestPathForever = {
	API = {
		version = 1,
		Estimate = function()
			return 60
		end,
		Navigate = function(_, _, _, _, title)
			scrollClient.routed = title
			return true
		end,
	},
}
equal(scrollAPI.Navigate(COOKING, 1), true, "the scroll step routes")
equal(scrollClient.routed, "Fish Vendor", "to its vendor, not a trainer")
equal(trainerAsked, false, "even when it routes")

-- A core older than the kit's Publish still loads the addon: with the kit at minor 1 the guard hands it nothing.
local kit = c.G.ForeverCore.APIKit
local kitMinor, publishCalls = kit.minor, 0
kit.minor = 1
kit.Publish = function()
	publishCalls = publishCalls + 1
end
local chunk = assert(loadfile("Core/API.lua"))
setfenv(chunk, c.G)
equal(pcall(chunk, "SkillUpForever", c.ns), true, "the addon loads on a kit from before Publish")
equal(publishCalls, 0, "and a minor 1 kit is handed nothing")
kit.minor = kitMinor

Client.report("api_spec")
