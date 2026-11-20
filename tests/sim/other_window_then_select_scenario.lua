-- luacheck: read globals scenario ADDON
-- #840 (third report, CurseForge 8743396): after another window (a merchant, the bags) was opened and closed, a
-- click on a recipe row must still select it, under Default and every sort, with the Professions window open.
local ForeverCore = dofile("tests/forever_core.lua")

-- The rows the player can see and click, whichever list shows them.
local function VisibleRows(sim)
	local rows = {}
	for _, row in ipairs(sim:recipeRows()) do
		if row.frame:IsVisible() and row.frame:GetEffectiveAlpha() > 0 then
			rows[#rows + 1] = row
		end
	end
	local list = sim.G.ProfessionsFrame.CraftingPage.RecipeList
	for _, child in ipairs({ list:GetChildren() }) do
		if child.ScrollBox and child:IsVisible() then
			child.ScrollBox:ForEachFrame(function(frame, node)
				local info = node:GetData().recipeInfo
				if info and frame:IsVisible() then
					rows[#rows + 1] = { frame = frame, recipeInfo = info }
				end
			end)
		end
	end
	return rows
end

for _, mode in ipairs({ "blizzard", "skill", "chance", "cost", "profit", "name" }) do
	scenario(
		"a click selects after another window opened and closed (" .. mode .. ")",
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
			local opened = {}
			sim.impl["C_TradeSkillUI.OpenRecipe"] = function(recipeID)
				opened[#opened + 1] = recipeID
				sim:closeProfessions()
			end
			-- Another window first: a merchant and the bags, opened and closed.
			sim:openMerchant()
			sim:openBags()
			sim:advance(0.2)
			sim:closeMerchant()
			sim.run(function()
				sim.G.CloseAllBags()
			end)
			sim:advance(0.2)

			local frame = sim:openProfessions(185)
			sim:advance(0.3)
			local page = frame.CraftingPage
			local first = page.SchematicForm:GetRecipeInfo()
			local clicked = 0
			for _, row in ipairs(VisibleRows(sim)) do
				if clicked < 3 and row.recipeInfo.learned and row.recipeInfo.recipeID ~= (first and first.recipeID) then
					sim:click(row.frame, "LeftButton")
					sim:advance(0.3)
					local now = page.SchematicForm:GetRecipeInfo()
					assert(
						now and now.recipeID == row.recipeInfo.recipeID,
						("the clicked recipe %d is selected, not %s"):format(
							row.recipeInfo.recipeID,
							tostring(now and now.recipeID)
						)
					)
					clicked = clicked + 1
				end
			end
			assert(clicked == 3, "three rows were clicked")
			assert(#opened == 0, "no click asks the client to open a recipe")
			assert(frame:IsShown(), "the window stays open")
			sim:closeProfessions()
		end
	)
end
