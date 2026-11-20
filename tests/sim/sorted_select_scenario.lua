-- luacheck: read globals scenario ADDON
-- #840: under every SkillUp sort, a left click on a learned recipe row selects that recipe in the crafting
-- page through the client's own row click, and the window stays open.
local ForeverCore = dofile("tests/forever_core.lua")

for _, mode in ipairs({ "skill", "chance", "cost", "profit", "name" }) do
	scenario(
		"a left click selects the recipe under the " .. mode .. " sort",
		{ addons = ForeverCore.addons() },
		function(sim)
			local recipes = {}
			for index = 1, 6 do
				recipes[index] =
					{ id = 99100 + index, name = "Test Food " .. index, category = 1, itemID = 2680 + index }
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
			sim:login({ savedVariables = { SkillUpForeverDB = { sortMode = mode } } })
			-- The Forever client's answer to OpenRecipe in an open window, recorded in game (#840): it closes the
			-- trade skill, then answers with the base and child skill lines, and the window stays closed.
			local opened = {}
			sim.impl["C_TradeSkillUI.OpenRecipe"] = function(recipeID)
				opened[#opened + 1] = recipeID
				sim:closeProfessions()
				sim.events.fire("OPEN_RECIPE_RESPONSE", recipeID, 185, 2939)
			end
			local frame = sim:openProfessions(185)
			sim:advance(0.2)
			local page = frame.CraftingPage
			local rows = sim:recipeRows()
			assert(#rows >= 2, "the sorted list shows recipes")
			local first = page.SchematicForm:GetRecipeInfo()
			local target
			for _, row in ipairs(rows) do
				if row.recipeInfo.learned and row.recipeInfo.recipeID ~= (first and first.recipeID) then
					target = row
					break
				end
			end
			assert(target, "a learned recipe other than the selected one")
			sim:click(target.frame, "LeftButton")
			sim:advance(0.5)
			assert(#opened == 0, "the click never asks the client to open the recipe")
			assert(frame:IsShown(), "the Professions window stays open")
			local now = page.SchematicForm:GetRecipeInfo()
			assert(
				now and now.recipeID == target.recipeInfo.recipeID,
				("the clicked recipe %d is selected, not %s"):format(
					target.recipeInfo.recipeID,
					tostring(now and now.recipeID)
				)
			)
			sim:closeProfessions()
			sim:expectNoErrors(ADDON)
		end
	)
end
