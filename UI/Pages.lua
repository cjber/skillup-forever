---@type string, SkillUpNamespace
local _, ns = ...
local L = ns.L

-- The one SkillUp side tab and the bottom tabs of its pages. Each page module owns its own frame and
-- drawing; this owns when a page shows, which tab is checked, and the side tab's place in the column.
-- A page registers itself once its frame exists, in the order the tabs should read.

---@type SkillUpPages
---@diagnostic disable-next-line: missing-fields -- every field is defined below, one function at a time
ns.Pages = {}

---@type SkillUpPageSpec[]
local pages = {}
---@type table<string, SkillUpPageSpec>
local byID = {}
---@type SkillUpSideTab?
local tab
---@type table<string, Button>
local bottom = {}
-- The page the player asked for, nil while the window shows Blizzard's own page.
---@type string?
local wanted
local token = 0
local opening = false

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

-- Our side tab and the bottom tabs are ours to draw; Blizzard's selected tab is never ours to keep.
local function Sync()
	if not tab then
		return
	end
	tab:SetChecked(wanted ~= nil)
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
	if wanted then
		ProfessionsFrame.ProfessionsOverviewTab:SetChecked(false)
		for _, professionTab in ipairs(ProfessionsFrame.rightProfessionTabs or {}) do
			professionTab:SetChecked(false)
		end
	end
end

