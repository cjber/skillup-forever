-- Run from the repository root: luajit tests/pages_spec.lua
-- The bottom tabs of SkillUp's pages (UI/Pages.lua): the side tab and the page on show belong to
-- ForeverCore.ProfessionTabs, while the bottom tabs follow each page's setting, the last page reopens, and a
-- client tab or the closed window hands the window back.
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function noop() end

local timers = {}
local function Flush()
	while #timers > 0 do
		table.remove(timers, 1)()
	end
end

local function NewRegion(parent, frameType)
	local region = {
		frameType = frameType or "Frame",
		parent = parent,
		scripts = {},
		hooks = {},
		children = {},
		points = {},
		shown = true,
		width = 100,
		height = 20,
	}
	function region:SetPoint(point, relative, relativePoint, x, y)
		if type(relative) == "number" then
			point, relative, relativePoint, x, y = point, nil, nil, relative, relativePoint
		end
		self.points = { { point = point, relative = relative, relativePoint = relativePoint, x = x, y = y } }
	end
	function region:ClearAllPoints()
		self.points = {}
	end
	function region:GetNumPoints()
		return #self.points
	end
	function region:GetPoint(index)
		local point = self.points[index]
		return point and point.point, point and point.relative, point and point.relativePoint, point and point.x
	end
	function region:GetLeft()
		return self.left or 0
	end
	function region:GetBottom()
		return self.bottom or 0
	end
	function region:GetTop()
		return self:GetBottom() + self:GetHeight()
	end
	function region:GetWidth()
		return self.width
	end
	function region:GetHeight()
		return self.height
	end
	function region:GetSize()
		return self:GetWidth(), self:GetHeight()
	end
	function region:SetWidth(width)
		self.width = width
	end
	function region:SetHeight(height)
		self.height = height
	end
	function region:SetSize(width, height)
		self.width, self.height = width, height
	end
	function region:GetChildren()
		return unpack(self.children)
	end
	function region:GetParent()
		return self.parent
	end
	function region.GetFrameLevel()
		return 1
	end
	function region.IsAnchoringRestricted()
		return false
	end
	function region:IsShown()
		return self.shown
	end
	function region:Show()
		local was = self.shown
		self.shown = true
		if not was then
			if self.scripts.OnShow then
				self.scripts.OnShow(self)
			end
			for _, fn in ipairs(self.hooks.OnShow or {}) do
				fn(self)
			end
		end
	end
	function region:Hide()
		local was = self.shown
		self.shown = false
		if was then
			if self.scripts.OnHide then
				self.scripts.OnHide(self)
			end
			for _, fn in ipairs(self.hooks.OnHide or {}) do
				fn(self)
			end
		end
	end
	function region:SetShown(shown)
		if shown then
			self:Show()
		else
			self:Hide()
		end
	end
	function region:SetChecked(checked)
		self.checked = checked
	end
	function region:IsChecked()
		return self.checked == true
	end
	function region:HookScript(name, fn)
		self.hooks[name] = self.hooks[name] or {}
		table.insert(self.hooks[name], fn)
	end
	function region:SetScript(name, fn)
		self.scripts[name] = fn
	end
	function region:GetScript(name)
		return self.scripts[name]
	end
	function region:SetText(text)
		self.text = text
	end
	function region:GetText()
		return self.text or ""
	end
	function region:GetStringWidth()
		return #(self.text or "") * 6
	end
	function region:GetTextWidth()
		return self:GetStringWidth()
	end
	function region:CreateTexture()
		return NewRegion(self, "Texture")
	end
	function region:CreateFontString()
		return NewRegion(self, "FontString")
	end
	function region:SetTexture(texture)
		self.texture = texture
	end
	function region:SetAtlas(atlas)
		self.atlas = atlas
	end
	function region:SetBlendMode()
		return self
	end
	function region:SetVertexColor()
		return self
	end
	function region:SetDesaturated(desaturated)
		self.desaturated = desaturated
	end
	function region:SetColorTexture()
		return self
	end
	function region:SetTexCoord()
		return self
	end
	function region:SetAlpha()
		return self
	end
	function region:SetAllPoints()
		return self
	end
	function region:SetCustomOnMouseUpHandler(fn)
		self.scripts.OnMouseUp = fn
	end
	function region:Click()
		if self.scripts.OnClick then
			self.scripts.OnClick(self)
		end
	end
	if parent then
		table.insert(parent.children, region)
	end
	return setmetatable(region, {
		__index = function(_, key)
			if type(key) == "string" and key:match("^%u") then
				return noop
			end
		end,
	})
