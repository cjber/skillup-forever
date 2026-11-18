-- luacheck: read globals scenario ADDON
-- #683: clicking a route step selected its recipe behind SkillUp's own page. The client's crafting page is only
-- alpha-hidden while the side tab is SkillUp's, so showing it raises no OnShow and the hand-back never runs. The
-- click now gives the window back to the client first, then finds the recipe in the client's own list.
-- #840: ns.ShowRecipe is every SkillUp way to a recipe (Route, Gear, the shopping list, the tracker menu). It never
-- calls OpenRecipe, which closes an open window on this client, and the player's own row click selects.
local ForeverCore = dofile("tests/forever_core.lua")

scenario("A route step hands the Professions window back to the client's crafting page", {
	addons = ForeverCore.addons(),
}, function(sim)
	sim.world.professions = {
		{
			skillLineID = 164,
			name = "Blacksmithing",
			skill = 30,
			max = 75,
			categories = { { id = 1, name = "Materials" } },
			recipes = {
				{ id = 2660, name = "Rough Sharpening Stone", category = 1, itemID = 2862 },
				{ id = 3115, name = "Rough Weightstone", category = 1, itemID = 3239 },
			},
		},
	}
	sim:login()
	local G = sim.G
	local ns
	for _, entry in ipairs(sim.loader.addons) do
		if entry.name == ADDON then
			ns = entry.ns
		end
	end
	assert(ns, "the full addon namespace loaded")

	local frame = sim:openProfessions(164)
	assert(frame and frame:IsShown(), "the client's Professions window is open")
	local tabs = G.ForeverCore.ProfessionTabs
	assert(tabs, "ForeverCore's ProfessionTabs module is loaded")

	-- The player selects SkillUp's side tab: the client's crafting page stays shown under it, at alpha 0.
	sim:input(function()
		tabs.Select("skillup")
	end)
	sim:tick(0.3)
	assert(tabs.Selected() == "skillup", "SkillUp's page is selected")
	assert(frame.CraftingPage:IsShown(), "the client's crafting page is still shown")
	assert(frame.CraftingPage:GetAlpha() == 0, "only alpha-hidden beneath SkillUp's page")

	local routePage
	for _, child in ipairs({ frame:GetChildren() }) do
		if child.Profession ~= nil and child.RouteList ~= nil then
			routePage = child
		end
	end
	assert(routePage and routePage:IsShown(), "the route page covers the crafting page")

	-- The route step's click path, with the recipe the client knows.
	local info = G.C_TradeSkillUI.GetRecipeInfo(3115)
	assert(info and info.learned, "the route's recipe is one the client knows")
	local opened = {}
	-- The Forever client's answer to OpenRecipe in an open window, recorded in game (#840).
	sim.impl["C_TradeSkillUI.OpenRecipe"] = function(recipeID)
		opened[#opened + 1] = recipeID
		sim:closeProfessions()
		sim.events.fire("OPEN_RECIPE_RESPONSE", recipeID, 164, 164)
	end
	sim:input(function()
		ns.ShowRecipe(3115, true)
	end)
	sim:tick(0.5)

	assert(#opened == 0, "the client is never asked to open the recipe")
	assert(frame:IsShown(), "the Professions window stays open")
	assert(tabs.Selected() == nil, "the window is the client's again")
	assert(frame.CraftingPage:GetAlpha() == 1, "the crafting page is visible")
	assert(frame.CraftingPage:IsShown(), "and still shown")
	assert(not routePage:IsShown(), "SkillUp's page stepped aside")
	local list = frame.CraftingPage.RecipeList
	assert(list.SearchBox:GetText() == "Rough Weightstone", "the client's search finds the recipe")
	-- Showing, initialising or selecting on the client's crafting page from addon code writes the state the craft
	-- path and bag item use read (#350). The opener leaves every field of the page, its schematic and its list
	-- as the client wrote them.
	local written = {}
	for label, owner in pairs({ page = frame.CraftingPage, form = frame.CraftingPage.SchematicForm, list = list }) do
		for key, slot in pairs(sim.taint.slots[owner] or {}) do
			if slot.addon == ADDON then
				written[#written + 1] = label .. "." .. tostring(key)
			end
		end
	end
	table.sort(written)
	assert(#written == 0, "the opener wrote the client's crafting page: " .. table.concat(written, ", "))
	local target
	for _, row in ipairs(sim:recipeRows()) do
		if row.recipeInfo.recipeID == 3115 then
			target = row.frame
		end
	end
	assert(target, "the recipe's row is listed")
	sim:click(target, "LeftButton")
	sim:advance(0.3)
	local now = frame.CraftingPage.SchematicForm:GetRecipeInfo()
	assert(now and now.recipeID == 3115, "the player's click on the client's row selects it")
end)
