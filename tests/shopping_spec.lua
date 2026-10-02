-- Run from the repository root: luajit tests/shopping_spec.lua
-- The objective tracker's lines and the merchant's buy button, with the whole addon loaded: what they show
-- follows the client's prices, bags and merchant through the plan.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local BANDAGE, HEAVY, SILK = 1, 2, 3
local c = Client.load({
	saved = { routeTargets = { [129] = 80 }, trackedProfessions = { [129] = true } },
	-- First Aid in miniature: a known bandage, a better one to train at 40, and Journeyman from 50.
	data = {
		Thresholds = { [BANDAGE] = { 1, 30, 45, 60 }, [HEAVY] = { 40, 50, 75, 100 } },
		RecipeData = {
			[BANDAGE] = { skillLine = 129, reagents = { { itemID = SILK, quantity = 1 } } },
			[HEAVY] = { skillLine = 129, reagents = { { itemID = SILK, quantity = 2 } } },
		},
		TrainerFees = { [HEAVY] = { 100, 40 } },
		TrainerRanks = { [129] = { { 150, 500, 50, 0 } } },
		RecipeSources = {},
		ItemSellPrices = {},
		GatheredBy = {},
		VendorPrices = {},
		ReagentVendors = {},
		ProfessionTrainers = {},
	},
})
local ns = c.ns
local module = c.G.SkillUpForeverObjectiveTracker
equal(c.host.IsAttached(module), true, "attaches to private host immediately")
c.EnterWorld()
equal(#c.tracker, 1, "native initialization cannot change private ownership")
c.G.ForeverTrackerHost, c.tracker = nil, {}
c.Advance(0)
equal(#c.tracker, 0, "missing private host remains inert")
c.G.ForeverTrackerHost = c.host
c.EnterWorld()
equal(#c.tracker, 0, "late host waits for the deferred callback")
c.Advance(0)
equal(c.tracker[1], module, "deferred callback attaches after late host publication")

c.level = 20
c.spells[HEAVY] = "Heavy Linen Bandage"
c.items[SILK] = { name = "Linen Cloth" }
c.known[BANDAGE] = true
c.auction[SILK] = 10
c.professions = { { name = "First Aid", rank = 40, max = 75, id = 129 } }

-- Journeyman is allowed from 50, but the plan trains Heavy Linen Bandage at 45 first, where it
-- becomes the cheaper point: the tracker leads with the page's first training step.
local lines = c.Tracker()[1].lines
local walked = ns.PlanRoute(ns.RouteProfessions()[129]).steps
equal(walked[2].training and walked[2].training.recipeID, HEAVY, "the route page trains the recipe first")
equal(walked[4].rank and walked[4].rank.name, "Journeyman", "and the rank after")
equal(lines[1].key, "Train", "the tracker leads with training")
equal(lines[1].text, "Train Heavy Linen Bandage at 45 |cff808080(+1 more)|r", "the same training")
equal(lines[2].key, SILK, "then the reagent still missing")

-- Auctionator loses the only price there was: the scan reaches the tracker, which redraws to say why
-- nothing can be crafted, not that the reagents are in hand.
local redraws = module.dirty or 0
c.auction[SILK] = nil
c.AuctionatorScan()
equal(module.dirty, redraws + 1, "a price change redraws the tracker once")
lines = c.Tracker()[1].lines
equal(#lines, 1, "one line")
equal(lines[1].key, "Blocked", "a blocked route says so")
equal(
	lines[1].text,
	"Auctionator hasn't seen these reagents yet: scan the auction house with it to price them.",
	"with the route page's reason"
)
c.auction[SILK] = 10
c.AuctionatorScan()

-- The merchant's button and its purchase, including missing stack data: seven cloth short of the route.
local function Needed()
	return ns.TrackedNeeds()[1].items[1].need
end
c.bags[SILK] = Needed() - 7
c.money = 10000
c.merchant = { { itemID = SILK, price = 100, stackCount = 5 } }
c.Fire("MERCHANT_SHOW")
local button
for _, frame in ipairs(c.frames) do
	if frame.parent == c.G.MerchantFrame then
		button = frame
	end
end
equal(button.shown, true, "known merchant stack enables purchasing")
equal(button.text, "Buy tracked reagents  200c", "purchase price accounts for whole stacks")
button.scripts.OnClick()
equal(c.purchased[1].count, 10, "purchase callback buys complete stacks in units")
for _, invalid in ipairs({ false, 0, -1 }) do
	c.merchant[1].stackCount = invalid or nil
	c.purchased = {}
	c.Fire("MERCHANT_UPDATE")
	equal(button.shown, false, "unknown or invalid stack hides purchase action")
	button.scripts.OnClick()
	equal(#c.purchased, 0, "unknown or invalid stack cannot buy invented units")
end
c.merchant = nil
c.Fire("MERCHANT_CLOSED")
equal(button.shown, false, "the button goes with the merchant")
equal(#c.chat, 0, "and none of it says anything in chat")

Client.report("shopping_spec")