end

local tabs, bottomTabs = {}, {}
local function CreateFrame(frameType, _, parent, template)
	local region = NewRegion(parent, frameType)
	region.template = template
	if template == "LargeSideTabButtonTemplate" then
		region.Icon = NewRegion(region, "Texture")
		tabs[#tabs + 1] = region
	elseif template == "PanelTabButtonTemplate" then
		bottomTabs[#bottomTabs + 1] = region
		region.Text = NewRegion(region, "FontString")
	end
	return region
end

local ProfessionsFrame = NewRegion(nil)
ProfessionsFrame.width, ProfessionsFrame.height = 673, 594
ProfessionsFrame.CraftingPage = NewRegion(ProfessionsFrame)
ProfessionsFrame.BookPage = NewRegion(ProfessionsFrame)
ProfessionsFrame.ProfessionsOverviewTab = NewRegion(ProfessionsFrame)
ProfessionsFrame.ProfessionsOverviewTab:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 0, -60)
ProfessionsFrame.ProfessionsOverviewTab:SetSize(43, 55)
ProfessionsFrame.rightProfessionTabs = {}

-- ForeverCore.ProfessionTabs, as the client's own side tab works: one register, its page shown and hidden, and a
-- selection callback after the page shows. Its minor is 2, the version Core/Require.lua asks for.
local coreTab
local coreEntry
local coreSelected
local Core = { minor = 2 }
function Core.Register(key, spec)
	coreEntry = { key = key, spec = spec }
	coreTab = CreateFrame("Button", nil, ProfessionsFrame, "LargeSideTabButtonTemplate")
	coreTab.Icon:SetTexture(spec.icon)
	coreTab.tooltipText = spec.tooltip
	coreTab:SetCustomOnMouseUpHandler(function(_, button, upInside)
		if button == "LeftButton" and upInside then
			Core.Select(key)
		end
	end)
	coreTab:SetChecked(false)
	return coreTab
end
function Core.Select()
	coreSelected = coreEntry.key
	coreTab:SetChecked(true)
	coreEntry.spec.page:Show()
	if coreEntry.spec.onSelect then
		coreEntry.spec.onSelect(coreEntry.key)
	end
end
function Core.ShowNative()
	coreSelected = nil
	coreTab:SetChecked(false)
	coreEntry.spec.page:Hide()
end
function Core.Selected()
	return coreSelected
end
function Core.SetMinWidth(key, width)
	coreEntry.spec.minWidth = width
	return key == coreEntry.key
end

local handlers = {}
local lastPage
local ns = {
	L = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	}),
	ICON = "Interface\\Icons\\INV_Scroll_03",
	db = { showRouteTab = true, showGearTab = false, showBuffsTab = true },
	core = {
		SafeCall = function(_, fn, ...)
			return pcall(fn, ...)
		end,
	},
	LastSkillUpPage = function()
		return lastPage
	end,
	SetLastSkillUpPage = function(pageID)
		lastPage = pageID
	end,
	WhenStale = function(name, handler)
		handlers[name] = handler
	end,
}
ns.Pages = {}

