---@type string, SkillUpNamespace
local _, ns = ...

-- Exhaustive initial-order selection for ONE declared refill policy. Bounds
-- come from resources before the atomic initial batch, never a fitted basket
-- cutoff. Unbounded dimensions and overlapping objective enclosures stay unknown.
local Choice = {}
local LIMIT = 2 ^ 52 - 1
local function Integer(x)
	return type(x) == "number" and x >= 0 and x <= LIMIT and x % 1 == 0
end
local function Unknown(reason)
	return { status = "unknown", reasons = { reason }, costKnown = false }
end

-- This theorem concerns the fixed-refill expenditure objective only, which has
-- no carrying/capacity term. No source observation establishes these laws.
---@param input SkillUpResupplyInput Already validated by Resupply.
---@param alpha number
---@param tick fun()
---@return SkillUpSupplyChoiceResult?
local function FreeNonattainment(input, alpha, tick)
	if alpha >= 1 or #input.sources ~= 1 then
		return nil
	end
	local source = input.sources[1]
	local refillCost = input.refillVisitCosts[source.vendor]
	if
		source.moneyCopper ~= 0
		or next(source.costs) ~= nil
		or source.access ~= true
		or input.stock[source.stockKey] ~= "unlimited"
		or input.initialVisitCosts[source.vendor] ~= 0
		or not (type(refillCost) == "number" and refillCost > 0)
	then
		return nil
	end
	-- A closed contract guard: additional objective/capacity terms require a
	-- different proof.
	local fields = {
		sourceRevision = true,
		assumptions = true,
		route = true,
		service = true,
		journey = true,
		walletCopper = true,
		currencies = true,
		stock = true,
		sources = true,
		tokenValues = true,
		initialOrders = true,
		refillOrders = true,
		initialVisitCosts = true,
		refillVisitCosts = true,
		options = true,
	}
	for field in pairs(input) do
		if not fields[field] then
			return nil
		end
		tick()
	end
	local stages, held, failure = ns.Demand.Prepare(input.route, tick)
	if failure or not stages or not held or #stages ~= 1 then
		return nil
	end
	local stage = stages[1]
	if not (stage.chance > 0 and stage.chance < 1) or stage.use[source.itemID] ~= 1 then
		return nil
	end
	for item in pairs(stage.use) do
		if item ~= source.itemID then
			return nil
		end
		tick()
	end
	local refillUnits = 0
	for _, order in ipairs(input.refillOrders) do
		refillUnits = refillUnits + order.bundles * source.bundleUnits
		tick()
	end
	if refillUnits == 0 then
		return nil
	end
	-- q=1-p in exact real arithmetic. For h held units and n initial bundles,
	-- later cost is R*q^(h+n*u)/(1-q^B), strictly positive for every finite n,
	-- strictly decreasing in n, and tending to zero. Alpha<1 has finite feasible
	-- n. Thus zero is an infimum, with no finite attaining basket. LIMIT is an
	-- arithmetic guard, not an invented physical inventory capacity.
	return {
		status = "unattained",
		costKnown = false,
		infimumKnown = true,
		objectiveInfimumLower = 0,
		objectiveInfimumUpper = 0,
		alpha = alpha,
		reasons = { "free unlimited initial supply has an unattained zero expenditure infimum" },
		nonattainment = {
			kind = "free-unlimited-geometric",
			chance = stage.chance,
			heldUnits = held[source.itemID] or 0,
			bundleUnits = source.bundleUnits,
			refillUnits = refillUnits,
			refillVisitCost = refillCost,
		},
	}
end

