-- luacheck: read globals scenario ADDON
local ForeverCore = dofile("tests/forever_core.lua")

scenario("the reagent tracker shares its show switch and opens the target profession", {
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
		{
			skillLineID = 129,
			name = "First Aid",
			skill = 1,
			max = 75,
			categories = { { id = 2, name = "Bandages" } },
			recipes = { { id = 3275, name = "Linen Bandage", category = 2, itemID = 1251 } },
		},
	}
	sim:login()
	sim:openProfessions(185)
	local G = sim.G
	local module = assert(G.SkillUpForeverObjectiveTracker)
	local open
	local slots = {}
	local menu = {}
	for _, kind in ipairs({ "Title", "Action", "Submenu", "Open", "End" }) do
		menu[kind] = function(_, _, action)
			slots[#slots + 1] = kind
			if kind == "Open" then
				open = action
			end
		end
	end
	sim.run(function()
		module.trackerMenu({ kind = "section", module = module }, menu)
	end)
	sim:expectNoErrors(ADDON)
	assert(
		table.concat(slots, ",") == "Title,Open",
		"core receives the ordered section menu slots: " .. table.concat(slots, ",")
	)
	sim.run(open)
	sim:advance(0.2)
	assert(G.ForeverCore.ProfessionTabs.Selected() == "skillup", "Open shows the profession's route page")
	-- A block can target another profession without changing the client's crafting profession.
	local ns
	for _, entry in ipairs(sim.loader.addons) do
		if entry.name == ADDON then
			ns = entry.ns
		end
	end
	assert(ns)
	local profession = ns.RouteProfessions()[129]
	sim.run(function()
		module.trackerMenu({
			kind = "block",
			id = 129,
			module = module,
			block = {
				id = 129,
				profession = "First Aid",
				plan = ns.PlanRoute(profession),
				steps = {},
				vendorMissing = {},
			},
		}, menu)
	end)
	sim.run(open)
	sim:advance(0.2)
	local targeted
	for _, child in ipairs({ G.ProfessionsFrame:GetChildren() }) do
		if child.Profession and child:IsShown() and child.Profession:GetText() == "First Aid" then
			targeted = true
		end
	end
	assert(targeted, "the block's Open action selects the target profession")
	-- Exercise the actual header menu, including core's Tracker submenu.
	sim:input(function()
		sim.widgets.dispatch(module.Header, "OnMouseUp", "RightButton")
	end)
	local popup = G.ForeverCoreContextMenu
	local count, tracker = 0
	for _, row in ipairs(popup.rows) do
		if row:IsShown() then
			if row:GetText() == "Hide this section" then
				count = count + 1
			end
			if row:GetText() == "Tracker" then
				tracker = row
			end
		end
	end
	assert(tracker, "core adds its Tracker submenu")
	sim:click(tracker)
	local hide
	for _, row in ipairs(popup.rows) do
		if row:IsShown() and row:GetText() == "Hide this section" then
			count = count + 1
			hide = row
		end
	end
	assert(count == 1, "header menu has exactly one Hide this section, supplied by core")
	sim:click(assert(hide))
	assert(module.show.get() == false, "the section menu hides through its show switch")
	assert(G.Settings.GetValue("SkillUpForever_showTracker") == false, "the settings panel sees the same value")
	sim.run(function()
		G.Settings.SetValue("SkillUpForever_showTracker", true)
	end)
	assert(module.show.get() == true, "the settings panel restores the same switch")
	sim:closeProfessions()
	sim:expectNoErrors(ADDON)
end)
