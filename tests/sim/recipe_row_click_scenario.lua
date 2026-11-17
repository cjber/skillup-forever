-- luacheck: read globals scenario ADDON
local ForeverCore = dofile("tests/forever_core.lua")
local RecipeRows = dofile("tests/sim_recipe_rows.lua")

-- Scrolling recycles pooled rows, and the template's initializer sets a fresh OnClick each time. SkillUp's click
-- handling has to be applied again on every initialization, or recycled rows fall back to the template's own.
scenario("recycled SkillUp recipe rows keep SkillUp's click handling", { addons = ForeverCore.addons() }, function(sim)
	local recipes = {}
	for index = 1, 60 do
		recipes[index] = { id = 99000 + index, name = "Test Food " .. index, category = 1 }
	end
	sim.world.professions = {
		{
			skillLineID = 185,
			name = "Cooking",
			skill = 50,
			max = 75,
			categories = { { id = 1, name = "Food" } },
			recipes = recipes,
		},
	}
	sim:login({ savedVariables = { SkillUpForeverDB = { sortMode = "skill" } } })
	sim:openProfessions(185)
	sim:advance(0.2)
	local box = RecipeRows(sim)[1].frame:GetParent():GetParent():GetParent()
	for _, percent in ipairs({ 1, 0, 0.5, 0 }) do
		sim.run(function()
			box:SetScrollPercentage(percent, true)
		end)
		sim:advance(0.1)
	end
	local checked = 0
	for _, row in ipairs(RecipeRows(sim)) do
		sim:click(row.frame, "RightButton")
		local popup = sim.G.ForeverCoreContextMenu
		local favorite = false
		for _, item in ipairs(popup and popup.rows or {}) do
			favorite = favorite or (item:IsShown() and item:GetText() == sim.G.BATTLE_PET_FAVORITE)
		end
		assert(favorite, "a recycled row's right click opens SkillUp's favorite menu")
		popup:Hide()
		checked = checked + 1
	end
	assert(checked > 0, "recycled rows are shown")
	sim:closeProfessions()
	sim:expectNoErrors(ADDON)
end)
