-- luacheck: read globals scenario ADDON
-- #718: a fresh installation exposes SkillUp's side tab with only its required companion installed.
local ForeverCore = dofile("tests/forever_core.lua")

local professions = {
	{ skillLineID = 171, name = "Alchemy", skill = 1, max = 75 },
	{ skillLineID = 164, name = "Blacksmithing", skill = 1, max = 75 },
	{ skillLineID = 333, name = "Enchanting", skill = 1, max = 75 },
	{ skillLineID = 202, name = "Engineering", skill = 1, max = 75 },
	{ skillLineID = 165, name = "Leatherworking", skill = 1, max = 75 },
	{ skillLineID = 197, name = "Tailoring", skill = 1, max = 75 },
	{ skillLineID = 185, name = "Cooking", skill = 1, max = 75 },
	{ skillLineID = 129, name = "First Aid", skill = 1, max = 75 },
}
for _, profession in ipairs(professions) do
	scenario("Fresh SkillUp side tab: " .. profession.name, { addons = ForeverCore.addons() }, function(sim)
		local client = sim
		client.world.professions = { profession }
		client:login()
		for pass = 1, 2 do
			local ns
			for _, entry in ipairs(client.loader.addons) do
				if entry.name == ADDON then
					ns = entry.ns
				end
			end
			assert(#client.loader.addons == 2, "only SkillUp and ForeverCore loaded")
			assert(ns and ns.db.showProfessionTabs and ns.db.showRouteTab, "fresh tab defaults are on")
			local host = client:openProfessions(profession.skillLineID)
			local side = assert(ns.Pages.SideTab(), profession.name .. ": side tab registered")
			assert(side:IsShown(), profession.name .. ": side tab shown")
			assert(ns.Pages.Count() == 4, "all four SkillUp pages registered")
			assert(not ns.Pages.BottomTab("route"):IsShown(), "bottom tabs wait for the SkillUp side tab")
			client.widgets.dispatch(side, "OnMouseUp", "LeftButton", true)
			client:advance(0.1)
			assert(ns.Pages.BottomTab("route"):IsShown(), profession.name .. ": route becomes discoverable")
			-- Supply and Buffs start off until the player turns them on in settings (#811).
			for _, id in ipairs({ "supply", "buffs" }) do
				assert(not ns.Pages.BottomTab(id):IsShown(), profession.name .. ": " .. id .. " starts off")
			end
			assert(host:IsShown(), "the profession host stays open")
			client:expectNoErrors(ADDON)
			client:expectNoGamepadTaint(ADDON)
			if pass == 1 then
				client = client:reload()
			end
			client.world.professions = { profession }
		end
	end)
end
