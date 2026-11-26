local Client = dofile("tests/client.lua")
local c = Client.load()
local ns, equal = c.ns, Client.equal

for _, case in ipairs({
	{ "Weaponsmith lesson", 164, 10003, 9787, 9788 },
	{ "Armorsmith lesson", 164, 9954, 9788, 9787 },
	{ "Master Axesmith pattern", 164, 16970, 17041, 9787 },
	{ "Master Hammersmith pattern", 164, 16973, 17040, 9787 },
	{ "Master Swordsmith pattern", 164, 16978, 17039, 9787 },
	{ "Goblin Engineering lesson", 202, 12760, 20222, 20219 },
	{ "Goblin Engineering schematic", 202, 23078, 20222, 20219 },
	{ "Gnomish Engineering schematic", 202, 23096, 20219, 20222 },
	{ "Tribal Leatherworking lesson", 165, 10621, 10660, 10658 },
	{ "Elemental Leatherworking pattern", 165, 19059, 10658, 10656 },
	{ "Tribal Leatherworking pattern", 165, 19053, 10660, 10658 },
	{ "Dragonscale Leatherworking pattern", 165, 19050, 10656, 10660 },
}) do
	local name, line, recipe, required, other = unpack(case)
	local profession = { skillLine = line, modifier = 0 }
	equal(ns.SpecialisationLocked(recipe), true, name .. " with no specialisation")
	local asked = ns.LearnSkill(profession, recipe)
	c.known[other] = true
	equal(ns.SpecialisationLocked(recipe), true, name .. " with a different specialisation")
	c.known[other], c.known[required] = nil, true
	equal(ns.SpecialisationLocked(recipe), false, name .. " with its specialisation")
	equal(asked > 0, true, name .. " says what skill it asks without the specialisation")
	equal(ns.LearnSkill(profession, recipe), asked, name .. " asks the same skill with it")
	c.known[required] = nil
end

-- The actual trainer set for Inlaid Mithril Cylinder Plans covers both branches.
local engineering = { skillLine = 202, modifier = 0 }
equal(ns.TrainingFor(engineering, 12895), nil, "a shared specialist lesson still requires a specialisation")
for _, spell in ipairs({ 20219, 20222 }) do
	c.known[spell] = true
	equal(ns.TrainingFor(engineering, 12895) ~= nil, true, "either engineering branch can take the shared lesson")
	c.known[spell] = nil
end

-- Use the generated recipe and teaching item or trainer set with just one craft in the planner's choice.
local function CheckRoute(line, name, recipeID, required, other, skill)
	local recipe = ns.RecipeData[recipeID]
	local scroll = ns.RecipeScrolls[recipeID]
	local item = scroll and scroll[1]
	local vendor = {}
	for _, reagent in ipairs(recipe.reagents) do
		vendor[reagent.itemID] = 1
	end
	if item then
		vendor[item] = 10
	end
	local test = Client.load({
		boot = false,
		saved = { craftValue = "none", vendor = vendor, routeTargets = { [line] = skill + 1 } },
		data = { RecipeData = { [recipeID] = recipe } },
		questie = item and {
			items = { [item] = { class = 9, teaches = recipeID, vendors = { 900 } } },
			npcs = { [900] = { name = "Vendor", side = "AH" } },
		} or nil,
	})
	local addon = test.ns
	test.level = 60
	test.professions = { { name = name, id = line, rank = skill, max = 300 } }
	test.spells[recipeID] = "Specialist recipe"
	test.known[other] = true
	test.Boot()
	local profession = addon.RouteProfessions()[line]
	addon.Catalogue.EnsureProfession(line)
	test.Advance(0)

	equal(#addon.UnlearnedRecipes(profession), 0, name .. " hides the locked recipe from its unlearned list")
	equal(#addon.PlanRoute(profession).training, 0, name .. " does not send the wrong specialist shopping or training")
	if item then
		equal(#addon.RecipeSuggestions(profession, skill), 0, name .. " does not suggest the locked pattern")
	end

	test.known[other], test.known[required] = nil, true
	test.Fire("SPELLS_CHANGED")
	equal(#addon.UnlearnedRecipes(profession), 1, name .. " lists the recipe after specialising")
	local learned = addon.PlanRoute(profession)
	equal(#learned.training, 1, name .. " replans after specialising")
	equal(learned.training[1].recipeID, recipeID, name .. " recommends the right lesson")
	equal(learned.training[1].scroll, item, name .. " buys the pattern only for a pattern recipe")
	if item then
		equal(#addon.RecipeSuggestions(profession, skill), 1, name .. " suggests the unlocked pattern")
	end

	test.known[required] = nil
	test.Fire("SPELLS_CHANGED")
	equal(addon.RouteFollowable(learned), false, name .. " cannot follow the old route after losing the specialisation")
	equal(#addon.PlanRoute(profession).training, 0, name .. " removes the training step from the route")
end

CheckRoute(164, "Blacksmithing", 10003, 9787, 9788, 225)
CheckRoute(202, "Engineering", 12760, 20222, 20219, 210)
CheckRoute(165, "Leatherworking", 19050, 10656, 10660, 240)

print("specialisation spec passed")
