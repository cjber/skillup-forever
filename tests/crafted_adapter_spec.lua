local Client = dofile("tests/client.lua")
local c = Client.load({
	boot = false,
	saved = { routeTargets = { [197] = 2 }, trackedProfessions = { [197] = true } },
	data = {
		Thresholds = { [1] = { 0, 2, 2, 2 }, [4] = { 0, 3, 3, 3 } },
		RecipeData = {
			[1] = {
				skillLine = 197,
				output = { itemID = 11, quantity = 1 },
				reagents = { { itemID = 10, quantity = 1 } },
			},
		},
		TrainerFees = {},
		TrainerRanks = {},
		ItemSellPrices = {},
	},
})
c.professions = { { name = "Tailoring", icon = 1, rank = 1, max = 75, id = 8197 } }
c.known[1], c.spells[1] = true, "Synthetic Cloth"
c.schematics = { [1] = { reagents = { { 10, 1 } }, output = 11 } }
c.bags[10], c.bags[30], c.money = 1, 2, 0
c.Boot()
local ns = c.ns
local plan = {
	profession = { modifier = 0 },
	crafts = { { recipeID = 1, from = 1, to = 2 } },
}
local policy = {
	service = "adaptive-finite",
	journey = "independent-round-trips",
	delivery = "independent-bundle-outcomes",
	objective = "expected-expenditure-plus-terminal-carry-plus-failure-loss",
	route = assert(ns.RouteDemand.Snapshot(plan, {})),
	walletCopper = 0,
	currencies = {},
	stock = { S = 1 },
	sources = {
		{
			offerID = "inaccessible-other-product",
			itemID = 30,
			bundleUnits = 1,
			moneyCopper = 0,
			costs = {},
			maxBundles = 1,
			stockKey = "S",
			stockPerBundle = 1,
			vendor = "V",
			access = false,
			priceLaw = "fixed",
			futureDelivery = { chance = 1, payOnFailure = true },
		},
	},
	initialOrders = {},
	tokenValues = {},
	terminalCarry = { ["item:10"] = 0, ["item:30"] = 3 },
	failureLoss = 100,
	initialVisitMoney = { V = 0 },
	refillVisitMoney = { V = 0 },
	initialVisitValue = { V = 0 },
	refillVisitValue = { V = 0 },
	sourceRevision = 1,
	assumptions = {},
	options = { workLimit = 1000000, stateLimit = 1000, coordinateLimit = 32, limbLimit = 256 },
}
local checks = 0
local function Check(value, why)
	checks = checks + 1
	assert(value, why)
end
local function Copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for k, v in pairs(value) do
		result[k] = Copy(v)
	end
	return result
end
local owner = ns.RecipeEvidence
local schemaAPI = c.G.C_TradeSkillUI.GetRecipeSchematic
local schemas = {
	[1] = {
		recipeID = 1,
		isRecraft = false,
		quantityMin = 1,
		quantityMax = 1,
		outputItemID = 11,
		reagentSlotSchematics = {
			{
				reagentType = 0,
				quantityRequired = 1,
				reagents = { { itemID = 20 } },
				slotIndex = 1,
				dataSlotIndex = 1,
				required = true,
				variableQuantities = { { reagent = { itemID = 20 }, quantity = 1 } },
				slotInfo = { mcrSlotID = 9, requiredSkillRank = 0 },
			},
		},
	},
	[2] = {
		recipeID = 2,
		isRecraft = false,
		quantityMin = 2,
		quantityMax = 2,
		outputItemID = 20,
		reagentSlotSchematics = {
			{
				reagentType = 0,
				quantityRequired = 1,
				reagents = { { itemID = 10 } },
				slotIndex = 1,
				dataSlotIndex = 1,
				required = true,
				slotInfo = { mcrSlotID = 9, requiredSkillRank = 0 },
			},
		},
	},
	[3] = {
		recipeID = 3,
		isRecraft = false,
		quantityMin = 3,
		quantityMax = 3,
		outputItemID = 20,
		reagentSlotSchematics = {
			{
				reagentType = 0,
				quantityRequired = 2,
				reagents = { { itemID = 10 } },
				slotIndex = 1,
				dataSlotIndex = 1,
				required = true,
				slotInfo = { mcrSlotID = 9, requiredSkillRank = 0 },
			},
		},
	},
}
c.G.C_TradeSkillUI.GetRecipeSchematic = function(id)
	return schemas[id]
end
c.G.C_TradeSkillUI.GetProfessionInfoByRecipeID = function()
	return { professionID = 197, skillLevel = 1, skillModifier = 0, maxSkillLevel = 75 }