-- The client runs the window's OnShow inside a secure panel call, where an addon's Hide is blocked (#393).
-- Record what the player asked for now and do the frame work on the next frame.
local function HidePageLater()
	local myToken = token
	C_Timer.After(0, function()
		if myToken ~= token or wanted or not ProfessionsFrame:IsShown() then
			return
		end
		Frames(function()
			if myToken ~= token or wanted or not ProfessionsFrame:IsShown() then
				return
			end
			for _, spec in ipairs(pages) do
				spec.page:Hide()
			end
		end)
		Sync()
	end)
end

local function HideNativePagesLater()
	local myToken = token
	C_Timer.After(0, function()
		if myToken ~= token or not wanted or not ProfessionsFrame:IsShown() then
			return
		end
		Frames(function()
			if myToken ~= token or not wanted or not ProfessionsFrame:IsShown() then
				return
			end
			ProfessionsFrame.CraftingPage:Hide()
			ProfessionsFrame.BookPage:Hide()
		end)
	end)
end

-- The client runs the window's OnHide inside a secure panel call as well, where showing a native page is the
-- same mistake as hiding one there (#398). Return the window to its crafting page once the call has ended.
local function ShowCraftingPageLater()
	local myToken = token
	C_Timer.After(0, function()
		if myToken ~= token or wanted or ProfessionsFrame:IsShown() then
			return
		end
		Frames(function()
			if myToken ~= token or wanted or ProfessionsFrame:IsShown() then
				return
			end
			ProfessionsFrame.CraftingPage:Show()
		end)
	end)
end

-- Blizzard's own tabs show their page explicitly, which hands the window back.
local function Deselect()
	wanted = nil
	token = token + 1
	Sync()
	HidePageLater()
end

-- The native pages hand the window back when the player picks one, but the client also shows them while
-- opening the window; a SkillUp page already on show stays.
local function NativePageShown()
	if opening and wanted then
		HideNativePagesLater()
		return
	end
	Deselect()
end

---@param spec SkillUpPageSpec
local function Show(spec)
	wanted = spec.id
	token = token + 1
	local myToken = token
	ns.SetLastSkillUpPage(spec.id)
	Sync()
	Frames(function()
		if myToken ~= token or wanted ~= spec.id then
			return
		end
		-- One page at a time: the other one's own OnHide only clears its drawing.
		for _, other in ipairs(pages) do
			if other ~= spec and other.page:IsShown() then
				other.page:Hide()
			end
		end
		if spec.prepare then
			spec.prepare()
		end
		-- Show the native page first so another custom page's CraftingPage hook can hand off cleanly. Its own
		-- OnShow may run our Deselect, so the page is marked wanted after that.
		ProfessionsFrame.CraftingPage:Show()
		if wanted ~= spec.id then
			wanted = spec.id
			ns.SetLastSkillUpPage(spec.id)
			Sync()
		end
		spec.page:Show()
		Sync()
		HideNativePagesLater()
	end)
end

---@param id string
local function Select(id)
	local spec = byID[id]
	if spec and Enabled(spec) then
		Show(spec)
	end
end

-- Open the page the player used last, or the first one that is on.
function ns.Pages.Open()
	local last = ns.LastSkillUpPage()
	local spec = last and byID[last]
	if spec and Enabled(spec) then
		Show(spec)
		return
	end
	spec = FirstEnabled()
	if spec then
		Show(spec)
	end
end

-- Close one page, as its setting or another window's tab does.
---@param id string
function ns.Pages.Close(id)
	local spec = byID[id]
	if not spec then
		return
	end
	if wanted == id then
		Deselect()
	elseif spec.page:IsShown() then
		local myToken = token
		Frames(function()
			if myToken ~= token then
				return
			end
			spec.page:Hide()
		end)
		Sync()
	end
end

-- A page can be turned off in settings; an open page goes back to crafting. The side tab shows while at
-- least one page is on.
local function RefreshSettings()
	---@type Frame[]?
	local hiding
	for _, spec in ipairs(pages) do
		if not Enabled(spec) and spec.page:IsShown() then
			wanted = nil
			token = token + 1
			hiding = hiding or {}
			hiding[#hiding + 1] = spec.page
		end
	end
	if tab then
		tab:SetShown(AnyEnabled())
	end
	Sync()
	ns.PlaceSideTabs()
	if hiding then
		local myToken = token
		Frames(function()
			if myToken ~= token then
				return
			end
			for _, page in ipairs(hiding) do
				page:Hide()
			end
			ProfessionsFrame.CraftingPage:Show()
		end)
	end
end

-- Whether a frame hangs off one of our tabs, directly or through the frames it is anchored to.
---@param frame Region
---@param ours table<Region, boolean>
---@param seen table<Region, boolean>
---@return boolean
local function HangsOff(frame, ours, seen)
	if ours[frame] then
		return true
	end
	-- A frame anchored through a protected one refuses GetPoint; it is not one of ours either way.
	if seen[frame] or frame:IsAnchoringRestricted() then
		return false
	end
	seen[frame] = true
	for index = 1, frame:GetNumPoints() do
		-- Anything a frame anchors to is itself anchorable.
		local _, relative = frame:GetPoint(index)
		if
			relative and HangsOff(relative --[[@as Region]], ours, seen)
		then
			return true
		end
	end
	return false
end

-- A side tab is no taller than the tab the column starts with. A frame that spans the column is the frame the
-- tabs hang in, not a tab: All The Things on Forever reparents Blizzard's tabs into one such frame on the
-- window's right edge and anchors its own tab in the next free slot inside it, so the tab in the slot is
-- inside that frame, and the frame itself is never mistaken for a tab (#402).
---@class SkillUpTabSlot
---@field frame Frame
---@field top number
---@field bottom number

-- Every tab already in the column, apart from ours: a shown frame flush with the column's left edge and no
-- taller than one slot. A frame tall enough to hold two tabs is a holder another addon put its tabs in, so its
-- children are read instead. A frame that hangs off our tab is below it by definition, not a tab we must
-- clear.
---@param frame Frame
---@param left number
---@param slotHeight number
---@param ours table<Region, boolean>
---@param seen table<Region, boolean>
---@param found SkillUpTabSlot[]
local function ColumnTabs(frame, left, slotHeight, ours, seen, found)
	if seen[frame] or not frame:IsShown() then
		return
	end
	seen[frame] = true
	local frameLeft, frameBottom, height = frame:GetLeft(), frame:GetBottom(), frame:GetHeight()
	if
		type(frameLeft) ~= "number"
		or type(frameBottom) ~= "number"
		or type(height) ~= "number"
		or math.abs(frameLeft - left) >= 1
	then
		return
	end
	if height >= slotHeight * 2 then
		for _, child in ipairs({ frame:GetChildren() }) do
			ColumnTabs(child --[[@as Frame]], left, slotHeight, ours, seen, found)
		end
		return
	end
	if HangsOff(frame, ours, {}) then
		return
	end
	found[#found + 1] = { frame = frame, top = frameBottom + height, bottom = frameBottom }
end

-- The lowest tab overlapping a slot we want: our tab goes under it rather than on top of it. Touching edges
-- leave the slot free, as the column's two-pixel gap does.
---@param slotTop number
---@param slotBottom number
---@param found SkillUpTabSlot[]
---@return Frame?
local function BlockingTab(slotTop, slotBottom, found)
	local lowest, lowestBottom
	for _, occupied in ipairs(found) do
		if occupied.top > slotBottom and occupied.bottom < slotTop then
			if not lowestBottom or occupied.bottom < lowestBottom then
				lowest, lowestBottom = occupied.frame, occupied.bottom
			end
		end
	end
	return lowest
end

-- Our one side tab in the next free slot under the last tab the column already holds, in the same tab art.
-- A tab another addon pins lower down, such as What's Training?'s bottom-right corner, leaves the slots
-- directly under the native column free: ours takes those and stays beside the window instead of being
-- pushed below that tab and past the window's bottom (#446). Each pass reads the column as it is now, so
-- the order the addons loaded or re-placed their tabs in does not matter.
local function PlaceTabs()
	if not (tab and ProfessionsFrame.ProfessionsOverviewTab) then
		return
	end
	local ours = { [tab] = true }
	---@type Frame
	local above = ProfessionsFrame.ProfessionsOverviewTab
	for _, professionTab in ipairs(ProfessionsFrame.rightProfessionTabs or {}) do
		if professionTab:IsShown() then
			above = professionTab
		end
	end
	local left, slotHeight = above:GetLeft(), above:GetHeight()
	local found = {}
	if type(left) == "number" and type(slotHeight) == "number" then
		for _, sibling in ipairs({ ProfessionsFrame:GetChildren() }) do
			ColumnTabs(sibling --[[@as Frame]], left, slotHeight, ours, {}, found)
		end
	end
	if type(slotHeight) == "number" then
		local slotBottom = above:GetBottom()
		while type(slotBottom) == "number" do
			local slotTop = slotBottom - 2
			local blocker = BlockingTab(slotTop, slotTop - slotHeight, found)
			if not blocker then
				break
			end
			above = blocker
			slotBottom = above:GetBottom()
		end
	end
	tab:ClearAllPoints()
	tab:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -2)
end
ns.PlaceSideTabs = PlaceTabs

---@param spec SkillUpPageSpec
local function CreateBottomTab(spec)
	local button = CreateFrame("Button", nil, ProfessionsFrame, "PanelTabButtonTemplate") --[[@as Button]]
	button:SetText(spec.title)
	PanelTemplates_TabResize(button, 0)
	PanelTemplates_DeselectTab(button)
	button:SetScript("OnClick", function()
		Select(spec.id)
	end)
	bottom[spec.id] = button
end

-- The window's own show and hide, done once: opening reads the column, closing hands the crafting page back.
local function CreateFrames()
	-- A real Button, not a Frame with the same art: under the gamepad interface SmartNavigation's panel scan
	-- calls GetScript("OnMouseUp") and GetScript("OnMouseDown") on every frame that is not a Button or an
	-- EditBox, and that read of our frame's template scripts runs in the gamepad's own call. The protected
	-- SetPreferredGamepadInteractTarget it later calls is then refused and blamed on us (#398). The client
	-- itself inherits this art into Buttons (Blizzard_CollectionsTabs.xml), so the tab looks and clicks the same.
	tab = CreateFrame("Button", nil, ProfessionsFrame, "LargeSideTabButtonTemplate") --[[@as SkillUpSideTab]]
	-- art-ok: a square icon in the square LargeSideTabButtonTemplate sizes for it
	tab.Icon:SetTexture("Interface\\Icons\\INV_Scroll_03")
	tab:SetFillToInterior(true)
	tab.tooltipText = L["SkillUp"]
	tab:EnableMouse(true)
	tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
		if button == "LeftButton" and upInside then
			ns.Pages.Open()
		end
	end)
	ProfessionsFrame:HookScript("OnShow", function()
		opening = true
		PlaceTabs()
		C_Timer.After(0, function()
			opening = false
		end)
	end)
	ProfessionsFrame:HookScript("OnHide", function()
		if wanted then
			Deselect()
			ShowCraftingPageLater()
		end
		Sync()
	end)
	ProfessionsFrame.CraftingPage:HookScript("OnShow", NativePageShown)
	ProfessionsFrame.BookPage:HookScript("OnShow", NativePageShown)
	PlaceTabs()
end

-- Register a page, in the order its bottom tab should read. The first registration creates the one side
-- tab and the window hooks; each one's own frame already exists.
---@param spec SkillUpPageSpec
function ns.Pages.Register(spec)
	if byID[spec.id] then
		return
	end
	if not tab then
		CreateFrames()
	end
	pages[#pages + 1] = spec
	byID[spec.id] = spec
	spec.page:HookScript("OnShow", Sync)
	spec.page:HookScript("OnHide", Sync)
	CreateBottomTab(spec)
	if tab then
		tab:SetShown(AnyEnabled())
	end
	Sync()
	PlaceTabs()
end

ns.WhenStale("pages", RefreshSettings)

---@return SkillUpSideTab?
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

-- Blizzard reselects its profession tab on skill updates; keep ours checked while our page shows.
function ns.Pages.Sync()
	Sync()
end

---@param id string
function ns.Pages.Select(id)
	Select(id)
end
