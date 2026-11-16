-- Run from the repository root: luajit tests/first_visit_prices_spec.lua
local Client = dofile("tests/client.lua")
local equal = Client.equal

local c = Client.load({
	data = {
		VendorPrices = { [60] = 25, [61] = 40, [62] = 30 },
		LootedFrom = { [60] = true, [64] = true },
		GatheredBy = { [62] = 356 },
		RecipeData = {
			[100] = {
				skillLine = 164,
				reagents = { { itemID = 60, quantity = 2 } },
				output = { itemID = 63, quantity = 1 },
			},
			[101] = { skillLine = 164, reagents = { { itemID = 63, quantity = 1 } } },
			[102] = { skillLine = 164, reagents = { { itemID = 64, quantity = 3 } } },
			[103] = {
				skillLine = 164,
				reagents = { { itemID = 64, quantity = 1 } },
				output = { itemID = 65, quantity = 1 },
			},
			[104] = {
				skillLine = 164,
				reagents = { { itemID = 65, quantity = 1 } },
				output = { itemID = 66, quantity = 1 },
			},
			[105] = {
				skillLine = 164,
				reagents = { { itemID = 66, quantity = 1 } },
				output = { itemID = 67, quantity = 1 },
			},
		},
	},
	tsm = {},
})
local ns = c.ns
ns.SetCollectMode("auction")
ns.db.craftValue = "none"

equal(ns.Price(60).unknown, true, "a vendor fallback for loot has no auction observation yet")
equal(ns.Price(60).source, "auction", "the unobserved market good stays in the auction search")
equal(ns.Price(61).source, "vendor", "a vendor-only reagent keeps its known source")
equal(ns.Price(61).unknown, nil, "a vendor-only reagent needs no auction observation")
equal(ns.Price(62).unknown, true, "a gathering source counts even without that profession")
equal(ns.Price(63).unknown, true, "a crafted market good without an observation stays unknown")
equal(ns.ObtainCost(60), nil, "a fallback amount is not a known obtain cost")
equal(ns.CraftCost(100), nil, "an unknown fallback does not become a recipe cost")
equal(ns.ObtainCost(64), nil, "an unobserved looted reagent is not free")
equal(ns.CraftCost(102), nil, "the zero placeholder does not become a free craft")

c.professions = { { name = "Blacksmithing", rank = 1, max = 300, id = 164 } }
c.known[100] = true
c.known[103], c.known[104], c.known[105] = true, true, true
ns.Changed("prices")
equal(ns.CraftCost(101), nil, "unknown input costs propagate through a learned subcraft")
equal(ns.ObtainCost(67), nil, "the recursion depth limit also rejects an unknown zero placeholder")

c.auction[60], c.auction[62], c.auction[64] = 50, 10, 80
c.AuctionatorScan()
equal(ns.Price(60).source, "vendor", "a cheaper vendor wins once the auction price is observed")
equal(ns.Price(60).copper, 25, "the known vendor price is retained")
equal(ns.Price(60).unknown, nil, "a known auction comparison is not unknown")
equal(ns.Price(62).source, "auctionator", "a cheaper auction observation wins")
equal(ns.CraftCost(100), 50, "the scan makes the recipe cost known")
equal(ns.CraftCost(101), 50, "a known cheaper subcraft resolves the intermediate cost")
c.auction[63] = 200
c.AuctionatorScan()
equal(ns.CraftCost(101), 190, "a known intermediate keeps its auction sale-value floor")

c.tsm[62] = 15
c.SetSetting("priceSource", "tsm")
equal(ns.Price(62).source, "tsm", "the chosen auction source still wins")
equal(ns.Price(62).copper, 15, "the chosen source supplies its own observation")
equal(ns.Price(60).source, "vendor", "a gap in the chosen source uses the other observation")
equal(ns.Price(60).unknown, nil, "fallback auction observations also resolve uncertainty")
c.auction[60] = 25
c.AuctionatorScan()
equal(ns.Price(60).source, "vendor", "the known vendor still wins an observed auction tie")
equal(ns.Price(60).unknown, nil, "an observed tie is not unknown")

ns.SetCollectMode("gather")
equal(ns.Price(60).source, "gather", "collect mode still permits self-supplied loot")
equal(ns.Price(60).copper, 0, "self-supplied loot keeps the player's free-material setting")

-- Route planning and retained routes must agree on what counts as a known price.
local routeClient = Client.load({
	data = {
		Thresholds = { [200] = { 1, 30, 40, 50 }, [201] = { 1, 30, 40, 50 }, [202] = { 1, 30, 40, 50 } },
		RecipeData = {
			[200] = { skillLine = 164, reagents = { { itemID = 60, quantity = 1 } } },
			[201] = { skillLine = 164, reagents = { { itemID = 61, quantity = 1 } } },
			[202] = { skillLine = 164, reagents = { { itemID = 60, quantity = 2 }, { itemID = 64, quantity = 1 } } },
		},
		VendorPrices = { [60] = 25, [61] = 40 },
		LootedFrom = { [60] = true, [64] = true },
		GatheredBy = {},
		TrainerFees = {},
		TrainerRanks = {},
	},
})
local routeNS = routeClient.ns
routeClient.professions = { { name = "Blacksmithing", rank = 1, max = 75, id = 164 } }
routeClient.known[200], routeClient.known[201], routeClient.known[202] = true, true, true
routeNS.SetCollectMode("auction")
routeNS.db.craftValue = "none"
routeNS.db.routeTargets[164] = 5
local profession = routeNS.PlayerProfessions()[164]
local first = routeNS.PlanRoute(profession)
equal(first.crafts[1].recipeID, 201, "first visit uses the vendor-only recipe with a known cost")
equal(first.unpriced, 2, "both recipes needing market observations are excluded")
equal(
	table.concat(routeNS.UnpricedReagents(first), ","),
	"60,64",
	"missing market observations are sorted and deduplicated"
)

