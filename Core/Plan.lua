---@type string, SkillUpNamespace
local _, ns = ...

if ns.broken then
	return
end
local L = ns.L

-- The levelling plan: from a profession, the recipes this character knows, prices and trainer
-- data to the steps a player walks. Everything it returns is in base skill, the number the
-- Professions window shows, with trainer requirements resolved; the route page, the tracker, the
-- public API and the trainer window draw it without the modifier or the trainer tables.

local RANK_NAMES = { [75] = APPRENTICE, [150] = JOURNEYMAN, [225] = EXPERT, [300] = ARTISAN }
-- Each rank raises the cap by this much, so a rank is needed once the route passes cap - RANK_SPAN.
local RANK_SPAN = 75

-- The rank a skill cap belongs to, nil for a cap no trainer rank ends at.
---@param cap number
---@return string?
function ns.RankName(cap)
	return RANK_NAMES[cap]
end

-- What a rank's book is called: its item name, else "the Expert book" while the item loads.
---@param rank SkillUpRank
---@return string
function ns.RankBookName(rank)
	local name = rank.book and C_Item.GetItemNameByID(rank.book)
	if name then
		return name
	end
	if rank.book then
		C_Item.RequestLoadItemDataByID(rank.book)
	end
	return string.format(L["the %s book"], rank.name)
end

-- What a rank's quest is called: its QuestieDB title, else "the Artisan quest" (without Questie, or until it is read).
---@param rank SkillUpRank
---@return string
function ns.RankQuestName(rank)
	local quest = rank.quest and ns.Catalogue and ns.Catalogue.Quest(rank.quest)
	return quest and quest.title or string.format(L["the %s quest"], rank.name)
end

-- A rank's book already held (bags or bank, as ns.Have counts): only reading it is left, with nothing to buy.
---@param rank SkillUpRank
---@return boolean
function ns.RankHeld(rank)
	return rank.book ~= nil and ns.Have(rank.book) > 0
end

---@param rank SkillUpRank
---@return string
function ns.RankText(rank)
	if rank.book then
		local name = ns.RankBookName(rank)
		local held = ns.RankHeld(rank)
		if rank.level > UnitLevel("player") then
			local text = held and L["Read %s at %d (level %d)"] or L["Buy and read %s at %d (level %d)"]
			return string.format(text, name, rank.reqSkill, rank.level)
		end
		return string.format(held and L["Read %s at %d"] or L["Buy and read %s at %d"], name, rank.reqSkill)
	end
	if rank.quest then
		local name = ns.RankQuestName(rank)
		if rank.level > UnitLevel("player") then
			return string.format(L["Complete %s at %d (level %d)"], name, rank.reqSkill, rank.level)
		end
		return string.format(L["Complete %s at %d"], name, rank.reqSkill)
	end
	if rank.level > UnitLevel("player") then
		return string.format(L["Train %s at %d (level %d)"], rank.name, rank.reqSkill, rank.level)
	end
	return string.format(L["Train %s at %d"], rank.name, rank.reqSkill)
end

-- Levelled by gathering, not crafting: their few Forever recipes can't carry a route.
local GATHERING = { [182] = true, [356] = true, [393] = true } -- Herbalism, Fishing, Skinning

-- The player's professions a route can be planned for.
---@return table<integer, SkillUpProfession>
function ns.RouteProfessions()
	local professions = {}
	for skillLine, profession in pairs(ns.PlayerProfessions()) do
		if not GATHERING[skillLine] then
			professions[skillLine] = profession
		end
	end
	return professions
end

