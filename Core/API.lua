---@type string, SkillUpNamespace
local _, ns = ...

if ns.broken then
	return
end
local L = ns.L

-- SkillUpForever.API, version 1: each profession's next steps, recipes and reagents,
-- read from the same levelling plan the route tab shows, for other addons to draw.
-- Built once and kept until Core/Changes.lua says it is stale.
-- API.ShoppingList's records carry `target`: the base skill that profession's plan buys to,
-- the same number the route tab's Target box shows.

-- Core/Require.lua stopped every file if the kit is missing, so it is here.
local APIKit = ForeverCore.APIKit
---@cast APIKit ForeverCoreAPIKit

-- A change that drops the API's cache reaches callers through ForeverCore's hub, on the frame after it lands and
-- once per burst, never in the call that made it (docs/api.md). Both names move together: one change signal drops
-- every answer, so the list and the shopping list are read again together.
local revision = 0
local hub = APIKit.Hub("SkillUpForever", {
	professions = function()
		return revision
	end,
	shopping = function()
		return revision
	end,
}, function()
	return ns.db ~= nil
end)

local DEFAULT_STEPS = 3
local DEFAULT_RECIPES = 5
-- The largest answer one call may ask for. The cache is built once at this size and each call trims its own copy:
-- a limit never forces a rebuild, and one build is cheaper than a cache per limit.
local MAX_LIMIT = 25
-- Earlier first: what can be done with what's in the bags beats a trip.
local KIND_ORDER = { craft = 1, buy = 2, gather = 3, train = 4 }

---@type SkillUpAPIProfession[]?
local cache
-- [skill line][step index] = picks the step's NPC by travel time, for Navigate.
---@type table<integer, table<integer, fun(): integer?>>
local pickers = {}
local namesPending = false

ns.WhenStale("api", function()
	namesPending = false
	cache = nil
	revision = revision + 1
	hub.Queue()
end)

---@param copper number
---@return string
local function Money(copper)
	return ns.FormatNet(ns.Model.RoundMoney(copper), false)
end

---@param itemID integer
---@return string
local function ItemName(itemID)
	local name = C_Item.GetItemNameByID(itemID)
	if name then
		return name
	end
	namesPending = true
	C_Item.RequestLoadItemDataByID(itemID)
	return string.format(L["item %d"], itemID)
end

---@param recipeID integer
---@return integer?
local function OutputItem(recipeID)
	local recipe = ns.RecipeData[recipeID]
	return recipe and recipe.output and recipe.output.itemID or nil
end

-- "Name, Zone · fee", or the fallback when there is no NPC to name.
---@param npcID integer?
---@param fallback string
---@param copper number?
---@return string
local function Detail(npcID, fallback, copper)
	local text = fallback
	if npcID then
		local where = ns.NPCLocation(npcID)
		text = where.name .. ", " .. where.label
	end
	if copper and copper > 0 then
		text = text .. " · " .. Money(copper)
	end
	return text
end

-- [itemID] = recipes that make it, from the bundled data.
---@type table<integer, integer[]>?
local makers

---@param itemID integer
---@return boolean
local function CanCraft(itemID)
	if not makers then
		makers = {}
		for recipeID in pairs(ns.RecipeData) do
			local output = OutputItem(recipeID)
			if output then
				makers[output] = makers[output] or {}
				table.insert(makers[output], recipeID)
			end
		end
	end
	for _, recipeID in ipairs(makers[itemID] or {}) do
		if ns.IsLearned(recipeID) then
			return true
		end
	end
	return false
end

---@param item SkillUpNeededItem
---@return SkillUpAPIReagentSource?
local function ReagentSource(item)
	if item.source == "gather" then
		return "gather"
	elseif item.source == "vendor" then
		return "vendor"
	elseif CanCraft(item.itemID) then
		return "craft"
	elseif item.source == "auction" then
		return "auction"
	end
end

