-- luacheck: read globals scenario ADDON
-- #454: Blizzard's Filter menu is opened by the client's own gamepad footer. A section added to it by
-- Menu.ModifyMenu is addon code that reads the saved sort and buff settings, so the client builds the menu
-- under SkillUp's taint and the gamepad frame manager's next protected call is refused. With the gamepad
-- interface on, SkillUp leaves that menu alone; turning the interface off puts the section back.
local ForeverCore = dofile("tests/forever_core.lua")

scenario("the gamepad interface leaves Blizzard's Filter menu to the game", {
	addons = ForeverCore.addons(),
}, function(sim)
	local G = sim.G
	sim.world.professions = {
		{
			skillLineID = 185,
			name = "Cooking",
			skill = 185,
			max = 300,
			recipes = {
				{ id = 2538, name = "Charred Wolf Meat", learned = true },
			},
		},
	}
	sim:setGamepad(true)
	assert(G.InputUtil.IsGamepadUIEnabled(), "the gamepad interface is on")

	-- Every menu tag SkillUp modifies, and every time it withdraws one.
	local registered, unregistered = {}, {}
	local modifyMenu = G.Menu.ModifyMenu
	G.Menu.ModifyMenu = function(tag, callback)
		registered[#registered + 1] = tag
		local handle = modifyMenu(tag, callback)
		if type(handle) == "table" and type(handle.Unregister) == "function" then
			local unregister = handle.Unregister
			function handle:Unregister(...)
				unregistered[#unregistered + 1] = tag
				return unregister(self, ...)
			end
		end
		return handle
	end

	sim:login()
	sim:openProfessions(185)
	assert(
		#registered == 0,
		"with the gamepad interface on, no Blizzard menu is modified: " .. table.concat(registered, ", ")
	)

	-- With the interface off the section is registered as before.
	sim:setGamepad(false)
	assert(not G.InputUtil.IsGamepadUIEnabled(), "the gamepad interface is off")
	assert(#registered == 1, "turning it off adds the Sort by section once")
	assert(registered[1] == "MENU_PROFESSIONS_FILTER", "on the recipe list's Filter menu")

	-- Turning it back on withdraws it, so a later gamepad filter press builds Blizzard's own menu.
	sim:setGamepad(true)
	assert(#registered == 1, "turning it on registers nothing new")
	assert(#unregistered == 1, "and withdraws the section")
	assert(unregistered[1] == "MENU_PROFESSIONS_FILTER", "from the recipe list's Filter menu")

	sim:closeProfessions()
	sim:expectNoErrors(ADDON)
end)
