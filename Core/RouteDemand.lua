---@type string, SkillUpNamespace
local _, ns = ...

if ns.broken then
	return
end
local RouteDemand = {}

local COST_REASON = "observed expenditure unavailable: feasible source orders not established"
local ATOMIC_PURCHASE_REASON = "atomic-purchase-not-executable"
local STALE_ACTION_REASON = "unpublished-or-stale"
local MISSING_ACTION_REASON = "action-unavailable"

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
---@type table<SkillUpJointDemandJob|SkillUpResupplyJob|SkillUpSupplyChoiceJob|SkillUpFiniteSelectionJob, integer>
local jobs = setmetatable({}, { __mode = "k" })
---@type table<SkillUpSupplyChoiceJob|SkillUpFiniteSelectionJob, SkillUpPlan>
local supplyPlans = {}
---@type table<integer, SkillUpSupplyConfiguration>
local configured = {}
-- Intent survives cancellation, so a revoked adaptive owner cannot become an
-- estimated craft. Explicit configuration removal/switching clears this intent.
-- The solver frame runs only while work is pending: shown on the wakes below, hidden by its own
-- handler once no configured snapshot is dirty and no job is still calculating (WFA-13, no idle OnUpdate).
local supplyFrame = CreateFrame("Frame")
supplyFrame:Hide()
local function WakeSupply()
	supplyFrame:Show()
end
-- A chance revision can change without any game event (Model.SetChanceBonus), so its producer wakes the
-- frame; the handler then revokes the old revision's results as before.
ns.Model.OnChanceRevision(WakeSupply)
local adaptiveIntent = setmetatable({}, { __mode = "k" })
local actionRecords = setmetatable({}, { __mode = "k" })
local generation = 0
local configuring = false

local function DetachJob(job)
	local plan = supplyPlans[job]
	supplyPlans[job] = nil
	actionRecords[job] = nil
	jobs[job] = nil
	if plan and plan.supply and plan.supply.job == job then
		plan.supply = nil
		ns.Changed("supply")
	end
end

