-- luacheck: read globals scenario ADDON
-- #734: a foreign replacement UI can park the native crafting page offscreen.
-- SkillUp owns its content bounds, without moving or restoring the native page.
local ForeverCore = dofile("tests/forever_core.lua")

scenario("SkillUp pages stay inside the host when the native page is parked", {
	addons = ForeverCore.addons(),
}, function(sim)
	local G = sim.G
	sim.world.professions = {
		{ skillLineID = 129, name = "First Aid", skill = 1, max = 75 },
		{ skillLineID = 164, name = "Blacksmithing", skill = 1, max = 75 },
	}
	sim:login()
	for _, entry in ipairs(sim.loader.addons) do
		if entry.name == ADDON then
			entry.ns.RecipeData = {}
			entry.ns.db.showBuffsTab = true -- off by default (#811)
		end
	end
	local host = sim:openProfessions(129)
	local function find(root, predicate)
		for _, child in ipairs({ root:GetChildren() }) do
			if predicate(child) then
				return child
			end
			local found = find(child, predicate)
			if found then
				return found
			end
		end
	end
	local side = assert(find(host, function(frame)
		return frame.tooltipText == "SkillUp"
	end))
	local route = assert(find(host, function(frame)
		return frame.RouteList ~= nil
	end))
	local function tab(text)
		return assert(find(host, function(frame)
			return frame.GetText and frame:GetText() == text and frame:GetScript("OnClick")
		end))
	end
	local function bounds(frame, label)
		assert(frame:GetLeft() >= host:GetLeft(), label .. " left outside host")
		assert(frame:GetRight() <= host:GetRight(), label .. " right outside host")
		assert(frame:GetTop() <= host:GetTop(), label .. " top outside host")
		assert(frame:GetBottom() >= host:GetBottom(), label .. " bottom outside host")
		assert(
			frame:GetWidth() == host:GetWidth() and frame:GetHeight() == host:GetHeight(),
			label .. " lost host size"
		)
	end
	local function selectSide()
		sim.widgets.dispatch(side, "OnMouseUp", "LeftButton", true)
		sim:advance(0.1)
	end
	selectSide()
	sim:click(tab("Buffs"))
	sim:advance(0.1)
	local buffs = assert(find(host, function(frame)
		return frame.RowsData ~= nil
	end))
	sim:click(tab("Route"))
	sim:advance(0.1)
	bounds(G.SkillUpForeverProfessionTabPage, "normal shell")
	bounds(route, "normal route")
	bounds(buffs, "normal buffs")
	local height = host:GetHeight()

	-- A synthetic foreign addon reproduces the proven anchoring mechanism only.
	-- Full actual-source ClassicUI compatibility is checked separately in scratch.
	assert(sim:runAs(
		"ForeignProfessionLayout",
		[[
		local page = ProfessionsFrame.CraftingPage
		page:SetSize(600, 500)
		page:ClearAllPoints()
		page:SetPoint("TOPLEFT", ProfessionsFrame, "TOPLEFT", 6000, 0)
		page:SetAlpha(0)
	]]
	))
	local native = host.CraftingPage
	local function parked()
		assert(native:GetLeft() == host:GetLeft() + 6000, "SkillUp moved the foreign native page")
		assert(native:GetWidth() == 600 and native:GetHeight() == 500, "SkillUp resized the foreign native page")
		assert(native:GetAlpha() == 0, "SkillUp restored the foreign native page")
	end
	local function visible(page, label)
		assert(page:IsShown(), label .. " not shown")
		bounds(G.SkillUpForeverProfessionTabPage, label .. " shell")
		bounds(page, label)
		assert(host:GetHeight() == height, "tab switch changed host height")
		parked()
	end
	visible(route, "parked route")
	sim:click(tab("Buffs"))
	sim:advance(0.1)
	visible(buffs, "parked buffs")
	sim:click(tab("Route"))
	sim:advance(0.1)
	visible(route, "route return")

	host:SetHeight(height + 80)
	height = host:GetHeight()
	sim:advance(0.1)
	visible(route, "resized route")
	sim:enterCombat()
	sim:click(tab("Buffs"))
	sim:leaveCombat()
	sim:advance(0.1)
	visible(buffs, "deferred combat selection")

	sim:openProfessions(164)
	sim:advance(0.1)
	height = host:GetHeight()
	selectSide()
	-- Last selected Buffs is retained across profession changes.
	visible(buffs, "changed profession")
	sim:closeProfessions()
	sim:expectNoErrors(ADDON)
	sim:expectNoGamepadTaint(ADDON)
	local reloaded = sim:reload()
	reloaded:openProfessions(129)
	reloaded:expectNoErrors(ADDON)
end)
