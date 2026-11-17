-- Rows visible to the player, including SkillUp's separate sorted and unlearned view.
return function(sim)
	local list = sim.G.ProfessionsFrame.CraftingPage.RecipeList
	for _, child in ipairs({ list:GetChildren() }) do
		if child.ScrollBox and child:IsShown() then
			local rows = {}
			child.ScrollBox:ForEachFrame(function(frame, node)
				local info = node:GetData().recipeInfo
				if info then
					rows[#rows + 1] = { frame = frame, recipeInfo = info }
				end
			end)
			return rows
		end
	end
	return sim:recipeRows()
end
