-- Run from the repository root: luajit tests/profession_tabs_spec.lua
-- SkillUp's Professions side tab is ForeverCore.ProfessionTabs'. Core owns where the tab sits and which page is
-- on show; SkillUp keeps its own pages and bottom tabs. Selecting SkillUp, a client tab and coming back leaves
-- exactly one page shown, with the window's width and anchor where they were.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local DATA = {
	Thresholds = { [1] = { 1, 30, 45, 60 } },
	RecipeData = {
		[1] = {
			skillLine = 129,
			reagents = { { itemID = 3, quantity = 1 } },
			output = { itemID = 50, quantity = 1 },
		},
	},
	TrainerFees = {},
	TrainerRanks = { [129] = {} },
	ItemSellPrices = {},
	GatheredBy = {},
	VendorPrices = { [3] = 10 },
	ProfessionTrainers = {},
}

local function Prepare(c)
	local G = c.G
	c.professions = { { name = "First Aid", icon = 1, rank = 40, max = 75, id = 129 } }
	c.spells[1] = "Linen Bandage"
	c.known[1] = true
	c.items[3] = { name = "Linen Cloth", sell = 10 }
	c.items[50] = { name = "Linen Bandage", sell = 5 }
	c.live[1] = {
		info = {
			recipeID = 1,
			name = "Linen Bandage",
			learned = true,
			maxTrivialLevel = 60,
			numSkillUps = 1,
			relativeDifficulty = G.Enum.TradeskillRelativeDifficulty.Optimal,
			canSkillUp = true,
		},
		requirements = {},
	}

	local function Frame(name, parent)
		return G.CreateFrame("Frame", name, parent)
	end

	local frame = Frame("ProfessionsFrame", G.UIParent)
	frame:SetSize(673, 594)
	frame:SetPoint("TOPLEFT", G.UIParent, "TOPLEFT", 51, -34)
	local crafting = Frame("CraftingPage", frame)
	crafting:SetSize(673, 594)
	local book = Frame("BookPage", frame)
	book:Hide()
	local recipeList = Frame(nil, crafting)
	recipeList:SetWidth(304)
	recipeList.ScrollBox = Frame(nil, recipeList)
	recipeList.ScrollBox.GetDataProvider = function()
		return nil
	end
	recipeList.ScrollBox.RegisterCallback = function(self, event, callback)
		self.callbacks = self.callbacks or {}
		self.callbacks[event] = callback
	end
	recipeList.IsVisible = function(self)
		return self:IsShown()
	end
	crafting.RecipeList = recipeList
	crafting.SchematicForm = Frame(nil, crafting)
	crafting.SchematicForm:SetWidth(360)
	crafting.SchematicForm.GetRecipeInfo = function()
		return c.live[1].info
	end
	crafting.CreateAllButton = Frame(nil, crafting)
	crafting.CreateButton = Frame(nil, crafting)
	frame.CraftingPage, frame.BookPage = crafting, book
	frame.Pages = { crafting, book }
	frame.ProfessionsOverviewTab = Frame(nil, frame)
	frame.ProfessionsOverviewTab:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -60)
	frame.ProfessionsOverviewTab:SetSize(43, 55)
	frame.rightProfessionTabs = {}
	frame.professionInfo = { professionID = 129, professionName = "First Aid" }
	frame.RefreshRightTabs = function() end
	G.ProfessionsFrame = frame

	G.Professions = {
		GetProfessionInfo = function()
			return {
				skillLevel = 40,
				maxSkillLevel = 75,
				displayName = "First Aid",
				skillModifier = 0,
				professionName = "First Aid",
				professionID = 129,
				parentProfessionName = "First Aid",
				parentProfessionID = 129,
			}
		end,
		GetHighestLearnedRecipe = function(info)
			return info
		end,
	}
end

local c = Client.load({ saved = nil, boot = true, data = DATA })
local ns, G = c.ns, c.G
Prepare(c)

local core = G.ForeverCore.ProfessionTabs
assert(core, "ForeverCore's ProfessionTabs module is loaded")
equal(core.Selected(), nil, "no tab is selected before the window opens")

