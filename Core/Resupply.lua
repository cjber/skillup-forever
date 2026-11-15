local _, ns = ...
local Resupply = {}
ns.Resupply = Resupply

-- Outward binary64 intervals. LuaJIT has no nextafter primitive, so construct
-- adjacent values from the exact binary exponent. These helpers are deliberately
-- local: the certificate is a property of this evaluator, not a public math API.
local NextUp, NextDown
NextUp = function(x)
	if x ~= x or x == math.huge then
		return x
	end
	if x == 0 then
		return math.ldexp(1, -1074)
	end
	if x < 0 then
		return -NextDown(-x)
	end
	local _, e = math.frexp(x)
	local step = math.ldexp(1, e - 53)
	return x + (step == 0 and math.ldexp(1, -1074) or step)
end
NextDown = function(x)
	if x ~= x or x == -math.huge then
		return x
	end
	if x == 0 then
		return -math.ldexp(1, -1074)
	end
	if x < 0 then
		return -NextUp(-x)
	end
	local m, e = math.frexp(x)
	local step = m == 0.5 and math.ldexp(1, e - 54) or math.ldexp(1, e - 53)
	return x - (step == 0 and math.ldexp(1, -1074) or step)
end
local function I(lo, hi)
	return { lo, hi }
end
local function IAdd(a, b)
	return I(NextDown(a[1] + b[1]), NextUp(a[2] + b[2]))
end
local function ISub(a, b)
	return I(NextDown(a[1] - b[2]), NextUp(a[2] - b[1]))
end
local function IMul(a, b)
	local p, q, r, s = a[1] * b[1], a[1] * b[2], a[2] * b[1], a[2] * b[2]
	return I(NextDown(math.min(p, q, r, s)), NextUp(math.max(p, q, r, s)))
end
local function IAbs(a)
	return math.max(math.abs(a[1]), math.abs(a[2]))
end
local function IRecip(a)
	if a[1] <= 0 and a[2] >= 0 then
		return nil
	end
	return I(NextDown(1 / a[2]), NextUp(1 / a[1]))
end
local function IDiv(a, b)
	local reciprocal = IRecip(b)
	return reciprocal and IMul(a, reciprocal) or nil
end
local function IFinite(a)
	return a and a[1] == a[1] and a[2] == a[2] and a[1] > -math.huge and a[2] < math.huge and a[1] <= a[2]
end

local function Finite(x)
	return type(x) == "number" and x == x and x >= 0 and x < math.huge
end
local function Integer(x)
	return Finite(x) and x <= 2 ^ 52 - 1 and x == math.floor(x)
end
local function Result(status, reason)
	return { status = status, coverageKnown = false, costKnown = false, rankable = false, reasons = { reason } }
end

