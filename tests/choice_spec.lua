-- Run from the repository root: luajit tests/choice_spec.lua
-- The player's say over the route, with the whole addon loaded: gathered materials valued at what they would
-- sell for (the Prices setting), and "Not this recipe", which leaves a recipe out of every route on this
-- character until Show again. Two Blacksmithing recipes reach the same skill: one from ore this character
-- mines, one from flux a vendor sells.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local FROM_ORE, FROM_FLUX = 101, 102
local ORE, FLUX = 2770, 2880

local c = Client.load({
	boot = false,
	saved = { valueGathered = false, gatheredValueSeen = true, routeTargets = { [164] = 20 } },
	data = {
		Thresholds = {
			[FROM_ORE] = { 1, 30, 45, 60 },
			[FROM_FLUX] = { 1, 30, 45, 60 },
		},
		RecipeData = {
			[FROM_ORE] = { skillLine = 164, reagents = { { itemID = ORE, quantity = 2 } } },
			[FROM_FLUX] = { skillLine = 164, reagents = { { itemID = FLUX, quantity = 2 } } },
		},
		TrainerFees = {},
		TrainerRanks = {},
		ItemSellPrices = {},
		GatheredBy = { [ORE] = 186 },
		VendorPrices = { [FLUX] = 50 },
		ProfessionTrainers = {},
		ScrollDrops = {},
		WorldDrops = {},
	},
})
local ns = c.ns
c.spells = { [FROM_ORE] = "Copper Chain Belt", [FROM_FLUX] = "Rough Grinding Stone" }
c.known = { [FROM_ORE] = true, [FROM_FLUX] = true }
c.items = { [ORE] = { name = "Copper Ore", sell = 5 }, [FLUX] = { name = "Weak Flux" } }
c.auction = { [ORE] = 100 }
c.professions = {
	{ name = "Blacksmithing", icon = 136241, rank = 1, max = 75, id = 8164 },
	{ name = "Mining", icon = 136248, rank = 50, max = 75, id = 8186 },
}
c.Boot()
ns.SetCollectMode("gather")
-- The tracker section joins the shared column once the world loads, as core's own sections do.
c.EnterWorld()
c.Advance(0)

---@return SkillUpPlan
local function Plan()
	return ns.PlanRoute(ns.RouteProfessions()[164])
end

--[[ Gathered materials ]]

