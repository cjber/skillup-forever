-- Run from the repository root: luajit tests/wide_professions_spec.lua
-- The recipe list fills the room the window has, never moving the window itself: the one window width is
-- measured over the learned professions in window_width_spec.lua. A filtered or collapsed list, a craftable
-- count or a price does not resize it. The count the bags can make follows the name in parentheses, the
-- client's own list width comes back when the setting is off, and FitLabel keeps the name clear of SkillUp's
-- row text.
local function noop() end

local function Font()
	local font = { text = "", width = 0, shown = true, points = {} }
	function font:SetText(text)
		self.text = text
	end
	function font:SetFormattedText(format, value)
		self.text = string.format(format, value)
	end
	function font:GetStringWidth()
		return #self.text * 6
	end
	function font:GetText()
		return self.text
	end
	function font:GetWidth()
		return self.width
	end
	function font:SetWidth(width)
		self.width = width
	end
	function font:SetPoint(...)
		self.points[#self.points + 1] = { ... }
	end
	function font:ClearAllPoints()
		self.points = {}
	end
	function font.SetTextColor() end
	function font.SetJustifyH() end
	function font:Show()
		self.shown = true
	end
	function font:Hide()
		self.shown = false
	end
	function font:IsShown()
		return self.shown
	end
	return font
end

local function Leaf(name, recipeID)
	return {
		GetData = function()
			return { recipeInfo = { recipeID = recipeID, name = name, learned = true } }
		end,
		GetNodes = function()
			return {}
		end,
	}
end

local function Tree(nodes)
	return {
		GetRootNode = function()
			return {
				GetNodes = function()
					return nodes
				end,
			}
		end,
	}
end

local function Box()
	local box = { callbacks = {} }
	function box:RegisterCallback(event, callback, owner)
		self.callbacks[event] = { callback = callback, owner = owner }
	end
	function box:GetDataProvider()
		return self.provider
	end
	function box:SetDataProvider(provider)
		self.provider = provider
		local entry = self.callbacks.OnDataProviderReassigned
		entry.callback(entry.owner, self)
	end
	return box
end

local box = Box()
local recipeList = { ScrollBox = box, width = 304, visible = true }
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
function page.Init() end
local frame = { CraftingPage = page, width = 673, professionInfo = { professionID = 1 }, widthCalls = 0 }
function frame:GetWidth()
	return self.width
end
function frame:SetWidth(width)
	self.widthCalls = self.widthCalls + 1
	self.width = width
end

local combat = false
local counts = {}
-- The profession's full recipe set, as the client reports it, for the scene's own client data.
local recipes = {}
local events, stale, decorate = {}, {}, nil
local ns = {
	L = {},
	db = { sortMode = "blizzard", wideRecipeList = true, showRowText = false },
	Readable = function(value)
		return value
	end,
	GamepadUI = function()
		return false
	end,
	WhenEvent = function(event, callback)
		events[event] = callback
	end,
	WhenStale = function(name, callback)
		stale[name] = callback
	end,
	AttachRoute = noop,
	AttachGear = noop,
	AttachAuctionSearch = noop,
	AttachDetailsBar = noop,
	ShowRecipeTooltip = noop,
	Print = function(message)
		error(message)
	end,
	SetSortMode = function()
		error("unexpected sort failure")
	end,
	SkillContext = function()
		return {}
	end,
	Describe = function()
		return { thresholds = { 1, 2, 3, 4 }, chance = 0.5, perSkillUp = 3 }
	end,
	FormatRow = function()
		return "50% · -3"
	end,
	RowColor = function()
		return { GetRGB = noop }
	end,
}
local env = setmetatable({
	ProfessionsFrame = frame,
	Professions = {
		GetHighestLearnedRecipe = function(info)
			return info
		end,
	},
	C_TradeSkillUI = {
		GetCraftableCount = function(recipeID)
			return counts[recipeID] or 0
		end,
		GetAllRecipeIDs = function()
			local ids = {}
			for recipeID in pairs(recipes) do
				ids[#ids + 1] = recipeID
			end
			table.sort(ids)
			return ids
		end,
		GetRecipeInfo = function(recipeID)
			return recipes[recipeID]
		end,
	},
	UIParent = {
		GetWidth = function()
			return 1024
		end,
	},
	InCombatLockdown = function()
		return combat
	end,
	ScrollUtil = {
		AddInitializedFrameCallback = function(_, callback)
			decorate = callback
		end,
	},
	EventRegistry = { RegisterCallback = noop },
	Menu = { ModifyMenu = noop },
	hooksecurefunc = function()
		error("native recipe methods must stay unhooked")
	end,
}, { __index = _G })

setfenv(assert(loadfile("UI/RecipeList.lua")), env)("SkillUpForever", ns)
ns.AttachRecipeList()

local function Widths()
	return recipeList:GetWidth(), frame:GetWidth()
end

---@param recipeID integer
---@param name string
---@return table
local function Recipe(recipeID, name)
	return { recipeID = recipeID, name = name, learned = true }
end

-- The client's 673-wide window leaves the list its own 304 beside the 360-wide schematic, so a name longer than
-- that is laid out in the width the list has and the window keeps its width. A 40-character name needs 339.
recipes = { [1] = Recipe(1, string.rep("A", 40)) }
counts[1] = 1
box:SetDataProvider(Tree({ Leaf(string.rep("A", 40), 1) }))
local list, window = Widths()
assert(list == 304 and window == 673, string.format("kept to %s/%s", list, window))

-- A filtered list holding only a short name does not move the list: it already has all the room the window
-- leaves. Neither does a craftable count that grew while the window is open.
recipes[2] = Recipe(2, "Short")
box:SetDataProvider(Tree({ Leaf("Short", 2) }))
list, window = Widths()
assert(list == 304 and window == 673, string.format("a filtered refresh kept %s/%s", list, window))
counts[1] = 12
box:SetDataProvider(Tree({ Leaf(string.rep("A", 40), 1) }))
list, window = Widths()
assert(list == 304 and window == 673, string.format("a crafting refresh kept %s/%s", list, window))

-- Another profession still has no more room at the client's width.
frame.professionInfo = { professionID = 2 }
recipes = { [3] = Recipe(3, string.rep("B", 40)) }
counts[3] = 0
box:SetDataProvider(Tree({ Leaf("Short", 2) }))
list, window = Widths()
assert(list == 304 and window == 673, string.format("another profession kept %s/%s", list, window))

-- SkillUp's own row text on is still laid out inside the list's width.
ns.db.showRowText = true
stale.recipeList()
list, window = Widths()
assert(list == 304 and window == 673, string.format("row text on kept %s/%s", list, window))
ns.db.showRowText = false
stale.recipeList()
list, window = Widths()
assert(list == 304 and window == 673, string.format("row text off kept %s/%s", list, window))

-- The setting puts back the client's own list width, which the list refresh did not change.
ns.db.wideRecipeList = false
stale.recipeList()
list, window = Widths()
assert(list == 304 and window == 673, string.format("restored to %s/%s", list, window))

-- A fight defers the change until combat ends; the list does not resize meanwhile.
ns.db.wideRecipeList = true
frame.professionInfo = { professionID = 3 }
recipes = { [5] = Recipe(5, string.rep("D", 40)) }
counts[5] = 1
recipeList.width, frame.width = 304, 673
combat = true
box:SetDataProvider(Tree({ Leaf(string.rep("D", 40), 5) }))
list, window = Widths()
assert(list == 304 and window == 673, "no resize in combat")
combat = false
if events.PLAYER_REGEN_ENABLED then
	events.PLAYER_REGEN_ENABLED()
end
list, window = Widths()
assert(list == 304 and window == 673, "kept when combat ends")

-- The list takes the room a window wider than the client's has, and still never moves the window itself.
frame.professionInfo = { professionID = 4 }
recipes = { [6] = Recipe(6, string.rep("E", 200)) }
counts[6] = 0
recipeList.width, frame.width = 304, 900
box:SetDataProvider(Tree({ Leaf(string.rep("E", 200), 6) }))
list, window = Widths()
assert(list == 304 and window == 900, string.format("a wider window changed native list geometry %s/%s", list, window))
assert(frame.widthCalls == 0, "the addon never sets the window's width")

-- The count follows the name in parentheses whether or not SkillUp's own row text is on.
local count = Font()
local rowTexts = {}
local row = {
	Count = count,
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
	GetWidth = function()
		return 276
	end,
	CreateFontString = function()
		local text = Font()
		rowTexts[#rowTexts + 1] = text
		return text
	end,
}
counts[2] = 3
decorate(ns, row, {
	GetData = function()
		return { recipeInfo = { recipeID = 2, name = "Camp Tent" } }
	end,
})
assert(count:GetText() == " (3) " and count:IsShown(), "the craftable count is in parentheses")
counts[2] = 0
decorate(ns, row, {
	GetData = function()
		return { recipeInfo = { recipeID = 2, name = "Camp Tent" } }
	end,
})
assert(not count:IsShown(), "nothing craftable shows no count")

-- With the row text on, FitLabel still shrinks the name so the two never overlap.
ns.db.showRowText = true
row.Label = Font()
row.Label.width = 260
counts[3] = 12
decorate(ns, row, {
	GetData = function()
		return { recipeInfo = { recipeID = 3, name = string.rep("F", 60) } }
	end,
})
assert(row.Label.width < 260, "FitLabel keeps the name clear of the row text")
assert(rowTexts[#rowTexts]:IsShown(), "the row text is drawn")
assert(row.SkillUpText == nil, "the row text lives off the client's row, not on it (#350)")
print("wide_professions_spec: room, stability, another profession, settings, combat, count and FitLabel: ok")
