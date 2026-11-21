local Client = dofile("tests/client.lua")
local probe = arg and arg[1] == "--probe"

local function Fixture()
	local c = Client.load({ boot = false })
	c.maps[0] = { mapID = 10, name = "Vendor zone" }
	local sellers, vendor, stock = {}, {}, {}
	for itemID, vendors in pairs(c.ns.LimitedStock) do
		vendor[itemID] = c.ns.VendorPrices[itemID] or 10
		stock[itemID] = {}
		for npcID, limit in pairs(vendors) do
			stock[itemID][npcID] = limit
			local seller = sellers[npcID]
			if not seller then
				seller = { name = "Vendor " .. npcID, side = "A", map = 10, x = 0.5, y = 0.5, items = {} }
				sellers[npcID] = seller
			end
			seller.items[itemID] = true
		end
	end
	c.G.SkillUpForeverDB = {
		sellers = sellers,
		vendor = vendor,
		stock = stock,
		routeTargets = { [165] = 300, [164] = 300, [202] = 300, [197] = 300 },
	}
	for recipeID, recipe in pairs(c.ns.RecipeData) do
		c.known[recipeID] = true
		for _, reagent in ipairs(recipe.reagents) do
			c.auction[reagent.itemID] = 1000 + reagent.itemID % 1000
		end
	end
	c.Boot()
	return c
end

local c = Fixture()
local ns = c.ns
local shares = ns.StockShares
local calls = 0
local joins = 0
if not probe then
	-- Price memo keys account for most of these joins during a plan. Count all joins in the stub client
	-- so the test can catch rebuilding a key for every batch count without hooking a private function.
	c.G.table = setmetatable({
		concat = function(...)
			joins = joins + 1
			return table.concat(...)
		end,
	}, { __index = table })
end
-- Expand asks for shares once for each recipe or subcraft it prices.
if shares then
	ns.StockShares = function(...)
		calls = calls + 1
		return shares(...)
	end
end

local cases = { [165] = "Leatherworking", [164] = "Blacksmithing", [202] = "Engineering", [197] = "Tailoring" }
for _, id in ipairs({ 165, 164, 202, 197 }) do
	if id == 165 or probe then
		c.professions = { { name = cases[id], id = id, rank = 1, max = 300 } }
		ns.Changed("recipes")
		calls = 0
		local start = os.clock()
		local plan = ns.PlanRoute(assert(ns.PlayerProfessions()[id]))
		if probe then
			print(
				string.format(
					"%s %.1f ms %d stock expansions, reached %d",
					cases[id],
					(os.clock() - start) * 1000,
					calls,
					plan.reached
				)
			)
			print(string.format("route cost %.17g", plan.cost))
			for _, craft in ipairs(plan.crafts) do
				print(craft.recipeID, craft.from, craft.to, craft.crafts, craft.materialCost)
			end
		else
			for itemID, vendors in pairs(ns.LimitedStock) do
				local npc = assert(ns.NearestVendor(itemID, true), "no nearest vendor for item " .. itemID)
				Client.equal(ns.IsLimitedStock(itemID, npc), assert(vendors[npc]), "nearest vendor has bundled stock")
			end
			-- Recorded with main's uncached pricing. The early steps buy from limited vendors.
			local steps = {}
			for _, craft in ipairs(plan.crafts) do
				steps[#steps + 1] =
					table.concat({ craft.recipeID, craft.from, craft.to, craft.crafts, craft.materialCost or "?" }, ":")
			end
			Client.equal(
				table.concat(steps, ","),
				"2165:1:2:1:50,10507:2:3:1:2344,19048:3:4:1:7013,19093:4:300:296:?",
				"Leatherworking keeps the uncached route and each step's material cost"
			)
			Client.equal(plan.cost, -872754, "Leatherworking keeps the uncached total cost")
			-- Quote reuse alone still made 2,860 calls, including candidates that could never win.
			assert(calls <= 400, "expected at most 400 stock expansions, got " .. calls)
			assert(joins <= 22000, "expected at most 22000 table joins, got " .. joins)
			print(string.format("limited_stock_speed_spec: ok (%d stock expansions, %d table joins)", calls, joins))
		end
	end
end
