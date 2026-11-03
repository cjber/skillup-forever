local Client = dofile("tests/client.lua")
local equal = Client.equal
local c = Client.load()
local ns, M = c.ns, c.ns.Model

ns.SetSkipped(3275, true)
ns.SetPinned(3275, true)
equal(ns.IsSkipped(3275), false, "pinning restores a skipped recipe")
equal(ns.PinPreference(3275) > 0, true, "the pin belongs to this character")
ns.SetPinned(3276, true)
equal(ns.PinPreference(3276) > ns.PinPreference(3275), true, "newer pins take priority")
ns.SetPinned(3275, true)
equal(ns.PinPreference(3275) > ns.PinPreference(3276), true, "pinning again raises priority")
equal(#ns.PinnedRecipes(129), 2, "the profession lists its pins")
equal(#ns.PinnedRecipes(164), 0, "another profession has none")
ns.SetSkipped(3275, true)
equal(ns.PinPreference(3275), 0, "skipping removes the pin")
ns.SetPinned(3276, false)
equal(#ns.PinnedRecipes(), 0, "unpinning removes the saved choice")

local cheap = { recipeID = 1, thresholds = { 1, 20, 30, 50 }, netCost = 1 }
local pinned = { recipeID = 2, thresholds = { 5, 10, 15, 20 }, netCost = 10, preference = 1 }
local snapshot = { skill = 1, target = 25, recipes = { cheap, pinned } }
local route = M.PlanRoute(snapshot)
equal(route.segments[1].recipeID, 1, "automatic recipe before the pin's range")
equal(route.segments[2].recipeID, 2, "the expensive pin wins in its usable range")
equal(route.segments[2].fromSkill, 5, "the pin respects its requirement")
equal(route.segments[2].toSkill, 20, "the pin stops when grey")
equal(route.segments[3].recipeID, 1, "automatic recipe resumes afterwards")
local later = { recipeID = 3, thresholds = { 5, 10, 15, 20 }, netCost = 20, preference = 2 }
snapshot.recipes[3] = later
equal(M.PlanRoute(snapshot).segments[2].recipeID, 3, "the most recent overlapping pin wins")
later.netCost = nil
equal(M.PlanRoute(snapshot).segments[2].recipeID, 2, "an unpriced pin is never assigned a guessed cost")

snapshot.recipes = { cheap }
local service = { recipeID = 2, thresholds = pinned.thresholds, netCost = 10, preference = 1, fee = 100 }
local trained = M.PlanWithTraining(snapshot, { service })
equal(trained.segments[2].recipeID, 2, "a pinned trainer recipe is used despite its higher cost")
equal(#trained.training, 1, "the pinned recipe is trained")
equal(trained.trainingCost, 100, "its fee is charged once")
equal(M.RecommendTraining(snapshot, { service }).recipeID, 2, "trainer advice honours the same preference")
service.thresholds = { 30, 40, 45, 50 }
equal(#M.PlanWithTraining(snapshot, { service }).training, 0, "a pin beyond the target is not trained")

local reloaded = Client.load({
	saved = {
		pinnedRecipes = {
			["Tester-Realm"] = { [3275] = 1, [3276] = 2, bad = 3, [1] = math.huge, [2] = -1 },
			Other = 3,
		},
		skippedRecipes = { ["Tester-Realm"] = { [3276] = true } },
	},
})
equal(reloaded.ns.PinPreference(3275), 1, "a saved pin survives reload")
equal(reloaded.ns.PinPreference(3276), 0, "a saved skip wins over a conflicting pin")
equal(reloaded.ns.db.pinnedRecipes["Tester-Realm"].bad, nil, "invalid recipe keys are removed")
equal(reloaded.ns.PinPreference(1), 0, "nonfinite priorities are removed")
equal(reloaded.ns.PinPreference(2), 0, "negative priorities are removed")
equal(reloaded.ns.db.pinnedRecipes.Other, nil, "malformed character maps are removed")

-- Character changes see a different saved map.
c.player.name = "Other"
equal(ns.PinPreference(3275), 0, "pins are isolated per character")
ns.SetPinned(3275, true)
c.player.name = "Tester"
equal(ns.PinPreference(3275), 0, "another character's pin does not change this one")

Client.report("pin_spec")