---@param input SkillUpResupplyInput Immutable during this job.
---@param alpha number Explicit starting-inventory coverage requirement.
---@return SkillUpSupplyChoiceJob
function Choice.Start(input, alpha)
	local revision = ns.Model.ChanceRevision()
	local result = { status = "calculating", reasons = {}, costKnown = false }
	---@type SkillUpResupplyJob?
	local child
	local operations = 0
	---@type thread?
	local thread = coroutine.create(function()
		if type(alpha) ~= "number" or not (alpha > 0 and alpha <= 1) then
			return Unknown("explicit starting coverage in (0, 1] required")
		end
		local limit = type(input) == "table" and type(input.options) == "table" and input.options.workLimit
		if not Integer(limit) or limit == 0 then
			return Unknown("explicit selection operation budget required")
		end
		local function Tick()
			operations = operations + 1
			if operations > limit then
				error({ choice = "selection work budget exhausted; no optimum certificate" }, 0)
			end
			coroutine.yield()
		end
		-- Evidence is optional for synthetic contracts, but a source-owned contract
		-- must publish an owned, complete revision record rather than loose labels.
		local assumptions
		if input.sourceRevision ~= nil or input.assumptions ~= nil then
			if not Integer(input.sourceRevision) or type(input.assumptions) ~= "table" then
				return Unknown("paired source revision and dated assumptions required")
			end
			assumptions = {}
			local count = 0
			for index, evidence in pairs(input.assumptions) do
				if not Integer(index) or index < 1 or type(evidence) ~= "table" then
					return Unknown("dense dated source assumptions required")
				end
				local copy = {}
				for _, field in ipairs({ "offerID", "field", "provenance", "scope", "observationRevision" }) do
					if type(evidence[field]) ~= "string" or evidence[field] == "" then
						return Unknown("complete scoped source provenance required")
					end
					copy[field] = evidence[field]
					Tick()
				end
				for _, field in ipairs({ "revision", "observedAt", "session", "index" }) do
					if not Integer(evidence[field]) or (field ~= "observedAt" and evidence[field] == 0) then
						return Unknown("integral source evidence revisions required")
					end
					copy[field] = evidence[field]
					Tick()
				end
				assumptions[index], count = copy, count + 1
			end
			for index = 1, count do
				if not assumptions[index] then
					return Unknown("dense dated source assumptions required")
				end
				Tick()
			end
		end
		-- Validate every policy law before using its resources as domain bounds.
		child = ns.Resupply.Start(input)
		repeat
			child:Advance(1)
			Tick()
		until child.result.status ~= "calculating" or child.result.initialFeasible ~= nil
		if child.result.status == "unknown" and child.result.initialFeasible ~= false then
			return Unknown(child.result.reasons[1])
		end
		child:Cancel()
		local unattained = FreeNonattainment(input, alpha, Tick)
		if unattained then
			unattained.sourceRevision, unattained.assumptions = input.sourceRevision, assumptions
			return unattained
		end
		local bounds, quantities, resourceBounds, unbounded = {}, {}, {}, {}
		local searching = false
		local extent = 1
		for index, source in ipairs(input.sources) do
			local bound = LIMIT
			local proven = false
			if source.access == false then
				bound, proven = 0, true
			end
			local stock = input.stock[source.stockKey]
			if Integer(stock) then
				bound, proven = math.min(bound, math.floor(stock / source.stockPerBundle)), true
			end
			if Integer(input.walletCopper) and source.moneyCopper > 0 then
				bound, proven = math.min(bound, math.floor(input.walletCopper / source.moneyCopper)), true
			end
			for key, amount in pairs(source.costs) do
				local kind, id = key:match("^(%a+):(%d+)$")
				local balance = kind == "item" and (input.route.held[tonumber(id)] or 0)
					or input.currencies[tonumber(id)]
					or 0
				bound, proven = math.min(bound, math.floor(balance / amount)), true
				Tick()
			end
			if not proven then
				if source.moneyCopper == 0 then
					return Unknown("free unbounded initial-order dimension requires a dominance proof")
				end
				unbounded[index], searching = true, true
			end
			resourceBounds[index], quantities[index] = bound, 0
			Tick()
		end
		for index, bound in ipairs(resourceBounds) do
			bounds[index] = searching and math.min(bound, extent) or bound
			Tick()
		end
		local best, bestOrders, bestQuantities
		local competitorLower = math.huge
		local anyAmbiguous = false
		local done = false
		while not done do
			local orders = {}
			for index, quantity in ipairs(quantities) do
				local left = quantity
				while left > 0 do
					local bundles = math.min(left, input.sources[index].maxBundles)
					orders[#orders + 1] = { source = index, bundles = bundles }
					left = left - bundles
					Tick()
				end
			end
			local candidate = {}
			for key, value in pairs(input) do
				candidate[key] = value
				Tick()
			end
			---@cast candidate SkillUpResupplyInput
			candidate.initialOrders = orders
			child = ns.Resupply.Start(candidate)
			local excluded = false
			while child.result.status == "calculating" do
				child:Advance(1)
				local upper = child.result.coverageUpper
				if upper and upper < alpha then
					excluded = true
					child:Cancel()
					break
				end
				Tick()
			end
			local value = child.result
			if not excluded and value.initialFeasible ~= false then
				if value.status ~= "complete" then
					return Unknown(value.reasons[1] or "candidate evaluation unresolved")
				end
				if value.coverageUpper >= alpha then
					local feasible = value.coverageLower >= alpha
					if feasible and (not best or value.costUpper < best.costUpper) then
						if best then
							competitorLower = math.min(competitorLower, best.costLower)
						end
						best, bestOrders, bestQuantities = value, orders, {}
						for index, quantity in ipairs(quantities) do
							bestQuantities[index] = quantity
							Tick()
						end
					else
						competitorLower = math.min(competitorLower, value.costLower)
					end
					anyAmbiguous = anyAmbiguous or not feasible
				end
			end
			local index = 1
			while quantities[index] == bounds[index] and index <= #bounds do
				quantities[index] = 0
				index = index + 1
				Tick()
			end
			if index > #bounds then
				if searching then
					if best then
						-- All rewards are nonnegative. An initial money outlay
						-- above this feasible total upper cost cannot win.
						local incumbent = best.costUpper
						for i, bound in ipairs(resourceBounds) do
							local price = input.sources[i].moneyCopper
							if price > 0 then
								local paidBound = math.floor(incumbent / price)
								if unbounded[i] and paidBound > LIMIT then
									return Unknown("economic domain bound exceeds exact quantity range")
								end
								bound = math.min(bound, paidBound)
							elseif unbounded[i] then
								return Unknown("unbounded free dimension lacks a dominance proof")
							end
							bounds[i] = bound
							Tick()
						end
						searching = false
					else
						if extent >= LIMIT then
							return Unknown("incumbent search exceeds exact quantity range")
						end
						extent = math.min(LIMIT, extent * 2)
						for i, bound in ipairs(resourceBounds) do
							bounds[i] = math.min(bound, extent)
							Tick()
						end
					end
					best, bestOrders, bestQuantities = nil, nil, nil
					competitorLower, anyAmbiguous = math.huge, false
				else
					done = true
				end
			else
				quantities[index] = quantities[index] + 1
			end
			Tick()
		end
		if not best then
			return Unknown(
				anyAmbiguous and "coverage boundary unresolved" or "no feasible initial order in complete finite domain"
			)
		end
		if best.costUpper > competitorLower then
			return Unknown("candidate cost enclosures overlap; optimum unresolved")
		end
		local products, consumed, items, have, acquisitions, visits = {}, {}, {}, {}, {}, {}
		for _, leg in ipairs(input.route.legs) do
			for item in pairs(leg.use) do
				consumed[item] = true
				Tick()
			end
		end
		for _, order in ipairs(assert(bestOrders)) do
			local source = input.sources[order.source]
			local costs = {}
			for key, amount in pairs(source.costs) do
				costs[key] = amount * order.bundles
				Tick()
			end
			local acquisition = {
				source = order.source,
				offerID = source.offerID,
				npcID = source.npcID,
				vendor = source.vendor,
				itemID = source.itemID,
				bundles = order.bundles,
				bundleUnits = source.bundleUnits,
				units = source.bundleUnits * order.bundles,
				moneyCopper = source.moneyCopper * order.bundles,
				costs = costs,
			}
			acquisitions[#acquisitions + 1] = acquisition
			visits[source.vendor] = input.initialVisitCosts[source.vendor]
			products[source.itemID] = (products[source.itemID] or 0) + acquisition.units
			Tick()
		end
		for item in pairs(consumed) do
			have[item] = input.route.held[item] or 0
			items[item] = have[item] + (products[item] or 0)
			if not Integer(items[item]) then
				return Unknown("selected inventory budget exceeds exact quantity range")
			end
			Tick()
		end
		best.items, best.have = items, have
		best.orders, best.quantities, best.alpha = bestOrders, bestQuantities, alpha
		best.acquisitions, best.initialVisits = acquisitions, visits
		best.sourceRevision, best.assumptions = input.sourceRevision, assumptions
		return best
	end)
	---@param self SkillUpSupplyChoiceJob
	local function Cancel(self)
		if child then
			child:Cancel()
		end
		thread, child = nil, nil
		self.result = { status = "cancelled", reasons = { "supply choice invalidated" }, costKnown = false }
	end
	---@param self SkillUpSupplyChoiceJob
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
			local ok, value = coroutine.resume(active)
			if not ok then
				if type(value) ~= "table" or not value.choice then
					error(value)
				end
				self.result, thread = Unknown(value.choice), nil
				if child then
					child:Cancel()
					child = nil
				end
			elseif coroutine.status(active) == "dead" then
				self.result, thread = value, nil
			end
		end
		return self.result
	end
	return { result = result, Advance = Advance, Cancel = Cancel }
end
ns.SupplyChoice = { Start = Choice.Start }
