-- Run from the repository root: luajit tests/recipe_list_taint_spec.lua
-- A settings, price or profession change redraws the recipe rows and re-sorts them in place. It must not
-- rebuild the crafting page through Blizzard's Init, and the decoration must not write a field on the
-- client's recipe row: both ran from addon code on a row's click path and tainted the recipe selection the
-- craft and item-use paths read (#350).
local function noop() end

local function Font()
	local font = { text = "", width = 0, shown = true }
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
	function font.SetPoint() end
	function font.ClearAllPoints() end
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

-- The client's tree provider, as CreateTreeDataProvider makes one.
local function Provider()
	local nodes = {}
	return {
		Insert = function(_, data)
			nodes[#nodes + 1] = {
				GetData = function()
					return data
				end,
				GetNodes = function()
					return {}
				end,
			}
		end,
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
	local box = { callbacks = {}, frames = {} }
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
	function box:ForEachFrame(callback)
		for _, pair in ipairs(self.frames) do
			callback(pair[1], pair[2])
		end
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

local inits = 0
local page = { RecipeList = recipeList }
function page.Init()
	inits = inits + 1
end
local frame = { CraftingPage = page, width = 673, professionInfo = { professionID = 1 } }
function frame:GetWidth()
	return self.width
end
function frame:SetWidth(width)
	self.width = width
end

local stale, decorate = {}, nil
local craftable = 0
local ns = {
	L = {},
	db = { sortMode = "blizzard", wideRecipeList = false, showRowText = false },
	Model = {
		Get = function()
			return { 1 }
		end,
	},
	Readable = function(value)
		return value
	end,
	WhenEvent = noop,
	GamepadUI = function()
		return false
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
		error("sorting must not fail here")
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
-- The sort's range start: this harness holds no learn source, so the bundle's first threshold is the start (#519).
function ns.RangeThresholds(_, recipeID)
	return ns.Model.Get(recipeID)
end
local env = setmetatable({
	ProfessionsFrame = frame,
	Professions = {
		GetHighestLearnedRecipe = function(info)
			return info
		end,
	},
	C_TradeSkillUI = {
		GetCraftableCount = function()
			return craftable
		end,
	},
	UIParent = {
		GetWidth = function()
			return 1024
		end,
	},
	InCombatLockdown = function()
		return false
	end,
	ScrollUtil = {
		AddInitializedFrameCallback = function(_, callback)
			decorate = callback
		end,
	},
	EventRegistry = { RegisterCallback = noop },
	Menu = { ModifyMenu = noop },
	ScrollBoxConstants = { RetainScrollPosition = true },
	CreateTreeDataProvider = Provider,
	hooksecurefunc = function()
		error("native recipe methods must stay unhooked")
	end,
}, { __index = _G })

setfenv(assert(loadfile("UI/RecipeList.lua")), env)("SkillUpForever", ns)
ns.AttachRecipeList()

-- Decorating a row draws our text from a weak table, never a field on the client's row: a written field
-- is the taint the row's own click path carried (#350).
local created = {}
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
	GetWidth = function()
		return 276
	end,
	CreateFontString = function()
		local text = Font()
		created[#created + 1] = text
		return text
	end,
}
ns.db.showRowText = true
decorate(ns, row, {
	GetData = function()
		return { recipeInfo = { recipeID = 1, name = "Camp Tent" } }
	end,
})
assert(row.SkillUpText == nil, "SkillUp writes no field on the client's recipe row")
assert(created[#created]:IsShown(), "the row text is drawn")

-- A sort replaces the client's provider; Default puts the client's own back in place, with no Init.
box.frames = {
	{
		row,
		{
			GetData = function()
				return { recipeInfo = { recipeID = 1, name = "Camp Tent" } }
			end,
		},
	},
}
local clientData = { recipeInfo = { recipeID = 1, name = "Camp Tent", learned = true } }
local native = Tree({
	{
		GetData = function()
			return clientData
		end,
		GetNodes = function()
			return {}
		end,
	},
})
ns.db.sortMode = "skill"
box:SetDataProvider(native)
assert(box:GetDataProvider() ~= native, "a chosen sort replaces the client's provider")
local sortedNodes = box:GetDataProvider():GetRootNode():GetNodes()
assert(sortedNodes[1]:GetData() == clientData, "the sort keeps the client's own node data in the list")
ns.db.sortMode = "blizzard"
stale.recipeList()
assert(inits == 0, "a settings change never rebuilds Blizzard's crafting page")
assert(box:GetDataProvider() == native, "Default restores the client's own provider")

-- A row setting change redraws the rows on screen without rebuilding the page either.
ns.db.showRowText = false
craftable = 3
stale.recipeList()
assert(inits == 0, "a row setting change never rebuilds Blizzard's crafting page")
assert(row.Count:IsShown() and row.Count:GetText() == " (3) ", "the rows redraw from what they hold")

print("recipe_list_taint_spec: 8 checks passed")
