-- Run from the repository root: luajit tests/route_layout_spec.lua
-- The route and gear pages at their real window size: the rectangles their controls, headings and rows
-- occupy, the width a reagent name gets, and the side tabs handing the window from one page to the other.
-- Frames resolve their anchors in screen pixels, as tracker_geometry_spec does; a name or an icon that
-- would reach outside its region is the bug this guards.
local Client = dofile("tests/client.lua")
local equal = Client.equal

-- Friz Quadrata at 12px, the widths the client draws for GameFontNormal and GameFontHighlight; anything not
-- listed is measured at a flat rate. The reagent names are the ones the rows in this spec carry.
local WIDTH = {
	["Buy reagents"] = 73,
	["Route"] = 33,
	["Reagents  (have / need)"] = 133,
	["Light Leather"] = 74,
	["Coarse Thread"] = 81,
	["Simple Wood"] = 76,
	["Latest Auctionator prices: rescan to update old prices."] = 271,
}
local function TextWidth(text)
	return WIDTH[text] or #text * 7
end

local function noop() end
local created, insets, tabs, pageFrame = {}, {}, {}, nil

-- Where a point sits inside a region: its own fraction of the region's width and height.
local function Fraction(point)
	local x = point:find("LEFT", 1, true) and 0 or point:find("RIGHT", 1, true) and 1 or 0.5
	local y = point:find("BOTTOM", 1, true) and 0 or point:find("TOP", 1, true) and 1 or 0.5
	return x, y
end

-- A region's rect in screen pixels: left, bottom, right, top. Anchors resolve against their relative
-- region; a frame on the scroll view stretches to its scroll box, as the client does.
local function Rect(frame, seen)
	if not frame then
		return 0, 0, 0, 0
	end
	if frame.allPoints then
		return Rect(frame.allPoints, seen)
	end
	if frame.scrollable and #frame.points == 0 and frame.parent then
		return Rect(frame.parent, seen)
	end
	if #frame.points == 0 then
		return 0, 0, frame.width or 0, frame.height or 0
	end
	seen = seen or {}
	assert(not seen[frame], "anchor dependency cycle")
	seen[frame] = true
	local left, right, bottom, top, hx, hy
	for _, anchor in ipairs(frame.points) do
		local rl, rb, rr, rt = Rect(anchor.relative, seen)
		local rx, ry = Fraction(anchor.relativePoint)
		local ax = rl + rx * (rr - rl) + anchor.x
		local ay = rb + ry * (rt - rb) + anchor.y
		local fx, fy = Fraction(anchor.point)
		if fx == 0 then
			left = ax
		elseif fx == 1 then
			right = ax
		else
			hx = ax
		end
		if fy == 0 then
			bottom = ay
		elseif fy == 1 then
			top = ay
		else
			hy = ay
		end
	end
	seen[frame] = nil
	local text = frame.text and TextWidth(frame.text) or 0
	if not (left and right) then
		if left then
			right = left + (frame.width or text)
		elseif right then
			left = right - (frame.width or text)
		elseif hx then
			left, right = hx - (frame.width or 0) / 2, hx + (frame.width or 0) / 2
		else
			left, right = 0, frame.width or 0
		end
	end
	if not (bottom and top) then
		if bottom then
			top = bottom + (frame.height or 12)
		elseif top then
			bottom = top - (frame.height or 12)
		elseif hy then
			bottom, top = hy - (frame.height or 12) / 2, hy + (frame.height or 12) / 2
		else
			bottom, top = 0, frame.height or 12
		end
	end
	return left, bottom, right, top
end

local function Width(region)
	local left, _, right = Rect(region)
	return right - left
end

local function Height(region)
	local _, bottom, _, top = Rect(region)
	return top - bottom
end

-- Two rects intersect when they overlap on both axes; touching edges do not count.
local function overlaps(a, b)
	local al, ab, ar, at = Rect(a)
	local bl, bb, br, bt = Rect(b)
	return al < br and bl < ar and ab < bt and bb < at
end

