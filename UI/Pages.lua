---@type string, SkillUpNamespace
local _, ns = ...

if ns.broken then
	return
end
local L = ns.L

-- The one SkillUp tab and the bottom tabs of its pages. ForeverCore.ProfessionTabs owns the side tab: where it
-- sits, which tab is checked, showing the one registered page and handing the window back. This owns when a
-- SkillUp page shows and which bottom tab is selected. A page registers itself once its frame exists, in the
-- order the tabs should read.

local KEY = "skillup"

---@type SkillUpPages
---@diagnostic disable-next-line: missing-fields -- every field is defined below, one function at a time
ns.Pages = {}

---@type SkillUpPageSpec[]
local pages = {}
---@type table<string, SkillUpPageSpec>
local byID = {}
---@type ForeverProfessionTab?
local tab
-- The frame core shows and hides. Its own Show and Hide are the one place the real pages follow it.
---@type Frame
local shell
-- The bottom tabs, in registration order.
---@type table<string, Button>
local bottom = {}
-- The page the player asked for, nil while the window shows Blizzard's own page.
---@type string?
local wanted
-- The page the shell's OnShow just asked for, so the selection callback core runs next does not show it twice.
---@type SkillUpPageSpec?
local revealed
local token = 0

---@return boolean
local function Locked()
	return type(InCombatLockdown) == "function" and InCombatLockdown()
end

