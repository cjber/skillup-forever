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
