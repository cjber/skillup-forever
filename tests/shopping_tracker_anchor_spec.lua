-- Run from the repository root: luajit tests/shopping_tracker_anchor_spec.lua
-- The reagent section's anchor: the shared host owns it, no tracker order is reserved, and a parent or
-- point that the client has replaced is re-read on the next layout instead of being kept as a dead point.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local c = Client.load({
	saved = { trackedProfessions = { [129] = true } },
	data = {
		Thresholds = {},
		RecipeData = {},
		TrainerFees = {},
		TrainerRanks = {},
		ItemSellPrices = {},
		GatheredBy = {},
		VendorPrices = {},
		ProfessionTrainers = {},
	},
})
local ns = c.ns
local module = c.G.SkillUpForeverObjectiveTracker
equal(c.host.IsAttached(module), true, "the shared host owns the section")
equal(module.uiOrder, nil, "no permanent uiOrder pin is kept")

-- One tracked profession with no training step and no missing reagent, so every layout says it is ready.
-- The point here is the anchor, not the route.
ns.TrackedNeeds = function()
	return {
		{
			plan = { profession = { name = "First Aid", skillLine = 129 }, target = 75, steps = {} },
			items = {},
		},
	}
end
ns.Have = function()
	return 0
end
ns.RouteBlocked = function()
	return nil
end

-- A host that reparents on Attach, like UI/TrackerHost.lua's SetContainer. `current` is the anchor the
-- client has under the module now.
local current, attaches = nil, 0
local host = {
	Attach = function(target)
		attaches = attaches + 1
		current = {
			GetPoint = function()
				return "TOPLEFT"
			end,
		}
		target.parent = current
	end,
	IsAttached = function(target)
		return target.parent == current
	end,
}
c.G.ForeverTrackerHost = host

-- The module's old parent is gone. Attaching objects reads the anchor again, finds the host, and adds the
-- reagent block instead of raising.
module.parent = nil
local blocks = c.Tracker()
equal(#blocks, 1, "a replaced anchor is re-read and the reagent block is added")
equal(attaches, 1, "the host owns the frame again")
equal(#c.chat, 0, "nothing is printed when the anchor is back")

-- Blizzard recreates the heading frame during a layout: the old point is dead, so the next layout attaches
-- through the host again and lays the block out from the fresh anchor.
module.parent = {
	GetPoint = function()
		return nil
	end,
}
blocks = c.Tracker()
equal(#blocks, 1, "a dead point does not stop the reagent block")
equal(attaches, 2, "the next layout re-reads the anchor")
equal(ns.TrackerAttached(), true, "the module is still attached")

-- No parent and no anchor the host can give: the reagent path is skipped with one line, never an error.
c.G.ForeverTrackerHost = {
	Attach = function(target)
		target.parent = nil
	end,
	IsAttached = function()
		return false
	end,
}
local before = #c.chat
blocks = c.Tracker()
equal(#blocks, 0, "a missing parent skips the reagent block")
equal(#c.chat, before + 1, "and says so once")
equal(module:IsShown(), false, "the module is left inert")
equal(ns.TrackerAttached(), false, "and no longer counts as attached")

Client.report("shopping_tracker_anchor_spec")