-- Fixed raw stages, expanded by the caller using Model's chance/gain ownership.
-- Inputs must remain immutable until completion. Every coordinate, matrix cell
-- and arithmetic elimination step yields. No frame, clock, scheduling or cache
-- ownership is hidden here. maxStates is a caller resource budget, never a tail
-- cutoff: exceeding it discards the entire evaluation.
---@param input SkillUpResupplyInput
---@return SkillUpResupplyJob
function Resupply.Start(input)
	---@type thread?
	local thread = coroutine.create(function()
		local function Tick()
			coroutine.yield()
		end
		local function DenseLength(vector)
			if type(vector) ~= "table" then
				return nil
			end
			local count, largest = 0, 0
			for key in pairs(vector) do
				Tick()
				if not Integer(key) or key < 1 then
					return nil
				end
				count, largest = count + 1, math.max(largest, key)
			end
			if count ~= largest then
				return nil
			end
			return count
		end
		local function Copy(vector, n)
			if DenseLength(vector) ~= n then
				return nil
			end
			local out = {}
			for i = 1, n do
				if not Integer(vector[i]) then
					return nil
				end
				out[i] = vector[i]
				Tick()
			end
			return out
		end
		if type(input) ~= "table" or not Integer(input.maxStates) or input.maxStates == 0 then
			return Result("unsupported", "explicit positive maxStates resource budget required")
		end
		local n, g = DenseLength(input.inventory), DenseLength(input.sources)
		local stageCount = DenseLength(input.stages)
		if not n or not g or not stageCount then
			return Result("unsupported", "dense inventory, sources and stages required")
		end
		local inv = Copy(input.inventory, n)
		if not inv or stageCount == 0 then
			return Result("unsupported", "nonempty raw stage route and integer inventory required")
		end
		local stages, sources, owners, groups, unknown = {}, {}, {}, {}, {}
		local costKnown = Finite(input.initialCost)
		if not costKnown then
			unknown[#unknown + 1] = "initial acquisition cost missing or invalid"
		end
		for _, stage in ipairs(input.stages) do
			Tick()
			if type(stage) ~= "table" then
				return Result("unsupported", "stage record required")
			end
			if stage.chance == nil then
				return Result("unknown", "missing chance")
			end
			if not Finite(stage.chance) or stage.chance > 1 then
				return Result("unsupported", "invalid chance")
			end
			if stage.chance == 0 then
				return Result("unreachable", "zero chance stage")
			end
			local use = Copy(stage.use, n)
			if not use then
				return Result("unsupported", "raw nonnegative integer consumption required")
			end
			stages[#stages + 1] = { chance = stage.chance, use = use }
			Tick()
		end
		for _, s in ipairs(input.sources) do
			Tick()
			if type(s) ~= "table" then
				return Result("unsupported", "source record required")
			end
			if type(s.group) ~= "string" or s.group == "" or groups[s.group] then
				return Result("unsupported", "unique explicit visit group required")
			end
			groups[s.group] = true
			local k = DenseLength(s.items)
			if not k then
				return Result("unsupported", "dense source items required")
			end
			if s.units ~= nil and type(s.units) ~= "table" then
				return Result("unsupported", "unit cost vector required")
			end
			local source = {
				group = s.group,
				items = {},
				units = {},
				fee = s.visitFee,
				unitI = {},
				feeI = I(s.visitFee, s.visitFee),
			}
			source.bundles = Copy(s.bundleQuantities, k)
			if not source.bundles then
				return Result("unknown", "explicit acquisition bundle quantities required: " .. s.group)
			end
			for i = 1, k do
				if source.bundles[i] == 0 then
					return Result("unsupported", "positive acquisition bundle quantities required")
				end
				Tick()
			end
			source.targets, source.batch = Copy(s.targets, k), s.mode == "capped_batch" and Copy(s.batch, k) or nil
			if
				not source.targets
				or (s.mode ~= "order_up_to" and s.mode ~= "capped_batch")
				or (s.mode == "capped_batch" and not source.batch)
			then
				return Result("unsupported", "finite targets and explicit refill policy required")
			end
			for _, field in ipairs({ "perVisitStock", "totalStock" }) do
				Tick()
				if s[field] == nil then
					return Result("unknown", "stock or replenishment missing: " .. s.group)
				end
				source[field] = s[field] == "unlimited" and "unlimited" or Copy(s[field], k)
				if not source[field] then
					return Result("unsupported", "invalid explicit stock vector")
				end
			end
			local evidence = (s.kind == "vendor" or s.kind == "auction")
				and (s.provenance == "observed" or s.provenance == "entered" or s.provenance == "measured")
				and Finite(s.ageSeconds)
			local farm = s.kind == "farm"
				and (s.provenance == "entered" or s.provenance == "measured")
				and Finite(s.workSeconds)
				and Finite(s.yieldUnits)
				and s.yieldUnits > 0
				and Finite(s.setupSeconds)
				and Finite(s.copperPerSecond)
			if farm then
				source.fee = s.setupSeconds * s.copperPerSecond
				source.feeI = IMul(I(s.setupSeconds, s.setupSeconds), I(s.copperPerSecond, s.copperPerSecond))
			end
			if not (evidence or farm) or not Finite(source.fee) then
				costKnown = false
				unknown[#unknown + 1] = s.group .. ": explicit source kind and cost provenance required"
				if s.kind == "farm" then
					for _, field in ipairs({ "workSeconds", "yieldUnits", "setupSeconds", "copperPerSecond" }) do
						if not Finite(s[field]) or (field == "yieldUnits" and s[field] == 0) then
							unknown[#unknown + 1] = s.group .. ": missing or invalid " .. field
						end
						Tick()
					end
				else
					if not Finite(s.ageSeconds) then
						unknown[#unknown + 1] = s.group .. ": dated price observation required (ageSeconds)"
					end
					if not Finite(s.visitFee) then
						unknown[#unknown + 1] = s.group .. ": explicit per-visit travel/setup cost required (visitFee)"
					end
				end
			end
			for i, item in ipairs(s.items) do
				if not Integer(item) or item < 1 or item > n or owners[item] then
					return Result(
						"unsupported",
						"restricted reactive policy requires one selected source per item; finite source then backup unsupported"
					)
				end
				owners[item], source.items[i] = true, item
				local unit = farm and s.workSeconds / s.yieldUnits * s.copperPerSecond or (s.units and s.units[i])
				local unitI = farm and IDiv(I(s.workSeconds, s.workSeconds), I(s.yieldUnits, s.yieldUnits))
					or I(unit, unit)
				if farm then
					unitI = IMul(unitI, I(s.copperPerSecond, s.copperPerSecond))
				end
				if not Finite(unit) then
					costKnown = false
					unknown[#unknown + 1] = s.group .. ": missing unit cost"
				end
				source.units[i] = Finite(unit) and unit or 0
				source.unitI[i] = unitI
				Tick()
			end
			source.fee = Finite(source.fee) and source.fee or 0
			sources[#sources + 1] = source
		end
		for i = 1, n do
			if not owners[i] then
				return Result(
					"unsupported",
					"restricted reactive policy requires one selected source per item; finite source then backup unsupported"
				)
			end
			Tick()
		end
		-- One additional reward tracks explicitly valued terminal surplus, on
		-- success AND stock-blocked termination. Missing values are never zero.
		local terminalValues = input.terminalUnitValues
		local surplusKnown = DenseLength(terminalValues) == n
		if surplusKnown then
			for i = 1, n do
				surplusKnown = surplusKnown and Finite(terminalValues[i])
				Tick()
			end
		end
		if not surplusKnown then
			unknown[#unknown + 1] = "explicit terminal surplus unit values required for objective"
		end
		local width = 5 + g + n
		local function Surplus(inventory)
			local value, bound = 0, I(0, 0)
			if surplusKnown then
				for i = 1, n do
					value = value + inventory[i] * terminalValues[i]
					bound = IAdd(bound, IMul(I(inventory[i], inventory[i]), I(terminalValues[i], terminalValues[i])))
					Tick()
				end
			end
			return value, bound
		end
		local states, ids, edges, rewards, edgeIntervals, rewardIntervals = {}, {}, {}, {}, {}, {}
		local function Intern(stage, inventory, stocks, visited)
			local key = { tostring(stage), visited and "1" or "0" }
			for _, q in ipairs(inventory) do
				key[#key + 1] = string.format("%.0f", q)
				Tick()
			end
			for _, stock in ipairs(stocks) do
				Tick()
				if stock == "unlimited" then
					key[#key + 1] = "U"
				else
					for _, q in ipairs(stock) do
						key[#key + 1] = string.format("%.0f", q)
						Tick()
					end
				end
			end
			local name = table.concat(key, ",")
			if not ids[name] then
				if #states == input.maxStates then
					return nil
				end
				states[#states + 1] = { stage = stage, inventory = inventory, stocks = stocks, visited = visited }
				ids[name] = #states
			end
			return ids[name]
		end
		local stocks = {}
		for j, source in ipairs(sources) do
			stocks[j] = source.totalStock
			Tick()
		end
		Intern(1, inv, stocks, false)
		local cursor = 1
		while cursor <= #states do
			local state = states[cursor]
			local inventory, remaining, reward, edge = {}, {}, {}, {}
			local rewardI, edgeI = {}, {}
			for i = 1, width do
				reward[i] = 0
				rewardI[i] = I(0, 0)
				Tick()
			end
			for i = 1, n do
				inventory[i] = state.inventory[i]
				Tick()
			end
			local use, visited = stages[state.stage].use, state.visited
			for j, s in ipairs(sources) do
				Tick()
				local deficient = false
				for _, item in ipairs(s.items) do
					deficient = deficient or inventory[item] < use[item]
					Tick()
				end
				local stock = state.stocks[j]
				remaining[j] = stock == "unlimited" and "unlimited" or Copy(stock, #s.items)
				if deficient then
					visited, reward[4 + j] = true, 1
					rewardI[4 + j] = I(1, 1)
					if costKnown then
						reward[3] = reward[3] + s.fee
						rewardI[3] = IAdd(rewardI[3], s.feeI)
					end
					for k, item in ipairs(s.items) do
						local qty = math.max(0, s.targets[k] - inventory[item])
						if s.batch then
							qty = math.min(qty, s.batch[k])
						end
						if s.perVisitStock ~= "unlimited" then
							qty = math.min(qty, s.perVisitStock[k])
						end
						if stock ~= "unlimited" then
							qty = math.min(qty, stock[k])
						end
						qty = math.floor(qty / s.bundles[k]) * s.bundles[k]
						if stock ~= "unlimited" then
							remaining[j][k] = stock[k] - qty
						end
						inventory[item] = inventory[item] + qty
						reward[4 + g + item] = qty
						if costKnown then
							reward[3] = reward[3] + qty * s.units[k]
							rewardI[3] = IAdd(rewardI[3], IMul(I(qty, qty), s.unitI[k]))
						end
						rewardI[4 + g + item] = IAdd(rewardI[4 + g + item], I(qty, qty))
						Tick()
					end
				end
			end
			local affordable = true
			for i = 1, n do
				affordable = affordable and inventory[i] >= use[i]
				Tick()
			end
			if affordable then
				reward[4] = 1
				rewardI[4] = I(1, 1)
				for i = 1, n do
					inventory[i] = inventory[i] - use[i]
					Tick()
				end
				local p = stages[state.stage].chance
				for branch = 1, 2 do
					local nextStage, probability = state.stage + 1, p
					if branch == 2 then
						nextStage, probability = state.stage, 1 - p
					end
					if probability > 0 then
						local probabilityI = branch == 1 and I(p, p) or ISub(I(1, 1), I(p, p))
						if nextStage > #stages then
							local surplus, surplusI = Surplus(inventory)
							reward[width] = reward[width] + probability * surplus
							rewardI[width] = IAdd(rewardI[width], IMul(probabilityI, surplusI))
							reward[1] = reward[1] + probability
							rewardI[1] = IAdd(rewardI[1], probabilityI)
							if not visited then
								reward[2] = reward[2] + probability
								rewardI[2] = IAdd(rewardI[2], probabilityI)
							end
						else
							local dest = Intern(nextStage, inventory, remaining, visited)
							if not dest then
								return Result("unsupported", "reachable states exceed explicit resource budget")
							end
							edge[dest] = (edge[dest] or 0) + probability
							edgeI[dest] = IAdd(edgeI[dest] or I(0, 0), probabilityI)
						end
					end
				end
			end
			if not affordable then
				reward[width], rewardI[width] = Surplus(inventory)
			end
			edges[cursor], rewards[cursor] = edge, reward
			edgeIntervals[cursor], rewardIntervals[cursor] = edgeI, rewardI
			cursor = cursor + 1
			Tick()
		end
		-- Finite capped inventory and ledgers give a finite chain. Positive stage
		-- chances imply almost-sure absorption and finite expected attempts. Solve
		-- the full infinite-tail equations, not a finite attempt enumeration.
		-- Binary64 elimination alone is not an enclosure. The residual check
		-- below supplies optional bounds for this selected policy only.
		local size, matrix = #states, {}
		for i = 1, size do
			matrix[i] = {}
			for j = 1, size + width do
				matrix[i][j] = j <= size and ((i == j and 1 or 0) - (edges[i][j] or 0)) or rewards[i][j - size]
				Tick()
			end
		end
		for col = 1, size do
			local pivot = col
			for i = col + 1, size do
				if math.abs(matrix[i][col]) > math.abs(matrix[pivot][col]) then
					pivot = i
				end
				Tick()
			end
			matrix[col], matrix[pivot] = matrix[pivot], matrix[col]
			local d = matrix[col][col]
			if d == 0 or d ~= d then
				return Result("unsupported", "numerically singular policy equations")
			end
			for j = col, size + width do
				matrix[col][j] = matrix[col][j] / d
				Tick()
			end
			for i = 1, size do
				Tick()
				if i ~= col then
					local factor = matrix[i][col]
					for j = col, size + width do
						matrix[i][j] = matrix[i][j] - factor * matrix[col][j]
						Tick()
					end
				end
			end
		end
		local values = {}
		for k = 1, width do
			values[k] = matrix[1][size + k]
			if not Finite(values[k]) then
				return Result("unsupported", "nonfinite or negative numerical estimate")
			end
			Tick()
		end
		local result = Result("estimated", "selected reactive policy estimate; optional numerical enclosure")
		result.reasons = unknown
		result.reasons[#result.reasons + 1] = "selected reactive policy only; no unrestricted acquisition optimum"
		-- Validate the solved rounded candidate against branch-level outward
		-- enclosures. Compare consumes these bounds only within its declared
		-- finite domain; the legacy estimate flags remain false.
		local tUpper = I(1, 1)
		local certificate = true
		for _, stage in ipairs(stages) do
			Tick()
			local reciprocal = IRecip(I(stage.chance, stage.chance))
			if not reciprocal then
				certificate = false
				break
			end
			tUpper = IAdd(tUpper, reciprocal)
		end
		local maxResidual = 0
		if certificate and tUpper[2] < math.huge then
			for row = 1, size do
				for k = 1, width do
					if not Finite(matrix[row][size + k]) then
						certificate = false
					end
					Tick()
				end
			end
			for row = 1, size do
				for k = 1, width do
					Tick()
					local lhs = I(matrix[row][size + k], matrix[row][size + k])
					for dest, bound in pairs(edgeIntervals[row]) do
						Tick()
						lhs = ISub(lhs, IMul(bound, I(matrix[dest][size + k], matrix[dest][size + k])))
					end
					local residual = ISub(rewardIntervals[row][k], lhs)
					if not IFinite(residual) then
						certificate = false
					end
					maxResidual = math.max(maxResidual, IAbs(residual))
				end
			end
		else
			certificate = false
		end
		local errorI = certificate and IMul(I(tUpper[2], tUpper[2]), I(maxResidual, maxResidual)) or nil
		local costError = nil
		if certificate and errorI and costKnown then
			local exactCostI = IAdd(
				I(NextDown(values[3] - errorI[2]), NextUp(values[3] + errorI[2])),
				I(input.initialCost, input.initialCost)
			)
			local roundedCost = values[3] + input.initialCost
			local costResidual = ISub(exactCostI, I(roundedCost, roundedCost))
			if IFinite(costResidual) then
				costError = IAbs(costResidual)
			else
				certificate = false
			end
		end
		result.certificate = certificate
				and IFinite(errorI)
				and (not costKnown or costError ~= nil)
				and {
					errorBound = errorI[2],
					costErrorBound = costError and NextUp(costError) or nil,
					maxResidual = maxResidual,
					transientBound = tUpper[2],
				}
			or nil
		result.completionEstimate, result.withoutRefillEstimate = values[1], values[2]
		result.expectedCostEstimate = costKnown and values[3] + input.initialCost or nil
		if result.expectedCostEstimate and not Finite(result.expectedCostEstimate) then
			return Result("unsupported", "nonfinite total cost estimate")
		end
		result.expectedAttemptsEstimate, result.states = values[4], size
		result.costScope = "restricted reactive policy spend until completion or explicit stock-blocked stop"
		result.policyScope =
			"one selected source per item; refill only on deficiency; no backup source or proactive visit optimization"
		result.expectedSurplusValueEstimate = surplusKnown and values[width] or nil
		if costKnown and surplusKnown then
			result.netCostEstimate = result.expectedCostEstimate - values[width]
			if result.certificate then
				local netI = ISub(
					I(
						NextDown(result.expectedCostEstimate - result.certificate.costErrorBound),
						NextUp(result.expectedCostEstimate + result.certificate.costErrorBound)
					),
					I(
						NextDown(values[width] - result.certificate.errorBound),
						NextUp(values[width] + result.certificate.errorBound)
					)
				)
				if IFinite(netI) then
					result.netCostLower, result.netCostUpper = netI[1], netI[2]
				end
			end
		end
		result.visitsEstimate, result.unitsEstimate = {}, {}
		for j, s in ipairs(sources) do
			result.visitsEstimate[s.group] = values[4 + j]
			Tick()
		end
		for i = 1, n do
			result.unitsEstimate[i] = values[4 + g + i]
			Tick()
		end
		return result
	end)
	---@param self SkillUpResupplyJob
	---@param work integer
	---@return SkillUpResupplyResult
	local function Advance(self, work)
		assert(Integer(work) and work > 0, "positive integer work budget required")
		for _ = 1, work do
			if self.result.status ~= "calculating" then
				break
			end
			local active = assert(thread)
			local ok, value = coroutine.resume(active)
			if not ok then
				self.result, thread = Result("unsupported", "evaluation failed: " .. tostring(value)), nil
				break
			end
			if coroutine.status(active) == "dead" then
				self.result, thread = value, nil
			end
		end
		return self.result
	end
	---@param self SkillUpResupplyJob
	local function Cancel(self)
		if self.result.status == "calculating" then
			self.result, thread = Result("cancelled", "cancelled"), nil
		end
	end
	return { result = Result("calculating", "evaluation pending"), Advance = Advance, Cancel = Cancel }
end

-- Exhaustively compare only a caller-declared finite basket/policy domain.
-- This is not an unrestricted acquisition optimizer: each candidate still uses
-- Start's one-source reactive policy. No implicit quantity cap or economics.
function Resupply.Compare(input)
	local active
	local thread = coroutine.create(function()
		local function Finish(status, reason, evaluations, chosen)
			return {
				status = status,
				reasons = { reason },
				evaluations = evaluations,
				chosenIndex = chosen,
				domainScope = "explicit finite baskets with selected reactive policies only",
			}
		end
		if type(input) ~= "table" or not Finite(input.minCompletion) or input.minCompletion > 1 then
			return Finish("unsupported", "explicit completion probability constraint required")
		end
		if type(input.candidates) ~= "table" then
			return Finish("unsupported", "explicit nonempty finite basket domain required")
		end
		local count, largest = 0, 0
		for key in pairs(input.candidates) do
			if not Integer(key) or key < 1 then
				return Finish("unsupported", "dense finite basket domain required")
			end
			count, largest = count + 1, math.max(largest, key)
			coroutine.yield()
		end
		if count == 0 or count ~= largest then
			return Finish("unsupported", "dense nonempty finite basket domain required")
		end
		local evaluations, feasible, unresolved = {}, {}, false
		for i = 1, count do
			active = Resupply.Start(input.candidates[i])
			while active.result.status == "calculating" do
				active:Advance(1)
				coroutine.yield()
			end
			local result = active.result
			evaluations[i], active = result, nil
			local certificate = result.certificate
			if not certificate or not result.completionEstimate then
				unresolved = true
			else
				local lower = math.max(0, NextDown(result.completionEstimate - certificate.errorBound))
				local upper = math.min(1, NextUp(result.completionEstimate + certificate.errorBound))
				if upper < input.minCompletion then
					-- A cheap early stock stop cannot win the cost comparison.
					result.constraintStatus = "infeasible"
				elseif lower >= input.minCompletion then
					result.constraintStatus = "feasible"
					feasible[#feasible + 1] = i
					if not result.netCostLower or not result.netCostUpper then
						unresolved = true
					end
				else
					result.constraintStatus = "unknown"
					unresolved = true
				end
			end
		end
		if unresolved then
			return Finish("unknown", "completion constraint or surplus-adjusted cost unresolved", evaluations)
		end
		if #feasible == 0 then
			return Finish("infeasible", "no declared candidate meets completion constraint", evaluations)
		end
		local best = feasible[1]
		for _, i in ipairs(feasible) do
			if evaluations[i].netCostUpper < evaluations[best].netCostUpper then
				best = i
			end
			coroutine.yield()
		end
		for _, i in ipairs(feasible) do
			if i ~= best and evaluations[best].netCostUpper >= evaluations[i].netCostLower then
				return Finish("unknown", "candidate cost enclosures overlap", evaluations)
			end
			coroutine.yield()
		end
		return Finish("complete", "minimum certified within declared finite domain only", evaluations, best)
	end)
	local job = { result = { status = "calculating", reasons = { "finite domain comparison pending" } } }
	function job:Advance(work)
		assert(Integer(work) and work > 0, "positive integer work budget required")
		for _ = 1, work do
			if self.result.status ~= "calculating" then
				break
			end
			local ok, result = coroutine.resume(thread)
			if not ok then
				if active then
					active:Cancel()
				end
				self.result = { status = "unsupported", reasons = { "comparison failed: " .. tostring(result) } }
				thread = nil
			elseif coroutine.status(thread) == "dead" then
				self.result, thread = result, nil
			end
		end
		return self.result
	end
	function job:Cancel()
		if self.result.status == "calculating" then
			if active then
				active:Cancel()
			end
			self.result, thread = { status = "cancelled", reasons = { "cancelled" } }, nil
		end
	end
	return job
end
