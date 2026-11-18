-- luacheck: read globals scenario ADDON
local ForeverCore = dofile("tests/forever_core.lua")

for _, gamepad in ipairs({ false, true }) do
	for _, mode in ipairs({ "skill", "blizzard" }) do
		scenario(
			(gamepad and "gamepad" or "mouse") .. " closes the " .. mode .. " recipe provider",
			-- Known limitation (#794): a sorted or unlearned list sits in the client's own view, so its rows select
			-- through the client's own click (#840), and a gamepad close afterwards blocks
			-- SetPreferredGamepadInteractTarget. Drop the gamepad exception with #794.
			{ addons = ForeverCore.addons(), allowErrors = gamepad, allowGamepadTaint = gamepad },
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
				sim:openProfessions(185)
				sim:advance(0.2)
				local rows = sim:recipeRows()
				local learned, unlearned
				for _, row in ipairs(rows) do
					if row.recipeInfo.recipeID == 2538 then
						learned = row.frame
					elseif not row.recipeInfo.learned then
						unlearned = row.frame
					end
				end
				assert(learned and unlearned, "both learned and unlearned recipes remain visible")
				if gamepad then
					sim:click(learned)
					sim:advance(0.1)
				end
				sim:closeProfessions()
				if gamepad then
					sim:expectError("SetPreferredGamepadInteractTarget")
				else
					sim:expectNoErrors(ADDON)
				end
			end
		)
	end
end