routeClient.auction[60] = 10
routeClient.AuctionatorScan()
-- Explicitly choose today's cheapest route rather than retaining the vendor shopping route.
routeNS.Changed("replan")
local observed = routeNS.PlanRoute(profession)
equal(observed.crafts[1].recipeID, 200, "an observation makes the cheaper market recipe usable")
equal(routeNS.RouteFollowable(observed), true, "a known purchase cost keeps the route followable")
routeClient.auction[60] = nil
routeClient.AuctionatorScan()
equal(routeNS.RouteFollowable(observed), false, "a fallback amount cannot keep an unobserved purchase followable")
local refreshed = routeNS.PlanRoute(profession)
equal(refreshed.crafts[1].recipeID, 201, "losing an observation releases the retained market route")
routeClient.bags[60] = observed.crafts[1].crafts
equal(routeNS.RouteFollowable(observed), true, "held materials need no purchase observation")
routeClient.bags[60] = observed.crafts[1].crafts - 1
equal(routeNS.RouteFollowable(observed), false, "a single missing unit still needs a known purchase cost")

routeClient.auction[60] = 10
routeClient.AuctionatorScan()
routeNS.Changed("replan")
local carried = routeNS.PlanRoute(profession)
routeClient.bags[60] = carried.crafts[1].crafts
routeNS.Changed("bags")
routeClient.auction[60] = nil
routeClient.AuctionatorScan()
equal(
	routeNS.PlanRoute(profession).crafts[1].recipeID,
	200,
	"held materials preserve the committed route after an observation disappears"
)
routeClient.bags[60] = routeClient.bags[60] - 1
routeNS.Changed("bags")
equal(
	routeNS.PlanRoute(profession).crafts[1].recipeID,
	201,
	"a bag shortfall releases the committed route when its price is unknown"
)

-- Real retained-route state, with every material held and the market observation lost.
routeClient.auction[60] = 10
routeClient.AuctionatorScan()
routeNS.Changed("replan")
local committed = routeNS.PlanRoute(profession)
routeClient.bags[60] = committed.crafts[1].crafts
routeNS.Changed("bags")
routeClient.auction[60] = nil
routeClient.AuctionatorScan()
local retained = routeNS.PlanRoute(profession)
equal(retained.crafts[1].recipeID, 200, "the held route remains committed")
-- Locate the loaded UI closure without modifying any addon function or upvalue.
local seen = {}
local function find(fn, wanted)
	if seen[fn] then
		return
	end
	seen[fn] = true
	for i = 1, 100 do
		local name, value = debug.getupvalue(fn, i)
		if not name then
			break
		end
		if name == wanted then
			return value
		end
		if type(value) == "function" then
			local result = find(value, wanted)
			if result then
				return result
			end
		end
	end
end
local render = assert(find(routeNS.AttachRoute, "RenderRoute"), "loaded RenderRoute closure")
local rows = {}
local list = setmetatable({}, {
	__index = function(_, key)
		return function(_, row)
			if key == "Add" then
				rows[#rows + 1] = row
			end
		end
	end,
})
render(list, retained)
local craftRow
for _, row in ipairs(rows) do
	if row.text:find("Craft", 1, true) then
		craftRow = row
	end
end
assert(craftRow, "real route craft row")
local costText
routeClient.G.GameTooltip_AddColoredDoubleLine = function(_, left, right)
	if left == "Cost" then
		costText = right
	end
end
local tooltip = setmetatable({}, {
	__index = function()
		return function() end
	end,
})
-- Supply the color presentation method absent from the shared stub client.
for _, color in pairs(routeNS.COLORS) do
	color.WrapTextInColorCode = function(_, text)
		return text
	end
end
routeClient.G.GameTooltip_AddInstructionLine = function() end
routeClient.G.Professions = false
craftRow.tooltip(tooltip)
local apiRecipe = routeClient.G.SkillUpForever.API.Recipe(200)
assert(costText, "real craft tooltip cost")
equal(routeNS.StepCost(200, retained.crafts[1].crafts), nil, "unknown held craft cost stays unknown")
equal(craftRow.detail:find(routeNS.L["price unknown"], 1, true) ~= nil, true, "the row names the unknown price")
equal(costText, routeNS.L["price unknown"], "the tooltip names the unknown price")
equal(apiRecipe.netCost, nil, "the public recipe cost also stays unknown")
routeClient.auction[60] = 20
routeClient.AuctionatorScan()
equal(
	routeNS.StepCost(200, retained.crafts[1].crafts),
	20 * retained.crafts[1].crafts,
	"a new observation restores the cost"
)

Client.report("first_visit_prices_spec")
