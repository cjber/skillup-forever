---@type string, SkillUpNamespace
local _, ns = ...

if ns.broken then
	return
end
local RouteDemand = {}

local COST_REASON = "observed expenditure unavailable: feasible source orders not established"

-- This adapter accepts final Plan output, never CoveredCrafts counts or expanded
-- shopping rows. Its snapshot owns every table read by the asynchronous solver.
---@type table<SkillUpJointDemandJob, boolean>
local jobs = setmetatable({}, { __mode = "k" })

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
				input.held[item] = ns.Have(item)
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
	for job in pairs(jobs) do
		job:Cancel()
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
