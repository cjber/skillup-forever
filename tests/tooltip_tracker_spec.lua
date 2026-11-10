-- Run from the repository root: luajit tests/tooltip_tracker_spec.lua
-- Issue #526: an equippable item shows its own tooltip and up to two shopping comparison tooltips, and the client
-- loads item data for them while the pointer rests. Item data arrives for any item, from any addon, so only the
-- tracker's own data may redraw it: hovering gear must leave the section alone.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local BANDAGE, LINEN, BANDAGE_ITEM = 1, 3, 50
local GEAR_ONE, GEAR_TWO, GEAR_THREE = 5001, 5002, 5003
local FIRST_AID = 129

local c = Client.load({
	boot = false,
	saved = { routeTargets = { [FIRST_AID] = 50 }, trackedProfessions = { [FIRST_AID] = true } },
	data = {
		Thresholds = { [BANDAGE] = { 1, 30, 45, 60 } },
		RecipeData = {
			[BANDAGE] = {
				skillLine = FIRST_AID,
				reagents = { { itemID = LINEN, quantity = 1 } },
				output = { itemID = BANDAGE_ITEM, quantity = 1 },
			},
		},
		TrainerFees = {},
		TrainerRanks = { [FIRST_AID] = {} },
		ItemSellPrices = {},
		GatheredBy = {},
		VendorPrices = { [LINEN] = 10 },
		ProfessionTrainers = {},
		NodeSkills = {},
	},
})
local G, ns = c.G, c.ns
G.IsShiftKeyDown = function()
	return false
end

-- The tracked reagent's name has not arrived, so the tracker is waiting on it. The gear's names are loaded:
-- hovering equippable items is the case under test, not a missing name.
c.items[BANDAGE_ITEM] = { name = "Linen Bandage", sell = 3 }
c.items[GEAR_ONE] = { name = "Sturdy Boots" }
c.items[GEAR_TWO] = { name = "Sturdy Gloves" }
c.items[GEAR_THREE] = { name = "Sturdy Belt" }
c.known[BANDAGE] = true
c.professions = { { name = "First Aid", rank = 20, max = 75, id = FIRST_AID } }
c.Boot()
c.EnterWorld()
c.Advance(0)
ns.db.reagentTooltip = "full"

local module = c.tracker[1]
equal(module ~= nil, true, "the tracked reagents section is attached")
-- Lay the section out once, as the host does: it asks for the reagent name that has not arrived.
c.Tracker()
c.Advance(0)
local redraws = module.dirty or 0

-- The client's item post-call, and a tooltip that keeps what it is given.
local itemPost = c.postCalls[G.Enum.TooltipDataType.Item][1]
local function Tooltip()
	return {
		IsForbidden = function()
			return false
		end,
		HookScript = function() end,
		AddDoubleLine = function() end,
	}
end
local main, compareOne, compareTwo = Tooltip(), Tooltip(), Tooltip()

-- Five hovers of an equippable item, each showing its comparison tooltips and loading their item data. None of
-- that is data the tracker draws, so its redraw count must not move.
for _ = 1, 5 do
	itemPost(main, { id = GEAR_ONE })
	itemPost(compareOne, { id = GEAR_TWO })
	itemPost(compareTwo, { id = GEAR_THREE })
	c.Fire("ITEM_DATA_LOAD_RESULT", GEAR_ONE, true)
	c.Fire("ITEM_DATA_LOAD_RESULT", GEAR_TWO, true)
	c.Fire("ITEM_DATA_LOAD_RESULT", GEAR_THREE, true)
	c.Advance(0)
end
equal(module.dirty or 0, redraws, "hovering equippable items with comparison on leaves the tracker alone")

-- The name the tracker really is waiting for still reaches it, once.
c.items[LINEN] = { name = "Linen Cloth" }
c.Fire("ITEM_DATA_LOAD_RESULT", LINEN, true)
equal((module.dirty or 0) - redraws, 1, "item data the tracker waited for redraws it once")

Client.report("tooltip_tracker_spec")
