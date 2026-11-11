-- luacheck: read globals scenario ADDON
-- #555: SkillUp's tab in the Professions window is ForeverCore.ProfessionTabs'. A Commissions-like second tab
-- sits beside it, and the walk the player makes (SkillUp, a client tab, a profession change, back, the other
-- addon's tab) leaves exactly one page shown each time. The crafting page and every addon page keep the window's
-- one width, which follows the widest learned profession and whose room the list fills; the client's own overview
-- page keeps the client's width. A tab or profession switch moves neither the width nor the anchor.
local ForeverCore = dofile("tests/forever_core.lua")

scenario("SkillUp's professions tab shares the window with another addon", {
	addons = ForeverCore.addons(),
}, function(sim)
	local G = sim.G
	sim.world.professions = {
		{
			skillLineID = 164,
			name = "Blacksmithing",
			skill = 30,
			max = 75,
			categories = { { id = 1, name = "Materials" } },
			-- The long name widens the window for every profession until a wider one is learned.
			recipes = {
				{
					id = 2660,
					name = "Rough Sharpening Stone of an Unusually Long Blacksmithing Name",
					category = 1,
					itemID = 2862,
				},
			},
		},
		{
			skillLineID = 333,
			name = "Enchanting",
			skill = 20,
			max = 75,
			categories = { { id = 1, name = "Materials" } },
			recipes = { { id = 7421, name = "Runed Copper Rod", category = 1, itemID = 6218 } },
		},
	}
	sim:login()
	local ns
	for _, entry in ipairs(sim.loader.addons) do
		if entry.name == ADDON then
			ns = entry.ns
		end
	end
	assert(ns, "the full addon namespace loaded")

	-- The client says these recipes are known; the wide list measures what it knows.
	local key = ns.CharacterKey()
	ns.db.learned = ns.db.learned or {}
	ns.db.learned[key] = ns.db.learned[key] or {}
	ns.db.learned[key][2660] = true
	ns.db.learned[key][7421] = true

	local pf = sim:openProfessions(164)
	assert(pf and pf:IsShown(), "the client's Professions window is open")
	local core = G.ForeverCore.ProfessionTabs
	assert(core, "ForeverCore's ProfessionTabs module is loaded")

	local function find(root, matches)
		for _, child in ipairs({ root:GetChildren() }) do
			if matches(child) then
				return child
			end
			local found = find(child, matches)
			if found then
				return found
			end
		end
	end

	local skillupTab = assert(
		find(pf, function(frame)
			return frame.tooltipText == "SkillUp"
		end),
		"SkillUp's side tab is in the client's column"
	)
	local routePage = assert(
		find(pf, function(frame)
			return frame.Profession ~= nil and frame.RouteList ~= nil
		end),
		"the route page was built"
	)

	-- The wide list's one width: the client's 673 plus the room the widest learned profession's rows need
	-- beyond the client's own 304-wide list, and the list fills that room beside the 360-wide schematic.
	local recipeList = pf.CraftingPage.RecipeList
	local function listRoom(window)
		return window - 5 - 2 - 360 - 2
	end
	local widened = pf:GetWidth()
	assert(widened > 673, "the long learned recipe did not widen the window: " .. tostring(widened))
	assert(
		recipeList:GetWidth() == listRoom(widened),
		"the list did not fill the window's room: " .. tostring(recipeList:GetWidth())
	)

	-- A second addon's tab and page, registered the way Commissions registers its own.
	local registered = sim:runAs(
		ADDON,
		[[
		local ns = ...
		local page = CreateFrame("Frame", "ProfessionTabsScenarioOtherPage", UIParent)
		local tab = ForeverCore.ProfessionTabs.Register("commissions-like", {
			icon = "Interface\\Icons\\INV_Misc_Note_01",
			tooltip = "Commissions-like",
			page = page,
		})
		ForeverCore.ProfessionTabsScenario = { page = page, tab = tab }
	]],
		ns
	)
	assert(registered, "the other addon's tab registered without an error")
	local otherPage = G.ForeverCore.ProfessionTabsScenario.page
	local otherTab = G.ForeverCore.ProfessionTabsScenario.tab
	assert(otherPage and otherTab, "the other addon's page and tab were registered")

	local width, point = pf:GetWidth(), { pf:GetPoint(1) }
	local function stableAt(expected, label)
		assert(pf:GetWidth() == expected, label .. ": the window width changed to " .. tostring(pf:GetWidth()))
		local now = { pf:GetPoint(1) }
		assert(#now == #point, label .. ": the window anchor changed")
		for index = 1, #point do
			assert(now[index] == point[index], label .. ": the window anchor changed at " .. index)
		end
	end
	-- Every page but the client's own overview keeps the widened width.
	local function stable(label)
		stableAt(width, label)
	end

	local function press(tab)
		sim.widgets.dispatch(tab, "OnMouseUp", "LeftButton", true)
		sim:advance(0.05)
	end

	-- Tab art is how a check reads: the template shows its selected texture when SetChecked is true.
	local function checked(tab)
		return tab.SelectedTexture and tab.SelectedTexture:IsShown()
	end

	local function onePage(label, expected)
		local shown = 0
		for _, page in ipairs({ routePage, otherPage }) do
			if page:IsShown() then
				shown = shown + 1
			end
		end
		assert(shown == 1, label .. ": expected one page shown, got " .. shown)
		assert(expected:IsShown(), label .. ": the wrong page is shown")
		stable(label)
	end

	press(skillupTab)
	assert(core.Selected() == "skillup", "the SkillUp tab is selected")
	assert(checked(skillupTab), "and checked")
	assert(pf.CraftingPage:IsShown(), "the client's own crafting page is left shown underneath")
	onePage("after SkillUp", routePage)

	press(pf.ProfessionsOverviewTab)
	assert(core.Selected() == nil, "a client side tab hands the window back")
	assert(not routePage:IsShown() and not otherPage:IsShown(), "and hides both addons' pages")
	assert(not checked(skillupTab), "and unchecks the SkillUp tab")
	assert(pf.BookPage:IsShown(), "and shows the client's own overview page")
	-- The overview page lays its panels out at the client's own width and the client never resizes the window for
	-- it, so it keeps that width: a wider window only stretched empty art past its panels.
	stableAt(673, "after a client side tab")

	sim:openProfessions(333)
	sim:advance(0.2)
	assert(core.Selected() == nil, "a profession change hands the window back")
	assert(not routePage:IsShown() and not otherPage:IsShown(), "with no addon page shown")
	assert(pf.CraftingPage:IsShown(), "and the client's own crafting page takes the window again")
	-- Back on the crafting page, the widened width returns.
	stable("after a profession change")
	assert(
		pf:GetWidth() == widened,
		"the window changed width for another learned profession: " .. tostring(pf:GetWidth())
	)
	assert(recipeList:GetWidth() == listRoom(widened), "the list changed with the profession")

	press(skillupTab)
	onePage("back on SkillUp", routePage)

	press(otherTab)
	assert(core.Selected() == "commissions-like", "the other addon's tab takes the window")
	assert(otherPage:IsShown(), "and shows its page")
	assert(not routePage:IsShown(), "while SkillUp's page hides")
	stable("after the other addon's tab")

	press(skillupTab)
	assert(core.Selected() == "skillup", "SkillUp's tab comes back")
	onePage("back on SkillUp again", routePage)

	-- The setting off clears the width, and on raises the same one again.
	ns.db.wideRecipeList = false
	ns.Changed("settings")
	sim:advance(0.2)
	assert(pf:GetWidth() == 673, "the wide list off did not give the client width back: " .. tostring(pf:GetWidth()))
	assert(recipeList:GetWidth() == 304, "the wide list off did not give the client list width back")
	ns.db.wideRecipeList = true
	ns.Changed("settings")
	sim:advance(0.2)
	assert(pf:GetWidth() == widened, "the wide list on did not raise the window width again")
	assert(recipeList:GetWidth() == listRoom(widened), "the wide list on did not fill the room again")

	-- Learning a profession with a wider row recomputes the one width for every profession.
	table.insert(sim.world.professions, {
		skillLineID = 197,
		name = "Tailoring",
		skill = 1,
		max = 75,
		categories = { { id = 1, name = "Materials" } },
		recipes = {
			{ id = 12075, name = "Tailoring Pattern of a Considerably Longer Learned Name Than Before", category = 1 },
		},
	})
	ns.db.learned[key][12075] = true
	sim:event("SKILL_LINES_CHANGED")
	sim:advance(0.2)
	local learnedWidth = pf:GetWidth()
	assert(learnedWidth > widened, "learning a wider profession did not widen the window: " .. tostring(learnedWidth))
	assert(recipeList:GetWidth() == listRoom(learnedWidth), "the list did not fill the room learning a profession made")

	sim:closeProfessions()
	sim:expectNoErrors(ADDON)
	sim:expectNoGamepadTaint(ADDON)
end)
