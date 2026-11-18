-- luacheck: read globals scenario ADDON Sim
-- #845 / #350: after a click on a SkillUp-sorted row, the client's own Create still crafts and a bag item is still
-- usable. The sorted list sits in the client's own view, so its selection reads SkillUp's node data; neither the
-- craft nor the item use may be refused for it. The sim refuses UseContainerItem from tainted code; it does not
-- yet refuse CraftRecipe (forever-core#831), so the craft half checks the client's own Create path runs.
local ForeverCore = dofile("tests/forever_core.lua")

scenario("after a sorted-row click, Create crafts and a bag item is usable", {
	addons = ForeverCore.addons(),
}, function(sim)
	local G = sim.G
	local POTION = 2459
	sim.items[POTION] = { name = "Swiftness Potion", lines = { "Use: Increases run speed." } }
	sim:loadBlizzard("Blizzard_TokenUI:Camelot/Blizzard_TokenUI")
	sim:loadBlizzard("Blizzard_UIPanels_Game:BankFrame|TradeFrame")
	sim:loadBlizzard("Blizzard_MailFrame")
	sim:loadBlizzard("Blizzard_FrameXML/Mainline/StackSplitFrame.lua")
	sim:loadBlizzard("Blizzard_FrameXML/Camelot/StackSplitFrame.xml")
	G.SetCVar("combinedBags", "1")
	local recipes = {}
	for index = 1, 6 do
		recipes[index] = {
			id = 99100 + index,
			name = "Test Food " .. index,
			category = 1,
			itemID = 2680 + index,
			reagents = { { 2672, 1 } },
		}
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
	sim:login({ savedVariables = { SkillUpForeverDB = { sortMode = "skill" } } })
	sim:event("ADDON_LOADED", "Blizzard_TokenUI")

	local crafted = {}
	sim.impl["C_TradeSkillUI.CraftRecipe"] = function(recipeID)
		crafted[#crafted + 1] = recipeID
	end
	sim.impl["C_TradeSkillUI.GetCraftableCount"] = function()
		return 5
	end
	-- Five of the one reagent every test recipe uses are in the bags.
	local itemCount = sim.impl["C_Item.GetItemCount"]
	sim.impl["C_Item.GetItemCount"] = function(itemID, ...)
		if itemID == 2672 then
			return 5
		end
		return itemCount and itemCount(itemID, ...) or 0
	end
	local frame = sim:openProfessions(185)
	sim:advance(0.2)
	local page = frame.CraftingPage
	local first = page.SchematicForm:GetRecipeInfo()
	local target
	for _, row in ipairs(sim:recipeRows()) do
		if row.recipeInfo.learned and row.recipeInfo.recipeID ~= (first and first.recipeID) then
			target = row
			break
		end
	end
	assert(target, "a learned recipe other than the selected one")
	sim:click(target.frame, "LeftButton")
	sim:advance(0.3)
	local now = page.SchematicForm:GetRecipeInfo()
	assert(now and now.recipeID == target.recipeInfo.recipeID, "the sorted click selects the recipe")
	sim:click(page.CreateButton, "LeftButton")
	sim:advance(0.3)
	assert(#crafted == 1 and crafted[1] == target.recipeInfo.recipeID, "the client's Create crafts the recipe")
	sim:closeProfessions()

	local info = {
		itemID = POTION,
		stackCount = 1,
		iconFileID = 1,
		hyperlink = "|Hitem:2459|h[Swiftness Potion]|h",
		isLocked = false,
	}
	sim.impl["C_Container.GetContainerItemInfo"] = function()
		return info
	end
	sim.impl["C_Container.GetContainerNumSlots"] = function()
		return 16
	end
	local uses = {}
	sim.impl["C_Container.UseContainerItem"] = function(bag, slot)
		uses[#uses + 1] = { bag = bag, slot = slot }
	end
	sim.run(function()
		G.OpenAllBags()
	end)
	sim:advance(0.1)
	local button
	for _, itemButton in G.ContainerFrameCombinedBags:EnumerateValidItems() do
		if itemButton:GetBagID() == 0 and itemButton:GetID() == 1 then
			button = itemButton
			break
		end
	end
	assert(button, "the combined frame contains backpack slot 1")
	sim:click(button, "RightButton")
	-- The simulator records ADDON_ACTION_BLOCKED and ADDON_ACTION_FORBIDDEN as errors too.
	assert(#sim.errors == 0, Sim.describe(sim.errors))
	assert(#uses == 1, "the bag item is used once, got " .. #uses)
end)
