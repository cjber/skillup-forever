-- luacheck: read globals scenario ADDON
-- The tracker's clickable lines (the next trainer, a reagent's vendor) are drawn from the template the running
-- ForeverCore names. An embedded copy declares it under its own name, so a line drawn from the canonical name failed
-- CreateFrame with "Couldn't find inherited node" wherever no separate ForeverCore was installed
-- (#901, cjber/forever-core#964). The package job runs this on the embedded copy too.
local ForeverCore = dofile("tests/forever_core.lua")

local MILD_SPICES = 2678

scenario("the tracker's vendor line uses the running ForeverCore's line template", {
	addons = ForeverCore.addons(),
}, function(sim)
	sim.world.professions = {
		{
			skillLineID = 185,
			name = "Cooking",
			skill = 50,
			max = 75,
			categories = { { id = 1, name = "Food" } },
			recipes = { { id = 2538, name = "Charred Wolf Meat", category = 1, itemID = 2679 } },
		},
	}
	sim:login()
	local ns
	for _, entry in ipairs(sim.loader.addons) do
		if entry.name == ADDON then
			ns = entry.ns
		end
	end
	assert(ns, "the addon's namespace")
	-- The scenario stands at no map position, so name the spice vendor the route would pick.
	local nearestVendor = ns.NearestVendor
	ns.NearestVendor = function(itemID, ...)
		if itemID == MILD_SPICES then
			return 1
		end
		return nearestVendor(itemID, ...)
	end
	sim.run(function()
		ns.SetTrackedByPlayer(185, true)
	end)
	sim:advance(1)
	sim:expectNoErrors(ADDON)
	-- The tracker lays out under the addon's SafeCall, so a CreateFrame error lands in its journal, as players saw it.
	for _, caught in pairs(sim.G.SkillUpForeverDB.errors or {}) do
		error("the tracker recorded an error: " .. tostring(caught.message or caught[1] or caught))
	end
	local tracker = assert(sim.G.SkillUpForeverObjectiveTracker, "the SkillUp tracker section")
	local vendorLine
	for _, blocks in pairs(tracker.usedBlocks or {}) do
		for _, block in pairs(blocks) do
			for key, line in pairs(block.usedLines or {}) do
				if tostring(key):find(tostring(MILD_SPICES), 1, true) then
					vendorLine = line
				end
			end
		end
	end
	assert(vendorLine, "the tracker draws the Mild Spices line")
	assert(vendorLine:IsMouseEnabled(), "the vendor line is clickable")
end)