-- Page frames are protected while a secure button hangs off the window (Route's Craft button), so hiding or
-- showing one during combat lockdown is refused and taints our frame work (#489). The wanted page and our own
-- tabs still change at once; only the frame calls wait for combat to end, the way UI/Route.lua already waits for
-- its Craft button. The frame work is remembered in one slot, in the order the calls asked for it.
---@type (fun())?
local pending
local watched = CreateFrame("Frame")

local function StopWatching()
	if watched.UnregisterEvent then
		watched:UnregisterEvent("PLAYER_REGEN_ENABLED")
	end
end

watched:SetScript("OnEvent", function()
	if Locked() then
		return
	end
	local work = pending
	pending = nil
	StopWatching()
	if work then
		work()
	end
end)

---@param work fun()
---@return boolean
local function Frames(work)
	if not Locked() then
		work()
		return true
	end
	if pending then
		local earlier = pending
		pending = function()
			earlier()
			work()
		end
	else
		pending = work
	end
	watched:RegisterEvent("PLAYER_REGEN_ENABLED")
	return false
end

-- Wait for combat to end and then run `fn`, for the callers outside this file (Settings opens a protected panel).
---@param fn fun()
---@return boolean
local function Unlocked(fn)
	if not Locked() then
		return true
	end
	Frames(fn)
	return false
end
ns.Pages.Unlocked = Unlocked

---@param spec SkillUpPageSpec
---@return boolean
local function Enabled(spec)
	return spec.setting() == true
end

---@return SkillUpPageSpec?
local function FirstEnabled()
	for _, spec in ipairs(pages) do
		if Enabled(spec) then
			return spec
		end
	end
end

---@return boolean
local function AnyEnabled()
	return FirstEnabled() ~= nil
end

-- The page the side tab opens: the one the player used last, or the first one that is on.
---@return SkillUpPageSpec?
local function Chosen()
	local last = ns.LastSkillUpPage()
	local spec = last and byID[last]
	if spec and Enabled(spec) then
		return spec
	end
	return FirstEnabled()
end

-- The bottom tabs are ours to draw; the side tab's check and the client's own tabs are not.
local function Sync()
	local anyShown = wanted ~= nil and ProfessionsFrame:IsShown()
	for _, spec in ipairs(pages) do
		local button = bottom[spec.id]
		if button then
			button:SetShown(anyShown and Enabled(spec))
			if spec.id == wanted then
				PanelTemplates_SelectTab(button)
			else
				PanelTemplates_DeselectTab(button)
			end
		end
	end
	-- The tabs read left to right from the window's bottom-left corner, only the pages that are on.
	local previous
	for _, spec in ipairs(pages) do
		local button = bottom[spec.id]
		if button and Enabled(spec) then
			button:ClearAllPoints()
			if previous then
				button:SetPoint("LEFT", previous, "RIGHT", 3, 0)
			else
				button:SetPoint("TOPLEFT", ProfessionsFrame, "BOTTOMLEFT", 11, 4)
			end
			previous = button
		end
	end
	if tab then
		tab:SetShown(AnyEnabled())
	end
end

-- One page at a time. Its own OnShow draws it; the others' OnHide clears theirs.
---@param spec SkillUpPageSpec
local function Show(spec)
	wanted = spec.id
	token = token + 1
	local myToken = token
	ns.SetLastSkillUpPage(spec.id)
	Frames(function()
		if myToken ~= token or wanted ~= spec.id then
			return
		end
		for _, other in ipairs(pages) do
			if other ~= spec and other.page:IsShown() then
				other.page:Hide()
			end
		end
		if spec.prepare then
			spec.prepare()
		end
		spec.page:Show()
		Sync()
	end)
	Sync()
end

-- Every SkillUp page goes away and the bottom tabs hide with them. ForeverCore has already shown the client's
-- own page when it hides the frame this answers.
local function Hide()
	wanted = nil
	revealed = nil
	token = token + 1
	local myToken = token
	Frames(function()
		if myToken ~= token then
			return
		end
		for _, spec in ipairs(pages) do
			if spec.page:IsShown() then
				spec.page:Hide()
			end
		end
		Sync()
	end)
	Sync()
end

-- Core shows the frame it registered when its tab is selected. That frame's OnShow asks for the page the player
-- wants, and core's onSelect callback follows it.
local function Reveal()
	local spec = wanted and byID[wanted] or Chosen()
	if spec and Enabled(spec) then
		revealed = spec
		Show(spec)
	else
		wanted = nil
		Sync()
	end
end

-- ForeverCore's onSelect callback. The shell's OnShow has already shown the page it asked for; a bottom tab
-- selecting another one comes through here alone.
---@param _ string
local function Selected(_)
	local spec = wanted and byID[wanted] or Chosen()
	if spec and Enabled(spec) then
		if revealed ~= spec then
			Show(spec)
		end
		revealed = nil
	else
		wanted = nil
		Sync()
	end
end

---@param spec SkillUpPageSpec
local function CreateBottomTab(spec)
	local button = CreateFrame("Button", nil, ProfessionsFrame, "PanelTabButtonTemplate") --[[@as Button]]
	button:SetText(spec.title)
	PanelTemplates_TabResize(button, 0)
	PanelTemplates_DeselectTab(button)
	button:SetScript("OnClick", function()
		ns.Pages.Select(spec.id)
	end)
	bottom[spec.id] = button
end

-- Core's one frame for SkillUp: the client's side tab column, its checked state and the one page on show all
-- belong to ForeverCore.ProfessionTabs. The frame itself carries no art; the pages still draw in the window.
local function CreateFrames()
	shell = CreateFrame("Frame", "SkillUpForeverProfessionTabPage", ProfessionsFrame)
	shell:SetAllPoints(ProfessionsFrame.CraftingPage)
	shell:Hide()
	shell:SetScript("OnShow", Reveal)
	shell:SetScript("OnHide", Hide)
	tab = ForeverCore.ProfessionTabs.Register(KEY, {
		icon = ns.ICON,
		tooltip = L["SkillUp"],
		page = shell,
		onSelect = Selected,
		safeCall = ns.core and ns.core.SafeCall,
	})
	-- Closing the window hands it back, as the client's own tabs do, so the tab is unchecked and the bottom
	-- tabs are gone the next time the window opens.
	ProfessionsFrame:HookScript("OnHide", function()
		if ForeverCore.ProfessionTabs.Selected() == KEY then
			ForeverCore.ProfessionTabs.ShowNative()
		end
	end)
end

-- Register a page, in the order its bottom tab should read. The first registration creates core's one tab and
-- the frame core shows; each one's own frame already exists.
---@param spec SkillUpPageSpec
function ns.Pages.Register(spec)
	if byID[spec.id] then
		return
	end
	if not shell then
		CreateFrames()
	end
	pages[#pages + 1] = spec
	byID[spec.id] = spec
	spec.page:HookScript("OnShow", Sync)
	spec.page:HookScript("OnHide", Sync)
	CreateBottomTab(spec)
	Sync()
end

-- Close one page, as its setting or another window's tab does.
---@param id string
function ns.Pages.Close(id)
	local spec = byID[id]
	if not spec then
		return
	end
	if wanted == id then
		Hide()
		if ForeverCore.ProfessionTabs.Selected() == KEY then
			ForeverCore.ProfessionTabs.ShowNative()
		end
	elseif spec.page:IsShown() then
		local myToken = token
		Frames(function()
			if myToken ~= token then
				return
			end
			spec.page:Hide()
			Sync()
		end)
		Sync()
	end
end

-- A page can be turned off in settings; an open page goes back to the client's own. The side tab shows while at
-- least one page is on.
local function RefreshSettings()
	for _, spec in ipairs(pages) do
		if not Enabled(spec) and (wanted == spec.id or spec.page:IsShown()) then
			Hide()
			if ForeverCore.ProfessionTabs.Selected() == KEY then
				ForeverCore.ProfessionTabs.ShowNative()
			end
			break
		end
	end
	Sync()
end

ns.WhenStale("pages", RefreshSettings)

---@return ForeverProfessionTab?
function ns.Pages.SideTab()
	return tab
end

---@param id string
---@return Button?
function ns.Pages.BottomTab(id)
	return bottom[id]
end

---@return integer
function ns.Pages.Count()
	return #pages
end

-- Blizzard reselects its profession tab on skill updates; core keeps our tab checked while our page shows.
function ns.Pages.Sync()
	Sync()
end

---@param id string
function ns.Pages.Select(id)
	local spec = byID[id]
	if spec and Enabled(spec) then
		wanted = id
		ns.SetLastSkillUpPage(id)
		if ForeverCore.ProfessionTabs.Selected() == KEY then
			Show(spec)
		else
			ForeverCore.ProfessionTabs.Select(KEY)
		end
	end
end
