-- Run from the repository root: luajit tests/route_spec.lua
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local available = 2
local queries = 0
local ns = {
	IsLearned = function()
		return true
	end,
}
local env = setmetatable({
	C_Spell = {
		GetSpellName = function()
			return "Test recipe"
		end,
	},
	C_TradeSkillUI = {
		GetCraftableCount = function(recipeID)
			equal(recipeID, 42, "queries the first route recipe")
			queries = queries + 1
			return available
		end,
	},
}, { __index = _G })
assert(loadfile("Locales/enUS.lua"))("SkillUpForever", ns)
setfenv(assert(loadfile("Route.lua")), env)("SkillUpForever", ns)
ns.OpenSkillLine = function()
	return 171
end

local profession = { skillLine = 171, name = "Alchemy", capped = false, max = 75, modifier = 0 }
local route = { segments = { { recipeID = 42, fromSkill = 10, toSkill = 15, crafts = 5 } }, ranks = {} }
local craft = ns.NextCraft(profession, route)
equal(craft.count, 2, "the client count limits the batch even when bags would allow more")
equal(craft.recipeID, 42, "an available batch can be crafted")
available = 12
craft = ns.NextCraft(profession, route)
equal(craft.count, 5, "never crafts beyond the planned segment")
available = 0
craft = ns.NextCraft(profession, route)
equal(craft.recipeID, nil, "zero available disables crafting")
equal(craft.reason, "Missing reagents for this step.", "zero available explains the disabled button")
equal(queries, 3, "rechecks the client count after changes")

-- A segment past the cap stops where skill-ups do, until the next rank is trained.
ns.Model = {
	Get = function()
		return { 1, 60, 80, 100 }
	end,
	Chance = function(_, skill)
		return skill < 72 and 1 or 0.5
	end,
}
available = 99
route = { segments = { { recipeID = 42, fromSkill = 70, toSkill = 95, crafts = 40 } }, ranks = {} }
equal(ns.NextCraft(profession, route).count, 8, "crafts only to the cap: 2 sure then 3 half-chance points")

-- Planning over the bundled First Aid data: Linen Bandage (3275), Heavy Linen Bandage (3276).
local planned = { db = { trainer = {}, routeTargets = {} }, InvalidateAPI = function() end }
local known, costs = {}, {}
planned.IsLearned = function(id)
	return known[id] == true
end
planned.NetCost = function(id)
	return costs[id]
end
local ranks = setmetatable({ APPRENTICE = "Apprentice", JOURNEYMAN = "Journeyman" }, { __index = _G })
for _, file in ipairs({
	"Locales/enUS.lua",
	"Data/Thresholds.lua",
	"Data/Recipes.lua",
	"Data/Trainer.lua",
	"Model.lua",
	"Route.lua",
}) do
	setfenv(assert(loadfile(file)), ranks)("SkillUpForever", planned)
end
local function FirstAid(skill)
	return { skillLine = 129, name = "First Aid", skill = skill, base = skill, max = 75, modifier = 0 }
end

