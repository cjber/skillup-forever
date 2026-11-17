local Client = dofile("tests/client.lua")
local equal = Client.equal

local gathered =
	Client.load({ data = { VendorPrices = {}, GatheredBy = {}, LootedFrom = { [1] = true }, RecipeData = {} } })
gathered.ns.SetCollectMode("gather")
gathered.auction[1] = 100
gathered.ns.Changed("prices")
equal(gathered.ns.db.valueGathered, true, "new installs value gathered materials")
equal(gathered.ns.Price(1).copper, 95, "gathered cost includes the forgone sale after the cut")
local free = Client.load({
	data = { VendorPrices = {}, GatheredBy = {}, LootedFrom = { [1] = true }, RecipeData = {} },
	saved = { valueGathered = false, gatheredValueSeen = true },
})
free.ns.SetCollectMode("gather")
free.auction[1] = 100
free.ns.Changed("prices")
equal(free.ns.Price(1).copper, 0, "a saved false remains free")
equal(
	free.ns.PriceSourceText(free.ns.Price(1)),
	"you loot it from creatures, would sell for 95c",
	"free material names its forgone sale"
)
local unknown = Client.load({
	data = { VendorPrices = {}, ItemSellPrices = {}, GatheredBy = {}, LootedFrom = { [1] = true }, RecipeData = {} },
})
unknown.ns.SetCollectMode("gather")
equal(unknown.ns.Price(1).unknown, true, "an unknown opportunity value never becomes a free material")
Client.report("gathered_value_spec")
