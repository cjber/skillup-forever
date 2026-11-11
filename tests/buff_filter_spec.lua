-- Run from the repository root: luajit tests/buff_filter_spec.lua
-- The recipe list's buff filter: off leaves Blizzard's provider alone; on, only the recipes whose product
-- is a buff this character's level can use are listed, highest required level first, with the unlearned
-- ones under the divider when those are listed. A chosen sort mode still orders it, an empty match is an
-- empty list, and the Filter menu's checkbox toggles the setting.
local function noop() end

local function Font()
	local font = { text = "", shown = true }
	function font:SetText(text)
		self.text = text
	end
	function font:SetFormattedText(format, value)
		self.text = string.format(format, value)
	end
	function font:GetStringWidth()
		return #self.text * 6
	end
	function font:GetWidth()
		return self.width or 0
	end
	function font:Hide()
		self.shown = false
	end
	function font:Show()
		self.shown = true
	end
	function font:IsShown()
		return self.shown
	end
	function font.SetWidth() end
	function font.SetJustifyH() end
	function font.SetTextColor() end
	function font.ClearAllPoints() end
	function font.SetPoint() end
	return font
end

local function Node(data, children)
	local node = { data = data, children = children or {} }
	function node:GetData()
		return self.data
	end
	function node:GetNodes()
		return self.children
	end
	function node:Insert(value)
		local child = Node(value)
		self.children[#self.children + 1] = child
		return child
	end
	return node
end

-- A provider whose Insert appends to its root and returns the new node, as Blizzard's tree does.
local function Provider(nodes)
	local root = Node(nil, nodes or {})
	local provider = { root = root }
	function provider:GetRootNode()
		return self.root
	end
	function provider:Insert(data)
		return self.root:Insert(data)
	end
	return provider
end

local provider, callback, owner, replacements = nil, nil, nil, 0
local box = {}
function box.RegisterCallback(_, event, fn, target)
	assert(event == "OnDataProviderReassigned")
	callback, owner = fn, target
end
function box.GetDataProvider()
	return provider
end
function box.SetDataProvider(_, value)
	provider, replacements = value, replacements + 1
	assert(replacements < 10, "the list must not rebuild itself forever")
	callback(owner, box)
end

local recipeList = { ScrollBox = box, FilterDropdown = {}, width = 304, visible = true }
function recipeList:GetWidth()
	return self.width
end
function recipeList:SetWidth(width)
	self.width = width
end
function recipeList:IsVisible()
	return self.visible
end
function recipeList.CreateFontString()
	return Font()
end

local page = { RecipeList = recipeList }
local frame = { CraftingPage = page, width = 673, professionInfo = { professionID = 171 } }
function frame:GetWidth()
	return self.width
end
function frame:SetWidth(width)
	self.width = width
end

local playerLevel = 20
local ctx = { skillLine = 171, skill = 50, base = 45, modifier = 5 }
local thresholds = {
	[1] = { 1, 25, 50, 75 },
	[2] = { 100, 125, 150, 175 },
}
local ns = {
	L = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	}),
	db = {
		sortMode = "blizzard",
		wideRecipeList = false,
		showRowText = true,
		showUnlearned = false,
		buffsOnly = false,
	},
	SORT_OPTIONS = {
		{ "blizzard", "Default" },
		{ "skill", "Skill range start" },
	},
	SkillContext = function()
		return ctx
	end,
	UnlearnedRecipes = function()
		return {
			{ recipeID = 5, name = "Unlearned Buff", kind = "trainer", skill = 50, thresholds = { 1, 25, 50, 75 } },
			{ recipeID = 6, name = "Unlearned Potion", kind = "trainer", skill = 60, thresholds = { 1, 25, 50, 75 } },
		}
	end,
	Model = {
		Get = function(recipeID)
			return thresholds[recipeID] or { 1, 25, 50, 75 }
		end,
	},
	Describe = function()
		return { thresholds = { 1, 25, 50, 75 }, chance = 0.5, perSkillUp = 3 }
	end,
	LearnSourceText = function(source)
		return string.format("%s %d", source.kind, source.skill)
	end,
	FormatRow = function()
		return "50%"
	end,
	RowColor = function()
		return { GetRGB = noop }
	end,
	WhenStale = noop,
	WhenEvent = noop,
	GamepadUI = function()
		return false
	end,
	AttachRoute = noop,
	AttachGear = noop,
	AttachAuctionSearch = noop,
	AttachDetailsBar = noop,
	ShowRecipeTooltip = noop,
	Readable = function(value)
		return value
	end,
	Print = function(message)
		error(message)
	end,
	SetSortMode = function()
		error("unexpected sort failure")
	end,
}
-- The range start the list sorts by, from the bundle's own first threshold: this harness has no learn sources.
function ns.RangeThresholds(_, recipeID)
	return ns.Model.Get(recipeID)