-- Getting `count` more of a reagent, the way its price says it is got.
---@param itemID integer
---@param count number
---@return SkillUpAPIStep
---@return (fun(): integer?)?
local function Acquire(itemID, count)
	local name = ItemName(itemID)
	local price = ns.Price(itemID)
	if price and price.source == "gather" then
		return {
			kind = "gather",
			text = price.loot and string.format(L["Loot %d %s from creatures"], count, name)
				or string.format(L["Gather %d %s"], count, name),
			detail = price.profession,
			itemID = itemID,
			count = count,
			nav = false,
		}
	end
	local cost = price and not price.unknown and price.copper * count or nil
	local step = {
		kind = "buy",
		text = string.format(L["Buy %d %s"], count, name),
		itemID = itemID,
		count = count,
		cost = cost,
		nav = false,
	}
	if price and price.source == "vendor" then
		local vendor = ns.NearestVendor(itemID)
		step.detail, step.nav = Detail(vendor, L["Vendor"], cost), vendor ~= nil
		return step, vendor and function()
			return ns.NearestVendor(itemID, true)
		end or nil
	elseif price then
		step.detail = Detail(nil, L["Auction house"], cost)
	end
	return step
end

---@param profession SkillUpProfession
---@param text string
---@param cap number
---@param fee number
---@return SkillUpAPIStep
---@return (fun(): integer?)?
local function Train(profession, text, cap, fee)
	local trainer = ns.NearestTrainer(profession, cap)
	local step = {
		kind = "train",
		text = text,
		detail = Detail(trainer, string.format(L["%s trainer"], profession.name), fee),
		cost = fee > 0 and fee or nil,
		nav = trainer ~= nil,
	}
	return step, trainer and function()
		return ns.NearestTrainer(profession, cap, true)
	end or nil
end

