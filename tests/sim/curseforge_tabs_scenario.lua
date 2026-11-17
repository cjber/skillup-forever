-- luacheck: read globals scenario ADDON
local ForeverCore = dofile("tests/forever_core.lua")

scenario("SkillUp side tab survives reopening and Cooking", {
	addons = ForeverCore.addons(),
}, function(sim)
	sim.world.professions = {
		{ skillLineID = 202, name = "Engineering", skill = 30, max = 75 },
		{ skillLineID = 185, name = "Cooking", skill = 30, max = 75 },
	}
	sim:login()
	local ns
	for _, entry in ipairs(sim.loader.addons) do
		if entry.name == ADDON then
			ns = entry.ns
			ns.RecipeData = {}
		end
	end
	local function check(label)
		local host = sim.G.ProfessionsFrame
		local side = assert(ns.Pages.SideTab())
		assert(side:IsVisible(), label .. ": side tab disappeared")
		assert(side:GetTop() <= host:GetTop(), label .. ": tab above host")
		assert(side:GetBottom() >= host:GetBottom(), label .. ": tab below host")
		return side
	end
	for _, profession in ipairs({ 202, 185, 202, 185 }) do
		sim:openProfessions(profession)
		sim:advance(0.2)
		local side = check("profession " .. profession)
		for _, page in ipairs({ "route", "supply", "buffs" }) do
			sim:runAs(ADDON, "local ns, page = ...; ns.Pages.Select(page)", ns, page)
			sim:advance(0.2)
			check(page)
			sim:closeProfessions()
			sim:openProfessions(profession)
			sim:advance(0.2)
			assert(check("reopened " .. page) == side, "reopening replaced the tab")
		end
	end
	sim:enterCombat()
	sim:openWorldMap()
	sim:closeWorldMap()
	sim:leaveCombat()
	sim:expectNoErrors(ADDON)
	sim:expectNoGamepadTaint(ADDON)
end)
