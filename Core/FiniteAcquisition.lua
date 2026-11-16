---@type string, SkillUpNamespace
local _, ns = ...
local Finite = {}
---@type table<SkillUpFiniteAcquisitionJob, {coverage: SkillUpDyadic, objective: SkillUpDyadic, revision: integer}>
local exactResults = setmetatable({}, { __mode = "k" })
local LIMIT = 2 ^ 52 - 1
local COMPONENTS = { "success", "money", "tokens", "visitValue", "carry", "failure", "visits" }
local function Integer(value)
	return type(value) == "number" and value >= 0 and value <= LIMIT and value == math.floor(value)
end
local function Nonnegative(value)
	return type(value) == "number" and value >= 0 and value < math.huge
end
---@param reason string
---@return SkillUpFiniteSelectionResult
local function Unknown(reason)
	return { status = "unknown", costKnown = false, reasons = { reason } }
end

---@param input SkillUpFiniteAcquisitionInput
---@return SkillUpFiniteAcquisitionJob
function Finite.Start(input)
	---@type SkillUpFiniteAcquisitionJob
	local job
	local revision = ns.Model.ChanceRevision()
	---@type SkillUpFiniteAcquisitionResult
	local initial = { status = "calculating", costKnown = false, reasons = {} }
	---@type thread?
	local thread = coroutine.create(function()
		local function Reject(reason)
			error({ finiteAcquisition = reason }, 0)
		end
		if type(input) ~= "table" or type(input.options) ~= "table" then
			return Unknown("explicit finite acquisition contract and resource budgets required")
		end
		local options = input.options
		for _, key in ipairs({ "workLimit", "stateLimit", "coordinateLimit", "limbLimit" }) do
			if not Integer(options[key]) or options[key] == 0 then
				return Unknown("positive finite integer resource budgets required")
			end
		end
		local work = 0
		local function Tick()
			work = work + 1
			if work > options.workLimit then
				Reject("finite acquisition work budget exhausted; no certificate")
			end
			coroutine.yield()
		end
		local allowed = {
			service = true,
			journey = true,
			delivery = true,
			objective = true,
			route = true,
			walletCopper = true,
			currencies = true,
			stock = true,
			sources = true,
			initialOrders = true,
			tokenValues = true,
			terminalCarry = true,
			failureLoss = true,
			initialVisitMoney = true,
			refillVisitMoney = true,
			initialVisitValue = true,
			refillVisitValue = true,
			sourceRevision = true,
			assumptions = true,
			options = true,
		}
		for key in pairs(input) do
			if not allowed[key] then
				Reject("unsupported finite acquisition contract field")
			end
			Tick()
		end
		if
			input.service ~= "adaptive-finite"
			or input.journey ~= "independent-round-trips"
			or input.delivery ~= "independent-bundle-outcomes"
			or input.objective ~= "expected-expenditure-plus-terminal-carry-plus-failure-loss"
		then
			return Unknown("explicit finite service, trip, delivery and objective laws required")
		end
		local function Dense(list)
			if type(list) ~= "table" then
				Reject("dense finite acquisition records required")
			end
			local count, last = 0, 0
			for key in pairs(list) do
				if not Integer(key) or key == 0 then
					Reject("dense finite acquisition records required")
				end
				count, last = count + 1, math.max(last, key)
				Tick()
			end
			if count ~= last then
				Reject("dense finite acquisition records required")
			end
		end
		local function Safe(value)
			if not Integer(value) then
				Reject("finite resource arithmetic exceeds exact integer range")
			end
			return value
		end
		local function Copy(values)
			local copy = {}
			for i, value in ipairs(values) do
				copy[i] = value
				Tick()
			end
			return copy
		end
		---@type SkillUpFiniteStage[]?
		local stages
		---@type table<integer, integer>?
		local held
		local recipes, auxiliary, topological = {}, {}, {}
		local crafted = type(input.route) == "table" and rawget(input.route, "version") ~= nil
		local function Fields(record, fields, reason)
			if type(record) ~= "table" then
				Reject(reason)
			end
			for key in pairs(record) do
				if not fields[key] then
					Reject(reason)
				end
				Tick()
			end
		end
		local function Text(value)
			return type(value) == "string" and value ~= ""
		end
		if crafted then
			local route = input.route
			---@cast route SkillUpCraftedRoute
			Fields(route, {
				version = true,
				skillCap = true,
				coverage = true,
				prerequisites = true,
				recipes = true,
				legs = true,
				held = true,
				buy = true,
			}, "unsupported crafted route law")
			if
				route.version ~= "crafted-deterministic-v1"
				or route.coverage ~= "maximum-craft-only-completion"
				or route.prerequisites ~= "already-satisfied"
			then
				Reject("explicit versioned crafted laws and satisfied prerequisites required")
			end
			Dense(route.recipes)
			Dense(route.legs)
			if type(route.held) ~= "table" or type(route.buy) ~= "table" then
				Reject("explicit crafted inventories required")
			end
			held, stages = {}, {}
			for item, count in pairs(route.held) do
				if not Integer(item) or item == 0 or not Integer(count) then
					Reject("invalid crafted inventory")
				end
				held[item] = count
				Tick()
			end
			local graph, indegree = {}, {}
			local function Map(values)
				if type(values) ~= "table" then
					Reject("complete deterministic item maps required")
				end
				local copy, positive = {}, false
				for item, count in pairs(values) do
					if not Integer(item) or item == 0 or not Integer(count) then
						Reject("invalid deterministic item map")
					end
					if count > 0 then
						copy[item], positive = count, true
					end
					held[item] = held[item] or 0
					graph[item], indegree[item] = graph[item] or {}, indegree[item] or 0
					Tick()
				end
				return copy, positive
			end
			for _, row in ipairs(route.recipes) do
				Fields(row, {
					recipeID = true,
					professionID = true,
					role = true,
					available = true,
					eligibility = true,
					scope = true,
					skillEffect = true,
					productionLaw = true,
					use = true,
					produce = true,
					evidence = true,
				}, "unsupported crafted recipe law")
				if
					not Integer(row.recipeID)
					or row.recipeID == 0
					or recipes[row.recipeID]
					or not Integer(row.professionID)
					or row.professionID == 0
					or (row.role ~= "main" and row.role ~= "auxiliary")
					or type(row.available) ~= "boolean"
					or not Text(row.scope)
					or row.productionLaw ~= "deterministic-completed-attempt"
				then
					Reject("complete distinct identified deterministic recipes required")
				end
				if
					(row.role == "auxiliary" and row.skillEffect ~= "neutral")
					or (row.role == "main" and row.skillEffect ~= "route")
				then
					Reject("skill-affecting auxiliary recipes are not modeled")
				end
				Fields(
					row.evidence,
					{ revision = true, allocation = true, clientBuild = true },
					"complete scoped production evidence required"
				)
				if
					not Integer(row.evidence.revision)
					or not Text(row.evidence.allocation)
					or not Text(row.evidence.clientBuild)
				then
					Reject("complete scoped production evidence required")
				end
				local eligibility
				if row.eligibility ~= nil then
					Fields(
						row.eligibility,
						{ fromSkill = true, toSkill = true, fixedSkill = true },
						"invalid recipe eligibility"
					)
					local bounds = assert(row.eligibility)
					if
						not Integer(bounds.fromSkill)
						or not Integer(bounds.toSkill)
						or bounds.toSkill < bounds.fromSkill
						or (bounds.fixedSkill ~= nil and (row.role ~= "auxiliary" or not Integer(bounds.fixedSkill)))
					then
						Reject("invalid recipe eligibility")
					end
					if bounds.fixedSkill == nil and route.skillCap == nil then
						Reject("dynamic recipe eligibility requires physical skill cap")
					end
					eligibility =
						{ fromSkill = bounds.fromSkill, toSkill = bounds.toSkill, fixedSkill = bounds.fixedSkill }
				end
				local use, consumed = Map(row.use)
				local produce, produced = Map(row.produce)
				if not produced then
					Reject("positive deterministic item production required")
				end
				if row.role == "auxiliary" and not consumed then
					Reject("free auxiliary craft has no finite rank")
				end
				local recipe = {
					recipeID = row.recipeID,
					professionID = row.professionID,
					role = row.role,
					available = row.available,
					eligibility = eligibility,
					scope = row.scope,
					skillEffect = row.skillEffect,
					productionLaw = row.productionLaw,
					use = use,
					produce = produce,
					evidence = {
						revision = row.evidence.revision,
						allocation = row.evidence.allocation,
						clientBuild = row.evidence.clientBuild,
					},
				}
				recipes[row.recipeID] = recipe
				if row.role == "auxiliary" then
					auxiliary[#auxiliary + 1] = recipe
				end
				for item in pairs(use) do
					for product in pairs(produce) do
						if not graph[item][product] then
							graph[item][product], indegree[product] = true, indegree[product] + 1
						end
						Tick()
					end
				end
			end
			-- Kahn's order includes every consume-to-produce edge, even for
			-- unavailable declared recipes. Smallest item ID breaks ties.
			local remaining = 0
			for _ in pairs(graph) do
				remaining = remaining + 1
				Tick()
			end
			while remaining > 0 do
				local first
				for item, degree in pairs(indegree) do
					if degree == 0 and (not first or item < first) then
						first = item
					end
					Tick()
				end
				if not first then
					Reject("cyclic consume-to-produce graph has no declared finite rank")
				end
				topological[#topological + 1], indegree[first], remaining = first, nil, remaining - 1
				for product in pairs(graph[first]) do
					indegree[product] = indegree[product] - 1
					Tick()
				end
			end
			local physical
			if route.skillCap ~= nil then
				if not Integer(route.skillCap) then
					Reject("invalid physical skill cap")
				end
				physical = { cap = route.skillCap }
			end
			local previousTarget
			for _, leg in ipairs(route.legs) do
				Fields(
					leg,
					{ recipeID = true, fromSkill = true, toSkill = true, skillUps = true, thresholds = true },
					"unsupported crafted main leg"
				)
				local recipe = recipes[leg.recipeID]
				if not recipe or recipe.role ~= "main" then
					Reject("main leg requires declared main recipe identity")
				end
				if physical then
					if
						not Integer(leg.fromSkill)
						or not Integer(leg.toSkill)
						or leg.toSkill > physical.cap
						or (previousTarget and previousTarget ~= leg.fromSkill)
					then
						Reject("physical skill legs must be contiguous and within cap")
					end
					previousTarget = leg.toSkill
				end
				local prepared, _, failure = ns.Demand.Prepare({
					legs = {
						{
							fromSkill = leg.fromSkill,
							toSkill = leg.toSkill,
							skillUps = leg.skillUps,
							thresholds = leg.thresholds,
							use = recipe.use,
							rawConsumption = true,
							deterministicOutput = true,
						},
					},
					held = {},
					buy = {},
				}, Tick, physical)
				if failure then
					Reject(failure.reasons[1])
				end
				for _, stage in ipairs(assert(prepared)) do
					stages[#stages + 1] = {
						chance = stage.chance,
						skill = stage.skill,
						use = stage.use,
						recipeID = recipe.recipeID,
						produce = recipe.produce,
						available = recipe.available,
						eligibility = recipe.eligibility,
						role = "main",
					}
					Tick()
				end
			end
		else
			if type(input.route) == "table" then
				for key in pairs(input.route) do
					if key ~= "legs" and key ~= "held" and key ~= "buy" then
						Reject("unsupported finite route law")
					end
					Tick()
				end
				if type(input.route.legs) == "table" then
					local fields = {
						fromSkill = true,
						toSkill = true,
						skillUps = true,
						thresholds = true,
						use = true,
						rawConsumption = true,
						deterministicOutput = true,
					}
					for _, leg in pairs(input.route.legs) do
						if type(leg) == "table" then
							for key in pairs(leg) do
								if not fields[key] then
									Reject("unsupported finite craft transition")
								end
								Tick()
							end
						end
					end
				end
			end
			local failure
			local raw = input.route
			---@cast raw SkillUpJointDemandInput
			stages, held, failure = ns.Demand.Prepare(raw, Tick)
			if failure then
				return Unknown(failure.reasons[1])
			end
		end
		assert(stages and held)
		for item, count in pairs(input.route.buy) do
			if not Integer(item) or item == 0 or not Integer(count) or count ~= 0 then
				Reject("initialOrders exclusively owns acquired inventory")
			end
			Tick()
		end
		if not Integer(input.walletCopper) or not Nonnegative(input.failureLoss) then
			Reject("explicit finite wallet and nonnegative terminal failure loss required")
		end
		for _, field in ipairs({
			"currencies",
			"stock",
			"tokenValues",
			"terminalCarry",
			"initialVisitMoney",
			"refillVisitMoney",
			"initialVisitValue",
			"refillVisitValue",
		}) do
			if type(input[field]) ~= "table" then
				Reject("explicit typed balances and valuation laws required")
			end
		end
		Dense(input.sources)
		Dense(input.initialOrders)
		Dense(input.assumptions)
		if not Integer(input.sourceRevision) then
			Reject("dated source revision required")
		end
		local assumptions = {}
		for _, row in ipairs(input.assumptions) do
			if
				type(row) ~= "table"
				or type(row.offerID) ~= "string"
				or row.offerID == ""
				or type(row.field) ~= "string"
				or row.field == ""
				or not Integer(row.revision)
				or type(row.provenance) ~= "string"
				or row.provenance == ""
				or type(row.scope) ~= "string"
				or row.scope == ""
				or not Nonnegative(row.observedAt)
				or type(row.observationRevision) ~= "string"
				or row.observationRevision == ""
				or not Integer(row.session)
				or not Integer(row.index)
			then
				Reject("complete dated scoped source assumptions required")
			end
			assumptions[#assumptions + 1] = {
				offerID = row.offerID,
				field = row.field,
				revision = row.revision,
				provenance = row.provenance,
				scope = row.scope,
				observedAt = row.observedAt,
				observationRevision = row.observationRevision,
				session = row.session,
				index = row.index,
			}
			Tick()
		end
		local exact = ns.Dyadic.Create(options.limbLimit, Tick)
		local n, add, mul, cmp = exact.Number, exact.Add, exact.Multiply, exact.Compare
		local zero, one = n(0), n(1)
		local coordinates, coordinateIndex, initialBalances = {}, {}, {}
		local function Coordinate(key, balance)
			if not coordinateIndex[key] then
				if #coordinates >= options.coordinateLimit then
					Reject("finite coordinate budget exhausted")
				end
				coordinates[#coordinates + 1] = key
				coordinateIndex[key] = #coordinates
				initialBalances[#coordinates] = balance or 0
			end
			Tick()
			return coordinateIndex[key]
		end
		local items = {}
		for item in pairs(held) do
			items[#items + 1] = item
			Tick()
		end
		table.sort(items)
		for _, item in ipairs(items) do
			Coordinate("item:" .. string.format("%.0f", item), held[item])
		end
		local currencies = {}
		for id, count in pairs(input.currencies) do
			if not Integer(id) or id == 0 or not Integer(count) then
				Reject("invalid currency inventory")
			end
			currencies[#currencies + 1] = id
			Tick()
		end
		table.sort(currencies)
		for _, id in ipairs(currencies) do
			Coordinate("currency:" .. string.format("%.0f", id), input.currencies[id])
		end
		local poolKeys, poolIndex, initialStock = {}, {}, {}
		for key, count in pairs(input.stock) do
			if type(key) ~= "string" or key == "" or not Integer(count) then
				Reject("finite stock opportunity law required")
			end
			poolKeys[#poolKeys + 1] = key
			Tick()
		end
		table.sort(poolKeys)
		if #poolKeys > options.coordinateLimit then
			Reject("finite stock coordinate budget exhausted")
		end
		for i, key in ipairs(poolKeys) do
			poolIndex[key], initialStock[i] = i, input.stock[key]
			Tick()
		end
		local sources, identities, vendors = {}, {}, {}
		local sourceFields = {
			offerID = true,
			npcID = true,
			itemID = true,
			bundleUnits = true,
			moneyCopper = true,
			costs = true,
			maxBundles = true,
			stockKey = true,
			stockPerBundle = true,
			vendor = true,
			access = true,
			priceLaw = true,
			futureDelivery = true,
		}

		for _, row in ipairs(input.sources) do
			if
				type(row) ~= "table"
				or type(row.offerID) ~= "string"
				or row.offerID == ""
				or identities[row.offerID]
				or (row.npcID ~= nil and (not Integer(row.npcID) or row.npcID == 0))
				or not Integer(row.itemID)
				or row.itemID == 0
				or not Integer(row.bundleUnits)
				or row.bundleUnits == 0
				or not Integer(row.moneyCopper)
				or not Integer(row.maxBundles)
				or row.maxBundles == 0
				or not Integer(row.stockPerBundle)
				or row.stockPerBundle == 0
				or not poolIndex[row.stockKey]
				or type(row.vendor) ~= "string"
				or row.vendor == ""
				or type(row.access) ~= "boolean"
				or row.priceLaw ~= "fixed"
				or type(row.costs) ~= "table"
				or type(row.futureDelivery) ~= "table"
				or not Nonnegative(row.futureDelivery.chance)
				or row.futureDelivery.chance > 1
				or type(row.futureDelivery.payOnFailure) ~= "boolean"
			then
				Reject("complete distinct finite source and delivery laws required")
			end
			for key in pairs(row) do
				if not sourceFields[key] then
					Reject("unsupported finite source law")
				end
				Tick()
			end
			for key in pairs(row.futureDelivery) do
				if key ~= "chance" and key ~= "payOnFailure" then
					Reject("unsupported future delivery law")
				end
				Tick()
			end
			identities[row.offerID] = true
			local costs = {}
			local keys = {}
			for key, count in pairs(row.costs) do
				local kind, id
				if type(key) == "string" then
					kind, id = key:match("^(%a+):(%d+)$")
				end
				local numeric = tonumber(id)
				if
					(kind ~= "item" and kind ~= "currency")
					or not Integer(numeric)
					or numeric == 0
					or key ~= kind .. ":" .. string.format("%.0f", numeric)
					or not Integer(count)
					or not Nonnegative(input.tokenValues[key])
				then
					Reject("canonical typed payment and explicit token valuation required")
				end
				keys[#keys + 1] = key
				Tick()
			end
			table.sort(keys)
			for _, key in ipairs(keys) do
				costs[Coordinate(key)] = row.costs[key]
			end
			local product = Coordinate("item:" .. string.format("%.0f", row.itemID))
			local p = n(row.futureDelivery.chance)
			sources[#sources + 1] = {
				offerID = row.offerID,
				npcID = row.npcID,
				itemID = row.itemID,
				product = product,
				units = row.bundleUnits,
				money = row.moneyCopper,
				ceiling = row.maxBundles,
				pool = poolIndex[row.stockKey],
				stockUnits = row.stockPerBundle,
				vendor = row.vendor,
				access = row.access,
				costs = costs,
				probability = p,
				complement = exact.Subtract(one, p),
				payOnFailure = row.futureDelivery.payOnFailure,
			}
			if not vendors[row.vendor] then
				local values = {}
				for _, field in ipairs({
					"initialVisitMoney",
					"refillVisitMoney",
					"initialVisitValue",
					"refillVisitValue",
				}) do
					local value = input[field][row.vendor]
					if not Nonnegative(value) or (field:find("Money", 1, true) and not Integer(value)) then
						Reject("explicit monetary fares and opportunity visit values required")
					end
					values[field] = value
				end
				vendors[row.vendor] = values
			end
			Tick()
		end
		for _, field in ipairs({
			"tokenValues",
			"terminalCarry",
			"initialVisitMoney",
			"refillVisitMoney",
			"initialVisitValue",
			"refillVisitValue",
		}) do
			for key, value in pairs(input[field]) do
				if
					type(key) ~= "string"
					or key == ""
					or not Nonnegative(value)
					or (field:find("Money", 1, true) and not Integer(value))
				then
					Reject("finite nonnegative typed valuation required")
				end
				Tick()
			end
		end
		if crafted then
			for _, field in ipairs({ "terminalCarry", "tokenValues" }) do
				local keys = {}
				for key in pairs(input[field]) do
					local kind, id = key:match("^(%a+):(%d+)$")
					local numeric = tonumber(id)
					if
						(kind ~= "item" and kind ~= "currency")
						or not Integer(numeric)
						or numeric == 0
						or key ~= kind .. ":" .. string.format("%.0f", numeric)
					then
						Reject("canonical typed valuation coordinates required")
					end
					keys[#keys + 1] = key
					Tick()
				end
				table.sort(keys)
				for _, key in ipairs(keys) do
					Coordinate(key)
				end
			end
		end
		local carryValues, tokenValues = {}, {}
		for i, key in ipairs(coordinates) do
			if not Nonnegative(input.terminalCarry[key]) then
				Reject("explicit terminal carry valuation for every coordinate required")
			end
			carryValues[i], tokenValues[i] = n(input.terminalCarry[key]), n(input.tokenValues[key] or 0)
			Tick()
		end
		local compiled, compiledAuxiliary = {}, {}
		local function Compile(stage, neutral)
			local use, produce, consumed = {}, {}, false
			for item, count in pairs(stage.use) do
				use[coordinateIndex["item:" .. string.format("%.0f", item)]], consumed = count, consumed or count > 0
				Tick()
			end
			for item, count in pairs(stage.produce or {}) do
				produce[coordinateIndex["item:" .. string.format("%.0f", item)]] = count
				Tick()
			end
			if not consumed and (neutral or stage.chance ~= 1) then
				Reject("zero-progress zero-consumption craft has no finite rank")
			end
			local p = n(neutral and 0 or stage.chance)
			return {
				use = use,
				produce = produce,
				recipeID = stage.recipeID,
				role = stage.role,
				available = stage.available ~= false,
				skill = stage.skill,
				eligibility = stage.eligibility,
				probability = p,
				complement = exact.Subtract(one, p),
			}
		end
		for _, stage in ipairs(stages) do
			compiled[#compiled + 1] = Compile(stage, false)
		end
		for _, recipe in ipairs(auxiliary) do
			compiledAuxiliary[#compiledAuxiliary + 1] = Compile(recipe, true)
		end
		local rankCoordinates = {}
		for _, item in ipairs(topological) do
			rankCoordinates[#rankCoordinates + 1] = coordinateIndex["item:" .. string.format("%.0f", item)]
			Tick()
		end
		local function Rank(state)
			local units = 0
			for _, count in ipairs(state.stock) do
				units = Safe(units + count)
				Tick()
			end
			local rank = { units, #compiled + 1 - state.stage }
			for _, coordinate in ipairs(rankCoordinates) do
				rank[#rank + 1] = state.balances[coordinate]
				Tick()
			end
			return rank
		end
		local function Decreases(before, after)
			local a, b = Rank(before), Rank(after)
			for i = 1, #a do
				if b[i] ~= a[i] then
					return b[i] < a[i]
				end
				Tick()
			end
			return false
		end
		local function Vector()
			return { zero, zero, zero, zero, zero, zero, zero }
		end
		local function Objective(value)
			local total = zero
			for i = 2, 6 do
				total = add(total, value[i])
			end
			return total
		end
		local function Amount(balances, values)
			local total = zero
			for i, count in ipairs(balances) do
				total = add(total, mul(n(count), values[i]))
				Tick()
			end
			return total
		end
		local initialQuantities = {}
		for i = 1, #sources do
			initialQuantities[i] = 0
		end
		local acquisitions = {}
		for _, order in ipairs(input.initialOrders) do
			if
				type(order) ~= "table"
				or not Integer(order.source)
				or not sources[order.source]
				or not Integer(order.bundles)
				or order.bundles == 0
				or order.bundles > sources[order.source].ceiling
			then
				Reject("legal certain initial transactions required")
			end
			initialQuantities[order.source] = Safe(initialQuantities[order.source] + order.bundles)
			local source, costs = sources[order.source], {}
			for coordinate, count in pairs(source.costs) do
				costs[coordinates[coordinate]] = Safe(count * order.bundles)
				Tick()
			end
			acquisitions[#acquisitions + 1] = {
				source = order.source,
				offerID = source.offerID,
				npcID = source.npcID,
				vendor = source.vendor,
				itemID = source.itemID,
				bundles = order.bundles,
				bundleUnits = source.units,
				units = Safe(source.units * order.bundles),
				moneyCopper = Safe(source.money * order.bundles),
				costs = costs,
			}
			Tick()
		end
		-- Reserve every typed payment against PRE-action balances. Delivered
		-- products become available only to later actions, never this same batch.
		local function Batch(state, quantities, initialBatch)
			local debit, costs, selected = {}, {}, {}
			local money, fare, value, visits, positive = 0, 0, zero, 0, false
			for i = 1, #initialStock do
				debit[i] = 0
			end
			for i = 1, #coordinates do
				costs[i] = 0
			end
			for i, count in ipairs(quantities) do
				if count > 0 then
					local source = sources[i]
					if not source.access then
						return nil
					end
					positive = true
					debit[source.pool] = Safe(debit[source.pool] + Safe(count * source.stockUnits))
					money = Safe(money + Safe(count * source.money))
					for coordinate, cost in pairs(source.costs) do
						costs[coordinate] = Safe(costs[coordinate] + Safe(count * cost))
						Tick()
					end
					if not selected[source.vendor] then
						selected[source.vendor] = true
						local vendor = vendors[source.vendor]
						fare = Safe(fare + vendor[initialBatch and "initialVisitMoney" or "refillVisitMoney"])
						value = add(value, n(vendor[initialBatch and "initialVisitValue" or "refillVisitValue"]))
						visits = visits + 1
					end
				end
				Tick()
			end
			if Safe(money + fare) > state.wallet then
				return nil
			end
			for i, count in ipairs(costs) do
				if count > state.balances[i] then
					return nil
				end
				Tick()
			end
			for i, count in ipairs(debit) do
				if count > state.stock[i] then
					return nil
				end
				Tick()
			end
			return {
				debit = debit,
				costs = costs,
				fare = fare,
				visitValue = value,
				visits = visits,
				positive = positive,
			}
		end
		local function Delivery(state, quantities, delivered, batch)
			local balances, stock = Copy(state.balances), Copy(state.stock)
			local money, costs = batch.fare, {}
			for i = 1, #coordinates do
				costs[i] = 0
			end
			for i, source in ipairs(sources) do
				local paid = source.payOnFailure and quantities[i] or delivered[i]
				money = Safe(money + Safe(paid * source.money))
				for coordinate, count in pairs(source.costs) do
					costs[coordinate] = Safe(costs[coordinate] + Safe(paid * count))
					Tick()
				end
			end
			for i, count in ipairs(costs) do
				balances[i] = balances[i] - count
				Tick()
			end
			for i, source in ipairs(sources) do
				balances[source.product] = Safe(balances[source.product] + Safe(delivered[i] * source.units))
				Tick()
			end
			for i, count in ipairs(batch.debit) do
				stock[i] = stock[i] - count
				Tick()
			end
			local immediate = Vector()
			immediate[2], immediate[3], immediate[4], immediate[7] =
				n(money), Amount(costs, tokenValues), batch.visitValue, n(batch.visits)
			return { stage = state.stage, balances = balances, stock = stock, wallet = state.wallet - money }, immediate
		end
		local start = { stage = 1, balances = initialBalances, stock = initialStock, wallet = input.walletCopper }
		local initialBatch = Batch(start, initialQuantities, true)
		if not initialBatch then
			return {
				status = "infeasible",
				costKnown = false,
				reasons = { "initial atomic payments or stock infeasible" },
			}
		end
		-- Initial delivery is explicitly certain, including sources whose future
		-- delivery may fail. Every initial transaction pays its complete quote.
		local initialState, initialCost = Delivery(start, initialQuantities, initialQuantities, initialBatch)
		local nodes, ordered, actionCount, transitionCount = {}, {}, 0, 0
		local function Key(state, coverage)
			local function Encode(values)
				local encoded = {}
				for i, value in ipairs(values) do
					encoded[i] = string.format("%.0f", value)
					Tick()
				end
				return table.concat(encoded, ",")
			end
			-- Lua's default tostring rounds large integers to about 14 digits.
			-- Every accepted integer must remain distinct in the memoized DAG.
			return (coverage and "C" or "A")
				.. ":"
				.. string.format("%.0f", state.stage)
				.. ":"
				.. Encode(state.balances)
				.. ":"
				.. Encode(state.stock)
				.. ":"
				.. string.format("%.0f", state.wallet)
		end
		local function Node(state, coverage)
			local key = Key(state, coverage)
			if not nodes[key] then
				if #ordered >= options.stateLimit then
					Reject("finite state budget exhausted; no certificate")
				end
				nodes[key] = { state = state, key = key, coverage = coverage }
				ordered[#ordered + 1] = nodes[key]
			end
			Tick()
			return nodes[key]
		end
		local function Orders(quantities)
			local orders = {}
			for i, count in ipairs(quantities) do
				while count > 0 do
					local part = math.min(count, sources[i].ceiling)
					orders[#orders + 1], count = { source = i, bundles = part }, count - part
					Tick()
				end
			end
			return orders
		end
		local function Actions(node)
			local state, actions = node.state, {}
			local terminal = Vector()
			terminal[5] = Amount(state.balances, carryValues)
			if state.stage > #compiled then
				terminal[1] = one
			else
				terminal[6] = n(input.failureLoss)
			end
			actions[1] = { kind = state.stage > #compiled and "complete" or "stop", terminal = terminal, edges = {} }
			if state.stage > #compiled then
				return actions
			end
			local function Edge(action, probability, successor, immediate)
				if cmp(probability, zero) == 0 then
					return
				end
				if crafted and not Decreases(state, successor) then
					Reject("transition violates declared lexicographic rank")
				end
				transitionCount = transitionCount + 1
				action.edges[#action.edges + 1] =
					{ probability = probability, node = Node(successor, node.coverage), immediate = immediate }
				Tick()
			end
			local function Craft(stage, neutral)
				if not stage.available then
					return
				end
				local bounds = stage.eligibility
				if bounds then
					local skill = bounds.fixedSkill or compiled[state.stage].skill
					if skill < bounds.fromSkill or skill > bounds.toSkill then
						return
					end
				end
				for i, count in pairs(stage.use) do
					if state.balances[i] < count then
						return
					end
					Tick()
				end
				local balances = Copy(state.balances)
				for i, count in pairs(stage.use) do
					balances[i] = balances[i] - count
					Tick()
				end
				for i, count in pairs(stage.produce) do
					balances[i] = Safe(balances[i] + count)
					Tick()
				end
				local craft = { kind = "craft", recipeID = stage.recipeID, role = stage.role, edges = {} }
				if not neutral then
					Edge(
						craft,
						stage.probability,
						{ stage = state.stage + 1, balances = balances, stock = state.stock, wallet = state.wallet },
						Vector()
					)
				end
				Edge(
					craft,
					stage.complement,
					{ stage = state.stage, balances = balances, stock = state.stock, wallet = state.wallet },
					Vector()
				)
				actions[#actions + 1] = craft
			end
			Craft(compiled[state.stage], false)
			for _, recipe in ipairs(compiledAuxiliary) do
				Craft(recipe, true)
			end
			if node.coverage then
				return actions
			end
			local quantities, bounds = {}, {}
			for i, source in ipairs(sources) do
				quantities[i], bounds[i] =
					0, source.access and math.floor(state.stock[source.pool] / source.stockUnits) or 0
				Tick()
			end
			while #sources > 0 do
				local i = #sources
				while i > 0 and quantities[i] == bounds[i] do
					quantities[i], i = 0, i - 1
					Tick()
				end
				if i == 0 then
					break
				end
				quantities[i] = quantities[i] + 1
				local batch = Batch(state, quantities, false)
				if batch then
					local action = { kind = "acquire", orders = Orders(quantities), edges = {} }
					-- Exact binomial kernels by repeated convolution. No factorial,
					-- rounded coefficient or fitted delivery cutoff is needed.
					local distributions = {}
					for index, count in ipairs(quantities) do
						local distribution = { [0] = one }
						local source = sources[index]
						for attempt = 1, count do
							local following = {}
							for successes = 0, attempt do
								following[successes] = add(
									mul(distribution[successes] or zero, source.complement),
									mul(distribution[successes - 1] or zero, source.probability)
								)
								Tick()
							end
							distribution = following
						end
						distributions[index] = distribution
					end
					local delivered = {}
					for index = 1, #sources do
						delivered[index] = 0
					end
					while true do
						local probability = one
						for index, successes in ipairs(delivered) do
							probability = mul(probability, distributions[index][successes])
							Tick()
						end
						if cmp(probability, zero) > 0 then
							local successor, immediate = Delivery(state, quantities, delivered, batch)
							Edge(action, probability, successor, immediate)
						end
						local index = #sources
						while index > 0 and delivered[index] == quantities[index] do
							delivered[index], index = 0, index - 1
							Tick()
						end
						if index == 0 then
							break
						end
						delivered[index] = delivered[index] + 1
					end
					actions[#actions + 1] = action
				end
				Tick()
			end
			return actions
		end
		local function Solve(root)
			local stack = { root }
			while #stack > 0 do
				local node = stack[#stack]
				if not node.actions then
					node.actions, node.action, node.edge = Actions(node), 1, 1
					actionCount = actionCount + #node.actions
				end
				local action = node.actions[node.action]
				if not action then
					node.value, node.selected = assert(node.best), node.winner
					node.actions, node.best, node.winner = nil, nil, nil
					stack[#stack] = nil
				else
					local edge = action.edges[node.edge]
					if edge and not edge.node.value then
						stack[#stack + 1] = edge.node
					elseif edge then
						local value = action.value or Vector()
						for component = 1, #COMPONENTS do
							value[component] = add(
								value[component],
								mul(edge.probability, add(edge.immediate[component], edge.node.value[component]))
							)
						end
						action.value, node.edge = value, node.edge + 1
					else
						local value = action.terminal or action.value
						if
							not node.best
							or (node.coverage and cmp(value[1], node.best[1]) > 0)
							or (not node.coverage and cmp(Objective(value), Objective(node.best)) < 0)
						then
							node.best, node.winner = value, action
						end
						node.action, node.edge = node.action + 1, 1
					end
				end
				Tick()
			end
			return root.value
		end
		local coverageRoot = Node(initialState, true)
		local coverage = Solve(coverageRoot)
		local adaptiveRoot = Node(initialState, false)
		local value = Solve(adaptiveRoot)
		for i = 2, #COMPONENTS do
			value[i] = add(value[i], initialCost[i])
		end
		---@type SkillUpFiniteAcquisitionResult
		local result = {
			status = "complete",
			costKnown = true,
			reasons = {},
			sourceRevision = input.sourceRevision,
			assumptions = assumptions,
			acquisitions = acquisitions,
		}
		local function Publish(name, amount)
			local lower, upper = exact.Bounds(amount)
			if upper == math.huge then
				Reject("finite objective publication overflow; no certificate")
			end
			if name == "coverage" or name == "success" then
				lower, upper = math.max(0, lower), math.min(1, upper)
			end
			result[name .. "Lower"], result[name .. "Upper"] = lower, upper
		end
		Publish("coverage", coverage[1])
		for i, name in ipairs(COMPONENTS) do
			Publish(name, value[i])
		end
		Publish("cost", add(add(value[2], value[3]), value[4]))
		Publish("objective", Objective(value))
		local policy, coveragePolicy = {}, {}
		for _, node in ipairs(ordered) do
			local selected, successors = assert(node.selected), {}
			for _, edge in ipairs(selected.edges) do
				local lower, upper = exact.Bounds(edge.probability)
				successors[#successors + 1] = {
					state = edge.node.key,
					probabilityLower = math.max(0, lower),
					probabilityUpper = math.min(1, upper),
				}
			end
			local target = node.coverage and coveragePolicy or policy
			target[#target + 1] = {
				state = node.key,
				kind = selected.kind,
				recipeID = selected.recipeID,
				role = selected.role,
				orders = selected.orders,
				successors = successors,
				rank = crafted and Rank(node.state) or nil,
			}
			if node.coverage and not crafted then
				policy[#policy + 1] = target[#target]
			end
			Tick()
		end
		local function CopyMap(values)
			local copied = {}
			for key, amount in pairs(values) do
				copied[key] = amount
				Tick()
			end
			return copied
		end
		local bindings = {}
		for i, source in ipairs(input.sources) do
			bindings[i] = {
				offerID = source.offerID,
				npcID = source.npcID,
				itemID = source.itemID,
				bundleUnits = source.bundleUnits,
				moneyCopper = source.moneyCopper,
				costs = CopyMap(source.costs),
				maxBundles = source.maxBundles,
				stockKey = source.stockKey,
				stockPerBundle = source.stockPerBundle,
				vendor = source.vendor,
				access = source.access,
				priceLaw = source.priceLaw,
				futureDelivery = {
					chance = source.futureDelivery.chance,
					payOnFailure = source.futureDelivery.payOnFailure,
				},
			}
			Tick()
		end
		local routeLaws = {}
		for i, stage in ipairs(stages) do
			local use = {}
			for item, count in pairs(stage.use) do
				use["item:" .. string.format("%.0f", item)] = count
				Tick()
			end
			local produce = {}
			for item, count in pairs(stage.produce or {}) do
				produce["item:" .. string.format("%.0f", item)] = count
				Tick()
			end
			routeLaws[i] = {
				chance = stage.chance,
				skill = stage.skill,
				use = use,
				produce = crafted and produce or nil,
				recipeID = stage.recipeID,
				role = stage.role,
			}
		end
		local laws = {
			skillCap = crafted and input.route.skillCap or nil,
			failureLoss = input.failureLoss,
			tokenValues = CopyMap(input.tokenValues),
			terminalCarry = CopyMap(input.terminalCarry),
			initialVisitMoney = CopyMap(input.initialVisitMoney),
			refillVisitMoney = CopyMap(input.refillVisitMoney),
			initialVisitValue = CopyMap(input.initialVisitValue),
			refillVisitValue = CopyMap(input.refillVisitValue),
		}
		result.certificate = {
			kind = "finite-dag-exhaustive",
			sources = bindings,
			laws = laws,
			stages = routeLaws,
			objective = input.objective,
			states = #ordered,
			actions = actionCount,
			transitions = transitionCount,
			initialState = adaptiveRoot.key,
			-- Structured states are copied at their producer, with the same work
			-- budget as the graph. Consumers need no second key decoder.
			preInitialState = Key(start, false),
			preInitialResources = {
				stage = start.stage,
				balances = Copy(start.balances),
				stock = Copy(start.stock),
				wallet = start.wallet,
			},
			initialResources = {
				stage = initialState.stage,
				balances = Copy(initialState.balances),
				stock = Copy(initialState.stock),
				wallet = initialState.wallet,
			},
			coverageState = coverageRoot.key,
			coordinates = Copy(coordinates),
			pools = Copy(poolKeys),
			policy = policy,
			coveragePolicy = coveragePolicy,
			coverageInterpretation = "maximum-craft-only-completion",
			craftedVersion = crafted and input.route.version or nil,
			recipes = crafted and recipes or nil,
			topologicalItems = crafted and Copy(topological) or nil,
			rankSchema = crafted and "remaining-opportunities,remaining-main-stages,topological-item-balances" or nil,
		}
		exactResults[job] = { coverage = coverage[1], objective = Objective(value), revision = revision }
		return result
	end)
	---@param self SkillUpFiniteAcquisitionJob
	local function Cancel(self)
		exactResults[self] = nil
		thread = nil
		self.result =
			{ status = "cancelled", costKnown = false, reasons = { "finite acquisition snapshot invalidated" } }
	end
	---@param self SkillUpFiniteAcquisitionJob
	---@param work integer
	local function Advance(self, work)
		assert(Integer(work) and work > 0, "positive finite integer advance budget required")
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
				if type(result) == "table" and result.finiteAcquisition then
					self.result = Unknown(result.finiteAcquisition)
				elseif
					result == "exact arithmetic limb budget exhausted"
					or result == "exact arithmetic exponent budget exhausted"
				then
					self.result = Unknown(result)
				else
					error(result)
				end
				thread = nil
			elseif coroutine.status(active) == "dead" then
				self.result, thread = result, nil
			end
		end
		return self.result
	end
	job = { result = initial, Cancel = Cancel, Advance = Advance }
	return job
end

-- Private values are valid only for the chance revision that produced them.
-- Rounded publication bounds never decide selection eligibility or ordering.
local function Exact(job)
	local record = exactResults[job]
	if record and record.revision ~= ns.Model.ChanceRevision() then
		job:Cancel()
		return nil
	end
	return record
end

---@param input SkillUpFiniteAcquisitionInput
---@param alpha number
---@return SkillUpFiniteSelectionJob
function Finite.Select(input, alpha)
	local revision = ns.Model.ChanceRevision()
	---@type SkillUpFiniteAcquisitionJob?
	local child, bestJob
	---@type SkillUpFiniteSelectionResult
	local initial = { status = "calculating", costKnown = false, reasons = {} }
	---@type thread?
	local thread = coroutine.create(function()
		if not Nonnegative(alpha) or alpha > 1 then
			return Unknown("explicit starting coverage alpha in [0,1] required")
		end
		if
			type(input) ~= "table"
			or type(input.options) ~= "table"
			or type(input.initialOrders) ~= "table"
			or next(input.initialOrders) ~= nil
		then
			return Unknown("finite selection requires an empty initialOrders decision slot")
		end
		local options = {}
		for _, field in ipairs({ "workLimit", "stateLimit", "coordinateLimit", "limbLimit" }) do
			if not Integer(input.options[field]) or input.options[field] == 0 then
				return Unknown("explicit positive finite selection budgets required")
			end
			options[field] = input.options[field]
		end
		local work, evaluated, eligible = 0, 0, 0
		local function Reject(reason)
			error({ finiteSelection = reason }, 0)
		end
		local function Tick()
			work = work + 1
			if work > options.workLimit then
				Reject("aggregate finite selection work budget exhausted; no optimum certificate")
			end
			coroutine.yield()
		end
		local function Safe(value)
			if not Integer(value) then
				Reject("selected gross inventory exceeds exact integer range")
			end
			return value
		end
		local exact = ns.Dyadic.Create(options.limbLimit, Tick)
		local target = exact.Number(alpha)
		local function Orders(quantities)
			local orders = {}
			for i, count in ipairs(quantities) do
				while count > 0 do
					local part = math.min(count, input.sources[i].maxBundles)
					orders[#orders + 1], count = { source = i, bundles = part }, count - part
					Tick()
				end
			end
			return orders
		end
		local bestQuantities, bestOrders
		local sourceEvidence
		local function Evaluate(quantities)
			local candidate, orders, childOptions = {}, Orders(quantities), {}
			for key, value in pairs(input) do
				candidate[key] = value
				Tick()
			end
			for key, value in pairs(options) do
				childOptions[key] = value
				Tick()
			end
			candidate.initialOrders, candidate.options = orders, childOptions
			---@cast candidate SkillUpFiniteAcquisitionInput
			child = Finite.Start(candidate)
			while child.result.status == "calculating" do
				child:Advance(1)
				Tick()
			end
			evaluated = evaluated + 1
			if child.result.status == "infeasible" then
				child = nil
				return
			end
			if child.result.status ~= "complete" then
				Reject(child.result.reasons[1] or "unresolved finite initial candidate")
			end
			if not sourceEvidence then
				sourceEvidence =
					{ sourceRevision = child.result.sourceRevision, assumptions = child.result.assumptions }
			end
			local record = Exact(child)
			if not record then
				Reject("finite initial candidate invalidated")
			end
			assert(record)
			if exact.Compare(record.coverage, target) >= 0 then
				eligible = eligible + 1
				local previous = bestJob and Exact(bestJob)
				if bestJob and not previous then
					Reject("finite incumbent invalidated")
				end
				if not previous or exact.Compare(record.objective, previous.objective) < 0 then
					bestJob, bestQuantities, bestOrders = child, {}, orders
					for i, count in ipairs(quantities) do
						bestQuantities[i] = count
						Tick()
					end
				end
			end
			child = nil
		end
		-- The empty order validates the entire fixed-initial schema before source
		-- bounds are read. Unknown anywhere prevents a global optimum claim.
		Evaluate({})
		local bounds, quantities = {}, {}
		for i, source in ipairs(input.sources) do
			bounds[i] = source.access and math.floor(input.stock[source.stockKey] / source.stockPerBundle) or 0
			quantities[i] = 0
			if bestQuantities and bestQuantities[i] == nil then
				bestQuantities[i] = 0
			end
			Tick()
		end
		while #quantities > 0 do
			local index = #quantities
			while index > 0 and quantities[index] == bounds[index] do
				quantities[index], index = 0, index - 1
				Tick()
			end
			if index == 0 then
				break
			end
			quantities[index] = quantities[index] + 1
			Evaluate(quantities)
		end
		local selection = {
			kind = "finite-initial-enumeration",
			evaluated = evaluated,
			eligible = eligible,
			domainBounds = bounds,
			alpha = alpha,
		}
		if not bestJob then
			assert(sourceEvidence)
			return {
				status = "infeasible",
				costKnown = false,
				reasons = { "no finite initial order meets explicit starting coverage" },
				sourceRevision = sourceEvidence.sourceRevision,
				assumptions = sourceEvidence.assumptions,
				alpha = alpha,
				selection = selection,
			}
		end
		if not Exact(bestJob) then
			Reject("finite selected candidate invalidated")
		end
		local result = bestJob.result
		local have, items = {}, {}
		for item, count in pairs(input.route.held) do
			have[item], items[item] = count, count
			Tick()
		end
		for i, count in ipairs(bestQuantities) do
			local source = input.sources[i]
			items[source.itemID] = Safe((items[source.itemID] or 0) + Safe(count * source.bundleUnits))
			Tick()
		end
		result.alpha, result.orders, result.quantities = alpha, bestOrders, bestQuantities
		result.have, result.items, result.selection = have, items, selection
		return result
	end)
	---@param self SkillUpFiniteSelectionJob
	local function Cancel(self)
		if child then
			child:Cancel()
		end
		if bestJob then
			bestJob:Cancel()
		end
		child, bestJob, thread = nil, nil, nil
		self.result = { status = "cancelled", costKnown = false, reasons = { "finite selection snapshot invalidated" } }
	end
	---@param self SkillUpFiniteSelectionJob
	---@param work integer
	local function Advance(self, work)
		assert(Integer(work) and work > 0, "positive finite integer advance budget required")
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
				if type(result) == "table" and result.finiteSelection then
					self.result = Unknown(result.finiteSelection)
				elseif
					result == "exact arithmetic limb budget exhausted"
					or result == "exact arithmetic exponent budget exhausted"
				then
					self.result = Unknown(result)
				else
					error(result)
				end
				if child then
					child:Cancel()
				end
				if bestJob then
					bestJob:Cancel()
				end
				child, bestJob, thread = nil, nil, nil
			elseif coroutine.status(active) == "dead" then
				self.result, thread = result, nil
			end
		end
		return self.result
	end
	return { result = initial, Cancel = Cancel, Advance = Advance }
end

ns.FiniteAcquisition = { Start = Finite.Start, Select = Finite.Select }
