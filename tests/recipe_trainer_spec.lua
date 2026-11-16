-- Run from the repository root: luajit tests/recipe_trainer_spec.lua
-- Issue #722: a route's training step goes to a trainer who lists that recipe, not merely one whose rank cap
-- covers it. At 175 Leatherworking the route sent a player to Drakk Stonehand for Barbaric Shoulders, which
-- only Una and Telonis teach, so he would not talk to them.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local LEATHERWORKING = 165
local BARBARIC_SHOULDERS, GUARDIAN_GLOVES, JOURNEYMAN_ONLY, UNA_ONLY = 7151, 7156, 7147, 7400
-- Una (Thunder Bluff), Telonis (Darnassus), Drakk Stonehand (Aerie Peak), Randal Worth (a journeyman).
local DRAKK, UNA, TELONIS, RANDAL = 11097, 3007, 4212, 11096
local THREAD = 2996

local function Load(faction, level, withQuestie)
	local recipes, thresholds, fees = {}, {}, {}
	for _, recipe in ipairs({ BARBARIC_SHOULDERS, GUARDIAN_GLOVES, JOURNEYMAN_ONLY, UNA_ONLY }) do
		recipes[recipe] = { skillLine = LEATHERWORKING, reagents = { { itemID = THREAD, quantity = 1 } } }
		thresholds[recipe] = { 160, 180, 200, 220 }
		fees[recipe] = { 500, 150 }
	end
	local places = {
		npcs = {
			[DRAKK] = { name = "Drakk Stonehand", spawns = { [10] = { { 1, 1 } } }, side = "A" },
			[TELONIS] = { name = "Telonis", spawns = { [10] = { { 50, 50 } } }, side = "A" },
			[RANDAL] = { name = "Randal Worth", spawns = { [10] = { { 60, 60 } } }, side = "A" },
			[UNA] = { name = "Una", spawns = { [10] = { { 50, 50 } } }, side = "H" },
		},
		items = { [THREAD] = { class = 7, vendors = {} } },
		areas = { [10] = 10 },
	}
	local c = Client.load({
		boot = false,
		data = {
			Thresholds = thresholds,
			RecipeData = recipes,
			TrainerFees = fees,
			-- Una and Telonis teach the two artisan recipes; Randal alone teaches one of his own. Randal is
			-- no rank trainer, so he is in no ProfessionTrainers list, as the real journeymen are not.
			TrainerSets = { [1] = { UNA, TELONIS }, [2] = { RANDAL }, [3] = { UNA } },
			RecipeTrainerSets = {
				[BARBARIC_SHOULDERS] = 1,
				[GUARDIAN_GLOVES] = 1,
				[JOURNEYMAN_ONLY] = 2,
				[UNA_ONLY] = 3,
			},
			-- A trainer who asks a character level for the recipe before he shows it.
			TrainerLevels = { [GUARDIAN_GLOVES] = 45 },
			TrainerRanks = {},
			ItemSellPrices = {},
			GatheredBy = {},
			VendorPrices = { [THREAD] = 100 },
			-- Drakk's Artisan cap covers every Leatherworking recipe, which is what the route used to go by.
			ProfessionTrainers = { [LEATHERWORKING] = { { DRAKK, 300 } } },
		},
		questie = withQuestie ~= false and places or nil,
	})
	c.maps = { [0] = { mapID = 10, name = "Darkshire" } }
	c.areas = { [10] = "Darkshire" }
	c.player.faction = faction
	c.level = level or 35
	c.professions = { { name = "Leatherworking", icon = 1, rank = 175, max = 225, id = LEATHERWORKING } }
	for _, recipe in ipairs({ BARBARIC_SHOULDERS, GUARDIAN_GLOVES, JOURNEYMAN_ONLY, UNA_ONLY }) do
		c.spells[recipe] = "Recipe " .. recipe
	end
	c.Boot()
	c.ns.Catalogue.EnsureProfession(LEATHERWORKING)
	c.Advance(0)
	return c, c.ns.PlayerProfessions()[LEATHERWORKING]
end

local c, leatherworking = Load("Alliance")
local ns = c.ns

