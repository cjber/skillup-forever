-- Run from the repository root: luajit tests/plan_spec.lua
-- The levelling plan over the bundled First Aid data, on the shared stub client: Linen Bandage (3275), and Heavy
-- Linen Bandage (3276), which a trainer teaches at 40 for 1s.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local LINEN, HEAVY, WOOL, CLOTH = 3275, 3276, 3277, 2589
local HEAVY_WOOL, UNDER_WRAPS = 3278, 16084
local MAGEWEAVE, TRIAGE_A, TRIAGE_H = 10840, 6624, 6622
local WOOL_CLOTH, MAGEWEAVE_CLOTH = 2592, 4338
-- A cloth costs 2c at a merchant, and the client sells each bandage for 1c less than its cloth: every craft
-- nets 1c while its cloth is priced, so a step's money counts the sale on every craft (#466). Only linen
-- cloth is priced until a case prices another.
local SELLS = { [1251] = 1, [2581] = 3, [3530] = 1, [3531] = 3, [8544] = 1, [8545] = 3 }

local c = Client.load({
	saved = { vendor = { [CLOTH] = 2 } },
	data = { LootedFrom = {} },
})
local ns, G = c.ns, c.G
c.level, c.craftable = 20, 99
c.professions = {
	{ name = "First Aid", id = 129, rank = 1, max = 75 },
	{ name = "Herbalism", id = 182, rank = 1, max = 75 },
}
c.spells[LINEN], c.spells[HEAVY] = "Linen Bandage", "Heavy Linen Bandage"
for itemID, sell in pairs(SELLS) do
	c.items[itemID] = { sell = sell }
end
-- Auctionator is installed only where a case says so.
local auctionator = G.Auctionator
G.Auctionator = nil
-- The profession on show in the Professions window.
local open = { professionName = "First Aid", professionID = 129 }
G.Professions = {
	GetProfessionInfo = function()
		return open
	end,
}

-- A recipe the character knows, or no longer knows.
local function Know(recipeID, known)
	c.known[recipeID] = known or nil
end
-- A cloth at a merchant, at Auctionator's last scan, or priced nowhere.
local function ClothPrice(itemID, vendor, auction)
	ns.db.vendor[itemID], c.auction[itemID] = vendor, auction
	ns.Changed("prices")
end

local function FirstAid(base, modifier, max)
	modifier, max = modifier or 0, max or 75
	return {
		skillLine = 129,
		name = "First Aid",
		base = base,
		modifier = modifier,
		skill = base + modifier,
		max = max,
		capped = base >= max,
	}
end
-- A fresh plan for a new setup: the cache is keyed on skill and target, not on what is known.
local function Plan(profession, target)
	ns.db.routeTargets[129] = target
	ns.Changed("target")
	return ns.PlanRoute(profession)
end
local function Kinds(plan)
	local kinds = {}
	for index, step in ipairs(plan.steps) do
		kinds[index] = step.rank and "rank" or step.training and "train" or "craft"
	end
	return table.concat(kinds, " ")
end

equal(ns.RouteProfessions()[129].name, "First Aid", "a crafting profession can be planned")
equal(ns.RouteProfessions()[182], nil, "a gathering one can't")
equal(ns.RankName(150), "Journeyman", "the 150 cap is Journeyman")
equal(ns.RankName(60), nil, "a cap no rank ends at has no name")

