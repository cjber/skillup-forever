---@type string, SkillUpNamespace
local _, ns = ...

if ns.broken then
	return
end
local L = ns.L

-- The public copy runs for every read, so its primitives are locals: a global lookup per copied value is not free.
local type, next, min = type, next, math.min

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
-- Item names the list was built without; only one of these arriving rebuilds it (#846).
---@type table<integer, true>
local waitingNames = {}

ns.WhenStale("api", function()
	waitingNames = {}
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
	waitingNames[itemID] = true
	ns.RequestItemData(itemID)
	return string.format(L["item %d"], itemID)
end

---@param recipeID integer
---@return integer?
local function OutputItem(recipeID)
	local recipe = ns.RecipeData[recipeID]
	return recipe and recipe.output and recipe.output.itemID or nil
end

-- "Name, Zone · fee", or the fallback when there is no NPC to name. The separator is the locale's: a font
-- without a middle dot draws its own (Locales/ruRU.lua, #692).
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
		text = text .. L[" · "] .. Money(copper)
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
	elseif item.source == "auction" and item.allocatedPrice then
		return "auction"
	elseif CanCraft(item.itemID) then
		return "craft"
	elseif item.source == "auction" then
		return "auction"
	end
end

-- Getting `count` more of a reagent, the way its price says it is got.
---@param itemID integer
---@param count number
---@param price SkillUpPrice?
---@return SkillUpAPIStep
---@return (fun(): integer?)?
local function Acquire(itemID, count, price)
	local name = ItemName(itemID)
	price = price or ns.Price(itemID)
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
		local vendor = price.vendor or ns.NearestVendor(itemID)
		step.detail, step.nav = Detail(vendor, L["Vendor"], cost), vendor ~= nil
		return step, vendor and function()
			return price.vendor or ns.NearestVendor(itemID, true)
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

-- A recipe a trainer teaches: the nearest trainer who teaches that one, never one whose rank cap covers it
-- but who does not offer it (#722). A recipe only the other faction's trainers teach says so in the detail.
---@param profession SkillUpProfession
---@param text string
---@param training SkillUpPlanTraining
---@return SkillUpAPIStep
---@return (fun(): integer?)?
local function RecipeTrain(profession, text, training)
	local trainer, known = ns.NearestRecipeTrainer(profession, training.recipeID)
	local step = {
		kind = "train",
		text = text,
		detail = Detail(
			trainer,
			known and L["No trainer of your faction teaches this recipe."]
				or string.format(L["%s trainer"], profession.name),
			training.fee
		),
		cost = training.fee > 0 and training.fee or nil,
		nav = trainer ~= nil,
	}
	return step,
		trainer and function()
			return (ns.NearestRecipeTrainer(profession, training.recipeID, true))
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

-- The route's first few steps, each craft preceded by getting what the bags lack for it. The build expands the
-- route's reagents once and hands the same rows to every reader here.
---@param plan SkillUpPlan
---@param rows SkillUpNeededItem[]
---@return SkillUpAPIStep[]
---@return table<integer, fun(): integer?>
local function Steps(plan, rows)
	local profession = plan.profession
	local steps, picks = {}, {}
	---@param step SkillUpAPIStep
	---@param pick (fun(): integer?)?
	local function Add(step, pick)
		if #steps < MAX_LIMIT then
			steps[#steps + 1] = step
			picks[#steps] = pick
		end
	end
	local acquired = {}
	---@param inputs SkillUpRawInput[]
	---@param owner SkillUpSubCraft?
	local function AcquireInputs(inputs, owner)
		for _, item in ipairs(inputs) do
			if not acquired[item] and (not owner or item.owner == owner) then
				acquired[item] = true
				Add(Acquire(item.itemID, item.count, item.price)) -- multi-value: the step and its picker
			end
		end
	end
	local supply = ns.RouteDemand.Supply(plan)
	if supply then
		for _, acquisition in ipairs(supply.acquisitions or {}) do
			local npcID = acquisition.npcID
			local detail = Detail(npcID, L["Vendor"], acquisition.moneyCopper)
			local payments = ns.AcquisitionPayments({ acquisition })
			if payments ~= "" then
				detail = detail .. " · " .. L["Requires"] .. " " .. payments
			end
			Add({
				kind = "buy",
				text = string.format(L["Buy %d %s"], acquisition.units, ItemName(acquisition.itemID)),
				itemID = acquisition.itemID,
				count = acquisition.units,
				cost = acquisition.moneyCopper,
				detail = detail,
				nav = npcID ~= nil,
				acquisition = acquisition,
			}, npcID and function()
				return npcID
			end or nil)
		end
		for _, item in ipairs(rows) do
			if not item.acquisitions then
				local have = ns.RouteDemand.Held(item)
				local missing = have and item.need - have
				if missing and missing > 0 then
					Add(Acquire(item.itemID, missing)) -- multi-value: the tool step and its picker
				end
			end
		end
	end
	local craftIndex = 1
	for _, walk in ipairs(plan.steps) do
		if #steps >= MAX_LIMIT then
			break
		end
		local rank, training, craft, subcraft = walk.rank, walk.training, walk.craft, walk.subcraft
		if subcraft then
			if not supply then
				AcquireInputs(plan.crafts[craftIndex].raw, subcraft)
			end
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
				step, pick = RecipeTrain(profession, string.format(L["Train %s"], name), training)
				step.spellID, step.itemID = training.recipeID, OutputItem(training.recipeID)
			end
			Add(step, pick)
		elseif craft then
			local recipeID = craft.recipeID
			if not supply then
				AcquireInputs(plan.crafts[craftIndex].raw)
			end
			craftIndex = craftIndex + 1
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

---@param rows SkillUpNeededItem[]
---@return SkillUpAPIReagent[]
local function Reagents(rows)
	local reagents = {}
	for _, item in ipairs(rows) do
		reagents[#reagents + 1] = {
			itemID = item.itemID,
			need = item.need,
			have = ns.RouteDemand.Held(item),
			source = ReagentSource(item),
		}
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
		-- One expansion of the route serves the steps, the reagents and the source product universe.
		local rows = ns.RouteReagents(plan)
		local steps, picks = Steps(plan, rows)
		pickers[skillLine] = picks
		local products = {}
		for _, item in ipairs(rows) do
			products[item.itemID] = true
		end
		local entry = {
			name = profession.name,
			skillLineID = skillLine,
			icon = profession.icon,
			rank = profession.base,
			maxRank = profession.max,
			title = ns.RankName(profession.max),
			steps = steps,
			recipes = Recipes(plan),
			reagents = Reagents(rows),
			sourceEvidence = ns.SupplySources.Inspect(products),
			recipeEvidence = ns.RecipeEvidence.Inspect(skillLine),
			supply = plan.supply and plan.supply.job.result,
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
	-- `next` skips the iterator function `pairs` calls once per key; this runs for every public read.
	for key, value in next, row do
		copy[key] = type(value) == "table" and CopyRow(value) or value
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
		for stepIndex = 1, min(#entry.steps, steps) do
			copiedSteps[stepIndex] = CopyRow(entry.steps[stepIndex])
		end
		for recipeIndex = 1, min(#entry.recipes, recipes) do
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
			sourceEvidence = CopyRow(entry.sourceEvidence),
			recipeEvidence = ns.RecipeEvidence.Inspect(entry.skillLineID),
			supply = entry.supply and CopyRow(entry.supply) or nil,
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
local API = { version = 1, minor = 16 }

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
				supplySummary = CopyRow(ns.RouteDemand.Summary(entry.plan)),
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
				local price = not item.acquisitions and (item.allocatedPrice or ns.Price(item.itemID)) or nil
				local have = ns.RouteDemand.Held(item)
				local missing = have and math.max(item.need - have, 0)
				local row = {
					itemID = item.itemID,
					need = item.need,
					have = have,
					missing = missing,
					inventoryScope = item.supplyScope or "bags-and-bank",
					source = item.source,
					price = price and not price.unknown and price.copper or nil,
					priceAge = price and price.days or nil,
					cost = price and not price.unknown and missing and missing * price.copper or nil,
					alt = ns.AltCounts(item.itemID),
				}
				if item.acquisitions then
					row.acquisitions = CopyRow(item.acquisitions)
					row.cost = 0
					for _, acquisition in ipairs(item.acquisitions) do
						row.cost = row.cost + acquisition.moneyCopper
					end
				end
				bySource[row.source][#bySource[row.source] + 1] = row
			end
			for _, source in ipairs(ns.Model.SHOPPING_SOURCES) do
				table.sort(bySource[source], function(a, b)
					return a.itemID < b.itemID
				end)
				for _, row in ipairs(bySource[source]) do
					result.items[#result.items + 1] = row
					if row.missing and row.missing > 0 then
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
	for _, list in ipairs(lists) do
		lines[#lines + 1] = list.profession .. ": " .. ns.SupplySummaryText(list.supplySummary)
	end
	local total = 0
	for _, source in ipairs(ns.Model.SHOPPING_SOURCES) do
		local bucket = {}
		for _, list in ipairs(lists) do
			for _, row in ipairs(list.items) do
				if row.source == source and row.missing and row.missing > 0 then
					local name = C_Item.GetItemNameByID(row.itemID)
					if not name then
						ns.RequestItemData(row.itemID)
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
					if row.acquisitions then
						local payments = ns.AcquisitionPayments(row.acquisitions)
						if payments ~= "" then
							text = text .. " · " .. L["Requires"] .. " " .. payments
						end
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
			if row.missing and row.missing > 0 then
				anyMissing = true
				if row.source == "vendor" then
					for _, npcID in ipairs(ns.RouteDemand.Vendors(row, true)) do
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
			local npcID = ns.NearestRecipeTrainer(profession, first.recipeID, true)
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
			return APIKit.Invalid()
		end
		local stepLimit = limits.steps
		if stepLimit ~= nil then
			if not WholeBetween(stepLimit, 1, MAX_LIMIT) then
				return APIKit.Invalid()
			end
			---@cast stepLimit integer
			steps = stepLimit
		end
		local recipeLimit = limits.recipes
		if recipeLimit ~= nil then
			if not WholeBetween(recipeLimit, 1, MAX_LIMIT) then
				return APIKit.Invalid()
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

-- The client refuses OpenTradeSkill from addon code, including hardware clicks
-- (live evidence: forever-core#538). Reuse an already-open profession instead;
-- the player's own profession control is the only supported way to open it.
---@param skillLineID integer
---@return boolean
function API.OpenRecipes(skillLineID)
	if InCombatLockdown() then
		return false
	end
	local profession = ns.db and ns.RouteProfessions()[skillLineID]
	if not profession then
		return false
	end
	if ProfessionsFrame and ProfessionsFrame:IsShown() and ns.OpenSkillLine and ns.OpenSkillLine() == skillLineID then
		ForeverCore.ProfessionTabs.ShowNative()
		return true
	end
	ns.Print(string.format(L["Open %s from your spellbook."], profession.name))
	return false
end

-- Read-only recipe and account-history surfaces. These return fresh tables so callers cannot mutate the planner's
-- bundled data or saved-variable records through the public API.
---@param skillLineID integer?
---@return integer[]?, SkillUpAPIReason?
function API.Recipes(skillLineID)
	if not ns.db then
		return nil, "loading"
	end
	local result = {}
	for recipeID, recipe in pairs(ns.RecipeData or {}) do
		if not skillLineID or recipe.skillLine == skillLineID then
			result[#result + 1] = recipeID
		end
	end
	if #result == 0 then
		return nil, "none"
	end
	table.sort(result)
	return result
end

---@param recipeID integer
---@return SkillUpAPIRecipeDetails?, SkillUpAPIReason?
function API.Recipe(recipeID)
	if not ns.db then
		return nil, "loading"
	end
	local recipe = ns.RecipeData and ns.RecipeData[recipeID]
	if not recipe then
		return nil, "none"
	end
	local result = { skillLineID = recipe.skillLine, reagents = {} }
	if recipe.output then
		result.output = { itemID = recipe.output.itemID, quantity = recipe.output.quantity }
	else
		result.output = false
	end
	for _, reagent in ipairs(recipe.reagents or {}) do
		result.reagents[#result.reagents + 1] = { itemID = reagent.itemID, quantity = reagent.quantity }
	end
	return result
end

---@param recipeID integer
---@return SkillUpAPIRequirement?, SkillUpAPIReason?
function API.RecipeRequirement(recipeID)
	if not ns.db then
		return nil, "loading"
	end
	local recipe = ns.RecipeData and ns.RecipeData[recipeID]
	if not recipe then
		return nil, "none"
	end
	local training = ns.TrainingFor({ skillLine = recipe.skillLine }, recipeID)
	if training then
		return { skill = training[2], source = "trainer", trainerFee = training[1] }
	end
	local scroll = ns.RecipeScrolls and ns.RecipeScrolls[recipeID]
	if scroll then
		return { skill = scroll[2], source = "item", recipeItem = scroll[1] }
	end
	return nil, "none"
end

-- The four base skill bands the tooltip colours against, and the Working Overtime bonus in percentage points.
---@param recipeID integer
---@return SkillUpAPIRecipeSkill?, SkillUpAPIReason?
function API.RecipeSkill(recipeID)
	if not ns.db then
		return nil, "loading"
	end
	if not ns.RecipeData or not ns.RecipeData[recipeID] then
		return nil, "none"
	end
	local thresholds = ns.Model.Get(recipeID)
	if not thresholds then
		return nil, "none"
	end
	return {
		orange = thresholds[1],
		yellow = thresholds[2],
		green = thresholds[3],
		grey = thresholds[4],
		chanceBonus = ns.Model.ChanceBonus() * 100,
	}
end

-- An NPC a recipe's item comes from, as the tooltip names and colours it; nil for one the catalogue cannot name.
---@param npcID integer
---@return table?
local function SourceNPC(npcID)
	local npc = ns.Catalogue.NPC(npcID)
	return npc
		and {
			npcID = npcID,
			name = npc.name,
			zone = ns.NPCLocation(npcID).label,
			usable = ns.SourceFactionUsable(npc.side),
		}
end

---@param recipeID integer
---@return SkillUpAPIRecipeSources?, SkillUpAPIReason?
function API.RecipeSources(recipeID)
	if not ns.db then
		return nil, "loading"
	end
	local recipe = ns.RecipeData[recipeID]
	if not recipe then
		return nil, "none"
	end
	local C = ns.Catalogue
	if not C.EnsureProfession(recipe.skillLine) then
		return nil, "loading"
	end
	local source = C.Recipe(recipeID)
	if not source then
		return nil, "none"
	end
	---@type SkillUpAPIRecipeSources
	local result = { itemID = source.item, vendors = {}, quests = {}, drops = {}, world = source.world == true }
	for _, npcID in ipairs(source.vendors) do
		result.vendors[#result.vendors + 1] = SourceNPC(npcID)
	end
	for _, questID in ipairs(source.quests) do
		local quest = C.Quest(questID)
		if quest then
			result.quests[#result.quests + 1] = {
				questID = questID,
				title = quest.title,
				usable = ns.SourceFactionUsable(quest.side),
			}
		end
	end
	for _, drop in ipairs(source.drops) do
		local row = SourceNPC(drop[1])
		if row then
			row.chance = drop[2]
			result.drops[#result.drops + 1] = row
		end
	end
	return result
end

---@return string[]?, SkillUpAPIReason?
function API.Characters()
	if not ns.db then
		return nil, "loading"
	end
	local result = {}
	for key in pairs(ns.db.learned or {}) do
		result[#result + 1] = key
	end
	table.sort(result)
	return result
end

---@param characterKey string
---@param recipeID integer
---@return boolean?, SkillUpAPIReason?
function API.Knows(characterKey, recipeID)
	if not ns.db then
		return nil, "loading"
	end
	if type(characterKey) ~= "string" or type(recipeID) ~= "number" or not ns.RecipeData[recipeID] then
		return APIKit.Invalid()
	end
	return ns.db.learned[characterKey] and ns.db.learned[characterKey][recipeID] == true or false
end

---@type SkillUpPublicAddon
SkillUpForever = { API = API }
if (ForeverCore.APIKit.minor or 1) >= 2 then
	ForeverCore.APIKit.Publish("SkillUpForever", API)
end

ns.WhenEvent("ITEM_DATA_LOAD_RESULT", function(itemID, success)
	if success and waitingNames[itemID] and C_Item.GetItemNameByID(itemID) then
		return "names"
	end
end)
