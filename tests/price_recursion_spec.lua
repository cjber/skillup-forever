-- Run from the repository root: luajit tests/price_recursion_spec.lua
-- #899: pricing a long route's need of a crafted reagent froze the client ("script ran too long" in ObtainCost).
-- With limited vendor stock anywhere below it, ObtainCost tried every whole batch count of the item and, for each,
-- every batch count of each reagent, three levels down, so the work grew with the need to the power of the depth.
-- The answer bends only where stock or a purchase runs out, so only the batch counts near a bend are priced, and
-- a subtree priced again under the same stock is read from the memo. Work must not grow with the count.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local LEATHERWORKING = 165
local SCRAPS, LIGHT, MEDIUM, HEAVY, THICK = 2934, 2318, 2319, 4234, 4304
-- Light Leather from scraps, Medium from Light, Heavy from Medium, Thick from Heavy: four levels of one maker each.
local KNOWN = { 2881, 20648, 20649, 20650 }
local VENDOR = 5001

local c = Client.load({
	saved = {
		vendor = { [LIGHT] = 5, [MEDIUM] = 5, [HEAVY] = 5 },
		sellers = {
			[VENDOR] = {
				name = "Leather Vendor",
				side = "A",
				map = 10,
				x = 0.5,
				y = 0.5,
				items = { [LIGHT] = true, [MEDIUM] = true, [HEAVY] = true },
			},
		},
	},
	data = { LimitedStock = { [LIGHT] = { [VENDOR] = 3 }, [MEDIUM] = { [VENDOR] = 2 }, [HEAVY] = { [VENDOR] = 2 } } },
})
local ns = c.ns
c.level = 60
c.player.faction = "Alliance"
c.professions = { { name = "Leatherworking", id = LEATHERWORKING, rank = 200, max = 300 } }
for _, recipeID in ipairs(KNOWN) do
	c.known[recipeID] = true
end
for itemID, copper in pairs({ [SCRAPS] = 20, [LIGHT] = 90, [MEDIUM] = 400, [HEAVY] = 2500, [THICK] = 16000 }) do
	c.auction[itemID] = copper
end
ns.Changed("prices")
equal(ns.LimitedReagentPrice(HEAVY), 2, "the vendor's Heavy Leather is limited stock")

-- Every ObtainCost evaluation reads the item's limited quote once; the memo and the batch bound both show here.
local reads = 0
local quote = ns.LimitedReagentPrice
ns.LimitedReagentPrice = function(itemID)
	reads = reads + 1
	return quote(itemID)
end

---@param count integer
---@return integer reads
---@return SkillUpMakerChoice?
local function Price(count)
	ns.Changed("prices")
	reads = 0
	local maker = ns.SubCraft(THICK, count, {})
	return reads, maker
end

local small, smallMaker = Price(30)
local large, largeMaker = Price(60)
equal(smallMaker and smallMaker.recipeID, 20650, "thirty Thick Leather are made from Heavy Leather")
equal(largeMaker and largeMaker.recipeID, 20650, "and so are sixty")
equal(largeMaker and largeMaker.purchaseUnits, 0, "none of them bought at auction")
-- Past the stock window the candidate batches are the same few at any count, so twice the need is not more work.
-- Before #899 it was about eight times (the work grew with the cube of the count).
equal(large <= small * 2, true, string.format("pricing 60 reads %d quotes against %d for 30", large, small))

-- The route's own call shape: the tracker's whole Leatherworking need, priced with a shared stock ledger.
local ledger = {}
ns.Changed("prices")
local maker = ns.SubCraft(HEAVY, 232, ledger)
equal(maker and maker.recipeID, 20649, "a long route's Heavy Leather is still made from Medium Leather")
equal(next(ledger), nil, "pricing does not spend the ledger it was not asked to take from")

print("price_recursion_spec: ok")
