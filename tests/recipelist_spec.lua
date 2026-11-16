-- A native provider replacement must sort through its callback without replacing native methods.
local function noop() end
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
	assert(replacements < 10, "sorting must not recurse through provider callbacks")
	callback(owner)
end
local original = box.SetDataProvider
local function tree(data)
	local nodes = {}
	local branch = {}
	function branch.Insert(_, value)
		local child = tree(value)
		nodes[#nodes + 1] = child
		return child
	end
	function branch.GetData()
		return data
	end
	function branch.GetNodes()
		return nodes
	end
	function branch:GetRootNode()
		return self
	end
	return branch
end
local ns = {
	L = {},
	db = { sortMode = "skill", unlearnedSortMode = "skill", wideRecipeList = true },
	Model = {
		Get = function(id)
			return { id }
		end,
	},
	SkillContext = noop,
	AttachRoute = noop,
	AttachGear = noop,
	AttachAuctionSearch = noop,
	AttachDetailsBar = noop,
	AttachRecipePreview = function()
		return noop
	end,
	WhenStale = noop,
	WhenEvent = noop,
	GamepadUI = function()
		return false
	end,
	Readable = function(value)
		return value
	end,
	ShowRecipeTooltip = noop,
	Print = function(msg)
		error(msg)
	end,
	SetSortMode = function()
		error("unexpected sort failure")
	end,
}
-- The range start the list sorts by: the recipe's learn skill, as Core/Plan.lua's RangeThresholds gives it
-- (#519). A recipe with no known source keeps the data's first threshold.
local learnedAt = {}
ns.RangeThresholds = function(_, id)
	local t = ns.Model.Get(id)
	local learnAt = learnedAt[id] or 0
	if not t or learnAt <= t[1] then
		return t
	end
	return { learnAt, t[2], t[3], t[4] }
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
function recipeList.CreateFontString()
	return {
		SetText = noop,
		SetFormattedText = noop,
		Hide = noop,
		GetStringWidth = function()
			return 100
		end,
	}
end
local frame = { CraftingPage = { RecipeList = recipeList }, width = 673 }
function frame:GetWidth()
	return self.width
end
function frame:SetWidth(width)
	self.width = width
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
			return 0
		end,
		GetRecipeItemNameFilter = function()
			return searchText
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
	ScrollUtil = { AddInitializedFrameCallback = noop },
	EventRegistry = { RegisterCallback = noop },
	Menu = { ModifyMenu = noop },
	ScrollBoxConstants = { RetainScrollPosition = true },
	CreateTreeDataProvider = tree,
	strlower = string.lower,
	strfind = string.find,
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
setfenv(assert(loadfile("UI/RecipeList.lua")), env)("SkillUpForever", ns)
ns.AttachRecipeList()
local input = tree()
input:Insert({ recipeInfo = { recipeID = 30, learned = true } })
input:Insert({ recipeInfo = { recipeID = 10, learned = true } })
box:SetDataProvider(input)
assert(replacements == 2, "one native update and one sorted replacement")
assert(provider:GetRootNode():GetNodes()[1]:GetData().recipeInfo.recipeID == 10)
assert(box.SetDataProvider == original, "native method remains untouched")
ns.db.sortMode = "blizzard"
box:SetDataProvider(input)
assert(provider == input, "default sort leaves the native provider alone")

-- Newest recipes first: the skill range start descending, learned recipes only, with the unlearned ones
-- still under Blizzard's divider.
local skills = { [10] = 50, [20] = 75, [30] = 25, [40] = 100 }
ns.Model.Get = function(id)
	local skill = skills[id] or 0
	return { skill, skill + 70, skill + 85, skill + 100 }
end
ns.SkillContext = function()
	return {}
end
ns.UnlearnedRecipes = function()
	return {}
end
ns.db.showUnlearned = true
ns.db.unlearnedSortMode = "skill"
local newest = tree()
newest:Insert({ recipeInfo = { recipeID = 10, name = "Ten", learned = true } })
newest:Insert({ recipeInfo = { recipeID = 20, name = "Twenty", learned = true } })
newest:Insert({ recipeInfo = { recipeID = 30, name = "Thirty", learned = true } })
newest:Insert({ recipeInfo = { recipeID = 40, name = "Forty", learned = false } })
ns.db.sortMode = "newest"
box:SetDataProvider(newest)
local nodes = provider:GetRootNode():GetNodes()
assert(nodes[1]:GetData().recipeInfo.recipeID == 20, "the highest skill range start comes first")
assert(nodes[2]:GetData().recipeInfo.recipeID == 10, "then the next highest")
assert(nodes[3]:GetData().recipeInfo.recipeID == 30, "then the lowest")
assert(nodes[4]:GetData().isDivider, "unlearned recipes stay below the divider")
assert(nodes[5]:GetData().recipeInfo.recipeID == 40, "the unlearned recipe follows the divider")

-- #519: the start is where the recipe is learned, so one the client starts at 1 but a trainer teaches at 60
-- comes before one that starts at 40.
ns.Model.Get = function(id)
	local skill = skills[id] or 0
	return { skill, skill + 100, skill + 120, skill + 150 }
end
skills[50], skills[60] = 1, 40
learnedAt[50], learnedAt[60] = 60, 40
local late = tree()
late:Insert({ recipeInfo = { recipeID = 60, name = "Sixty", learned = true } })
late:Insert({ recipeInfo = { recipeID = 50, name = "Fifty", learned = true } })
box:SetDataProvider(late)
nodes = provider:GetRootNode():GetNodes()
assert(nodes[1]:GetData().recipeInfo.recipeID == 50, "the recipe learned at 60 comes before the one learned at 40")
assert(nodes[2]:GetData().recipeInfo.recipeID == 60, "even though the client starts it at 1")

-- The client's search filters the bundled unlearned recipes in a sorted list too: only a matching added
-- recipe follows the divider, no match leaves the client's rows, and clearing it brings both back.
ns.UnlearnedRecipes = function()
	return {
		{ recipeID = 70, name = "Potion of Speed", kind = "trainer", skill = 90, thresholds = { 1, 25, 50, 75 } },
		{ recipeID = 80, name = "Elixir of Might", kind = "trainer", skill = 95, thresholds = { 1, 25, 50, 75 } },
	}
end
local searched = tree()
searched:Insert({ recipeInfo = { recipeID = 10, name = "Ten", learned = true } })
searchText = "POTION"
replacements = 0
box:SetDataProvider(searched)
nodes = provider:GetRootNode():GetNodes()
assert(#nodes == 3, "one learned recipe, a divider and one matching unlearned recipe")
assert(nodes[3]:GetData().recipeInfo.recipeID == 70, "the added recipe whose name matches stays")
searchText = "missing"
replacements = 0
box:SetDataProvider(searched)
nodes = provider:GetRootNode():GetNodes()
assert(#nodes == 1 and nodes[1]:GetData().recipeInfo.recipeID == 10, "no match leaves only the client's rows")
searchText = ""
replacements = 0
box:SetDataProvider(searched)
nodes = provider:GetRootNode():GetNodes()
assert(#nodes == 4, "clearing the search brings both added recipes back")
searchText = nil
-- Learned and unlearned recipes can use opposing skill orders.
ns.db.sortMode, ns.db.unlearnedSortMode = "skill", "newest"
ns.Model.Get = function(id)
	return { id == 10 and 90 or id == 20 and 20 or id == 70 and 90 or id == 80 and 20 or 0, 100, 100, 100 }
end
local split = tree()
split:Insert({ recipeInfo = { recipeID = 10, name = "Learned expensive", learned = true } })
split:Insert({ recipeInfo = { recipeID = 20, name = "Learned cheap", learned = true } })
replacements = 0
box:SetDataProvider(split)
nodes = provider:GetRootNode():GetNodes()
assert(nodes[1]:GetData().recipeInfo.recipeID == 20, "learned recipes retain their selected sort")
assert(nodes[4]:GetData().recipeInfo.recipeID == 70, "unlearned recipes use their independent sort key")
print("recipelist_spec: provider replacement, sort, newest first, recursion and native method identity passed")

-- Blizzard mode retains learned categories while sorting native unlearned rows,
-- even when the bundle has no missing recipes to add.
ns.db.sortMode, ns.db.unlearnedSortMode = "blizzard", "skill"
ns.db.showUnlearned = false -- this controls bundle additions, not the native rows already present
ns.UnlearnedRecipes = function()
	return {}
end
local categorized = tree()
local category = categorized:Insert({ categoryInfo = { name = "Native category" } })
category:Insert({ recipeInfo = { recipeID = 10, name = "Learned first", learned = true } })
category:Insert({ recipeInfo = { recipeID = 20, name = "Learned second", learned = true } })
category:Insert({ isDivider = true, dividerHeight = 70 })
category:Insert({ recipeInfo = { recipeID = 70, name = "Unlearned high", learned = false } })
category:Insert({ recipeInfo = { recipeID = 80, name = "Unlearned low", learned = false } })
replacements = 0
box:SetDataProvider(categorized)
nodes = provider:GetRootNode():GetNodes()
assert(nodes[1]:GetData().categoryInfo.name == "Native category", "native learned category stays")
assert(nodes[1]:GetNodes()[1]:GetData().recipeInfo.recipeID == 10, "native learned ordering stays")
assert(#nodes[1]:GetNodes() == 2, "unlearned rows leave the learned category")
assert(nodes[3]:GetData().recipeInfo.recipeID == 80, "native unlearned rows use ascending independent skill")
ns.db.unlearnedSortMode = "newest"
replacements = 0
box:SetDataProvider(categorized)
nodes = provider:GetRootNode():GetNodes()
assert(nodes[3]:GetData().recipeInfo.recipeID == 70, "changing unlearned order sorts native rows again")
print("independent unlearned ordering: native categories and bundled recipes passed")
