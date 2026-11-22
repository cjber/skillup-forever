-- luacheck: read globals scenario ADDON
local ForeverCore = dofile("tests/forever_core.lua")

for _, input in ipairs({ "mouse", "gamepad", "switch to gamepad" }) do
	for _, mode in ipairs({ "skill", "blizzard" }) do
		scenario(input .. " closes the " .. mode .. " recipe provider", { addons = ForeverCore.addons() }, function(sim)
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
			sim:setGamepad(input == "gamepad")
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
			if input == "switch to gamepad" then
				sim:setGamepad(true)
			end
			local rows = sim:recipeRows()
			local learned, unlearned
			for _, row in ipairs(rows) do
				if row.recipeInfo.recipeID == 2538 then
					learned = row.frame
				elseif not row.recipeInfo.learned then
					unlearned = row.frame
				end
			end
			assert(learned and unlearned, "both recipes remain visible")
			if input ~= "mouse" then
				sim:click(learned)
				sim:advance(0.1)
			end
			sim:closeProfessions()
			if input ~= "mouse" then
				-- Opening chat adds a binding set, which refreshes the action bar's interact icons.
				sim:bindingSetChange()
			end
			sim:expectNoErrors(ADDON)
		end)
	end
end
