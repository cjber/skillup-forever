-- luacheck: read globals scenario ADDON
-- #382: with the gamepad interface on, the Forever addons page is the client's own rows, so Options can enter it;
-- the canvas page it shows with the mouse leaves the cursor on a hidden frame.
local ForeverCore = dofile("tests/forever_core.lua")

scenario("the gamepad cursor enters the Forever addons page", { addons = ForeverCore.addons() }, function(sim)
	local G = sim.G
	-- The client opens the panel itself: a C function that calls SettingsPanel:OpenToCategory.
	sim.impl["C_SettingsUtil.OpenSettingsPanel"] = function(categoryID, scrollTo)
		G.SettingsPanel:OpenToCategory(categoryID, scrollTo)
	end
	sim:setGamepad(true)
	sim:login()
	local ns
	for _, entry in ipairs(sim.loader.addons) do
		if entry.name == ADDON then
			ns = entry.ns
		end
	end
	assert(ns and G.ForeverCore and G.ForeverCore.OpenSettingsPanel, "the shared settings opener is loaded")
	local category
	for _, c in ipairs(G.SettingsPanel:GetAllCategories()) do
		if c:GetName() == "SkillUp Forever" then
			category = c
		end
	end
	assert(category, "SkillUp Forever is under Options > AddOns")
	local sub
	for _, s in ipairs(category:GetSubcategories()) do
		if s:GetName() == "Forever addons" then
			sub = s
		end
	end
	assert(sub, "the Forever addons page is registered")
	assert(
		G.SettingsPanel:GetLayout(sub):IsVerticalLayout(),
		"Forever addons is a canvas page, which the gamepad cursor cannot enter (cjber/tweaks-forever#382)"
	)
	-- The page opens through the addon's own opener, which asks the client's restricted function through its secure
	-- delegate (cjber/forever-core#333), so this path is walked too.
	sim:input(function()
		G.ForeverCore.OpenSettingsPanel(category:GetID())
	end)
	sim:input(function()
		G.SettingsPanel:SelectCategory(sub)
	end)
	sim:advance(0.1)
	local first = G.SettingsPanel:GetFirstSmartNavFocusableSettingFrame()
	assert(first and first:IsVisible(), "the cursor lands on a visible row of the Forever addons page")
	sim:expectNoErrors(ADDON)
end)
