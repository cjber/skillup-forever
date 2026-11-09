-- Run from the repository root: luajit tests/tooltip_refresh_spec.lua
-- Issue #477: with item comparison on, the game shows the hovered item's tooltip and up to two shopping
-- comparison tooltips, and refreshes all three while the character moves. A refresh that asks for the same item
-- on the same tooltip must only look its answer up: no uses worked out, no routes read and no lines added again.
-- A tooltip the client genuinely clears drops that answer, so its lines are drawn back.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local BANDAGE, LINEN, BANDAGE_ITEM = 1, 3, 50
local GEAR_ONE, GEAR_TWO, GEAR_THREE, GEAR_FOUR = 5001, 5002, 5003, 5004
local FIRST_AID, MINING, SKINNING = 129, 186, 393
local COPPER = 1

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
		NodeSkills = { ["Copper Vein"] = { MINING, COPPER } },
	},
})
local G, ns = c.G, c.ns
G.IsShiftKeyDown = function()
	return false
end

c.items[LINEN] = { name = "Linen Cloth" }
c.items[BANDAGE_ITEM] = { name = "Linen Bandage", sell = 3 }
c.items[GEAR_ONE] = { name = "Sturdy Boots" }
c.items[GEAR_TWO] = { name = "Sturdy Gloves" }
c.items[GEAR_THREE] = { name = "Sturdy Belt" }
c.items[GEAR_FOUR] = { name = "Sturdy Cloak" }
c.known[BANDAGE] = true
c.professions = {
	{ name = "First Aid", rank = 20, max = 75, id = FIRST_AID },
	{ name = "Mining", rank = 140, max = 150, id = MINING },
	{ name = "Skinning", rank = 60, max = 75, id = SKINNING },
}
c.Boot()
c.EnterWorld()
c.Advance(0)
ns.db.reagentTooltip = "full"

-- Count the work each refresh does: the addon's own lookups beyond its caches, and every line it adds.
local calls = {}
local function Wrap(name, table)
	calls[name] = 0
	local real = table[name]
	table[name] = function(...)
		calls[name] = calls[name] + 1
		return real(...)
	end
end
Wrap("UsedIn", ns)
Wrap("TrackedNeeds", ns)
Wrap("RouteReagents", ns)
Wrap("PlayerProfessions", ns)
Wrap("Have", ns)
Wrap("Get", ns.Model)

local draws = 0
local colored = {}
c.G.GameTooltip_AddBlankLineToTooltip = function()
	draws = draws + 1
end
c.G.GameTooltip_AddNormalLine = function()
	draws = draws + 1
end
c.G.GameTooltip_AddDisabledLine = function()
	draws = draws + 1
end
c.G.GameTooltip_AddColoredLine = function(_, text)
	draws = draws + 1
	colored[#colored + 1] = text
end

local function Reset()
	for name in pairs(calls) do
		calls[name] = 0
	end
	draws = 0
	colored = {}
end

-- A tooltip that keeps what it was given, runs the clearing hooks the client fires, and records the hook.
local function Tooltip()
	local tooltip = { lines = {}, hooks = {} }
	function tooltip.IsForbidden()
		return false
	end
	function tooltip:HookScript(name, hook)
		self.hooks[name] = self.hooks[name] or {}
		table.insert(self.hooks[name], hook)
	end
	-- What the client does before it sets the tooltip again: empty it and fire OnTooltipCleared.
	function tooltip:Clear()
		self.lines = {}
		for _, hook in ipairs(self.hooks.OnTooltipCleared or {}) do
			hook(self)
		end
	end
	function tooltip:AddDoubleLine(left, right)
		self.lines[#self.lines + 1] = { left = left, right = right }
		draws = draws + 1
	end
	return tooltip
end

local itemPost = c.postCalls[G.Enum.TooltipDataType.Item][1]
local main, compareOne, compareTwo = Tooltip(), Tooltip(), Tooltip()
local gearOne, gearTwo = { id = GEAR_ONE }, { id = GEAR_TWO }
local gearThree, gearFour = { id = GEAR_THREE }, { id = GEAR_FOUR }

-- The first frame works each tooltip's answer out.
Reset()
itemPost(main, { id = LINEN })
itemPost(compareOne, gearOne)
itemPost(compareTwo, gearTwo)
equal(calls.UsedIn, 3, "the first frame works out each tooltip's item")
equal(calls.TrackedNeeds, 1, "and reads the routes once for the reagent")
equal(draws > 0, true, "and draws the reagent's lines")

-- The next frame asks for the same three items on the same three tooltips. This is the refresh the game runs
-- while the character moves: nothing changed, so there is no work beyond the lookup, and nothing is drawn.
Reset()
itemPost(main, { id = LINEN })
itemPost(compareOne, gearOne)
itemPost(compareTwo, gearTwo)
equal(calls.UsedIn, 0, "a repeated item on the same tooltip works out no uses again")
equal(calls.TrackedNeeds, 0, "and reads no routes again")
equal(calls.PlayerProfessions, 0, "and reads no professions again")
equal(draws, 0, "and adds no lines again")
equal(calls.Have, 0, "and reads no bag counts again")

-- The client clears a tooltip before it sets it again. The lines are gone with the clear, so they are drawn
-- back, from the answers already cached.
main:Clear()
Reset()
itemPost(main, { id = LINEN })
equal(calls.UsedIn, 0, "a real set after the client's clear reads the cached answer")
equal(calls.Have, 0, "and reads no bag counts for its route line")
equal(draws > 0, true, "and draws the cached lines back into the cleared tooltip")

-- A bag change moves a route line's count, so the next set draws it with the new count.
c.bags[LINEN] = 1
c.Fire("BAG_UPDATE_DELAYED")
main:Clear()
Reset()
itemPost(main, { id = LINEN })
equal(calls.UsedIn, 0, "looting one more does not rebuild the item's uses")
equal(calls.Have, 1, "a bag change reads the new count once")
equal(string.find(colored[1] or "", "^Route: 1/") ~= nil, true, "and the route line shows the new count")
Reset()
main:Clear()
itemPost(main, { id = LINEN })
equal(calls.Have, 0, "the next set of the same item reads the cached route line")

-- Only the tooltip whose item changed works anything out; the other two are lookups.
Reset()
itemPost(main, { id = LINEN })
itemPost(compareOne, gearThree)
itemPost(compareTwo, gearTwo)
equal(calls.UsedIn, 1, "only the comparison tooltip whose item moved works out its uses")

-- A different item on the same tooltip is a different answer, drawn once and then looked up.
Reset()
itemPost(compareTwo, gearFour)
equal(calls.UsedIn, 1, "a different item on the same tooltip works its uses out once")
Reset()
itemPost(compareTwo, gearFour)
equal(calls.UsedIn, 0, "and the refresh after it is a lookup again")

-- A mode or Shift change is part of the answer's key, so it draws the other variant.
ns.db.reagentTooltip = "route"
Reset()
itemPost(main, { id = LINEN })
equal(draws > 0, true, "another mode draws the other variant")

Client.report("tooltip_refresh_spec")