local env = setmetatable({
	ForeverCore = { ProfessionTabs = Core },
	CreateFrame = CreateFrame,
	ProfessionsFrame = ProfessionsFrame,
	C_Timer = {
		After = function(_, fn)
			timers[#timers + 1] = fn
		end,
	},
	PanelTemplates_SelectTab = function(tab)
		tab.selected = true
	end,
	PanelTemplates_DeselectTab = function(tab)
		tab.selected = false
	end,
	PanelTemplates_TabResize = function(tab, padding)
		tab:SetWidth(tab.Text:GetStringWidth() + 20 + (padding or 0))
	end,
}, {
	__index = function(_, key)
		if key == "_G" then
			return _G
		end
		local value = _G[key]
		if value ~= nil then
			return value
		end
		return noop
	end,
})

setfenv(assert(loadfile("UI/Pages.lua")), env)("SkillUpForever", ns)

local prepared = {}
local function Page(id)
	local page = NewRegion(ProfessionsFrame)
	page:Hide()
	ns.Pages.Register({
		id = id,
		title = id,
		setting = function()
			if id == "route" then
				return ns.db.showRouteTab
			elseif id == "gear" then
				return ns.db.showGearTab
			end
			return ns.db.showBuffsTab
		end,
		page = page,
		prepare = function()
			prepared[id] = (prepared[id] or 0) + 1
		end,
	})
	return page
end
local route = Page("route")
local gear = Page("gear")
local buffs = Page("buffs")

-- Core builds the one side tab for every page, and the bottom tabs are ours.
equal(#tabs, 1, "the pages share core's one side tab")
equal(ns.Pages.SideTab(), coreTab, "the side tab is the one core registered")
equal(coreEntry.spec.icon, ns.ICON, "it wears the addon's icon")
equal(coreEntry.spec.tooltip, "SkillUp", "and says its name")
equal(coreEntry.spec.minWidth, nil, "no wide list means no width of its own")
equal(coreEntry.spec.safeCall, ns.core.SafeCall, "its failures go to SkillUp's journal")
equal(ns.Pages.SetMinWidth, nil, "SkillUp does not expose a host resize hook")
equal(ns.Pages.Count(), 3, "three pages are registered")
equal(#bottomTabs, 3, "and each has a bottom tab")
equal(ns.Pages.BottomTab("route") ~= nil, true, "the route tab is kept by id")
equal(ns.Pages.BottomTab("gear").shown, false, "no page tabs show before a page does")

-- The side tab opens the page the player used last, or Route before there is one.
coreTab.scripts.OnMouseUp(nil, "LeftButton", true)
Flush()
equal(coreSelected, "skillup", "the side tab selects core's SkillUp tab")
equal(route:IsShown(), true, "and opens Route by default")
equal(prepared.route, 1, "and prepares it")
equal(coreTab:IsChecked(), true, "with the side tab checked")
equal(ns.Pages.BottomTab("route").selected, true, "and Route's bottom tab selected")
equal(ns.Pages.BottomTab("route").shown, true, "Route's bottom tab shows with the page")
equal(ns.Pages.BottomTab("gear").shown, false, "a page that is off has no bottom tab")
equal(ns.Pages.BottomTab("buffs").shown, true, "a page that is on has one")

-- A bottom tab switches page, and the side tab remembers it.
ns.db.showGearTab = true
handlers.pages()
ns.Pages.BottomTab("gear").scripts.OnClick()
Flush()
equal(gear:IsShown(), true, "the gear tab shows the gear page")
equal(route:IsShown(), false, "and hides the route page")
equal(lastPage, "gear", "the last page is saved")
coreTab.scripts.OnMouseUp(nil, "LeftButton", true)
Flush()
equal(gear:IsShown(), true, "the side tab reopens the last page used")
equal(prepared.gear, 2, "preparing it again")

-- A page turned off loses its bottom tab; when it is the open one, the window goes back to the client's page.
ns.db.showGearTab = false
handlers.pages()
equal(ns.Pages.BottomTab("gear").shown, false, "the gear tab hides with its setting")
equal(gear:IsShown(), false, "and the open gear page closes")
equal(coreTab:IsChecked(), false, "the side tab unchecks with no page showing")
equal(coreSelected, nil, "and core hands the window back")
equal(ProfessionsFrame.CraftingPage:IsShown(), true, "the client's own page stays shown")

-- The side tab shows while at least one page is on, and goes when every page is off.
ns.db.showRouteTab = false
ns.db.showBuffsTab = false
handlers.pages()
equal(coreTab.shown, false, "the side tab hides when every page is off")
ns.db.showBuffsTab = true
handlers.pages()
equal(coreTab.shown, true, "and comes back with one page on")
equal(ns.Pages.BottomTab("route").shown, false, "the route tab stays off")

-- A client tab or page hands the window back: our page hides and the side tab unchecks.
ns.Pages.BottomTab("buffs").scripts.OnClick()
Flush()
equal(ns.Pages.BottomTab("buffs").shown, true, "the buffs tab shows while its page does")
equal(buffs:IsShown(), true, "the buffs tab shows the buffs page")
Core.ShowNative()
Flush()
equal(buffs:IsShown(), false, "a client page hides ours")
equal(coreTab:IsChecked(), false, "and unchecks the side tab")
equal(ns.Pages.BottomTab("buffs").shown, false, "with the page tabs hidden")

-- The window closing hands it back too.
ns.Pages.BottomTab("buffs").scripts.OnClick()
Flush()
equal(buffs:IsShown(), true, "the buffs page shows before the window closes")
ProfessionsFrame:Hide()
Flush()
equal(coreTab:IsChecked(), false, "closing the window unchecks the side tab")
equal(ns.Pages.BottomTab("buffs").shown, false, "and hides the page tabs")

print("pages_spec: " .. checks .. " checks passed")