end
-- The real setter lives in UI/Settings.lua and writes through the setting; here the saved value is enough.
function ns.SetBuffsOnly(on)
	ns.db.buffsOnly = on
end

local MENU_REFRESH = "refresh"
local menuGenerator
local function Description()
	local description = { checkboxes = {}, titles = {} }
	function description.CreateDivider() end
	function description:CreateTitle(text)
		self.titles[#self.titles + 1] = text
	end
	function description:CreateCheckbox(text, isSelected, setSelected)
		self.checkboxes[#self.checkboxes + 1] = { text = text, isSelected = isSelected, setSelected = setSelected }
		return {}
	end
	function description.CreateRadio() end
	return description
end

local env = setmetatable({
	ProfessionsFrame = frame,
	Professions = {
		GetHighestLearnedRecipe = function(info)
			return info.learned and info or nil
		end,
	},
	C_TradeSkillUI = {
		GetCraftableCount = function()
			return 0
		end,
	},
	UnitLevel = function()
		return playerLevel
	end,
	UIParent = {
		GetWidth = function()
			return 1920
		end,
	},
	InCombatLockdown = function()
		return false
	end,
	ScrollUtil = { AddInitializedFrameCallback = noop },
	EventRegistry = { RegisterCallback = noop },
	Menu = {
		ModifyMenu = function(_, generator)
			menuGenerator = generator
		end,
	},
	MenuResponse = { Refresh = MENU_REFRESH },
	ScrollBoxConstants = { RetainScrollPosition = true },
	CreateTreeDataProvider = Provider,
	GRAY_FONT_COLOR = { GetRGB = noop },
	strcmputf8i = function(a, b)
		if a == b then
			return 0
		end
		return a < b and -1 or 1
	end,
	hooksecurefunc = function()
		error("native recipe methods must stay unhooked")
	end,
}, { __index = _G })

setfenv(assert(loadfile("Core/Gear.lua")), env)("SkillUpForever", ns)

-- The spec's own recipe data: an elixir (level 10), buff food (level 25), a healing potion and a sword
-- that are no buff, two unlearned recipes (one buff), and a recipe whose output is no item.
ns.RecipeData = {
	[1] = { skillLine = 171, output = { itemID = 100, quantity = 1 } },
	[2] = { skillLine = 185, output = { itemID = 101, quantity = 1 } },
	[3] = { skillLine = 171, output = { itemID = 102, quantity = 1 } },
	[4] = { skillLine = 164, output = { itemID = 103, quantity = 1 } },
	[5] = { skillLine = 171, output = { itemID = 104, quantity = 1 } },
	[6] = { skillLine = 171, output = { itemID = 105, quantity = 1 } },
	[9] = { skillLine = 171, output = false },
}
ns.BuffItems = { [100] = 1, [101] = 2, [104] = 4 }
ns.ItemGear = {
	[100] = { 10 },
	[101] = { 25 },
	[102] = { 5 },
	[103] = { 0 },
	[104] = { 15 },
	[105] = { 5 },
}

setfenv(assert(loadfile("UI/RecipeList.lua")), env)("SkillUpForever", ns)
ns.AttachRecipeList()

local input = Provider({
	Node({ recipeInfo = { recipeID = 1, name = "Elixir", learned = true } }),
	Node({ recipeInfo = { recipeID = 2, name = "Buff Food", learned = true } }),
	Node({ recipeInfo = { recipeID = 3, name = "Healing Potion", learned = true } }),
	Node({ recipeInfo = { recipeID = 4, name = "Sword", learned = true } }),
})

local function Nodes()
	return provider:GetRootNode():GetNodes()
end

-- Off, the client's provider stands as it did before the filter existed.
box:SetDataProvider(input)
assert(provider == input and replacements == 1, "the filter off leaves the client's provider alone")

-- On at level 20, only the elixir can be used: the level 25 food, the potion and the sword are out.
ns.db.buffsOnly = true
replacements = 0
box:SetDataProvider(input)
assert(provider ~= input, "the filter on installs the addon's list")
local nodes = Nodes()
assert(#nodes == 1, "only the elixir is left")
assert(nodes[1]:GetData().recipeInfo.recipeID == 1, "and it is the elixir")
assert(nodes[1]:GetData().recipeInfo.learned == true, "the client's own learned node data is kept")

-- At level 30 both buffs fit, and the higher required level comes first.
playerLevel = 30
replacements = 0
box:SetDataProvider(input)
nodes = Nodes()
assert(#nodes == 2, "both buffs fit at level 30")
assert(nodes[1]:GetData().recipeInfo.recipeID == 2, "the level 25 food comes first")
assert(nodes[2]:GetData().recipeInfo.recipeID == 1, "then the level 10 elixir")

-- With unlearned recipes listed, an unlearned buff follows the divider; a non-buff stays out.
ns.db.showUnlearned = true
replacements = 0
box:SetDataProvider(input)
nodes = Nodes()
assert(#nodes == 4, "two learned buffs, a divider and one unlearned buff")
assert(nodes[1]:GetData().recipeInfo.recipeID == 2 and nodes[2]:GetData().recipeInfo.recipeID == 1)
assert(nodes[3]:GetData().isDivider, "the divider is Blizzard's own")
assert(nodes[4]:GetData().recipeInfo.recipeID == 5, "the unlearned buff recipe follows")
assert(nodes[4]:GetData().recipeInfo.learned == false, "and is marked unlearned")
for _, node in ipairs(nodes) do
	local info = node:GetData().recipeInfo
	assert(not info or info.recipeID ~= 6, "an unlearned recipe that is no buff is left out")
end

-- A chosen sort mode orders by its own key instead of the required level.
ns.db.showUnlearned = false
ns.db.sortMode = "skill"
replacements = 0
box:SetDataProvider(input)
nodes = Nodes()
assert(#nodes == 2, "the sort mode keeps both buffs")
assert(nodes[1]:GetData().recipeInfo.recipeID == 1, "the skill sort puts the elixir first")
assert(nodes[2]:GetData().recipeInfo.recipeID == 2, "then the food, the reverse of the level order")

-- Nothing matching is an empty list, not the client's list.
ns.db.sortMode = "blizzard"
playerLevel = 5
replacements = 0
box:SetDataProvider(input)
nodes = Nodes()
assert(provider ~= input, "the empty match still installs the addon's list")
assert(#nodes == 0, "and that list has no rows")

-- The Filter menu's checkbox reads the setting and toggles it.
playerLevel = 30
ns.db.buffsOnly = false
assert(menuGenerator, "the Filter menu is registered")
local menu = Description()
menuGenerator(recipeList.FilterDropdown, menu)
assert(#menu.checkboxes == 1, "the menu gets one new checkbox")
local checkbox = menu.checkboxes[1]
assert(checkbox.text == "Only buffs for your level", "named for the buff filter")
assert(checkbox.isSelected() == false, "unchecked while the setting is off")
assert(checkbox.setSelected() == MENU_REFRESH, "checking it refreshes the menu")
assert(ns.db.buffsOnly == true, "and turns the filter on")

-- BuffLevel is nil for a recipe with no item output, and for a product that is no buff.
assert(ns.BuffLevel(9) == nil, "a recipe with output false has no buff level")
assert(ns.BuffLevel(3) == nil, "a healing potion is no buff")
assert(ns.BuffLevel(1) == 10, "the elixir asks for level 10")
assert(ns.BuffLevel(5) == 15, "the unlearned buff asks for level 15")

-- A buff item with no ItemGear row reads as level 0, not as no buff.
ns.ItemGear[100] = nil
assert(ns.BuffLevel(1) == 0, "a buff item with no gear row needs no level")

print("buff_filter_spec: off, level filter, order, unlearned, sort mode, empty, menu and BuffLevel: ok")
