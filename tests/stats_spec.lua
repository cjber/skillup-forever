-- Own-character observations remain local after peer leaderboards are removed.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local c = Client.load({ saved = { learned = { ["Tester-Realm"] = { [3275] = true } } } })
local ns = c.ns

local function own()
	return ns.Stats.Local()
end

equal(own(), 0, "old learned flags are not new observations")
equal(ns.Stats.Observe(3275), true, "a new recipe is observed")
equal(ns.Stats.Observe(3275), false, "the same recipe is only counted once")
equal(own(), 1, "the observation stays local")
equal(ns.Stats.Observe(0), false, "invalid recipe IDs are refused")
equal(ns.Stats.Observe(math.huge), false, "infinite recipe IDs are refused")

local saved = c.G.SkillUpForeverDB
saved.peerStats = { ["Tester-Realm"] = { stale = true } }
saved.statsShare = false
local reloaded = Client.load({ saved = saved })
equal(reloaded.ns.db.peerStats, nil, "old peer data is discarded")
equal(reloaded.ns.db.statsShare, nil, "old sharing setting is discarded")
equal(reloaded.ns.Stats.Local(), 1, "local observations survive migration")

Client.report("stats_spec")
