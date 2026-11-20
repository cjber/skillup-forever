-- Run from the repository root: luajit tests/unlearned_list_spec.lua
-- The recipe list's unlearned rows: the setting off leaves Blizzard's provider alone; on, the categories
-- stay as the client built them, favourites included, the bundle's unlearned recipes follow under a
-- divider, and one the client already lists is not added twice. The added row shows its source and skill
-- while the recipe preview owns its click.
local Client = dofile("tests/client.lua")
local client = Client.load({
	boot = false,
	data = {
		RecipeData = {
			[20] = { skillLine = 165, reagents = {}, output = { itemID = 100, quantity = 1 } },
			[30] = { skillLine = 165, reagents = {}, output = { itemID = 200, quantity = 1 } },
		},
	},
})
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
	function font:SetWidth(width)
		self.width = width
	end
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
local searchText
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
local original = box.SetDataProvider

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
page.Init = noop
local frame = { CraftingPage = page, width = 673, professionInfo = { professionID = 165 } }
function frame:GetWidth()
	return self.width
end
function frame:SetWidth(width)
	self.width = width
end

local decorate
local itemDataArrived
local previewRows = {}
local ctx = { skillLine = 165, skill = 50, base = 45, modifier = 5 }
local ns = {
	RecipeData = client.ns.RecipeData,
	L = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	}),
	db = {
		sortMode = "blizzard",
		unlearnedSortMode = "skill",
		wideRecipeList = false,
		showRowText = true,
		showUnlearned = true,
	},
	SkillContext = function()
		return ctx
	end,
	UnlearnedRecipes = function()
		return {
			{ recipeID = 20, name = "Ahead", kind = "trainer", skill = 60, thresholds = { 1, 25, 50, 75 } },
			{
				recipeID = 30,
				name = "Recipe item",
				kind = "scroll",
				skill = 80,
				itemID = 9001,
				thresholds = { 1, 25, 50, 75 },
			},
		}
	end,
	Model = {
		Get = function()
			return { 1, 25, 50, 75 }
		end,
	},
	RangeThresholds = function(_, id)
		local starts = { [10] = 1, [20] = 60, [30] = 80 }
		return { starts[id], 100, 100, 100 }
	end,
	LearnSourceText = function(source)
		local text = source.kind == "trainer" and "Trainer" or "Recipe item"
		if source.skill > 0 then
			text = string.format("%s %d", text, source.skill)
		end
		return text
	end,
	Describe = function()
		return { thresholds = { 1, 25, 50, 75 }, chance = 0.5, perSkillUp = 3 }
	end,
	FormatRow = function()
		return "50%"
	end,
	RowColor = function()
		return { GetRGB = noop }
	end,
	WhenStale = noop,
	RequestItemData = function(itemID)
		client.G.C_Item.RequestLoadItemDataByID(itemID)
	end,
	WhenEvent = function(event, handler)
		if event == "ITEM_DATA_LOAD_RESULT" then
			itemDataArrived = handler
		end
	end,
	GamepadUI = function()
		return false
	end,
	AttachRoute = noop,
	AttachGear = noop,
	AttachAuctionSearch = noop,
	AttachDetailsBar = noop,
	AttachRecipePreview = function()
		return function(row, data)
			previewRows[row] = data
		end
	end,
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

local env = setmetatable({
	C_Item = client.G.C_Item,
	ProfessionsFrame = frame,
	Professions = {
		GetHighestLearnedRecipe = function(info)
			return info.learned and info or nil
		end,
	},
	C_TradeSkillUI = {
		IsTradeSkillLinked = function()
			return false
		end,
		IsTradeSkillGuild = function()
			return false
		end,
		GetCraftableCount = function()
			return 0
		end,
		GetRecipeItemLevelFilter = client.G.C_TradeSkillUI.GetRecipeItemLevelFilter,
		GetRecipeItemNameFilter = function()
			return searchText
		end,
		GetAllRecipeIDs = function()
			return { 10 }
		end,
		GetRecipeInfo = function(recipeID)
			return recipeID == 10 and { recipeID = 10, name = "Learned", learned = true } or nil
		end,
	},
	UIParent = {
		GetWidth = function()
			return 1920
		end,
	},
	InCombatLockdown = function()
		return false
	end,
	ScrollUtil = {
		AddReleasedFrameCallback = noop,
		AddInitializedFrameCallback = function(_, fn)
			decorate = fn
		end,
	},
	EventRegistry = { RegisterCallback = noop },
	Menu = { ModifyMenu = noop },
	ScrollBoxConstants = { RetainScrollPosition = true },
	CreateTreeDataProvider = Provider,
	GRAY_FONT_COLOR = { GetRGB = noop },
	strlower = string.lower,
	strfind = string.find,
	hooksecurefunc = function()
		error("native recipe methods must stay unhooked")
	end,
}, { __index = _G })

setfenv(assert(loadfile("UI/RecipeList.lua")), env)("SkillUpForever", ns)
ns.AttachRecipeList()

