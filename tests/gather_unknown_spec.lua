local Client = dofile("tests/client.lua")
local equal = Client.equal
local c = Client.load({
	boot = false,
	auctionator = false,
	saved = { valueGathered = true, routeTargets = { [165] = 51 }, trackedProfessions = { [165] = true } },
	data = {
		Thresholds = { [11] = { 1, 60, 70, 80 } },
		RecipeData = { [11] = { skillLine = 165, reagents = { { itemID = 1101, quantity = 1 } } } },
		TrainerFees = {},
		TrainerRanks = {},
		RankBooks = {},
		ItemSellPrices = {},
		GatheredBy = { [1101] = 393 },
		LootedFrom = {},
		VendorPrices = {},
		ProfessionTrainers = {},
		ScrollDrops = {},
		WorldDrops = {},
	},
})
c.professions = {
	{ name = "Leatherworking", rank = 50, max = 75, id = 8165 },
	{ name = "Skinning", rank = 50, max = 75, id = 8393 },
}
c.spells[11], c.known[11] = "Cured Leather", true
c.Boot()
c.ns.SetCollectMode("gather")
c.Fire("PLAYER_ENTERING_WORLD")
c.Fire("VARIABLES_LOADED")
c.Advance(0)
local ns = c.ns
local function Check(known)
	local price = ns.Price(1101)
	equal(price.source, "gather", "gathering remains the source")
	equal(not not price.unknown, not known, "missing sale value stays unknown")
	local plan = ns.PlanRoute(ns.RouteProfessions()[165])
	equal(#plan.crafts, 1, "gatherable unpriced reagent stays on the route")
	equal(ns.StepCost(11, 1), known and 25 or nil, "route cost is unknown until priced")
	equal(ns.RouteFollowable(plan), true, "gathering can supply the committed route")
	local list = c.G.SkillUpForever.API.ShoppingList(165)[1]
	equal(#list.items, 1, "API keeps the reagent")
	equal(list.items[1].source, "gather", "API keeps gather bucket")
	equal(list.items[1].price, known and 25 or nil, "API never calls unknown free")
	equal(list.unpriced, known and 0 or 1, "API counts unknown prices")
	local buckets = ns.Model.BucketNeeded({ [1101] = 1 }, ns.PriceSource)
	equal(#buckets.gather, 1, "model buckets retain gather-source unknown")
	ns.OpenShoppingList(165)
	local texts = {}
	local function Walk(frame)
		if not frame:IsShown() then
			return
		end
		if frame.text then
			texts[#texts + 1] = frame.text
		end
		for _, child in ipairs({ frame:GetChildren() }) do
			Walk(child)
		end
	end
	Walk(c.G.SkillUpForeverShoppingList)
	equal(
		table.concat(texts, "\n"):find("price unknown", 1, true) ~= nil,
		not known,
		"shopping window marks unknown and recovers"
	)
	equal(
		ns.ShoppingText():find("price unknown", 1, true) ~= nil,
		not known,
		"shopping copy marks unknown and recovers"
	)
end
Check(false)
c.items[1101] = { name = "Light Leather", sell = 25 }
c.Fire("GET_ITEM_INFO_RECEIVED", 1101, true)
c.Advance(0.5)
Check(true)
Client.report("gather unknown")
