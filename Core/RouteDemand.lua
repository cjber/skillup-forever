---@type string, SkillUpNamespace
local _, ns = ...

if ns.broken then
	return
end
local RouteDemand = {}

local COST_REASON = "observed expenditure unavailable: feasible source orders not established"

-- A probability or acquisition certificate cannot inherit display fallbacks.
-- Explicit bank scope follows Forever's GetItemCount declaration, with reagent
-- and account bank inclusion disabled. Missing/secret reads remain unknown.
---@param itemID integer
---@param includeBank boolean
---@return integer?
---@return string?
function RouteDemand.Count(itemID, includeBank)
	itemID = ns.Readable(itemID)
	includeBank = ns.Readable(includeBank)
	if
		type(itemID) ~= "number"
		or itemID <= 0
		or itemID > 2 ^ 52 - 1
		or itemID % 1 ~= 0
		or type(includeBank) ~= "boolean"
	then
		return nil, "explicit inventory identity and bank scope required"
	end
	local api = C_Item and C_Item.GetItemCount
	if type(api) ~= "function" then
		return nil, "current inventory capability unavailable"
	end
	local ok, raw = pcall(api, itemID, includeBank, false, false, false)
	local count = ok and ns.Readable(raw)
	if type(count) ~= "number" or count < 0 or count > 2 ^ 52 - 1 or count % 1 ~= 0 then
		return nil, "current inventory quantity unavailable"
	end
	return count
end

-- This adapter accepts final Plan output, never CoveredCrafts counts or expanded
-- shopping rows. Its snapshot owns every table read by the asynchronous solver.
---@type table<SkillUpJointDemandJob|SkillUpResupplyJob|SkillUpSupplyChoiceJob, boolean>
local jobs = setmetatable({}, { __mode = "k" })
---@type table<SkillUpSupplyChoiceJob, SkillUpPlan>
local supplyPlans = {}
---@type table<integer, SkillUpSupplyConfiguration>
local configured = {}

---@param plan SkillUpPlan
---@param buy table<integer, integer>
---@return SkillUpJointDemandInput?
---@return string?
function RouteDemand.Snapshot(plan, buy)
	local legCount, largest = 0, 0
	if type(plan) ~= "table" or type(plan.crafts) ~= "table" then
		return nil, "dense ordered crafts required"
	end
	for key, craft in pairs(plan.crafts) do
		if type(key) ~= "number" or key < 1 or key ~= math.floor(key) or type(craft) ~= "table" then
			return nil, "dense ordered crafts required"
		end
		legCount, largest = legCount + 1, math.max(largest, key)
	end
	if legCount ~= largest then
		return nil, "dense ordered crafts required"
	end
	local input = { legs = {}, held = {}, buy = buy }
	local outputs, consumed = {}, {}
	-- Demand copies and validates basket quantities before any probability work.
	if type(buy) == "table" then
		input.buy = {}
		for item, count in pairs(buy) do
			input.buy[item] = count
		end
	end
	for _, craft in ipairs(plan.crafts) do
		if craft.subcrafts and #craft.subcrafts > 0 then
			return nil, "subcraft requires an inventory transition"
		end
		local schematic = C_TradeSkillUI.GetRecipeSchematic(craft.recipeID, false)
		if not schematic or not schematic.reagentSlotSchematics then
			return nil, "live deterministic schematic unavailable"
		end
		if
			not schematic.quantityMin
			or not schematic.quantityMax
			or schematic.quantityMin ~= schematic.quantityMax
			or schematic.quantityMin <= 0
		then
			return nil, "deterministic output not established"
		end
		local output = schematic.outputItemID
		if not output or output <= 0 then
			return nil, "item output not established"
		end
		outputs[output] = true
		local liveUse = {}
		for _, slot in ipairs(schematic.reagentSlotSchematics) do
			if slot.reagentType ~= Enum.CraftingReagentType.Basic or not slot.reagents or #slot.reagents ~= 1 then
				return nil, "reagent choices require an inventory transition"
			end
			local item = slot.reagents[1].itemID
			if not item or not slot.quantityRequired then
				return nil, "live reagent quantity unavailable"
			end
			liveUse[item] = (liveUse[item] or 0) + slot.quantityRequired
		end
		local reagents = ns.Reagents(craft.recipeID)
		if not reagents then
			return nil, "reagents unavailable"
		end
		local use = {}
		for _, reagent in ipairs(reagents) do
			local item = reagent.itemID
			use[item] = (use[item] or 0) + reagent.quantity
			consumed[item] = true
			if input.held[item] == nil then
				local count, reason = RouteDemand.Count(item, true)
				if count == nil then
					return nil, reason
				end
				input.held[item] = count
			end
		end
		for item, count in pairs(liveUse) do
			if use[item] ~= count then
				return nil, "reagent producer differs from live schematic"
			end
		end
		for item, count in pairs(use) do
			if liveUse[item] ~= count then
				return nil, "reagent producer differs from live schematic"
			end
		end
		local thresholds = ns.Model.Get(craft.recipeID)
		local copy
		if thresholds then
			copy = { thresholds[1], thresholds[2], thresholds[3], thresholds[4] }
		end
		input.legs[#input.legs + 1] = {
			-- Model.Get thresholds and Model.Chance use effective skill. Preserve
			-- each final rank boundary while translating Plan's base intervals.
			fromSkill = craft.from + plan.profession.modifier,
			toSkill = craft.to + plan.profession.modifier,
			thresholds = copy,
			skillUps = ns.RecipeSkillUps(craft.recipeID),
			use = use,
			rawConsumption = true,
			deterministicOutput = true,
		}
	end
	for item in pairs(outputs) do
		if consumed[item] then
			return nil, "route output reuse requires an inventory transition"
		end
	end
	return input