end
plan.profession = { skillLine = 197, professionID = 197, modifier = 0, max = 75 }
plan.training, plan.ranks = {}, {}
plan.crafts[1].subcrafts = { { recipeID = 2 } }
policy.route = { held = { [10] = 999, [20] = 999, [11] = 999 }, legs = {} }
policy.terminalCarry = { ["item:10"] = 0, ["item:20"] = 0, ["item:11"] = 1, ["item:30"] = 0 }
c.bags[10], c.bags[20], c.bags[11] = 1, 0, 2
local declaration
local function Declare()
	declaration = {
		version = "crafted-adapter-v1",
		skillGainLaw = "whole-successful-count-bounded-by-rank",
		universeComplete = true,
		recipes = {},
		prerequisites = {},
		allocations = {},
		eligibility = {},
	}
	for id = 1, 3 do
		local observed = assert(owner.Observe(id, "allocation-" .. id, 10000))
		local recipe = {
			recipeID = id,
			professionID = observed.professionID,
			role = id == 1 and "main" or "auxiliary",
			available = true,
			scope = "synthetic completed attempt law",
			skillEffect = id == 1 and "route" or "neutral",
			productionLaw = "deterministic-completed-attempt",
			use = id == 1 and { [20] = 1 } or { [10] = id == 2 and 1 or 2 },
			produce = id == 1 and { [11] = 1 } or { [20] = id == 2 and 2 or 3 },
			evidence = {
				revision = observed.revision,
				allocation = observed.allocation,
				clientBuild = observed.clientBuild,
			},
		}
		declaration.recipes[#declaration.recipes + 1] = recipe
		declaration.prerequisites[id] = { rank = true, training = true, tools = true, station = true, access = true }
		declaration.allocations[id] = {
			identity = observed.allocation,
			complete = true,
			slots = {
				{ slotIndex = 1, dataSlotIndex = 1, itemID = id == 1 and 20 or 10, quantity = id == 3 and 2 or 1 },
			},
		}
		declaration.eligibility[id] = { fromSkill = 0, toSkill = 75 }
	end
	return owner.Declare(197, declaration, 10000)
end
local function Request()
	return {
		inventoryScope = "bags-only",
		policy = policy,
		crafted = { version = "crafted-adapter-v1", revision = owner.Revision(), skillLine = 197 },
	}
end
local function Finish(request, alpha)
	local job = ns.RouteDemand.StartAdaptive(plan, request or Request(), alpha == nil and 1 or alpha)
	for _ = 1, 100000 do
		if job.result.status ~= "calculating" then
			return job.result, job
		end
		job:Advance(64)
	end
	error("fixture work exhausted")
end
Check(owner.Inspect(197).status == "unsupported", "alpha-free inspection has no default law")
local obs = assert(owner.Observe(1, "allocation-1", 10000))
Check(
	obs.schematic.quantityMin == obs.schematic.quantityMax and owner.Inspect(197).status == "unsupported",
	"equal bounds never establish production"
)
schemas[1].reagentSlotSchematics[1].slotInfo.mcrSlotID = 88
Check(obs.schematic.reagentSlotSchematics[1].slotInfo.mcrSlotID == 9, "observation owns nested slot metadata")
obs.schematic.reagentSlotSchematics[1].slotInfo.mcrSlotID = 99
Check(Finish().status == "unknown", "absent law rejects crafted selection")
assert(Declare())
local reads = {}
local nativeCount = c.G.C_Item.GetItemCount
c.G.C_Item.GetItemCount = function(id, bank, uses, reagentBank, accountBank)
	Check(bank == false and uses == false and reagentBank == false and accountBank == false, "bags-only flags")
	reads[id] = (reads[id] or 0) + 1
	return c.bags[id] or 0
end
local result, job = Finish()
Check(result.status == "complete", result.reasons[1] or "crafted adapter complete")
Check(
	result.have[10] == 1 and result.have[20] == 0 and result.have[11] == 2,
	"native pooled and output-only holdings replace caller"
)
for _, id in ipairs({ 10, 11, 20, 30 }) do
	Check(reads[id] == 1, "each coordinate read once")
end
Check(result.certificate.recipes[2] and result.certificate.recipes[3], "both declared alternatives retained")
Check(result.certificate.stages[1].recipeID == 1, "exact final Plan leg identity")
Check(
	result.recipeRevision == owner.Revision() and result.recipeScope == "declared-finite-recipes",
	"conditional revision scope published"
)
-- Independent tiny integer oracle: enumerate both makers and the one main
-- attempt directly. Unit-cheapest maker 2 leaves a worse economic remainder.
c.bags[10] = 2
policy.terminalCarry["item:10"], policy.terminalCarry["item:20"] = 10, 1
local best = math.huge
for a = 0, 2 do
	for b = 0, 1 do
		local spent, made = a + 2 * b, 2 * a + 3 * b
		if spent <= 2 and made >= 1 then
			best = math.min(best, (2 - spent) * 10 + made - 1 + 3)
		end
	end
end
result = Finish()
Check(
	result.status == "complete" and result.objectiveLower <= best and result.objectiveUpper >= best,
	"tiny independent alternative oracle: "
		.. tostring(result.objectiveLower)
		.. ","
		.. tostring(result.objectiveUpper)
		.. " expected "
		.. best
)
local initial
for _, action in ipairs(result.certificate.policy) do
	if action.state == result.certificate.initialState then
		initial = action
	end
end
Check(initial and initial.recipeID == 3, "economic policy retains and chooses worse unit-price maker")
Check(result.certificate.recipes[2] and result.certificate.recipes[3], "both alternatives reach selected certificate")
c.bags[10] = 1
policy.terminalCarry["item:10"], policy.terminalCarry["item:20"] = 0, 0
local certificate = result.certificate
-- Mutating caller declarations cannot change either owned law or completed result.
declaration.recipes[2].produce[20] = 999
Check(certificate.recipes[2].produce[20] == 2, "certificate owns declarations")
Check(Finish().status == "complete", "owner declaration remains independent")
-- Item 20 is both crafted intermediate and source payment, one inventory pool.
policy.sources[1].costs = { ["item:20"] = 1 }
policy.tokenValues = { ["item:20"] = 0 }
reads = {}
result = Finish()
Check(result.status == "complete" and reads[20] == 1, "item-token and intermediate share one native read")
policy.sources[1].costs = {}
policy.tokenValues = {}
-- Interval and identity validation happens before any live balance read.
plan.crafts[1].to = 76
Check(Finish().reasons[1] == "recipe-plan-eligibility-boundary", "rank crossing unsupported")
plan.crafts[1].to = 2
plan.training = { { recipeID = 1 } }
Check(Finish().reasons[1] == "recipe-plan-unmet-training", "unmet training cannot inherit all-true declaration")
plan.training = {}
plan.profession.professionID = 999
Check(Finish().reasons[1] == "recipe-plan-leg-identity-mismatch", "exact main profession required")
plan.profession.professionID = 197
local partial = ns.RouteDemand.StartAdaptive(plan, Request(), 1)
partial:Advance(5)
assert(owner.Observe(2, "changed-allocation", 10000))
Check(
	partial.result.status == "cancelled" and job.result.status == "cancelled",
	"allocation revision revokes partial and complete jobs"
)
Check(owner.Inspect(197).status == "unsupported", "allocation revision revokes law")
assert(Declare())
local bad = Copy(declaration)
bad.recipes[1].productionLaw = nil
local valid, why = owner.Declare(197, bad, 10000)
Check(not valid and why == "recipe-production-law-missing", "equal bounds cannot replace missing declaration")
assert(Declare())
bad = Copy(declaration)
bad.allocations[1].complete = false
valid, why = owner.Declare(197, bad, 10000)
Check(not valid and why == "recipe-allocation-incomplete", "incomplete allocation explicit")
assert(Declare())
bad = Copy(declaration)
bad.prerequisites[1].tools = false
valid, why = owner.Declare(197, bad, 10000)
Check(not valid and why == "recipe-prerequisite-tools-missing", "missing prerequisite code stable")
assert(Declare())
bad = Copy(declaration)
bad.recipes[2].skillEffect = "route"
valid, why = owner.Declare(197, bad, 10000)
Check(not valid and why == "recipe-skill-effect-unsupported", "non-neutral auxiliary rejected")
assert(Declare())
bad = Copy(declaration)
bad.universeComplete = false
valid, why = owner.Declare(197, bad, 10000)
Check(not valid and why == "recipe-complete-universe-required", "known incomplete universe rejected")
assert(Declare())
local stale = Request()
assert(owner.Observe(1, "new", 10000))
Check(Finish(stale).reasons[1] == "recipe-revision-mismatch", "stale revision token rejected")
assert(Declare())
local _, builtJob = Finish()
c.build = "changed"
Check(builtJob:Advance(1).status == "cancelled", "build change revokes completed job on freshness check")
Check(owner.Inspect(197).status == "unsupported" and Finish().status == "cancelled", "build change cannot retain law")
c.build = "70938"
assert(Declare())
local reentrant = c.G.C_Item.GetItemCount
c.G.C_Item.GetItemCount = function(id, ...)
	owner.Observe(1, "reentrant", 10000)
	return reentrant(id, ...)
end
Check(Finish().status == "cancelled", "revision during native read cannot publish")
c.G.C_Item.GetItemCount = nativeCount
-- Publication uses the existing frame and its single owned supply record.
assert(Declare())
local published = ns.RouteDemand.SelectAdaptiveSupply(plan, Request(), 1)
local before = published.result
for _ = 1, 10 do
	ns.RouteDemand.Supply(plan)
end
Check(
	published.result == before and published.result.status == "calculating",
	"getters never advance crafted publication"
)
for _ = 1, 10000 do
	for _, frame in ipairs(c.frames) do
		local callback = frame.scripts.OnUpdate
		if callback and debug.getinfo(callback, "S").source:find("Core/RouteDemand.lua", 1, true) then
			callback(frame, 0)
		end
	end
	if published.result.status ~= "calculating" then
		break
	end
end
local supply = ns.RouteDemand.Supply(plan)
Check(
	supply and supply.job == published and supply.result.recipeEvidence,
	"shared publisher retains crafted evidence: "
		.. published.result.status
		.. " "
		.. tostring(published.result.reasons[1])
)
Check(
	supply.result.recipeEvidence.observations[1].schematic.reagentSlotSchematics[1].slotInfo.mcrSlotID == 88,
	"published snapshot owns nested native slots"
)
ns.Changed("bags")
Check(published.result.status == "cancelled" and plan.supply == nil, "resource revision removes complete publication")
assert(Declare())
local moneyAPI = c.G.GetMoney
local walletRead = false
c.G.GetMoney = function()
	walletRead = true
	return moneyAPI()
end
local solving = ns.RouteDemand.StartAdaptive(plan, Request(), 1)
for _ = 1, 10000 do
	solving:Advance(1)
	if walletRead then
		break
	end
end
Check(walletRead and solving.result.status == "calculating", "fixture reaches selector after native snapshot")
assert(Declare())
Check(solving.result.status == "cancelled", "declaration revision revokes solve after copying")
c.G.GetMoney = moneyAPI
assert(Declare())
local _, eligible = Finish()
local replacement = Copy(declaration)
replacement.recipes[2].available = false
assert(owner.Declare(197, replacement, 10000))
Check(eligible.result.status == "cancelled", "eligibility replacement revokes complete certificate")
assert(Declare())
replacement = Copy(declaration)
replacement.eligibility[1] = nil
local bounded, missing = owner.Declare(197, replacement, 10000)
Check(not bounded and missing == "recipe-eligibility-bounds-missing", "unknown interval bound unsupported")
assert(Declare())
replacement = Copy(declaration)
replacement.allocations[1].slots[1].quantity = 2
bounded, missing = owner.Declare(197, replacement, 10000)
Check(not bounded and missing == "recipe-allocation-quantity-mismatch", "slot allocation must match observed quantity")
-- A native unmet prerequisite cannot be overridden by caller true flags.
c.live[1] = { requirements = { { name = "synthetic station", met = false } } }
local declared, requirementReason = Declare()
Check(
	not declared and requirementReason == "recipe-native-prerequisite-unmet",
	"known unmet native gate rejects declaration"
)
c.live[1] = nil
-- Two final legs pool the same intermediate, including held intermediates.
assert(Declare())
schemas[4] = Copy(schemas[1])
schemas[4].recipeID = 4
schemas[4].outputItemID = 21
local fourth = assert(owner.Observe(4, "allocation-4", 10000))
local pooled = Copy(declaration)
local main = Copy(pooled.recipes[1])
main.recipeID = 4
main.produce = { [21] = 1 }
main.evidence = { revision = fourth.revision, allocation = fourth.allocation, clientBuild = fourth.clientBuild }
pooled.recipes[4] = main
pooled.prerequisites[4] = Copy(pooled.prerequisites[1])
pooled.allocations[4] = { identity = fourth.allocation, complete = true, slots = Copy(pooled.allocations[1].slots) }
pooled.eligibility[4] = Copy(pooled.eligibility[1])
assert(owner.Declare(197, pooled, 10000))
plan.crafts[2] = { recipeID = 4, from = 2, to = 3, subcrafts = {} }
policy.terminalCarry["item:21"] = 0
c.bags[10], c.bags[20], c.bags[21] = 1, 0, 4
local shared = Finish()
Check(
	shared.status == "complete" and shared.coverageLower <= 1 and shared.coverageUpper >= 1,
	"one auxiliary supplies both final legs"
)
Check(
	#shared.certificate.stages == 2 and shared.certificate.stages[2].recipeID == 4,
	"ordered main identities retained"
)
c.bags[10], c.bags[20] = 0, 2
shared = Finish()
Check(shared.status == "complete" and shared.have[21] == 4, "native held intermediate and output-only item retained")
-- A source cannot fund its own payment with delivered products.
c.bags[20] = 0
policy.sources[1].itemID, policy.sources[1].access = 20, true
policy.sources[1].costs = { ["item:20"] = 1 }
policy.tokenValues = { ["item:20"] = 0 }
Check(Finish().status == "infeasible", "source output cannot finance its own atomic payment")
policy.sources[1].itemID, policy.sources[1].access = 30, false
policy.sources[1].costs = {}
policy.tokenValues = {}
local itemAPI = c.G.C_Item.GetItemCount
c.G.C_Item.GetItemCount = function(id, ...)
	if id == 21 then
		return nil
	end
	return itemAPI(id, ...)
end
Check(Finish().status == "unknown", "missing output-only holding never inherits caller placeholder")
c.G.C_Item.GetItemCount = itemAPI
plan.crafts[2] = nil
local unchanged = owner.Revision()
local observed, variantReason = owner.Observe(1, "recraft", 10000, { isRecraft = true })
Check(
	not observed and variantReason == "recipe-variant-unsupported" and owner.Revision() == unchanged,
	"recraft variant explicitly unsupported"
)
local readerOK, readerValue = owner.ReadRequest(function()
	local value, reason = owner.Observe(1, "reader", 10000)
	Check(
		not value and reason == "recipe-evidence-reader-is-read-only",
		"configured reader cannot run observation outside shared budget"
	)
	return Request()
end)
Check(readerOK and readerValue and owner.Revision() == unchanged, "read-only reader does not mutate revision")
-- The public getter exposes unsupported evidence without alpha and does not
-- advance a configured job. Build freshness is also checked before API copies.
c.G.C_TradeSkillUI.GetProfessionInfoByRecipeID = function()
	return { professionID = 8197, skillLevel = 1, skillModifier = 0, maxSkillLevel = 75 }
end
c.auction[10], c.auction[20] = 3, 3
c.items[11] = { sell = 0 }
c.bags[10], c.bags[20] = 1, 0
ns.Changed("prices")
assert(Declare())
plan = ns.PlanRoute(assert(ns.RouteProfessions()[197]))
Check(#plan.crafts == 1, "public fixture has final native plan")
local api = c.G.SkillUpForever.API
local publicJob = ns.RouteDemand.SelectAdaptiveSupply(plan, Request(), 1)
for _ = 1, 10 do
	api.Professions()
end
Check(publicJob.result.status == "calculating", "API reads do not advance crafted job")
for _ = 1, 10000 do
	for _, frame in ipairs(c.frames) do
		local callback = frame.scripts.OnUpdate
		if callback and debug.getinfo(callback, "S").source:find("Core/RouteDemand.lua", 1, true) then
			callback(frame, 0)
		end
	end
	if publicJob.result.status ~= "calculating" then
		break
	end
end
local public = api.Professions()[1]
Check(public.supply and public.supply.recipeScope == "declared-finite-recipes", "API publishes same crafted result")
public.supply.recipeEvidence.observations[1].schematic.reagentSlotSchematics[1].slotInfo.mcrSlotID = 12345
Check(
	api.Professions()[1].supply.recipeEvidence.observations[1].schematic.reagentSlotSchematics[1].slotInfo.mcrSlotID
		== 88,
	"API recursively owns native slot snapshot"
)
c.build = "changed-after-publication"
public = api.Professions()[1]
Check(
	public.supply == nil and public.recipeEvidence.status == "unsupported",
	"API build check rejects stale certificate without progressing job"
)
Check(publicJob.result.status == "complete", "getter rejects freshness without solver progress")
c.build = "70938"
plan.crafts[1].subcrafts = { { recipeID = 2 } }
-- Existing raw adapter stays consumption-only and fixed APIs remain intact.
c.G.C_TradeSkillUI.GetRecipeSchematic = schemaAPI
local raw, reason = ns.RouteDemand.Snapshot(plan, {})
Check(raw == nil and reason == "subcraft requires an inventory transition", "raw contract preserved")
print("crafted adapter: " .. checks .. " checks passed")
