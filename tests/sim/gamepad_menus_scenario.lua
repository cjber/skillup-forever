-- luacheck: read globals scenario ADDON
-- #398: with the gamepad interface on, Blizzard's gamepad frame manager takes every menu that shows into its
-- focus in the same call, under the taint of whoever opened it, and the next secure window call then has its
-- protected SetPreferredGamepadInteractTarget refused. SkillUp's route profession picker is a Blizzard dropdown,
-- whose menu SkillUp's own SetupMenu configured, so under the gamepad interface a press on it steps to the next
-- profession instead of opening a menu. This walks that press both ways and checks that no menu is shown.
local ForeverCore = dofile("tests/forever_core.lua")

scenario("the route's profession picker leaves the gamepad focus to the game", {
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
		{
			skillLineID = 129,
			name = "First Aid",
			skill = 129,
			max = 300,
			recipes = {
				{ id = 3275, name = "Linen Bandage", learned = true },
			},
		},
	}
	-- Natives the gamepad frame manager calls as a panel hides, which the sim does not define.
	G.SpellCanTargetItem = G.SpellCanTargetItem or function()
		return false
	end
	G.SpellStopTargeting = G.SpellStopTargeting or function() end
	sim:loadBlizzard("Blizzard_FrameXML/SecureTemplates.lua")
	sim:loadBlizzard("Blizzard_FrameXML/SecureTemplates.xml")
	sim:setGamepad(true)
	sim:login()
	assert(G.InputUtil.IsGamepadUIEnabled(), "the gamepad interface is on")
	local FCM = G.GamepadMode.FrameControlsManager
	assert(FCM, "the gamepad frame manager exists")

	local ns
	for _, entry in ipairs(sim.loader.addons) do
		if entry.name == ADDON then
			ns = entry.ns
		end
	end
	assert(ns, "full addon namespace loaded")

	-- Every frame the gamepad frame manager takes into its focus: a menu shows through MenuProxy.OnShow.
	local shown = {}
	local frameShown = FCM.FrameShown
	FCM.FrameShown = function(self, frame, ...)
		shown[#shown + 1] = frame
		return frameShown(self, frame, ...)
	end

	sim:openProfessions(185)
	local tab = ns.Pages.SideTab()
	assert(tab, "the SkillUp side tab exists")
	sim:input(function()
		tab:GetScript("OnMouseUp")(tab, "LeftButton", true)
	end)
	sim:advance(0.2)
	local page
	for _, child in ipairs({ G.ProfessionsFrame:GetChildren() }) do
		if child.Profession and child.Profession.OpenMenu and child:IsShown() then
			page = child
		end
	end
	assert(page and page:IsShown(), "the route page is open")
	local dropdown = page.Profession
	assert(dropdown, "the route's profession picker exists")
	-- Cooking is the open profession, so it is the page's first selection.
	assert(dropdown:GetText() == "Cooking", "the picker starts on the open profession")

	-- What the template's OnMouseDown intrinsic runs, from a fresh input dispatch.
	local function PressDropdown()
		local before = #shown
		sim:input(function()
			dropdown:SetMenuOpen(not dropdown:IsMenuOpen())
		end)
		sim:advance(0.1)
		return before
	end

	local before = PressDropdown()
	assert(#shown == before, "a gamepad press on the picker shows no menu")
	assert(not dropdown:IsMenuOpen(), "and leaves the picker closed")
	assert(dropdown:GetText() == "First Aid", "and steps to the other profession")

	before = PressDropdown()
	assert(#shown == before, "a second gamepad press shows no menu")
	assert(not dropdown:IsMenuOpen(), "and leaves the picker closed")
	assert(dropdown:GetText() == "Cooking", "and wraps back to the first profession")

	-- With the gamepad interface off, the same press opens the menu, which then closes as usual.
	sim:setGamepad(false)
	assert(not G.InputUtil.IsGamepadUIEnabled(), "the gamepad interface is off")
	PressDropdown()
	assert(dropdown:IsMenuOpen(), "a mouse and keyboard press opens the menu")
	sim:input(function()
		dropdown:CloseMenu()
	end)
	sim:advance(0.1)
	assert(not dropdown:IsMenuOpen(), "the menu closes")

	sim:closeProfessions()
	sim:expectNoErrors(ADDON)
end)
