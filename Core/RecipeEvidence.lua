---@type string, SkillUpNamespace
local _, ns = ...
if ns.broken then
	return
end

-- Observations describe the native schema. Declarations supply the stronger
-- completed-attempt law, allocation and fixed prerequisites. Neither substitutes
-- for the other, and there is deliberately no automatic declaration/provider.
local Owner = {}
local revision = 0
local reading = 0
local observedBuild
local failures = {}
---@type table<integer, table>
local observations = {}
---@type table<integer, table>
local declarations = {}
local gates = { "rank", "training", "tools", "station", "access" }
local function Integer(value)
	return type(value) == "number" and value >= 0 and value <= 2 ^ 52 - 1 and value % 1 == 0
end
local function Text(value)
	return type(value) == "string" and value ~= ""
end
local function Changed()
	revision = revision + 1
	ns.Changed("recipeEvidence")
end

-- A bounded explicit stack owns all nested slot metadata, including variable
-- quantities and alternatives. Secrets remain missing rather than being read.
local function Copy(value, tick)
	local result, active = {}, {}
	local stack = { { source = value, target = result } }
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		error("recipe-plain-record-required", 0)
	end
	active[value] = true
	while #stack > 0 do
		tick()
		local frame = stack[#stack]
		local key, field = next(frame.source, frame.key)
		frame.key = key
		if key == nil then
			active[frame.source], stack[#stack] = nil, nil
		else
			key, field = ns.Readable(key), ns.Readable(field)
			if type(key) ~= "number" and type(key) ~= "string" then
				error("recipe-readable-key-required", 0)
			end
			if type(field) == "table" then
				if getmetatable(field) ~= nil or active[field] then
					error("recipe-plain-acyclic-record-required", 0)
				end
				local child = {}
				frame.target[key], active[field] = child, true
				stack[#stack + 1] = { source = field, target = child }
			elseif field == nil or type(field) == "number" or type(field) == "string" or type(field) == "boolean" then
				frame.target[key] = field
			else
				error("recipe-plain-record-required", 0)
			end
		end
	end
	return result
end
local function Budget(limit)
	if not Integer(limit) or limit == 0 then
		return nil
	end
	local work = 0
	return function()
		work = work + 1
		if work > limit then
			error("recipe-evidence-work-exhausted", 0)
		end
	end
end
local function Build()
	if type(GetBuildInfo) ~= "function" then
		return nil
	end
	local ok, _, build = pcall(GetBuildInfo)
	build = ok and ns.Readable(build)
	return Text(build) and build or nil
end
local function Dense(list, tick)
	if type(list) ~= "table" then
		return false
	end
	local count, largest = 0, 0
	for key in pairs(list) do
		tick()
		if not Integer(key) or key == 0 then
			return false
		end
		count, largest = count + 1, math.max(largest, key)
	end
	return count == largest
end

---@param recipeID integer
---@param allocation string Exact caller allocation identity, not an inferred selection.
---@param workLimit integer
---@param variant table? Variants are unsupported in this adapter.
---@return table?, string?
function Owner.Observe(recipeID, allocation, workLimit, variant)
	if reading > 0 then
		return nil, "recipe-evidence-reader-is-read-only"
	end
	if variant ~= nil then
		return nil, "recipe-variant-unsupported"
	end
	local tick = Budget(workLimit)
	if not tick or not Integer(recipeID) or recipeID == 0 or not Text(allocation) then
		return nil, "recipe-observation-identity-required"
	end
	local record = {
		recipeID = recipeID,
		allocation = allocation,
		clientBuild = Build(),
		variant = "default-non-recraft",
		missing = {},
	}
	local function Missing(code)
		record.missing[#record.missing + 1] = { code = code, recipeID = recipeID }
	end
	local api = C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic
	local ok, schema = false, nil
	if type(api) == "function" then
		ok, schema = pcall(api, recipeID, false)
	end
	schema = ok and ns.Readable(schema)
	if type(schema) == "table" then
		local copied, value = pcall(Copy, schema, tick)
		if copied then
			record.schematic = value
		else
			Missing(tostring(value))
		end
	else
		Missing("recipe-schematic-unavailable")
	end
	local professionAPI = C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoByRecipeID
	if type(professionAPI) == "function" then
		local readable, info = pcall(professionAPI, recipeID)
		info = readable and ns.Readable(info)
		local id = type(info) == "table" and ns.Readable(info.professionID)
		if Integer(id) and id > 0 then
			record.professionID = id
			local copied, value = pcall(Copy, info, tick)
			if copied then
				record.profession = value
			else
				Missing(tostring(value))
			end
		end
	end
	if not record.professionID then
		Missing("recipe-profession-unavailable")
	end
	if not record.clientBuild then
		Missing("recipe-build-unavailable")
	end
	local requirementsAPI = C_TradeSkillUI and C_TradeSkillUI.GetRecipeRequirements
	if type(requirementsAPI) == "function" then
		local readable, requirements = pcall(requirementsAPI, recipeID)
		requirements = readable and ns.Readable(requirements)
		local copied, value = pcall(Copy, requirements, tick)
		if copied then
			record.requirements = value
		else
			Missing("recipe-native-requirements-unavailable")
		end
	else
		Missing("recipe-native-requirements-unavailable")
	end
	local schematic = record.schematic
	if schematic then
		if schematic.isRecraft ~= false then
			Missing("recipe-variant-unsupported")
		end
		if schematic.recipeID ~= recipeID then
			Missing("recipe-native-identity-mismatch")
		end
		local checked, dense = pcall(Dense, schematic.reagentSlotSchematics, tick)
		if not checked or not dense then
			Missing("recipe-slots-unavailable")
		end
		if
			not Integer(schematic.quantityMin)
			or not Integer(schematic.quantityMax)
			or schematic.quantityMin > schematic.quantityMax
		then
			Missing("recipe-output-bounds-unavailable")
		end
	end
	-- Reobserving explicitly replaces allocation/freshness, even at equal bounds.
	record.revision = revision + 1
	observations[recipeID] = record
	observedBuild = record.clientBuild
	declarations, failures = {}, {}
	Changed()
	local copied, result = pcall(Copy, record, Budget(workLimit))
	if not copied then
		return nil, tostring(result)
	end
	return result
end

-- Allocation is exact slot selection, not a price-selected maker. This item-only
-- kernel rejects a native currency reagent or an unresolved slot explicitly.
local function Allocation(recipe, observed, allocation, tick)
	for key in pairs(allocation) do
		tick()
		if key ~= "identity" and key ~= "complete" and key ~= "slots" then
			return "recipe-variant-unsupported"
		end
	end
	local slots = observed.schematic.reagentSlotSchematics
	if not Dense(allocation.slots, tick) or #allocation.slots ~= #slots then
		return "recipe-allocation-incomplete"
	end
	local use, seen = {}, {}
	for index, slot in ipairs(slots) do
		tick()
		local choice = allocation.slots[index]
		if type(choice) == "table" then
			for key in pairs(choice) do
				tick()
				if key ~= "slotIndex" and key ~= "dataSlotIndex" and key ~= "itemID" and key ~= "quantity" then
					return "recipe-variant-unsupported"
				end
			end
		end
		if
			type(slot) ~= "table"
			or type(choice) ~= "table"
			or not Integer(slot.slotIndex)
			or slot.slotIndex == 0
			or not Integer(slot.dataSlotIndex)
			or slot.dataSlotIndex == 0
			or type(slot.required) ~= "boolean"
			or choice.slotIndex ~= slot.slotIndex
			or choice.dataSlotIndex ~= slot.dataSlotIndex
			or seen[slot.slotIndex]
			or not Integer(choice.quantity)
		then
			return "recipe-allocation-incomplete"
		end
		seen[slot.slotIndex] = true
		if choice.quantity == 0 then
			if slot.required then
				return "recipe-required-slot-missing"
			end
		else
			if not Integer(choice.itemID) or choice.itemID == 0 then
				return "recipe-item-allocation-required"
			end
			local matched = false
			if not Dense(slot.reagents, tick) then
				return "recipe-native-reagents-incomplete"
			end
			for _, reagent in ipairs(slot.reagents) do
				tick()
				if type(reagent) == "table" and reagent.itemID == choice.itemID and reagent.currencyID == nil then
					matched = true
				end
			end
			if not matched then
				return "recipe-allocation-item-mismatch"
			end
			local quantity = slot.quantityRequired
			if type(slot.variableQuantities) == "table" and next(slot.variableQuantities) then
				if not Dense(slot.variableQuantities, tick) then
					return "recipe-native-quantities-incomplete"
				end
				quantity = nil
				for _, variable in ipairs(slot.variableQuantities) do
					tick()
					if
						type(variable) == "table"
						and type(variable.reagent) == "table"
						and variable.reagent.itemID == choice.itemID
					then
						if quantity ~= nil then
							return "recipe-native-quantities-incomplete"
						end
						quantity = variable.quantity
					end
				end
			end
			if not Integer(quantity) or quantity ~= choice.quantity then
				return "recipe-allocation-quantity-mismatch"
			end
			use[choice.itemID] = (use[choice.itemID] or 0) + choice.quantity
		end
	end
	for item, quantity in pairs(use) do
		tick()
		if recipe.use[item] ~= quantity then
			return "recipe-allocation-use-mismatch"
		end
	end
	for item, quantity in pairs(recipe.use) do
		tick()
		if use[item] ~= quantity then
			return "recipe-allocation-use-mismatch"
		end
	end
	local output = observed.schematic.outputItemID
	local quantity = recipe.produce[output]
	if
		not Integer(output)
		or output == 0
		or not Integer(quantity)
		or quantity < observed.schematic.quantityMin
		or quantity > observed.schematic.quantityMax
	then
		return "recipe-output-schema-mismatch"
	end
end

local function Validate(declaration, tick)
	if declaration.version ~= "crafted-adapter-v1" or declaration.universeComplete ~= true then
		return "recipe-complete-universe-required"
	end
	if not Dense(declaration.recipes, tick) or #declaration.recipes == 0 then
		return "recipe-dense-universe-required"
	end
	if declaration.skillGainLaw ~= "whole-successful-count-bounded-by-rank" then
		return "recipe-successful-skill-gain-law-missing"
	end
	local seen = {}
	for _, recipe in ipairs(declaration.recipes) do
		tick()
		if type(recipe) ~= "table" or not Integer(recipe.recipeID) or recipe.recipeID == 0 or seen[recipe.recipeID] then
			return "recipe-distinct-identity-required"
		end
		seen[recipe.recipeID] = true
		local observed, evidence = observations[recipe.recipeID], recipe.evidence
		local allocation = type(declaration.allocations) == "table" and declaration.allocations[recipe.recipeID]
		if
			type(allocation) ~= "table"
			or allocation.complete ~= true
			or type(evidence) ~= "table"
			or allocation.identity ~= evidence.allocation
		then
			return "recipe-allocation-incomplete"
		end
		local bounds = type(declaration.eligibility) == "table" and declaration.eligibility[recipe.recipeID]
		if
			type(bounds) ~= "table"
			or not Integer(bounds.fromSkill)
			or not Integer(bounds.toSkill)
			or bounds.toSkill < bounds.fromSkill
		then
			return "recipe-eligibility-bounds-missing"
		end
		if not observed or #observed.missing > 0 then
			return "recipe-observation-incomplete"
		end
		if
			type(evidence) ~= "table"
			or evidence.revision ~= observed.revision
			or evidence.allocation ~= observed.allocation
			or evidence.clientBuild ~= observed.clientBuild
			or evidence.clientBuild ~= Build()
			or recipe.professionID ~= observed.professionID
		then
			return "recipe-evidence-mismatch"
		end
		if not Dense(observed.requirements, tick) then
			return "recipe-native-requirements-unavailable"
		end
		for _, requirement in ipairs(observed.requirements) do
			tick()
			if type(requirement) ~= "table" or type(requirement.met) ~= "boolean" then
				return "recipe-native-requirements-unavailable"
			end
			if not requirement.met then
				return "recipe-native-prerequisite-unmet"
			end
		end
		for _, name in ipairs({ "use", "produce" }) do
			local map = recipe[name]
			if type(map) ~= "table" then
				return "recipe-production-map-required"
			end
			for item, quantity in pairs(map) do
				tick()
				if not Integer(item) or item == 0 or not Integer(quantity) or quantity == 0 then
					return "recipe-production-map-required"
				end
			end
		end
		if next(recipe.produce) == nil then
			return "recipe-production-map-required"
		end
		local allocationReason = Allocation(recipe, observed, allocation, tick)
		if allocationReason then
			return allocationReason
		end
		local profession = observed.profession
		if
			type(profession) ~= "table"
			or not Integer(profession.skillLevel)
			or not Integer(profession.maxSkillLevel)
			or not Integer(profession.skillModifier)
		then
			return "recipe-native-rank-unavailable"
		end
		if recipe.productionLaw ~= "deterministic-completed-attempt" then
			return "recipe-production-law-missing"
		end
		if type(recipe.available) ~= "boolean" or not Text(recipe.scope) then
			return "recipe-fixed-eligibility-missing"
		end
		if
			(recipe.role == "main" and recipe.skillEffect ~= "route")
			or (recipe.role == "auxiliary" and recipe.skillEffect ~= "neutral")
			or (recipe.role ~= "main" and recipe.role ~= "auxiliary")
		then
			return "recipe-skill-effect-unsupported"
		end
		for _, gate in ipairs(gates) do
			tick()
			if
				type(declaration.prerequisites) ~= "table"
				or type(declaration.prerequisites[recipe.recipeID]) ~= "table"
				or declaration.prerequisites[recipe.recipeID][gate] ~= true
			then
				return "recipe-prerequisite-" .. gate .. "-missing"
			end
		end
	end
end

---@param skillLine integer Plan skill-line identity, separate from the native profession ID.
---@param declaration table
---@param workLimit integer
---@return boolean, string?
function Owner.Declare(skillLine, declaration, workLimit)
	if reading > 0 then
		return false, "recipe-evidence-reader-is-read-only"
	end
	local tick = Budget(workLimit)
	if not tick or not Integer(skillLine) or skillLine == 0 then
		return false, "recipe-declaration-identity-required"
	end
	local ok, frozen = pcall(Copy, declaration, tick)
	local reason
	if ok then
		local valid, missing = pcall(Validate, frozen, tick)
		if valid then
			reason = missing
		else
			reason = tostring(missing)
		end
	else
		reason = tostring(frozen)
	end
	-- A replacement revokes the old law even when the new one is incomplete.
	declarations[skillLine] = not reason and frozen or nil
	failures[skillLine] = reason
	local expectedRevision = revision + 1
	Changed()
	if expectedRevision ~= revision then
		return false, "recipe-declaration-replaced"
	end
	if reason then
		return false, reason
	end
	return true
end

---@return integer
function Owner.Revision()
	return revision
end

---@param captured integer
---@return boolean
function Owner.Current(captured)
	return captured == revision and (observedBuild == nil or observedBuild == Build())
end

---@param skillLine integer
---@return SkillUpRecipeEvidence
function Owner.Inspect(skillLine)
	local declared = declarations[skillLine]
	local missing = {}
	if not declared then
		missing[1] = { code = failures[skillLine] or "recipe-production-law-missing" }
	else
		-- Build is bound per recipe below; no native deterministic law is implied.
		for _, recipe in ipairs(declared.recipes) do
			if recipe.evidence.clientBuild ~= Build() then
				missing[#missing + 1] = { code = "recipe-build-changed", recipeID = recipe.recipeID }
			end
		end
	end
	return {
		status = #missing == 0 and "conditional" or "unsupported",
		scope = "declared-finite-recipes",
		recipeRevision = revision,
		missing = missing,
	}
end

-- Called inside the existing adaptive snapshot coroutine, sharing its budget.
---@param plan SkillUpPlan
---@param token table
---@param tick fun()
---@return SkillUpCraftedRoute?, string?, table?
function Owner.Snapshot(plan, token, tick)
	if type(token) == "table" then
		for key in pairs(token) do
			tick()
			if key ~= "version" and key ~= "revision" and key ~= "skillLine" then
				return nil, "recipe-variant-unsupported"
			end
		end
	end
	if type(token) ~= "table" or token.version ~= "crafted-adapter-v1" or token.revision ~= revision then
		return nil, "recipe-revision-mismatch"
	end
	if type(plan.profession) ~= "table" or token.skillLine ~= plan.profession.skillLine then
		return nil, "recipe-plan-profession-mismatch"
	end
	local declaration = declarations[token.skillLine]
	if not declaration then
		return nil, "recipe-production-law-missing"
	end
	local reason = Validate(declaration, tick)
	if reason then
		return nil, reason
	end
	if
		not Integer(plan.profession.max)
		or not Integer(plan.profession.modifier)
		or not Integer(plan.profession.max + plan.profession.modifier)
	then
		return nil, "recipe-plan-rank-unavailable"
	end
	local frozen = Copy(declaration, tick)
	local evidence = { revision = revision, scope = "declared-finite-recipes", declaration = frozen, observations = {} }
	for _, recipe in ipairs(frozen.recipes) do
		tick()
		evidence.observations[recipe.recipeID] = Copy(observations[recipe.recipeID], tick)
	end
	local route = {
		version = "crafted-deterministic-v1",
		skillCap = plan.profession.max + plan.profession.modifier,
		coverage = "maximum-craft-only-completion",
		prerequisites = "already-satisfied",
		recipes = frozen.recipes,
		legs = {},
		held = {},
		buy = {},
	}
	local recipes = {}
	for _, recipe in ipairs(route.recipes) do
		tick()
		recipes[recipe.recipeID] = recipe
		do
			local bounds = frozen.eligibility[recipe.recipeID]
			local observed = observations[recipe.recipeID].profession
			recipe.eligibility = {
				fromSkill = bounds.fromSkill,
				toSkill = bounds.toSkill,
				fixedSkill = recipe.role == "auxiliary"
						and recipe.professionID ~= plan.profession.professionID
						and observed.skillLevel + observed.skillModifier
					or nil,
			}
		end
		for item in pairs(recipe.use) do
			tick()
			route.held[item] = 0
		end
		for item in pairs(recipe.produce) do
			tick()
			route.held[item] = 0
		end
	end
	if not Dense(plan.crafts, tick) then
		return nil, "recipe-plan-dense-legs-required"
	end
	for _, key in ipairs({ "training", "ranks" }) do
		if not Dense(plan[key], tick) then
			return nil, "recipe-plan-prerequisites-unavailable"
		end
		if #plan[key] > 0 then
			return nil, "recipe-plan-unmet-" .. key
		end
	end
	local previous
	for _, craft in ipairs(plan.crafts) do
		tick()
		local recipe = recipes[craft.recipeID]
		if not recipe or recipe.role ~= "main" or recipe.professionID ~= plan.profession.professionID then
			return nil, "recipe-plan-leg-identity-mismatch"
		end
		if
			not Integer(craft.from)
			or not Integer(craft.to)
			or craft.to <= craft.from
			or (previous and previous ~= craft.from)
			or not Integer(plan.profession.modifier)
		then
			return nil, "recipe-plan-interval-mismatch"
		end
		local bounds = frozen.eligibility[craft.recipeID]
		local observed = observations[craft.recipeID].profession
		if
			craft.from + plan.profession.modifier < bounds.fromSkill
			or craft.to + plan.profession.modifier > bounds.toSkill
			or craft.to > plan.profession.max
			or plan.profession.max ~= observed.maxSkillLevel
			or plan.profession.modifier ~= observed.skillModifier
		then
			return nil, "recipe-plan-eligibility-boundary"
		end
		previous = craft.to
		local thresholds = ns.Model.Get(craft.recipeID)
		route.legs[#route.legs + 1] = {
			recipeID = craft.recipeID,
			fromSkill = craft.from + plan.profession.modifier,
			toSkill = craft.to + plan.profession.modifier,
			thresholds = thresholds and { thresholds[1], thresholds[2], thresholds[3], thresholds[4] },
			skillUps = ns.RecipeSkillUps(craft.recipeID),
		}
	end
	return route, nil, evidence
end

-- Readers return immutable contracts, never perform observation/declaration
-- work outside the shared snapshot budget. Mutations belong to their producer.
---@param read fun(): SkillUpResupplyInput|SkillUpAdaptiveSupplyRequest|nil, string?
---@return boolean, SkillUpResupplyInput|SkillUpAdaptiveSupplyRequest|nil, string?
function Owner.ReadRequest(read)
	reading = reading + 1
	local ok, request, reason = pcall(read)
	reading = reading - 1
	return ok, request, reason
end

local function Revoke()
	if next(observations) or next(declarations) then
		observations, declarations, failures = {}, {}, {}
		observedBuild = nil
		Changed()
	end
end
-- Build identity is a live freshness check, independent of chance revisions.
function Owner.Refresh()
	if not Owner.Current(revision) then
		Revoke()
	end
end
ns.WhenStaleObserver("schematics", Revoke)
ns.WhenEvent("TRADE_SKILL_LIST_UPDATE", Revoke)
ns.WhenEvent("SKILL_LINES_CHANGED", Revoke)
ns.WhenEvent("PLAYER_EQUIPMENT_CHANGED", Revoke)
ns.WhenEvent("TRADE_SKILL_DATA_SOURCE_CHANGED", Revoke)
ns.WhenEvent("ZONE_CHANGED_NEW_AREA", Revoke)
---@cast Owner SkillUpRecipeEvidenceOwner
ns.RecipeEvidence = Owner