equal(ns.NearestTrainer(leatherworking, 176), DRAKK, "the rank list still names the Artisan trainer for a rank")
equal(
	ns.RecipeNPC(leatherworking, BARBARIC_SHOULDERS),
	TELONIS,
	"the training step names the trainer who teaches that recipe, not his Artisan cap"
)
equal(ns.NearestRecipeTrainer(leatherworking, BARBARIC_SHOULDERS), TELONIS, "and only him for this character")
equal(ns.NearestRecipeTrainer(leatherworking, GUARDIAN_GLOVES), TELONIS, "as for the other recipe he teaches")
equal(
	ns.NearestRecipeTrainer(leatherworking, UNA_ONLY),
	nil,
	"a recipe only the other faction's trainers teach names nobody of yours"
)
equal(ns.RecipeNPC(leatherworking, UNA_ONLY), nil, "and falls back to no other NPC either")

-- Without QuestieDB nobody's place is known: that is not the same as no trainer of yours teaching it.
local bare = Load("Alliance", 35, false)
local bareNPC, bareKnown = bare.ns.NearestRecipeTrainer(bare.ns.PlayerProfessions()[LEATHERWORKING], BARBARIC_SHOULDERS)
equal(bareNPC, nil, "without QuestieDB no trainer is named")
equal(bareKnown, false, "and the step does not claim none teaches it")

-- A journeyman who trains no rank is not in the profession's cap list, but he teaches a recipe and is read.
equal(ns.NearestRecipeTrainer(leatherworking, JOURNEYMAN_ONLY), RANDAL, "a recipe only a journeyman teaches names him")
equal(ns.NPCLocation(RANDAL).name, "Randal Worth", "and he is read from QuestieDB like any other trainer")

-- The trainer a step names is the one this character can use.
local horde = Load("Horde")
equal(
	horde.ns.NearestRecipeTrainer(horde.ns.PlayerProfessions()[LEATHERWORKING], BARBARIC_SHOULDERS),
	UNA,
	"the Horde trainer for the same recipe"
)

-- The step says why it names nobody, rather than pointing at a trainer who will not talk.
local lines = {}
c.G.GameTooltip_AddInstructionLine = function() end
c.G.GameTooltip_AddNormalLine = function() end
c.G.GameTooltip_AddDisabledLine = function() end
c.G.GameTooltip_AddColoredDoubleLine = function() end
c.G.strcmputf8i = function(a, b)
	if a == b then
		return 0
	end
	return a < b and -1 or 1
end
c.G.GameTooltip_AddColoredLine = function(_, text)
	lines[#lines + 1] = text
end
ns.AddRecipeTrainer({}, leatherworking, UNA_ONLY)
equal(lines[1], "No trainer of your faction teaches this recipe.", "the step says no trainer of yours teaches it")
lines = {}
ns.AddRecipeTrainer({}, leatherworking, BARBARIC_SHOULDERS)
equal(lines[1], nil, "while a step with a trainer says nothing against it")
equal(ns.NPCLocation(ns.NearestRecipeTrainer(leatherworking, BARBARIC_SHOULDERS)).name, "Telonis", "and names him")

-- A level gate the trainer asks is kept with the recipe, so a route that defers it says what it waits for.
local training = ns.TrainingFor(leatherworking, GUARDIAN_GLOVES)
equal(training[4], 45, "the bundled level is part of the training")
local source = ns.LearnSource(leatherworking, GUARDIAN_GLOVES)
equal(source.level, 45, "and the recipe's source carries it")
equal(ns.LearnSourceText(source), "Trainer 150 (level 45)", "which the recipe reads out")
equal(ns.TrainingFor(leatherworking, BARBARIC_SHOULDERS)[4], nil, "no level is invented for a recipe that asks none")
local found
for _, entry in ipairs(ns.UnlearnedRecipes(leatherworking)) do
	if entry.recipeID == GUARDIAN_GLOVES then
		found = entry
	end
end
equal(found and found.level, 45, "and the recipe stays in the list, with the level it waits for")

-- A trainer's own record of a recipe: the level it showed is used only when it asks one.
ns.db.trainer[LEATHERWORKING] = { [BARBARIC_SHOULDERS] = { 500, 150, 150, 0 } }
equal(ns.LearnSource(leatherworking, BARBARIC_SHOULDERS).level, nil, "a service that asks no level shows none")
ns.db.trainer[LEATHERWORKING][BARBARIC_SHOULDERS] = { 500, 150, 150, 35 }
equal(ns.LearnSource(leatherworking, BARBARIC_SHOULDERS).level, 35, "a level a trainer showed is kept")
ns.db.trainer[LEATHERWORKING] = nil

Client.report("recipe_trainer_spec")
