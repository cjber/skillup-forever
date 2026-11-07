-- Run from the repository root: luajit tests/wide_professions_spec.lua
-- The recipe list widens to its longest name and the window with it, once per list refresh, out of combat;
-- the count the bags can make follows the name in parentheses. The client's own widths come back when the
-- setting is off, and FitLabel still keeps the name clear of SkillUp's row text.
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
local frame = { CraftingPage = page, width = 673, professionInfo = { professionID = 1 } }
function frame:GetWidth()
	return self.width
end
function frame:SetWidth(width)
	self.width = width
end

local combat = false
local counts = {}
local events, stale, decorate = {}, {}, nil
local ns = {
	L = {},
	db = { sortMode = "blizzard", wideRecipeList = true, showRowText = false },
	Readable = function(value)
		return value
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
	SkillContext = noop,
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

-- A 40-character name needs 240 for itself and a count; the client's 304 list leaves 304 - 69 of chrome
-- and the count short, so the list and the window grow by exactly what is missing.
counts[1] = 1
box:SetDataProvider(Tree({ Leaf(string.rep("A", 40), 1) }))
local list, window = Widths()
assert(list == 339 and window == 708, string.format("widened to %s/%s", list, window))

-- With SkillUp's own row text on, the list also makes room for it and FitLabel's gap: the same name, count,
-- 59 of list chrome, then "50% · -3" (54) and the 14 FitLabel keeps clear of it. Without that room the name
-- would truncate against our text.
ns.db.showRowText = true
counts[4] = 1
box:SetDataProvider(Tree({ Leaf(string.rep("E", 40), 4) }))
list, window = Widths()
assert(list == 397 and window == 766, string.format("widened to %s/%s with row text", list, window))
ns.db.showRowText = false

-- The setting off puts back the client's own widths, which the list refresh did not change.
ns.db.wideRecipeList = false
stale.recipeList()
list, window = Widths()
assert(list == 304 and window == 673, string.format("restored to %s/%s", list, window))

-- A fight defers the resize until combat ends; the list refresh still measures, it just does not resize.
ns.db.wideRecipeList = true
combat = true
counts[1] = 1
box:SetDataProvider(Tree({ Leaf(string.rep("B", 40), 1) }))
list, window = Widths()
assert(list == 304 and window == 673, "no resize in combat")
combat = false
events.PLAYER_REGEN_ENABLED()
list, window = Widths()
assert(list == 339 and window == 708, "resized when combat ends")

-- The cap keeps the window on screen: here the screen leaves 12 more than the client's 673.
env.UIParent.GetWidth = function()
	return 673 + 2 * 32 + 12
end
recipeList.width, frame.width = 304, 673
box:SetDataProvider(Tree({ Leaf(string.rep("C", 200), 1) }))
list, window = Widths()
assert(list == 316 and window == 685, string.format("capped to %s/%s", list, window))

-- The count follows the name in parentheses whether or not SkillUp's own row text is on.
local count = Font()
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
		return Font()
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
		return { recipeInfo = { recipeID = 3, name = string.rep("D", 60) } }
	end,
})
assert(row.Label.width < 260, "FitLabel keeps the name clear of the row text")
assert(row.SkillUpText:IsShown(), "the row text is drawn")
print("wide_professions_spec: measurement, widening, cap, combat deferral, restore, count and FitLabel: ok")
