local _, ns = ...
local Demand = {}
ns.Demand = Demand

-- IEEE binary64 outward enclosure. Each elementary operation is widened by
-- more than one ulp, including gradual underflow. Model.Chance's returned
-- binary64 value is the input probability, not an empirical RNG guarantee.
local function Down(x)
	return math.max(0, x - (math.abs(x) * 2 ^ -50 + 2 ^ -1074))
end
local function Up(x)
	return x + (math.abs(x) * 2 ^ -50 + 2 ^ -1074)
end
local function Integer(x)
	return type(x) == "number" and x >= 0 and x <= 2 ^ 52 - 1 and x == math.floor(x)
end
---@return SkillUpJointDemandResult
local function Unknown(reason, supported)
	return { status = "unknown", supported = supported, coverageKnown = false, costKnown = false, reasons = { reason } }
end

-- A copied, fixed ordered route and one shared capacity. No source ranking or
-- inventory expansion is performed here. Work units cover a coordinate or transition; table operations
-- still scale with the explicit input dimension. Callers own scheduling, revision checks and cancellation.
---@param input SkillUpJointDemandInput
---@return SkillUpJointDemandJob
function Demand.Start(input)
	---@type SkillUpJointDemandResult
	local initial = { status = "calculating", supported = true, coverageKnown = false, costKnown = false, reasons = {} }
	local revision = ns.Model.ChanceRevision()
	---@type thread?
	---@type thread?
	local thread = coroutine.create(function()
		local function Tick()
			coroutine.yield()
		end
		-- ipairs stops at the first hole, which must not certify a route prefix.
		if type(input) ~= "table" or type(input.held) ~= "table" or type(input.buy) ~= "table" then
			return Unknown("explicit route, held inventory and basket tables required", false)
		end
		if type(input.legs) ~= "table" then
			return Unknown("dense route legs required", false)
		end
		local legCount, largest = 0, 0
		for key in pairs(input.legs) do
			if not Integer(key) or key < 1 then
				return Unknown("dense route legs required", false)
			end
			legCount, largest = legCount + 1, math.max(largest, key)
			Tick()
		end
		if legCount ~= largest then
			return Unknown("dense route legs required", false)
		end
		local legs, capacity = {}, {}
		for item, held in pairs(input.held) do
			if not Integer(item) or not Integer(held) then
				return Unknown("invalid inventory", false)
			end
			capacity[item] = held
			Tick()
		end
		for item, buy in pairs(input.buy) do
			if not Integer(item) or not Integer(buy) or not Integer((capacity[item] or 0) + buy) then
				return Unknown("invalid basket", false)
			end
			capacity[item] = (capacity[item] or 0) + buy
			Tick()
		end
		for _, leg in ipairs(input.legs) do
			if type(leg) ~= "table" then
				return Unknown("route leg record required", false)
			end
			if leg.rawConsumption ~= true or leg.deterministicOutput ~= true then
				return Unknown("subcraft or random output requires an inventory transition", false)
			end
			if
				not Integer(leg.fromSkill)
				or not Integer(leg.toSkill)
				or leg.toSkill < leg.fromSkill
				or (leg.skillUps ~= nil and (not Integer(leg.skillUps) or leg.skillUps == 0))
			then
				return Unknown("invalid skill interval", false)
			end
			local copy = { fromSkill = leg.fromSkill, toSkill = leg.toSkill, skillUps = leg.skillUps, use = {} }
			if leg.thresholds ~= nil and type(leg.thresholds) ~= "table" then
				return Unknown("invalid thresholds", false)
			end
			if type(leg.use) ~= "table" then
				return Unknown("raw consumption table required", false)
			end
			if leg.thresholds then
				copy.thresholds = {}
				for i = 1, 4 do
					if not Integer(leg.thresholds[i]) then
						return Unknown("invalid thresholds", false)
					end
					copy.thresholds[i] = leg.thresholds[i]
				end
			end
			for item, count in pairs(leg.use) do
				if not Integer(item) or not Integer(count) then
					return Unknown("invalid raw consumption", false)
				end
				if count > 0 then
					copy.use[item] = count
					capacity[item] = capacity[item] or 0
				end
				Tick()
			end
			legs[#legs + 1] = copy
			Tick()
		end
		-- Probability inputs are captured before evaluating any stochastic states.
		local stages = {}
		for _, leg in ipairs(legs) do
			local skill = leg.fromSkill
			while skill < leg.toSkill do
				local stage = ns.Model.DemandStage(leg.thresholds, skill, leg.skillUps, leg.toSkill)
				if not stage or stage.chance == nil then
					return Unknown("missing skill-up chance", true)
				elseif stage.chance <= 0 then
					return {
						status = "unreachable",
						supported = true,
						coverageKnown = true,
						coverageLower = 0,
						coverageUpper = 0,
						costKnown = false,
						reasons = { "zero skill-up chance", "source cost not evaluated" },
					}
				end
				stages[#stages + 1] = { chance = stage.chance, use = leg.use }
				skill = skill + stage.gain
				Tick()
			end
		end
		local items = {}
		for item in pairs(capacity) do
			items[#items + 1] = item
			Tick()
		end
		-- Sorted coordinates give deterministic merging; overflow is an absorbing
		-- failure because this contract has only nonnegative raw consumption.
		table.sort(items)
		local states = { { use = {}, low = 1, high = 1 } }
		for _, stage in ipairs(stages) do
			local following, indexed = {}, {}
			for _, start in ipairs(states) do
				local use, low, high = start.use, start.low, start.high
				while true do
					local nextUse, key, overflow, changes = {}, {}, false, false
					for i, item in ipairs(items) do
						local amount = (use[item] or 0) + (stage.use[item] or 0)
						nextUse[item], key[i] = amount, string.format("%.0f", amount)
						overflow = overflow or amount > capacity[item]
						changes = changes or (stage.use[item] or 0) > 0
						Tick()
					end
					if overflow then
						break
					end
					local name = table.concat(key, ",")
					local dest = indexed[name]
					if not dest then
						dest = { use = nextUse, low = 0, high = 0 }
						indexed[name], following[#following + 1] = dest, dest
					end
					-- Zero consumption aggregates the complete infinite geometric tail.
					dest.low = Down(dest.low + (changes and Down(low * stage.chance) or low))
					dest.high = Up(dest.high + (changes and Up(high * stage.chance) or high))
					Tick()
					if not changes or stage.chance == 1 then
						break
					end
					low = Down(low * Down(1 - stage.chance))
					high = Up(high * Up(1 - stage.chance))
					use = nextUse
				end
			end
			states = following
			Tick()
		end
		local low, high = 0, 0
		for _, state in ipairs(states) do
			low, high = Down(low + state.low), Up(high + state.high)
			Tick()
		end
		return {
			status = "complete",
			supported = true,
			coverageKnown = true,
			coverageLower = low,
			coverageUpper = math.min(1, high),
			costKnown = false,
			reasons = { "source cost not evaluated" },
		}
	end)
	---@param self SkillUpJointDemandJob
	---@param work integer
	---@return SkillUpJointDemandResult
	local function Advance(self, work)
		assert(Integer(work) and work > 0, "positive integer work budget required")
		if self.result.status == "calculating" and revision ~= ns.Model.ChanceRevision() then
			self.result = Unknown("skill-up chance changed; start a new snapshot", true)
			thread = nil
			return self.result
		end
		for _ = 1, work do
			if self.result.status ~= "calculating" then
				break
			end
			local active = assert(thread)
			local ok, result = coroutine.resume(active)
			if not ok then
				error(result)
			end
			if coroutine.status(active) == "dead" then
				self.result = result
				thread = nil
			end
		end
		return self.result
	end
	---@param self SkillUpJointDemandJob
	local function Cancel(self)
		if self.result.status == "calculating" then
			self.result = Unknown("cancelled", true)
			self.result.status = "cancelled"
			thread = nil
		end
	end
	return { result = initial, Advance = Advance, Cancel = Cancel }
end

-- Compare explicit baskets incrementally. The scalar shortfall cost is an
-- explicit caller observation, not a farm-time estimate or a source policy.
---@param input SkillUpJointDemandInput
---@param baskets table<integer, table<integer, integer>>
---@param shortfallCost number
---@param unitCosts table<integer, number>
---@return SkillUpBasketChoiceJob
function Demand.StartBasketChoice(input, baskets, shortfallCost, unitCosts)
	local revision = ns.Model.ChanceRevision()
	---@type SkillUpJointDemandJob?
	local child
	---@type SkillUpBasketChoiceResult
	local initial = { status = "calculating", reasons = {} }
	---@return SkillUpBasketChoiceResult
	local function UnknownChoice(reason)
		return { status = "unknown", reasons = { reason } }
	end
	local function Money(value)
		return type(value) == "number" and value >= 0 and value < math.huge
	end
	---@type thread?
	local thread = coroutine.create(function()
		local function Tick()
			coroutine.yield()
		end
		if type(input) ~= "table" or type(baskets) ~= "table" or type(unitCosts) ~= "table" then
			return UnknownChoice("explicit route, baskets and observed costs required")
		end
		if not Money(shortfallCost) then
			return UnknownChoice("shortfall cost unavailable")
		end
		local count, largest = 0, 0
		for key in pairs(baskets) do
			if not Integer(key) or key < 1 then
				return UnknownChoice("dense basket candidates required")
			end
			count, largest = count + 1, math.max(largest, key)
			Tick()
		end
		if count == 0 or count ~= largest then
			return UnknownChoice("dense basket candidates required")
		end
		---@type SkillUpBasketChoiceResult[]
		local evaluated = {}
		for _, basket in ipairs(baskets) do
			if type(basket) ~= "table" then
				return UnknownChoice("explicit basket required")
			end
			local purchase, purchaseLower, purchaseUpper, copied = 0, 0, 0, {}
			for item, amount in pairs(basket) do
				if not Integer(item) or item < 1 or not Integer(amount) then
					return UnknownChoice("invalid basket quantity")
				end
				if amount > 0 then
					local price = unitCosts[item]
					if not Money(price) then
						return UnknownChoice("observed basket cost unavailable")
					end
					purchase = purchase + amount * price
					purchaseLower = Down(purchaseLower + Down(amount * price))
					purchaseUpper = Up(purchaseUpper + Up(amount * price))
					if not Money(purchaseUpper) then
						return UnknownChoice("basket cost overflow")
					end
					copied[item] = amount
				end
				Tick()
			end
			child = Demand.Start({ legs = input.legs, held = input.held, buy = copied })
			while child.result.status == "calculating" do
				child:Advance(1)
				Tick()
			end
			local result = child.result
			child = nil
			if not result.coverageKnown then
				return UnknownChoice("joint completion probability unavailable")
			end
			local lower = Down(purchaseLower + Down(Down(1 - result.coverageUpper) * shortfallCost))
			local upper = Up(purchaseUpper + Up(Up(1 - result.coverageLower) * shortfallCost))
			if not Money(lower) or not Money(upper) then
				return UnknownChoice("shortfall cost overflow")
			end
			evaluated[#evaluated + 1] = {
				basket = copied,
				purchaseCopper = purchase,
				costLower = lower,
				costUpper = upper,
				coverageLower = result.coverageLower,
				coverageUpper = result.coverageUpper,
			}
			Tick()
		end
		---@type SkillUpBasketChoiceResult?
		local best
		for _, candidate in ipairs(evaluated) do
			if not best or candidate.costUpper < best.costUpper then
				best = candidate
			end
			Tick()
		end
		assert(best)
		for _, candidate in ipairs(evaluated) do
			if candidate ~= best and best.costUpper > candidate.costLower then
				return UnknownChoice("cost bounds overlap; no proven basket choice")
			end
			Tick()
		end
		best.status, best.reasons = "complete", {}
		return best
	end)
	local function Advance(self, work)
		assert(Integer(work) and work > 0, "positive integer work budget required")
		if self.result.status == "calculating" and revision ~= ns.Model.ChanceRevision() then
			if child then
				child:Cancel()
			end
			self.result = UnknownChoice("skill-up chance changed; start a new snapshot")
			thread, child = nil, nil
		end
		for _ = 1, work do
			if self.result.status ~= "calculating" then
				break
			end
			local ok, result = coroutine.resume(assert(thread))
			if not ok then
				error(result)
			end
			if coroutine.status(thread) == "dead" then
				self.result, thread = result, nil
			end
		end
		return self.result
	end
	local function Cancel(self)
		if self.result.status == "calculating" then
			if child then
				child:Cancel()
			end
			self.result = { status = "cancelled", reasons = { "cancelled" } }
			thread, child = nil, nil
		end
	end
	return { result = initial, Advance = Advance, Cancel = Cancel }
end
