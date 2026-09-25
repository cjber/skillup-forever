-- Run from the repository root: luajit tests/waypoint_spec.lua
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

-- One vendor in Elwynn Forest (uiMapID 1429) at 42.1, 65.9, which is 47.0, 80.0 on
-- the Eastern Kingdoms continent map (1415).
local calls
local ns = {
	SourceNPCs = { [1250] = { "Drake Lindgren", "A", 0, -9000, 100 } },
	InstanceNames = {},
	Print = function(message)
		calls.printed = message
	end,
}
local maps = {
	[1415] = { mapID = 1415, name = "Eastern Kingdoms", mapType = 2, parentMapID = 947 },
	[1429] = { mapID = 1429, name = "Elwynn Forest", mapType = 3, parentMapID = 1415 },
	[1600] = { mapID = 1600, name = "Goldshire Inn", mapType = 5, parentMapID = 1429 },
}
---@type integer?
local underPoint = 1429
local positions = {
	[1415] = { 0.47, 0.80 },
	[1429] = { 0.421, 0.659 },
}
local function Position(x, y)
	return {
		GetXY = function()
			return x, y
		end,
	}
end
local env = setmetatable({
	Enum = { UIMapType = { Continent = 2, Zone = 3, Dungeon = 4, Micro = 5 } },
	C_Map = {
		GetMapPosFromWorldPos = function(_, _, override)
			local map = override or 1415
			local at = positions[map]
			if at then
				return map, Position(at[1], at[2])
			end
		end,
		GetMapInfo = function(map)
			return maps[map]
		end,
		GetMapInfoAtPosition = function(map, x, y)
			calls.atPosition = { map = map, x = x, y = y }
			return maps[underPoint]
		end,
		CanSetUserWaypointOnMap = function()
			return true
		end,
		SetUserWaypoint = function(point)
			calls.native = point
		end,
	},
	C_SuperTrack = {
		SetSuperTrackedUserWaypoint = function(on)
			calls.superTracked = on
		end,
	},
	UiMapPoint = {
		CreateFromCoordinates = function(map, x, y)
			return { map = map, x = x, y = y }
		end,
	},
	CreateVector2D = function(x, y)
		return { x = x, y = y }
	end,
}, { __index = _G })
setfenv(assert(loadfile("Sources.lua")), env)("SkillUpForever", ns)

---@param accepts boolean?
local function Run(accepts)
	calls = {}
	if accepts == nil then
		env.ShortestPathForever = nil
	else
		env.ShortestPathForever = {
			API = {
				version = 1,
				Navigate = function(owner, map, x, y, title)
					calls.navigate = { owner = owner, map = map, x = x, y = y, title = title }
					return accepts
				end,
			},
		}
	end
	calls.result = ns.SetWaypoint(1250)
end

Run(true)
equal(calls.result, true, "an accepted route reports it started")
equal(calls.navigate.owner, "SkillUpForever", "Shortest Path Forever gets the addon as owner")
equal(calls.navigate.map, 1429, "Shortest Path Forever gets the NPC's map")
equal(calls.navigate.x, 0.421, "Shortest Path Forever gets the NPC's x")
equal(calls.navigate.y, 0.659, "Shortest Path Forever gets the NPC's y")
equal(calls.navigate.title, "Drake Lindgren", "Shortest Path Forever names the stop after the NPC")
equal(calls.native, nil, "an accepted route sets no map waypoint")
equal(calls.printed, "route set to Drake Lindgren, Elwynn Forest  42, 66.", "an accepted route says where")

Run(false)
equal(calls.navigate ~= nil, true, "Shortest Path Forever is asked first")
equal(calls.native and calls.native.map, 1429, "a declined route falls back to the map waypoint")
equal(calls.superTracked, true, "the fallback waypoint is super-tracked")
equal(calls.printed, "waypoint set to Drake Lindgren, Elwynn Forest  42, 66.", "the fallback says where")
equal(calls.result, true, "a map waypoint counts as started")

Run(nil)
equal(calls.native and calls.native.x, 0.421, "without Shortest Path Forever the map waypoint is set")
equal(calls.superTracked, true, "without Shortest Path Forever the waypoint is super-tracked")

-- Another API version, or version 1 without Navigate, is never called.
calls = {}
env.ShortestPathForever = {
	API = {
		version = 2,
		Navigate = function()
			calls.navigate = true
			return true
		end,
	},
}
ns.SetWaypoint(1250)
equal(calls.navigate, nil, "another API version isn't asked")
equal(calls.native and calls.native.map, 1429, "another API version falls back to the map waypoint")
calls = {}
env.ShortestPathForever = { API = { version = 1 } }
ns.SetWaypoint(1250)
equal(calls.native and calls.native.map, 1429, "an API without Navigate falls back to the map waypoint")

