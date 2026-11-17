-- luacheck: read globals scenario ADDON
local ForeverCore = dofile("tests/forever_core.lua")

scenario("profit sorting includes grey recipes priced by a snapshot", { addons = ForeverCore.addons() }, function(sim)
	sim.world.professions = {
		{
			skillLineID = 197,
			name = "Tailoring",
			skill = 150,
			max = 300,
			categories = { { id = 1, name = "Cloth" } },
			recipes = {
				{
					id = 2963,
					name = "Bolt of Linen Cloth",
					difficulty = "trivial",
					itemID = 2996,
					reagents = { { 2589, 2 } },
				},
				{ id = 2964, name = "Bolt of Woolen Cloth", itemID = 2997, reagents = { { 2592, 3 } } },
			},
		},
	}
	sim:runAs(
		"NaowhForever",
		[[
		NaowhForever = { AuctionPrice = function(itemID)
			local prices = { [2589] = 10, [2592] = 10, [2996] = 1000, [2997] = 100 }
			return prices[itemID], GetServerTime()
		end }
	]]
	)
	sim:login({
		savedVariables = { SkillUpForeverDB = { priceSource = "naowh", sortMode = "profit", craftValue = "auction" } },
	})
	local frame = sim:openProfessions(197)
	local native = frame.CraftingPage.RecipeList
	local shown
	for _, child in ipairs({ native:GetChildren() }) do
		if child.ScrollBox and child ~= native and child:IsShown() then
			shown = child
		end
	end
	assert(shown, "the addon's view displays the profit-sorted rows")
	local provider = shown.ScrollBox:GetDataProvider()
	assert(
		provider:GetRootNode():GetNodes()[1]:GetData().recipeInfo.recipeID == 2963,
		"grey recipe with the highest craft profit comes first"
	)
	sim:enterCombat()
	sim:leaveCombat()
	sim:closeProfessions()
	sim:expectNoErrors(ADDON)
end)