known[3275], costs[3275] = true, 1
planned.db.routeTargets[129] = 100
local short = planned.PlanRoute(FirstAid(1))
equal(short.reachedSkill, 60, "Linen Bandage alone stops at 60")
equal(#short.ranks, 0, "a rank past where the route stops is not trained")
equal(short.trainingCost, 0, "nor charged for")

known[3276], costs[3276] = true, 1
planned.db.routeTargets[129] = 90
local first = FirstAid(40)
local steps = planned.RouteSteps(first, planned.PlanRoute(first))
equal(steps[1].segment and steps[1].segment.toSkill, 50, "crafts up to the skill Journeyman needs")
equal(steps[2].rank and steps[2].rank.reqSkill, 50, "then trains Journeyman")
equal(steps[3].segment and steps[3].segment.fromSkill, 50, "then crafts on past the cap")
equal(steps[3].segment.toSkill, 90, "to the target")

-- The route page, drawn into stub frames: every frame method is a no-op but the
-- scripts, which run, and the lists, which record their rows.
local function Stub()
	local scripts = {}
	return setmetatable({}, {
		__index = function(self, key)
			local value
			if key == "SetScript" or key == "HookScript" then
				value = function(_, name, fn)
					scripts[name] = fn
				end
			elseif key == "SetCustomOnMouseUpHandler" then
				value = function(_, fn)
					scripts.OnMouseUp = fn
				end
			elseif key == "Show" then
				value = function(frame)
					rawset(frame, "shown", true)
					if scripts.OnShow then
						scripts.OnShow(frame)
					end
				end
			elseif key == "IsShown" then
				value = function(frame)
					return rawget(frame, "shown") == true
				end
			elseif key == "Click" then
				value = function(frame)
					scripts.OnMouseUp(frame, "LeftButton", true)
				end
			else
				value = Stub()
			end
			rawset(self, key, value)
			return value
		end,
		__call = function()
			return Stub()
		end,
		__add = function()
			return 0
		end,
	})
end
local requested, lists = {}, {}
local page = {
	db = { trainer = {}, routeTargets = { [129] = 100 }, showRouteTab = true },
	COLORS = {},
	InvalidateAPI = function() end,
	IsLearned = function(id)
		return id == 3275
	end,
	NetCost = function() end,
	Reagents = function()
		return { { itemID = 2589, quantity = 1 } }
	end,
	Price = function() end,
	-- One scroll nothing prices, to carry the route on.
	RecipeSuggestions = function()
		return { { recipeID = 3276, source = { item = 6454 }, reach = 115, kindText = "vendor" } }
	end,
	ScrollPrice = function() end,
	RouteReagents = function()
		return {}
	end,
	PlayerProfessions = function()
		return { [129] = FirstAid(1) }
	end,
	HasAuctionator = function()
		return false
	end,
	IsTracked = function()
		return false
	end,
	CreateList = function()
		local list = { rows = {}, scrollBox = Stub() }
		function list:Add(row)
			self.rows[#self.rows + 1] = row
		end
		list.Message, list.Finish = function() end, function() end
		lists[#lists + 1] = list
		return list
	end,
}
local pageEnv = setmetatable({
	C_Item = {
		GetItemNameByID = function() end,
		GetItemIconByID = function() end,
		RequestLoadItemDataByID = function(id)
			requested[id] = true
		end,
	},
	Professions = false,
}, {
	__index = function(_, key)
		local value = _G[key]
		if value == nil then
			return Stub()
		end
		return value
	end,
})
for _, file in ipairs({
	"Locales/enUS.lua",
	"Data/Thresholds.lua",
	"Data/Recipes.lua",
	"Data/Trainer.lua",
	"Model.lua",
	"Route.lua",
}) do
	setfenv(assert(loadfile(file)), pageEnv)("SkillUpForever", page)
end
local tabs = {}
pageEnv.CreateFrame = function()
	local frame = Stub()
	tabs[#tabs + 1] = frame
	return frame
end
page.AttachRoute()
tabs[#tabs - 1]:Click() -- the side tab, created just before the event frame
local reagentList = lists[2]
equal(reagentList.rows[1] and reagentList.rows[1].text, "item 2589", "an unpriced reagent is listed")
equal(requested[2589], true, "and its name is asked for")

-- With only Linen Bandage priced, the route runs out and suggests a scroll nothing prices.
page.NetCost = function(recipeID)
	return recipeID == 3275 and 10 or nil
end
page.FormatNet = function(copper)
	return tostring(copper)
end
-- And one reagent from every shopping bucket, each labelled with where it comes from.
page.RouteReagents = function()
	local items = {}
	for index, source in ipairs(page.Model.SHOPPING_SOURCES) do
		items[index] = { itemID = index, need = 1, source = source }
	end
	return items
end
page.Have = function()
	return 0
end
page.InvalidatePlans()
tabs[#tabs - 1]:Click()
local routeList = lists[#lists - 1]
local suggestion = routeList.rows[#routeList.rows]
equal(suggestion and suggestion.values[1], "?", "an unpriced scroll shows ?")
local labels = {}
for _, row in ipairs(lists[#lists].rows) do
	labels[row.text] = row.values[2]
end
for index, source in ipairs(page.Model.SHOPPING_SOURCES) do
	equal(type(labels["item " .. index]), "string", source .. " is listed with a source label")
end

print("route_spec: " .. checks .. " checks passed")