-- The hint under a waypoint click: install or enable Shortest Path Forever, or nothing.
local addons, hints = {}, {}
env.C_AddOns = {
	IsAddOnLoaded = function(name)
		return addons[name] == "loaded"
	end,
	DoesAddOnExist = function(name)
		return addons[name] ~= nil
	end,
	GetAddOnInfo = function(name)
		return name, name, "", addons[name] ~= "disabled", addons[name] == "disabled" and "DISABLED" or nil, "INSECURE"
	end,
}
env.GameTooltip_AddDisabledLine = function(_, text)
	hints[#hints + 1] = text
end
ns.db = { companionHints = true }
local function Hint(state)
	addons.ShortestPathForever, hints = state, {}
	ns.AddCompanionHint({})
	return hints[1]
end
equal(Hint(nil), "Install Shortest Path Forever for walked routes and boat times.", "missing: install it")
equal(Hint("disabled"), "Enable Shortest Path Forever for walked routes and boat times.", "turned off: enable it")
equal(Hint("loaded"), nil, "running: no hint")
ns.db.companionHints = false
equal(Hint(nil), nil, "the setting off hides the hint")

-- The client places the spawn on the continent map; the zone under that point names
-- it and re-projects it, so the label and waypoint are the zone's, not the continent's.
calls = {}
local where = ns.NPCLocation(1250)
equal(calls.atPosition.map, 1415, "the zone is looked up on the continent's map")
equal(calls.atPosition.x, 0.47, "the zone is looked up at the continent x")
equal(calls.atPosition.y, 0.80, "the zone is looked up at the continent y")
equal(ns.LocationText(where), "Elwynn Forest  42, 66", "the NPC is named by zone and zone coordinates")
equal(where.map, 1429, "the waypoint is on the zone's map")
underPoint = 1600
equal(
	ns.LocationText(ns.NPCLocation(1250)),
	"Elwynn Forest  42, 66",
	"a micro map under the point walks up to its zone"
)
underPoint = nil
where = ns.NPCLocation(1250)
equal(ns.LocationText(where), "Eastern Kingdoms  47, 80", "with no zone under the point the continent stays")
equal(where.map, 1415, "with no zone under the point the waypoint stays on the continent")
underPoint = 1429
positions[1429] = nil
equal(
	ns.LocationText(ns.NPCLocation(1250)),
	"Eastern Kingdoms  47, 80",
	"a zone that can't place the spawn keeps the continent"
)
positions[1429] = { 0.421, 0.659 }

-- Nearest by travel: 1251 is nearer in a straight line, 1252 across the water but
-- a quicker trip; both on the player's continent (0), 1253 of the other faction.
ns.SourceNPCs[1251] = { "Near", "", 0, -9100, 100 }
ns.SourceNPCs[1252] = { "Quick", "", 0, -9500, 100 }
ns.SourceNPCs[1253] = { "Horde", "H", 0, -9050, 100 }
local combat, estimated = false, 0
env.UnitFactionGroup = function()
	return "Alliance"
end
env.UnitPosition = function()
	return -9050, 100, 0, 0
end
env.InCombatLockdown = function()
	return combat
end
env.C_Map.GetBestMapForUnit = function()
	return 1429
end
env.C_Map.GetPlayerMapPosition = function()
	return {
		GetXY = function()
			return 0.5, 0.5
		end,
	}
end
env.C_Map.GetMapPosFromWorldPos = function(_, vector)
	return 1429, {
		GetXY = function()
			return -vector.x / 10000, 0.5
		end,
	}
end
local seconds = { [0.91] = 300, [0.95] = 60 }
env.ShortestPathForever = {
	API = {
		version = 1,
		Estimate = function(_, _, _, _, toX)
			estimated = estimated + 1
			return seconds[toX], seconds[toX] == nil and "unreachable" or nil
		end,
	},
}
local npcs = { 1253, 1251, 1252 }
equal(ns.NearestNPC(npcs), 1251, "without byTravel the straight-line nearest wins")
equal(estimated, 0, "without byTravel nothing is estimated")
equal(ns.NearestNPC(npcs, true), 1252, "byTravel prefers the quicker trip")
equal(estimated, 2, "only this faction's vendors are estimated")
seconds = {}
equal(ns.NearestNPC(npcs, true), 1251, "no estimate keeps the straight-line nearest")
combat, estimated = true, 0
equal(ns.NearestNPC(npcs, true), 1251, "in combat the straight-line nearest wins")
equal(estimated, 0, "nothing is estimated in combat")
combat, env.ShortestPathForever = false, nil
equal(ns.NearestNPC(npcs, true), 1251, "without Shortest Path Forever the straight-line nearest wins")
env.ShortestPathForever = { API = { version = 1 } }
equal(ns.NearestNPC(npcs, true), 1251, "an API without Estimate keeps the straight-line nearest")

-- A dungeon NPC has no map point: only a chat line, and no route started.
calls = {}
ns.InstanceNames[0] = "The Deadmines"
equal(ns.SetWaypoint(1250), false, "a dungeon NPC starts no route")
equal(calls.printed, "Drake Lindgren is in The Deadmines.", "and says where it is")
ns.InstanceNames[0] = nil

print("waypoint_spec: " .. checks .. " checks passed")
