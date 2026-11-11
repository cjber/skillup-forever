-- Run from the repository root: luajit tests/window_width_spec.lua
-- The wide recipe list keeps one window width, measured over every profession this character has learned.
-- The width is the client's crafting page plus the room the widest row needs beyond the client's own list
-- width; it does not depend on the open profession or the list on screen, and a screen cap keeps the window
-- clear of the screen's edges. Turning the setting off clears it.
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

-- The client's own names for the recipes; the bundle only holds their skill lines.
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
local screenWidth = 1920
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
	UIParent = {
		GetWidth = function()
			return screenWidth
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

-- The client's own list width is 304 and its window 673. The window's width is 673 plus the room the widest
-- learned profession's rows need beyond 304. A 60-character name at one category indent needs
-- 10 + 60 * 6 + 59 + 10 = 439, so the window takes 673 + 135.
local function fitted(label, expectedWidth, expectedList)
	assert(
		applied == expectedWidth,
		label .. ": expected the window at " .. tostring(expectedWidth) .. ", got " .. tostring(applied)
	)
	assert(frame:GetWidth() == 673, label .. ": the spec's own window moved")
	assert(
		recipeList.width == expectedList,
		label .. ": expected the list at " .. tostring(expectedList) .. ", got " .. tostring(recipeList.width)
	)
end

assert(ns.RecipeListMinWidth() == 808, "the widest learned profession sets the window width")
fitted("after measuring", 808, 304)

-- The list fills the room the one width leaves: 808 - 5 - 2 - 360 - 2 = 439. Its widest row needs 439.
ns.FitRecipeListWidth()
fitted("with the list filled", 808, 439)

-- Opening another learned profession does not move the window, even though its own names are shorter.
frame.professionInfo = { professionID = 200 }
stale.recipeList()
fitted("after another profession", 808, 439)

-- The setting off clears the width, so the client's own list and window widths return.
ns.db.wideRecipeList = false
stale.recipeList()
fitted("with the wide list off", nil, 304)

-- And on again raises the same width, from the client's own list width.
ns.db.wideRecipeList = true
stale.recipeList()
fitted("with the wide list on again", 808, 439)

-- Learning a profession measures the new set: a 100-character name needs 10 + 600 + 59 + 10 = 679, so the
-- window is 673 + (679 - 304) = 1048.
professions[300] = { skillLine = 300, skill = 50, base = 50, modifier = 0, max = 75, name = "Three", capped = false }
events.SKILL_LINES_CHANGED()
fitted("after learning a profession", 1048, 679)

-- It stays one width whichever learned profession is open.
frame.professionInfo = { professionID = 300 }
stale.recipeList()
fitted("with the widest profession open", 1048, 679)

-- A skill-up inside a profession changes no learned set: the same width, no remeasurement.
names[1] = string.rep("E", 10)
events.SKILL_LINES_CHANGED()
fitted("after a skill-up", 1048, 679)
names[1] = string.rep("A", 60)

-- The screen cap: with a 1024-wide screen and 32 clear at each edge the window stops at 960, so the list takes
-- 960 - 369 = 591 even though the 200-character row needs far more. The name truncates; it never overlaps.
screenWidth = 1024
professions[400] = { skillLine = 400, skill = 50, base = 50, modifier = 0, max = 75, name = "Four", capped = false }
events.SKILL_LINES_CHANGED()
fitted("at the screen cap", 960, 591)

-- With every learned row already inside the client's own list width, the wide list asks for the client's
-- crafting width, not for nothing: only the setting off clears it.
names[1], names[3], names[4] = "Short", "Short", "Short"
professions[300], professions[400] = nil, nil
ns.db.wideRecipeList = false
stale.recipeList()
ns.db.wideRecipeList = true
stale.recipeList()
fitted("with every row inside the client list", 673, 304)

print("window_width_spec: one width, widest profession, setting, learned profession, switch, screen cap: ok")
