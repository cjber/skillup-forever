-- A native provider replacement must sort through its callback without replacing native methods.
local function noop() end
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
	assert(replacements < 10, "sorting must not recurse through provider callbacks")
	callback(owner)
end
local original = box.SetDataProvider
local function tree()
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
local ns = {
	L = {},
	db = { sortMode = "skill", wideRecipeList = true },
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
print("recipelist_spec: provider replacement, sort, newest first, recursion and native method identity passed")