local function NewRegion(parent, frameType)
	local region =
		{ parent = parent, frameType = frameType or "Frame", points = {}, scripts = {}, shown = true, enabled = true }
	function region:SetPoint(...)
		local args = { ... }
		local point = args[1]
		local relative, relativePoint, x, y
		if type(args[2]) == "table" then
			relative, relativePoint, x, y = args[2], args[3], args[4], args[5]
		else
			relative, relativePoint, x, y = parent, point, args[2], args[3]
		end
		-- The client refuses an anchor to a region that already hangs off this one.
		local function DependsOnSelf(other)
			if other == self then
				return true
			end
			for _, anchor in ipairs(other and other.points or {}) do
				if DependsOnSelf(anchor.relative) then
					return true
				end
			end
			return false
		end
		if DependsOnSelf(relative) then
			error("Action[SetPoint] failed because[Cannot anchor to a region dependent on it]", 2)
		end
		self.points[#self.points + 1] =
			{ point = point, relative = relative, relativePoint = relativePoint, x = x or 0, y = y or 0 }
	end
	function region:GetNumPoints()
		return #self.points
	end
	function region:GetPoint(index)
		local anchor = self.points[index or 1]
		if anchor then
			return anchor.point, anchor.relative, anchor.relativePoint, anchor.x, anchor.y
		end
	end
	function region:GetLeft()
		return (Rect(self))
	end
	function region:GetBottom()
		local _, bottom = Rect(self)
		return bottom
	end
	function region:GetChildren()
		local children = {}
		for _, child in ipairs(created) do
			if child.parent == self and child.template ~= "texture" then
				children[#children + 1] = child
			end
		end
		return unpack(children)
	end
	function region:ClearAllPoints()
		self.points = {}
	end
	function region:SetAllPoints(target)
		self.allPoints = target
	end
	function region:SetSize(width, height)
		self.width, self.height = width, height
	end
	function region:SetWidth(width)
		self.width = width
	end
	function region:SetHeight(height)
		self.height = height
	end
	function region:GetWidth()
		return Width(self)
	end
	function region:GetHeight()
		local _, bottom, _, top = Rect(self)
		return top - bottom
	end
	function region:SetText(text)
		self.text = text
	end
	function region:SetAtlas(atlas)
		self.atlas = atlas
	end
	function region:SetTexture(texture)
		self.texture = texture
	end
	function region:SetFormattedText(format, ...)
		self.text = string.format(format, ...)
	end
	function region:GetTextWidth()
		return TextWidth(self.text or "")
	end
	function region:GetStringWidth()
		return TextWidth(self.text or "")
	end
	function region.GetStringHeight()
		return 12
	end
	function region:SetShown(shown)
		self.shown = shown and true or false
	end
	function region:Show()
		self.shown = true
		if self.scripts.OnShow then
			self.scripts.OnShow(self)
		end
	end
	function region:Hide()
		self.shown = false
		if self.scripts.OnHide then
			self.scripts.OnHide(self)
		end
	end
	function region:IsShown()
		return self.shown
	end
	function region:IsVisible()
		return self.shown
	end
	function region:SetEnabled(enabled)
		self.enabled = enabled and true or false
	end
	function region:EnableMouse(enabled)
		self.mouseEnabled = enabled and true or false
	end
	function region:IsEnabled()
		return self.enabled
	end
	function region:Enable()
		self.enabled = true
	end
	function region:Disable()
		self.enabled = false
	end
	function region:SetChecked(checked)
		self.checked = checked
	end
	function region:GetChecked()
		return self.checked
	end
	function region:SetScript(name, fn)
		self.scripts[name] = fn
	end
	function region:GetScript(name)
		return self.scripts[name]
	end
	function region:IsObjectType(kind)
		return self.frameType == kind
	end
	function region:GetSize()
		return self.width or 0, self.height or 0
	end
	function region:HookScript(name, fn)
		local previous = self.scripts[name]
		self.scripts[name] = previous and function(...)
			previous(...)
			fn(...)
		end or fn
	end
	function region:RegisterEvent(event)
		self.events = self.events or {}
		self.events[event] = true
	end
	function region:CreateFontString()
		local font = NewRegion(self, "FontString")
		font.height = 12
		created[#created + 1] = font
		return font
	end
	function region:CreateTexture()
		local texture = NewRegion(self, "Texture")
		created[#created + 1] = texture
		return texture
	end
	function region:CreateMaskTexture()
		local mask = NewRegion(self, "MaskTexture")
		created[#created + 1] = mask
		return mask
	end
	function region:AddMaskTexture(mask)
		self.masks = self.masks or {}
		self.masks[#self.masks + 1] = mask
	end
	function region:SetStatusBarTexture(texture)
		self.statusBarTexture = texture
	end
	function region:GetStatusBarTexture()
		return self.statusBarTexture
	end
	function region:SetCustomOnMouseUpHandler(fn)
		self.scripts.OnMouseUp = fn
	end
	function region:GetPortrait()
		return self.portrait
	end
	function region.GetEffectiveScale()
		return 1
	end
	function region.GetFrameLevel()
		return 1
	end
	function region.HasFocus()
		return false
	end
	function region:Click()
		if self.scripts.OnClick then
			self.scripts.OnClick(self)
		end
	end
	created[#created + 1] = region
	return setmetatable(region, {
		__index = function(_, key)
			if type(key) == "string" and key:match("^%u") then
				return noop
			end
			return nil
		end,
	})
end

local ProfessionsFrame = NewRegion(nil)
ProfessionsFrame.width, ProfessionsFrame.height = 673, 594
ProfessionsFrame.CraftingPage = NewRegion(ProfessionsFrame)
ProfessionsFrame.CraftingPage.width, ProfessionsFrame.CraftingPage.height = 673, 594
-- The route's Craft button reads the shown recipe and the page's own Create buttons; this spec draws the
-- page, not a craft, so the page shows none and the buttons are off.
ProfessionsFrame.CraftingPage.SchematicForm = {
	GetRecipeInfo = function()
		return nil
	end,
}
ProfessionsFrame.CraftingPage.CreateButton = {
	IsEnabled = function()
		return false
	end,
}
ProfessionsFrame.CraftingPage.CreateAllButton = {
	IsEnabled = function()
		return false
	end,
}
ProfessionsFrame.BookPage = NewRegion(ProfessionsFrame)
ProfessionsFrame.ProfessionsOverviewTab = NewRegion(ProfessionsFrame)
ProfessionsFrame.rightProfessionTabs = {}
-- Blizzard's tab column hangs off the window's top-right corner: the overview tab is a TOPLEFT of the
-- window's TOPRIGHT at -60 (Blizzard_ProfessionsFrame.xml), and each right tab is -2 under the one above.
ProfessionsFrame.ProfessionsOverviewTab:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 0, -60)
ProfessionsFrame.ProfessionsOverviewTab:SetSize(43, 55)
ProfessionsFrame.portrait = NewRegion(ProfessionsFrame)
ProfessionsFrame.portrait:SetPoint("TOPLEFT", 0, 0)
ProfessionsFrame.portrait:SetSize(64, 64)
-- PortraitFrameTemplate's title band: the window's content starts at -21, so nothing a page draws may
-- reach into it or over the portrait that overhangs the top-left corner.
local titleBar = NewRegion(ProfessionsFrame)
titleBar:SetPoint("TOPLEFT", 0, 0)
titleBar:SetPoint("TOPRIGHT", 0, 0)
titleBar:SetHeight(21)

local function CreateFrame(frameType, name, parent, template)
	local region = NewRegion(parent, frameType)
	region.template = template
	if template == "LargeSideTabButtonTemplate" then
		region.Icon = NewRegion(region, "Texture")
		-- The template's own XML gives it OnMouseDown and OnMouseUp scripts, as the client's does.
		region.scripts.OnMouseDown = noop
		region.scripts.OnMouseUp = noop
		tabs[#tabs + 1] = region
	elseif template == "InsetFrameTemplate" then
		insets[#insets + 1] = region
	elseif template == "UICheckButtonTemplate" then
		region.width, region.height = 26, 26
	elseif template == "NumericInputSpinnerTemplate" then
		region.IncrementButton = NewRegion(region, "Button")
		region.DecrementButton = NewRegion(region, "Button")
		region.MouseWheelCatcher = NewRegion(region, "Frame")
	elseif parent == ProfessionsFrame and template == nil and name == nil then
		pageFrame = region
	end
	return region
end

-- ForeverCore.ProfessionTabs, as the shared module drives it: one tab and the page core shows. This spec is
-- about SkillUp's pages, so core's own placement and hand-back are its own tests; here selecting and handing
-- back do what core does. Its minor is 2, the version Core/Require.lua asks for.
local coreTab, coreEntry, coreSelected
local ProfessionTabs = { minor = 2 }
function ProfessionTabs.Register(key, spec)
	coreEntry = { key = key, spec = spec }
	coreTab = CreateFrame("Button", nil, ProfessionsFrame, "LargeSideTabButtonTemplate")
	coreTab.Icon:SetTexture(spec.icon)
	coreTab.tooltipText = spec.tooltip
	coreTab:SetCustomOnMouseUpHandler(function(_, button, upInside)
		if button == "LeftButton" and upInside then
			ProfessionTabs.Select(key)
		end
	end)
	return coreTab
end
function ProfessionTabs.Select()
	coreSelected = coreEntry.key
	coreTab:SetChecked(true)
	coreEntry.spec.page:Show()
	if coreEntry.spec.onSelect then
		coreEntry.spec.onSelect(coreEntry.key)
	end
end
function ProfessionTabs.ShowNative()
	coreSelected = nil
	coreTab:SetChecked(false)
	coreEntry.spec.page:Hide()
end
function ProfessionTabs.Selected()
	return coreSelected
end

-- The scroll box list, as this spec needs it: the view draws a frame for an element through its element
-- factory, at the extent it gives that element, and the scroll box stacks them as the client does.
local function CreateScrollBoxListLinearView()
	local view = NewRegion(nil)
	function view:SetElementExtentCalculator(calculator)
		self.extent = calculator
	end
	function view:SetElementFactory(factory)
		self.factory = factory
	end
	return view
end

local function InitScrollBoxList(scrollBox, _, view)
	function scrollBox:SetDataProvider(provider)
		local offset = 0
		for _, elementData in ipairs(provider.elements) do
			local template, initializer
			view.factory(function(name, init)
				template, initializer = name, init
			end, elementData)
			local frame = CreateFrame(nil, nil, self, template)
			initializer(frame, elementData)
			local height = view.extent(nil, elementData)
			frame:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -offset)
			frame:SetPoint("RIGHT", self, "RIGHT")
			frame:SetHeight(height)
			offset = offset + height
			self.frames = self.frames or {}
			self.frames[#self.frames + 1] = frame
		end
	end
end

local function Color()
	return {
		GetRGB = noop,
		WrapTextInColorCode = function(_, text)
			return text
		end,
	}
end

local timers = {}
-- The page hides and the native page handoff happen on the next frame; run everything queued.
local function Flush()
	while #timers > 0 do
		table.remove(timers, 1)()
	end
end
local waypoints, opened, showAll = {}, {}, false
local reagents = {
	{ itemID = 1, need = 50, source = "gather" },
	{ itemID = 2, need = 20, source = "vendor" },
	{ itemID = 3, need = 10, source = "vendor" },
}
local apprentice = { name = "Apprentice", from = 0, cap = 75 }
local craftStep = { recipeID = 3275, crafts = 5, from = 1, to = 5, color = "green" }
local plan = {
	target = 100,
	crafts = { craftStep },
	steps = {
		-- The sub-craft that makes the craft's reagent, as its own row before the craft.
		{ band = apprentice, subcraft = { recipeID = 3276, itemID = 2, crafts = 5, made = 5 } },
		{ band = apprentice, craft = craftStep },
	},
	ranks = {},
	cost = 0,
	unpriced = 0,
	bands = { apprentice },
}

local function FirstAid(skill)
	return { skillLine = 129, name = "First Aid", icon = 135966, skill = skill, base = skill, max = 75, modifier = 0 }
end

local stale = setmetatable({}, {
	__index = function()
		return noop
	end,
})
local ns = {
	L = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	}),
	db = { routeTargets = { [129] = 100 }, showRouteTab = true },
	COLORS = setmetatable({}, {
		__index = Color,
	}),
	GatheredBy = {},
	LootedFrom = {},
	FormatNet = function(copper)
		return tostring(copper)
	end,
	NetCost = function()
		return 10
	end,
	Have = function()
		return 0
	end,
	IsLearned = function()
		return true
	end,
	IsTracked = function()
		return false
	end,
	SetTracked = noop,
	-- The page's profession picker asks the client for the gamepad check; this spec is about its layout.
	StepDropdownUnderGamepad = noop,
	SkippedRecipes = function()
		return {}
	end,
	PinnedRecipes = function()
		return {}
	end,
	HasAuctionator = function()
		return true
	end,
	AuctionatorAutoscan = function()
		return nil
	end,
	AuctionListName = function(profession)
		return "SkillUp: " .. profession
	end,
	ShowRecipe = noop,
	TrackerAttached = function()
		return true
	end,
	CollectMode = function()
		return "gather"
	end,
	SetCollectMode = noop,
	ShowAllGear = function()
		return showAll
	end,
	SetShowAllGear = function(show)
		showAll = show and true or false
	end,
	PlayerProfessions = function()
		return { [129] = FirstAid(1) }
	end,
	ProfessionSkillLine = function(_, reported)
		return reported
	end,
	RouteProfessions = function()
		return { [129] = FirstAid(48) }
	end,
	PlanRoute = function(profession)
		plan.profession = profession
		return plan
	end,
	RouteReagents = function()
		return reagents
	end,
	UnpricedReagents = function()
		return {}
	end,
	NextCraft = function()
		return { text = "Craft next", reason = "Nothing to craft on this route." }
	end,
	RouteBlocked = function()
		return nil
	end,
	RankText = function()
		return "Rank"
	end,
	Price = function()
		return { copper = 10, source = "auctionator" }
	end,
	PriceAge = function()
		return 90000
	end,
	PriceAgeText = function()
		return "2d ago"
	end,
	PriceSourceText = function()
		return ""
	end,
	NearestVendor = function()
		return nil
	end,
	NearestNPC = function()
		return nil
	end,
	NearestTrainer = function()
		return nil
	end,
	SetWaypoint = function(npcID)
		waypoints[#waypoints + 1] = npcID
		return true
	end,
	RecipeNPC = function()
		return 1234
	end,
	AddNearest = noop,
	AddCompanionHint = noop,
	AddSourceLines = noop,
	SuggestionNPC = function()
		return nil
	end,
	RecipeSuggestions = function()
		return {}
	end,
	RecipeBands = function()
		return {}
	end,
	ScrollSkill = function()
		return 1
	end,
	ScrollPrice = function()
		return nil
	end,
	Catalogue = {
		Hint = function() end,
		Recipe = function()
			return nil
		end,
	},
	TrainingFor = function()
		return nil
	end,
	NPCLocation = function()
		return { name = "Somewhere" }
	end,
	-- The tab settings ask the pages for a refresh; the route's own views are not this spec's subject.
	stale = stale,
	Changed = function(kind)
		if kind == "settings" then
			stale.pages()
		end
	end,
	WhenStale = function(name, handler)
		stale[name] = handler
	end,
	WhenEvent = noop,
	Print = noop,
	LastSkillUpPage = function()
		return nil
	end,
	SetLastSkillUpPage = noop,
	OnlyBuffsForLevel = function()
		return false
	end,
	SetOnlyBuffsForLevel = noop,
}
function ns.CanGather(itemID)
	if ns.LootedFrom[itemID] then
		return "loot"
	end
	local skillLine = ns.GatheredBy[itemID]
	local profession = skillLine and ns.PlayerProfessions()[skillLine]
	return profession and profession.name or nil
end

local env = setmetatable({
	ForeverCore = { ProfessionTabs = ProfessionTabs },
	-- SafeCall hands a caught error to the game's handler: here it fails the spec.
	geterrorhandler = function()
		return function(message)
			io.stderr:write("error handler: ", tostring(message), "\n")
			os.exit(1)
		end
	end,
	CreateFrame = CreateFrame,
	C_Texture = {
		GetAtlasInfo = function(atlas)
			-- The band's bar frame is its own wide art; every other atlas in this spec is square.
			if atlas == "Professions-skillbar-frame" then
				return { width = 451, height = 29 }
			end
			return { width = 32, height = 32 }
		end,
	},
	C_Timer = {
		After = function(_, fn)
			timers[#timers + 1] = fn
		end,
	},
	hooksecurefunc = function()
		error("the route page must not hook native profession methods")
	end,
	C_Item = {
		GetItemNameByID = function(itemID)
			return ({ "Light Leather", "Coarse Thread", "Simple Wood" })[itemID]
		end,
		GetItemIconByID = function()
			return 134400
		end,
		GetItemQualityByID = function()
			return nil
		end,
		RequestLoadItemDataByID = noop,
		GetItemInfo = function() end,
	},
	C_PaperDollInfo = {
		GetInventorySlotInfo = function()
			return 0, 134400
		end,
	},
	Professions = false,
	ProfessionsFrame = ProfessionsFrame,
	C_Spell = {
		GetSpellName = function(id)
			return "Spell " .. id
		end,
		GetSpellTexture = noop,
	},
	C_TradeSkillUI = {
		GetCraftableCount = function()
			return 5
		end,
		CraftRecipe = noop,
		OpenRecipe = function(recipeID)
			opened[#opened + 1] = recipeID
		end,
		GetRecipeInfo = function() end,
	},
	EventRegistry = {
		RegisterCallback = noop,
	},
	GameTooltip = NewRegion(nil),
	GameTooltip_SetTitle = noop,
	GameTooltip_AddNormalLine = noop,
	GameTooltip_AddDisabledLine = noop,
	GameTooltip_AddColoredDoubleLine = noop,
	GameTooltip_AddBlankLineToTooltip = noop,
	GameTooltip_AddHighlightLine = noop,
	GameTooltip_AddInstructionLine = noop,
	GameTooltip_Hide = noop,
	NORMAL_FONT_COLOR = Color(),
	HIGHLIGHT_FONT_COLOR = Color(),
	GRAY_FONT_COLOR = Color(),
	RED_FONT_COLOR = Color(),
	CreateColor = Color,
	CreateScrollBoxListLinearView = CreateScrollBoxListLinearView,
	CreateDataProvider = function(elements)
		return { elements = elements }
	end,
	ScrollUtil = { InitScrollBoxListWithScrollBar = InitScrollBoxList },
	ScrollBoxConstants = { RetainScrollPosition = true },
	IsModifiedClick = function()
		return false
	end,
	ChatFrameUtil = { InsertLink = noop },
	HandleModifiedItemClick = noop,
}, {
	__index = function(_, key)
		local value = _G[key]
		if value == nil then
			return noop
		end
		return value
	end,
})

ns.core = {
	SafeCall = function(_, fn, ...)
		return pcall(fn, ...)
	end,
}
for _, file in ipairs({
	"Locales/enUS.lua",
	"Data/Thresholds.lua",
	"Data/Recipes.lua",
	"Data/Trainer.lua",
	"Core/Model.lua",
	"Core/Changes.lua",
	"Core/Plan.lua",
	"UI/Art.lua",
	"UI/List.lua",
	"UI/PageParts.lua",
	"UI/Pages.lua",
	"UI/Route.lua",
	"UI/Gear.lua",
}) do
	setfenv(assert(loadfile(file)), env)("SkillUpForever", ns)
end

ns.RouteReagents = function()
	return reagents
end
ns.Reagents = function(recipeID)
	if recipeID == 2001 then
		return { { itemID = 1, quantity = 50 }, { itemID = 2, quantity = 20 } }
	end
	return {}
end
ns.PlanRoute = function(profession)
	plan.profession = profession
	return plan
end
ns.CraftedGear = function()
	local profession = FirstAid(1)
	local head = {
		{
			recipeID = 2001,
			itemID = 1001,
			name = "Known Helm",
			skillLine = 129,
			skill = 30,
			level = 20,
			profession = profession.name,
			learned = true,
			state = "known",
		},
		{
			recipeID = 2002,
			itemID = 1002,
			name = "Trainable Helm",
			skillLine = 129,
			skill = 40,
			level = 20,
			profession = profession.name,
			learned = false,
			state = "trainable",
		},
		{
			recipeID = 2003,
			itemID = 1003,
			name = "Far Helm",
			skillLine = 129,
			skill = 240,
			level = 20,
			profession = profession.name,
			learned = false,
			state = "needs",
		},
	}
	-- Every character-sheet slot is returned, as the real rule returns them, so a click on an empty
	-- slot keeps the selection.
	local slots = {}
	for index = 1, 15 do
		slots[index] = { slot = index, name = "Slot " .. index, items = index == 1 and head or {} }
	end
	return slots
end
ns.NextCraft = function()
	-- The bottom row is laid out with the craft button at its widest, so a longer label cannot reach
	-- a control beside it.
	return { text = "Craft 999× Cured Light Hide of the Bear", recipeID = 3275, count = 999, planned = 999, to = 100 }
end

ns.AttachRoute()
local tab = tabs[1]
local page = pageFrame
ns.db.showGearTab = true
ns.AttachGear()

-- One SkillUp side tab, whatever its pages, and it is the one core registered.
equal(#tabs, 1, "the pages share core's one side tab")
equal(tab, coreTab, "the side tab is the one core registered")
equal(tab.tooltipText, "SkillUp", "it says SkillUp")
equal(coreEntry.spec.minWidth, nil, "no recipe list here means no width of its own")
-- The tab stays while any page is on, and goes with the last one.
ns.db.showRouteTab = false
ns.Changed("settings")
equal(tab.shown, true, "the tab stays while the gear page is on")
ns.db.showGearTab = false
ns.Changed("settings")
equal(tab.shown, false, "the tab is hidden when every page is off")
ns.db.showRouteTab = true
ns.Changed("settings")
equal(tab.shown, true, "and comes back with one page on")

tab.scripts.OnMouseUp(nil, "LeftButton", true)
Flush()
equal(page ~= nil, true, "the route page is created")
equal(page.RouteList ~= nil and page.ReagentList ~= nil, true, "with its two lists")

local function Find(text)
	for _, region in ipairs(created) do
		if region.text == text then
			return region
		end
	end
end

local headings = { Find("Route"), Find("Reagents  (have / need)") }
equal(headings[1] ~= nil and headings[2] ~= nil, true, "the two inset headings exist")

local pageL, pageB, pageR, pageT = Rect(page)
for _, heading in ipairs(headings) do
	local left, bottom, right, top = Rect(heading)
	equal(left > pageL and right < pageR, true, heading.text .. " sits inside the page's width")
	equal(top < pageT and bottom > pageB, true, heading.text .. " sits inside the page's height")
	equal(overlaps(heading, titleBar), false, heading.text .. " misses the title bar")
	equal(overlaps(heading, ProfessionsFrame.portrait), false, heading.text .. " misses the portrait")
end

-- The switch and its label are one control in the header; the Track checkbox, the Replan button, Craft, the count
-- box and the vendor button share the bottom row, right to left, at their one fixed width each.
local controls = {
	page.Skill,
	page.Target,
	page.Collect,
	page.CollectLabel,
	page.Money,
	page.Vendor,
	page.Craft,
	page.CraftCount,
	page.Track,
	page.TrackLabel,
	page.Replan,
}
local names = {
	"the skill line",
	"the target box",
	"the switch",
	"the switch's label",
	"the money line",
	"the vendor button",
	"Craft",
	"Craft's count",
	"Track",
	"Track's label",
	"Replan",
}

for index, control in ipairs(controls) do
	for _, heading in ipairs(headings) do
		equal(overlaps(control, heading), false, names[index] .. " misses the " .. heading.text .. " heading")
	end
	local left, bottom, right, top = Rect(control)
	equal(left > pageL and right < pageR, true, names[index] .. " sits inside the page's width")
	equal(top < pageT and bottom > pageB, true, names[index] .. " sits inside the page's height")
	equal(overlaps(control, titleBar), false, names[index] .. " misses the title bar")
	equal(overlaps(control, ProfessionsFrame.portrait), false, names[index] .. " misses the portrait")
end

-- Long translated header labels still get a bounded rank column. This is the cooking 95/150 to target 150 shape
-- from the reported overlap: the rank line may be clipped by its own column, but never paints through its controls.
page.Skill:SetText("Kompetenz 95/150 Ziel")
page.CollectLabel:SetText("Materialien im Auktionshaus kaufen")
ns.Changed("settings")
for _, control in ipairs({ page.Skill, page.Target, page.Collect, page.CollectLabel }) do
	for _, other in ipairs({ page.Skill, page.Target, page.Collect, page.CollectLabel }) do
		if control ~= other then
			equal(overlaps(control, other), false, "translated header controls do not overlap")
		end
	end
end
for index, control in ipairs(controls) do
	equal(Width(control) > 0, true, names[index] .. " has a width to overlap with")
end
for i = 1, #controls do
	for j = i + 1, #controls do
		equal(overlaps(controls[i], controls[j]), false, names[i] .. " misses " .. names[j])
	end
end

-- The controls hang off existing regions, never off a hand-measured offset from the window top.
local switchAnchor = page.Collect.points[1]
equal(switchAnchor.relative, page.Target, "the switch hangs off the target it changes")
equal(switchAnchor.relativePoint, "RIGHT", "at the target's right, in the header")
local vendorAnchor = page.Vendor.points[1]
equal(vendorAnchor.relative, page.CraftCount, "the vendor button hangs off the count it sits beside")
equal(vendorAnchor.relativePoint, "LEFT", "at the count's left, in the bottom row")
local countAnchor = page.CraftCount.points[1]
equal(countAnchor.relative, page.Craft, "the count hangs off the craft button")
equal(countAnchor.relativePoint, "LEFT", "at the craft's left, in the bottom row")
local craftAnchor = page.Craft.points[1]
equal(craftAnchor.relative, insets[2], "the craft button ends the bottom row at the reagents' edge")
equal(craftAnchor.relativePoint, "BOTTOMRIGHT", "where the actions start from")
local trackLabelAnchor = page.TrackLabel.points[1]
equal(trackLabelAnchor.relative, page.Track, "the track label sits at the checkbox's right")
equal(trackLabelAnchor.relativePoint, "RIGHT", "so the checkbox keeps the row's left edge")
local trackAnchor = page.Track.points[1]
equal(trackAnchor.relative, insets[1], "and the checkbox sits at the route's bottom left")
equal(trackAnchor.relativePoint, "BOTTOMLEFT", "where the row starts")
local replanAnchor = page.Replan.points[1]
equal(replanAnchor.relative, page.TrackLabel, "Replan sits after the Track label")
equal(replanAnchor.relativePoint, "RIGHT", "in the bottom row's free space")

-- The footer is below the insets, not pressed against their lower art seam. Keep a real gap after the Track
-- checkbox and between its translated label and Replan, even when the host is at its fixed 673 px width.
local _, _, trackRight, trackTop = Rect(page.Track)
local labelLeft, _, labelRight, _ = Rect(page.TrackLabel)
local replanLeft, _, replanRight, replanTop = Rect(page.Replan)
local _, routeBoxBottom = Rect(insets[1])
equal(labelLeft - trackRight >= 4, true, "Track label has clearance from its checkbox")
equal(replanLeft - labelRight >= 20, true, "Replan has clearance from the Track label")
equal(trackTop < routeBoxBottom - 4, true, "Track clears the route inset seam")
equal(replanTop < routeBoxBottom - 4, true, "Replan clears the route inset seam")
equal(replanRight <= pageR, true, "Replan stays inside the host footer")
local _, trackFooterBottom, _, trackFooterTop = Rect(page.Track)
local _, craftFooterBottom, _, craftFooterTop = Rect(page.Craft)
equal(
	math.abs((trackFooterBottom + trackFooterTop) / 2 - (craftFooterBottom + craftFooterTop) / 2) < 1e-6,
	true,
	"footer controls share one baseline"
)
equal(routeBoxBottom - trackFooterTop >= 8, true, "Track clears the inset seam by 8 px")
local _, footerPageBottom = Rect(page)
equal(trackFooterBottom - footerPageBottom >= 8, true, "footer keeps host bottom clearance")
equal(Width(page.Replan), 80, "at its one fixed width")
equal(Width(page.Craft), 100, "the craft button keeps one width")
equal(Width(page.CraftCount), 62, "and the count box keeps its own")
equal(page.CraftCount.template, "NumericInputSpinnerTemplate", "the count uses the game's spinner count box")
equal(page.CraftCount.IncrementButton.shown, false, "with its up arrow hidden")
equal(page.CraftCount.DecrementButton.shown, false, "and its down arrow hidden")
equal(page.CraftCount.MouseWheelCatcher.mouseEnabled, false, "and no wheel capture")
equal(page.Track.checked, false, "the Track checkbox shows an untracked route")

-- The list's scroll box is what the addon places; the game lays the rows out inside it, so the scroll
-- box must sit inside the inset and every row the game draws inside the scroll box.
local routeLeft, _, routeRight, routeTop = Rect(insets[1])
local boxLeft, boxBottom, boxRight, boxTop = Rect(page.RouteList.scrollBox)
equal(boxLeft >= routeLeft and boxRight <= routeRight, true, "the route list's scroll box is inside its inset")
equal(boxTop <= routeTop and boxBottom >= routeBoxBottom, true, "and inside its height")
local routeRows = 0
for _, row in ipairs(page.RouteList.scrollBox.frames) do
	if row.kind == "row" then
		routeRows = routeRows + 1
		local left, bottom, right, top = Rect(row)
		equal(Width(row.Icon) >= 36, true, "a route row's icon is a full item icon")
		equal(left >= routeLeft and right <= routeRight, true, "the route row is inside its inset's width")
		equal(top <= routeTop and bottom >= routeBoxBottom, true, "and inside its height")
		local textLeft, textBottom, textRight = Rect(row.Text)
		equal(textLeft > left and textRight < right, true, "the name is inside the row")
		local detailLeft, _, detailRight, detailTop = Rect(row.Detail)
		equal(detailLeft >= textLeft and detailRight <= textRight, true, "the facts line spans the name's width")
		equal(detailTop <= textBottom, true, "and sits under the name")
	end
end
equal(routeRows, 2, "the route list draws the sub-craft and the craft as rows")

-- Skill bands use the same approved clean progress assets as reagent counts.
local bands = 0
for _, row in ipairs(page.RouteList.scrollBox.frames) do
	if row.kind == "band" then
		bands = bands + 1
		equal(row.BarBg.atlas, "common-stat-bar-BG", "a band draws the native clean bar background")
		equal(row.BarFill.atlas, "common-stat-bar-white", "a band draws the native clean bar fill")
		equal(Height(row.BarBg), 29, "at the native background height")
		equal(Height(row.BarFill), 15, "at the native fill height")
		equal(Width(row.BarBg), 170, "inside the band's bar width")
		-- The client's ColoredProgressBarTemplate keeps its fill 6 inside the frame's rim and masks it to the
		-- track; a fill flush with the frame draws over the rim.
		local frameLeft, frameBottom, frameRight, frameTop = Rect(row.BarBg)
		equal(Rect(row.BarFill) - frameLeft, 6, "a band's fill starts inside the frame's rim")
		local done, span = row.BarText.text:match("^(%d+)/(%d+)$")
		local fraction = math.min(tonumber(done) / tonumber(span), 1)
		equal(
			math.abs(Width(row.BarFill) - (Width(row.BarBg) - 12) * fraction) < 1e-9,
			true,
			"and fills only the track inside the rim"
		)
		local maskLeft, maskBottom, maskRight, maskTop = Rect(row.BarMask)
		equal(
			maskLeft == frameLeft and maskRight == frameRight and maskBottom == frameBottom and maskTop == frameTop,
			true,
			"a mask covers the band's frame"
		)
		equal(row.BarMask.atlas, "common-stat-bar-Mask", "the client's own bar mask")
		equal(row.BarFill.masks and row.BarFill.masks[1], row.BarMask, "shapes the band's fill to the track")
	end
end
equal(bands, 1, "the route draws its skill band's header")
local currentRow
for _, row in ipairs(page.RouteList.scrollBox.frames) do
	if row.current then
		currentRow = row
	end
end
equal(currentRow and currentRow.Text.text, "Spell 3275", "the next craft is marked as the current step")
equal(
	currentRow and currentRow.Current:IsShown(),
	true,
	"with the client's gold highlight over the row, not a recoloured name"
)
equal(Find("Apprentice") ~= nil, true, "the route opens with its skill band header")
equal(Find("0 to 75") ~= nil, true, "with the band's range beside it")
equal(Find("Craft 5× Spell 3276") ~= nil, true, "the sub-craft names itself as a craft")
equal(Find("makes 5 Coarse Thread") ~= nil, true, "and says how much of the reagent it makes")

-- A reagent row is the same item row: the icon, the name and where it comes from with how many of
-- the route's need the bags hold.
local reagentLeft, reagentBottom, reagentRight, reagentTop = Rect(insets[2])
local reagentBoxLeft, reagentBoxBottom, reagentBoxRight, reagentBoxTop = Rect(page.ReagentList.scrollBox)
equal(
	reagentBoxLeft >= reagentLeft and reagentBoxRight <= reagentRight,
	true,
	"the reagent list's scroll box is inside its inset"
)
equal(reagentBoxTop <= reagentTop and reagentBoxBottom >= reagentBottom, true, "and inside its height")
local reagentRows = 0
for _, row in ipairs(page.ReagentList.scrollBox.frames) do
	if row.kind == "row" then
		reagentRows = reagentRows + 1
		local left, bottom, right, top = Rect(row)
		equal(Width(row.Icon) >= 36, true, "a reagent row's icon is a full item icon")
		equal(left >= reagentLeft and right <= reagentRight, true, "the reagent row is inside its inset's width")
		equal(top <= reagentTop and bottom >= reagentBottom, true, "and inside its height")
		equal(
			Width(row.Text),
			row.entry.sourceIcon and 163.5 or 183.5,
			"a reagent row gives its name the room beside its source icon"
		)
		local _, barBottom, _, barTop = Rect(row.BarBg)
		local _, fillBottom, _, fillTop = Rect(row.Bar)
		local _, nameBottom = Rect(row.Text)
		local _, detailBottom, _, detailTop = Rect(row.Detail)
		equal(Height(row.BarBg), 29, "reagent background keeps native height")
		equal(Height(row.Bar), 15, "reagent fill keeps native height")
		local frameLeft, _, frameRight = Rect(row.BarBg)
		local fillLeft, _, fillRight = Rect(row.Bar)
		equal(fillLeft - frameLeft, 6, "a reagent fill starts inside the frame's rim")
		equal(frameRight - fillRight, 6, "and a full one ends inside it")
		equal(row.Bar:GetStatusBarTexture().masks[1], row.BarMask, "the frame's mask shapes the reagent fill")
		equal(row.BarMask.atlas, "common-stat-bar-Mask", "with the client's own bar mask")
		equal(fillBottom >= barBottom and fillTop <= barTop, true, "fill stays inside its background")
		equal(nameBottom - barTop >= 3, true, "bar clears the item name")
		equal(barBottom - detailTop >= 3, true, "bar clears the source label")
		equal(
			detailBottom >= bottom,
			true,
			("source label stays inside its row (%s >= %s)"):format(detailBottom, bottom)
		)
		equal(row.barNeed, row.entry.bar.need, "a reagent row carries its have/need bar")
		equal(row.Source.shown, row.entry.sourceIcon ~= nil, "and a source icon where the source has one")
	end
end
equal(reagentRows, 3, "the reagent list draws a row a reagent")

-- The gear page is the window's other page. Its title, switch and rows all sit inside the visible
-- page, under the window's title bar and clear of its portrait, as the route page's own controls do.
ns.db.showGearTab = true
ns.Changed("settings")
local routePage, gearPage = page, pageFrame
local routeTab = tab
local routeBottom = ns.Pages.BottomTab("route")
local gearTab = ns.Pages.BottomTab("gear")
local gearInset = insets[3]
local _, pageBottom, _, pageTop = Rect(page)
local insetLeft, insetBottom, insetRight, gearTop = Rect(gearInset)
equal(gearTop, 506, "the gear inset starts under the window's title bar")
equal(overlaps(gearInset, titleBar), false, "the gear inset misses the title bar")
equal(overlaps(gearInset, ProfessionsFrame.portrait), false, "and the portrait")

local title = Find("Crafted gear")
local titleLeft, titleBottom, titleRight, titleTop = Rect(title)
equal(title ~= nil, true, "the gear page has its title")
equal(overlaps(title, titleBar), false, "the title misses the title bar")
equal(overlaps(title, ProfessionsFrame.portrait), false, "and the portrait")
equal(titleTop <= pageTop and titleBottom >= pageBottom, true, "the title sits inside the page")
equal(titleLeft > insetLeft and titleRight <= insetRight, true, "over its inset width")

local switch = gearPage.ShowAll
equal(switch ~= nil and gearPage.ShowAllLabel ~= nil, true, "the gear page has its switch")
equal(Width(switch) > 0, true, "the switch has a width to overlap with")
equal(overlaps(switch, titleBar), false, "the switch misses the title bar")
equal(overlaps(switch, ProfessionsFrame.portrait), false, "and the portrait")
equal(overlaps(switch, title), false, "and the title")
equal(switch.points[1].relative, gearInset, "the switch hangs off the gear inset")

-- The gear bottom tab shows the page and hides the route's; the first render fills the doll.
gearTab.scripts.OnClick()
Flush()
equal(gearPage:IsShown(), true, "the gear tab shows the gear page")
equal(routePage:IsShown(), false, "and hides the route page")
equal(routeTab.checked, true, "with the side tab checked while a page shows")

-- The paper doll: one stock-size slot button a character-sheet slot, inside the inset, clear of the
-- title bar and portrait, and clear of each other.
local slots = gearPage.Slots
equal(#slots, 15, "the doll has a slot a character-sheet slot")
for index, slot in ipairs(slots) do
	local left, bottom, right, top = Rect(slot)
	equal(Width(slot), 37, "slot " .. index .. " is a stock-size item slot")
	equal(left > insetLeft and right < insetRight, true, "slot " .. index .. " is inside the inset's width")
	equal(top < gearTop and bottom > insetBottom, true, "slot " .. index .. " is inside its height")
	equal(overlaps(slot, titleBar), false, "slot " .. index .. " misses the title bar")
	equal(overlaps(slot, ProfessionsFrame.portrait), false, "slot " .. index .. " misses the portrait")
end
for i = 1, #slots do
	for j = i + 1, #slots do
		equal(overlaps(slots[i], slots[j]), false, "slot " .. i .. " misses slot " .. j)
	end
end

-- The pane for the selected slot: the pick's icon and name, its reagents and its one button, all
-- inside the pane and clear of the doll.
local pane = gearPage.Detail
local paneLeft, paneBottom, paneRight, paneTop = Rect(pane)
equal(pane.Body:IsShown(), true, "the pane shows a pick")
equal(pane.Empty:IsShown(), false, "and not its empty state")
for index, slot in ipairs({ slots[1], slots[7], slots[13] }) do
	equal(overlaps(slot, pane), false, "doll slot " .. index .. " misses the pane")
end
local iconLeft, iconBottom, iconRight, iconTop = Rect(pane.Icon)
equal(iconRight - iconLeft >= 36, true, "the pane's icon is a full-size item icon")
equal(iconLeft >= paneLeft and iconRight <= paneRight, true, "the pane's icon is inside the pane")
equal(iconTop <= paneTop and iconBottom >= paneBottom, true, "and inside its height")
equal(pane.Name.text ~= nil, true, "the pane names the pick")
local nameLeft, _, _, nameTop = Rect(pane.Name)
equal(nameLeft > iconRight, true, "the name sits beside the icon")
equal(nameTop <= iconTop, true, "at the icon's top")
equal(pane.ReagentRows[1] ~= nil and pane.ReagentRows[1]:IsShown(), true, "the pane draws its reagents")
equal(Width(pane.ReagentRows[1].Icon) >= 36, true, "a reagent row's icon is a full item icon")
local paneReagentLeft, _, paneReagentRight = Rect(pane.ReagentRows[1])
equal(paneReagentLeft >= paneLeft and paneReagentRight <= paneRight, true, "the reagent row is inside the pane")
equal(overlaps(pane.ReagentRows[1], pane.Action), false, "a reagent row misses the action button")
local paneActionLeft, _, paneActionRight = Rect(pane.Action)
equal(paneActionLeft >= paneLeft and paneActionRight <= paneRight, true, "the action button is inside the pane")
equal(overlaps(pane.Action, titleBar), false, "the action button misses the title bar")
equal(pane.Also:IsShown(), true, "the pane lists the slot's other items")
equal(pane.OtherRows[1] ~= nil and pane.OtherRows[1]:IsShown(), true, "with a row a remaining item")
local paneOtherLeft, _, paneOtherRight = Rect(pane.OtherRows[1])
equal(paneOtherLeft >= paneLeft and paneOtherRight <= paneRight, true, "the other item's row is inside the pane")

-- The action button: a known pick opens the recipe, a trainable one sets a waypoint to where it is
-- taught, and one out of reach is disabled with the reason why.
pane.Action:Click()
equal(opened[#opened], 2001, "a known pick's button opens its recipe")
pane.OtherRows[1]:Click()
equal(pane.Action.text, "Set waypoint", "a trainable pick's button names the waypoint")
pane.Action:Click()
equal(waypoints[1], 1234, "a trainable pick's button sets a waypoint to where it is learned")
pane.OtherRows[2]:Click()
equal(pane.Action:IsEnabled(), false, "a pick out of reach disables its button")
equal(pane.Action.reason ~= nil, true, "with the reason why")

-- Clicking a slot selects it and shows the stock selection highlight.
slots[2]:Click()
equal(slots[2].checked, true, "the clicked slot is checked")
equal(slots[1].checked, false, "and the first is not")

-- The switch saves the rule for the list.
switch:SetChecked(true)
switch.scripts.OnClick(switch)
equal(showAll, true, "the switch saves the choice")

routeBottom.scripts.OnClick()
Flush()
equal(routePage:IsShown(), true, "the route tab shows the route page")
equal(gearPage:IsShown(), false, "and hides the gear page")
equal(routeTab.checked, true, "with the side tab checked")

gearTab.scripts.OnClick()
Flush()
routeBottom.scripts.OnClick()
Flush()
equal(routePage:IsShown(), true, "a second route click shows the route page again")
equal(gearPage:IsShown(), false, "and still hides the gear page")
equal(routeTab.checked, true, "with the side tab checked")

-- ForeverCore hands the window back when the player picks a client tab or page: core hides SkillUp's page and
-- unchecks the side tab. The client's own page is never hidden by this addon.
ProfessionTabs.ShowNative()
Flush()
equal(routePage:IsShown(), false, "a client tab hides the route page")
equal(gearPage:IsShown(), false, "and the gear page")
equal(routeTab.checked, false, "the side tab unchecks")
equal(ProfessionsFrame.CraftingPage:IsShown(), true, "and the client's own page stays shown")

-- Closing the window hands it back the same way.
routeBottom.scripts.OnClick()
Flush()
equal(routePage:IsShown(), true, "the route page shows before the window closes")
ProfessionsFrame:Hide()
Flush()
equal(routePage:IsShown(), false, "closing the window hides the route page")
equal(routeTab.checked, false, "and unchecks the side tab")
ProfessionsFrame:Show()

-- #398: under the gamepad interface, opening the Professions window runs SmartNavigation's panel scan
-- (Blizzard_GamepadSmartNavigation, FindButtons and SmartNavigation_CanFocusFrame at Forever 1.60.1). For a
-- frame that is not a Button or an EditBox it calls GetScript("OnMouseUp") and GetScript("OnMouseDown") to
-- tell a button-like frame from a plain one. That read is inside the gamepad's own call, so a script on a
-- frame this addon made taints the call: the action bar's protected SetPreferredGamepadInteractTarget is
-- then refused and blamed on us. Our side tab and page tabs are the only button-like frames here, and all
-- must be real Buttons so the scan never reads their scripts.
local scriptReads = {}
local function ScanForScriptReads(frame)
	local isButton = frame:IsObjectType("Button") or frame:IsObjectType("EditBox")
	if not isButton then
		if frame:GetScript("OnMouseUp") ~= nil or frame:GetScript("OnMouseDown") ~= nil then
			scriptReads[#scriptReads + 1] = frame
		end
	end
	for _, child in ipairs({ frame:GetChildren() }) do
		ScanForScriptReads(child)
	end
end
ScanForScriptReads(ProfessionsFrame)
equal(#scriptReads, 0, "the gamepad scan reads no script from a frame SkillUp made")
equal(routeTab:IsObjectType("Button"), true, "the SkillUp side tab is a Button, so the scan skips its scripts")
equal(routeBottom:IsObjectType("Button"), true, "and the route page tab is one too")
equal(gearTab:IsObjectType("Button"), true, "and the gear page tab")

Client.report("route_layout_spec")
