-- luacheck: read globals scenario ADDON
-- #840 (second report): after learning a recipe from a trainer with the Professions window open, a left click on a
-- recipe row must still select it, under every sort and Default, without reopening the window.
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
		"a click selects after learning a recipe with the window open (" .. mode .. ")",
		{ addons = ForeverCore.addons() },
		function(sim)
			local recipes = {}
			for index = 1, 6 do
				recipes[index] =
					{ id = 99100 + index, name = "Test Food " .. index, category = 1, itemID = 2680 + index }
			end
			recipes[7] = { id = 99107, name = "Test Food 7", category = 1, itemID = 2687, learned = false }
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
			local frame = sim:openProfessions(185)
			sim:advance(0.2)

			-- The trainer teaches the recipe while the window stays open.
			recipes[7].learned = nil
			sim.events.fire("NEW_RECIPE_LEARNED", 99107)
			sim.events.fire("TRADE_SKILL_LIST_UPDATE")
			sim.events.fire("SKILL_LINES_CHANGED")
			sim:advance(0.5)

			local page = frame.CraftingPage
			for _, wanted in ipairs({ 99107, 99103, 99101 }) do
				local target
				for _, row in ipairs(VisibleRows(sim)) do
					if row.recipeInfo.recipeID == wanted then
						target = row
					end
				end
				assert(target, ("recipe %d is listed after learning"):format(wanted))
				sim:click(target.frame, "LeftButton")
				sim:advance(0.3)
				local now = page.SchematicForm:GetRecipeInfo()
				assert(
					now and now.recipeID == wanted,
					("the clicked recipe %d is selected, not %s"):format(wanted, tostring(now and now.recipeID))
				)
			end
			assert(#opened == 0, "no click asks the client to open a recipe")
			assert(frame:IsShown(), "the window stays open")
			sim:closeProfessions()
		end
	)
end
