local Client = dofile("tests/client.lua")
local C, R, ALT, M, X, Y, Z = 185, 10001, 10002, 10003, 10004, 10005, 10006
local function recipe(item, output, n)
	return {
		skillLine = C,
		reagents = { { itemID = item, quantity = 1 } },
		output = output and { itemID = output, quantity = n } or nil,
	}
end
local function setup(data, target)
	local c = Client.load({ saved = { routeTargets = { [C] = target } }, data = data })
	c.professions = { { name = "Cooking", id = C, rank = 1, max = 75 } }
	c.player.faction = "Alliance"
	c.items[X], c.items[Y], c.items[Z] = { name = "X", sell = 0 }, { name = "Y", sell = 0 }, { name = "Z", sell = 0 }
	c.maps[0] = { mapID = 10, name = "A zone" }
	c.maps[1] = { mapID = 11, name = "B zone" }
	c.ns.SetCollectMode("auction")
	return c, c.ns
end
local function merchant(c, npc, item, price, stock)
	c.npc = { id = npc, name = "Vendor " .. npc }
	c.merchant = { { itemID = item, price = price, stackCount = 1, numAvailable = stock } }
	c.Fire("MERCHANT_SHOW")
	c.Advance(0)
end
local function plan(c)
	return c.ns.PlanRoute(c.ns.PlayerProfessions()[C])
end

do
	local c, ns = setup({
		Thresholds = { [R] = { 1, 20, 40, 60 }, [ALT] = { 1, 20, 40, 60 } },
		RecipeData = { [R] = recipe(X), [ALT] = recipe(Z), [M] = recipe(Y, X, 2) },
		VendorPrices = { [Y] = 30, [Z] = 20 },
		ItemSellPrices = {},
	}, 11)
	c.known[R], c.known[ALT], c.known[M] = true, true, true
	c.items[X].sell = 0
	local p = plan(c)
	Client.equal(p.crafts[1].recipeID, R, "unlimited maker ranks at cost per output")
	Client.equal(p.crafts[1].subcrafts[1].crafts, 5, "ten outputs take five batches")
	Client.equal(ns.PlanMoney(p).buy, 150, "the cheaper route costs 150 copper")
end

do
	local c, ns = setup({
		Thresholds = { [R] = { 1, 20, 40, 60 } },
		RecipeData = { [R] = recipe(X) },
		LootedFrom = { [X] = { 1 } },
		LimitedStock = {},
		ItemSellPrices = {},
	}, 9)
	c.known[R] = true
	c.auction[X] = 105
	merchant(c, 5001, X, 5, 4)
	local p = plan(c)
	Client.equal(p.cost, 440, "with empty bags four units cost the auction price")
	c.bags[X] = 4
	c.Fire("BAG_UPDATE_DELAYED")
	c.Advance(0)
	p = plan(c)
	Client.equal(p.cost, 40, "retained route includes held opportunity cost")
	Client.equal(ns.StepCost(R, 8, p.crafts[1]), p.cost, "step and route agree")
	Client.equal(ns.PlanMoney(p).buy, 20, "only four vendor units are purchased")
end

do
	local parent = recipe(X)
	parent.reagents[1].quantity = 2
	local c, ns = setup({
		Thresholds = { [R] = { 1, 20, 40, 60 } },
		RecipeData = { [R] = parent, [M] = recipe(Y, X, 1) },
		LootedFrom = { [Y] = { 1 } },
		LimitedStock = {},
		ItemSellPrices = {},
	}, 2)
	c.known[R], c.known[M] = true, true
	c.auction[X], c.auction[Y] = 50, 100
	merchant(c, 5001, Y, 5, 1)
	local p = plan(c)
	Client.equal(ns.PlanMoney(p).buy, 55, "make one intermediate and buy the other")
	Client.equal(p.crafts[1].subcrafts[1].crafts, 1, "the maker uses a single batch")
end

do
	local parent = recipe(X)
	parent.reagents[2] = { itemID = Z, quantity = 1 }
	local c, ns = setup({
		Thresholds = { [R] = { 1, 20, 40, 60 } },
		RecipeData = { [R] = parent, [M] = recipe(Y, X, 1), [M + 1] = recipe(Y, Z, 1) },
		LootedFrom = { [Y] = { 1 } },
		LimitedStock = {},
		ItemSellPrices = {},
	}, 2)
	c.known[R], c.known[M], c.known[M + 1] = true, true, true
	c.auction[Y] = 100
	merchant(c, 5001, Y, 5, 1)
	Client.equal(ns.CraftCost(R), 105, "sibling makers share one cheap unit")
	Client.equal(ns.PlanMoney(plan(c)).buy, 105, "the recipe preview agrees with the route")

	local lines = {}
	c.G.GameTooltip = {
		SetOwner = function() end,
		SetPoint = function() end,
		Show = function() end,
		AddDoubleLine = function(_, left, right)
			lines[left] = right
		end,
	}
	c.G.ProfessionsFrame = {}
	c.G.Professions = {
		GetHighestLearnedRecipe = function() end,
		GetProfessionInfo = function() end,
	}
	ns.ShowRecipeTooltip(ns, {}, { recipeInfo = { recipeID = R, name = "Parent", learned = true } })
	Client.equal(lines.X and lines.X:match("^%d+c"), "5c", "the first tooltip line uses the cheap unit")
	Client.equal(lines.Z and lines.Z:match("^%d+c"), "100c", "the second tooltip line uses overflow")
	Client.equal(lines.Reagents, "105c", "the tooltip total matches the lines")
end

do
	local c, ns = setup({
		Thresholds = { [R] = { 1, 20, 40, 60 } },
		RecipeData = { [R] = recipe(X) },
		LootedFrom = { [X] = { 1 } },
		LimitedStock = {},
		ItemSellPrices = {},
	}, 9)
	c.known[R] = true
	c.auction[X] = 20
	merchant(c, 5001, X, 5, 4)
	c.player.instance = 1
	merchant(c, 5002, X, 9, -1)
	c.player.instance = 0
	c.Fire("ZONE_CHANGED_NEW_AREA")
	c.Advance(0)
	local p = plan(c)
	Client.equal(ns.PlanMoney(p).buy, 56, "the unlimited seller beats auction overflow")
	local costs = {}
	for _, step in ipairs(c.G.SkillUpForever.API.Professions()[1].steps) do
		if step.kind == "buy" then
			Client.equal(step.count, 4, "each seller supplies four units")
			costs[#costs + 1] = step.cost
		end
	end
	Client.equal(#costs, 2, "public steps preserve both vendors")
	table.sort(costs)
	Client.equal(costs[1], 20, "limited seller costs 20 copper")
	Client.equal(costs[2], 36, "unlimited seller costs 36 copper")
	ns.SetTracked(C, true)
	local shopping = ns.ShoppingList(C)[1]
	Client.equal(#shopping.items, 2, "shopping keeps both vendor quotes separate")
	Client.equal(shopping.total, 56, "shopping uses both vendor quotes")
end

print("stock_pricing_spec: ranked, split and refreshed stock-aware costs: ok")
