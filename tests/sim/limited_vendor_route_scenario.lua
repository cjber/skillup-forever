-- luacheck: read globals scenario
local ForeverCore = dofile("tests/forever_core.lua")

scenario("a tracked route splits limited vendor stock", { addons = ForeverCore.addons() }, function(sim)
	local cooking, fish, vendor = 185, 6303, 5001
	sim.world.professions = {
		{
			skillLineID = cooking,
			name = "Cooking",
			skill = 1,
			max = 75,
			categories = { { id = 1, name = "Food" } },
			recipes = {
				{
					id = 7752,
					grey = 85,
					name = "Slitherskin Mackerel",
					itemID = 787,
					category = 1,
					reagents = { { fish, 1 } },
				},
			},
		},
	}
	sim:stub("Auctionator", { prices = { [fish] = 105 } })
	sim:login({
		savedVariables = {
			SkillUpForeverDB = {
				routeTargets = { [cooking] = 45 },
				learned = { ["Syrberus-Forever"] = { [7752] = true } },
				trackedProfessions = { [cooking] = true },
				vendor = { [fish] = 5 },
				stock = { [fish] = { [vendor] = 4 } },
				sellers = {
					[vendor] = {
						name = "Fish Vendor",
						side = "H",
						map = 1454,
						x = 0.5,
						y = 0.5,
						items = { [fish] = true },
					},
				},
			},
		},
	})
	sim:openProfessions(cooking)
	local G = sim.G
	sim.run(function()
		G.ForeverCore.ProfessionTabs.Select("skillup")
	end)
	sim:advance(0.2)
	assert(G.ForeverCore.ProfessionTabs.Selected() == "skillup", "the route page opened")
	local list = assert(G.SkillUpForever.API.ShoppingList(cooking)[1])
	local bought, auctioned = 0, 0
	for _, row in ipairs(list.items) do
		if row.itemID == fish then
			if row.source == "vendor" then
				bought = bought + row.missing
			elseif row.source == "auction" then
				auctioned = auctioned + row.missing
			end
		end
	end
	assert(bought == 4 and auctioned > 0, "the tracked route uses four vendor fish and buys the rest at auction")
	assert(list.total == 4 * 5 + auctioned * 105, "the shopping list prices each source")
end)
