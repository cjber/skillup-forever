-- Run from the repository root: luajit tests/identity_icon_spec.lua
-- One client icon for every in-game identity surface: the TOC declares it once, Core reads it once, and the side
-- tab, the shared leaderboard tab and both shopping windows draw that same value.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local c = Client.load()
local ns, G = c.ns, c.G
local declared = G.C_AddOns.GetAddOnMetadata("SkillUpForever", "X-Forever-Icon")
assert(declared and declared ~= "", "the TOC declares no X-Forever-Icon")
equal(ns.ICON, declared, "Core reads the TOC icon once onto the namespace")

local board = G.ForeverCore.Leaderboards.boards.skillup
assert(board, "the shared Forever Leaderboards window has this addon's tab")
equal(board.icon, declared, "the leaderboard tab wears the identity icon")

-- The side tab is made when the first page registers; the client's template gives it the Icon region.
local frame = G.CreateFrame("Frame", "ProfessionsFrame", G.UIParent)
frame.CraftingPage = G.CreateFrame("Frame", nil, frame)
frame.BookPage = G.CreateFrame("Frame", nil, frame)
frame.ProfessionsOverviewTab = G.CreateFrame("Frame", nil, frame)
frame.rightProfessionTabs = {}
G.ProfessionsFrame = frame
local page = G.CreateFrame("Frame", nil, frame)
page:Hide()
ns.Pages.Register({
	id = "identity",
	title = "Identity",
	setting = function()
		return true
	end,
	page = page,
	prepare = function() end,
})
local tab = ns.Pages.SideTab()
assert(tab, "the side tab was built")
equal(tab.Icon.texture, declared, "the side tab wears the identity icon")

c.Fire("PLAYER_ENTERING_WORLD")
c.Fire("VARIABLES_LOADED")
c.Advance(0)
ns.OpenShoppingList()
local window = G.SkillUpForeverShoppingList
assert(window and window:IsShown(), "the shopping list window was built")
equal(window:GetPortrait().texture, declared, "the shopping list portrait wears the identity icon")

local copy
for _, child in ipairs({ window:GetChildren() }) do
	if child.text == ns.L["Copy list"] then
		copy = child
	end
end
assert(copy, "the shopping list's Copy list button was built")
copy.scripts.OnClick(copy)
local copyWindow = G.SkillUpForeverShoppingCopy
assert(copyWindow, "the copy window was built")
equal(copyWindow:GetPortrait().texture, declared, "the copy window portrait wears the identity icon")

Client.report("identity_icon_spec")
