-- Run from the repository root: luajit tests/window_width_spec.lua
-- SkillUp's deferred wide-list feature must not resize either the shared host or Blizzard's recipe list.
local function noop() end

local function Font()
	local font = { text = "", width = 0 }
	function font:SetText(text)
		self.text = text
	end
	function font:SetFormattedText(format, value)
		self.text = string.format(format, value)
	end
	function font:GetStringWidth()
		return #self.text * 6
	end
	function font.Hide(_) end
	return font
end

-- The client's recipe list and its scroll box, as the file touches them.
local box = {}
function box.RegisterCallback(_) end
function box.GetDataProvider(_)
	return nil
end
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
function recipeList.CreateFontString(_)
	return Font()
end

local frame = { CraftingPage = { RecipeList = recipeList }, width = 673, professionInfo = { professionID = 100 } }
function frame:GetWidth()
	return self.width
end
function frame:SetWidth(width)
	self.width = width
end

-- Legacy recipe data remains present to prove that old saved settings and data cannot trigger host resizing.
local names = {
	[1] = string.rep("A", 60),
	[2] = string.rep("B", 20),
	[3] = string.rep("C", 100),
	[4] = string.rep("D", 200),
}
local learned = { [1] = true, [2] = true, [3] = true, [4] = true }
local recipes = {
	[1] = { skillLine = 100 },
	[2] = { skillLine = 200 },
	[3] = { skillLine = 300 },
	[4] = { skillLine = 400 },
}
local professions = {
	[100] = { skillLine = 100, skill = 50, base = 50, modifier = 0, max = 75, name = "One", capped = false },
	[200] = { skillLine = 200, skill = 50, base = 50, modifier = 0, max = 75, name = "Two", capped = false },
}
local applied
local stale, events = {}, {}

local ns = {
	L = {},
	db = { wideRecipeList = true, showRowText = false, showUnlearned = false, sortMode = "blizzard" },
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
	PlayerProfessions = function()
		return professions
	end,
	RecipeData = recipes,
	RecipeNames = {},
	IsLearned = function(recipeID)
		return learned[recipeID] == true
	end,
	UnlearnedRecipes = function()
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
	SkillContext = function()
		return professions[100]
	end,
	ShowRecipeTooltip = noop,
	AttachRoute = noop,
	AttachGear = noop,
	AttachAuctionSearch = noop,
	AttachDetailsBar = noop,
	Print = function(message)
		error(message)
	end,
	SetSortMode = function()
		error("unexpected sort failure")
	end,
}
ns.Pages = {
	SetMinWidth = function(width)
		applied = width
		return true
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
		GetCraftableCount = function()
			return 0
		end,
	},
	C_Spell = {
		GetSpellName = function(recipeID)
			return names[recipeID]
		end,
	},
	InCombatLockdown = function()
		return false
	end,
	ScrollUtil = { AddInitializedFrameCallback = noop },
	EventRegistry = { RegisterCallback = noop },
	Menu = { ModifyMenu = noop },
	hooksecurefunc = function()
		error("native recipe methods must stay unhooked")
	end,
}, { __index = _G })

setfenv(assert(loadfile("UI/RecipeList.lua")), env)("SkillUpForever", ns)
ns.AttachRecipeList()

local function fitted(label)
	assert(applied == nil, label .. ": SkillUp must not resize the shared Professions host")
	assert(frame:GetWidth() == 673, label .. ": the spec's own window moved")
	assert(recipeList.width == 304, label .. ": expected the client list width, got " .. tostring(recipeList.width))
end

assert(ns.RecipeListMinWidth == nil and ns.FitRecipeListWidth == nil, "SkillUp still exposes automatic width hooks")
fitted("after attach")

-- Opening another learned profession does not move the window, even though its own names are shorter.
frame.professionInfo = { professionID = 200 }
stale.recipeList()
fitted("after another profession")

ns.db.wideRecipeList = false
stale.recipeList()
fitted("with the legacy setting off")

-- An old saved setting cannot re-enable the deferred feature.
ns.db.wideRecipeList = true
stale.recipeList()
fitted("with the legacy setting on again")

-- Learning a profession measures the new set: a 100-character name needs 10 + 600 + 59 + 10 = 679, so the
-- window is 673 + (679 - 304) = 1048.
professions[300] = { skillLine = 300, skill = 50, base = 50, modifier = 0, max = 75, name = "Three", capped = false }
if events.SKILL_LINES_CHANGED then
	events.SKILL_LINES_CHANGED()
end
fitted("after learning a profession")

-- It stays one width whichever learned profession is open.
frame.professionInfo = { professionID = 300 }
stale.recipeList()
fitted("with the widest profession open")

-- A skill-up inside a profession changes no learned set: the same width, no remeasurement.
names[1] = string.rep("E", 10)
if events.SKILL_LINES_CHANGED then
	events.SKILL_LINES_CHANGED()
end
fitted("after a skill-up")
names[1] = string.rep("A", 60)

professions[400] = { skillLine = 400, skill = 50, base = 50, modifier = 0, max = 75, name = "Four", capped = false }
if events.SKILL_LINES_CHANGED then
	events.SKILL_LINES_CHANGED()
end
fitted("after another learned profession")

names[1], names[3], names[4] = "Short", "Short", "Short"
professions[300], professions[400] = nil, nil
ns.db.wideRecipeList = false
stale.recipeList()
ns.db.wideRecipeList = true
stale.recipeList()
fitted("after legacy data shrinks")

print("window_width_spec: host and native list geometry stay unchanged: ok")
