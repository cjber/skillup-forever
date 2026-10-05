-- Run from the repository root: luajit tests/sources_spec.lua
-- Where a recipe's scroll, a vendor and a trainer are, with the whole addon loaded over a synthetic QuestieDB
-- and AtlasLoot: what the route suggests, what a tooltip lists, and what is left without either addon.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local TAILORING = 197
local SOLD, HORDE_SOLD, QUESTED, DROPPED, WORLD, ADVANCED = 11, 12, 13, 14, 15, 16
local SELLER, HORDE_SELLER, FAR_SELLER, BOSS, TRAINER, HOSTILE_TRAINER = 301, 302, 303, 304, 305, 306
local FARTHER_SELLER, FARTHEST_SELLER, BLUFF_SELLER = 307, 308, 309
local THUNDER_BLUFF = 1638
local COOK, ISLE = 900, 2
local THREAD = 2321

local function Load(questie, atlasLoot, saved, build)
	local recipes, thresholds = {}, {}
	for recipeID = SOLD, ADVANCED do
		recipes[recipeID] = { skillLine = TAILORING, reagents = { { itemID = THREAD, quantity = 1 } } }
		thresholds[recipeID] = { 40, 60, 70 + recipeID, 80 + recipeID }
	end
	local c = Client.load({
		boot = false,
		saved = saved,
		build = build,
		data = {
			Thresholds = thresholds,
			RecipeData = recipes,
			TrainerFees = {},
			TrainerRanks = {},
			ItemSellPrices = {},
			GatheredBy = {},
			VendorPrices = { [THREAD] = 100 },
			ProfessionTrainers = { [TAILORING] = { { HOSTILE_TRAINER, 300 }, { TRAINER, 150 } } },
			ScrollDrops = { [200 + DROPPED] = { { BOSS, 4 } } },
			WorldDrops = { [200 + WORLD] = true },
		},
		questie = questie and {
			items = {
				[200 + SOLD] = { vendors = { HORDE_SELLER, SELLER, FAR_SELLER } },
				[200 + HORDE_SOLD] = { vendors = { HORDE_SELLER } },
				[200 + QUESTED] = { quests = { 401, 402 } },
				[THREAD] = { class = 7, vendors = { SELLER, FAR_SELLER } },
				[999] = { class = 7 },
			},
			npcs = {
				[SELLER] = { name = "Seller", spawns = { [10] = { { 30, 40 } } }, side = "A" },
				[FAR_SELLER] = { name = "Far Seller", spawns = { [10] = { { 60, 60 } } }, side = "A" },
				[HORDE_SELLER] = { name = "Horde Seller", spawns = { [10] = { { 31, 41 } } }, side = "H" },
				[BOSS] = { name = "Boss", spawns = { [1581] = { { -1, -1 } } } },
				[TRAINER] = { name = "Trainer", spawns = { [10] = { { 50, 50 } } }, side = "AH" },
				[HOSTILE_TRAINER] = { name = "Hostile Trainer", spawns = { [10] = { { 1, 1 } } } },
				[FARTHER_SELLER] = { name = "Farther Seller", spawns = { [10] = { { 70, 70 } } }, side = "A" },
				[FARTHEST_SELLER] = { name = "Farthest Seller", spawns = { [10] = { { 80, 80 } } }, side = "A" },
				-- Friendly to both by QuestieDB, inside a Horde capital.
				[BLUFF_SELLER] = { name = "Bluff Seller", spawns = { [THUNDER_BLUFF] = { { 2, 2 } } }, side = "AH" },
			},
			quests = { [401] = { name = "For the Horde", races = 178 }, [402] = { name = "A Fine Shirt", races = 77 } },
			areas = { [10] = 10, [THUNDER_BLUFF] = 10 },
		} or nil,
		atlasLoot = atlasLoot and {
			recipes = {
				[200 + SOLD] = { 8, 40, SOLD },
				[200 + HORDE_SOLD] = { 8, 40, HORDE_SOLD },
				[200 + QUESTED] = { 8, 40, QUESTED },
				[200 + DROPPED] = { 8, 40, DROPPED },
				[200 + WORLD] = { 8, 40, WORLD },
				[200 + ADVANCED] = { 8, 200, ADVANCED },
			},
			drops = { [BOSS] = { [200 + DROPPED] = 12.5 } },
		} or nil,
	})
	c.maps = { [0] = { mapID = 10, name = "Darkshire" }, [ISLE] = { mapID = 20, name = "Zephras Isle" } }
	c.areas = { [1581] = "The Deadmines" }
	c.professions = { { name = "Tailoring", icon = 1, rank = 50, max = 75, id = 8197 } }
	c.Boot()
	-- What a tooltip is given, as "left: right" lines.
	local lines = {}
	c.G.GameTooltip_AddColoredDoubleLine = function(_, left, right)
		lines[#lines + 1] = left .. ": " .. right
	end
	c.G.GameTooltip_AddNormalLine = function(_, text)
		lines[#lines + 1] = text
	end
	c.G.GameTooltip_AddDisabledLine = c.G.GameTooltip_AddNormalLine
	c.G.GameTooltip_AddInstructionLine = c.G.GameTooltip_AddNormalLine
	c.G.GameTooltip_AddBlankLineToTooltip = function() end
	function c.Lines(fill)
		lines = {}
		fill({})
		return table.concat(lines, " | ")
	end
	return c, c.ns.PlayerProfessions()[TAILORING]
end

local function Kinds(suggestions)
	local parts = {}
	for index, suggestion in ipairs(suggestions) do
		parts[index] = suggestion.recipeID .. " " .. suggestion.kindText
	end
	return table.concat(parts, ", ")
end

--[[ With QuestieDB and AtlasLoot ]]

local c, tailoring = Load(true, true)
local ns = c.ns
equal(#ns.RecipeSuggestions(tailoring, 50), 0, "nothing is suggested until the profession is read")
equal(ns.NearestTrainer(tailoring, 150), nil, "nor is a trainer named")
c.Advance(0)
local suggestions = ns.RecipeSuggestions(tailoring, 50)
-- The Horde's scroll and the one wanting 200 skill are left out.
equal(Kinds(suggestions), "11 vendor, 13 quest, 14 drop, 15 world drop", "the easiest to get first")
equal(suggestions[1].npcID, SELLER, "the vendor is the one of your faction")
equal(ns.SuggestionNPC(suggestions[1]), SELLER, "a click goes to that vendor")
equal(ns.SuggestionNPC(suggestions[3]), BOSS, "a drop's click goes to who drops it")
equal(ns.ScrollSkill(SOLD, suggestions[1].source), 40, "the skill a scroll needs is AtlasLoot's")
equal(
	c.Lines(function(tooltip)
		ns.AddSourceLines(tooltip, suggestions[1].source)
	end),
	"Sold by: Seller |  : Darkshire  30, 40 | Sold by: Far Seller |  : Darkshire  60, 60"
		.. " | Sold by: Horde Seller |  : Darkshire  31, 41",
	"every vendor is listed with where it stands, the ones of your faction nearest first"
)
-- A scroll with more vendors than a tooltip has room for: the nearest four, and a count of the rest.
local many = {
	item = 200 + SOLD,
	vendors = { HORDE_SELLER, SELLER, FAR_SELLER, FARTHER_SELLER, FARTHEST_SELLER, BLUFF_SELLER },
	quests = {},
	drops = {},
}
equal(ns.NearestNPC({ BLUFF_SELLER }), nil, "a vendor inside the other faction's capital is nobody's nearest")
equal(ns.NearestNPC(many.vendors), SELLER, "however near it stands")
equal(
	c.Lines(function(tooltip)
		ns.AddSourceLines(tooltip, many)
	end),
	"Sold by: Seller |  : Darkshire  30, 40 | Sold by: Far Seller |  : Darkshire  60, 60"
		.. " | Sold by: Farther Seller |  : Darkshire  70, 70 | Sold by: Farthest Seller |  : Darkshire  80, 80"
		.. " | +2 more",
	"a long list of vendors stops at the nearest four"
)
equal(
	c.Lines(function(tooltip)
		ns.AddSourceLines(tooltip, many, FARTHEST_SELLER)
	end),
	"Sold by: Farthest Seller |  : Darkshire  80, 80 | Sold by: Seller |  : Darkshire  30, 40"
		.. " | Sold by: Far Seller |  : Darkshire  60, 60 | Sold by: Farther Seller |  : Darkshire  70, 70"
		.. " | +2 more",
	"the vendor a click goes to is listed first"
)
equal(
	c.Lines(function(tooltip)
		ns.AddSourceLines(tooltip, suggestions[1].source, BOSS)
	end):find("Boss", 1, true),
	nil,
	"and nobody who does not sell the scroll is"
)
equal(
	c.Lines(function(tooltip)
		ns.AddSourceLines(tooltip, suggestions[2].source)
	end),
	"Quest: For the Horde | Quest: A Fine Shirt",
	"every quest by its title"
)
equal(
	c.Lines(function(tooltip)
		ns.AddSourceLines(tooltip, suggestions[3].source)
	end),
	"Dropped by: Boss  (12.5%) |  : The Deadmines",
	"a drop by its dungeon and AtlasLoot's chance"
)
equal(
	c.Lines(function(tooltip)
		ns.AddSourceLines(tooltip, suggestions[4].source)
	end),
	"World drop",
	"a world drop as that"
)

-- A scroll's price is the one seen: nothing is bundled.
equal(ns.ScrollPrice(suggestions[1].source), nil, "a scroll nobody priced has no price")
c.merchant = { { itemID = 200 + SOLD, price = 250, stackCount = 1 } }
c.Fire("MERCHANT_SHOW")
equal(ns.ScrollPrice(suggestions[1].source), 250, "the price at a merchant's window is kept")

equal(ns.NearestTrainer(tailoring, 150), TRAINER, "the trainer this character can use")
equal(ns.NearestTrainer(tailoring, 225), nil, "a hostile trainer is nobody's")
equal(ns.NearestVendor(THREAD), nil, "a reagent's vendors are read when first asked for")
c.Advance(0)
equal(ns.NearestVendor(THREAD), SELLER, "then the nearest is named")
equal(ns.NearestVendor(999), nil, "an item nobody sells has no vendor")
equal(
	c.Lines(function(tooltip)
		ns.AddNearest(tooltip, "Nearest trainer", nil)
	end),
	"",
	"with Questie, a step with no trainer says nothing more"
)

--[[ Far from every vendor the databases know, then at one they do not ]]

-- An isle on its own continent: both of the thread's vendors are a continent away, so neither is the nearest.
c.player.instance = ISLE
equal(ns.NearestVendor(THREAD), nil, "with every vendor on another continent none is called the nearest")
equal(ns.NearestTrainer(tailoring, 150), TRAINER, "the only trainer there is is still named")
suggestions = ns.RecipeSuggestions(tailoring, 50)
equal(Kinds(suggestions), "11 vendor, 13 quest, 14 drop, 15 world drop", "a scroll is still one a vendor sells")
equal(suggestions[1].npcID, SELLER, "and names a vendor of it")
equal(ns.SuggestionNPC(suggestions[1]), SELLER, "which its click goes to")
-- A cook neither database knows sells the thread, a known scroll, and bread the addon has no use for.
c.npc = { id = COOK, name = "Cook" }
c.merchant = {
	{ itemID = THREAD, price = 100, stackCount = 1 },
	{ itemID = 200 + SOLD, price = 250, stackCount = 1 },
	{ itemID = 999, price = 25, stackCount = 1 },
}
c.Fire("MERCHANT_SHOW")
equal(ns.NearestVendor(THREAD), COOK, "a vendor seen selling the item is the nearest when it is")
equal(ns.LocationText(ns.NPCLocation(COOK)), "Zephras Isle  50, 50", "placed where the player stood at its window")
equal(ns.NPCLocation(COOK).name, "Cook", "under the name it had")
equal(ns.SuggestionNPC(ns.RecipeSuggestions(tailoring, 50)[1]), COOK, "a scroll it sells is bought from it too")
local seen = c.G.SkillUpForeverDB.sellers[COOK]
equal(seen.items[THREAD] and seen.items[200 + SOLD], true, "the reagent and the scroll it sells are saved")
equal(seen.items[999], nil, "and nothing the addon has no use for")
c.player.instance = 0
equal(ns.NearestVendor(THREAD), SELLER, "back on the mainland the vendor there is nearer")
c.npc = { id = 901, name = "Baker" }
c.merchant = { { itemID = 999, price = 25, stackCount = 1 } }
c.Fire("MERCHANT_SHOW")
equal(c.G.SkillUpForeverDB.sellers[901], nil, "a vendor of nothing the addon uses is not kept")

--[[ Without AtlasLoot: QuestieDB names no recipe on a scroll, so no scroll is known ]]

c, tailoring = Load(true, false)
ns = c.ns
ns.RecipeSuggestions(tailoring, 50)
c.Advance(0)
equal(#ns.RecipeSuggestions(tailoring, 50), 0, "without AtlasLoot no scroll is tied to a recipe")
equal(ns.NearestTrainer(tailoring, 150), TRAINER, "trainers are still named")
equal(
	ns.Catalogue.Hint(),
	"Install AtlasLoot to see the recipes vendors, quests and drops would add.",
	"and one line says what to install"
)
equal(ns.Catalogue.Hint(true), nil, "which a vendor or trainer does not need")

--[[ Without Questie: scrolls that drop are still suggested, and nobody is named ]]

c, tailoring = Load(false, true)
ns = c.ns
ns.RecipeSuggestions(tailoring, 50)
c.Advance(0)
suggestions = ns.RecipeSuggestions(tailoring, 50)
equal(Kinds(suggestions), "14 drop, 15 world drop", "without Questie only drops are known")
equal(ns.SetWaypoint(ns.SuggestionNPC(suggestions[1])), false, "with nobody to route to")
equal(#c.chat, 0, "and nothing said")
equal(ns.NearestTrainer(tailoring, 150), nil, "no trainer is named")
equal(ns.NearestVendor(THREAD), nil, "nor a vendor")
-- A vendor seen in an earlier session needs no database.
local later = Load(false, true, {
	sellers = { [COOK] = { name = "Cook", side = "A", map = 10, x = 0.2, y = 0.2, items = { [THREAD] = true } } },
})
equal(later.ns.NearestVendor(THREAD), COOK, "a vendor seen before is named without Questie")
equal(later.ns.NPCLocation(COOK).label, "Darkshire", "where it was seen")

-- A vendor is used for the build it was seen on and the next one, and not after two builds without it.
local function VendorOn(build)
	return {
		builds = { "70205", "70210" },
		sellers = {
			[COOK] = {
				name = "Cook",
				side = "A",
				map = 10,
				x = 0.2,
				y = 0.2,
				build = build,
				items = { [THREAD] = true },
			},
		},
	}
end
local oneBuildAgo = Load(false, true, VendorOn("70210"), "70215")
equal(oneBuildAgo.ns.NearestVendor(THREAD), COOK, "a vendor seen one build ago is still named")
local twoBuildsAgo = Load(false, true, VendorOn("70205"), "70215")
equal(twoBuildsAgo.ns.NearestVendor(THREAD), nil, "a vendor unseen for two builds is not named")
equal(
	c.Lines(function(tooltip)
		ns.AddNearest(tooltip, "Nearest trainer", nil)
	end),
	"Install Questie to see vendors, quests and trainers, with waypoints to them.",
	"a step's tooltip says what to install"
)

--[[ With neither ]]

c, tailoring = Load(false, false)
ns = c.ns
equal(#ns.RecipeSuggestions(tailoring, 50), 0, "with neither addon nothing is suggested")
equal(
	ns.Catalogue.Hint(),
	"Install Questie and AtlasLoot to see where recipes, vendors and trainers are.",
	"and one line names both"
)
c.Advance(0)
equal(#c.chat, 0, "the addon runs without a word")

Client.report("sources_spec")
