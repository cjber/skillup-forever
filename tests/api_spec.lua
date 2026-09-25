-- Run from the repository root: luajit tests/api_spec.lua
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local THREAD, LEATHER, SILK = 2321, 2319, 4306
local GLOVES, HILLMANS, LEATHER_RECIPE, SHIRT, BRACERS = 1, 2, 9, 3, 4

local handler
local opened = {}
local names = {
	[GLOVES] = "Toughened Leather Gloves",
	[HILLMANS] = "Hillman's Leather Gloves",
	[BRACERS] = "Copper Bracers",
}
local items = { [THREAD] = "Fine Thread", [LEATHER] = "Medium Leather" }
local env = setmetatable({
	CreateFrame = function()
		return {
			RegisterEvent = function() end,
			SetScript = function(_, _, fn)
				handler = fn
			end,
		}
	end,
	C_Spell = {
		GetSpellName = function(id)
			return names[id]
		end,
	},
	C_Item = {
		GetItemNameByID = function(id)
			return items[id]
		end,
		RequestLoadItemDataByID = function() end,
	},
	C_TradeSkillUI = {
		OpenTradeSkill = function(id)
			opened[#opened + 1] = id
			return true
		end,
	},
	UnitLevel = function()
		return 20
	end,
	-- The client's GlobalStrings the rank names come from.
	APPRENTICE = "Apprentice",
	JOURNEYMAN = "Journeyman",
	EXPERT = "Expert",
	ARTISAN = "Artisan",
}, { __index = _G })

local ns = {
	Thresholds = {
		[GLOVES] = { 125, 140, 155, 165 },
		[HILLMANS] = { 145, 155, 165, 175 },
		[SHIRT] = { 40, 60, 70, 80 },
		[BRACERS] = { 1, 20, 40, 60 },
	},
	RecipeData = {
		[GLOVES] = { skillLine = 165, reagents = {}, output = { itemID = 4253, quantity = 1 } },
		[HILLMANS] = { skillLine = 165, reagents = {}, output = { itemID = 4247, quantity = 1 } },
		[LEATHER_RECIPE] = { skillLine = 165, reagents = {}, output = { itemID = LEATHER, quantity = 1 } },
		[SHIRT] = { skillLine = 197, reagents = {} },
	},
	TrainerFees = { [HILLMANS] = { 1800, 145 } },
	FormatNet = function(copper)
		return copper .. "c"
	end,
}
for _, file in ipairs({ "Locales/enUS.lua", "Model.lua", "Route.lua", "Shopping.lua", "API.lua" }) do
	setfenv(assert(loadfile(file)), env)("SkillUpForever", ns)
end
local API = env.SkillUpForever.API
equal(API.version, 1, "version 1")
equal(#API.Professions(), 0, "nothing before the saved variables load")

ns.db = { trainer = {}, routeTargets = {} }
local learned = { [GLOVES] = true, [LEATHER_RECIPE] = true, [SHIRT] = true, [BRACERS] = true }
ns.IsLearned = function(id)
	return learned[id] == true
end
ns.IsTracked = function(skillLine)
	return skillLine == 197
end
local reagents = {
	[GLOVES] = { { itemID = LEATHER, quantity = 6 }, { itemID = THREAD, quantity = 2 } },
	[HILLMANS] = { { itemID = LEATHER, quantity = 8 }, { itemID = THREAD, quantity = 1 } },
	[SHIRT] = { { itemID = SILK, quantity = 1 } },
	[BRACERS] = {},
}
ns.Reagents = function(id)
	return reagents[id]
end
local bags = { [LEATHER] = 40, [SILK] = 20 }
ns.Have = function(id)
	return bags[id] or 0
end
local prices = { [THREAD] = { copper = 100, source = "vendor" }, [LEATHER] = { copper = 500, source = "auctionator" } }
ns.Price = function(id)
	return prices[id]
end
ns.PriceSource = function(id)
	return prices[id] and prices[id].source
end
local travelled = {}
ns.NearestVendor = function(id, byTravel)
	travelled[#travelled + 1] = byTravel or false
	return id == THREAD and 77 or nil
end
ns.NearestTrainer = function(_, _, byTravel)
	travelled[#travelled + 1] = byTravel or false
	return 88
end
ns.NPCLocation = function(npcID)
	return npcID == 77 and { name = "Gina", label = "Darkshire" } or { name = "Telonis", label = "Darnassus" }
end
local waypoint
ns.SetWaypoint = function(npcID)
	waypoint = npcID
	return true
end

local function Profession(skillLine, name, base, max)
	return {
		skillLine = skillLine,
		professionID = skillLine + 8000,
		name = name,
		icon = 136247,
		base = base,
		max = max,
		skill = base,
		modifier = 0,
	}
end
local professions = {
	[165] = Profession(165, "Leatherworking", 142, 150),
	[197] = Profession(197, "Tailoring", 50, 75),
	[164] = Profession(164, "Blacksmithing", 10, 75),
	[171] = Profession(171, "Alchemy", 0, 0),
}
ns.RouteProfessions = function()
	return professions
end
local function Route(segments, training)
	return { segments = segments, training = training or {}, ranks = {}, excluded = { unpriced = 0 } }
end
local routes = {
	[165] = Route({
		{ recipeID = GLOVES, fromSkill = 142, toSkill = 145, expectedCrafts = 3, crafts = 3 },
		{ recipeID = HILLMANS, fromSkill = 145, toSkill = 150, expectedCrafts = 5, crafts = 5 },
	}, { { recipeID = HILLMANS, fee = 1800, atSkill = 145 } }),
	[197] = Route({ { recipeID = SHIRT, fromSkill = 50, toSkill = 60, expectedCrafts = 10, crafts = 10 } }),
	[164] = Route({ { recipeID = BRACERS, fromSkill = 10, toSkill = 20, expectedCrafts = 10, crafts = 10 } }),
	[171] = Route({}),
}
local plans = 0
ns.PlanRoute = function(profession)
	plans = plans + 1
	return routes[profession.skillLine]
end

local list = API.Professions()
-- Tracked first, then reagents in hand, then a purchase first, then nothing to do.
equal(#list, 4, "one entry per profession")
equal(list[1].name, "Tailoring", "a tracked profession leads")
equal(list[2].name, "Blacksmithing", "a craft ready to go beats a shopping trip")
equal(list[3].name, "Leatherworking", "a purchase first comes after")
equal(list[4].name, "Alchemy", "nothing to do comes last")

local lw = list[3]
equal(lw.skillLineID, 165, "skill line")
equal(lw.icon, 136247, "icon")
equal(lw.rank, 142, "rank is base skill")
equal(lw.maxRank, 150, "max rank is the cap")
equal(lw.title, "Journeyman", "the 150 cap is Journeyman")
equal(#lw.steps, 3, "at most three steps")

local buy, craft, train = lw.steps[1], lw.steps[2], lw.steps[3]
equal(buy.kind, "buy", "the thread the bags lack is bought first")
equal(buy.text, "Buy 6 Fine Thread", "buy text")
equal(buy.detail, "Gina, Darkshire · 600c", "buy detail names the nearest vendor and cost")
equal(buy.itemID, THREAD, "buy item")
equal(buy.count, 6, "buy count")
equal(buy.cost, 600, "buy cost")
equal(buy.nav, true, "a vendor can be routed to")
equal(craft.kind, "craft", "then the craft")
equal(craft.text, "Craft 3 Toughened Leather Gloves", "craft text")
equal(craft.detail, "142 to 145", "craft detail is its skill range")
equal(craft.spellID, GLOVES, "craft spell")
equal(craft.itemID, 4253, "craft product")
equal(craft.count, 3, "craft count")
equal(craft.cost, nil, "the craft's cost is in its purchases")
equal(craft.nav, false, "a craft has nowhere to go")
equal(train.kind, "train", "then the recipe the route trains next")
equal(train.text, "Train Hillman's Leather Gloves", "train text")
equal(train.detail, "Telonis, Darnassus · 1800c", "train detail names the nearest trainer and fee")
equal(train.spellID, HILLMANS, "train spell")
equal(train.cost, 1800, "train fee")
equal(train.nav, true, "a trainer can be routed to")

equal(#lw.recipes, 2, "the route's crafts")
local gloves, hillmans = lw.recipes[1], lw.recipes[2]
equal(gloves.name, "Toughened Leather Gloves", "recipe name")
equal(gloves.spellID, GLOVES, "recipe spell")
equal(gloves.itemID, 4253, "recipe product")
equal(gloves.count, 3, "recipe crafts")
equal(gloves.fromRank, 142, "recipe from")
equal(gloves.toRank, 145, "recipe to")
equal(gloves.learned, true, "known recipe")
equal(gloves.color, "yellow", "colour at its first skill")
equal(gloves.trainAt, nil, "a known recipe needs no training")
equal(gloves.cost, nil, "and costs no fee")
equal(hillmans.learned, false, "a recipe still to train")
equal(hillmans.trainAt, 145, "trained where the route first uses it")
equal(hillmans.cost, 1800, "its fee")
equal(hillmans.color, "orange", "orange at 145")

local byItem = {}
for _, reagent in ipairs(lw.reagents) do
	byItem[reagent.itemID] = reagent
end
equal(byItem[THREAD].need, 11, "thread for the whole route")
equal(byItem[THREAD].have, 0, "thread in the bags")
equal(byItem[THREAD].source, "vendor", "thread from a vendor")
equal(byItem[LEATHER].need, 58, "leather for the whole route")
equal(byItem[LEATHER].have, 40, "leather in the bags")
equal(byItem[LEATHER].source, "craft", "a learned recipe makes the leather")

-- Nil where SkillUp can't tell: no name, no rank title, no price, nothing planned.
local tailoring = list[1]
equal(tailoring.steps[1].text, "Craft 10 recipe 3", "an unnamed recipe still reads")
equal(tailoring.recipes[1].name, nil, "an unnamed recipe has no name")
equal(tailoring.recipes[1].itemID, nil, "a recipe without a product has no item")
equal(tailoring.reagents[1].source, nil, "an unpriced reagent has no source")
local alchemy = list[4]
equal(alchemy.title, nil, "a cap no rank ends at has no title")
equal(#alchemy.steps, 0, "no steps")
equal(#alchemy.recipes, 0, "no recipes")
equal(#alchemy.reagents, 0, "no reagents")

-- Kept until an event says otherwise.
equal(API.Professions(), list, "a second call is the cache")
equal(plans, 4, "and plans nothing")
handler(nil, "ITEM_DATA_LOAD_RESULT")
equal(API.Professions(), list, "item data with no name waiting keeps the cache")
handler(nil, "BAG_UPDATE_DELAYED")
local rebuilt = API.Professions()
equal(rebuilt ~= list, true, "a bag update rebuilds")
equal(plans, 8, "planning each profession once")
ns.InvalidateAPI()
equal(API.Professions() ~= rebuilt, true, "invalidated plans rebuild it")

-- Steps route by travel time to the NPC they name.
travelled = {}
equal(API.Navigate(165, 1), true, "the vendor step routes")
equal(waypoint, 77, "to the vendor")
equal(travelled[#travelled], true, "picked by travel")
equal(API.Navigate(165, 3), true, "the training step routes")
equal(waypoint, 88, "to the trainer")
equal(API.Navigate(165, 2), false, "a craft doesn't route")
equal(API.Navigate(999, 1), false, "an unknown profession doesn't route")

equal(API.OpenRecipes(165), true, "opens a profession")
equal(opened[1], 8165, "by the ID the client reported")
equal(API.OpenRecipes(999), false, "not one the character lacks")

print("api_spec: " .. checks .. " checks passed")
