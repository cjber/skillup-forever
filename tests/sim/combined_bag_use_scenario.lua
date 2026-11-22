-- luacheck: read globals scenario ADDON Sim
-- #717: exercise the native combined-bag button after the Shift tooltip path from #708.
local ForeverCore = dofile("tests/forever_core.lua")

scenario("combined bags keep the hovered item usable after Shift", {
	addons = ForeverCore.addons(),
}, function(sim)
	local G = sim.G
	local POTION = 2459
	sim.items[POTION] = { name = "Swiftness Potion", lines = { "Use: Increases run speed." } }
	-- Load the native token tracker and the panels read by bag layout and right-click.
	-- Currency transfer is unrelated and is not part of this simulator boot.
	sim:loadBlizzard("Blizzard_TokenUI:Camelot/Blizzard_TokenUI")
	sim:loadBlizzard("Blizzard_UIPanels_Game:BankFrame|TradeFrame")
	sim:loadBlizzard("Blizzard_MailFrame")
	sim:loadBlizzard("Blizzard_FrameXML/Mainline/StackSplitFrame.lua")
	sim:loadBlizzard("Blizzard_FrameXML/Camelot/StackSplitFrame.xml")
	G.SetCVar("combinedBags", "1")
	sim:login()
	sim:event("ADDON_LOADED", "Blizzard_TokenUI")
	local ns
	for _, entry in ipairs(sim.loader.addons) do
		if entry.name == ADDON then
			ns = entry.ns
		end
	end
	assert(ns, "the full addon namespace loaded")
	-- The report's mode: the tooltip shows the recipe uses only while Shift is held.
	ns.db.reagentTooltip = "route"

	-- The bag's first slot holds the potion, and the client's tooltip reads it from there.
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
	sim.impl["C_TooltipInfo.GetBagItem"] = function()
		return sim.impl["C_TooltipInfo.GetItemByID"](POTION)
	end
	-- The sim's GameTooltip:GetItem answers nil for every tooltip. The client answers a bag item's name, link and
	-- id, which is what an addon tempting the tooltip to refresh itself would read.
	rawset(G.GameTooltip, "GetItem", function()
		return "Swiftness Potion", info.hyperlink, POTION
	end)
	local uses = {}
	sim.impl["C_Container.UseContainerItem"] = function(bag, slot)
		uses[#uses + 1] = { bag = bag, slot = slot }
	end
	sim.run(function()
		G.OpenAllBags()
	end)
	sim:advance(0.1)
	assert(G.ContainerFrameSettingsManager:IsUsingCombinedBags(), "the client's combined-bag setting is active")
	local frame = G.ContainerFrameCombinedBags
	assert(frame and frame:IsShown(), "the client's bags are open")
	local button
	for _, itemButton in frame:EnumerateValidItems() do
		if itemButton:GetBagID() == 0 and itemButton:GetID() == 1 then
			button = itemButton
			break
		end
	end
	assert(button, "the combined frame contains backpack slot 1")
	sim:hover(button)
	assert(G.GameTooltip:IsShown(), "the client drew the item's tooltip")
	assert(G.GameTooltip:NumLines() > 0, "the tooltip has the client's lines")

	-- Toggle the modifier the report used while the native item tooltip is visible.
	sim.modifiers.shift = true
	sim:event("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
	sim.modifiers.shift = false
	sim:event("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
	sim:click(button, "RightButton")
	-- The simulator records ADDON_ACTION_BLOCKED and ADDON_ACTION_FORBIDDEN as errors too.
	assert(#sim.errors == 0, Sim.describe(sim.errors))
	assert(#uses == 1, "native right-click must use the item exactly once, got " .. #uses)
	assert(uses[1].bag == 0 and uses[1].slot == 1, "native right-click must use backpack slot 1")

	-- Every field the addon wrote on the client's tooltip. Reading a tooltip field from addon code and asking the
	-- client to rebuild the tooltip both land here. This also catches #708 before a later protected call.
	local written = {}
	for key, slot in pairs(sim.taint.slots[G.GameTooltip] or {}) do
		if slot.addon == ADDON then
			written[#written + 1] = tostring(key)
		end
	end
	table.sort(written)
	assert(
		#written == 0,
		"Shift over a bag item wrote the client's tooltip from SkillUpForever: " .. table.concat(written, ", ")
	)
end)

scenario("combined bags keep a buff food item usable with SkillUp lines, Shift held and released", {
	addons = ForeverCore.addons(),
}, function(sim)
	local G = sim.G
	local FOOD = 2680 -- Spiced Wolf Meat (Cooking buff food in ns.BuffItems)
	local REAGENT = 2672 -- Stringy Wolf Meat (reagent in Cooking recipes and tracked route)
	sim.items[FOOD] = {
		name = "Spiced Wolf Meat",
		sell = 5,
		lines = {
			"Use: Restores 61.2 health over 18 sec. Must remain seated while eating. "
				.. "If you spend at least 10 seconds eating you will become well fed and gain 5% XP.",
		},
	}
	sim.items[REAGENT] = { name = "Stringy Wolf Meat", lines = { "Cooking Reagent" } }
	sim:loadBlizzard("Blizzard_TokenUI:Camelot/Blizzard_TokenUI")
	sim:loadBlizzard("Blizzard_UIPanels_Game:BankFrame|TradeFrame")
	sim:loadBlizzard("Blizzard_MailFrame")
	sim:loadBlizzard("Blizzard_FrameXML/Mainline/StackSplitFrame.lua")
	sim:loadBlizzard("Blizzard_FrameXML/Camelot/StackSplitFrame.xml")
	G.SetCVar("combinedBags", "1")
	sim.world.professions = {
		{
			skillLineID = 185,
			name = "Cooking",
			skill = 20,
			max = 75,
			categories = { { id = 1, name = "Food" } },
			recipes = {
				{
					id = 2539,
					name = "Spiced Wolf Meat",
					category = 1,
					itemID = FOOD,
					reagents = { { REAGENT, 1 }, { 2678, 1 } },
				},
			},
		},
	}
	sim:login()
	sim:event("ADDON_LOADED", "Blizzard_TokenUI")
	local ns
	for _, entry in ipairs(sim.loader.addons) do
		if entry.name == ADDON then
			ns = entry.ns
		end
	end
	assert(ns, "the full addon namespace loaded")
	ns.db.reagentTooltip = "route"
	ns.SetTracked(185, true)

	sim:putInBag(0, 1, FOOD, 5)
	sim:putInBag(0, 2, REAGENT, 5)
	sim.impl["C_TooltipInfo.GetBagItem"] = function(bag, slot)
		local itemID = G.C_Container.GetContainerItemID(bag, slot)
		return itemID and sim.impl["C_TooltipInfo.GetItemByID"](itemID) or nil
	end
	local uses = {}
	local useContainerItem = sim.impl["C_Container.UseContainerItem"]
	sim.impl["C_Container.UseContainerItem"] = function(bag, slot, ...)
		uses[#uses + 1] = { bag = bag, slot = slot, taint = sim.taint.current }
		return useContainerItem(bag, slot, ...)
	end
	-- The simulator defaults IsModifiedClick to false even when its Shift key is down.
	local splitOnShift = true
	rawset(G, "IsModifiedClick", function(action)
		return splitOnShift and sim.modifiers.shift and (action == nil or action == "SPLITSTACK")
	end)

	local function hasLine(pattern)
		for index = 1, G.GameTooltip:NumLines() do
			local left = G["GameTooltipTextLeft" .. index]
			local text = left and left:GetText()
			if text and text:find(pattern, 1, true) then
				return true
			end
		end
		return false
	end

	sim.run(function()
		G.OpenAllBags()
	end)
	sim:advance(0.1)
	assert(G.ContainerFrameSettingsManager:IsUsingCombinedBags(), "the client's combined-bag setting is active")
	local frame = G.ContainerFrameCombinedBags
	assert(frame and frame:IsShown(), "the client's bags are open")
	local foodButton, reagentButton
	for _, itemButton in frame:EnumerateValidItems() do
		if itemButton:GetBagID() == 0 and itemButton:GetID() == 1 then
			foodButton = itemButton
		elseif itemButton:GetBagID() == 0 and itemButton:GetID() == 2 then
			reagentButton = itemButton
		end
	end
	assert(foodButton and reagentButton, "combined bags hold both food and reagent buttons")

	-- Draw SkillUp's route and Shift-expanded reagent lines first.
	sim:hover(reagentButton)
	assert(hasLine("Route:"), "SkillUp drew route line on the reagent tooltip")
	assert(hasLine("Shift:"), "SkillUp drew Shift hint on the reagent tooltip")
	sim.modifiers.shift = true
	sim:event("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
	sim:leave()
	sim:hover(reagentButton)
	assert(hasLine("Used in"), "SkillUp drew Used in lines while Shift was held")
	sim.modifiers.shift = false
	sim:event("MODIFIER_STATE_CHANGED", "LSHIFT", 0)

	-- Hover the buff food item (SkillUp draws Made by Cooking) and right-click with Shift not held.
	sim:leave()
	sim:hover(foodButton)
	assert(G.GameTooltip:IsShown(), "the client drew the food item tooltip")
	assert(hasLine("Made by Cooking"), "SkillUp drew Made by Cooking on the buff food tooltip")
	sim:click(foodButton, "RightButton")
	assert(#uses == 1, "unmodified right-click must use the food item once, got " .. #uses)
	assert(uses[1].bag == 0 and uses[1].slot == 1, "right-click must target backpack slot 1")
	assert(uses[1].taint == nil, "UseContainerItem must run untainted, got " .. tostring(uses[1].taint))

	-- Hold Shift with the food tooltip shown and right-click.
	sim.modifiers.shift = true
	sim:event("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
	sim:leave()
	sim:hover(foodButton)
	assert(G.GameTooltip:IsShown(), "food tooltip is shown while Shift is held")
	sim:click(foodButton, "RightButton")
	assert(#uses == 1, "Shift bound to stack splitting must bypass normal item use")
	assert(G.StackSplitFrame:IsShown(), "the native Shift click opened the stack splitter")
	sim.run(function()
		G.StackSplitFrame:Hide()
	end)

	-- Shift can also be held with no modified-click binding to consume the click.
	splitOnShift = false
	sim:hover(foodButton)
	sim:click(foodButton, "RightButton")
	assert(#uses == 2, "Shift without a modified-click binding must reach item use")

	-- Release Shift, fire post-eat bag and aura events, let GameTooltip OnUpdate tick, and right-click again.
	sim.modifiers.shift = false
	sim:event("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
	sim:putInBag(0, 1, FOOD, 4)
	sim:event("UNIT_AURA", "player", { isFullUpdate = false })
	sim:leave()
	sim:hover(foodButton)
	sim:advance(0.3)
	local before = #uses
	sim:click(foodButton, "RightButton")
	assert(#uses == before + 1, "right-click after Shift release and eat events must use the food item")
	-- Stock tab and SkillUp's Reagents tab both leave the native bag sell path in charge.
	rawset(G, "GetMerchantNumItems", function()
		return 1
	end)
	rawset(G, "GetMerchantItemID", function()
		return REAGENT
	end)
	rawset(G, "GetMerchantItemLink", function()
		return sim.itemLink(REAGENT)
	end)
	sim.impl["C_MerchantFrame.GetItemInfo"] = function()
		return {
			name = "Stringy Wolf Meat",
			texture = 134400,
			price = 10,
			stackCount = 1,
			numAvailable = -1,
			isPurchasable = true,
			isUsable = true,
		}
	end
	sim:leave()
	local merchant = sim:openMerchant()
	assert(merchant and merchant:IsShown(), "the native merchant is open")
	local reagentsTab = G.SkillUpForeverMerchantTab
	assert(reagentsTab and reagentsTab:IsShown(), "SkillUp offered a tracked reagent: " .. Sim.describe(sim.errors))
	for _, tab in ipairs({ G.MerchantFrameTab1, reagentsTab }) do
		sim:click(tab, "LeftButton")
		assert(G.SkillUpForeverMerchantPage:IsShown() == (tab == reagentsTab), "the requested merchant tab is active")
		sim:hover(foodButton)
		assert(hasLine("Made by Cooking"), "SkillUp drew its food line at the merchant")
		local held = sim.bagCount(FOOD)
		local money = sim.world.player.money
		local calls = #uses
		sim:click(foodButton, "RightButton")
		assert(#uses == calls + 1, "the native merchant path reached item use")
		assert(not sim.bagCount(FOOD), "the simulator sold the food stack")
		assert(sim.world.player.money == money + held * 5, "the sale credited the stack's value")
		sim:leave()
		sim:putInBag(0, 1, FOOD, 4)
	end
	sim:closeMerchant()
	sim:hover(foodButton)
	before = #uses
	sim:click(foodButton, "RightButton")
	assert(#uses == before + 1 and sim.bagCount(FOOD) == 4, "the click after closing the merchant did not sell")

	for _, entry in ipairs(uses) do
		assert(entry.bag == 0 and entry.slot == 1, "every use targeted backpack slot 1")
		assert(entry.taint == nil, "UseContainerItem must stay untainted, got " .. tostring(entry.taint))
	end
	assert(#sim.errors == 0, Sim.describe(sim.errors))

	for label, obj in pairs({ GameTooltip = G.GameTooltip, foodButton = foodButton, MerchantFrame = merchant }) do
		local written = {}
		for key, slot in pairs(sim.taint.slots[obj] or {}) do
			if slot.addon == ADDON then
				written[#written + 1] = tostring(key)
			end
		end
		table.sort(written)
		assert(
			#written == 0,
			label .. " carried SkillUpForever taint after food hover and use: " .. table.concat(written, ", ")
		)
	end
end)
