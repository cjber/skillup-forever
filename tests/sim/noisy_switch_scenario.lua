-- luacheck: read globals scenario ADDON
-- #850: a live client raises bag events many times a second with nothing SkillUp reads moving. Each one used to
-- count as a bag change, and the next redraw rebuilt the whole plan inside the profession window's frame. Under
-- a noisy client, switching between two planned professions builds no plan.
local ForeverCore = dofile("tests/forever_core.lua")

scenario("a noisy client's bag events rebuild no plan on a profession switch", {
	addons = ForeverCore.addons(),
}, function(sim)
	sim:login()
	local ns
	for _, entry in ipairs(sim.loader.addons) do
		if entry.name == ADDON then
			ns = entry.ns
		end
	end
	-- Real recipes from the addon's own data, so each plan is a real one.
	local function Profession(skillLine, name, skill, limit)
		local recipes, n = {}, 0
		local ids = {}
		for id, recipe in pairs(ns.RecipeData) do
			if recipe.skillLine == skillLine and recipe.output then
				ids[#ids + 1] = id
			end
		end
		table.sort(ids)
		for _, id in ipairs(ids) do
			if n < limit then
				n = n + 1
				local recipe = ns.RecipeData[id]
				recipes[n] =
					{ id = id, name = "R" .. id, category = 1, itemID = recipe.output.itemID, learned = n <= 25 }
			end
		end
		return {
			skillLineID = skillLine,
			name = name,
			skill = skill,
			max = 150,
			categories = { { id = 1, name = "Recipes" } },
			recipes = recipes,
		}
	end
	sim.world.professions = { Profession(185, "Cooking", 95, 80), Profession(165, "Leatherworking", 2, 120) }
	sim:reload()
	for _, entry in ipairs(sim.loader.addons) do
		if entry.name == ADDON then
			ns = entry.ns
		end
	end

	local builds = 0
	local plan = ns.Model.PlanWithTraining
	ns.Model.PlanWithTraining = function(...)
		builds = builds + 1
		return plan(...)
	end
	-- Each profession's first open plans it once.
	sim:openProfessions(185)
	sim:advance(0.5)
	sim:openProfessions(165)
	sim:advance(0.5)
	local planned = builds
	assert(planned >= 2, ("each profession's first open plans it, got %d builds"):format(planned))

	sim:noisy()
	for _ = 1, 3 do
		sim:openProfessions(185)
		sim:advance(0.5)
		sim:openProfessions(165)
		sim:advance(0.5)
	end
	local bagEvents = sim.noise.fired.BAG_UPDATE_DELAYED or 0
	sim:noisy(false)
	assert(bagEvents > 0, "the noisy client raised bag events")
	assert(
		builds == planned,
		("%d bag events with no count SkillUp read moving rebuilt %d plans"):format(bagEvents, builds - planned)
	)
	sim:expectNoErrors()
end)