end

-- Called by Plan's existing cache owners on plans/replan/bags invalidation,
-- and by the caller when replacing its explicit basket. It revokes completed
-- results too: a formerly valid bag snapshot is not a current certificate.
function RouteDemand.Invalidate()
	for _, config in pairs(configured) do
		config.dirty = true
	end
	local published = false
	for job in pairs(jobs) do
		job:Cancel()
	end
	for job, plan in pairs(supplyPlans) do
		if plan.supply and plan.supply.job == job then
			published = published or plan.supply.items ~= nil
			plan.supply = nil
		end
		supplyPlans[job] = nil
	end
	if published then
		ns.Changed("supply")
	end
end

---@param plan SkillUpPlan
---@param buy table<integer, integer>
---@return SkillUpJointDemandJob
function RouteDemand.Start(plan, buy)
	local input, reason = RouteDemand.Snapshot(plan, buy)
	local inner = input and ns.Demand.Start(input)
	local revision = ns.Model.ChanceRevision()
	---@type SkillUpJointDemandResult
	local rejected = {
		status = "unknown",
		supported = false,
		coverageKnown = false,
		costKnown = false,
		reasons = reason and { reason, COST_REASON } or { COST_REASON },
	}
	---@param self SkillUpJointDemandJob
	local function Cancel(self)
		if inner then
			inner:Cancel()
		end
		self.result = {
			status = "cancelled",
			supported = self.result.supported,
			coverageKnown = false,
			costKnown = false,
			reasons = { "route, inventory or basket snapshot invalidated" },
		}
		jobs[self] = nil
	end
	---@param self SkillUpJointDemandJob
	---@param work integer
	local function Advance(self, work)
		if revision ~= ns.Model.ChanceRevision() and self.result.status ~= "cancelled" then
			Cancel(self)
		end
		if inner and self.result.status == "calculating" then
			self.result = inner:Advance(work)
			self.result.costKnown = false
			self.result.costCopper = nil
			if self.result.reasons[#self.result.reasons] ~= COST_REASON then
				self.result.reasons[#self.result.reasons + 1] = COST_REASON
			end
		end
		return self.result
	end
	local job = { result = inner and inner.result or rejected, Advance = Advance, Cancel = Cancel }
	if inner then
		job.result.reasons[#job.result.reasons + 1] = COST_REASON
	end
	jobs[job] = true
	return job
end

-- Copy the bounded record/array/map schema before any asynchronous solver read.
-- Lua strings are immutable and shared. Five levels cover route/legs/leg/use;
-- deeper tables and metatables are outside the declared policy schema.
---@param contract SkillUpResupplyInput
---@return SkillUpResupplyInput?
---@return string?
local function FreezePolicy(contract)
	if
		type(contract) ~= "table"
		or getmetatable(contract) ~= nil
		or type(contract.options) ~= "table"
		or getmetatable(contract.options) ~= nil
	then
		return nil, "plain policy records and options required"
	end
	local limit = type(contract) == "table" and type(contract.options) == "table" and contract.options.workLimit
	if type(limit) ~= "number" or limit < 1 or limit > 2 ^ 52 - 1 or limit % 1 ~= 0 then
		return nil, "explicit snapshot operation budget required"
	end
	local count, memo, visiting = 0, {}, {}
	local function Copy(value, depth)
		count = count + 1
		if count > limit then
			error("policy snapshot operation budget exhausted", 0)
		end
		if type(value) ~= "table" then
			if type(value) ~= "number" and type(value) ~= "string" and type(value) ~= "boolean" and value ~= nil then
				error("policy snapshot requires plain records", 0)
			end
			return value
		end
		if getmetatable(value) ~= nil or depth > 5 or visiting[value] then
			error("policy snapshot requires acyclic plain schema records", 0)
		end
		if memo[value] then
			return memo[value]
		end
		local result = {}
		memo[value], visiting[value] = result, true
		for key, field in pairs(value) do
			if type(key) ~= "number" and type(key) ~= "string" then
				error("policy snapshot requires scalar keys", 0)
			end
			result[key] = Copy(field, depth + 1)
		end
		visiting[value] = nil
		return result
	end
	-- The final live plan owns route data; a caller cannot replace it.
	local record = {}
	for key, value in pairs(contract) do
		count = count + 1
		if count > limit then
			return nil, "policy snapshot operation budget exhausted"
		end
		if key ~= "route" then
			record[key] = value
		end
	end
	local ok, frozen = pcall(Copy, record, 1)
	if not ok then
		return nil, tostring(frozen)
	end
	return frozen
end

---@param reason string
---@return SkillUpResupplyJob
local function RejectedPolicy(reason)
	local result = { status = "unknown", costKnown = false, reasons = { reason } }
	local function Cancel(self)
		self.result = { status = "cancelled", costKnown = false, reasons = { "policy snapshot invalidated" } }
	end
	return {
		result = result,
		Cancel = Cancel,
		Advance = function(self)
			return self.result
		end,
	}
end

---@param reason string
---@return SkillUpSupplyChoiceJob
local function RejectedChoice(reason)
	---@type SkillUpSupplyChoiceResult
	local result = { status = "unknown", costKnown = false, reasons = { reason } }
	return {
		result = result,
		Advance = function(self)
			return self.result
		end,
		Cancel = function(self)
			self.result = { status = "cancelled", costKnown = false, reasons = { "supply choice invalidated" } }
		end,
	}
end

-- This remains CONDITIONAL on the caller's explicit future source/price/stock
-- laws. Only balances and route inputs are read live here. Merchant observation
-- maxima, historical quotes and absent costs never populate a policy law.
---@param plan SkillUpPlan
---@param contract SkillUpResupplyInput
---@param alpha number? Explicit when selecting initial orders.
---@return SkillUpResupplyJob|SkillUpSupplyChoiceJob
function RouteDemand.StartPolicy(plan, contract, alpha)
	local frozen, reason = FreezePolicy(contract)
	if not frozen then
		return RejectedPolicy(assert(reason))
	end
	local route, routeReason = RouteDemand.Snapshot(plan, {})
	if not route then
		return RejectedPolicy(assert(routeReason))
	end
	frozen.route, frozen.currencies = route, {}
	if type(GetMoney) ~= "function" then
		return RejectedPolicy("current wallet capability unavailable")
	end
	local ok, raw = pcall(GetMoney)
	local wallet = ok and ns.Readable(raw)
	if type(wallet) ~= "number" or wallet < 0 or wallet > 2 ^ 52 - 1 or wallet % 1 ~= 0 then
		return RejectedPolicy("current wallet quantity unavailable")
	end
	frozen.walletCopper = wallet
	if type(frozen.sources) ~= "table" then
		return RejectedPolicy("explicit source laws required")
	end
	for _, source in ipairs(frozen.sources) do
		if type(source) ~= "table" or type(source.costs) ~= "table" then
			return RejectedPolicy("complete typed source requirements required")
		end
		for key in pairs(source.costs) do
			local kind, id
			if type(key) == "string" then
				kind, id = key:match("^(%a+):(%d+)$")
			end
			local number = id and tonumber(id)
			if
				not number
				or number <= 0
				or number > 2 ^ 52 - 1
				or number % 1 ~= 0
				or key ~= kind .. ":" .. string.format("%.0f", number)
			then
				return RejectedPolicy("canonical typed source requirement required")
			end
			if kind == "item" then
				local total, totalReason = RouteDemand.Count(number, true)
				local bags, bagsReason = RouteDemand.Count(number, false)
				if total == nil or bags == nil then
					return RejectedPolicy(totalReason or assert(bagsReason))
				end
				if total ~= bags then
					return RejectedPolicy("bank token inventory requires a location transition")
				end
				route.held[number] = total
			elseif kind == "currency" then
				local api = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
				if type(api) ~= "function" then
					return RejectedPolicy("current currency capability unavailable")
				end
				local readable, info = pcall(api, number)
				info = readable and ns.Readable(info)
				local amount = type(info) == "table" and ns.Readable(info.quantity)
				if type(amount) ~= "number" or amount < 0 or amount > 2 ^ 52 - 1 or amount % 1 ~= 0 then
					return RejectedPolicy("current currency quantity unavailable")
				end
				frozen.currencies[number] = amount
			else
				return RejectedPolicy("typed source requirement unavailable")
			end
		end
	end
	local job = alpha ~= nil and ns.SupplyChoice.Start(frozen, alpha) or ns.Resupply.Start(frozen)
	jobs[job] = true
	return job
end

-- One owner publishes the selected starting inventory budget. No getter starts
-- or advances a solve. A missing explicit policy leaves the legacy estimates
-- intact, without giving them a coverage or economic certificate.
---@param plan SkillUpPlan
---@param contract SkillUpResupplyInput
---@param alpha number
---@return SkillUpSupplyChoiceJob
function RouteDemand.SelectSupply(plan, contract, alpha)
	local replaced = plan.supply and plan.supply.items ~= nil
	if plan.supply then
		local old = plan.supply.job
		old:Cancel()
		supplyPlans[old] = nil
	end
	local job = alpha ~= nil and RouteDemand.StartPolicy(plan, contract, alpha)
		or RejectedPolicy("explicit starting coverage required")
	---@cast job SkillUpSupplyChoiceJob
	plan.supply = { job = job, revision = ns.Model.ChanceRevision() }
	supplyPlans[job] = plan
	local cancel = job.Cancel
	job.Cancel = function(self)
		cancel(self)
		supplyPlans[self] = nil
		if plan.supply and plan.supply.job == self then
			local published = plan.supply.items ~= nil
			plan.supply = nil
			if published then
				ns.Changed("supply")
			end
		end
	end
	if replaced then
		ns.Changed("supply")
	end
	return job
end

-- The source owner must return a fresh complete contract on each revision.
-- Copying a finite stock record across purchases would silently replenish it.
-- The reader may return nil when current/future laws are no longer established.
---@param skillLine integer
---@param read (fun(): SkillUpResupplyInput?, string?)? nil removes the configuration.
---@param alpha number?
---@return boolean
---@return string?
function RouteDemand.ConfigureSupply(skillLine, read, alpha)
	if type(skillLine) ~= "number" or skillLine <= 0 or skillLine > 2 ^ 52 - 1 or skillLine % 1 ~= 0 then
		return false, "explicit profession identity required"
	end
	if read ~= nil and (type(read) ~= "function" or type(alpha) ~= "number" or alpha <= 0 or alpha > 1) then
		return false, "explicit source contract reader and starting coverage required"
	end
	local previous = configured[skillLine]
	if previous and previous.job then
		previous.job:Cancel()
	end
	configured[skillLine] = read and { read = read, alpha = assert(alpha), dirty = true } or nil
	return true
end

---@param plan SkillUpPlan
---@return SkillUpPlanSupply?
function RouteDemand.Supply(plan)
	local supply = plan.supply
	if
		supply
		and supply.revision == ns.Model.ChanceRevision()
		and supply.job.result.status == "complete"
		and supply.items
	then
		return supply
	end
end

-- At most 64 solver operations across all jobs per frame. This is a scheduling
-- budget, not a probability cutoff; exhaustion of a model budget stays unknown.
local supplyFrame = CreateFrame("Frame")
supplyFrame:SetScript("OnUpdate", function()
	if ns.db then
		for skillLine, config in pairs(configured) do
			if config.dirty then
				config.dirty = false
				local profession = ns.RouteProfessions()[skillLine]
				if profession then
					local ok, contract = pcall(config.read)
					local plan = ns.PlanRoute(profession)
					if ok and contract then
						config.job = RouteDemand.SelectSupply(plan, contract, config.alpha)
					else
						local job = RejectedChoice("fresh complete source contract unavailable")
						config.job = job
						plan.supply = { job = job, revision = ns.Model.ChanceRevision() }
					end
				end
				-- Snapshot one configured profession per frame, outside getters.
				break
			end
		end
	end
	local budget = 64
	for job, plan in pairs(supplyPlans) do
		if budget <= 0 then
			break
		end
		if job.result.status == "calculating" then
			job:Advance(budget)
			budget = 0
		end
		local supply = plan.supply
		if supply and supply.job == job and not supply.items and job.result.status == "complete" then
			if job.result.items and job.result.have then
				supply.items, supply.have = job.result.items, job.result.have
				ns.Changed("supply")
			end
		end
	end
end)

-- Explicit current offer selections only. This quotes requirements without
-- certifying starting inventory, source availability or future acquisitions.
-- Retaining an old offer across an update cannot quote the new transient slot.
---@param orders {offer: SkillUpObservedMerchantOffer, bundles: integer}[]
---@return SkillUpMerchantOrderQuote?
---@return string?
function RouteDemand.QuoteOrders(orders)
	local window = ns.MerchantOffers.current
	if not window then
		return nil, "current merchant window required"
	end
	local total = { products = {}, moneyCopper = 0, costs = {} }
	for _, order in ipairs(orders) do
		if window.offers[order.offer.index] ~= order.offer then
			return nil, "merchant offer observation replaced"
		end
		local quote, reason = ns.MerchantOffers.Quote(order.offer, order.bundles)
		if not quote then
			return nil, reason
		end
		local itemID = order.offer.itemID
		if type(itemID) ~= "number" or itemID <= 0 or itemID >= math.huge or itemID % 1 ~= 0 then
			return nil, "product identity unavailable"
		end
		total.products[itemID] = (total.products[itemID] or 0) + quote.units
		total.moneyCopper = total.moneyCopper + quote.moneyCopper
		if total.products[itemID] >= math.huge or total.moneyCopper >= math.huge then
			return nil, "quote arithmetic overflow"
		end
		for key, quantity in pairs(quote.costs) do
			total.costs[key] = (total.costs[key] or 0) + quantity
			if total.costs[key] >= math.huge then
				return nil, "quote arithmetic overflow"
			end
		end
	end
	return total
end

ns.RouteDemand = {
	ConfigureSupply = RouteDemand.ConfigureSupply,
	SelectSupply = RouteDemand.SelectSupply,
	Supply = RouteDemand.Supply,
	Count = RouteDemand.Count,
	StartPolicy = RouteDemand.StartPolicy,
	Snapshot = RouteDemand.Snapshot,
	Start = RouteDemand.Start,
	Invalidate = RouteDemand.Invalidate,
	QuoteOrders = RouteDemand.QuoteOrders,
}

-- RouteDemand owns a certificate over the final plan, inventory and basket. The
-- regular stale graph is the producer seam for all three, so a completed result
-- cannot survive a replan or bag/target change.
ns.WhenStaleObserver("plans", RouteDemand.Invalidate)
ns.WhenStaleObserver("replan", RouteDemand.Invalidate)
ns.WhenStaleObserver("bags", RouteDemand.Invalidate)
ns.WhenStaleObserver("prices", RouteDemand.Invalidate)
ns.WhenStaleObserver("sourceEvidence", RouteDemand.Invalidate)

-- Skill changes need not invalidate Plan's recipe cache. These events revoke
-- the snapshot without changing its route choice or shopping counts.
ns.WhenEvent("SKILL_LINES_CHANGED", function()
	RouteDemand.Invalidate()
end)
ns.WhenEvent("TRADE_SKILL_LIST_UPDATE", function()
	RouteDemand.Invalidate()
end)

-- All resource changes revoke pending AND completed conditional results. The
-- shared Changes frame owns these event registrations, including bank scope.
for _, event in ipairs({
	"PLAYER_MONEY",
	"CURRENCY_DISPLAY_UPDATE",
	"PLAYERBANKSLOTS_CHANGED",
	"BANKFRAME_OPENED",
	"BANKFRAME_CLOSED",
}) do
	ns.WhenEvent(event, function()
		RouteDemand.Invalidate()
	end)
end
