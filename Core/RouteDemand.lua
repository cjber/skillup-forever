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
	ns.NoteItemCount(itemID)
	local ok, raw = pcall(api, itemID, includeBank, false, false, false)
	local count = ok and ns.Readable(raw)
	if type(count) ~= "number" or count < 0 or count > 2 ^ 52 - 1 or count % 1 ~= 0 then
		return nil, "current inventory quantity unavailable"
	end
	return count
end

-- This adapter accepts final Plan output, never CoveredCrafts counts or expanded
-- shopping rows. Its snapshot owns every table read by the asynchronous solver.
---@type table<SkillUpJointDemandJob, integer>
local jobs = setmetatable({}, { __mode = "k" })

---@param plan SkillUpPlan
---@param buy table<integer, integer>
---@param includeBank boolean? Existing callers include bank inventory.
---@param tick (fun())? Shares snapshot work with a solver budget.
---@param deferInventory boolean? Collect route coordinates before reading balances.
---@return SkillUpJointDemandInput?
---@return string?
function RouteDemand.Snapshot(plan, buy, includeBank, tick, deferInventory)
	includeBank = includeBank ~= false
	tick = tick or function() end
	local legCount, largest = 0, 0
	if type(plan) ~= "table" or type(plan.crafts) ~= "table" then
		return nil, "dense ordered crafts required"
	end
	for key, craft in pairs(plan.crafts) do
		tick()
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
		tick()
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
			tick()
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
			tick()
			local item = reagent.itemID
			use[item] = (use[item] or 0) + reagent.quantity
			consumed[item] = true
			if input.held[item] == nil then
				local count, reason
				if deferInventory then
					count = 0
				else
					count, reason = RouteDemand.Count(item, includeBank)
				end
				if count == nil then
					return nil, reason
				end
				input.held[item] = count
			end
		end
		for item, count in pairs(liveUse) do
			tick()
			if use[item] ~= count then
				return nil, "reagent producer differs from live schematic"
			end
		end
		for item, count in pairs(use) do
			tick()
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
		tick()
		if consumed[item] then
			return nil, "route output reuse requires an inventory transition"
		end
	end
	return input
end

-- Called by Plan's existing cache owners on plans/replan/bags invalidation,
-- and by the caller when replacing its explicit basket. It revokes completed
-- results too: a formerly valid bag snapshot is not a current certificate.
---@param revision integer? Only revoke older chance snapshots when supplied by the frame.
function RouteDemand.Invalidate(revision)
	-- Freeze the revoked set before cancellation: callbacks can publish a new
	-- current owner, which does not belong to this invalidation.
	local revoked = {}
	for job, captured in pairs(jobs) do
		if revision == nil or captured ~= revision then
			revoked[job] = true
		end
	end
	for job in pairs(revoked) do
		job:Cancel()
		jobs[job] = nil
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
	jobs[job] = revision
	return job
end

-- Certified coordinates never inherit the display helper's bank scope.
---@param item SkillUpNeededItem
---@return number?
function RouteDemand.Held(item)
	if item.allocatedPrice then
		return item.have
	end
	return ns.Have(item.itemID)
end

-- Purchases arrive in bags, and every row counts bags and bank together. Count each shared holding only once.
---@param tracked SkillUpTracked[]
---@return table<integer, number> missing
function RouteDemand.Shortfalls(tracked)
	local totals = {}
	for _, entry in ipairs(tracked) do
		for _, item in ipairs(entry.items) do
			local total = totals[item.itemID]
			if not total then
				total = { need = 0 }
				totals[item.itemID] = total
			end
			local have = item.allocatedPrice and ns.Have(item.itemID) or RouteDemand.Held(item)
			if have == nil or (total.held ~= nil and total.held ~= have) then
				total.unknown = true
			end
			total.held = have
			total.need = total.need + item.need
		end
	end
	local missing = {}
	for itemID, total in pairs(totals) do
		if not total.unknown then
			missing[itemID] = math.max(0, total.need - total.held)
		end
	end
	return missing
end

-- No supply selection exists, so every plan's status is "unconfigured".
---@param plan SkillUpPlan
---@return SkillUpSupplySummary
---@diagnostic disable-next-line: unused-local
function RouteDemand.Summary(plan) -- luacheck: ignore 212
	return { status = "unconfigured" }
end

-- Whole localized sentences are shared by the route, shopping window and export.
---@param summary SkillUpSupplySummary
---@return string
---@diagnostic disable-next-line: unused-local
function ns.SupplySummaryText(summary) -- luacheck: ignore 212
	return ns.L["Craft counts and shopping quantities are estimates. You may need more reagents."]
end

---@param item SkillUpNeededItem|SkillUpAPIShoppingItem
---@param byTravel boolean?
---@return integer[]
function RouteDemand.Vendors(item, byTravel)
	local vendors = {}
	if item.source == "vendor" then
		local npcID = item.allocatedPrice and item.allocatedPrice.vendor or ns.NearestVendor(item.itemID, byTravel)
		if npcID then
			vendors[1] = npcID
		end
	end
	return vendors
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
	Held = RouteDemand.Held,
	Shortfalls = RouteDemand.Shortfalls,
	Vendors = RouteDemand.Vendors,
	Summary = RouteDemand.Summary,
	Count = RouteDemand.Count,
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