-- The collect mode is part of the plan cache key: the same skill and target planned under the other mode is a
-- different route, so it is planned again rather than served from the cache (#190).
local character = ns.CharacterKey()
ns.db.collectModes[character] = "gather"
local gathered = Plan(FirstAid(1), 100)
equal(ns.PlanRoute(gathered.profession), gathered, "the same skill, target and mode reuses the cached plan")
ns.db.collectModes[character] = "auction"
equal(ns.PlanRoute(gathered.profession) ~= gathered, true, "turning buying on plans again")
ns.db.collectModes[character] = "gather"

-- #189: a profession keeps its last few targets' plans, so returning to one doesn't plan it again.
local builds = 0
local planWithTraining = ns.Model.PlanWithTraining
ns.Model.PlanWithTraining = function(...)
	builds = builds + 1
	return planWithTraining(...)
end
ns.Changed("target")
local baseline = builds
ns.db.routeTargets[129] = 80
local plan80 = ns.PlanRoute(FirstAid(1))
equal(builds - baseline, 1, "the first plan for a target is built")
ns.db.routeTargets[129] = 100
ns.PlanRoute(FirstAid(1))
equal(builds - baseline, 2, "another target is planned")
ns.db.routeTargets[129] = 80
equal(ns.PlanRoute(FirstAid(1)), plan80, "returning to a planned target reuses its plan")
equal(builds - baseline, 2, "without planning it again")

-- Nine distinct targets fill the per-profession cache past its eight, evicting the oldest.
ns.Changed("target")
baseline = builds
local planned = {}
for target = 2, 10 do
	ns.db.routeTargets[129] = target
	planned[target] = ns.PlanRoute(FirstAid(1))
end
equal(builds - baseline, 9, "nine distinct targets are planned")
ns.db.routeTargets[129] = 9
equal(ns.PlanRoute(FirstAid(1)), planned[9], "the newest target is still cached")
equal(builds - baseline, 9, "without planning again")
ns.db.routeTargets[129] = 2
ns.PlanRoute(FirstAid(1))
equal(builds - baseline, 10, "the ninth target pushed the oldest out of the cache")

-- The plans stale signal clears the cache, so the next ask plans afresh.
ns.Changed("target")
ns.db.routeTargets[129] = 9
local beforeStale = ns.PlanRoute(FirstAid(1))
local mark = builds
ns.Changed("target")
equal(ns.PlanRoute(FirstAid(1)) ~= beforeStale, true, "the plans stale signal clears the cache")
equal(builds - mark, 1, "so the target is planned again")
ns.Model.PlanWithTraining = planWithTraining

-- #189: committing the target the box already holds changes nothing.
ns.db.routeTargets[129] = 100
equal(ns.TargetChanged(129, 100), false, "the stored target has not changed")
equal(ns.TargetChanged(129, 110), true, "a new target has")
equal(ns.db.routeTargets[129], 100, "and asking never writes it")

-- Where the known recipes run out: a trainer was seen to want 200 for Heavy Linen Bandage, past the target.
Know(LINEN, true)
ns.db.trainer[129] = { [HEAVY] = { 100, 200 } }
local short = Plan(FirstAid(1), 100)
equal(short.target, 100, "the saved target")
equal(short.reached, 60, "Linen Bandage alone stops at 60")
equal(short.stopReason, "no_recipe", "for want of a recipe")
equal(#short.ranks, 0, "a rank past where the route stops is not trained")
equal(Kinds(short), "craft", "one step")
equal(short.crafts[1].color, "orange", "coloured where the craft starts")
equal(ns.RouteBlocked(short), nil, "a plan with crafts isn't blocked")
equal(ns.PlanRoute(FirstAid(1)), short, "the same skill and target is the same plan")
equal(Plan(FirstAid(1), 100) ~= short, true, "an invalidated plan is planned again")
equal(Plan(FirstAid(1), 0).target, 26, "no target, or one already reached, is 25 points on")
equal(Plan(FirstAid(60), 300).target, 300, "a target goes up to the last rank a trainer, book or quest teaches")
ns.db.trainer[129] = nil

-- A rank is trained between the crafts either side of the skill it needs.
Know(HEAVY, true)
local ranked = Plan(FirstAid(40), 90)
equal(Kinds(ranked), "craft rank craft", "crafts, the rank, then crafts on")
equal(ranked.steps[1].craft.to, 50, "crafts up to the skill Journeyman needs")
equal(ranked.steps[2].rank.name, "Journeyman", "then trains Journeyman")
equal(ranked.steps[2].rank.reqSkill, 50, "at 50")
equal(ranked.steps[3].craft.from, 50, "then crafts on past the cap")
equal(ranked.steps[3].craft.to, 90, "to the target")
equal(ranked.reached, 90, "which it reaches")
equal(ranked.cost, 500 + 102, "the rank's fee and every craft's net sale are in the cost")
equal(#ranked.bands, 2, "the route spans Apprentice and Journeyman")
equal(ranked.steps[1].band.name, "Apprentice", "the first crafts are in Apprentice")
equal(ranked.steps[1].band.cap, 75, "which ends at 75")
equal(ranked.steps[2].band.name, "Journeyman", "the rank step opens Journeyman")
equal(ranked.steps[3].band.name, "Journeyman", "and the crafts after it stay there")
equal(ranked.bands[2].from, 75, "which starts at the Apprentice cap")
equal(ns.RankText(ranked.ranks[1]), "Train Journeyman at 50", "the rank as a line")
-- What a trainer was seen to charge for the rank replaces the bundled fee, in the step and the total.
ns.db.trainerRanks[129] = { [150] = 450 }
local charged = Plan(FirstAid(40), 90)
equal(charged.steps[2].rank.fee, 450, "a fee seen at a trainer wins")
equal(charged.cost, 450 + 102, "and is the one in the cost")
ns.db.trainerRanks[129] = nil
-- #466: a bandage that vendors above its cloth shows a gain for every craft in the step, not just the first.
c.items[1251].sell = 3
ns.Changed("prices")
local profitable = Plan(FirstAid(1), 10)
equal(profitable.crafts[1].recipeID, LINEN, "the route uses the profitable bandage")
equal(ns.StepCost(LINEN, profitable.crafts[1].crafts) < 0, true, "the step's money is a gain")
equal(profitable.cost < 0, true, "and the route total shows the gain")
c.items[1251].sell = 1
ns.Changed("prices")
ranked.ranks[1].level, c.level = 10, 5
equal(ns.RankText(ranked.ranks[1]), "Train Journeyman at 50 (level 10)", "with the level while below it")
c.level = 20

-- Issue #121: no trainer teaches Expert First Aid; the book Expert First Aid - Under Wraps does, at 125.
Know(HEAVY_WOOL, true)
ClothPrice(WOOL_CLOTH, 2)
local expert = Plan(FirstAid(120, 0, 150), 170)
equal(Kinds(expert), "craft rank craft", "crafts, the book, then crafts on")
equal(expert.steps[1].craft.to, 125, "crafts up to the skill the book asks")
local book = expert.steps[2].rank
equal(book.name, "Expert", "the rank is Expert")
equal(book.book, UNDER_WRAPS, "taught by the book")
equal(book.cap, 225, "raising the cap to 225")
equal(book.reqSkill, 125, "read at 125")
equal(book.fee, 10000, "for the book's list price")
equal(expert.reached, 170, "the route goes on past 150")
c.requested = {}
equal(ns.RankText(book), "Buy and read the Expert book at 125", "named by its rank until the item loads")
equal(c.requested[UNDER_WRAPS], true, "and the item is asked for")
c.items[UNDER_WRAPS] = { name = "Expert First Aid - Under Wraps" }
equal(ns.RankText(book), "Buy and read Expert First Aid - Under Wraps at 125", "then by its name")
ns.db.vendor[UNDER_WRAPS] = 9000
equal(Plan(FirstAid(120, 0, 150), 170).steps[2].rank.fee, 9000, "a merchant's price wins")
ns.db.vendor[UNDER_WRAPS] = nil
local capped = Plan(FirstAid(150, 0, 150), 170)
equal(Kinds(capped), "rank craft", "at the cap, the book comes first")
equal(
	ns.NextCraft(capped).reason,
	"Read Expert First Aid - Under Wraps first: you're at your cap.",
	"and is read before crafting"
)
equal(capped.cost >= 10000, true, "the route pays for a book it still has to buy")
c.bags[UNDER_WRAPS] = 1
equal(ns.RankText(book), "Read Expert First Aid - Under Wraps at 125", "a book in the bags only needs reading")
equal(ns.RankHeld(book), true, "and is held")
c.bags[UNDER_WRAPS] = nil
-- #567: the route's money split: the reagents still to buy after the bags, the fees still to pay, what the
-- crafts sell for, and whether a needed reagent has no price at all.
Know(LINEN, true)
ClothPrice(CLOTH, 2)
c.items[1251].sell = 1
c.bags[CLOTH] = 1
local moneyRank = { name = "Journeyman", cap = 150, fee = 500, reqSkill = 50, level = 0 }
local moneyPlan = {
	crafts = { { recipeID = LINEN, crafts = 5 } },
	training = { { fee = 100 } },
	ranks = { moneyRank },
}
local money = ns.PlanMoney(moneyPlan)
equal(money.buy, 8, "the reagents still to buy, less the one in the bags")
equal(money.fees, 600, "the training and rank fees")
equal(money.sells, 5, "what the five crafts sell for")
equal(money.unknown, 0, "every reagent has a price")
c.bags[UNDER_WRAPS], moneyRank.book, moneyRank.fee = 1, UNDER_WRAPS, 10000
money = ns.PlanMoney(moneyPlan)
equal(money.fees, 100, "a book already in the bags is not bought again")
c.bags[UNDER_WRAPS], moneyRank.book, moneyRank.fee = nil, nil, 500
ClothPrice(CLOTH, nil)
c.bags[CLOTH] = nil
money = ns.PlanMoney(moneyPlan)
equal(money.unknown, 1, "an unpriced reagent is counted, not dropped from a lower total")
equal(money.buy, 0, "so the buy side says nothing it cannot price")
-- Artisan First Aid comes from Triage, one quest a side (classic-db quest_template, #121).
Know(MAGEWEAVE, true)
ClothPrice(MAGEWEAVE_CLOTH, 2)
local artisan = Plan(FirstAid(220, 0, 225), 250)
equal(Kinds(artisan), "craft rank craft", "crafts, the quest, then crafts on")
local quest = artisan.steps[2].rank
equal(quest.name, "Artisan", "the rank is Artisan")
equal(quest.quest, TRIAGE_A, "taught by the Alliance's Triage")
equal(quest.cap, 300, "raising the cap to 300")
equal(quest.reqSkill, 225, "at 225")
equal(quest.level, 35, "from level 35")
equal(quest.fee, 0, "for no fee")
equal(artisan.reached, 250, "the route goes on past 225")
c.level = 40
equal(ns.RankText(quest), "Complete the Artisan quest at 225", "named by its rank without Questie")
-- QuestieDB loads, and its title for Triage is read.
G.LibQuestieDB = Client.QuestieDB({ quests = { [TRIAGE_A] = { name = "Triage" } } })
c.Fire("ADDON_LOADED", "QuestieDB")
equal(ns.RankText(quest), "Complete Triage at 225", "then by QuestieDB's title")
c.level = 20
equal(ns.RankText(quest), "Complete Triage at 225 (level 35)", "with the level while below it")
equal(
	ns.NextCraft(Plan(FirstAid(225, 0, 225), 250)).reason,
	"Complete Triage first: you're at your cap.",
	"at the cap, the quest comes before crafting"
)
c.player.faction = "Horde"
equal(Plan(FirstAid(220, 0, 225), 250).steps[2].rank.quest, TRIAGE_H, "the Horde take their own Triage")
c.player.faction = "Alliance"
Know(MAGEWEAVE, false)
ClothPrice(MAGEWEAVE_CLOTH, nil)
Know(HEAVY_WOOL, false)
ClothPrice(WOOL_CLOTH, nil)
c.items[UNDER_WRAPS] = nil

-- Every reagent the crafts use, totalled, in the bucket its price puts it in.
local cloth = ranked.crafts[1].crafts * 2 + ranked.crafts[2].crafts * 2
ClothPrice(CLOTH, nil)
local reagents = ns.RouteReagents(ranked)
equal(#reagents, 1, "one reagent")
equal(reagents[1].itemID, CLOTH, "linen cloth")
equal(reagents[1].need, cloth, "two a craft, for both halves of the split")
equal(reagents[1].source, "unknown", "no price, no source")
G.Auctionator = auctionator
ClothPrice(CLOTH, nil, 2)
equal(ns.RouteReagents(ranked)[1].source, "auction", "an auction price is the auction bucket")
G.Auctionator = nil
ClothPrice(CLOTH, 2)

-- A recipe to train is trained just before its first craft, with what the trainer wants for it.
Know(HEAVY, false)
local trained = Plan(FirstAid(40), 75)
equal(Kinds(trained), "train craft", "the training, then its craft")
local training = trained.training[1]
equal(trained.steps[1].training, training, "the step is the plan's training")
equal(training.recipeID, HEAVY, "Heavy Linen Bandage")
equal(training.fee, 100, "its fee")
equal(training.reqSkill, 40, "the skill the trainer wants, with no walk needed first")
equal(training.cap, 41, "from a trainer who teaches past it")
equal(training.usedAt, 40, "first crafted at 40")
equal(trained.cost, 100 + 49, "the fee and every craft's net sale are in the cost")
ns.db.trainer[129] = { [HEAVY] = { 80, 50 } }
local quoted = Plan(FirstAid(40), 75)
equal(quoted.training[1].fee, 80, "a trainer seen to charge less wins")
equal(quoted.training[1].reqSkill, 50, "and so does the skill it wanted")
equal(quoted.training[1].usedAt, 50, "nothing is crafted before it can be taught")
ns.db.trainer[129] = nil
-- Not this recipe: a skipped recipe is never trained, and the route carries on with what is left.
ns.SetSkipped(HEAVY, true)
local unskipped = Plan(FirstAid(40), 75)
equal(#unskipped.training, 0, "a skipped recipe is not trained")
equal(unskipped.crafts[1].recipeID, LINEN, "the route crafts what is left")
ns.SetSkipped(LINEN, true)
local nothing = Plan(FirstAid(40), 75)
equal(#nothing.crafts, 0, "skipping every recipe leaves nothing to craft")
equal(ns.RouteBlocked(nothing), "Nothing you know skills up past 40.", "the usual no-route state")
ns.SetSkipped(HEAVY, false)
ns.SetSkipped(LINEN, false)

-- The plan is in base skill whatever the racial bonus; thresholds are met with the bonus.
local bonus = Plan(FirstAid(40, 15), 75)
equal(bonus.crafts[1].from, 40, "crafts start at the base skill")
equal(bonus.crafts[1].recipeID, HEAVY, "with the recipe the bonus already makes the better one")
equal(bonus.crafts[#bonus.crafts].to, 75, "and end at the base target")
equal(bonus.reached, 75, "reached in base skill")
equal(bonus.training[1].usedAt, 40, "training is placed in base skill")
equal(bonus.training[1].reqSkill, 40, "at the base skill the trainer wants")
equal(bonus.crafts[1].color, "yellow", "55 with the bonus is yellow")
Know(HEAVY, true)
local bonusRank = Plan(FirstAid(40, 15), 90)
equal(Kinds(bonusRank), "craft rank craft", "the rank still splits the crafts")
equal(bonusRank.steps[1].craft.to, 50, "at the base skill it needs")
Know(LINEN, false)
equal(Plan(FirstAid(40, 15), 150).reached, 85, "Heavy Linen Bandage goes grey at 100 with the bonus")
Know(LINEN, true)

-- The difficulty bands a recipe still has from where it can be learned, in this client or `on` another.
local function Bands(recipeID, on)
	local parts = {}
	for index, band in ipairs((on or ns).RecipeBands(FirstAid(40), recipeID)) do
		parts[index] = band.color .. " " .. band.from
	end
	return table.concat(parts, ", ")
end
equal(Bands(LINEN), "orange 1, yellow 30, green 45, grey 60", "every band from the data")
equal(Bands(HEAVY), "orange 40, yellow 50, green 75, grey 100", "from where the trainer teaches it")
ns.db.trainer[129] = { [HEAVY] = { 80, 60 } }
equal(Bands(HEAVY), "yellow 60, green 75, grey 100", "a band over before it can be learned is dropped")
ns.db.trainer[129] = nil
-- A client whose AtlasLoot names a scroll for Linen Bandage, asking `skill` (nil when it doesn't say), with First
-- Aid's scroll sources read: Linen Bandage's bands there.
local function ScrollBands(skill)
	local scroll = Client.load({ atlasLoot = { recipes = { [900001] = { 129, skill, LINEN } } } })
	scroll.ns.Catalogue.EnsureProfession(129)
	scroll.Advance(0)
	return Bands(LINEN, scroll.ns)
end
equal(ScrollBands(35), "yellow 35, green 45, grey 60", "a scroll's required skill counts the same")
equal(ScrollBands(nil), "orange 1, yellow 30, green 45, grey 60", "a scroll of unknown skill starts with the data")
equal(#ns.RecipeBands(FirstAid(40), 1), 0, "no thresholds, no bands")

-- The skill where a recipe can be learned, the number the crafted gear view shows for its recipe:
-- a trainer's own requirement, not the data's placeholder first threshold.
-- classic-db's 110 and 120 moved down as far as Forever moved each recipe's range from Classic Era's.
equal(ns.LearnSkill(FirstAid(40), 3848), 85, "Double-stitched Woolen Shoulders is taught at 85")
equal(ns.LearnSkill(FirstAid(40), 2166), 95, "Toughened Leather Armor is taught at 95")
equal(ns.LearnSkill(FirstAid(40), 19819), 290, "a recipe with no trainer takes its pattern's skill")
-- A Forever-added recipe with no trainer: the pattern that teaches it carries the real requirement,
-- where the client's own orange sits at its placeholder 1.
local leatherworking = { skillLine = 165, name = "Leatherworking", skill = 0, modifier = 0 }
equal(ns.LearnSkill(leatherworking, 1255109), 100, "Brawler's Leather Hood's pattern asks 100")
equal(ns.LearnSkill(leatherworking, 1255105), 100, "Stormrider's Leather Hood's pattern asks 100")
equal(ns.LearnSkill(leatherworking, 12719), 0, "a recipe with no known source has no skill")
-- A deprecated pattern teaches nobody: Enchant Cloak - Minor Protection's only item is the old "Formula:
-- Imbue Cloak - Protection" (asks 90), and its trainer teaches it at 70. Its orange is no higher than that.
equal(ns.Thresholds[7771][1] <= ns.TrainerFees[7771][2], true, "Minor Protection is not orange above its trainer")
equal(ns.LearnSkill(FirstAid(40), 7771), 70, "Enchant Cloak - Minor Protection is taught at 70")
equal(ns.RecipeScrolls[7771], nil, "and no deprecated formula is offered as its scroll")
equal(ns.Model.Color(ns.Model.Get(7771), 75), "orange", "trained at 75 it is orange, as the game shows it")
local cloak = ns.RecipeBands(FirstAid(40), 7771)
equal(cloak[1].color .. " " .. cloak[1].from, "orange 70", "its first band starts where it is taught")
for recipeID, taught in pairs(ns.TrainerFees) do
	local t, scroll = ns.Thresholds[recipeID], ns.RecipeScrolls[recipeID]
	if t and scroll and taught[2] >= 1 and t[1] == scroll[2] then
		equal(t[1] <= taught[2], true, "recipe " .. recipeID .. ": a pattern's orange is not above its trainer")
	end
end

-- It draws no band below where it is taught, so the orange band starts at the pattern's skill.
local hood = ns.RecipeBands(leatherworking, 1255109)
equal(hood[1].color .. " " .. hood[1].from, "orange 100", "the hood's first band starts at the pattern's skill")

-- A recipe's range starts where it can first be learned, which is what the tooltip, its bar and the rows
-- show: the client leaves most recipe starts at its placeholder 1 (#519).
equal(ns.Thresholds[3766][1], 1, "Dark Leather Belt's bundled start is the client's placeholder")
equal(ns.LearnSkill(leatherworking, 3766), 100, "its trainer asks 100")
local beltCtx = { skillLine = 165, name = "Leatherworking", skill = 113, modifier = 0 }
local belt = ns.RangeThresholds(beltCtx, 3766)
equal(belt[1], 100, "so its range starts at 100")
equal(belt[2], ns.Thresholds[3766][2], "the yellow above it is unchanged")
local beltRow = ns.Describe({ recipeID = 3766, learned = true }, beltCtx)
equal(beltRow.thresholds[1], 100, "the tooltip line, its bar and the row start at 100")
equal(ns.RangeThresholds(leatherworking, 12719)[1], 1, "a recipe with no known source keeps the data's start")
equal(
	ns.RangeThresholds({ skillLine = 197, name = "Tailoring", skill = 1, modifier = 0 }, 2393)[1],
	1,
	"White Linen Shirt is learned at 1"
)

-- Why there is nothing to craft.
ClothPrice(CLOTH, nil)
local unpriced = Plan(FirstAid(40), 75)
equal(#unpriced.steps, 0, "nothing priced, nothing to walk")
equal(unpriced.unpriced, 2, "both known recipes are left out")
equal(
	ns.RouteBlocked(unpriced),
	"These reagents have no vendor price. Auction prices need Auctionator or TradeSkillMaster.",
	"unpriced without Auctionator"
)
G.Auctionator = auctionator
equal(
	ns.RouteBlocked(unpriced),
	"Auctionator hasn't seen these reagents yet: scan the auction house with it to price them.",
	"unpriced with it"
)
G.Auctionator = nil
local missing = ns.UnpricedReagents(unpriced)
equal(#missing, 1, "the reagent that keeps them out, once")
equal(missing[1], CLOTH, "linen cloth")
ClothPrice(CLOTH, 2)
equal(#ns.UnpricedReagents(unpriced), 0, "a priced reagent isn't listed")
ClothPrice(CLOTH, nil)
equal(Plan(FirstAid(70), 75).unpriced, 1, "a grey recipe keeps nothing out")
ClothPrice(CLOTH, 2)
Know(LINEN, false)
Know(HEAVY, false)
ns.db.trainer[129] = { [HEAVY] = { 100, 200 } }
equal(ns.RouteBlocked(Plan(FirstAid(40), 75)), "Nothing you know skills up past 40.", "nothing known")
equal(ns.RouteBlocked(Plan(FirstAid(40, 15), 75)), "Nothing you know skills up past 40.", "in base skill")
ns.db.trainer[129] = nil
Know(LINEN, true)
Know(HEAVY, true)
equal(
	ns.RouteBlocked(Plan(FirstAid(150, 0, 150), 200)),
	"At the 150 cap: no trainer teaches the next rank.",
	"capped with no rank to train"
)

-- The next craft: the first craft, as often as it needs and the client allows.
local five = Plan(FirstAid(10), 15)
c.craftable = 2
local craft = ns.NextCraft(five)
equal(craft.count, 2, "the client count limits the batch")
equal(craft.recipeID, LINEN, "an available batch can be crafted")
equal(craft.text, "Craft 2 of 5× Linen Bandage", "and says how many of the route's it can make")
c.craftable = 12
equal(ns.NextCraft(five).count, 5, "never crafts beyond the planned step")
c.craftable = 0
craft = ns.NextCraft(five)
equal(craft.recipeID, nil, "zero available disables crafting")
equal(craft.text, "Craft 5× Linen Bandage", "the label still names the craft")
equal(craft.reason, "Missing reagents for this step.", "zero available explains the disabled button")
equal(craft.missing.itemID, CLOTH, "and names the reagent it is short of")
equal(craft.missing.count, 5, "with how many more it needs")
c.craftable = 99
open = { professionName = "Alchemy", professionID = 171 }
equal(ns.NextCraft(five).reason, "Open First Aid to craft from here.", "another profession is open")
open = { professionName = "First Aid", professionID = 129 }
-- Heavy Linen Bandage from 70 to the 75 cap: five points whose chance falls from 0.6 to 0.52.
equal(ns.NextCraft(Plan(FirstAid(70), 90)).count, 13, "crafts only to the cap until the rank is trained")
-- With a +15 bonus the same thresholds are met from 55 base, and the cap of 75 base is 90 with it.
equal(ns.NextCraft(Plan(FirstAid(55, 15), 90)).count, 67, "the cap is on base skill")
equal(
	ns.NextCraft(Plan(FirstAid(75), 90)).reason,
	"Train Journeyman first: you're at your cap.",
	"at the cap the rank comes first"
)
Know(HEAVY, false)
equal(ns.NextCraft(Plan(FirstAid(60), 75)).reason, "Train Heavy Linen Bandage first.", "an unlearned recipe")
Know(LINEN, false)
equal(ns.NextCraft(Plan(FirstAid(100), 110)).reason, "Nothing to craft on this route.", "an empty plan")
Know(LINEN, true)

-- The trainer window: which of its offers to train next.
ns.db.routeTargets[129] = 75
ClothPrice(WOOL_CLOTH, 2)
local offers = { { recipeID = WOOL, fee = 250 }, { recipeID = HEAVY, fee = 100 } }
equal(ns.BestTraining(FirstAid(40), {}, offers), HEAVY, "the offer that carries the route on")
equal(ns.BestTraining(FirstAid(40), {}, { offers[1] }), nil, "not one the target never uses")
equal(ns.BestTraining(FirstAid(75), {}, offers), nil, "nothing at the cap")
ns.SetSkipped(HEAVY, true)
equal(ns.BestTraining(FirstAid(40), {}, offers), nil, "not one the player skipped")
ns.SetSkipped(HEAVY, false)
Know(HEAVY, true)
equal(ns.BestTraining(FirstAid(40), {}, offers), nil, "not one already learned")
Know(HEAVY, false)
ns.db.routeTargets[129] = 150
Know(LINEN, false)
offers = { { recipeID = WOOL, fee = 250 } }
equal(ns.BestTraining(FirstAid(60, 0, 150), {}, offers), nil, "nothing gets to where Wool Bandage starts")
equal(
	ns.BestTraining(FirstAid(60, 0, 150), { [HEAVY] = true }, offers),
	WOOL,
	"a recipe the trainer shows as known does"
)

-- #357: two recipes that cost and skill up the same, the route takes the one whose product is a buff this
-- character can use. Below the buff's required level it loses the tie again, and the level in the plan cache
-- key makes that a fresh plan rather than the one already made.
local buffClient = Client.load({
	saved = { craftValue = "none" },
	data = {
		Thresholds = {
			[101] = { 1, 25, 50, 75 },
			[102] = { 1, 25, 50, 75 },
		},
		RecipeData = {
			[101] = { skillLine = 171, reagents = {}, output = { itemID = 1000, quantity = 1 } },
			[102] = { skillLine = 171, reagents = {}, output = { itemID = 1001, quantity = 1 } },
		},
		BuffItems = { [1001] = 500 },
		ItemGear = { [1001] = { 10 } },
		TrainerFees = {},
		TrainerRanks = {},
		ItemSellPrices = {},
		VendorPrices = {},
		GatheredBy = {},
		LootedFrom = {},
		ProfessionTrainers = {},
		ScrollDrops = {},
		WorldDrops = {},
	},
})
buffClient.level = 20
buffClient.professions = { { name = "Alchemy", id = 171, rank = 1, max = 75 } }
buffClient.known[101], buffClient.known[102] = true, true
buffClient.ns.db.routeTargets[171] = 10
local buffPlan = buffClient.ns.PlanRoute(buffClient.ns.RouteProfessions()[171])
equal(buffPlan.crafts[1].recipeID, 102, "the usable buff recipe wins the tie")
buffClient.level = 5
local lowPlan = buffClient.ns.PlanRoute(buffClient.ns.RouteProfessions()[171])
equal(lowPlan.crafts[1].recipeID, 101, "below its required level the buff recipe loses the tie")

-- #621: a route the player is shopping for stays put. Buying its reagents, or the scan that comes with the
-- purchase pricing another recipe lower, keeps the recipes and their order; only the player asking for a route
-- afresh, or a route a step of which can no longer be walked, plans a different one.
local shop = Client.load({
	saved = { routeTargets = { [171] = 25 }, craftValue = "none", vendor = { [1000] = 10, [1001] = 11 } },
	data = {
		Thresholds = { [101] = { 1, 5, 8, 12 }, [102] = { 1, 5, 8, 30 } },
		RecipeData = {
			[101] = { skillLine = 171, reagents = { { itemID = 1000, quantity = 1 } } },
			[102] = { skillLine = 171, reagents = { { itemID = 1001, quantity = 1 } } },
		},
		VendorPrices = {},
		TrainerFees = {},
		TrainerRanks = {},
		ItemSellPrices = {},
		GatheredBy = {},
		LootedFrom = {},
		ProfessionTrainers = {},
		ScrollDrops = {},
		WorldDrops = {},
	},
})
local shopNs = shop.ns
shop.professions = { { name = "Alchemy", id = 171, rank = 1, max = 75 } }
shop.known[101], shop.known[102] = true, true
shop.level = 20
---@return SkillUpPlan
local function ShopPlan()
	return shopNs.PlanRoute(shopNs.RouteProfessions()[171])
end
local function Crafts(plan)
	local ids = {}
	for index, step in ipairs(plan.crafts) do
		ids[index] = step.recipeID
	end
	return table.concat(ids, " ")
end
equal(Crafts(ShopPlan()), "101 102", "the cheaper recipe first, then the one that carries on")

-- The player buys the first step's reagent, and Auctionator's follow-up scan prices the other recipe's reagent
-- far lower: what they shopped for is what they keep.
shop.bags[1000] = 12
shop.Fire("BAG_UPDATE_DELAYED")
equal(Crafts(ShopPlan()), "101 102", "buying a route's reagent keeps its recipes")
shopNs.db.vendor[1000], shopNs.db.vendor[1001] = 100, 1
shopNs.Changed("prices")
equal(Crafts(ShopPlan()), "101 102", "and a scan that makes another recipe cheaper does not swap them")
equal(shopNs.StepCost(101, 1), 100, "while the money a step shows is today's price")

-- Asking for the route afresh, or a step it can no longer walk, does plan a different one.
shopNs.Changed("replan")
equal(Crafts(ShopPlan()), "102", "the page's Replan takes the cheaper recipe now")
shopNs.db.vendor[1000], shopNs.db.vendor[1001] = 10, 11
shopNs.Changed("prices")
shopNs.Changed("replan")
equal(Crafts(ShopPlan()), "101 102", "and its own recipes back again when they are cheaper")
shopNs.db.vendor[1000] = nil
shopNs.Changed("prices")
equal(Crafts(ShopPlan()), "101 102", "a reagent the bags still hold keeps the route when its price goes")
shop.bags[1000] = nil
shop.Fire("BAG_UPDATE_DELAYED")
equal(Crafts(ShopPlan()), "102", "a reagent gone from the bags with no price replans the route")
shop.bags[1000] = 12
shop.Fire("BAG_UPDATE_DELAYED")
equal(Crafts(ShopPlan()), "102", "a new route is followed, not swapped back")
shopNs.db.vendor[1000] = 10
shopNs.Changed("prices")
shopNs.Changed("replan")
equal(Crafts(ShopPlan()), "101 102", "the route's own reagent is priced and bought again")
shop.known[101] = nil
shop.Fire("NEW_RECIPE_LEARNED")
equal(Crafts(ShopPlan()), "102", "a recipe the route uses that is no longer known replans it")

-- A route that trains a recipe for its next step: buying that recipe's scroll and learning it is the step done,
-- so the route is planned again with the training gone and the crafts in the same order.
local learn = Client.load({
	saved = { routeTargets = { [171] = 25 }, craftValue = "none", vendor = { [1000] = 10, [1001] = 11 } },
	data = {
		Thresholds = { [101] = { 1, 5, 8, 12 }, [102] = { 1, 5, 8, 30 } },
		RecipeData = {
			[101] = { skillLine = 171, reagents = { { itemID = 1000, quantity = 1 } } },
			[102] = { skillLine = 171, reagents = { { itemID = 1001, quantity = 1 } } },
		},
		VendorPrices = {},
		TrainerFees = { [102] = { 100, 1 } },
		TrainerRanks = {},
		ItemSellPrices = {},
		GatheredBy = {},
		LootedFrom = {},
		ProfessionTrainers = {},
		ScrollDrops = {},
		WorldDrops = {},
	},
})
local learnNs = learn.ns
learn.professions = { { name = "Alchemy", id = 171, rank = 1, max = 75 } }
learn.known[101] = true
learn.level = 20
local taught = learnNs.PlanRoute(learnNs.RouteProfessions()[171])
equal(Crafts(taught), "101 102", "the route trains the recipe that carries it on")
equal(taught.training[1].recipeID, 102, "training it before its first craft")
learn.known[102] = true
learn.Fire("NEW_RECIPE_LEARNED")
local learnedPlan = learnNs.PlanRoute(learnNs.RouteProfessions()[171])
equal(#learnedPlan.training, 0, "learning the recipe drops the training step")
equal(Crafts(learnedPlan), "101 102", "and keeps the crafts and their order")

Client.report("plan_spec")
