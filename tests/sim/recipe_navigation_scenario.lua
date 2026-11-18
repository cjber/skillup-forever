-- luacheck: read globals scenario ADDON
local ForeverCore = dofile("tests/forever_core.lua")

for _, mode in ipairs({ "native", "default", "sorted", "unlearned" }) do
	scenario("controller navigates visible recipes: " .. mode, {
		addons = mode ~= "native" and ForeverCore.addons() or nil,
		addon = mode ~= "native",
		allowErrors = mode == "sorted",
		allowGamepadTaint = mode == "sorted",
	}, function(sim)
		sim.world.professions = {
			{
				skillLineID = 185,
				name = "Cooking",
				skill = 50,
				max = 75,
				categories = { { id = 1, name = "Food" } },
				recipes = {
					{ id = 2538, name = "Charred Wolf Meat", category = 1, itemID = 2679 },
					{ id = 2540, name = "Roasted Boar Meat", category = 1, itemID = 2681 },
					{ id = 2541, name = "Coyote Steak", category = 1, itemID = 2684 },
				},
			},
		}
		-- The fixture supplies engine filtering, which the shared simulator does not implement.
		local search = ""
		sim.impl["C_TradeSkillUI.GetRecipeItemNameFilter"] = function()
			return search
		end
		sim.impl["C_TradeSkillUI.SetRecipeItemNameFilter"] = function(text)
			search = text or ""
			sim.events.fire("TRADE_SKILL_LIST_UPDATE")
		end
		sim.impl["C_TradeSkillUI.GetFilteredRecipeIDs"] = function()
			local ids = {}
			for _, recipe in ipairs(sim.world.professions[1].recipes) do
				if recipe.name:lower():find(search:lower(), 1, true) then
					ids[#ids + 1] = recipe.id
				end
			end
			return ids
		end

		sim:setGamepad(true)
		sim:login({
			savedVariables = {
				SkillUpForeverDB = {
					sortMode = mode == "sorted" and "skill" or "blizzard",
					showUnlearned = mode == "unlearned",
				},
			},
		})
		sim:openProfessions(185)
		sim:advance(0.2)
		local rows = sim:recipeRows()
		assert(#rows >= 3, "three recipes are visible")
		local nav = sim.G.SmartNavigation

		local function focused(index)
			assert(nav.currentButton == rows[index].frame, "controller reaches visible recipe " .. index)
			assert(
				nav.currentButton:IsVisible() and nav.currentButton:GetEffectiveAlpha() > 0,
				"focused recipe is visible"
			)
		end
		sim:input(function()
			nav:SelectButton(rows[1].frame)
		end)
		focused(1)
		sim:input(function()
			nav:NavigateDown(true)
			nav:NavigateDown(false)
		end)
		focused(2)
		sim:input(function()
			nav:NavigateDown(true)
			nav:NavigateDown(false)
		end)
		focused(3)
		sim:input(function()
			nav:NavigateUp(true)
			nav:NavigateUp(false)
		end)
		focused(2)
		if mode == "sorted" then
			local list = sim.G.ProfessionsFrame.CraftingPage.RecipeList

			sim:input(function()
				list.SearchBox:SetText("Boar")
			end)
			sim:advance(0.3)
			local filtered = sim:recipeRows()
			assert(
				#filtered == 1 and filtered[1].recipeInfo.recipeID == 2540,
				"native search filters the sorted SkillUp rows"
			)
			assert(
				filtered[1].frame:IsVisible() and filtered[1].frame:GetEffectiveAlpha() > 0,
				"matching recipe stays visible"
			)
			sim:input(function()
				list.SearchBox:SetText("")
			end)
			sim:advance(0.3)
			assert(#sim:recipeRows() == 3, "clearing native search restores all sorted rows")
		end
		sim:closeProfessions()
		-- Known limitation (#794): a sorted list sits in the client's own view, so its row click selects through
		-- the client's own code (#840), and closing the window afterwards with the gamepad UI on blocks
		-- SetPreferredGamepadInteractTarget. Selecting at all outweighs that close; drop this exception with #794.
		if mode == "sorted" then
			sim:expectError("SetPreferredGamepadInteractTarget")
			assert(#sim.errors == 1, "the #794 close block is the only error")
		else
			sim:expectNoErrors(ADDON)
		end
	end)
end
