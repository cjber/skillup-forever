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
		ns.RequestItemData(rank.book)
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

-- One craft's reagent cost, what it makes and its net: the price module's answer. A client
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
---@param craft SkillUpPlanCraft?
---@return number?
function ns.StepCost(recipeID, crafts, craft)
	if craft and craft.materialCost ~= nil then
		local materials = craft.materialCost
		local _, value, net = RecipeCosts(recipeID)
		-- When the price model considers the output unpriced, a known input cost is only a partial total.
		return type(materials) == "number" and net and materials - (value and value.copper or 0) * crafts or nil
	end
	local _, _, netCost = RecipeCosts(recipeID)
	return ns.Model.StepCost(netCost, nil, crafts)
end

-- A recipe's reagents for the planner's held pool: what buying each unit costs, and what using a held copy
-- gives up. Only a reagent the bags or bank actually hold gets the second price: an unheld one is never read
-- from the pool, and pricing it anyway would ask the client for item data a plan does not otherwise need. A
-- recipe with nothing held therefore keeps nil, and with nothing held anywhere it costs no table and no read
-- at all: the planner uses `reagents` for nothing else.
---@param recipeID integer
---@param reagents SkillUpReagent[]? Already read, when the caller has them.
---@param held table<integer, integer>? The snapshot's held counts, entries only for what is held.
---@return SkillUpPricedReagent[]?
local function PricedReagents(recipeID, reagents, held)
	if not held or next(held) == nil then
		-- The bags and bank hold nothing: no recipe can draw from them, so not even a reagent list is read.
		return nil
	end
	local list = reagents or (ns.Reagents and ns.Reagents(recipeID)) or {}
	local pooled = false
	for _, reagent in ipairs(list) do
		if held[reagent.itemID] then
			pooled = true
			break
		end
	end
	if not pooled then
		return nil
	end
	local priced = {}
	for _, reagent in ipairs(list) do
		local itemID = reagent.itemID
		priced[#priced + 1] = {
			itemID = itemID,
			quantity = reagent.quantity,
			buy = ns.ObtainCost and ns.ObtainCost(itemID, reagent.quantity) or nil,
			held = held[itemID] and ns.HeldCost and ns.HeldCost(itemID) or nil,
		}
	end
	return priced
end

-- The reagents whose held count a snapshot has already read, keyed by the snapshot: a snapshot lives only for
-- the plan made from it, so the map is weak.
---@type table<SkillUpSnapshot, table<integer, true>>
local countedBySnapshot = setmetatable({}, { __mode = "k" })

-- Adds the held count of every reagent a snapshot has not counted yet, so two recipes using the same reagent
-- ask the bags and bank once. Only a recipe the planner can use is counted: one it can neither craft nor train
-- is never priced from the pool, so its reagents' counts are never read.
---@param snapshot SkillUpSnapshot
---@param reagents SkillUpReagent[]?
---@return table<integer, integer> The snapshot's held counts, entries only for what is held.
local function CountHeld(snapshot, reagents)
	local counted = countedBySnapshot[snapshot]
	if not counted then
		counted = {}
		countedBySnapshot[snapshot] = counted
	end
	local held = snapshot.held
	if not held then
		held = {}
		snapshot.held = held
	end
	for _, reagent in ipairs(reagents or {}) do
		local itemID = reagent.itemID
		if not counted[itemID] then
			counted[itemID] = true
			-- A count of zero would be copied into every walk's pool for nothing.
			local count = ns.Have and ns.Have(itemID) or 0
			if count > 0 then
				held[itemID] = count
			end
		end
	end
	return held
end

