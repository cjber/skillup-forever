---@type string, SkillUpNamespace
local _, ns = ...

-- Conditional evaluation of ONE declared refill rule, never source discovery
-- or an optimum claim. Every shortage attempts the same atomic batch. The
-- caller explicitly assumes independent additive vendor round trips and known
-- stock/resource/price laws. Current merchant observations do not supply those.
local Resupply = {}
local LIMIT = 2 ^ 52 - 1
local function Integer(x)
	return type(x) == "number" and x >= 0 and x <= LIMIT and x == math.floor(x)
end
local function Money(x)
	return type(x) == "number" and x >= 0 and x < math.huge
end
local function Down(x)
	return math.max(0, x - (math.abs(x) * 2 ^ -50 + 2 ^ -1074))
end
local function Up(x)
	return x + (math.abs(x) * 2 ^ -50 + 2 ^ -1074)
end
---@param reason string
---@return SkillUpResupplyResult
local function Unknown(reason)
	return { status = "unknown", reasons = { reason }, costKnown = false }
end

---@param input SkillUpResupplyInput
---@return SkillUpResupplyJob
function Resupply.Start(input)
	local revision = ns.Model.ChanceRevision()
	---@type SkillUpResupplyResult
	local initial = { status = "calculating", reasons = {}, costKnown = false }
	local operations = 0
	---@type SkillUpJointDemandJob?
	local child
	---@type thread?
	local thread = coroutine.create(function()
		local function Reject(reason)
			error({ resupply = reason }, 0)
		end
		local options = type(input) == "table" and input.options
		if type(options) ~= "table" then
			return Unknown("explicit precision and resource budgets required")
		end
		for _, key in ipairs({ "workLimit", "stateLimit", "coordinateLimit" }) do
			if not Integer(options[key]) or options[key] == 0 then
				return Unknown("positive integer resource budgets required")
			end
		end
		for _, key in ipairs({ "probabilityTolerance", "costTolerance", "visitTolerance" }) do
			if not Money(options[key]) or options[key] == 0 then
				return Unknown("positive finite precision required")
			end
		end
		local function Tick()
			operations = operations + 1
			if operations > options.workLimit then
				Reject("work budget exhausted; no policy certificate")
			end
			coroutine.yield()
		end
		local function Dense(list)
			if type(list) ~= "table" then
				Reject("dense policy records required")
			end
			local count, largest = 0, 0
			for key in pairs(list) do
				if not Integer(key) or key == 0 then
					Reject("dense policy records required")
				end
				count, largest = count + 1, math.max(largest, key)
				Tick()
			end
			if count ~= largest then
				Reject("dense policy records required")
			end
		end
		if input.service ~= "fixed-batch" or input.journey ~= "independent-round-trips" then
			return Unknown("explicit fixed-batch service and journey contract required")
		end
		local stages, held, failure = ns.Demand.Prepare(input.route, Tick)
		if failure then
			return Unknown(failure.reasons[1])
		end
		assert(stages and held)
		for _, count in pairs(input.route.buy) do
			if count ~= 0 then
				return Unknown("initial purchases require feasible bundle orders")
			end
			Tick()
		end
		local pmin = 1
		for _, stage in ipairs(stages) do
			if stage.chance <= 0 then
				return Unknown("zero chance requires a separate absorption proof")
			end
			pmin = math.min(pmin, stage.chance)
			Tick()
		end
		if
			(input.walletCopper ~= "unlimited" and not Integer(input.walletCopper))
			or type(input.currencies) ~= "table"
			or type(input.stock) ~= "table"
		then
			return Unknown("explicit wallet, currencies and stock law required")
		end
		local coordinates, coordinateSet, stocks, stockKeys = {}, {}, {}, {}
		local function Coordinate(key)
			if not coordinateSet[key] then
				coordinates[#coordinates + 1], coordinateSet[key] = key, true
				if #coordinates > options.coordinateLimit then
					Reject("coordinate budget exhausted; no policy certificate")
				end
			end
		end
		local balances = {}
		for item, count in pairs(held) do
			local key = "item:" .. string.format("%.0f", item)
			Coordinate(key)
			balances[key] = count
			Tick()
		end
		for currency, count in pairs(input.currencies) do
			if not Integer(currency) or currency == 0 or not Integer(count) then
				return Unknown("invalid currency balance")
			end
			local key = "currency:" .. string.format("%.0f", currency)
			Coordinate(key)
			balances[key] = count
			Tick()
		end
		for key, amount in pairs(input.stock) do
			if type(key) ~= "string" or (amount ~= "unlimited" and not Integer(amount)) then
				return Unknown("explicit finite stock units or declared unlimited law required")
			end
			stocks[key], stockKeys[#stockKeys + 1] = amount, key
			if #stockKeys > options.coordinateLimit then
				return Unknown("stock coordinate budget exhausted")
			end
			Tick()
		end
		Dense(input.sources)
		---@type SkillUpPolicySource[]
		local sources = {}
		for _, source in ipairs(input.sources) do
			if
				type(source) ~= "table"
				or (source.offerID ~= nil and (type(source.offerID) ~= "string" or source.offerID == ""))
				or (source.npcID ~= nil and (not Integer(source.npcID) or source.npcID == 0))
				or not Integer(source.itemID)
				or source.itemID == 0
				or not Integer(source.bundleUnits)
				or source.bundleUnits == 0
				or not Integer(source.moneyCopper)
				or not Integer(source.maxBundles)
				or source.maxBundles == 0
				or not Integer(source.stockPerBundle)
				or source.stockPerBundle == 0
				or type(source.stockKey) ~= "string"
				or stocks[source.stockKey] == nil
				or type(source.vendor) ~= "string"
				or type(source.access) ~= "boolean"
				or source.priceLaw ~= "fixed"
				or type(source.costs) ~= "table"
			then
				return Unknown("complete explicit source, access, price and stock law required")
			end
			local copy = {
				itemID = source.itemID,
				bundleUnits = source.bundleUnits,
				moneyCopper = source.moneyCopper,
				maxBundles = source.maxBundles,
				stockPerBundle = source.stockPerBundle,
				stockKey = source.stockKey,
				vendor = source.vendor,
				access = source.access,
				priceLaw = "fixed",
				costs = {},
			}
			Coordinate("item:" .. string.format("%.0f", source.itemID))
			for key, amount in pairs(source.costs) do
				-- These are canonical typed IDs, never names or texture identities.
				local kind, id
				if type(key) == "string" then
					kind, id = key:match("^(%a+):(%d+)$")
				end
				if
					(kind ~= "item" and kind ~= "currency")
					or not id
					or tonumber(id) == 0
					or key ~= kind .. ":" .. string.format("%.0f", tonumber(id))
					or not Integer(tonumber(id))
					or not Integer(amount)
					or amount == 0
				then
					return Unknown("canonical typed requirement and positive quantity required")
				end
				Coordinate(key)
				copy.costs[key] = amount
				Tick()
			end
			sources[#sources + 1] = copy
			Tick()
		end
		-- Sorting and key concatenation are bounded by explicit coordinate budgets.
		table.sort(coordinates)
		table.sort(stockKeys)
		local function Add(into, key, amount)
			local value = (into[key] or 0) + amount
			if not Integer(amount) or not Integer(value) then
				Reject("resource arithmetic exceeds exact integer range")
			end
			into[key] = value
		end
		local function Batch(orders, visitCosts)
			Dense(orders)
			if type(visitCosts) ~= "table" or type(input.tokenValues) ~= "table" then
				Reject("explicit visit and token valuations required")
			end
			local batch = { products = {}, costs = {}, stock = {}, money = 0, low = 0, high = 0, visits = 0 }
			local vendors = {}
			for _, order in ipairs(orders) do
				local source
				if type(order) == "table" and Integer(order.source) then
					source = sources[order.source]
				end
				if
					not source
					or not Integer(order.bundles)
					or order.bundles == 0
					or order.bundles > source.maxBundles
				then
					Reject("explicit integer transaction within its declared ceiling required")
				end
				source = assert(source)
				batch.access = batch.access ~= false and source.access
				Add(batch.products, "item:" .. string.format("%.0f", source.itemID), source.bundleUnits * order.bundles)
				Add(batch.stock, source.stockKey, source.stockPerBundle * order.bundles)
				local money = source.moneyCopper * order.bundles
				if not Integer(money) or not Integer(batch.money + money) then
					Reject("money arithmetic exceeds exact integer range")
				end
				batch.money = batch.money + money
				for key, amount in pairs(source.costs) do
					Add(batch.costs, key, amount * order.bundles)
					Tick()
				end
				vendors[source.vendor] = true
				Tick()
			end
			batch.low, batch.high = batch.money, batch.money
			for key, amount in pairs(batch.costs) do
				local value = input.tokenValues[key]
				if not Money(value) then
					Reject("token opportunity value unavailable")
				end
				batch.low = Down(batch.low + Down(amount * value))
				batch.high = Up(batch.high + Up(amount * value))
				Tick()
			end
			for vendor in pairs(vendors) do
				local cost = visitCosts[vendor]
				if not Money(cost) then
					Reject("explicit vendor visit cost unavailable")
				end
				batch.low, batch.high = Down(batch.low + cost), Up(batch.high + cost)
				batch.visits = batch.visits + 1
				Tick()
			end
			if not Money(batch.high) then
				Reject("batch reward overflow")
			end
			return batch
		end
		local first = Batch(input.initialOrders, input.initialVisitCosts)
		local refill = Batch(input.refillOrders, input.refillVisitCosts)
		local function Copy(values)
			local copy = {}
			for key, value in pairs(values) do
				copy[key] = value
				Tick()
			end
			return copy
		end
		---@param state SkillUpPolicyState
		---@param batch SkillUpPolicyBatch
		---@return SkillUpPolicyState?
		local function Acquire(state, batch)
			if batch.access == false or (state.wallet ~= "unlimited" and state.wallet < batch.money) then
				return nil
			end
			for key, amount in pairs(batch.stock) do
				if state.stock[key] ~= "unlimited" and state.stock[key] < amount then
					return nil
				end
				Tick()
			end
			for key, amount in pairs(batch.costs) do
				if (state.balances[key] or 0) < amount then
					return nil
				end
				Tick()
			end
			local next = {
				balances = Copy(state.balances),
				stock = Copy(state.stock),
				wallet = state.wallet == "unlimited" and "unlimited" or state.wallet - batch.money,
			}
			-- Atomic feasibility uses the SAME pre-order balances for every row.
			-- Products from this batch cannot bootstrap payment for another row.
			for key, amount in pairs(batch.costs) do
				next.balances[key] = next.balances[key] - amount
				Tick()
			end
			for key, amount in pairs(batch.products) do
				Add(next.balances, key, amount)
				Tick()
			end
			for key, amount in pairs(batch.stock) do
				if next.stock[key] ~= "unlimited" then
					next.stock[key] = next.stock[key] - amount
				end
				Tick()
			end
			return next
		end
		local start = Acquire({ balances = balances, stock = stocks, wallet = input.walletCopper }, first)
		if not start then
			local rejected = Unknown("declared initial bundle order is infeasible")
			rejected.initialFeasible = false
			return rejected
		end
		-- C0 has no later acquisitions. Initial purchases have already debited
		-- token reagents, shared stock and wallet before this coverage snapshot.
		local items = {}
		for key, amount in pairs(start.balances) do
			local id = key:match("^item:(%d+)$")
			if id then
				items[tonumber(id)] = amount
			end
			Tick()
		end
		child = ns.Demand.Start({ legs = input.route.legs, held = items, buy = {} })
		while child.result.status == "calculating" do
			child:Advance(1)
			Tick()
		end
		local coverage = child.result
		child = nil
		if not coverage.coverageKnown then
			return Unknown("starting-inventory coverage unavailable")
		end
		initial.initialFeasible = true
		initial.coverageLower, initial.coverageUpper = coverage.coverageLower, coverage.coverageUpper
		local costsLow, costsHigh, visitsLow, visitsHigh = first.low, first.high, first.visits, first.visits
		local successLow, successHigh = 0, 0
		local function CanCraft(state, stage)
			for item, amount in pairs(stage.use) do
				if (state.balances["item:" .. string.format("%.0f", item)] or 0) < amount then
					return false
				end
				Tick()
			end
			return true
		end
		local function Key(state, stage)
			local key =
				{ tostring(stage), state.wallet == "unlimited" and "unlimited" or string.format("%.0f", state.wallet) }
			for _, coordinate in ipairs(coordinates) do
				key[#key + 1] = string.format("%.0f", state.balances[coordinate] or 0)
				Tick()
			end
			for _, coordinate in ipairs(stockKeys) do
				local amount = state.stock[coordinate]
				key[#key + 1] = amount == "unlimited" and "unlimited" or string.format("%.0f", amount)
				Tick()
			end
			return table.concat(key, ";")
		end
		-- At most K/pmin expected remaining attempts, plus one potentially
		-- infeasible acquisition. Each attempt triggers at most one fixed batch.
		-- This uniform reward bound certifies the unprocessed probability tail.
		local attemptsBound = Up(Up(#stages) / pmin + 1)
		local tailCost = Up(attemptsBound * refill.high)
		local tailVisits = Up(attemptsBound * refill.visits)
		if not Money(tailCost) or not Money(tailVisits) then
			return Unknown("remaining reward bound overflows")
		end
		local states = { { state = start, stage = 1, low = 1, high = 1 } }
		while true do
			local following, indexed = {}, {}
			local function Enqueue(state, stage, low, high)
				if high == 0 then
					return
				end
				local key = Key(state, stage)
				local existing = indexed[key]
				if existing then
					existing.low, existing.high = Down(existing.low + low), Up(existing.high + high)
				else
					local entry = { state = state, stage = stage, low = low, high = high }
					following[#following + 1], indexed[key] = entry, entry
					if #following > options.stateLimit then
						Reject("state budget exhausted; no policy certificate")
					end
				end
				Tick()
			end
			for _, entry in ipairs(states) do
				---@type SkillUpPolicyState?
				local state = entry.state
				local index, low, high = entry.stage, entry.low, entry.high
				if index > #stages then
					successLow, successHigh = Down(successLow + low), Up(successHigh + high)
				else
					local stage = stages[index]
					if not CanCraft(state, stage) then
						state = Acquire(assert(state), refill)
						if state then
							if not CanCraft(state, stage) then
								Reject("fixed refill batch does not enable the next craft")
							end
							costsLow, costsHigh =
								Down(costsLow + Down(low * refill.low)), Up(costsHigh + Up(high * refill.high))
							visitsLow, visitsHigh =
								Down(visitsLow + Down(low * refill.visits)), Up(visitsHigh + Up(high * refill.visits))
						end
					end
					if state then
						local next = { balances = Copy(state.balances), stock = state.stock, wallet = state.wallet }
						for item, amount in pairs(stage.use) do
							local key = "item:" .. string.format("%.0f", item)
							next.balances[key] = next.balances[key] - amount
							Tick()
						end
						Enqueue(next, index + 1, Down(low * stage.chance), Up(high * stage.chance))
						if stage.chance < 1 then
							Enqueue(next, index, Down(low * Down(1 - stage.chance)), Up(high * Up(1 - stage.chance)))
						end
					end
				end
				Tick()
			end
			local mass = 0
			for _, entry in ipairs(following) do
				mass = Up(mass + entry.high)
				Tick()
			end
			---@type SkillUpResupplyResult
			local result = {
				status = "calculating",
				initialFeasible = true,
				reasons = {},
				costKnown = false,
				coverageLower = coverage.coverageLower,
				coverageUpper = coverage.coverageUpper,
				successLower = successLow,
				successUpper = math.min(1, Up(successHigh + mass)),
				costLower = costsLow,
				costUpper = Up(costsHigh + Up(mass * tailCost)),
				visitsLower = visitsLow,
				visitsUpper = Up(visitsHigh + Up(mass * tailVisits)),
			}
			if not Money(result.costUpper) or not Money(result.visitsUpper) then
				return Unknown("reward enclosure overflow")
			end
			if
				result.successUpper - result.successLower <= options.probabilityTolerance
				and result.costUpper - result.costLower <= options.costTolerance
				and result.visitsUpper - result.visitsLower <= options.visitTolerance
			then
				result.status, result.costKnown = "complete", true
				return result
			end
			if #following == 0 then
				return Unknown("requested precision is below arithmetic enclosure")
			end
			states = following
			Tick()
		end
	end)
	---@param self SkillUpResupplyJob
	local function Cancel(self)
		if child then
			child:Cancel()
		end
		thread, child = nil, nil
		self.result = { status = "cancelled", reasons = { "policy snapshot invalidated" }, costKnown = false }
	end
	---@param self SkillUpResupplyJob
	---@param work integer
	local function Advance(self, work)
		assert(Integer(work) and work > 0, "positive integer work budget required")
		if revision ~= ns.Model.ChanceRevision() and self.result.status ~= "cancelled" then
			self:Cancel()
		end
		for _ = 1, work do
			if self.result.status ~= "calculating" then
				break
			end
			local active = assert(thread)
			local ok, result = coroutine.resume(active)
			if not ok then
				if type(result) ~= "table" or not result.resupply then
					error(result)
				end
				self.result, thread = Unknown(result.resupply), nil
				if child then
					child:Cancel()
					child = nil
				end
			elseif coroutine.status(active) == "dead" then
				self.result, thread = result, nil
			end
		end
		return self.result
	end
	return { result = initial, Cancel = Cancel, Advance = Advance }
end
ns.Resupply = { Start = Resupply.Start }
