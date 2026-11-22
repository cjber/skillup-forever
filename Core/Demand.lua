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
-- Shared immutable route compilation. Both starting-only coverage and repeated
-- acquisition evaluation consume these exact stages and pooled coordinates.
---@param input SkillUpJointDemandInput
---@param Tick fun()
---@param physical {skill: integer?, cap: integer}? Full successful gain law for crafted snapshots.
---@return {chance: number, use: table<integer, integer>, skill: integer}[]?
---@return table<integer, integer>?
---@return SkillUpJointDemandResult?
local function Prepare(input, Tick, physical)
	-- ipairs stops at the first hole, which must not certify a route prefix.
	if type(input) ~= "table" or type(input.held) ~= "table" or type(input.buy) ~= "table" then
		return nil, nil, Unknown("explicit route, held inventory and basket tables required", false)
	end
	if type(input.legs) ~= "table" then
		return nil, nil, Unknown("dense route legs required", false)
	end
	local legCount, largest = 0, 0
	for key in pairs(input.legs) do
		if not Integer(key) or key < 1 then
			return nil, nil, Unknown("dense route legs required", false)
		end
		legCount, largest = legCount + 1, math.max(largest, key)
		Tick()
	end
	if legCount ~= largest then
		return nil, nil, Unknown("dense route legs required", false)
	end
	local legs, capacity = {}, {}
	for item, held in pairs(input.held) do
		if not Integer(item) or item == 0 or not Integer(held) then
			return nil, nil, Unknown("invalid inventory", false)
		end
		capacity[item] = held
		Tick()
	end
	for item, buy in pairs(input.buy) do
		if not Integer(item) or item == 0 or not Integer(buy) or not Integer((capacity[item] or 0) + buy) then
			return nil, nil, Unknown("invalid basket", false)
		end
		capacity[item] = (capacity[item] or 0) + buy
		Tick()
	end
	for _, leg in ipairs(input.legs) do
		if type(leg) ~= "table" then
			return nil, nil, Unknown("route leg record required", false)
		end
		if leg.rawConsumption ~= true or leg.deterministicOutput ~= true then
			return nil, nil, Unknown("subcraft or random output requires an inventory transition", false)
		end
		if
			not Integer(leg.fromSkill)
			or not Integer(leg.toSkill)
			or leg.toSkill < leg.fromSkill
			or (leg.skillUps ~= nil and (not Integer(leg.skillUps) or leg.skillUps == 0))
		then
			return nil, nil, Unknown("invalid skill interval", false)
		end
		local copy = { fromSkill = leg.fromSkill, toSkill = leg.toSkill, skillUps = leg.skillUps, use = {} }
		if leg.thresholds ~= nil and type(leg.thresholds) ~= "table" then
			return nil, nil, Unknown("invalid thresholds", false)
		end
		if type(leg.use) ~= "table" then
			return nil, nil, Unknown("raw consumption table required", false)
		end
		if leg.thresholds then
			copy.thresholds = {}
			for i = 1, 4 do
				if not Integer(leg.thresholds[i]) then
					return nil, nil, Unknown("invalid thresholds", false)
				end
				copy.thresholds[i] = leg.thresholds[i]
			end
		end
		for item, count in pairs(leg.use) do
			if not Integer(item) or item == 0 or not Integer(count) then
				return nil, nil, Unknown("invalid raw consumption", false)
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
		local skill = physical and (physical.skill or leg.fromSkill) or leg.fromSkill
		while skill < leg.toSkill do
			local stage = ns.Model.DemandStage(leg.thresholds, skill, leg.skillUps, leg.toSkill)
			if not stage or stage.chance == nil then
				return nil, nil, Unknown("missing skill-up chance", true)
			elseif stage.chance <= 0 then
				return nil,
					nil,
					{
						status = "unreachable",
						supported = true,
						coverageKnown = true,
						coverageLower = 0,
						coverageUpper = 0,
						costKnown = false,
						reasons = { "zero skill-up chance", "source cost not evaluated" },
					}
			end
			stages[#stages + 1] = { chance = stage.chance, use = leg.use, skill = skill }
			-- Planning clips progress at a leg target and grey. A declared physical
			-- gain instead advances the whole successful attempt, bounded by rank.
			skill = skill + (physical and math.min(leg.skillUps or 1, physical.cap - skill) or stage.gain)
			Tick()
		end
		if physical then
			physical.skill = skill
		end
	end
	return stages, capacity
end
Demand.Prepare = Prepare

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
		local stages, capacity, failure = Prepare(input, Tick)
		if failure then
			return failure
		end
		assert(stages and capacity)
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
		local result = {
			status = "complete",
			supported = true,
			coverageKnown = true,
			coverageLower = low,
			coverageUpper = math.min(1, high),
			costKnown = false,
			reasons = { "source cost not evaluated" },
		}
		-- A one-item projection gives its marginal shortage, without clipping on
		-- other reagents. For demand D and prepared capacity c:
		-- E[(D-c)+] = E[D] - c + sum(d<=c, (c-d) * P(D=d)).
		-- Each skill-up stage consumes a geometric number of crafts, with mean 1/p.
		if #items == 1 then
			local item = items[1]
			local meanLower, meanUpper, savedLower, savedUpper = 0, 0, 0, 0
			for _, stage in ipairs(stages) do
				local mean = (stage.use[item] or 0) / stage.chance
				meanLower, meanUpper = Down(meanLower + Down(mean)), Up(meanUpper + Up(mean))
				Tick()
			end
			for _, state in ipairs(states) do
				local unused = capacity[item] - (state.use[item] or 0)
				savedLower = Down(savedLower + Down(unused * state.low))
				savedUpper = Up(savedUpper + Up(unused * state.high))
				Tick()
			end
			-- The intermediate subtraction can be negative, so only clamp after
			-- adding the retained bounded distribution. Widen every operation.
			local differenceLower = meanLower - capacity[item]
			local differenceUpper = meanUpper - capacity[item]
			local errorLower = math.abs(differenceLower) * 2 ^ -50 + 2 ^ -1074
			local errorUpper = math.abs(differenceUpper) * 2 ^ -50 + 2 ^ -1074
			local shortageLower = Down(differenceLower - errorLower + savedLower)
			local shortageUpper = Up(differenceUpper + errorUpper + savedUpper)
			if shortageLower < math.huge and shortageUpper < math.huge and shortageUpper >= 0 then
				result.shortfallItem = item
				result.expectedShortfallLower = shortageLower
				result.expectedShortfallUpper = shortageUpper
			end
		end
		return result
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