-- A free choice saved before the reset was the old default written into the saved table, not a choice: it becomes
-- the sale value once, and a choice made afterwards sticks (#807).
do
	local old = Client.load({ saved = { valueGathered = false } })
	equal(old.ns.db.valueGathered, true, "a free setting saved before the reset becomes the sale value")
	equal(old.ns.db.gatheredValueSeen, true, "and the reset is recorded")
	local chosen = Client.load({ saved = { valueGathered = false, gatheredValueSeen = true } })
	equal(chosen.ns.db.valueGathered, false, "a free choice made after the reset is kept")
	local fresh = Client.load({})
	equal(fresh.ns.db.valueGathered, true, "a new install values gathered materials")
end

--[[ Reagent tooltips start off ]]

-- Reagent lines on item tooltips were saved on for everyone without a choice: they go off once, a mode chosen
-- afterwards stays, and a new install starts with them off and every page on (#811).
do
	local old = Client.load({ saved = { reagentTooltip = "route" } })
	equal(old.ns.db.reagentTooltip, "off", "reagent tooltips saved on before the reset go off")
	equal(old.ns.db.reagentTooltipOffSeen, true, "and the reset is recorded")
	local chosen = Client.load({ saved = { reagentTooltip = "full", reagentTooltipOffSeen = true } })
	equal(chosen.ns.db.reagentTooltip, "full", "a mode chosen after the reset stays")
	local fresh = Client.load({})
	equal(fresh.ns.db.reagentTooltip, "off", "a new install starts without reagent tooltips")
	equal(fresh.ns.db.showBuffsTab, true, "and keeps the Buffs page")
	equal(fresh.ns.db.gatherTooltip, true, "and node tooltips")
end

--[[ The Working Overtime estimate starts off ]]

-- Whether the server adds the talent's bonus as points or multiplies by it is unconfirmed, so the estimate saved
-- on for everyone goes off once; a saved off stays off, an on chosen afterwards stays, and a new install starts
-- off (#741).
do
	local old = Client.load({ saved = { includeWorkingOvertime = true } })
	equal(old.ns.db.includeWorkingOvertime, false, "an estimate saved on before the reset goes off")
	equal(old.ns.db.workingOvertimeOffSeen, true, "and the reset is recorded")
	local off = Client.load({ saved = { includeWorkingOvertime = false } })
	equal(off.ns.db.includeWorkingOvertime, false, "a saved off stays off")
	local chosen = Client.load({ saved = { includeWorkingOvertime = true, workingOvertimeOffSeen = true } })
	equal(chosen.ns.db.includeWorkingOvertime, true, "an on chosen after the reset stays")
	local fresh = Client.load({ boot = false })
	fresh.traitConfigs[1187] = 621140
	fresh.traitNodes[621140] = { [110290] = { activeRank = 5, maxRanks = 5 } }
	fresh.Boot()
	equal(fresh.ns.db.includeWorkingOvertime, false, "a new install starts without the estimate")
	equal(fresh.ns.workingOvertimeRank, 5, "and still reads the rank")
	equal(fresh.ns.Model.Chance({ 1, 40, 55, 70 }, 60), 1 / 3, "so a 5/5 character sees the base chance")
	fresh.ns.Model.SetChanceBonus(0)
end

equal(ns.db.valueGathered, false, "the saved free-material choice is preserved")
equal(ns.Price(ORE).copper, 0, "so ore this character mines costs nothing")
equal(Plan().crafts[1].recipeID, FROM_ORE, "and the route crafts from it")

-- Pins invalidate the cached route without changing the price of either recipe.
local oreCost = ns.NetCost(FROM_ORE)
ns.SetPinned(FROM_FLUX, true)
equal(Plan().crafts[1].recipeID, FROM_FLUX, "pinning rebuilds the route with the more expensive choice")
equal(ns.NetCost(FROM_ORE), oreCost, "a pin does not change craft pricing")
ns.SetPinned(FROM_FLUX, false)
equal(Plan().crafts[1].recipeID, FROM_ORE, "unpinning rebuilds the automatic route")

-- On, ore is worth its auction price after the cut, which beats its vendor sell price.
c.SetSetting("valueGathered", true)
equal(ns.Price(ORE).copper, 95, "a gathered material costs its auction price after the 5% cut")
equal(ns.Price(ORE).source, "gather", "it is still gathered, not bought")
equal(ns.Price(ORE).worth, "auction", "valued at the auction")
equal(ns.PriceSourceText(ns.Price(ORE)), "you gather it (Mining), valued at its AH price", "and says so")
equal(ns.NetCost(FROM_ORE), 190, "a craft from it costs what the ore would sell for")
equal(Plan().crafts[1].recipeID, FROM_FLUX, "so the route picks the cheaper flux recipe instead")

-- A cheap auction never values ore below what a vendor pays for it.
c.auction[ORE] = 4
c.AuctionatorScan()
equal(ns.Price(ORE).copper, 5, "the vendor sell price is the floor")
equal(ns.Price(ORE).worth, "vendor", "and is where the value came from")
equal(ns.PriceSourceText(ns.Price(ORE)), "you gather it (Mining), valued at its vendor sell price", "said so")
equal(Plan().crafts[1].recipeID, FROM_FLUX, "a cheaper price alone does not swap the route being followed")
ns.Changed("replan")
equal(Plan().crafts[1].recipeID, FROM_ORE, "asking for a route afresh, worth little, the ore recipe is back")

-- With no auction price at all, the vendor sell price alone; a secret sell price is never computed with.
c.auction[ORE] = nil
c.AuctionatorScan()
equal(ns.Price(ORE).copper, 5, "without an auction price, the vendor sell price")
c.G.issecretvalue = function(value)
	return value == 5
end
c.AuctionatorScan()
equal(ns.Price(ORE).copper, 0, "an unreadable sell price and no auction price leave it free, not guessed")
equal(ns.Price(ORE).worth, nil, "with no value claimed")
c.G.issecretvalue = function()
	return false
end
c.AuctionatorScan()

-- Buying instead of gathering ignores the setting: the ore is then bought like any other reagent.
c.auction[ORE] = 100
ns.SetCollectMode("auction")
equal(ns.Price(ORE).source, "auctionator", "Buy reagents buys gathered materials at the auction house")
equal(ns.Price(ORE).copper, 100, "at the full auction price")

-- Without an observation, ore remains searchable but cannot outrank a known purchase cost.
c.auction[ORE] = nil
c.AuctionatorScan()
equal(ns.Price(ORE).source, "auction", "Buy reagents with no price for the ore: it is bought there")
equal(ns.Price(ORE).unknown, true, "as a price unknown")
equal(ns.Price(ORE).copper, 0, "the placeholder is zero, not a known cost")
c.SetSetting("valueGathered", false)
equal(ns.NetCost(FROM_ORE), nil, "an unknown placeholder cannot price the ore recipe")
equal(Plan().crafts[1].recipeID, FROM_FLUX, "the known flux recipe carries the route")
equal(Plan().unpricedRecipes[1], FROM_ORE, "the unpriced recipe remains identified")
equal(ns.UnpricedReagents(Plan())[1], ORE, "its ore remains available for an auction search")
ns.SetCollectMode("gather")
equal(ns.Price(ORE).source, "gather", "off again, gathering is where it comes from")
equal(ns.Price(ORE).copper, 0, "and it is free")
c.auction[ORE] = 100
c.AuctionatorScan()

--[[ Not this recipe ]]

ns.SetSkipped(FROM_ORE, true)
equal(ns.db.skippedRecipes["Tester Surname-6941"][FROM_ORE], true, "a skip is saved for this character")
equal(ns.IsSkipped(FROM_ORE), true, "and read back")
local plan = Plan()
equal(#plan.crafts, 1, "the route still reaches the target")
equal(plan.crafts[1].recipeID, FROM_FLUX, "without the skipped recipe, though it was the cheapest")
equal(#ns.SkippedRecipes(164), 1, "the profession lists one skipped recipe")
equal(ns.SkippedRecipes(164)[1].name, "Copper Chain Belt", "by name")
equal(#ns.SkippedRecipes(171), 0, "and another profession none")

-- The tracker's header menu shows each skipped recipe of its profession again.
---@return table
local function MenuDescription()
	local description = { buttons = {} }
	function description.CreateTitle() end
	function description.SetScrollMode(_, extent)
		description.scrollExtent = extent
	end
	function description.CreateButton(_, text, action)
		local button = MenuDescription()
		button.text, button.action = text, action
		description.buttons[#description.buttons + 1] = button
		return button
	end
	return description
end
local root = MenuDescription()
c.G.ForeverCore.ContextMenu = function(owner, generator)
	generator(owner, root)
end
ns.SetTracked(164, true)
local block = c.Tracker()[1]
local module = c.G.SkillUpForeverObjectiveTracker
-- The stock tracker module's own method, which the stub client leaves out.
function module.GetContextMenuParent()
	return module
end
-- Blacksmithing is the open profession, so its next craft is actionable in the menu. The menu callback runs
-- as addon code: it must hand off to the client's secure craft button, never call the protected craft API.
local craftCalls = 0
c.G.C_TradeSkillUI.CraftRecipe = function()
	craftCalls = craftCalls + 1
end
c.G.Professions = {
	GetProfessionInfo = function()
		return { professionName = "Blacksmithing", professionID = 164 }
	end,
}
local craftRecipeID = ns.NextCraft(block.plan).recipeID
equal(craftRecipeID ~= nil, true, "the tracked profession has a craft to offer")
c.EnterWorld()
c.Advance(0)
dofile("tests/tracker_menu.lua")(module, block, root)
local skippedMenu, craftMenuEntry
for _, button in ipairs(root.buttons) do
	if button.text == "Skipped (1)" then
		skippedMenu = button
	end
	if button.text:find("^Craft") then
		craftMenuEntry = button
	end
end
equal(craftMenuEntry ~= nil, true, "the tracker's header menu offers the next craft")
local shownRecipe
local realShowRecipe = ns.ShowRecipe
ns.ShowRecipe = function(recipeID, anyProfession)
	shownRecipe = { recipeID, anyProfession }
end
craftMenuEntry.action()
ns.ShowRecipe = realShowRecipe
equal(craftCalls, 0, "and opens it instead of calling the protected craft API itself")
equal(shownRecipe[1], craftRecipeID, "opening the craft's recipe in the native page")
equal(shownRecipe[2], true, "even when the route page shows another profession")
equal(skippedMenu ~= nil, true, "the tracker's header menu counts the skipped recipes")
equal(skippedMenu.buttons[1].text, "Show again: Copper Chain Belt", "and shows each one again")
equal(skippedMenu.scrollExtent, 400, "and so does the skipped list")
skippedMenu.buttons[1].action()
equal(ns.IsSkipped(FROM_ORE), false, "from there")
ns.SetSkipped(FROM_ORE, true)

-- Skipping every recipe leaves the normal no-route state, not an error.
ns.SetSkipped(FROM_FLUX, true)
plan = Plan()
equal(#plan.crafts, 0, "nothing left to craft")
equal(ns.RouteBlocked(plan), "Nothing you know skills up past 1.", "says so the usual way")

-- /skillup skipped lists them with their IDs, and /skillup unskip shows one, or all, again.
local SlashCommand = c.G.SlashCmdList.SKILLUPFOREVER
c.chat = {}
SlashCommand("skipped")
equal(c.chat[1]:find("Skipped (2):", 1, true) ~= nil, true, "/skillup skipped counts them")
equal(c.chat[2]:find("Copper Chain Belt (101)", 1, true) ~= nil, true, "and names each with its ID")
SlashCommand("unskip 101")
equal(ns.IsSkipped(FROM_ORE), false, "/skillup unskip shows one again")
equal(Plan().crafts[1].recipeID, FROM_ORE, "and the route uses it again")
c.chat = {}
SlashCommand("unskip 999")
equal(c.chat[1]:find("/skillup skipped lists", 1, true) ~= nil, true, "an ID that isn't skipped says how to find one")
SlashCommand("unskip all")
equal(ns.IsSkipped(FROM_FLUX), false, "/skillup unskip all shows every one again")
equal(ns.db.skippedRecipes["Tester Surname-6941"], nil, "leaving nothing saved")
c.chat = {}
SlashCommand("skipped")
equal(c.chat[1]:find("no skipped recipes", 1, true) ~= nil, true, "with none skipped, it says how to skip one")

-- A save that isn't a recipe ID set is dropped on load.
local reloaded = Client.load({
	saved = {
		valueGathered = false,
		gatheredValueSeen = true,
		skippedRecipes = { ["Tester Surname-6941"] = { [FROM_ORE] = true, bad = true, [7] = "yes" }, Other = 3 },
	},
})
equal(reloaded.ns.db.skippedRecipes["Tester Surname-6941"][FROM_ORE], true, "a saved skip survives a reload")
equal(reloaded.ns.db.skippedRecipes["Tester Surname-6941"].bad, nil, "a key that isn't a recipe ID is dropped")
equal(reloaded.ns.db.skippedRecipes["Tester Surname-6941"][7], nil, "and a value that isn't true")
equal(reloaded.ns.db.skippedRecipes.Other, nil, "and a character entry that isn't a table")

Client.report("choice_spec")
