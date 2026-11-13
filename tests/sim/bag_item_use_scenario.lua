-- luacheck: read globals scenario ADDON
-- #708: Shift over a bag item's tooltip left SkillUp's name on the client's GameTooltip, and the game then refused
-- to use the item ("tried to call the protected function UseContainerItem()"). The tooltip's refresh state must
-- stay the client's: hovering an item and pressing Shift may only draw our own lines, never ask the client to
-- refill its tooltip or write a field on it.
local ForeverCore = dofile("tests/forever_core.lua")

scenario("Shift over a bag item's tooltip leaves the client's tooltip untainted", {
	addons = ForeverCore.addons(),
}, function(sim)
	local G = sim.G
	local POTION = 2459
	sim.items[POTION] = { name = "Swiftness Potion", lines = { "Use: Increases run speed." } }
	sim:login()
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
	-- The bag layout reads the bank's frame to keep the bags clear of it; the bank UI is not booted.
	if not G.BankFrame then
		local bank = G.CreateFrame("Frame")
		bank:Hide()
		rawset(bank, "GetActiveBankType", function()
			return nil
		end)
		G.BankFrame = bank
	end
	if G.BankUtil_IsAccountBankDepositRefundable == nil then
		G.BankUtil_IsAccountBankDepositRefundable = function()
			return false
		end
	end

	local frame = sim:openBags()
	assert(frame and frame:IsShown(), "the client's bags are open")
	local buttons = {}
	for _, itemButton in frame:EnumerateValidItems() do
		buttons[#buttons + 1] = itemButton
	end
	assert(#buttons > 0, "the first bag slot holds an item button")
	sim:hover(buttons[1])
	assert(G.GameTooltip:IsShown(), "the client drew the item's tooltip")
	assert(G.GameTooltip:NumLines() > 0, "the tooltip has the client's lines")

	-- The Shift the report pressed: the route mode's hint and uses swap.
	sim:event("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
	sim:event("MODIFIER_STATE_CHANGED", "LSHIFT", 0)

	-- Every field the addon wrote on the client's tooltip. Reading a tooltip field from addon code and asking the
	-- client to rebuild the tooltip both land here; the item use path then reads what it finds.
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
