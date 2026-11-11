-- luacheck: read globals scenario ADDON
-- #460, #461: one SkillUp side tab opens the pages, and the Buffs page draws, switches and hands the window
-- back, in and out of combat and across a reload. This scenario runs without recipe data so the page draws
-- its empty state; the timeline and its nodes are covered by tests/buffs_spec.lua.
local ForeverCore = dofile("tests/forever_core.lua")

scenario("the SkillUp side tab and the buffs page", { addons = ForeverCore.addons() }, function(sim)
	local G = sim.G
	local ns
	for _, entry in ipairs(sim.loader.addons) do
		if entry.name == ADDON then
			ns = entry.ns
		end
	end
	assert(ns, "full addon namespace loaded")

	sim.world.professions = {
		{
			skillLineID = 129,
			name = "First Aid",
			skill = 1,
			max = 75,
		},
	}

	local function find(root, matches)
		for _, child in ipairs({ root:GetChildren() }) do
			if matches(child) then
				return child
			end
			local found = find(child, matches)
			if found then
				return found
			end
		end
	end

	sim:login()
	ns.RecipeData = {}

	sim:openProfessions(129)
	local sideTab = find(G.ProfessionsFrame, function(frame)
		return frame.tooltipText == "SkillUp"
	end)
	assert(sideTab, "the one SkillUp side tab is there")
	-- The side tab is a real Button with the template's own mouse-up handler.
	sim:run(function()
		local handler = sideTab:GetScript("OnMouseUp")
		assert(handler, "the side tab has a mouse-up handler")
		handler(sideTab, "LeftButton", true)
	end)
	sim:advance(0.2)

	local buffsTab = find(G.ProfessionsFrame, function(frame)
		if not frame.IsObjectType then
			return false
		end
		return frame:IsObjectType("Button") and frame.GetText ~= nil and frame:GetText() == "Buffs"
	end)
	assert(buffsTab, "the Buffs bottom tab is there")
	sim:click(buffsTab)
	sim:advance(0.2)
	local page = find(G.ProfessionsFrame, function(frame)
		return frame.RowsData ~= nil
	end)
	assert(page, "the buffs page is drawn")
	assert(page.Empty:IsShown(), "no buff profession says so in one line")
	local chosen = page.Profession:GetText()
	assert(chosen == nil or chosen == "", "the dropdown has no profession to show, got " .. tostring(chosen))
	assert(not page.Skill:IsShown(), "and no skill beside it")

	local level
	for _, child in ipairs({ page:GetChildren() }) do
		if child.GetChecked and child:IsObjectType("CheckButton") then
			level = child
		end
	end
	assert(level, "the only-for-level switch is there")
	sim:click(level)
	sim:advance(0.1)

	-- Combat changes no page state; the page still draws and switches.
	sim:enterCombat()
	sim:click(buffsTab)
	sim:advance(0.1)
	sim:leaveCombat()

	sim:closeProfessions()
	sim:expectNoErrors(ADDON)

	local reloaded = sim:reload()
	reloaded:openProfessions(129)
	reloaded:expectNoErrors(ADDON)
end)