-- Whether a recipe with no known cost still plans, as an unknown-cost step ranked after every priced recipe, and
-- why. Every unpriced input must have a source: "gather" when each is one this character gathers (a missing sale
-- value does not prevent gathering), "auction" when any is an auction reagent with no listing seen yet. That
-- reagent stays on the route and in the Auctionator list as a price unknown, so a search can price it (#559,
-- #855). An input with no source at all keeps the recipe out (false).
---@param reagents SkillUpReagent[]?
---@return false|"gather"|"auction"
local function GatherableUnknown(reagents)
	if not ns.ObtainCost or not ns.Price then
		return false
	end
	---@type false|"gather"|"auction"
	local missing = false
	for _, reagent in ipairs(reagents or {}) do
		if ns.ObtainCost(reagent.itemID, reagent.quantity) == nil then
			local _, price = ns.ReagentBuyCost(reagent.itemID, reagent.quantity)
			if price and price.source == "auction" and price.unknown then
				missing = "auction"
			elseif price and price.source == "gather" then
				missing = missing or "gather"
			else
				return false
			end
		end
	end
	return missing
end

local NewStockReagentCost

-- A route only crafts at skills from its start up to, but excluding, its target. Resolve this from the
-- thresholds before reading the character's recipe book, bags or prices.
---@param recipeID integer
---@param snapshot SkillUpSnapshot
---@return number[]?
local function RouteThresholds(recipeID, snapshot)
	local thresholds = ns.Model.Get(recipeID)
	if thresholds and thresholds[1] < snapshot.target and thresholds[4] > snapshot.skill then
		return thresholds
	end
end

-- What the planner works from: the recipes this character knows, for any of its professions, from
-- the bundled recipe data plus the learned record, so the profession needn't be open. `known` adds
-- recipes the caller knows are learned. Skills here are effective (base + bonus), as the
-- thresholds are. `held` is what the bags and bank count of the reagents those recipes use; a
-- training search counts its own candidates' before it prices them.
---@param profession SkillUpContext
---@param target number Base skill.
---@param known table<integer, boolean>?
---@return SkillUpSnapshot
local function Snapshot(profession, target, known)
	local recipes = {}
	---@type SkillUpSnapshot
	local snapshot = {
		skill = profession.skill,
		target = target + profession.modifier,
		recipes = recipes,
		-- Between two recipes that tie on cost and chance, the planner takes one whose product is a buff this
		-- level can use (#357).
		buffs = ns.UsableBuffs(UnitLevel("player") or 0),
		held = {},
		stockCost = NewStockReagentCost(),
	}
	for _, recipeID in ipairs(RecipesOf(profession.skillLine)) do
		local thresholds = RouteThresholds(recipeID, snapshot)
		if thresholds and not Skipped(recipeID) and (known and known[recipeID] or ns.IsLearned(recipeID)) then
			local reagents = ns.Reagents and ns.Reagents(recipeID)
			local held = CountHeld(snapshot, reagents)
			local reagentCost, value, netCost = RecipeCosts(recipeID)
			local unknown = netCost == nil and GatherableUnknown(reagents)
			recipes[#recipes + 1] = {
				recipeID = recipeID,
				thresholds = thresholds,
				netCost = netCost,
				gatherableUnknown = unknown,
				reagentCost = reagentCost,
				stockSensitive = (netCost ~= nil or unknown) and ns.RecipeUsesStock and ns.RecipeUsesStock(recipeID),
				reagents = PricedReagents(recipeID, reagents, held),
				value = value and value.copper or nil,
				preference = ns.PinPreference(recipeID),
				skillUps = ns.RecipeSkillUps and ns.RecipeSkillUps(recipeID) or 1,
			}
		end
	end
	snapshot.restockCost = ns.db and ns.db.restockCost or 0
	return snapshot
end

-- { fee, required base skill, minimum character level }: what a trainer was seen to charge, else the base
-- fee and the bundle's level gate; nil for a recipe no trainer teaches. The level sits at the fourth place,
-- where a visit records it, so both kinds of training read the same.
---@param profession {skillLine: integer}
---@param recipeID integer
---@return number[]?
function ns.TrainingFor(profession, recipeID)
	local seen = ns.db.trainer[profession.skillLine]
	local training = seen and seen[recipeID]
	if training then
		return training
	end
	local bundled = ns.TrainerFees[recipeID]
	local level = bundled and ns.TrainerLevels and ns.TrainerLevels[recipeID]
	if not (bundled and level) then
		return bundled
	end
	---@type number[]
	local gated = { bundled[1], bundled[2] }
	gated[4] = level
	return gated
end

-- { fee, required base skill }: a recipe's scroll sold by a vendor, whose price is the fee, nil for a
-- recipe with no such scroll. A price seen at a merchant proves the vendor sells it; else the catalogue
-- must name a vendor, so a drop nobody sells is never planned as a purchase (#358).
---@param recipeID integer
---@param targetBase? number Only candidate searches supply a target; existing steps resolve their source directly.
---@return number[]?
local function VendorTraining(recipeID, targetBase)
	local scroll = ns.RecipeScrolls and ns.RecipeScrolls[recipeID]
	local item = scroll and scroll[1]
	if not item or (targetBase and scroll[2] >= targetBase) then
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
	local targetBase = snapshot.target - profession.modifier
	local level = UnitLevel("player") or 0
	for _, recipeID in ipairs(RecipesOf(profession.skillLine)) do
		local t = RouteThresholds(recipeID, snapshot)
		if t then
			local training = ns.TrainingFor(profession, recipeID) or VendorTraining(recipeID, targetBase)
			if
				training
				and training[2] < targetBase
				and (not training[4] or level >= training[4])
				and not ns.IsLearned(recipeID)
				and not Skipped(recipeID)
			then
				local taught = { math.max(t[1], training[2] + profession.modifier), t[2], t[3], t[4] }
				-- Its reagents join the snapshot's pool before they are priced, so a candidate the bags can make
				-- is weighed against what using those copies gives up.
				local reagents = ns.Reagents and ns.Reagents(recipeID)
				local held = CountHeld(snapshot, reagents)
				local reagentCost, value, netCost = RecipeCosts(recipeID)
				local unknown = netCost == nil and GatherableUnknown(reagents)
				services[#services + 1] = {
					recipeID = recipeID,
					thresholds = taught,
					netCost = netCost,
					gatherableUnknown = unknown,
					reagentCost = reagentCost,
					stockSensitive = (netCost ~= nil or unknown) and ns.RecipeUsesStock and ns.RecipeUsesStock(
						recipeID
					),
					reagents = PricedReagents(recipeID, reagents, held),
					value = value and value.copper or nil,
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
-- teaches it, the effective skill (base plus the profession's modifier) it asks and, for a trainer, the
-- character level it asks. Nil for anything else, including a quest, which only the catalogue knows.
---@param profession SkillUpContext
---@param recipeID integer
---@return SkillUpLearnSource?
function ns.LearnSource(profession, recipeID)
	local training = ns.TrainingFor(profession, recipeID)
	if training then
		-- A visit records 0 for a service that asks no level.
		local level = training[4]
		return {
			kind = "trainer",
			skill = training[2] + profession.modifier,
			level = level and level > 0 and level or nil,
		}
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
	if source.level and source.level > 1 then
		text = string.format(L["%s (level %d)"], text, source.level)
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
						level = source.level,
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
				rest.crafts =
					ns.Model.CoveredCrafts(thresholds, splitAt, segment.toSkill, ups, ns.Model.ROUTE_CONFIDENCE)
				segment.toSkill = splitAt
				segment.crafts =
					ns.Model.CoveredCrafts(thresholds, segment.fromSkill, splitAt, ups, ns.Model.ROUTE_CONFIDENCE)
				table.insert(segments, index + 1, rest)
				return
			end
		end
	end
end

-- How deep a reagent is followed into the recipes that make it before it is left to buy.
local MAX_SUB_DEPTH = 3
-- What Expand returns as `used` when no bags are passed: never written, since only the bags branch adds to it.
local NONE_USED = {}

-- A learned recipe that makes `itemID` from what the bags still hold, with its output per craft, its reagents and
-- how many crafts those held reagents cover in full. Inputs bought for a route keep making its intermediate once
-- the market turns to buying it, instead of sitting unused while the route asks for the intermediate (#858).
-- Only crafts the bags cover whole count: buying more inputs to make it is the market choice SubCraft makes. The
-- maker passes the same test SubCraft's does (ns.UsableMaker).
---@param itemID integer
---@param bags table<integer, number>
---@return integer?, number?, {itemID: integer, quantity: number}[]?, integer?
local function HeldMaker(itemID, bags)
	---@type integer?, number?, {itemID: integer, quantity: number}[]?, integer?, number?
	local bestID, bestQuantity, bestReagents, bestCrafts, bestCost
	for _, makerID in ipairs(ns.MakersOf and ns.MakersOf(itemID) or {}) do
		if ns.UsableMaker(makerID) then
			local quantity, reagents = ns.RecipeOutput(makerID).quantity, ns.Reagents(makerID) or {}
			---@type number, number?
			local crafts, cost = math.huge, 0
			-- A schematic can list one item in two slots, so what a craft takes of each item is summed first.
			local per = {}
			for _, reagent in ipairs(reagents) do
				per[reagent.itemID] = (per[reagent.itemID] or 0) + reagent.quantity
				local each = cost and ns.HeldCost and ns.HeldCost(reagent.itemID)
				cost = each and cost + each * reagent.quantity or nil
			end
			for input, total in pairs(per) do
				bags[input] = bags[input] or ns.Have(input)
				crafts = math.min(crafts, math.floor(bags[input] / total))
			end
			-- Of the makers the bags cover, the one whose held inputs give up least per item made; an input with
			-- no known worth ranks its maker after every priced one, and a tie keeps the lower recipe ID.
			local unit = cost and cost / quantity
			if crafts > 0 and (not bestID or (unit and (not bestCost or unit < bestCost))) then
				bestID, bestQuantity, bestReagents, bestCrafts, bestCost = makerID, quantity, reagents, crafts, unit
			end
		end
	end
	return bestID, bestQuantity, bestReagents, bestCrafts
end

-- Makes what the held inputs cover of `need` copies of `itemID`, each held maker in turn, cheapest first, taking
-- those inputs off `bags` and recording them in `used`. Returns the need left and how many crafts of `market` (the
-- recipe SubCraft chose, or nil) it made: the caller folds those into the market step, so one recipe is one step.
---@param itemID integer
---@param need number
---@param market integer?
---@param bags table<integer, number>
---@param subcrafts SkillUpSubCraft[]
---@param used {itemID: integer, count: number}[]
---@return number left
---@return integer marketCrafts
local function MakeFromHeld(itemID, need, market, bags, subcrafts, used)
	local marketCrafts = 0
	while need > 0 do
		local makerID, quantity, inputs, covered = HeldMaker(itemID, bags)
		if not makerID then
			break
		end
		---@cast quantity number
		---@cast inputs {itemID: integer, quantity: number}[]
		local batches = math.min(assert(covered), math.ceil(need / quantity))
		for _, input in ipairs(inputs) do
			local count = input.quantity * batches
			bags[input.itemID] = bags[input.itemID] - count
			used[#used + 1] = { itemID = input.itemID, count = count }
		end
		if makerID == market then
			marketCrafts = marketCrafts + batches
		else
			subcrafts[#subcrafts + 1] =
				{ recipeID = makerID, itemID = itemID, crafts = batches, made = batches * quantity }
		end
		need = math.max(0, need - batches * quantity)
	end
	return need, marketCrafts
end

-- Takes the held copies of a recipe's own reagents off the bags, up to what its crafts use, so no held sub-craft
-- spends them making another reagent while this one then has to be bought (#858). Returns each reagent's share.
---@param recipeID integer
---@param crafts number
---@param bags table<integer, number>
---@return number[]
local function Reserve(recipeID, crafts, bags)
	local reserved = {}
	for index, reagent in ipairs((ns.Reagents and ns.Reagents(recipeID)) or {}) do
		bags[reagent.itemID] = bags[reagent.itemID] or ns.Have(reagent.itemID)
		local held = math.min(bags[reagent.itemID], reagent.quantity * crafts)
		bags[reagent.itemID] = bags[reagent.itemID] - held
		reserved[index] = held
	end
	return reserved
end

-- Appends one purchased input split by source, debiting the route's limited vendor balance.
---@param raw SkillUpRawInput[]
---@param itemID integer
---@param count number
---@param stock table<integer, number>
local function AddAllocatedRaw(raw, itemID, count, stock)
	local units, vendor, overflow = ns.AllocateReagent(itemID, count, stock)
	if units > 0 then
		raw[#raw + 1] = { itemID = itemID, count = units, price = vendor }
	end
	if count > units then
		raw[#raw + 1] = { itemID = itemID, count = count - units, price = vendor and overflow }
	end
end

-- The sub-crafts a recipe's reagents need, deepest first, and the raw reagents left once every
-- reagent a learned recipe makes for less than it costs to buy is replaced by what it is made from.
-- A reagent already being made higher up is left raw, so a cycle cannot recurse. `bags` is the held
-- copies the plan has left: a step takes from it, so the steps after it never claim the same copy,
-- and only the shortfall is planned. `used` is the held copies that stood in for raw reagents, which
-- a caller reporting the whole route adds back to the shortfall (#667).
---@param recipeID integer
---@param crafts number
---@param depth integer
---@param making table<integer, true>
---@param bags table<integer, number>?
---@param reserved number[]? What Reserve set aside of each reagent; Expand reserves its own when not given.
---@param stock table<integer, number>? The route's stock ledger, spare batch output included (ns.StockFor).
---@param spare table<integer, number>? Where spare batch output goes when there is no stock, keyed as in a ledger.
---@return SkillUpSubCraft[]
---@return SkillUpRawInput[]
---@return {itemID: integer, count: number}[]
---@return boolean held Whether a held copy, raw or intermediate, stood in for a reagent.
---@return boolean wholeBatches Whether this expansion made or used spare batch output.
local function Expand(recipeID, crafts, depth, making, bags, reserved, stock, spare)
	local subcrafts, raw = {}, {}
	-- Only a caller that passes the bags writes or reads what they stood in for; the rest share one empty table.
	local used = bags and {} or NONE_USED
	local usedHeld, wholeBatches = false, false
	local reagents = (ns.Reagents and ns.Reagents(recipeID)) or {}
	reserved = reserved or (bags and Reserve(recipeID, crafts, bags)) or {}
	local needs, shares
	if stock then
		needs = {}
		for index, reagent in ipairs(reagents) do
			needs[index] = reagent.quantity * crafts - (reserved[index] or 0)
		end
		shares = ns.StockShares(reagents, stock, needs, MAX_SUB_DEPTH - depth, making)
	end
	for index, reagent in ipairs(reagents) do
		local held = reserved[index] or 0
		local need = needs and needs[index] + held or reagent.quantity * crafts
		local caps = shares and shares[index]
		local reagentStock = stock and ns.StockFor(stock, caps)
		-- Spare output from whole batches, an earlier sibling's included, has already been paid for. Use it after
		-- the copies reserved from the bags and before buying or making more.
		local spares = reagentStock or spare
		local copies = spares and math.min(need - held, spares[-reagent.itemID] or 0) or 0
		if spares and copies > 0 then
			wholeBatches = true
			spares[-reagent.itemID] = spares[-reagent.itemID] - copies
			need = need - copies
		end
		local maker
		if depth < MAX_SUB_DEPTH and not making[reagent.itemID] and ns.SubCraft then
			if reagentStock then
				if need > held then
					maker = ns.SubCraft(reagent.itemID, need - held, reagentStock, MAX_SUB_DEPTH - depth, making)
				end
			else
				maker = ns.SubCraft(reagent.itemID)
			end
		end
		if maker and maker.quantity and maker.quantity > 0 then
			-- Held copies of the intermediate are used before any are made, then held inputs make what they cover
			-- (#858); the market's maker makes the rest. The steps after this see what is left.
			local heldCrafts = 0
			if bags then
				local left
				left, heldCrafts = MakeFromHeld(reagent.itemID, need - held, maker.recipeID, bags, subcrafts, used)
				if left < need then
					usedHeld = true
				end
				need = left
			end
			local batches = math.ceil(need / maker.quantity)
			if reagentStock and maker.purchaseUnits > 0 then
				batches = math.ceil(math.max(need - maker.purchaseUnits, 0) / maker.quantity)
				local purchases = need - batches * maker.quantity
				if purchases > 0 then
					AddAllocatedRaw(raw, reagent.itemID, purchases, reagentStock)
				end
			end
			local firstChild = #raw + 1
			if batches > 0 then
				making[reagent.itemID] = true
				local childSubcrafts, childRaw, childUsed, childHeld, childBatches =
					Expand(maker.recipeID, batches, depth + 1, making, bags, nil, reagentStock, spare)
				making[reagent.itemID] = nil
				wholeBatches = wholeBatches or childBatches
				for _, sub in ipairs(childSubcrafts) do
					subcrafts[#subcrafts + 1] = sub
				end
				for _, item in ipairs(childRaw) do
					raw[#raw + 1] = item
				end
				for _, item in ipairs(childUsed) do
					used[#used + 1] = item
				end
				if childHeld then
					usedHeld = true
				end
			end
			if spares and batches * maker.quantity > need then
				wholeBatches = true
				spares[-reagent.itemID] = (spares[-reagent.itemID] or 0) + batches * maker.quantity - need
			end
			if batches + heldCrafts > 0 then
				local subcraft = {
					recipeID = maker.recipeID,
					itemID = reagent.itemID,
					crafts = batches + heldCrafts,
					made = (batches + heldCrafts) * maker.quantity,
				}
				subcrafts[#subcrafts + 1] = subcraft
				for child = firstChild, #raw do
					raw[child].owner = raw[child].owner or subcraft
				end
			end
		else
			-- A raw reagent the bags hold is not bought or gathered, nor is what held inputs make of it (#858); the
			-- rest is what the route still needs.
			if bags then
				need = need - held
				if held > 0 then
					used[#used + 1] = { itemID = reagent.itemID, count = held }
					usedHeld = true
				end
				if need > 0 and depth < MAX_SUB_DEPTH and not making[reagent.itemID] then
					local left = MakeFromHeld(reagent.itemID, need, nil, bags, subcrafts, used)
					if left < need then
						usedHeld = true
					end
					need = left
				end
			end
			if need > 0 then
				if reagentStock then
					AddAllocatedRaw(raw, reagent.itemID, need, reagentStock)
				else
					raw[#raw + 1] = { itemID = reagent.itemID, count = need }
				end
			end
		end
		if stock and reagentStock then
			ns.SpendStock(stock, reagentStock, caps)
		end
	end
	return subcrafts, raw, used, usedHeld, wholeBatches
end

---@class SkillUpExpanded
---@field subcrafts SkillUpSubCraft[]
---@field raw SkillUpRawInput[]
---@field used {itemID: integer, count: number}[]
---@field held boolean
---@field stockSensitive? boolean
---@field wholeBatches boolean

-- Expands each of a route's crafts against one shared view of the bags. Every craft's own reagents are reserved
-- before any craft expands, so a held sub-craft of an earlier craft cannot spend what a later one uses directly.
---@param crafts {recipeID: integer, crafts: number}[]
---@return SkillUpExpanded[]
local function ExpandRoute(crafts)
	local bags, reserved, expanded, ledger = {}, {}, {}, {}
	for index, craft in ipairs(crafts) do
		reserved[index] = Reserve(craft.recipeID, craft.crafts, bags)
	end
	for index, craft in ipairs(crafts) do
		local sensitive = ns.RecipeUsesStock and ns.RecipeUsesStock(craft.recipeID)
		local subcrafts, raw, used, held, wholeBatches =
			Expand(craft.recipeID, craft.crafts, 0, {}, bags, reserved[index], sensitive and ledger or nil, ledger)
		expanded[index] = {
			subcrafts = subcrafts,
			raw = raw,
			used = used,
			held = held,
			stockSensitive = sensitive,
			wholeBatches = wholeBatches,
		}
	end
	return expanded
end

---@type table<SkillUpPlan, SkillUpExpanded[]>
local planExpansions = setmetatable({}, { __mode = "k" })

-- The same acquisition rows price trial routes and displayed route steps.
---@param raw SkillUpRawInput[]
---@param used {itemID: integer, count: number}[]
---@return number?
local function ExpansionCost(raw, used)
	local total = 0
	for _, item in ipairs(raw) do
		local price = item.price or ns.Price(item.itemID)
		if not price or price.unknown then
			return nil
		end
		total = total + price.copper * item.count
	end
	for _, item in ipairs(used) do
		local each = ns.HeldCost(item.itemID)
		if not each then
			return nil
		end
		total = total + each * item.count
	end
	return total
end
-- A partial batch costs a whole craft up front, and its leftover units are already paid for.
---@param part SkillUpExpanded
---@return number|false|nil
local function ExpandedMaterialCost(part)
	if part.stockSensitive or part.wholeBatches then
		return ExpansionCost(part.raw, part.used) or false
	end
end

-- Quotes are local to a planning snapshot. Different walks can share them when they reach the same
-- craft count with the same relevant balances. The chosen craft still spends against the route's live balances.
NewStockReagentCost = function()
	---@type table<integer, integer[]>
	local dependencies = {}
	---@type table<integer, table<number, {bags: table<integer, number>, stock: table<integer, number>, cost: number?}>>
	local quotes = {}
	local emptyStock = {}
	return function(recipeID, crafts, pool, stock, take)
		if take then
			local _, raw, used = Expand(recipeID, crafts, 0, {}, pool, nil, stock)
			return ExpansionCost(raw, used)
		end
		local items = dependencies[recipeID]
		if not items then
			items = {}
			local seen = {}
			for _, reagent in ipairs(ns.Reagents(recipeID) or {}) do
				local reachable = ns.ItemCostDependencies(reagent.itemID, MAX_SUB_DEPTH)
				for _, itemID in ipairs(reachable) do
					if not seen[itemID] then
						seen[itemID] = true
						items[#items + 1] = itemID
					end
				end
			end
			dependencies[recipeID] = items
			quotes[recipeID] = {}
		end
		local ledger = stock or emptyStock
		local byCount = quotes[recipeID]
		local quote = byCount[crafts]
		if quote then
			local same = true
			for _, itemID in ipairs(items) do
				if
					quote.bags[itemID] ~= pool[itemID]
					or quote.stock[itemID] ~= ledger[itemID]
					or quote.stock[-itemID] ~= ledger[-itemID]
				then
					same = false
					break
				end
			end
			if same then
				return quote.cost
			end
		end
		local bags, balances, bagsBefore, stockBefore = {}, {}, {}, {}
		for _, itemID in ipairs(items) do
			local held, available, spare = pool[itemID], ledger[itemID], ledger[-itemID]
			bags[itemID], bagsBefore[itemID] = held, held
			balances[itemID], stockBefore[itemID] = available, available
			balances[-itemID], stockBefore[-itemID] = spare, spare
		end
		local _, raw, used = Expand(recipeID, crafts, 0, {}, bags, nil, balances)
		local cost = ExpansionCost(raw, used)
		byCount[crafts] = { bags = bagsBefore, stock = stockBefore, cost = cost }
		return cost
	end
end

-- What a cache keyed on the plan reads from one expansion of its crafts: the sub-craft steps, and each item's total
-- need, raw plus held, which RouteReagents lists. Ordinary holdings are live. Stock-aware rows are also keyed
-- on which units must be bought, so the tracker refreshes when a vendor allocation appears or disappears.
---@param expanded SkillUpExpanded[]
---@return string
local function ExpandedSignature(expanded)
	local parts, order, total = {}, {}, {}
	for _, part in ipairs(expanded) do
		for _, sub in ipairs(part.subcrafts) do
			parts[#parts + 1] = "s" .. sub.recipeID .. ":" .. sub.itemID .. ":" .. sub.crafts
		end
		if part.stockSensitive then
			for _, input in ipairs(part.raw) do
				local price = input.price
				if price then
					parts[#parts + 1] =
						table.concat({ "p", input.itemID, input.count, price.source, price.vendor or 0 }, ":")
				end
			end
		end
		for _, list in ipairs({ part.raw, part.used }) do
			for _, item in ipairs(list) do
				if not total[item.itemID] then
					order[#order + 1] = item.itemID
				end
				total[item.itemID] = (total[item.itemID] or 0) + item.count
			end
		end
	end
	table.sort(order)
	for _, itemID in ipairs(order) do
		parts[#parts + 1] = "n" .. itemID .. ":" .. total[itemID]
	end
	return table.concat(parts, ",")
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
	-- The bill is for the recipe alone: another addon asking what it takes is not told about these bags.
	local stock = ns.RecipeUsesStock and ns.RecipeUsesStock(recipeID) and {} or nil
	local subcrafts, raw = Expand(recipeID, crafts, 0, {}, nil, nil, stock, {})
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
	local stockSensitive = false
	for _, craft in ipairs(plan.crafts or {}) do
		if ns.RecipeUsesStock and ns.RecipeUsesStock(craft.recipeID) then
			stockSensitive = true
			break
		end
	end
	local expanded = (stockSensitive and planExpansions[plan]) or ExpandRoute(plan.crafts or {})
	local buy, unknown = 0, 0
	if stockSensitive then
		local unpriced = {}
		for _, part in ipairs(expanded) do
			for _, item in ipairs(part.raw) do
				local price = item.price or ns.Price(item.itemID)
				if price and not price.unknown then
					buy = buy + price.copper * item.count
				elseif not unpriced[item.itemID] then
					unpriced[item.itemID] = true
					unknown = unknown + 1
				end
			end
		end
	else
		local counts = {}
		for _, part in ipairs(expanded) do
			for _, item in ipairs(part.raw) do
				counts[item.itemID] = (counts[item.itemID] or 0) + item.count
			end
		end
		for itemID, short in pairs(counts) do
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

-- A plan's steps, in Walk's order, and each step's skill band, from the cap it starts under and the caps its ranks
-- raise: the route page groups steps by these without working the ranks out again (#574).
---@param plan SkillUpPlan
local function Lay(plan)
	plan.steps = Walk(plan)
	plan.bands = {}
	local cap = plan.profession.max
	if cap > 0 then
		plan.bands[1] = { name = ns.RankName(cap) or tostring(cap), from = math.max(cap - RANK_SPAN, 0), cap = cap }
	end
	for _, rank in ipairs(plan.ranks) do
		plan.bands[#plan.bands + 1] = { name = rank.name, from = math.max(rank.cap - RANK_SPAN, 0), cap = rank.cap }
	end
	local bandIndex = 1
	for _, step in ipairs(plan.steps) do
		if step.rank then
			bandIndex = bandIndex + 1
		end
		step.band = plan.bands[bandIndex] or plan.bands[#plan.bands]
	end
end

-- The planner's route, which is in effective skill, as the plan a player reads.
---@param profession SkillUpProfession
---@param target number
---@param route SkillUpTrainedRoute
---@return SkillUpPlan
local function Finish(profession, target, route)
	local m = profession.modifier
	local cost = route.trainingCost
	local segmentCount = #route.segments
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
	-- Reuse the model's budget unless a rank split changed its segments. Rebuilding a held route has no
	-- prior completion result, so it also budgets the current segments here.
	local completion = route.completion
	if completion == nil or #route.segments ~= segmentCount then
		for _, segment in ipairs(route.segments) do
			segment.thresholds = ns.Model.Get(segment.recipeID)
			segment.reagentCost = RecipeCosts(segment.recipeID)
		end
		local budgets
		budgets, completion =
			ns.Model.BudgetSegments(route.segments, ns.Model.ROUTE_CONFIDENCE, ns.db and ns.db.restockCost or 0)
		for index, segment in ipairs(route.segments) do
			segment.crafts = budgets[index]
		end
	end
	local crafts = {}
	local expanded = ExpandRoute(route.segments)
	for index, segment in ipairs(route.segments) do
		local part = expanded[index]
		crafts[index] = {
			recipeID = segment.recipeID,
			from = segment.fromSkill - m,
			to = segment.toSkill - m,
			crafts = segment.crafts,
			points = segment.toSkill - segment.fromSkill,
			skillUps = segment.skillUps or 1,
			color = ns.Model.Color(ns.Model.Get(segment.recipeID), segment.fromSkill),
			station = ns.RecipeStation and ns.RecipeStation(segment.recipeID) or nil,
			subcrafts = part.subcrafts,
			raw = part.raw,
			held = part.held or nil,
			materialCost = ExpandedMaterialCost(part),
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
		crafting = crafting + (ns.StepCost(craft.recipeID, craft.crafts, craft) or 0)
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
		completion = completion,
		unpriced = 0,
		unpricedRecipes = {},
		stopReason = route.stopReason,
	}
	-- Left out means not on the route: a recipe waiting on an auction price that the route picks is a step, shown
	-- with its cost unknown, not one of the recipes the page says it left out (#855).
	local onRoute = {}
	for _, segment in ipairs(route.segments) do
		onRoute[segment.recipeID] = true
	end
	for _, recipeID in ipairs(route.excluded.recipes) do
		if not onRoute[recipeID] then
			plan.unpriced = plan.unpriced + 1
			plan.unpricedRecipes[plan.unpriced] = recipeID
		end
	end
	plan.expanded = ExpandedSignature(expanded)
	planExpansions[plan] = expanded
	Lay(plan)
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
---@type table<integer, { plans: table<string, SkillUpPlan>, order: string[], bags: table<string, integer> }>
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

-- A bag change can choose a route's recipes: a plan made before it priced the bags as they were. The plan cache
-- is epoched rather than dropped, so nothing is replanned until something asks, and a plan made before the last
-- bag change is never served as today's choice. The route being followed is kept if every step can still be
-- walked (#621). Bags move many times a frame while looting, so that check runs once per bag change however
-- many asks follow it.
local bagEpoch = 0

ns.WhenStale("bags", function()
	bagEpoch = bagEpoch + 1
end)

-- Every reagent a route's crafts use is in the bags or has a price: what a bag change can take away.
---@param expandedRoute SkillUpExpanded[]
---@return boolean
local function Affordable(expandedRoute)
	for _, expanded in ipairs(expandedRoute) do
		for _, item in ipairs(expanded.raw) do
			local price = item.price or ns.Price(item.itemID)
			if not price or (price.unknown and price.source ~= "gather") then
				return false
			end
		end
	end
	return true
end

-- A followed route kept across a bag change takes its sub-crafts from today's bags: held inputs may now make an
-- intermediate, or held copies cover it, so the steps match what Reagents asks for (#858). The crafts stay.
---@param plan SkillUpPlan
---@param expanded SkillUpExpanded[]
local function RefreshSubcrafts(plan, expanded)
	planExpansions[plan] = expanded
	for index, craft in ipairs(plan.crafts) do
		local part = expanded[index]
		craft.subcrafts, craft.raw, craft.held = part.subcrafts, part.raw, part.held or nil
		local materials = ExpandedMaterialCost(part)
		if craft.materialCost ~= nil or materials ~= nil then
			local previous = ns.StepCost(craft.recipeID, craft.crafts, craft) or 0
			craft.materialCost = materials
			plan.cost = plan.cost - previous + (ns.StepCost(craft.recipeID, craft.crafts, craft) or 0)
		end
	end
	-- The plan stays the same table while its expansion follows the bags, so the revision follows the expansion.
	local signature = ExpandedSignature(expanded)
	if plan.expanded ~= signature then
		plan.expanded = signature
		plan.revision = (plan.revision or 0) + 1
	end
	Lay(plan)
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
			not ns.IsLearned(training.recipeID)
			and (
				not (ns.TrainingFor(profession, training.recipeID) or VendorTraining(training.recipeID))
				or ns.LearnSkill(profession, training.recipeID) > training.usedAt + modifier
			)
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
	return Affordable(ExpandRoute(plan.crafts))
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
			crafts = ns.Model.CoveredCrafts(
				thresholds,
				craft.from + modifier,
				craft.to + modifier,
				ups,
				ns.Model.ROUTE_CONFIDENCE
			),
		}
	end
	for _, step in ipairs(plan.training) do
		if not ns.IsLearned(step.recipeID) then
			local training = ns.TrainingFor(profession, step.recipeID) or VendorTraining(step.recipeID)
			---@cast training number[]
			route.training[#route.training + 1] = {
				recipeID = step.recipeID,
				fee = training[1],
				atSkill = step.usedAt + modifier,
			}
			route.trainingCost = route.trainingCost + training[1]
		end
	end
	return Finish(profession, target, route)
end

-- Drops one cached plan and its place in the per-profession order.
---@param cache { plans: table<string, SkillUpPlan>, order: string[], bags: table<string, integer> }
---@param key string
local function Forget(cache, key)
	cache.plans[key] = nil
	cache.bags[key] = nil
	for index, existing in ipairs(cache.order) do
		if existing == key then
			table.remove(cache.order, index)
			return
		end
	end
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
		cache = { plans = {}, order = {}, bags = {} }
		plans[profession.skillLine] = cache
	end
	-- The route being followed is checked against the bags here, once per bag change: a route a step can no
	-- longer afford to craft is planned afresh, any other bag change keeps it (#621).
	---@type { key: string, plan: SkillUpPlan, bags: integer }?
	local kept = committed[profession.skillLine]
	if kept and kept.bags ~= bagEpoch then
		kept.bags = bagEpoch
		local expanded = ExpandRoute(kept.plan.crafts)
		if not Affordable(expanded) then
			Forget(cache, kept.key)
			committed[profession.skillLine] = nil
			kept = nil
		else
			RefreshSubcrafts(kept.plan, expanded)
		end
	end
	-- A plan made before the last bag change is not today's choice: the bags may now favour another recipe. A
	-- route the player is following is the exception (#621): while every step can still be walked it is kept, so
	-- the bags cannot swap the recipes they are shopping for. A fresh plan is made when nothing is being followed.
	---@type SkillUpPlan?
	local cached = cache.plans[key]
	if cached and cache.bags[key] ~= bagEpoch then
		local followed = committed[profession.skillLine]
		if followed and followed.key == key and followed.plan == cached then
			cache.bags[key] = bagEpoch
			cached.profession = profession
			return cached
		end
		cached = nil
	end
	if cached then
		cached.profession = profession
		local entry = committed[profession.skillLine]
		if not entry or entry.plan ~= cached then
			Commit(profession.skillLine, key, cached)
		end
		return cached
	end
	local snapshot = Snapshot(profession, target)
	local route = ns.Model.PlanWithTraining(snapshot, Trainable(profession, snapshot))
	local plan = Finish(profession, target, route)
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
	Forget(cache, key)
	cache.plans[key] = plan
	cache.bags[key] = bagEpoch
	cache.order[#cache.order + 1] = key
	if #cache.order > PLAN_CACHE_SIZE then
		Forget(cache, table.remove(cache.order, 1))
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
	-- The snapshot is made before the offers are priced, so they are weighed against the same bags and bank the
	-- training search re-plans over.
	local snapshot = Snapshot(profession, RouteTarget(profession), known)
	local services = {}
	for _, offer in ipairs(offers) do
		local thresholds = ns.Model.Get(offer.recipeID)
		if thresholds and not ns.IsLearned(offer.recipeID) and not Skipped(offer.recipeID) then
			-- An offer's reagents join the snapshot's pool before they are priced, as a trainer's taught recipe's
			-- do, so the bags weigh in on which offer is worth taking.
			local reagents = ns.Reagents and ns.Reagents(offer.recipeID)
			local held = CountHeld(snapshot, reagents)
			local reagentCost, value, netCost = RecipeCosts(offer.recipeID)
			services[#services + 1] = {
				recipeID = offer.recipeID,
				thresholds = {
					math.max(thresholds[1], ns.LearnSkill(profession, offer.recipeID)),
					thresholds[2],
					thresholds[3],
					thresholds[4],
				},
				netCost = netCost,
				gatherableUnknown = netCost == nil and GatherableUnknown(reagents),
				reagentCost = reagentCost,
				stockSensitive = ns.RecipeUsesStock and ns.RecipeUsesStock(offer.recipeID),
				reagents = PricedReagents(offer.recipeID, reagents, held),
				value = value and value.copper or nil,
				preference = ns.PinPreference(offer.recipeID),
				skillUps = ns.RecipeSkillUps and ns.RecipeSkillUps(offer.recipeID) or 1,
				fee = offer.fee,
			}
		end
	end
	table.sort(services, function(a, b)
		return a.recipeID < b.recipeID
	end)
	local best = ns.Model.RecommendTraining(snapshot, services)
	return best and best.recipeID or nil
end

-- What the route page and shopping list say beside their quantities: the counts carry the spares that make the
-- whole route finish with the model's stated chance, and it is an estimate from the skill-up chance, not a promise.
---@return string
function ns.RouteSparesNote()
	return string.format(
		L["Counts include spares for an estimated %d%% chance to finish the whole route."],
		math.floor(ns.Model.ROUTE_CONFIDENCE * 100 + 0.5)
	)
end

local ShoppingOrder = {}
for index, source in ipairs(ns.Model.SHOPPING_SOURCES) do
	ShoppingOrder[source] = index
end

-- Everything the plan's crafts use, as totals: what you have is compared live, so the
-- list stays right as you buy, craft or bank things.
---@param plan SkillUpPlan
---@return SkillUpNeededItem[]
function ns.RouteReagents(plan)
	-- The raw reagents are worked out from the recipes as they stand now, so a bought or gathered
	-- source in the settings shows without rebuilding the plan.
	local supply = ns.RouteDemand and ns.RouteDemand.Supply(plan)
	if supply then
		local items = {}
		for itemID, count in pairs(supply.items) do
			local acquisitions = {}
			for _, acquisition in ipairs(supply.acquisitions or {}) do
				if acquisition.itemID == itemID then
					acquisitions[#acquisitions + 1] = acquisition
				end
			end
			items[#items + 1] = {
				itemID = itemID,
				need = count,
				have = supply.have[itemID],
				supplyScope = supply.result and supply.result.inventoryScope or "bags-and-bank",
				source = #acquisitions > 0 and "vendor" or "unknown",
				acquisitions = acquisitions,
			}
		end
		table.sort(items, function(a, b)
			return a.itemID < b.itemID
		end)
		for _, itemID in ipairs(ns.MissingToolItems and ns.MissingToolItems(plan) or {}) do
			items[#items + 1] = { itemID = itemID, need = 1, source = ns.Model.ShoppingSource(ns.PriceSource(itemID)) }
		end
		return items
	end
	if #plan.crafts == 0 then
		return {}
	end
	local byItem, held = {}, {}
	local items = {}
	for _, expanded in ipairs((ns.RecipeUsesStock and planExpansions[plan]) or ExpandRoute(plan.crafts)) do
		for _, item in ipairs(expanded.raw) do
			local source = ns.Model.ShoppingSource(item.price and item.price.source or ns.PriceSource(item.itemID))
			local key = item.price and (source .. item.itemID .. ":" .. (item.price.vendor or 0)) or item.itemID
			local row = byItem[key]
			if not row then
				row = {
					itemID = item.itemID,
					need = 0,
					source = source,
					allocatedPrice = item.price,
					limited = source == "vendor" and ns.IsLimitedStock and ns.IsLimitedStock(
						item.itemID,
						item.price and item.price.vendor
					) or nil,
				}
				byItem[key] = row
				items[#items + 1] = row
			end
			row.need = row.need + item.count
		end
		for _, item in ipairs(expanded.used) do
			held[item.itemID] = (held[item.itemID] or 0) + item.count
		end
	end
	for itemID, count in pairs(held) do
		local source = ns.Model.ShoppingSource(ns.PriceSource(itemID))
		local _, overflow
		if ns.LimitedReagentPrice then
			_, overflow = ns.LimitedReagentPrice(itemID)
		end
		local row = overflow
				and byItem[ns.Model.ShoppingSource(overflow.source) .. itemID .. ":" .. (overflow.vendor or 0)]
			or byItem[itemID]
		if overflow and not row and source == "vendor" then
			local _, _, vendor = ns.LimitedReagentPrice(itemID)
			row = vendor and byItem[source .. itemID .. ":" .. vendor.vendor] or nil
		end
		if not row then
			row = { itemID = itemID, need = 0, source = source }
			items[#items + 1] = row
		end
		row.have, row.need = count, row.need + count
	end
	for _, row in ipairs(items) do
		-- Every split row already excludes the held copies assigned to the other row.
		row.have = row.have or 0
	end
	local order = ShoppingOrder
	table.sort(items, function(a, b)
		if a.source ~= b.source then
			return order[a.source] < order[b.source]
		end
		if a.itemID ~= b.itemID then
			return a.itemID < b.itemID
		end
		return (a.allocatedPrice and a.allocatedPrice.copper or 0) < (b.allocatedPrice and b.allocatedPrice.copper or 0)
	end)
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
	-- A reagent a planned step uses is listed with the route's own reagents, not again here (#855).
	for _, craft in ipairs(plan.crafts or {}) do
		for _, reagent in ipairs(ns.Reagents(craft.recipeID) or {}) do
			seen[reagent.itemID] = true
		end
	end
	for _, recipeID in ipairs(plan.unpricedRecipes) do
		for _, reagent in ipairs(ns.Reagents(recipeID) or {}) do
			if not seen[reagent.itemID] then
				local price = ns.Price(reagent.itemID)
				if price and price.source == "vendor" and ns.ReagentBuyCost then
					local _, buy = ns.ReagentBuyCost(reagent.itemID, reagent.quantity)
					price = buy
				end
				if not price or price.unknown then
					seen[reagent.itemID] = true
					items[#items + 1] = reagent.itemID
				end
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
		local provider = ns.AuctionProvider()
		if provider == "auctionator" then
			return L["Auctionator hasn't seen these reagents yet: scan the auction house with it to price them."]
		elseif provider == "tsm" then
			return L["TradeSkillMaster has no price for these reagents: update its AuctionDB with the TSM desktop app."]
		elseif provider then
			return ns.UnpricedHint()
		end
		-- luacheck: push no max line length
		local none =
			L["These reagents have no vendor price. Auction prices need Auctionator, TradeSkillMaster, AHDB, Naowh Forever or Forever Ledger."]
		-- luacheck: pop
		return none
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
-- its label; or why it can't be crafted. The selected recipe's profession must be open.
---@param plan SkillUpPlan
---@return SkillUpCraft
function ns.NextCraft(plan)
	local action = ns.RouteDemand.NextAction(plan)
	if action then
		local guidance = { text = L["Craft next"], nextAction = action }
		if action.kind ~= "craft" then
			guidance.reason = action.kind == "stop" and L["Nothing to craft on this route."]
				or L["Supply estimate: not enough information."]
			return guidance
		end
		local recipeID = action.recipeID
		-- Craft actions bind a recipe before publication.
		---@cast recipeID integer
		local recipe = ns.RecipeData[recipeID]
		local skillLine = recipe and recipe.skillLine or plan.profession.skillLine
		if ns.OpenSkillLine() ~= skillLine or not ns.IsLearned(recipeID) then
			guidance.reason = L["The game's Craft button is not ready for this recipe."]
			return guidance
		end
		local tool = ns.MissingTool and ns.MissingTool(recipeID)
		if tool then
			guidance.reason = string.format(L["Need a %s in your bags."], tool.name)
			return guidance
		end
		local craftable = ns.Readable(C_TradeSkillUI.GetCraftableCount(recipeID))
		if type(craftable) ~= "number" or craftable < 1 then
			guidance.reason = L["Missing reagents for this step."]
			return guidance
		end
		guidance.recipeID, guidance.count = recipeID, 1
		guidance.text = string.format(
			L["Craft %d× %s"],
			1,
			C_Spell.GetSpellName(recipeID) or string.format(L["recipe %d"], recipeID)
		)
		return guidance
	end
	local profession, craft = plan.profession, plan.crafts[1]
	if not craft then
		return { text = L["Craft next"], reason = L["Nothing to craft on this route."] }
	elseif profession.capped and plan.ranks[1] then
		local rank = plan.ranks[1]
		local reason = rank.book and string.format(L["Read %s first: you're at your cap."], ns.RankBookName(rank))
			or rank.quest and string.format(L["Complete %s first: you're at your cap."], ns.RankQuestName(rank))
			or string.format(L["Train %s first: you're at your cap."], rank.name)
		return { text = L["Craft next"], reason = reason }
	end
	-- Past the cap a craft gives no skill-up until the next rank is trained.
	local crafts, m = craft.crafts, profession.modifier
	if profession.max > 0 and craft.to > profession.max then
		local thresholds = ns.Model.Get(craft.recipeID)
		---@cast thresholds number[]
		local ups = ns.RecipeSkillUps and ns.RecipeSkillUps(craft.recipeID) or 1
		crafts = ns.Model.CoveredCrafts(thresholds, craft.from + m, profession.max + m, ups)
	end
	-- Resolve the ordered prerequisites backwards from the parent demand. Each held item is
	-- allocated once, including intermediates shared by different branches of the recipe.
	local needed, held, batches = {}, {}, {}
	local function Require(recipe, count)
		for _, reagent in ipairs(ns.Reagents(recipe) or {}) do
			needed[reagent.itemID] = (needed[reagent.itemID] or 0) + reagent.quantity * count
		end
	end
	Require(craft.recipeID, crafts)
	local subcrafts = craft.subcrafts or {}
	for i = #subcrafts, 1, -1 do
		local sub = subcrafts[i]
		local itemID = sub.itemID
		held[itemID] = held[itemID] or ns.Have(itemID)
		local used = math.min(held[itemID], needed[itemID] or 0)
		held[itemID] = held[itemID] - used
		local short = (needed[itemID] or 0) - used
		local yield = sub.made / sub.crafts
		local count = math.min(sub.crafts, math.ceil(short / yield))
		needed[itemID] = math.max(0, short - count * yield)
		held[itemID] = held[itemID] + math.max(0, count * yield - short)
		batches[sub.recipeID] = (batches[sub.recipeID] or 0) + count
		Require(sub.recipeID, count)
	end
	-- Repeated makers share one batch count at their first occurrence, so a later
	-- branch cannot lend its batch surplus to an earlier step before it is made.
	local recipeID = craft.recipeID
	for _, sub in ipairs(subcrafts) do
		if batches[sub.recipeID] > 0 then
			recipeID, crafts = sub.recipeID, batches[sub.recipeID]
			break
		end
	end
	local recipe = ns.RecipeData[recipeID]
	local skillLine = recipe and recipe.skillLine or profession.skillLine
	if ns.OpenSkillLine() ~= skillLine then
		local selected = ns.PlayerProfessions()[skillLine]
		return {
			text = L["Craft next"],
			reason = string.format(L["Open %s to craft from here."], selected and selected.name or profession.name),
		}
	end
	local name = C_Spell.GetSpellName(recipeID) or string.format(L["recipe %d"], recipeID)
	if not ns.IsLearned(recipeID) then
		return { text = L["Craft next"], reason = string.format(L["Train %s first."], name) }
	end
	local tool = ns.MissingTool and ns.MissingTool(recipeID)
	if tool then
		return { text = L["Craft next"], reason = string.format(L["Need a %s in your bags."], tool.name) }
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