-- The client's provider: a favourites category holding its favourite, then a learned recipe in a category.
local learned = Node({ recipeInfo = { recipeID = 10, name = "Learned", learned = true } })
local favourites = Node({ recipeInfo = { recipeID = 10, name = "Learned", learned = true, favoritesInstance = true } })
local input = Provider({
	Node({ categoryInfo = { name = "Favourites", group = 0, uiOrder = 0 } }, { favourites }),
	Node({ categoryInfo = { name = "Basics", group = 1, uiOrder = 1 } }, {
		Node({ topPadding = true }),
		learned,
		Node({ bottomPadding = true }),
	}),
})

-- Off, the native provider stands.
ns.db.showUnlearned = false
box:SetDataProvider(input)
assert(provider == input and replacements == 1, "the setting off leaves the client's provider alone")

-- On, the categories are kept exactly as the client built them, favourites included, and the unlearned
-- recipes follow.
ns.db.showUnlearned = true
replacements = 0
box:SetDataProvider(input)
assert(box:GetDataProvider() ~= input and replacements == 2, "the setting on installs the addon's provider once")
local root = box:GetDataProvider():GetRootNode()
local nodes = root:GetNodes()
assert(#nodes == 5, "two categories, a divider and two unlearned recipes")
assert(nodes[1]:GetData().categoryInfo.name == "Favourites", "the favourites category is kept")
assert(#nodes[1]:GetNodes() == 1, "a favourite survives with the setting on")
assert(nodes[1]:GetNodes()[1]:GetData().recipeInfo.favoritesInstance, "as the client's favourites entry")
assert(nodes[2]:GetData().categoryInfo.name == "Basics", "the other category is copied")
assert(#nodes[2]:GetNodes() == 3, "with its padding and learned recipe")
assert(nodes[2]:GetNodes()[2]:GetData().recipeInfo.recipeID == 10, "the favourite's recipe stays in its own category")
assert(nodes[3]:GetData().isDivider, "the divider is Blizzard's own")
assert(nodes[4]:GetData().recipeInfo.recipeID == 20, "the first unlearned recipe")
assert(nodes[4]:GetData().recipeInfo.learned == false, "it is marked unlearned")
assert(nodes[4]:GetData().recipeInfo.skillUpUnlearned.kind == "trainer", "and carries its source")
assert(nodes[5]:GetData().recipeInfo.recipeID == 30, "the second unlearned recipe")
assert(box.SetDataProvider == original, "the native method is still the native method")

-- A recipe the client itself lists unlearned is not added again.
local nativeUnlearned = Node({ recipeInfo = { recipeID = 20, name = "Ahead", learned = false } })
provider = nil
replacements = 0
local withUnlearned = Provider({
	Node({ categoryInfo = { name = "Unlearned", group = 2, uiOrder = 2 } }, { nativeUnlearned }),
})
ns.UnlearnedRecipes = function()
	return {
		{ recipeID = 20, name = "Ahead", kind = "trainer", skill = 60, thresholds = { 1, 25, 50, 75 } },
		{
			recipeID = 30,
			name = "Recipe item",
			kind = "scroll",
			skill = 80,
			itemID = 9001,
			thresholds = { 1, 25, 50, 75 },
		},
	}
end
box:SetDataProvider(withUnlearned)
nodes = box:GetDataProvider():GetRootNode():GetNodes()
assert(nodes[1]:GetData().isDivider, "native and bundled unlearned rows share the sorted group")
assert(nodes[2]:GetData().recipeInfo.recipeID == 20, "the native unlearned recipe appears once in skill order")
assert(#nodes == 3 and nodes[3]:GetData().recipeInfo.recipeID == 30, "only the missing recipe is added")

-- The client's search filters the recipes the bundle adds, as it filters the client's own rows. A match
-- keeps only the matching added recipe, no match leaves the client's filtered list alone, and clearing the
-- search brings both added recipes back.
searchText = "RECIPE"
provider, replacements = nil, 0
box:SetDataProvider(input)
nodes = box:GetDataProvider():GetRootNode():GetNodes()
assert(#nodes == 4, "two categories, a divider and only the matching unlearned recipe")
assert(nodes[4]:GetData().recipeInfo.recipeID == 30, "the added recipe whose name matches stays")
searchText = "missing"
provider, replacements = nil, 0
box:SetDataProvider(input)
assert(provider == input, "no matching added recipe leaves the client's provider alone")
searchText = ""
provider, replacements = nil, 0
box:SetDataProvider(input)
nodes = box:GetDataProvider():GetRootNode():GetNodes()
assert(#nodes == 5, "clearing the search brings both added recipes back")
searchText = nil

-- Bounds are the client's parsed search state: N, ~N (+/-2), and N-M.
client.items[100] = { name = "Output A", level = 60 }
client.items[200] = { name = "Output B", level = 52 }
local function CheckLevels(low, high, expected)
	client.recipeItemLevelMin, client.recipeItemLevelMax = low, high
	provider, replacements = nil, 0
	box:SetDataProvider(input)
	local ids = {}
	for _, node in ipairs(box:GetDataProvider():GetRootNode():GetNodes()) do
		local info = node:GetData().recipeInfo
		if info then
			ids[#ids + 1] = info.recipeID
		end
	end
	assert(table.concat(ids, ",") == expected, "numeric bounds " .. low .. "-" .. high)
end
CheckLevels(60, 60, "20")
CheckLevels(70, 70, "")
CheckLevels(58, 62, "20")
CheckLevels(50, 60, "20,30")
client.items[100].level = nil
CheckLevels(60, 60, "")
assert(client.requested[100], "an uncached output requests its client data")
assert(itemDataArrived() == nil, "unrelated item data does not rebuild the list")
client.items[100].level = 60
assert(itemDataArrived() == "recipeFilter", "the awaited level invalidates the recipe filter")
CheckLevels(60, 60, "20")
client.ns.RecipeData[20].output = false
CheckLevels(60, 60, "")
CheckLevels(0, 0, "20,30")
assert(itemDataArrived() == nil, "clearing the filter stops waiting on item levels")

-- Legacy wide-list settings no longer resize the shared host or native list.
ns.db.wideRecipeList = true
recipeList.width, frame.width = 304, 900
box:SetDataProvider(input)
assert(recipeList.width == 304 and frame.width == 900, "the unlearned row changed native list geometry")
recipeList.width, frame.width = 304, 673
box:SetDataProvider(input)
assert(recipeList.width == 304 and frame.width == 673, "at the client's width the list keeps its width")

-- An added recipe has grey source text, no craftable count, and no native click.
local function Row()
	local row = {
		Count = Font(),
		Label = Font(),
		LockedIcon = {
			IsShown = function()
				return false
			end,
		},
		SkillUps = {
			GetWidth = function()
				return 26
			end,
		},
		mouse = true,
		motion = true,
		width = 276,
		texts = {},
	}
	function row:GetWidth()
		return self.width
	end
	function row:CreateFontString()
		local text = Font()
		self.texts[#self.texts + 1] = text
		return text
	end
	function row:EnableMouse(value)
		self.mouse, self.motion = value, value
	end
	function row:SetMouseMotionEnabled(value)
		self.motion = value
	end
	function row:GetText()
		return self.texts[#self.texts]
	end
	return row
end
local row = Row()
row.Label.width = 250 -- what the client's Init left the name: more than the row has once our text is in
decorate(ns, row, {
	GetData = function()
		return {
			recipeInfo = {
				recipeID = 20,
				name = "Ahead",
				learned = false,
				skillUpUnlearned = {
					recipeID = 20,
					name = "Ahead",
					kind = "trainer",
					skill = 60,
					thresholds = { 1, 25, 50, 75 },
				},
			},
		}
	end,
})
-- The Unlearned divider already says the row is not learned, so the row gives its width to the name (#854).
assert(row:GetText().text == "Trainer 60", "the row says only where and at what skill")
-- The name keeps the row less the skill-up column, the source text and the gap: 276 - 26 - 60 - 14. With the old
-- "Not learned · " prefix it was cut to 86.
assert(row.Label:GetWidth() == 176, "the recipe name gets the width the prefix took")
assert(row.Count.shown == false, "an unlearned row has no craftable count")
assert(row.mouse == false, "the native recipe row takes no click")
assert(previewRows[row] and previewRows[row].recipeInfo.recipeID == 20, "the preview gets the unlearned record")
assert(row.motion == true, "but still takes mouse motion, so it can show its tooltip")

-- Recycled for a learned recipe, the same row takes clicks again and shows the ordinary row text.
local learnedData = { recipeInfo = { recipeID = 10, name = "Learned", learned = true } }
decorate(ns, row, {
	GetData = function()
		return learnedData
	end,
})
assert(row.mouse == true, "a learned row takes clicks")
assert(previewRows[row] == learnedData, "the preview gets the record after a row is recycled")
assert(row.motion == true, "and keeps mouse motion")
assert(row:GetText().text == "50%", "and shows the skill-up text")

-- With the row text off, an unlearned row still says where it is learned.
ns.db.showRowText = false
decorate(ns, row, {
	GetData = function()
		return {
			recipeInfo = {
				recipeID = 30,
				name = "Recipe item",
				learned = false,
				skillUpUnlearned = {
					recipeID = 30,
					name = "Recipe item",
					kind = "scroll",
					skill = 80,
					thresholds = { 1, 25, 50, 75 },
				},
			},
		}
	end,
})
assert(row:GetText().shown and row:GetText().text == "Recipe item 80", "the source stays")
assert(previewRows[row] and previewRows[row].recipeInfo.recipeID == 30, "the preview gets the new unlearned record")

print("unlearned_list_spec: setting, categories, dedupe, width, marker, source and click: ok")