-- The ranks above the current cap, in order, and the highest cap they reach: a trainer's, else a book's
-- (Expert First Aid and Cooking), else a quest's your side can take (Artisan First Aid and Cooking). It stops
-- at a gap.
---@param profession SkillUpContext
---@return SkillUpRank[]
---@return number
local function NextRanks(profession)
	-- What a trainer was seen to charge for a rank, or a merchant for a book, wins over the bundled price.
	local seen = ns.db.trainerRanks[profession.skillLine] or {}
	local byCap = {}
	local quests = ns.RankQuests and ns.RankQuests[profession.skillLine] or {}
	local side = #quests > 0 and ns.PlayerSide and ns.PlayerSide()
	for _, rank in ipairs(quests) do
		local cap, quest, reqSkill, level, questSide = rank[1], rank[2], rank[3], rank[4], rank[5]
		---@cast cap number
		-- The generator already picked one quest a side for each rank.
		if questSide == side then
			byCap[cap] =
				{ name = RANK_NAMES[cap], cap = cap, fee = 0, reqSkill = reqSkill, level = level, quest = quest }
		end
	end
	for _, rank in ipairs(ns.RankBooks[profession.skillLine] or {}) do
		local cap, book = rank[1], rank[2]
		byCap[cap] = {
			name = RANK_NAMES[cap],
			cap = cap,
			fee = ns.db.vendor[book] or rank[3],
			reqSkill = rank[4],
			level = rank[5],
			book = book,
		}
	end
	for _, rank in ipairs(ns.TrainerRanks[profession.skillLine] or {}) do
		byCap[rank[1]] = {
			name = RANK_NAMES[rank[1]],
			cap = rank[1],
			fee = seen[rank[1]] or rank[2],
			reqSkill = rank[3],
			level = rank[4],
		}
	end
	local ranks, cap = {}, profession.max
	while byCap[cap + RANK_SPAN] and byCap[cap + RANK_SPAN].name do
		local rank = byCap[cap + RANK_SPAN]
		ranks[#ranks + 1] = rank
		cap = rank.cap
	end
	return ranks, cap
end

-- The caps a rank teaches, per skill line and side: bundled data, so made once a session.
---@type table<string, table<number, true>>
local rankCaps = {}

-- The highest cap NextRanks reaches, without building its ranks: every cached plan lookup asks for it.
---@param profession SkillUpContext
---@return number
local function RankCeiling(profession)
	local skillLine = profession.skillLine
	local quests = ns.RankQuests and ns.RankQuests[skillLine] or {}
	local side = #quests > 0 and ns.PlayerSide and ns.PlayerSide()
	local key = skillLine .. ":" .. tostring(side)
	local caps = rankCaps[key]
	if not caps then
		caps = {}
		for _, rank in ipairs(quests) do
			if rank[5] == side then
				caps[rank[1]] = true
			end
		end
		for _, rank in ipairs(ns.RankBooks[skillLine] or {}) do
			caps[rank[1]] = true
		end
		for _, rank in ipairs(ns.TrainerRanks[skillLine] or {}) do
			caps[rank[1]] = true
		end
		rankCaps[key] = caps
	end
	local cap = profession.max
	while caps[cap + RANK_SPAN] and RANK_NAMES[cap + RANK_SPAN] do
		cap = cap + RANK_SPAN
	end
	return cap
end

-- The chosen target in base skill, per profession; the trainer plans to it too.
-- A target already reached gives way to the default. Past the cap is fine up to
-- the last rank a trainer, book or quest teaches; the route takes those ranks on the way.
---@param profession SkillUpContext
---@return number
local function RouteTarget(profession)
	local saved = ns.db.routeTargets[profession.skillLine]
	local ceiling = RankCeiling(profession)
	return math.min(saved and saved > profession.base and saved or profession.base + 25, ceiling)
end

-- A recipe the player said "Not this recipe" to: no route crafts, trains or suggests it.
---@param recipeID integer
---@return boolean
local function Skipped(recipeID)
	return ns.IsSkipped ~= nil and ns.IsSkipped(recipeID)
end

-- The bundled recipes of each skill line, in the order pairs gives them: built once, as the bundle never
-- changes after load, so a replan walks its own profession instead of every recipe.
---@type table<integer, integer[]>?
local bySkillLine
---@type table?
local indexedData

---@param skillLine integer
---@return integer[]
local function RecipesOf(skillLine)
	if indexedData ~= ns.RecipeData or not bySkillLine then
		bySkillLine, indexedData = {}, ns.RecipeData
		for recipeID, recipe in pairs(ns.RecipeData) do
			local list = bySkillLine[recipe.skillLine]
			if not list then
				list = {}
				bySkillLine[recipe.skillLine] = list
			end
			list[#list + 1] = recipeID
		end
	end
	return bySkillLine[skillLine] or {}
end

-- One craft's reagent cost, what it makes and its net: the price module's answer. A headless client
-- without that module knows only the net, which stands in for both.
---@param recipeID integer
---@return number?, SkillUpValue?, number?
local function RecipeCosts(recipeID)
	if ns.CraftCost then
		return ns.CraftCost(recipeID)
	end
	local net = ns.NetCost(recipeID)
	return net, nil, net
end

-- What a step's crafts cost, by the same money the route page shows: every craft at the recipe's net,
-- so a sale value lowers every craft, not only the first (#466). Time stays in the planner's own cost:
-- the route page's money is what the player pays.
---@param recipeID integer
---@param crafts number
---@return number
function ns.StepCost(recipeID, crafts)
	local _, _, netCost = RecipeCosts(recipeID)
	return ns.Model.StepCost(netCost, nil, crafts) or 0
end

-- What the planner works from: the recipes this character knows, for any of its professions, from
-- the bundled recipe data plus the learned record, so the profession needn't be open. `known` adds
-- recipes the caller knows are learned. Skills here are effective (base + bonus), as the
-- thresholds are.
---@param profession SkillUpContext
---@param target number Base skill.
---@param known table<integer, boolean>?
---@return SkillUpSnapshot
local function Snapshot(profession, target, known)
	local recipes = {}
	for _, recipeID in ipairs(RecipesOf(profession.skillLine)) do
		local thresholds = not Skipped(recipeID) and ns.Model.Get(recipeID)
		if thresholds and (known and known[recipeID] or ns.IsLearned(recipeID)) then
			local reagentCost, _, netCost = RecipeCosts(recipeID)
			recipes[#recipes + 1] = {
				recipeID = recipeID,
				thresholds = thresholds,
				netCost = netCost,
				reagentCost = reagentCost,
				preference = ns.PinPreference(recipeID),
				skillUps = ns.RecipeSkillUps and ns.RecipeSkillUps(recipeID) or 1,
			}
		end
	end
	-- Between two recipes that tie on cost and chance, the planner takes one whose product is a buff this level
	-- can use (#357).
	return {
		skill = profession.skill,
		target = target + profession.modifier,
		recipes = recipes,
		buffs = ns.UsableBuffs(UnitLevel("player") or 0),
	}
end

-- { fee, required base skill }: what a trainer was seen to charge, else the base fee;
-- nil for a recipe no trainer teaches.
---@param profession SkillUpContext
---@param recipeID integer
---@return number[]?
function ns.TrainingFor(profession, recipeID)
	local seen = ns.db.trainer[profession.skillLine]
	return seen and seen[recipeID] or ns.TrainerFees[recipeID]
end

-- { fee, required base skill }: a recipe's scroll sold by a vendor, whose price is the fee, nil for a
-- recipe with no such scroll. A price seen at a merchant proves the vendor sells it; else the catalogue
-- must name a vendor, so a drop nobody sells is never planned as a purchase (#358).
---@param recipeID integer
---@return number[]?
local function VendorTraining(recipeID)
	local scroll = ns.RecipeScrolls and ns.RecipeScrolls[recipeID]
	local item = scroll and scroll[1]
	if not item then
		return nil
	end
	---@type number?
	local fee = ns.db.vendor[item] or (ns.VendorPrices and ns.VendorPrices[item])
	local source = ns.Catalogue and type(ns.Catalogue.Recipe) == "function" and ns.Catalogue.Recipe(recipeID)
	if not fee and not (source and #source.vendors > 0) then
		return nil
	end
	if not fee then
		local price = ns.Price(item)
		fee = price and price.source == "vendor" and price.copper or nil
	end
	if not fee then
		return nil
	end
	return { fee, scroll[2] }
end

-- Trainer-taught or vendor-sold recipes of this profession not yet learned that could skill up
-- somewhere between here and the target. Nothing is used before the trainer would
-- teach it: the thresholds' first value is where a recipe turns orange, not where
-- it's taught.
---@param profession SkillUpContext
---@param snapshot SkillUpSnapshot
---@return SkillUpService[]
local function Trainable(profession, snapshot)
	local services = {}
	for _, recipeID in ipairs(RecipesOf(profession.skillLine)) do
		local training = ns.TrainingFor(profession, recipeID) or VendorTraining(recipeID)
		local t = training and not ns.IsLearned(recipeID) and not Skipped(recipeID) and ns.Model.Get(recipeID)
		if training and t then
			local taught = { math.max(t[1], training[2] + profession.modifier), t[2], t[3], t[4] }
			if taught[1] <= snapshot.target and t[4] > snapshot.skill then
				local reagentCost, _, netCost = RecipeCosts(recipeID)
				services[#services + 1] = {
					recipeID = recipeID,
					thresholds = taught,
					netCost = netCost,
					reagentCost = reagentCost,
					preference = ns.PinPreference(recipeID),
					fee = training[1],
					skillUps = ns.RecipeSkillUps and ns.RecipeSkillUps(recipeID) or 1,
				}
			end
		end
	end
	table.sort(services, function(a, b)
		return a.recipeID < b.recipeID
	end)
	return services
end

local BAND_NAMES = { "orange", "yellow", "green", "grey" }

-- Where the bundle says a recipe is learned: a trainer's service or the pattern or recipe item that
-- teaches it, and the effective skill (base plus the profession's modifier) it asks. Nil for anything
-- else, including a quest, which only the catalogue knows.
---@param profession SkillUpContext
---@param recipeID integer
---@return SkillUpLearnSource?
function ns.LearnSource(profession, recipeID)
	local training = ns.TrainingFor(profession, recipeID)
	if training then
		return { kind = "trainer", skill = training[2] + profession.modifier }
	end
	local scroll = ns.RecipeScrolls[recipeID]
	if scroll then
		return { kind = "scroll", skill = scroll[2] + profession.modifier, itemID = scroll[1] }
	end
end

-- "Trainer 60" or "Recipe item 80": where a recipe is learned, as its row and tooltip say it.
---@param source SkillUpLearnSource|SkillUpUnlearnedRecipe
---@return string
function ns.LearnSourceText(source)
	local text = source.kind == "trainer" and L["Trainer"] or L["Recipe item"]
	if source.skill > 0 then
		text = string.format(L["%s %d"], text, source.skill)
	end
	return text
end

-- The skill where a recipe can first be learned: what a trainer asks, else the requirement of the
-- pattern or recipe item that teaches it, else the catalogue's scroll skill, else nothing the data
-- knows. The client's own orange is not a requirement: for many recipes it is left at 1.
---@param profession SkillUpContext
---@param recipeID integer
---@return number
function ns.LearnSkill(profession, recipeID)
	local learned = ns.LearnSource(profession, recipeID)
	if learned then
		return learned.skill
	end
	local source = ns.Catalogue.Recipe(recipeID)
	if source and source.skill then
		return source.skill + profession.modifier
	end
	return 0
end

-- A recipe's thresholds with the range starting where it can first be learned, which is the start a player
-- sees: the client leaves most recipe starts at its placeholder 1 (#519). The bands above the start stay as the
-- bundle has them, and the same table comes back when the data already starts there or nothing places the recipe.
---@param profession SkillUpContext?
---@param recipeID integer
---@param thresholds number[]?
---@return number[]?
function ns.RangeThresholds(profession, recipeID, thresholds)
	local t = thresholds or ns.Model.Get(recipeID)
	if not t or not profession then
		return t
	end
	local learnAt = ns.LearnSkill(profession, recipeID)
	if learnAt <= t[1] then
		return t
	end
	return { learnAt, t[2], t[3], t[4] }
end

-- The recipes of this profession the character has not learned that the bundle can place: a trainer's
-- or a recipe item's, with the skill each asks. Sorted by that skill, so the ones this character can
-- learn now come first, then what is still ahead; a trainer's before a recipe item's at the same skill.
---@param profession SkillUpContext
---@return SkillUpUnlearnedRecipe[]
function ns.UnlearnedRecipes(profession)
	local found = {}
	for recipeID, recipe in pairs(ns.RecipeData) do
		if recipe.skillLine == profession.skillLine and not ns.IsLearned(recipeID) then
			local source = ns.LearnSource(profession, recipeID)
			if source then
				local name = C_Spell.GetSpellName(recipeID)
				local thresholds = ns.Model.Get(recipeID)
				if name and thresholds then
					found[#found + 1] = {
						recipeID = recipeID,
						name = name,
						kind = source.kind,
						skill = source.skill,
						itemID = source.itemID,
						thresholds = thresholds,
					}
				end
			end
		end
	end
	table.sort(found, function(a, b)
		if a.skill ~= b.skill then
			return a.skill < b.skill
		elseif a.kind ~= b.kind then
			return a.kind == "trainer"
		end
		local order = strcmputf8i(a.name, b.name)
		return order < 0 or (order == 0 and a.recipeID < b.recipeID)
	end)
	return found
end

-- Each difficulty band a recipe still has and the skill it starts at, from where the recipe can
-- be learned. Empty without thresholds.
---@param profession SkillUpContext
---@param recipeID integer
---@return SkillUpBand[]
function ns.RecipeBands(profession, recipeID)
	local bands = {}
	local t = ns.Model.Get(recipeID)
	if not t then
		return bands
	end
	local learnAt = ns.LearnSkill(profession, recipeID)
	for i, name in ipairs(BAND_NAMES) do
		local from = math.max(t[i], learnAt)
		if i == #BAND_NAMES or from < t[i + 1] then
			bands[#bands + 1] = { color = name, from = from }
		end
	end
	return bands
end

-- A segment that crafts past the rank's cap from below the skill the trainer wants
-- for it is split there, so the rank is trained between its halves.
---@param segments SkillUpSegment[]
---@param rank SkillUpRank
---@param modifier number
local function SplitAtRank(segments, rank, modifier)
	local at = rank.reqSkill + modifier
	for index, segment in ipairs(segments) do
		if segment.fromSkill < at and segment.toSkill - modifier > rank.cap - RANK_SPAN then
			local thresholds = ns.Model.Get(segment.recipeID)
			---@cast thresholds number[]
			local ups = ns.RecipeSkillUps and ns.RecipeSkillUps(segment.recipeID) or 1
			-- Train no earlier than the requirement, and split on a whole number of the points a craft
			-- grants, so neither half is left with a craft that gives fewer points than the recipe does.
			local splitAt = segment.fromSkill + math.ceil((at - segment.fromSkill) / ups) * ups
			if splitAt < segment.toSkill then
				local rest = {
					recipeID = segment.recipeID,
					fromSkill = splitAt,
					toSkill = segment.toSkill,
					skillUps = segment.skillUps,
				}
				rest.crafts = ns.Model.CoveredCrafts(thresholds, splitAt, segment.toSkill, ups)
				segment.toSkill = splitAt
				segment.crafts = ns.Model.CoveredCrafts(thresholds, segment.fromSkill, splitAt, ups)
				table.insert(segments, index + 1, rest)
				return
			end
		end
	end
end

-- How deep a reagent is followed into the recipes that make it before it is left to buy.
local MAX_SUB_DEPTH = 3

-- The sub-crafts a recipe's reagents need, deepest first, and the raw reagents left once every
-- reagent a learned recipe makes for less than it costs to buy is replaced by what it is made from.
-- A reagent already being made higher up is left raw, so a cycle cannot recurse.
---@param recipeID integer
---@param crafts number
---@param depth integer
---@param making table<integer, true>
---@return SkillUpSubCraft[]
---@return {itemID: integer, count: number}[]
local function Expand(recipeID, crafts, depth, making)
	local subcrafts, raw = {}, {}
	for _, reagent in ipairs((ns.Reagents and ns.Reagents(recipeID)) or {}) do
		local need = reagent.quantity * crafts
		local maker = depth < MAX_SUB_DEPTH
			and not making[reagent.itemID]
			and ns.SubCraft
			and ns.SubCraft(reagent.itemID)
		if maker and maker.quantity and maker.quantity > 0 then
			local batches = math.ceil(need / maker.quantity)
			making[reagent.itemID] = true
			local childSubcrafts, childRaw = Expand(maker.recipeID, batches, depth + 1, making)
			making[reagent.itemID] = nil
			for _, sub in ipairs(childSubcrafts) do
				subcrafts[#subcrafts + 1] = sub
			end
			subcrafts[#subcrafts + 1] = {
				recipeID = maker.recipeID,
				itemID = reagent.itemID,
				crafts = batches,
				made = batches * maker.quantity,
			}
			for _, item in ipairs(childRaw) do
				raw[#raw + 1] = item
			end
		else
			raw[#raw + 1] = { itemID = reagent.itemID, count = need }
		end
	end
	return subcrafts, raw
end

-- Public, price-aware bill of materials for other addons: one raw entry per item, in first-seen order.
-- Unknown recipes and a craft count that is not a whole number above zero return nil.
---@param recipeID integer
---@param crafts integer
---@return SkillUpSubCraft[]?, {itemID: integer, count: number}[]?
function ns.RecipeMaterials(recipeID, crafts)
	if
		not ns.RecipeData[recipeID]
		or type(crafts) ~= "number"
		or crafts < 1
		or crafts == math.huge
		or crafts % 1 ~= 0
	then
		return nil, nil
	end
	local subcrafts, raw = Expand(recipeID, crafts, 0, {})
	local merged, byItem = {}, {}
	for _, item in ipairs(raw) do
		local entry = byItem[item.itemID]
		if entry then
			entry.count = entry.count + item.count
		else
			entry = { itemID = item.itemID, count = item.count }
			byItem[item.itemID] = entry
			merged[#merged + 1] = entry
		end
	end
	return subcrafts, merged
end

-- The route's money split: what its reagents still cost to buy after the bags, the training and rank fees
-- still to pay, what its crafts sell for, and how many needed reagents no price covers. A held book is not
-- bought again, and an unpriced reagent is counted rather than dropped from a lower total (#567).
---@param plan SkillUpPlan
---@return { buy: number, fees: number, sells: number, unknown: integer }
function ns.PlanMoney(plan)
	local count = {}
	for _, craft in ipairs(plan.crafts or {}) do
		local _, craftRaw = Expand(craft.recipeID, craft.crafts, 0, {})
		for _, item in ipairs(craftRaw) do
			count[item.itemID] = (count[item.itemID] or 0) + item.count
		end
	end
	local buy, unknown = 0, 0
	for itemID, need in pairs(count) do
		local short = need - math.min(ns.Have(itemID), need)
		if short > 0 then
			local each = ns.ObtainCost and ns.ObtainCost(itemID)
			if not each then
				local price = ns.Price and ns.Price(itemID)
				each = price and not price.unknown and price.copper or nil
			end
			if each then
				buy = buy + each * short
			else
				unknown = unknown + 1
			end
		end
	end
	local fees = 0
	for _, training in ipairs(plan.training or {}) do
		fees = fees + training.fee
	end
	for _, rank in ipairs(plan.ranks or {}) do
		if not ns.RankHeld(rank) then
			fees = fees + rank.fee
		end
	end
	local sells = 0
	for _, craft in ipairs(plan.crafts or {}) do
		local _, value = RecipeCosts(craft.recipeID)
		if value then
			sells = sells + value.copper * craft.crafts
		end
	end
	return { buy = buy, fees = fees, sells = sells, unknown = unknown }
end

-- The order the plan is walked in: each rank once the route passes the cap below it, a recipe's
-- training just before its first craft, the sub-crafts that make its reagents, then the craft.
---@param plan SkillUpPlan
---@return SkillUpRouteStep[]
local function Walk(plan)
	local steps, nextRank = {}, 1
	local training = {}
	for _, step in ipairs(plan.training) do
		training[step.recipeID] = step
	end
	for _, craft in ipairs(plan.crafts) do
		local rank = plan.ranks[nextRank]
		while rank and craft.to > rank.cap - RANK_SPAN do
			steps[#steps + 1] = { rank = rank }
			nextRank = nextRank + 1
			rank = plan.ranks[nextRank]
		end
		local step = training[craft.recipeID]
		if step then
			training[craft.recipeID] = nil
			steps[#steps + 1] = { training = step }
		end
		for _, sub in ipairs(craft.subcrafts or {}) do
			steps[#steps + 1] = { subcraft = sub }
		end
		steps[#steps + 1] = { craft = craft }
	end
	return steps
end

-- The planner's route, which is in effective skill, as the plan a player reads.
---@param profession SkillUpProfession
---@param target number
---@param route SkillUpTrainedRoute
---@return SkillUpPlan
local function Finish(profession, target, route)
	local m = profession.modifier
	local cost = route.trainingCost
	-- Each rank is needed once the route passes the cap below it: where it gets to,
	-- which falls short of the target when the known recipes run out.
	local ranks = {}
	for _, rank in ipairs(NextRanks(profession)) do
		if route.reachedSkill - m > rank.cap - RANK_SPAN then
			ranks[#ranks + 1] = rank
			cost = cost + rank.fee
			SplitAtRank(route.segments, rank, m)
		end
	end
	local crafts = {}
	for index, segment in ipairs(route.segments) do
		local subcrafts = Expand(segment.recipeID, segment.crafts, 0, {})
		crafts[index] = {
			recipeID = segment.recipeID,
			from = segment.fromSkill - m,
			to = segment.toSkill - m,
			crafts = segment.crafts,
			points = segment.toSkill - segment.fromSkill,
			skillUps = segment.skillUps or 1,
			color = ns.Model.Color(ns.Model.Get(segment.recipeID), segment.fromSkill),
			station = ns.RecipeStation and ns.RecipeStation(segment.recipeID) or nil,
			subcrafts = subcrafts,
		}
	end
	local training = {}
	for index, step in ipairs(route.training) do
		local reqSkill = ns.LearnSkill(profession, step.recipeID) - m
		-- A recipe no trainer teaches comes from its scroll, so the step buys that instead (#358).
		local scroll = not ns.TrainingFor(profession, step.recipeID)
			and ns.RecipeScrolls
			and ns.RecipeScrolls[step.recipeID]
			and ns.RecipeScrolls[step.recipeID][1]
		training[index] = {
			recipeID = step.recipeID,
			fee = step.fee,
			usedAt = step.atSkill - m,
			reqSkill = reqSkill,
			-- A trainer or scroll teaches recipes needing less than the cap they train to.
			cap = reqSkill + 1,
			scroll = scroll or nil,
		}
	end
	-- What the steps ask for, after any rank split them: the crafts and their cost.
	local crafting = 0
	for _, craft in ipairs(crafts) do
		crafting = crafting + ns.StepCost(craft.recipeID, craft.crafts)
	end
	---@type SkillUpPlan
	local plan = {
		profession = profession,
		target = target,
		reached = route.reachedSkill - m,
		crafts = crafts,
		training = training,
		ranks = ranks,
		steps = {},
		bands = {},
		cost = crafting + cost,
		unpriced = route.excluded.unpriced,
		unpricedRecipes = route.excluded.recipes,
		stopReason = route.stopReason,
	}
	plan.steps = Walk(plan)
	-- Each step's skill band, from the cap it starts under and the caps its ranks raise: the route page groups
	-- steps by these without working the ranks out again (#574).
	local cap = profession.max
	if cap > 0 then
		plan.bands[1] = { name = ns.RankName(cap) or tostring(cap), from = math.max(cap - RANK_SPAN, 0), cap = cap }
	end
	for _, rank in ipairs(ranks) do
		plan.bands[#plan.bands + 1] = { name = rank.name, from = math.max(rank.cap - RANK_SPAN, 0), cap = rank.cap }
	end
	local bandIndex = 1
	for _, step in ipairs(plan.steps) do
		if step.rank then
			bandIndex = bandIndex + 1
		end
		step.band = plan.bands[bandIndex] or plan.bands[#plan.bands]
	end
	return plan
end

-- Whether committing a route target would change it: an entered value equal to the stored target is a no-op,
-- so leaving the level box doesn't re-plan the route for nothing (#189).
---@param skillLine integer
---@param value number
---@return boolean
function ns.TargetChanged(skillLine, value)
	return ns.db.routeTargets[skillLine] ~= value
end

-- Planning with training re-plans once per candidate, so plans are kept until
-- prices, recipes, fees or targets change; skill is part of the key. A profession keeps its last
-- few targets' plans, so going back to a target already planned doesn't plan it again (#189).
local PLAN_CACHE_SIZE = 8
---@type table<integer, { plans: table<string, SkillUpPlan>, order: string[] }>
local plans = {}

-- The route each profession is following: the plan last handed out, the key it was planned for, and the bag
-- change it was last checked against. Prices, bags, recipes and fees moving replan into a fresh route, but the
-- player is shopping for this one, so while every step of it can still be walked its recipes and their order are
-- kept (#621). A key the player asked for (a new target, the collect switch, a level) is another route and is
-- committed in its place.
---@type table<integer, { key: string, plan: SkillUpPlan, bags: integer }>
local committed = {}

ns.WhenStale("plans", function()
	plans = {}
end)

ns.WhenStale("replan", function()
	committed = {}
end)

-- A bag change never chooses a route's recipes, but it can take away what a step still needs. Bags move many
-- times a frame while looting, so the route being followed is checked when something next asks for it, once per
-- bag change however many asks follow it.
local bagEpoch = 0

ns.WhenStale("bags", function()
	bagEpoch = bagEpoch + 1
end)

-- Every reagent a route's crafts use is in the bags or has a price: what a bag change can take away.
---@param plan SkillUpPlan
---@return boolean
local function Affordable(plan)
	for _, craft in ipairs(plan.crafts) do
		local _, raw = Expand(craft.recipeID, craft.crafts, 0, {})
		for _, item in ipairs(raw) do
			local short = item.count - math.min(ns.Have(item.itemID), item.count)
			if short > 0 and not ns.Price(item.itemID) then
				return false
			end
		end
	end
	return true
end

-- Whether every step of a route can still be walked: each craft's recipe is known, or trained by a step of the
-- route, still skills up from where the step starts, and every reagent it uses is in the bags or has a price.
---@param plan SkillUpPlan
---@return boolean
function ns.RouteFollowable(plan)
	local profession = plan.profession
	local modifier = profession.modifier
	local trained = {}
	for _, training in ipairs(plan.training) do
		-- A training step the player already took is done, a recipe nobody still teaches can't be learned, and
		-- one taught later than the route crafts it cannot be trained where the route puts it.
		if
			ns.IsLearned(training.recipeID)
			or not (ns.TrainingFor(profession, training.recipeID) or VendorTraining(training.recipeID))
			or ns.LearnSkill(profession, training.recipeID) > training.usedAt + modifier
		then
			return false
		end
		trained[training.recipeID] = true
	end
	for _, craft in ipairs(plan.crafts) do
		local recipeID = craft.recipeID
		if not (ns.IsLearned(recipeID) or trained[recipeID]) or Skipped(recipeID) then
			return false
		end
		local thresholds = ns.Model.Get(recipeID)
		local ups = ns.RecipeSkillUps and ns.RecipeSkillUps(recipeID) or 1
		if not (thresholds and ns.Model.Gain(thresholds, craft.from + modifier, ups, craft.to - craft.from) > 0) then
			return false
		end
	end
	return Affordable(plan)
end

-- Whether two plans walk the same recipes in the same order: the crafts, the training on the way and the ranks
-- it takes. Money, counts and colours are not part of it.
---@param a SkillUpPlan
---@param b SkillUpPlan
---@return boolean
local function SameSteps(a, b)
	if #a.crafts ~= #b.crafts or #a.training ~= #b.training or #a.ranks ~= #b.ranks then
		return false
	end
	for index, craft in ipairs(a.crafts) do
		if craft.recipeID ~= b.crafts[index].recipeID then
			return false
		end
	end
	for index, step in ipairs(a.training) do
		if step.recipeID ~= b.training[index].recipeID then
			return false
		end
	end
	for index, rank in ipairs(a.ranks) do
		if rank.cap ~= b.ranks[index].cap then
			return false
		end
	end
	return true
end

-- Keeps a profession's route, in place so a cached ask writes no table.
---@param skillLine integer
---@param key string
---@param plan SkillUpPlan
local function Commit(skillLine, key, plan)
	local entry = committed[skillLine]
	if entry then
		entry.key, entry.plan, entry.bags = key, plan, bagEpoch
	else
		committed[skillLine] = { key = key, plan = plan, bags = bagEpoch }
	end
end

-- The route a player is following, planned again from today's inputs while keeping its own steps: the same
-- recipes, in the same order, over the same skills, with today's fees, counts, colours and training skills.
---@param profession SkillUpProfession
---@param target number
---@param plan SkillUpPlan
---@param fresh SkillUpPlan
---@return SkillUpPlan
local function Rebuild(profession, target, plan, fresh)
	local modifier = profession.modifier
	---@type SkillUpTrainedRoute
	local route = {
		segments = {},
		-- The steps keep the skills they were planned over; Finish reads no expected cost.
		expectedCost = 0,
		training = {},
		trainingCost = 0,
		reachedSkill = plan.reached + modifier,
		excluded = { unpriced = fresh.unpriced, recipes = fresh.unpricedRecipes },
		stopReason = plan.stopReason,
	}
	for index, craft in ipairs(plan.crafts) do
		local thresholds = ns.Model.Get(craft.recipeID)
		---@cast thresholds number[]
		local ups = ns.RecipeSkillUps and ns.RecipeSkillUps(craft.recipeID) or 1
		route.segments[index] = {
			recipeID = craft.recipeID,
			fromSkill = craft.from + modifier,
			toSkill = craft.to + modifier,
			skillUps = ups,
			crafts = ns.Model.CoveredCrafts(thresholds, craft.from + modifier, craft.to + modifier, ups),
		}
	end
	for index, step in ipairs(plan.training) do
		local training = ns.TrainingFor(profession, step.recipeID) or VendorTraining(step.recipeID)
		---@cast training number[]
		route.training[index] = { recipeID = step.recipeID, fee = training[1], atSkill = step.usedAt + modifier }
		route.trainingCost = route.trainingCost + training[1]
	end
	return Finish(profession, target, route)
end

-- The cheapest way to the target from the recipes this character knows, with whatever training
-- pays for itself and the ranks it passes.
---@param profession SkillUpProfession
---@return SkillUpPlan
function ns.PlanRoute(profession)
	local target = RouteTarget(profession)
	-- The collect mode is part of the key: a switch that is on prices the reagents this character could gather,
	-- so a plan made under the other mode is a different route (#190). The level is too: a plan made at another
	-- level may prefer a buff that level could not use (#357).
	local level = UnitLevel("player") or 0
	local key =
		table.concat({ profession.skill, profession.modifier, profession.max, target, ns.CollectMode(), level }, ":")
	local cache = plans[profession.skillLine]
	if not cache then
		cache = { plans = {}, order = {} }
		plans[profession.skillLine] = cache
	end
	-- The route being followed is checked against the bags here, once per bag change: a route a step can no
	-- longer afford to craft is planned afresh, any other bag change keeps it (#621).
	---@type { key: string, plan: SkillUpPlan, bags: integer }?
	local kept = committed[profession.skillLine]
	if kept and kept.bags ~= bagEpoch then
		kept.bags = bagEpoch
		if not Affordable(kept.plan) then
			cache.plans[kept.key] = nil
			committed[profession.skillLine] = nil
			kept = nil
		end
	end
	local cached = cache.plans[key]
	if cached then
		cached.profession = profession
		local entry = committed[profession.skillLine]
		if not entry or entry.plan ~= cached then
			Commit(profession.skillLine, key, cached)
		end
		return cached
	end
	local snapshot = Snapshot(profession, target)
	local plan = Finish(profession, target, ns.Model.PlanWithTraining(snapshot, Trainable(profession, snapshot)))
	if
		kept
		and kept.key == key
		and #kept.plan.crafts > 0
		and not SameSteps(kept.plan, plan)
		and ns.RouteFollowable(kept.plan)
	then
		-- The player is shopping for this route: today's prices, fees and recipe data are not a reason to swap
		-- the recipes they came for, only a route that can no longer be walked is (#621).
		plan = Rebuild(profession, target, kept.plan, plan)
	end
	Commit(profession.skillLine, key, plan)
	cache.plans[key] = plan
	cache.order[#cache.order + 1] = key
	if #cache.order > PLAN_CACHE_SIZE then
		local oldest = table.remove(cache.order, 1)
		cache.plans[oldest] = nil
	end
	return plan
end

-- Which of a trainer's offers to train next on the way to the target, nil when none helps.
-- `known` are recipes the trainer shows as learned, which the learned record may not have yet.
---@param profession SkillUpContext
---@param known table<integer, boolean>
---@param offers {recipeID: integer, fee: number}[]
---@return integer?
function ns.BestTraining(profession, known, offers)
	if profession.capped then
		return nil
	end
	local services = {}
	for _, offer in ipairs(offers) do
		local thresholds = ns.Model.Get(offer.recipeID)
		if thresholds and not ns.IsLearned(offer.recipeID) and not Skipped(offer.recipeID) then
			local reagentCost, _, netCost = RecipeCosts(offer.recipeID)
			services[#services + 1] = {
				recipeID = offer.recipeID,
				thresholds = {
					math.max(thresholds[1], ns.LearnSkill(profession, offer.recipeID)),
					thresholds[2],
					thresholds[3],
					thresholds[4],
				},
				netCost = netCost,
				reagentCost = reagentCost,
				preference = ns.PinPreference(offer.recipeID),
				skillUps = ns.RecipeSkillUps and ns.RecipeSkillUps(offer.recipeID) or 1,
				fee = offer.fee,
			}
		end
	end
	table.sort(services, function(a, b)
		return a.recipeID < b.recipeID
	end)
	local best = ns.Model.RecommendTraining(Snapshot(profession, RouteTarget(profession), known), services)
	return best and best.recipeID or nil
end

-- Everything the plan's crafts use, as totals: what you have is compared live, so the
-- list stays right as you buy, craft or bank things.
---@param plan SkillUpPlan
---@return SkillUpNeededItem[]
function ns.RouteReagents(plan)
	-- The raw reagents are worked out from the recipes as they stand now, so a bought or gathered
	-- source in the settings shows without rebuilding the plan.
	local raw = {}
	for _, craft in ipairs(plan.crafts) do
		local _, craftRaw = Expand(craft.recipeID, craft.crafts, 0, {})
		for _, item in ipairs(craftRaw) do
			raw[#raw + 1] = item
		end
	end
	local list = ns.Model.BucketItems(raw, ns.PriceSource)
	local items = {}
	for _, source in ipairs(ns.Model.SHOPPING_SOURCES) do
		for _, item in ipairs(list[source]) do
			items[#items + 1] = {
				itemID = item.itemID,
				need = item.count,
				source = source,
				limited = source == "vendor" and ns.IsLimitedStock ~= nil and ns.IsLimitedStock(item.itemID) or nil,
			}
		end
	end
	-- A carried tool the route needs goes in once, after the reagents, so its place is stable.
	for _, itemID in ipairs(ns.MissingToolItems and ns.MissingToolItems(plan) or {}) do
		items[#items + 1] = { itemID = itemID, need = 1, source = ns.Model.ShoppingSource(ns.PriceSource(itemID)) }
	end
	return items
end

-- Reagents with no price among the known recipes the plan left out for it.
---@param plan SkillUpPlan
---@return integer[]
function ns.UnpricedReagents(plan)
	local seen, items = {}, {}
	for _, recipeID in ipairs(plan.unpricedRecipes) do
		for _, reagent in ipairs(ns.Reagents(recipeID) or {}) do
			if not seen[reagent.itemID] and not ns.Price(reagent.itemID) then
				seen[reagent.itemID] = true
				items[#items + 1] = reagent.itemID
			end
		end
	end
	table.sort(items)
	return items
end

-- The reagent a route leans on hardest, and how much of the route's reagent units it is. A missing reagent
-- price is what leaves a route sitting on one low-tier pattern: the higher-tier recipes that would spread it
-- out are left out, so its totals describe a chain nobody farms (#394).
---@param plan SkillUpPlan
---@return { itemID: integer, need: integer, share: number }?
function ns.DominantReagent(plan)
	local total, top, topNeed = 0, nil, 0
	for _, item in ipairs(ns.RouteReagents(plan)) do
		total = total + item.need
		if item.need > topNeed then
			top, topNeed = item.itemID, item.need
		end
	end
	if total == 0 then
		return nil
	end
	return { itemID = top, need = topNeed, share = topNeed / total }
end

-- A one-line warning for a route that is mostly one reagent while recipes were left out for want of a price;
-- nil when the route is spread out or nothing was left out.
---@param plan SkillUpPlan
---@return { itemID: integer, need: integer, recipes: integer }?
function ns.RouteNotice(plan)
	if plan.unpriced <= 0 or #plan.crafts == 0 then
		return nil
	end
	local dominant = ns.DominantReagent(plan)
	if not dominant or dominant.share < 0.5 then
		return nil
	end
	return { itemID = dominant.itemID, need = dominant.need, recipes = plan.unpriced }
end

-- Why a plan has nothing to craft, as the page and the tracker say it; nil when it has.
---@param plan SkillUpPlan
---@return string?
function ns.RouteBlocked(plan)
	if #plan.crafts > 0 then
		return nil
	elseif plan.profession.capped and #plan.ranks == 0 then
		return string.format(L["At the %d cap: no trainer teaches the next rank."], plan.profession.max)
	elseif plan.unpriced > 0 then
		-- An auction addon knows only what it has scanned, so installing it isn't enough.
		local without = L["These reagents have no vendor price. Auction prices need Auctionator or TradeSkillMaster."]
		local with = L["Auctionator hasn't seen these reagents yet: scan the auction house with it to price them."]
		if ns.HasTradeSkillMaster() and not ns.HasAuctionator() then
			return L["TradeSkillMaster has no price for these reagents: update its AuctionDB with the TSM desktop app."]
		end
		return ns.HasAuctionator() and with or without
	elseif plan.stopReason == "no_recipe" then
		return string.format(L["Nothing you know skills up past %d."], plan.reached)
	end
end

-- The first reagent a step is short of, with how many more it needs.
---@param recipeID integer
---@param crafts number
---@return {itemID: integer, count: integer}?
local function MissingReagent(recipeID, crafts)
	for _, reagent in ipairs(ns.Reagents(recipeID) or {}) do
		local need = reagent.quantity * crafts
		local have = ns.Have(reagent.itemID)
		if have < need then
			return { itemID = reagent.itemID, count = need - have }
		end
	end
end

-- The plan's first craft, as many times as it needs and the bags allow, with
-- its label; or why it can't be crafted. The profession must be the open one.
---@param plan SkillUpPlan
---@return SkillUpCraft
function ns.NextCraft(plan)
	local profession, craft = plan.profession, plan.crafts[1]
	if not craft then
		return { text = L["Craft next"], reason = L["Nothing to craft on this route."] }
	elseif ns.OpenSkillLine() ~= profession.skillLine then
		return { text = L["Craft next"], reason = string.format(L["Open %s to craft from here."], profession.name) }
	elseif profession.capped and plan.ranks[1] then
		local rank = plan.ranks[1]
		local reason = rank.book and string.format(L["Read %s first: you're at your cap."], ns.RankBookName(rank))
			or rank.quest and string.format(L["Complete %s first: you're at your cap."], ns.RankQuestName(rank))
			or string.format(L["Train %s first: you're at your cap."], rank.name)
		return { text = L["Craft next"], reason = reason }
	end
	local recipeID = craft.recipeID
	local name = C_Spell.GetSpellName(recipeID) or string.format(L["recipe %d"], recipeID)
	if not ns.IsLearned(recipeID) then
		return { text = L["Craft next"], reason = string.format(L["Train %s first."], name) }
	end
	-- A tool the step or a sub-craft needs and the bags don't hold stops the craft.
	local tool = ns.MissingTool and ns.MissingTool(recipeID)
	if not tool and ns.MissingTool then
		for _, sub in ipairs(craft.subcrafts or {}) do
			tool = ns.MissingTool(sub.recipeID)
			if tool then
				break
			end
		end
	end
	if tool then
		return { text = L["Craft next"], reason = string.format(L["Need a %s in your bags."], tool.name) }
	end
	-- Past the cap a craft gives no skill-up until the next rank is trained.
	local crafts, m = craft.crafts, profession.modifier
	if profession.max > 0 and craft.to > profession.max then
		local thresholds = ns.Model.Get(recipeID)
		---@cast thresholds number[]
		local ups = ns.RecipeSkillUps and ns.RecipeSkillUps(recipeID) or 1
		crafts = ns.Model.CoveredCrafts(thresholds, craft.from + m, profession.max + m, ups)
	end
	-- RecipeInfo has no count; this one includes the client's reagent and resource rules.
	local count = math.min(crafts, ns.Readable(C_TradeSkillUI.GetCraftableCount(recipeID)) or 0)
	if count > 0 then
		return {
			recipeID = recipeID,
			count = count,
			planned = crafts,
			to = craft.to,
			text = count < crafts and string.format(L["Craft %d of %d× %s"], count, crafts, name)
				or string.format(L["Craft %d× %s"], count, name),
		}
	end
	return {
		text = string.format(L["Craft %d× %s"], crafts, name),
		reason = L["Missing reagents for this step."],
		planned = crafts,
		to = craft.to,
		missing = MissingReagent(recipeID, crafts),
	}
end