---@generic T
---@param value T
---@return T
local function CopyAction(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, field in pairs(value) do
		result[key] = CopyAction(field)
	end
	return result
end

---@param plan SkillUpPlan
---@param buy table<integer, integer>
---@param includeBank boolean? Existing callers include bank inventory.
---@param tick (fun())? Adaptive callers share snapshot work with the solver budget.
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
	for _, config in pairs(configured) do
		config.dirty = true
	end
	WakeSupply()
	-- Freeze the revoked set before cancellation: callbacks can publish a new
	-- current owner, which does not belong to this invalidation.
	local revoked = {}
	for job, captured in pairs(jobs) do
		if revision == nil or captured ~= revision then
			revoked[job] = true
		end
	end
	for job, plan in pairs(supplyPlans) do
		if revision == nil or (plan.supply and plan.supply.job == job and plan.supply.revision ~= revision) then
			revoked[job] = true
		end
	end
	for job in pairs(revoked) do
		job:Cancel()
		jobs[job], supplyPlans[job] = nil, nil
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
	local revision = ns.Model.ChanceRevision()
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
	jobs[job] = revision
	return job
end

-- Opt-in native adapter. The request and plan remain immutable until snapshot
-- completion; invalidation revokes both partial and completed certificates.
-- Every traversal and native read yields under the caller's Advance budget.
---@param plan SkillUpPlan
---@param request SkillUpAdaptiveSupplyRequest
---@param alpha number
---@return SkillUpFiniteSelectionJob
function RouteDemand.StartAdaptive(plan, request, alpha)
	local revision = ns.Model.ChanceRevision()
	local recipeRevision = ns.RecipeEvidence.Revision()
	---@type SkillUpFiniteSelectionJob?
	local inner
	---@type SkillUpFiniteSelectionJob
	local job
	local function Unknown(reason)
		return { status = "unknown", costKnown = false, reasons = { reason } }
	end
	---@type thread?
	local thread = coroutine.create(function()
		local function Reject(reason)
			error({ adaptiveSnapshot = reason }, 0)
		end
		if type(request) ~= "table" or getmetatable(request) ~= nil or request.inventoryScope ~= "bags-only" then
			return Unknown("explicit bags-only inventory scope required")
		end
		if type(alpha) ~= "number" or not (alpha >= 0 and alpha <= 1) then
			return Unknown("explicit starting coverage in [0,1] required")
		end
		local input = request.policy
		if
			type(input) ~= "table"
			or getmetatable(input) ~= nil
			or type(input.options) ~= "table"
			or getmetatable(input.options) ~= nil
		then
			return Unknown("plain adaptive policy and resource budgets required")
		end
		local limit, coordinateLimit = input.options.workLimit, input.options.coordinateLimit
		local function Integer(value)
			return type(value) == "number" and value >= 0 and value <= 2 ^ 52 - 1 and value % 1 == 0
		end
		if not Integer(limit) or limit == 0 or not Integer(coordinateLimit) or coordinateLimit == 0 then
			return Unknown("positive finite snapshot work and coordinate budgets required")
		end
		local work = 0
		local function Tick()
			work = work + 1
			if work > limit then
				Reject("adaptive snapshot work budget exhausted; no certificate")
			end
			coroutine.yield()
		end
		for key in pairs(request) do
			Tick()
			if key ~= "inventoryScope" and key ~= "policy" and key ~= "crafted" then
				Reject("unsupported adaptive snapshot request field")
			end
		end
		-- Explicit stack: work bounds copying and nesting, without a recursive
		-- Lua stack limit or a fitted schema-depth cutoff. Active ancestors reject
		-- cycles; repeated acyclic tables receive separate owned copies.
		local function Copy(value)
			local function Plain(field)
				if type(field) == "table" then
					if getmetatable(field) ~= nil then
						Reject("adaptive snapshot requires plain records")
					end
				elseif
					type(field) ~= "string"
					and type(field) ~= "number"
					and type(field) ~= "boolean"
					and field ~= nil
				then
					Reject("adaptive snapshot requires plain records")
				end
			end
			Tick()
			Plain(value)
			if type(value) ~= "table" then
				return value
			end
			local result, visiting = {}, { [value] = true }
			local stack = { { input = value, output = result } }
			while #stack > 0 do
				Tick()
				local frame = stack[#stack]
				local key, field = next(frame.input, frame.key)
				frame.key = key
				if key == nil then
					visiting[frame.input], stack[#stack] = nil, nil
				else
					if type(key) ~= "number" and type(key) ~= "string" then
						Reject("adaptive snapshot requires scalar keys")
					end
					Plain(field)
					if type(field) == "table" then
						if visiting[field] then
							Reject("adaptive snapshot requires acyclic plain records")
						end
						local child = {}
						frame.output[key], visiting[field] = child, true
						stack[#stack + 1] = { input = field, output = child }
					else
						frame.output[key] = field
					end
				end
			end
			return result
		end
		local frozen = {}
		for key, value in pairs(input) do
			Tick()
			if type(key) ~= "string" then
				Reject("adaptive policy requires string fields")
			end
			if key ~= "route" then
				frozen[key] = Copy(value)
			end
		end
		local route, reason, recipeEvidence
		if request.crafted ~= nil then
			route, reason, recipeEvidence = ns.RecipeEvidence.Snapshot(plan, Copy(request.crafted), Tick)
		else
			route, reason = RouteDemand.Snapshot(plan, {}, false, Tick, true)
		end
		if not route then
			return Unknown(assert(reason))
		end
		local coordinates, count = {}, 0
		local function Coordinate(kind, id)
			Tick()
			if (kind ~= "item" and kind ~= "currency") or not Integer(id) or id == 0 then
				Reject("canonical typed inventory coordinate required")
			end
			local key = kind .. ":" .. string.format("%.0f", id)
			if not coordinates[key] then
				count = count + 1
				if count > coordinateLimit then
					Reject("adaptive snapshot coordinate budget exhausted")
				end
				coordinates[key] = { kind = kind, id = id }
			end
		end
		local function Typed(key)
			local kind, text
			if type(key) == "string" then
				kind, text = key:match("^(%a+):(%d+)$")
			end
			local id = text and tonumber(text)
			if not Integer(id) or id == 0 or key ~= kind .. ":" .. string.format("%.0f", id) then
				Reject("canonical typed inventory coordinate required")
			end
			Coordinate(kind, id)
		end
		for id in pairs(route.held) do
			Coordinate("item", id)
		end
		if
			type(frozen.sources) ~= "table"
			or type(frozen.currencies) ~= "table"
			or type(frozen.tokenValues) ~= "table"
			or type(frozen.terminalCarry) ~= "table"
		then
			return Unknown("complete modeled inventory coordinate maps required")
		end
		for _, source in pairs(frozen.sources) do
			Tick()
			if type(source) ~= "table" or type(source.costs) ~= "table" then
				Reject("complete typed source records required")
			end
			Coordinate("item", source.itemID)
			for key in pairs(source.costs) do
				Typed(key)
			end
		end
		for id in pairs(frozen.currencies) do
			Coordinate("currency", id)
		end
		for key in pairs(frozen.tokenValues) do
			Typed(key)
		end
		for key in pairs(frozen.terminalCarry) do
			Typed(key)
		end
		-- Native quantities replace every caller balance, including unused source
		-- products and valuation-only coordinates. No bank withdrawal is implied.
		route.held, frozen.currencies = {}, {}
		for _, coordinate in pairs(coordinates) do
			Tick()
			if coordinate.kind == "item" then
				local quantity, why = RouteDemand.Count(coordinate.id, false)
				if quantity == nil then
					return Unknown(assert(why))
				end
				route.held[coordinate.id] = quantity
			else
				local api = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
				if type(api) ~= "function" then
					return Unknown("current currency capability unavailable")
				end
				local ok, info = pcall(api, coordinate.id)
				info = ok and ns.Readable(info)
				local quantity = type(info) == "table" and ns.Readable(info.quantity)
				if not Integer(quantity) then
					return Unknown("current currency quantity unavailable")
				end
				frozen.currencies[coordinate.id] = quantity
			end
		end
		Tick()
		if type(GetMoney) ~= "function" then
			return Unknown("current wallet capability unavailable")
		end
		local ok, raw = pcall(GetMoney)
		local wallet = ok and ns.Readable(raw)
		if not Integer(wallet) then
			return Unknown("current wallet quantity unavailable")
		end
		frozen.route, frozen.walletCopper = route, wallet
		---@cast frozen SkillUpFiniteAcquisitionInput
		inner = ns.FiniteAcquisition.Select(frozen, alpha)
		while inner.result.status == "calculating" do
			Tick()
			inner:Advance(1)
		end
		inner.result.service = "adaptive-finite"
		inner.result.inventoryScope = "bags-only"
		if request.crafted ~= nil then
			inner.result.recipeRevision = recipeRevision
			inner.result.recipeScope = "declared-finite-recipes"
			inner.result.recipeEvidence = recipeEvidence
		end
		if inner.result.status == "complete" then
			local result, certificate = inner.result, inner.result.certificate
			local function Unsupported(code)
				return { kind = "unsupported", reason = code }
			end
			local action = Unsupported("economic-root-missing")
			if certificate and certificate.kind == "finite-dag-exhaustive" then
				local rows = {}
				for _, row in ipairs(certificate.policy) do
					Tick()
					if rows[row.state] then
						Reject("duplicate policy state")
					end
					rows[row.state] = row
				end
				for _, row in pairs(rows) do
					Tick()
					for _, edge in ipairs(row.successors) do
						Tick()
						if not rows[edge.state] then
							Reject("policy successor missing")
						end
					end
				end
				local row = rows[certificate.initialState]
				local orders = result.orders
				local initial = orders and #orders > 0
				if initial or (row and row.kind == "acquire") then
					orders = initial and orders or row.orders
					action = {
						kind = "purchase",
						phase = initial and "initial" or "continuation",
						atomic = true,
						executable = false,
						orders = {},
						reason = ATOMIC_PURCHASE_REASON,
						visits = Copy(
							initial and certificate.laws.initialVisitMoney or certificate.laws.refillVisitMoney
						),
						visitValues = Copy(
							initial and certificate.laws.initialVisitValue or certificate.laws.refillVisitValue
						),
						assumptions = Copy(result.assumptions),
					}
					for _, order in ipairs(orders) do
						Tick()
						local source = certificate.sources[order.source]
						if not source then
							Reject("purchase source binding missing")
						end
						action.orders[#action.orders + 1] = {
							source = order.source,
							bundles = order.bundles,
							binding = Copy(source),
						}
					end
				elseif row and row.kind == "craft" then
					local recipe = certificate.recipes and certificate.recipes[row.recipeID]
					if recipe and recipe.role == row.role then
						action =
							{ kind = "craft", recipeID = row.recipeID, role = row.role, count = 1, executable = false }
					else
						action = Unsupported("recipe-binding-missing")
					end
				elseif row and (row.kind == "stop" or row.kind == "complete") then
					action = { kind = "stop", reason = row.kind == "complete" and "complete" or "economic-stop" }
				end
				action.state = initial and certificate.preInitialState or certificate.initialState
				action.resources = Copy(initial and certificate.preInitialResources or certificate.initialResources)
				action.coordinates, action.pools = Copy(certificate.coordinates), Copy(certificate.pools)
				action.postInitialState = initial and certificate.initialState or nil
			end
			action.conditional, action.inventoryScope = true, "bags-only"
			action.sourceRevision, action.recipeRevision = result.sourceRevision, result.recipeRevision
			actionRecords[job] = action
		end
		return inner.result
	end)
	local function Cancel(self)
		thread = nil
		if inner then
			inner:Cancel()
		end
		self.result = {
			status = "cancelled",
			costKnown = false,
			reasons = { "adaptive inventory or source snapshot invalidated" },
		}
	end
	local function Advance(self, budget)
		if revision ~= ns.Model.ChanceRevision() or not ns.RecipeEvidence.Current(recipeRevision) then
			Cancel(self)
		end
		if type(budget) ~= "number" or budget < 1 or budget > 2 ^ 52 - 1 or budget % 1 ~= 0 then
			return self.result
		end
		for _ = 1, budget do
			local active = thread
			if not active then
				break
			end
			local ok, result = coroutine.resume(active)
			if revision ~= ns.Model.ChanceRevision() or not ns.RecipeEvidence.Current(recipeRevision) then
				Cancel(self)
			end
			if thread ~= active then
				return self.result
			end
			if not ok then
				thread = nil
				if inner then
					inner:Cancel()
				end
				self.result = Unknown(type(result) == "table" and result.adaptiveSnapshot or "adaptive snapshot failed")
			elseif coroutine.status(active) == "dead" then
				thread, self.result = nil, result
			end
		end
		return self.result
	end
	job = { result = { status = "calculating", costKnown = false, reasons = {} }, Advance = Advance, Cancel = Cancel }
	jobs[job] = revision
	return job
end

-- One owner publishes the selected starting inventory budget. No getter starts
-- or advances a solve. A missing explicit policy leaves the legacy estimates
-- intact, without giving them a coverage or economic certificate.
---@param plan SkillUpPlan
---@param job SkillUpSupplyChoiceJob|SkillUpFiniteSelectionJob
---@return SkillUpSupplyChoiceJob|SkillUpFiniteSelectionJob
local function PublishSupply(plan, job, alpha, service)
	local previous = plan.supply
	if previous then
		local old = previous.job
		old:Cancel()
		supplyPlans[old] = nil
		if plan.supply and plan.supply ~= previous then
			job:Cancel()
			return job
		end
	end
	generation = generation + 1
	plan.supply = {
		generation = generation,
		configuration = configured[plan.profession.skillLine],
		job = job,
		revision = ns.Model.ChanceRevision(),
		alpha = alpha,
		service = service,
	}
	supplyPlans[job] = plan
	WakeSupply()
	local cancel = job.Cancel
	job.Cancel = function(self)
		local ok, reason = pcall(cancel, self)
		supplyPlans[self] = nil
		if plan.supply and plan.supply.job == self then
			plan.supply = nil
			ns.Changed("supply")
		end
		if not ok then
			error(reason, 0)
		end
	end
	ns.Changed("supply")
	return job
end

---@param plan SkillUpPlan
---@param contract SkillUpResupplyInput
---@param alpha number
---@return SkillUpSupplyChoiceJob
function RouteDemand.SelectSupply(plan, contract, alpha)
	local skillLine = plan.profession.skillLine
	local previous = configured[skillLine]
	local owner = plan.supply
	local job = alpha ~= nil and RouteDemand.StartPolicy(plan, contract, alpha)
		or RejectedPolicy("explicit starting coverage required")
	---@cast job SkillUpSupplyChoiceJob
	if previous and previous.mode == "adaptive" then
		if previous.job then
			previous.job:Cancel()
		end
		-- Cancellation callbacks may install a new configuration or direct owner.
		-- That replacement wins; the outer fixed switch must not clear its intent.
		if configured[skillLine] ~= previous or (plan.supply and plan.supply ~= owner) then
			job:Cancel()
			return job
		end
		configured[skillLine] = nil
	end
	adaptiveIntent[skillLine or plan] = nil
	PublishSupply(plan, job, alpha, "fixed-batch")
	return job
end

-- The source owner must return a fresh complete contract on each revision.
-- Copying a finite stock record across purchases would silently replenish it.
-- The reader may return nil when current/future laws are no longer established.
---@param skillLine integer
---@param read (fun(): SkillUpResupplyInput|SkillUpAdaptiveSupplyRequest|nil, string?)? nil removes either mode.
---@param alpha number?
---@param mode 'fixed'|'adaptive'
---@return boolean
---@return string?
local function Configure(skillLine, read, alpha, mode)
	if configuring then
		return false, "configuration reentrant"
	end
	if type(skillLine) ~= "number" or skillLine <= 0 or skillLine > 2 ^ 52 - 1 or skillLine % 1 ~= 0 then
		return false, "explicit profession identity required"
	end
	if
		read ~= nil
		and (
			type(read) ~= "function"
			or type(alpha) ~= "number"
			or not (alpha >= 0 and alpha <= 1 and (mode == "adaptive" or alpha > 0))
		)
	then
		return false, "explicit source contract reader and starting coverage required"
	end
	local previous = configured[skillLine]
	local nextConfiguration = read and { read = read, alpha = assert(alpha), mode = mode, dirty = true } or nil
	configuring = true
	configured[skillLine] = nextConfiguration
	adaptiveIntent[skillLine] = nil
	if previous and previous.job then
		-- Cancellation is the final commit step.  A broken old job must not
		-- turn a committed replacement into a rejected ApplyDraft: its inner
		-- solver cannot be revived safely after Cancel has started.
		pcall(previous.job.Cancel, previous.job)
		DetachJob(previous.job)
	end
	configuring = false
	if nextConfiguration then
		WakeSupply()
	end
	-- The API's answers read this configuration and its cache drops on a change, so a read straight after this
	-- call sees the new mode rather than the one from before it.
	if previous or nextConfiguration then
		ns.Changed("supply")
	end
	return true
end

---@param skillLine integer
---@param read (fun(): SkillUpResupplyInput?, string?)?
---@param alpha number?
---@return boolean, string?
function RouteDemand.ConfigureSupply(skillLine, read, alpha)
	return Configure(skillLine, read, alpha, "fixed")
end

---@param skillLine integer
---@param read (fun(): SkillUpAdaptiveSupplyRequest?, string?)?
---@param alpha number?
---@return boolean, string?
function RouteDemand.ConfigureAdaptiveSupply(skillLine, read, alpha)
	return Configure(skillLine, read, alpha, "adaptive")
end

---@param plan SkillUpPlan
---@param request SkillUpAdaptiveSupplyRequest
---@param alpha number
---@return SkillUpFiniteSelectionJob
function RouteDemand.SelectAdaptiveSupply(plan, request, alpha)
	adaptiveIntent[plan.profession.skillLine or plan] = true
	local job = RouteDemand.StartAdaptive(plan, request, alpha)
	PublishSupply(plan, job, alpha, "adaptive-finite")
	return job
end

-- Certified coordinates never inherit the display helper's bank scope.
---@param item SkillUpNeededItem
---@return integer?
function RouteDemand.Held(item)
	if item.supplyScope then
		return item.have
	end
	return ns.Have(item.itemID)
end

-- Purchases arrive in bags. They must cover total demand across bags and bank,
-- and bags-only demand independently. Count each shared holding only once.
---@param tracked SkillUpTracked[]
---@return table<integer, number> missing
---@return table<integer, boolean> unknown
function RouteDemand.Shortfalls(tracked)
	local totals = {}
	for _, entry in ipairs(tracked) do
		for _, item in ipairs(entry.items) do
			local total = totals[item.itemID]
			if not total then
				total = { need = 0, bagsNeed = 0, held = {} }
				totals[item.itemID] = total
			end
			local scope = item.supplyScope or "bags-and-bank"
			local have = RouteDemand.Held(item)
			if have == nil or (total.held[scope] ~= nil and total.held[scope] ~= have) then
				total.unknown = true
			end
			total.held[scope] = have
			total.need = total.need + item.need
			if scope == "bags-only" then
				total.bagsNeed = total.bagsNeed + item.need
			end
		end
	end
	local missing, unknown = {}, {}
	for itemID, total in pairs(totals) do
		local bags, all = total.held["bags-only"], total.held["bags-and-bank"]
		if total.unknown or (all and bags and all < bags) then
			unknown[itemID] = true
		else
			missing[itemID] = math.max(0, total.need - (all or bags), total.bagsNeed - (bags or 0))
		end
	end
	return missing, unknown
end

---@param plan SkillUpPlan
---@return SkillUpPlanSupply?
function RouteDemand.Supply(plan)
	local supply = plan.supply
	if
		supply
		and supply.revision == ns.Model.ChanceRevision()
		and supply.job.result.status == "complete"
		and (not supply.job.result.recipeRevision or ns.RecipeEvidence.Current(supply.job.result.recipeRevision))
		and supply.items
		and supply.have
	then
		return supply
	end
end

-- A query over the frame-published owner only. No reader, native resource
-- read, graph traversal or reconciliation happens here. Only a freshly solved
-- empty initial basket can use its economic root; purchases stay outstanding.
---@param plan SkillUpPlan
---@return SkillUpNextAction? nil means ordinary estimated mode.
function RouteDemand.NextAction(plan)
	local config = configured[plan.profession.skillLine]
	if not (config and config.mode == "adaptive") and not adaptiveIntent[plan.profession.skillLine or plan] then
		return nil
	end
	local supply = RouteDemand.Supply(plan)
	if
		not supply
		or supply.service ~= "adaptive-finite"
		or (config and (config.dirty or supply.configuration ~= config))
	then
		return {
			kind = "unsupported",
			reason = STALE_ACTION_REASON,
			conditional = true,
			inventoryScope = "bags-only",
		}
	end
	local action = actionRecords[supply.job]
	if not action then
		return { kind = "unsupported", reason = MISSING_ACTION_REASON, conditional = true, inventoryScope = "bags-only" }
	end
	local copy = CopyAction(action)
	copy.generation = supply.generation
	return copy
end

-- Read only: status belongs to the current plan revision, never to a getter's clock.
---@param plan SkillUpPlan
---@return SkillUpSupplySummary
function RouteDemand.Summary(plan)
	local owner = plan.supply
	local config = configured[plan.profession.skillLine]
	if not owner then
		if not config then
			return { status = "unconfigured" }
		end
		return {
			status = not config.dirty and config.job and config.job.result.status == "cancelled" and "cancelled"
				or "calculating",
			alpha = config.alpha,
			conditional = true,
			service = config.mode == "adaptive" and "adaptive-finite" or "fixed-batch",
			inventoryScope = config.mode == "adaptive" and "bags-only" or "bags-and-bank",
		}
	end
	local result = owner.job.result
	local current = owner.revision == ns.Model.ChanceRevision()
		and (not result.recipeRevision or ns.RecipeEvidence.Current(result.recipeRevision))
	local summary = {
		status = current and result.status or "cancelled",
		alpha = owner.alpha,
		service = owner.service,
		inventoryScope = result.inventoryScope
			or (owner.service == "adaptive-finite" and "bags-only" or "bags-and-bank"),
		conditional = true,
	}
	if current and result.status == "complete" and not RouteDemand.Supply(plan) then
		summary.status = "calculating"
	end
	if summary.status == "complete" then
		summary.coverageLower, summary.coverageUpper = result.coverageLower, result.coverageUpper
		summary.successLower, summary.successUpper = result.successLower, result.successUpper
	end
	return summary
end

-- Whole localized sentences are shared by the route, shopping window and export.
---@param summary SkillUpSupplySummary
---@return string
function ns.SupplySummaryText(summary)
	local L = ns.L
	if summary.status == "unconfigured" then
		return L["Craft counts and shopping quantities are estimates. You may need more reagents."]
	end
	local statuses = {
		calculating = L["Supply estimate: calculating."],
		unknown = L["Supply estimate: not enough information."],
		infeasible = L["Supply estimate: no starting purchase meets the target."],
		cancelled = L["Supply estimate: cancelled."],
		complete = L["Supply estimate: ready."],
		unattained = L["Supply estimate: no cheapest purchase exists under these assumptions."],
	}
	local lines = { statuses[summary.status] or L["Supply estimate: not enough information."] }
	if summary.alpha ~= nil then
		lines[#lines + 1] =
			string.format(L["Target chance of finishing with starting supplies: %s%%."], tostring(summary.alpha * 100))
	end
	local function Probability(lower, upper)
		if lower == nil or upper == nil then
			return L["unknown"]
		end
		-- Outward rounding preserves the interval, including bounds very near 0 or 1.
		local low = math.floor(lower * 10000)
		local high = math.ceil(upper * 10000)
		if lower < 1 then
			low = math.min(low, 9999)
		end
		if upper > 0 then
			high = math.max(high, 1)
		end
		return string.format(L["%s%% to %s%%"], string.format("%.2f", low / 100), string.format("%.2f", high / 100))
	end
	if summary.status == "complete" then
		lines[#lines + 1] = string.format(
			L["Chance of finishing with starting supplies: %s."],
			Probability(summary.coverageLower, summary.coverageUpper)
		)
		lines[#lines + 1] = string.format(
			L["Chance of finishing with later purchases: %s."],
			Probability(summary.successLower, summary.successUpper)
		)
	end
	if summary.inventoryScope then
		lines[#lines + 1] = summary.inventoryScope == "bags-only" and L["Starting inventory: bags only."]
			or L["Starting inventory: bags and bank."]
	end
	lines[#lines + 1] =
		L["These chances assume the stated skill-up rates, prices, availability and delivery of later purchases."]
	lines[#lines + 1] = L["Craft counts and shopping quantities are estimates. You may need more reagents."]
	return table.concat(lines, "\n")
end

-- At most 64 solver operations across all jobs per frame. This is a scheduling
-- budget, not a probability cutoff; exhaustion of a model budget stays unknown.
local supplyRevision = ns.Model.ChanceRevision()
supplyFrame:SetScript("OnUpdate", function()
	-- The client build cannot change inside one Lua session (a patch needs a client restart, which reloads
	-- every addon), so checking it on each wake rather than every frame loses no revocation in the game.
	ns.RecipeEvidence.Refresh()
	local revision = ns.Model.ChanceRevision()
	if revision ~= supplyRevision then
		supplyRevision = revision
		RouteDemand.Invalidate(revision)
	end
	if ns.db then
		for skillLine, config in pairs(configured) do
			if config.dirty then
				config.dirty = false
				local profession = ns.RouteProfessions()[skillLine]
				if profession then
					local ok, contract, missing = ns.RecipeEvidence.ReadRequest(config.read)
					local plan = ns.PlanRoute(profession)
					if configured[skillLine] ~= config or config.dirty then
						break
					end
					local job
					if ok and contract then
						if config.mode == "adaptive" then
							---@cast contract SkillUpAdaptiveSupplyRequest
							job = RouteDemand.SelectAdaptiveSupply(plan, contract, config.alpha)
						else
							---@cast contract SkillUpResupplyInput
							job = RouteDemand.SelectSupply(plan, contract, config.alpha)
						end
					else
						job = RejectedChoice(
							ok and type(missing) == "string" and missing or "fresh complete source contract unavailable"
						)
						PublishSupply(
							plan,
							job,
							config.alpha,
							config.mode == "adaptive" and "adaptive-finite" or "fixed-batch"
						)
					end
					if configured[skillLine] == config and not config.dirty then
						config.job = job
					else
						job:Cancel()
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
		local previousStatus = job.result.status
		if previousStatus == "calculating" then
			job:Advance(budget)
			budget = 0
		end
		local supply = plan.supply
		local changed = previousStatus ~= job.result.status
		if supply and supply.job == job and not supply.items and job.result.status == "complete" then
			if job.result.items and job.result.have then
				supply.items, supply.have = job.result.items, job.result.have
				supply.acquisitions = job.result.acquisitions
				supply.initialVisits = job.result.initialVisits
				supply.sourceRevision = job.result.sourceRevision
				supply.assumptions = job.result.assumptions
				supply.result = job.result
				changed = true
			end
		end
		if changed then
			ns.Changed("supply")
		end
	end
	-- A reader can move the chance revision inside this handler, after the check above; its wake finds the frame
	-- already shown, so the frame stays up to revoke that revision on the next frame.
	local pending = ns.Model.ChanceRevision() ~= supplyRevision
	for _, config in pairs(configured) do
		pending = pending or config.dirty == true
	end
	if not pending then
		for job in pairs(supplyPlans) do
			if job.result and job.result.status == "calculating" then
				pending = true
				break
			end
		end
	end
	if not pending then
		supplyFrame:Hide()
	end
end)

-- Conditional rows resolve only their selected NPCs. An unknown NPC or an empty
-- selected order list must never acquire a different vendor through a fallback.
---@param item SkillUpNeededItem|SkillUpAPIShoppingItem
---@param byTravel boolean?
---@return integer[]
function RouteDemand.Vendors(item, byTravel)
	local vendors, seen = {}, {}
	if item.acquisitions then
		for _, acquisition in ipairs(item.acquisitions) do
			local npcID = acquisition.npcID
			if npcID and not seen[npcID] then
				vendors[#vendors + 1], seen[npcID] = npcID, true
			end
		end
	elseif item.source == "vendor" then
		local npcID = ns.NearestVendor(item.itemID, byTravel)
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
	NextAction = RouteDemand.NextAction,
	ConfigureSupply = RouteDemand.ConfigureSupply,
	ConfigureAdaptiveSupply = RouteDemand.ConfigureAdaptiveSupply,
	SelectAdaptiveSupply = RouteDemand.SelectAdaptiveSupply,
	Held = RouteDemand.Held,
	Shortfalls = RouteDemand.Shortfalls,
	Vendors = RouteDemand.Vendors,
	SelectSupply = RouteDemand.SelectSupply,
	Supply = RouteDemand.Supply,
	Summary = RouteDemand.Summary,
	Count = RouteDemand.Count,
	StartPolicy = RouteDemand.StartPolicy,
	StartAdaptive = RouteDemand.StartAdaptive,
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
ns.WhenStaleObserver("recipeEvidence", RouteDemand.Invalidate)

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
