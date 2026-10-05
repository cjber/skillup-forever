-- Run from the repository root: luajit tests/tracking_spec.lua
-- Tracking a profession on its own when its window or trainer opens: the rule, and the player's stop it honours.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local BANDAGE = 1
local TAILORING = 197
local c = Client.load({
	data = {
		Thresholds = { [BANDAGE] = { 1, 30, 45, 60 } },
		RecipeData = { [BANDAGE] = { skillLine = 129, reagents = {} } },
		TrainerFees = {},
		TrainerRanks = {},
		ItemSellPrices = {},
		GatheredBy = {},
		VendorPrices = {},
		ProfessionTrainers = {},
	},
})
local ns = c.ns
c.known[BANDAGE] = true
c.spells[BANDAGE] = "Linen Bandage"
c.professions = {
	-- First Aid has a route ahead, Tailoring is capped with nothing to craft, Herbalism gathers.
	{ name = "First Aid", rank = 40, max = 75, id = 129 },
	{ name = "Tailoring", rank = 75, max = 75, id = TAILORING },
	{ name = "Herbalism", rank = 1, max = 75, id = 182 },
}
equal(#ns.PlanRoute(ns.RouteProfessions()[129]).steps > 0, true, "First Aid has steps left")
equal(#ns.PlanRoute(ns.RouteProfessions()[TAILORING]).steps, 0, "Tailoring has none")

equal(ns.AutoTrack(nil), false, "no open profession to track")
equal(ns.AutoTrack(182), false, "a gathering profession is never tracked")
equal(ns.IsTracked(182), false, "and stays untracked")
equal(ns.AutoTrack(TAILORING), false, "a route with no steps left is not tracked")
equal(ns.db.trackedProfessions[TAILORING], nil, "which leaves no decision behind")

equal(ns.AutoTrack(129), true, "opening First Aid's own window starts tracking it")
equal(ns.IsTracked(129), true, "and it is tracked")
equal(ns.TrackedNeeds()[1].plan.profession.skillLine, 129, "which puts its reagents in the tracker")
equal(ns.AutoTrack(129), false, "the same open does not sign it up again")

-- The player stopping it is a decision of their own, kept as a saved false.
ns.SetTracked(129, false)
equal(ns.db.trackedProfessions[129], false, "stopping by hand is kept, not dropped")
equal(ns.AutoTrack(129), false, "so the next open leaves it stopped")
equal(ns.IsTracked(129), false, "and it stays untracked")
ns.SetTracked(129, true)
equal(ns.db.trackedProfessions[129], true, "tracking by hand clears the stop")
equal(ns.AutoTrack(129), false, "and nothing overrides a decision already made")

Client.report("tracking_spec")