-- A recipe no trainer teaches: buy its scroll from a vendor, and go to that vendor, not a trainer (#358).
---@param training SkillUpPlanTraining
---@return SkillUpAPIStep
---@return (fun(): integer?)?
local function Scroll(training)
	local vendor = ns.NearestScrollVendor(training.recipeID)
	local step = {
		kind = "train",
		text = string.format(L["Buy %s"], ItemName(training.scroll)),
		detail = Detail(vendor, L["Vendor"], training.fee),
		itemID = training.scroll,
		spellID = training.recipeID,
		cost = training.fee > 0 and training.fee or nil,
		nav = vendor ~= nil,
	}
	return step, vendor and function()
		return ns.NearestScrollVendor(training.recipeID, true)
	end or nil
end

-- A rank no trainer teaches: buy its book from a vendor and read it, or only read it when the bags hold it.
---@param rank SkillUpRank
---@return SkillUpAPIStep
---@return (fun(): integer?)?
local function Book(rank)
	local book = rank.book
	---@cast book integer
	-- Asked by name here so the list rebuilds when the book's name arrives.
	ItemName(book)
	if ns.RankHeld(rank) then
		return { kind = "train", text = ns.RankText(rank), itemID = book, nav = false }
	end
	local vendor = ns.NearestVendor(book)
	local step = {
		kind = "buy",
		text = ns.RankText(rank),
		detail = Detail(vendor, L["Vendor"], rank.fee),
		itemID = book,
		count = 1,
		cost = rank.fee > 0 and rank.fee or nil,
		nav = vendor ~= nil,
	}
	return step, vendor and function()
		return ns.NearestVendor(book, true)
	end or nil
end

-- A rank only a quest teaches: a train step with the quest's ID, sent to its nearest giver.
---@param profession SkillUpProfession
---@param rank SkillUpRank
---@return SkillUpAPIStep
---@return (fun(): integer?)?
local function Quest(profession, rank)
	local giver = ns.NearestForRank(profession, rank)
	local step = {
		kind = "train",
		text = ns.RankText(rank),
		detail = Detail(giver, L["Quest"]),
		questID = rank.quest,
		nav = giver ~= nil,
	}
	return step, giver and function()
		return (ns.NearestForRank(profession, rank, true))
	end or nil
end

-- The route's first few steps, each craft preceded by getting what the bags lack for it.
---@param plan SkillUpPlan
---@return SkillUpAPIStep[]
---@return table<integer, fun(): integer?>
local function Steps(plan)
	local profession = plan.profession
	local steps, picks, held = {}, {}, {}
	---@param step SkillUpAPIStep
	---@param pick (fun(): integer?)?
	local function Add(step, pick)
		if #steps < MAX_LIMIT then
			steps[#steps + 1] = step
			picks[#steps] = pick
		end
	end
	for _, walk in ipairs(plan.steps) do
		if #steps >= MAX_LIMIT then
			break
		end
		local rank, training, craft, subcraft = walk.rank, walk.training, walk.craft, walk.subcraft
		if subcraft then
			local name = C_Spell.GetSpellName(subcraft.recipeID) or string.format(L["recipe %d"], subcraft.recipeID)
			Add({
				kind = "craft",
				text = string.format(L["Craft %d %s"], subcraft.crafts, name),
				detail = string.format(L["for %s"], ItemName(subcraft.itemID)),
				spellID = subcraft.recipeID,
				itemID = subcraft.itemID,
				count = subcraft.crafts,
				nav = false,
			})
		elseif rank and rank.book then
			Add(Book(rank)) -- multi-value: the step and its picker
		elseif rank and rank.quest then
			Add(Quest(profession, rank)) -- multi-value: the step and its picker
		elseif rank then
			Add(Train(profession, ns.RankText(rank), rank.cap, rank.fee)) -- multi-value: the step and its picker
		elseif training then
			local name = C_Spell.GetSpellName(training.recipeID) or string.format(L["recipe %d"], training.recipeID)
			local step, pick
			if training.scroll then
				step, pick = Scroll(training)
			else
				step, pick = Train(profession, string.format(L["Train %s"], name), training.cap, training.fee)
				step.spellID, step.itemID = training.recipeID, OutputItem(training.recipeID)
			end
			Add(step, pick)
		elseif craft then
			local recipeID = craft.recipeID
			for _, reagent in ipairs(ns.Reagents(recipeID) or {}) do
				local itemID, need = reagent.itemID, reagent.quantity * craft.crafts
				local have = held[itemID] or ns.Have(itemID)
				held[itemID] = math.max(have - need, 0)
				if have < need then
					Add(Acquire(itemID, need - have)) -- multi-value: the step and its picker
				end
			end
			local name = C_Spell.GetSpellName(recipeID) or string.format(L["recipe %d"], recipeID)
			Add({
				kind = "craft",
				text = string.format(L["Craft %d %s"], craft.crafts, name),
				detail = string.format(L["%d to %d"], craft.from, craft.to),
				spellID = recipeID,
				itemID = OutputItem(recipeID),
				count = craft.crafts,
				nav = false,
			})
		end
	end
	return steps, picks
end

---@param plan SkillUpPlan
---@return SkillUpAPIRecipe[]
local function Recipes(plan)
	local training = {}
	for _, step in ipairs(plan.training) do
		training[step.recipeID] = step
	end
	local recipes = {}
	for i = 1, math.min(#plan.crafts, MAX_LIMIT) do
		local craft = plan.crafts[i]
		local recipeID, step = craft.recipeID, training[craft.recipeID]
		recipes[i] = {
			spellID = recipeID,
			itemID = OutputItem(recipeID),
			name = C_Spell.GetSpellName(recipeID),
			count = craft.crafts,
			fromRank = craft.from,
			toRank = craft.to,
			learned = ns.IsLearned(recipeID) == true,
			color = craft.color,
			trainAt = step and step.usedAt,
			cost = step and step.fee,
		}
	end
	return recipes
end

---@param plan SkillUpPlan
---@return SkillUpAPIReagent[]
local function Reagents(plan)
	local reagents = {}
	for _, item in ipairs(ns.RouteReagents(plan)) do
		reagents[#reagents + 1] =
			{ itemID = item.itemID, need = item.need, have = ns.Have(item.itemID), source = ReagentSource(item) }
	end
	return reagents
end

---@param entry SkillUpAPIProfession
---@return number
local function Urgency(entry)
	local first = entry.steps[1]
	return first and KIND_ORDER[first.kind] or 5
end

---@return SkillUpAPIProfession[]
local function Build()
	local entries, urgency = {}, {}
	pickers = {}
	for skillLine, profession in pairs(ns.RouteProfessions()) do
		local plan = ns.PlanRoute(profession)
		local steps, picks = Steps(plan)
		pickers[skillLine] = picks
		local entry = {
			name = profession.name,
			skillLineID = skillLine,
			icon = profession.icon,
			rank = profession.base,
			maxRank = profession.max,
			title = ns.RankName(profession.max),
			steps = steps,
			recipes = Recipes(plan),
			reagents = Reagents(plan),
		}
		entries[#entries + 1] = entry
		urgency[entry] = { #steps > 0 and 0 or 1, ns.IsTracked(skillLine) and 0 or 1, Urgency(entry) }
	end
	-- Something to do first, then what the player tracks, then the nearest to doing.
	table.sort(entries, function(a, b)
		local ua, ub = urgency[a], urgency[b]
		for i = 1, #ua do
			if ua[i] ~= ub[i] then
				return ua[i] < ub[i]
			end
		end
		return a.name < b.name
	end)
	return entries
end

-- The built answers, or nil while the saved variables are still loading. They are built once and kept until
-- Core/Changes.lua drops them, so only the copy handed to a caller is fresh.
---@return SkillUpAPIProfession[]?
local function Ensure()
	if not ns.db then
		return nil
	end
	if not cache then
		cache = Build()
	end
	return cache
end

---@generic T
---@param row T
---@return T
local function CopyRow(row)
	local copy = {}
	for key, value in pairs(row) do
		copy[key] = value
	end
	return copy
end

-- A read returns a fresh table on every call: a caller may keep it or change it (docs/api-conventions.md). The
-- cache holds MAX_LIMIT of each, so trimming here is the only per-call work a limit adds.
---@param list SkillUpAPIProfession[]
---@param steps number
---@param recipes number
---@return SkillUpAPIProfession[]
local function CopyProfessions(list, steps, recipes)
	local copy = {}
	for index, entry in ipairs(list) do
		local copiedSteps, copiedRecipes, reagents = {}, {}, {}
		for stepIndex = 1, math.min(#entry.steps, steps) do
			copiedSteps[stepIndex] = CopyRow(entry.steps[stepIndex])
		end
		for recipeIndex = 1, math.min(#entry.recipes, recipes) do
			copiedRecipes[recipeIndex] = CopyRow(entry.recipes[recipeIndex])
		end
		for reagentIndex, reagent in ipairs(entry.reagents) do
			reagents[reagentIndex] = CopyRow(reagent)
		end
		copy[index] = {
			name = entry.name,
			skillLineID = entry.skillLineID,
			icon = entry.icon,
			rank = entry.rank,
			maxRank = entry.maxRank,
			title = entry.title,
			steps = copiedSteps,
			recipes = copiedRecipes,
			reagents = reagents,
		}
	end
	return copy
end

-- A whole number between two bounds; anything else is the caller's mistake, not missing data.
---@param value any
---@param low number
---@param high number
---@return boolean
local function WholeBetween(value, low, high)
	return type(value) == "number" and value == value and value >= low and value <= high and value % 1 == 0
end

local STATS_METRIC = "recipes_observed_learned"

---@class SkillUpPublicAPI
-- `minor` rises with each addition within version 1 (1: Professions, Navigate and OpenRecipes; 2: ShoppingList;
-- 3: each shopping row's target; 4: RequiredMaterials and SubComponents; 5: Subscribe and the not-ready reason;
-- 6: IsTracked, SetTracked, ShoppingTrip, Professions limits and Stats);
-- a caller checks a member before using it (docs/api.md).
local API = { version = 1, minor = 6 }

-- The same hub the addon queues its own changes through; api.Subscribe is ForeverCore's (docs/api.md).
API.Subscribe = hub.Subscribe

-- Whether a profession is tracked in the objective tracker, from the same saved choice the route page writes.
---@param skillLineID integer
---@return boolean?
---@return SkillUpAPIReason?
function API.IsTracked(skillLineID)
	if not ns.db then
		return APIKit.NotReady("loading")
	end
	return ns.IsTracked(skillLineID)
end

-- The same choice without the player's click sound; an unlearned skill line has no tracker choice to set.
---@param skillLineID integer
---@param tracked boolean
---@return boolean?
---@return SkillUpAPIReason?
function API.SetTracked(skillLineID, tracked)
	if not ns.db then
		return APIKit.NotReady("loading")
	end
	if type(tracked) ~= "boolean" or not ns.PlayerProfessions()[skillLineID] then
		return false
	end
	if ns.IsTracked(skillLineID) == tracked then
		return false
	end
	ns.SetTracked(skillLineID, tracked)
	return true
end

---@param recipeID integer
---@param crafts number?
---@return {itemID: integer, count: number}[]?
---@return SkillUpAPIReason?
function API.RequiredMaterials(recipeID, crafts)
	local _, raw = ns.RecipeMaterials(recipeID, crafts or 1)
	if not raw then
		return APIKit.NotReady("none")
	end
	return raw
end

---@param recipeID integer
---@param crafts number?
---@return SkillUpSubCraft[]?
---@return SkillUpAPIReason?
function API.SubComponents(recipeID, crafts)
	local subcrafts = ns.RecipeMaterials(recipeID, crafts or 1)
	if not subcrafts then
		return APIKit.NotReady("none")
	end
	return subcrafts
end

---@param skillLineID integer?
---@return SkillUpAPIShoppingProfession[]
function API.ShoppingList(skillLineID)
	if not ns.db then
		return {}
	end
	local entries = {}
	local tracked = ns.TrackedNeeds()
	for _, entry in ipairs(tracked) do
		if not skillLineID or entry.plan.profession.skillLine == skillLineID then
			local result = {
				profession = entry.plan.profession.name,
				skillLine = entry.plan.profession.skillLine,
				target = entry.plan.target,
				items = {},
				total = 0,
				unpriced = 0,
			}
			local bySource = {}
			for _, source in ipairs(ns.Model.SHOPPING_SOURCES) do
				bySource[source] = {}
			end
			for _, item in ipairs(entry.items) do
				local price = ns.Price(item.itemID)
				local have = ns.Have(item.itemID)
				local missing = math.max(item.need - have, 0)
				local row = {
					itemID = item.itemID,
					need = item.need,
					have = have,
					missing = missing,
					source = item.source,
					price = price and not price.unknown and price.copper or nil,
					priceAge = price and price.source == "auctionator" and price.days or nil,
					cost = price and not price.unknown and missing * price.copper or nil,
					alt = ns.AltCounts(item.itemID),
				}
				bySource[row.source][#bySource[row.source] + 1] = row
			end
			for _, source in ipairs(ns.Model.SHOPPING_SOURCES) do
				table.sort(bySource[source], function(a, b)
					return a.itemID < b.itemID
				end)
				for _, row in ipairs(bySource[source]) do
					result.items[#result.items + 1] = row
					if row.missing > 0 then
						if row.cost then
							result.total = result.total + row.cost
						else
							result.unpriced = result.unpriced + 1
						end
					end
				end
			end
			entries[#entries + 1] = result
		end
	end
	table.sort(entries, function(a, b)
		return a.profession == b.profession and a.skillLine < b.skillLine or a.profession < b.profession
	end)
	return entries
end
ns.ShoppingList = API.ShoppingList

---@param copper number
---@return string
local function PlainMoney(copper)
	copper = ns.Model.RoundMoney(copper)
	local text = ns.FormatNet(copper, false)
	text = text:gsub("|T.-GoldIcon.-|t", "g"):gsub("|T.-SilverIcon.-|t", "s")
	text = text:gsub("|T.-CopperIcon.-|t", "c")
	return text
end

---@param skillLineID integer?
---@return string
function ns.ShoppingText(skillLineID)
	local lists = API.ShoppingList(skillLineID)
	local professions = {}
	for _, list in ipairs(lists) do
		professions[#professions + 1] = list.profession
	end
	local lines = {
		L["SkillUp Forever shopping list"],
		#professions > 0 and table.concat(professions, ", ") or L["No tracked profession"],
	}
	local total = 0
	for _, source in ipairs(ns.Model.SHOPPING_SOURCES) do
		local bucket = {}
		for _, list in ipairs(lists) do
			for _, row in ipairs(list.items) do
				if row.source == source and row.missing > 0 then
					local name = C_Item.GetItemNameByID(row.itemID)
					if not name then
						C_Item.RequestLoadItemDataByID(row.itemID)
						name = string.format(L["item %d"], row.itemID)
					end
					local text
					if row.price then
						text = string.format(L["%d x %s - %s each"], row.missing, name, PlainMoney(row.price))
						if row.priceAge then
							text = text .. string.format(L[", price seen %d days ago"], row.priceAge)
						end
						text = text .. " - " .. PlainMoney(row.cost)
						total = total + row.cost
					else
						text = string.format(L["%d x %s - price unknown"], row.missing, name)
					end
					bucket[#bucket + 1] = text
				end
			end
		end
		if #bucket > 0 then
			local titles =
				{ gather = L["Gather"], vendor = L["Vendor"], auction = L["Auction house"], unknown = L["Unknown"] }
			lines[#lines + 1] = titles[source]
			for _, line in ipairs(bucket) do
				lines[#lines + 1] = line
			end
		end
	end
	lines[#lines + 1] = L["Total for priced items: "] .. PlainMoney(total)
	return table.concat(lines, "\n")
end

---@param skillLineID integer?
---@return boolean
function ns.ShoppingTrip(skillLineID)
	local lists = API.ShoppingList(skillLineID)
	local byVendor, vendorItems, trainers = {}, {}, {}
	local anyMissing = false
	for _, list in ipairs(lists) do
		local profession = ns.RouteProfessions()[list.skillLine]
		local plan = profession and ns.PlanRoute(profession)
		for _, row in ipairs(list.items) do
			if row.missing > 0 then
				anyMissing = true
				if row.source == "vendor" then
					local npcID = ns.NearestVendor(row.itemID, true)
					if npcID then
						byVendor[npcID] = true
						vendorItems[npcID] = vendorItems[npcID] or {}
						vendorItems[npcID][#vendorItems[npcID] + 1] = row.itemID
					end
				end
			end
		end
		local first = plan and plan.steps and plan.steps[1] and plan.steps[1].training
		if first and first.scroll then
			local npcID = ns.NearestScrollVendor(first.recipeID, true)
			if npcID then
				byVendor[npcID] = true
				vendorItems[npcID] = vendorItems[npcID] or {}
				vendorItems[npcID][#vendorItems[npcID] + 1] = first.scroll
			end
		elseif first then
			local npcID = ns.NearestTrainer(profession, first.cap, true)
			if npcID then
				trainers[npcID] = true
			end
		end
	end
	if not anyMissing then
		ns.Print(L["Nothing is missing from the shopping list."])
		return false
	end
	local stops = {}
	local ids = {}
	for id in pairs(byVendor) do
		ids[#ids + 1] = id
	end
	local api = ShortestPathForever and ShortestPathForever.API
	local map = C_Map.GetBestMapForUnit("player")
	local point = map and C_Map.GetPlayerMapPosition(map, "player")
	local x, y
	if point then
		x, y = point:GetXY()
	end
	local travel = {}
	for _, id in ipairs(ids) do
		local where = ns.NPCLocation(id)
		travel[id] = api
				and api.Estimate
				and map
				and x
				and y
				and where.map
				and api.Estimate(map, x, y, where.map, where.x, where.y)
			or math.huge
	end
	table.sort(ids, function(a, b)
		return travel[a] == travel[b] and a < b or travel[a] < travel[b]
	end)
	for _, id in ipairs(ids) do
		local where = ns.NPCLocation(id)
		if where.map and where.x and where.y then
			local names = {}
			for _, itemID in ipairs(vendorItems[id]) do
				names[#names + 1] = C_Item.GetItemNameByID(itemID) or string.format(L["item %d"], itemID)
			end
			stops[#stops + 1] = {
				map = where.map,
				x = where.x,
				y = where.y,
				title = where.name .. L[": "] .. table.concat(names, L[", "]),
				kind = "vendor",
			}
		end
	end
	-- The catalogue exposes no faction-aware auctioneer location contract; never guess an NPC here.
	local trainerIDs = {}
	for id in pairs(trainers) do
		trainerIDs[#trainerIDs + 1] = id
	end
	table.sort(trainerIDs)
	for _, id in ipairs(trainerIDs) do
		local where = ns.NPCLocation(id)
		if where.map and where.x and where.y then
			stops[#stops + 1] = { map = where.map, x = where.x, y = where.y, title = where.name, kind = "trainer" }
		end
	end
	while #stops > 64 do
		table.remove(stops)
	end
	if api and type(api.NavigateRoute) == "function" and #stops > 0 and api.NavigateRoute("SkillUpForever", stops) then
		return true
	end
	local first = ids[1]
	if first then
		ns.Print(L["Shortest Path Forever cannot plan the full trip; setting a waypoint to the first vendor."])
		ns.SetWaypoint(first)
	else
		ns.Print(L["Shortest Path Forever is needed to plan this trip."])
	end
	return false
end

---@param limits? SkillUpAPIProfessionLimits
---@return SkillUpAPIProfession[]?
---@return SkillUpAPIReason?
function API.Professions(limits)
	local steps, recipes = DEFAULT_STEPS, DEFAULT_RECIPES
	if limits ~= nil then
		if type(limits) ~= "table" then
			return nil, "invalid"
		end
		local stepLimit = limits.steps
		if stepLimit ~= nil then
			if not WholeBetween(stepLimit, 1, MAX_LIMIT) then
				return nil, "invalid"
			end
			---@cast stepLimit integer
			steps = stepLimit
		end
		local recipeLimit = limits.recipes
		if recipeLimit ~= nil then
			if not WholeBetween(recipeLimit, 1, MAX_LIMIT) then
				return nil, "invalid"
			end
			---@cast recipeLimit integer
			recipes = recipeLimit
		end
	end
	local list = Ensure()
	if not list then
		return APIKit.NotReady("loading")
	end
	return CopyProfessions(list, steps, recipes)
end

-- The shopping list's trip button, with the same route and fallback.
---@param skillLineID integer?
---@return boolean
function API.ShoppingTrip(skillLineID)
	return ns.ShoppingTrip(skillLineID)
end

-- This character's own recipe observations.
---@return SkillUpAPIStat[]
function API.Stats()
	local value, eventUnix = ns.Stats.Local()
	return {
		{
			addon = "SkillUpForever",
			metric = STATS_METRIC,
			subject = "all",
			value = value,
			eventUnix = eventUnix,
		},
	}
end

---@param skillLineID integer
---@param stepIndex integer
---@return boolean
function API.Navigate(skillLineID, stepIndex)
	if not Ensure() then
		return false
	end
	local pick = pickers[skillLineID] and pickers[skillLineID][stepIndex]
	local npcID = pick and pick()
	return npcID ~= nil and ns.SetWaypoint(npcID)
end

-- The profession's window, where SkillUp's recipe colours and route tab are.
---@param skillLineID integer
---@return boolean
function API.OpenRecipes(skillLineID)
	local profession = ns.db and ns.RouteProfessions()[skillLineID]
	if not profession then
		return false
	end
	-- Forever's own profession ID opens it; the classic skill line is the fallback, asked only when it is
	-- another ID: the same one again would just repeat a request the client has refused.
	local id = profession.professionID
	if id and C_TradeSkillUI.OpenTradeSkill(id) then
		return true
	end
	return id ~= skillLineID and C_TradeSkillUI.OpenTradeSkill(skillLineID) == true
end

---@type SkillUpPublicAddon
SkillUpForever = { API = API }
if (ForeverCore.APIKit.minor or 1) >= 2 then
	ForeverCore.APIKit.Publish("SkillUpForever", API)
end

ns.WhenEvent("ITEM_DATA_LOAD_RESULT", function()
	return namesPending and "names" or nil
end)
