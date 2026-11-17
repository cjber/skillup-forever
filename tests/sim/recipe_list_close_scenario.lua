-- luacheck: read globals scenario ADDON
local ForeverCore = dofile("tests/forever_core.lua")

for _, gamepad in ipairs({ false, true }) do
	for _, mode in ipairs({ "skill", "blizzard" }) do
		scenario(
			(gamepad and "gamepad" or "mouse") .. " closes the " .. mode .. " recipe provider",
			{ addons = ForeverCore.addons() },
			function(sim)
				sim.world.professions = {
					{
						skillLineID = 185,
						name = "Cooking",
						skill = 50,
						max = 75,
						categories = { { id = 1, name = "Food" } },
						recipes = {
							{ id = 2538, name = "Charred Wolf Meat", learned = true, category = 1, itemID = 2679 },
							{ id = 2540, name = "Roasted Boar Meat", learned = false, category = 1, itemID = 2681 },
						},
					},
				}
				sim:setGamepad(gamepad)
				sim:login()
				local ns
				for _, entry in ipairs(sim.loader.addons) do
					if entry.name == ADDON then
						ns = entry.ns
					end
				end
				assert(ns)
				sim.run(function()
					ns.db.sortMode = mode
					ns.db.showUnlearned = true
				end)
				local host = sim:openProfessions(185)
				sim:advance(0.2)
				local native = host.CraftingPage.RecipeList
				local custom
				for _, child in ipairs({ native:GetChildren() }) do
					if child.ScrollBox and child ~= native then
						custom = child
					end
				end
				if custom then
					assert(custom:IsShown(), "the sorted or unlearned provider is displayed")
					assert(
						custom.ScrollBox:GetDataProvider() ~= native.ScrollBox:GetDataProvider(),
						"the providers are separate"
					)
					local learned, unlearned
					custom.ScrollBox:ForEachFrame(function(row, node)
						local info = node:GetData().recipeInfo
						if info and info.recipeID == 2538 then
							learned = row
						end
						if info and not info.learned then
							unlearned = row
						end
					end)
					assert(learned and unlearned, "both learned and unlearned recipes remain visible")
					if gamepad then
						sim:click(learned)
						sim:advance(0.1)
					end
				end
				sim:closeProfessions()
				sim:expectNoErrors(ADDON)
				assert(custom, "the addon owns the sorted and unlearned view")
			end
		)
	end
end