-- Blizzard_Professions arriving is when the pages and their one core tab are built.
c.LoadAddOn("Blizzard_Professions")
local frame = G.ProfessionsFrame
local tab = ns.Pages.SideTab()
assert(tab, "SkillUp registered its side tab with core")
equal(tab.tooltipText, "SkillUp", "core's tab is SkillUp's")
equal(tab.Icon.texture, ns.ICON, "and wears the addon's icon")
equal(core.Selected(), nil, "registering the tab does not select it")

local function RoutePage()
	for _, child in ipairs({ frame:GetChildren() }) do
		if child.Profession and child.RouteList then
			return child
		end
	end
end
local route = assert(RoutePage(), "the route page was built")

-- Core widens the window to its shared custom-page width while an addon page is selected, and gives the client's
-- own width back with the window.
local CUSTOM_WIDTH = 850
local width, point = frame:GetWidth(), { frame:GetPoint(1) }
local function Stable(label)
	local expected = core.Selected() and CUSTOM_WIDTH or width
	equal(frame:GetWidth(), expected, label .. ": the window width changed")
	local now = { frame:GetPoint(1) }
	equal(#now, #point, label .. ": the window anchor changed")
	for index = 1, #point do
		equal(now[index], point[index], label .. ": the window anchor changed at " .. index)
	end
end

-- The core tab opens SkillUp's last page, with core's page frame the one core shows.
tab.mouseUp(tab, "LeftButton", true)
c.Advance(0)
equal(core.Selected(), "skillup", "the side tab selects SkillUp's registered tab")
equal(tab.checked, true, "core checks the side tab")
equal(route:IsShown(), true, "the route page is shown")
equal(frame.CraftingPage:GetAlpha(), 0, "the client's own page is hidden beneath SkillUp's")
Stable("after selecting SkillUp")

-- A client page hands the window back: core hides its page, and SkillUp's pages follow it.
frame.CraftingPage:Hide()
frame.CraftingPage:Show()
c.Advance(0)
equal(core.Selected(), nil, "a client page hands the window back")
equal(tab.checked, false, "and unchecks the side tab")
equal(route:IsShown(), false, "no SkillUp page stays shown")
equal(frame.CraftingPage:GetAlpha(), 1, "and the client's own page shows again")
Stable("after a client page")

-- Back to SkillUp, then its own bottom tab switches pages without moving the window.
tab.mouseUp(tab, "LeftButton", true)
c.Advance(0)
equal(route:IsShown(), true, "the side tab opens the route page again")
ns.db.showGearTab = true
ns.Changed("settings")
local gearTab = ns.Pages.BottomTab("gear")
assert(gearTab, "the gear bottom tab is there")
gearTab.scripts.OnClick(gearTab)
c.Advance(0)
local gear
for _, child in ipairs({ frame:GetChildren() }) do
	if child.Slots then
		gear = child
	end
end
assert(gear and gear:IsShown(), "the gear bottom tab shows the gear page")
equal(route:IsShown(), false, "and hides the route page")
equal(core.Selected(), "skillup", "with the side tab still selected")
Stable("after switching SkillUp's own page")

-- A second registration through core is another addon's tab, not ours: SkillUp still has one tab.
local other = core.Register("commissions-like", {
	icon = "Interface\\Icons\\INV_Misc_Note_01",
	tooltip = "Another addon",
	page = G.CreateFrame("Frame", nil, frame),
})
equal(tab.tooltipText, "SkillUp", "SkillUp keeps its own tab beside another addon's")
other.mouseUp(other, "LeftButton", true)
c.Advance(0)
equal(core.Selected(), "commissions-like", "the other addon's tab takes the window")
equal(gear:IsShown(), false, "and SkillUp's page hides")
equal(route:IsShown(), false, "whichever SkillUp page was on")
Stable("after another addon's tab")

tab.mouseUp(tab, "LeftButton", true)
c.Advance(0)
equal(core.Selected(), "skillup", "SkillUp's tab comes back")
equal(gear:IsShown(), true, "on the page the player last used")
Stable("after coming back")

c.Advance(0)
assert(#c.errors == 0, "no error was raised: " .. tostring(c.errors[1]))
Client.report("profession_tabs_spec")
