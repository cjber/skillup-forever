-- Run from the repository root: luajit tests/waypoint_spec.lua
local Client = dofile("tests/client.lua")
local equal = Client.equal

-- One vendor in Elwynn Forest (uiMapID 1429) at 42.1, 65.9, as the catalogue reads it from QuestieDB.
local calls
---@type table<integer, table>
local npcs = { [1250] = { name = "Drake Lindgren", side = "A", map = 1429, x = 0.421, y = 0.659 } }
local ns = {
	Catalogue = {
		NPC = function(npcID)
			return npcs[npcID]
		end,
	},
	Print = function(message)
		calls.printed = message
	end,
}
local maps = { [1429] = { mapID = 1429, name = "Elwynn Forest", mapType = 3, parentMapID = 1415 } }
local placed = 0
local env = setmetatable({
	UNKNOWN = "Unknown",
	C_Map = {
		GetMapInfo = function(map)
			return maps[map]
		end,
		GetAreaInfo = function(area)
			return area == 1581 and "The Deadmines" or nil
		end,
		-- Elwynn Forest is on continent 0, its x running north to south.
		GetWorldPosFromMapPos = function(_, point)
			placed = placed + 1
			return 0, {
				GetXY = function()
					return -point.x * 10000, 100
				end,
			}
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
assert(loadfile("Locales/enUS.lua"))("SkillUpForever", ns)
setfenv(assert(loadfile("Integrations/Sources.lua")), env)("SkillUpForever", ns)

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

-- An NPC is named by its zone and its place on the zone's map.
local where = ns.NPCLocation(1250)
equal(ns.LocationText(where), "Elwynn Forest  42, 66", "the NPC is named by zone and zone coordinates")
equal(where.map, 1429, "the waypoint is on the zone's map")
npcs[1260] = { name = "Lost", side = "", map = 99, x = 0.5, y = 0.5 }
equal(ns.LocationText(ns.NPCLocation(1260)), "unknown location", "a map the client lacks has no place")
equal(ns.NPCLocation(1261).name, "Unknown", "an NPC QuestieDB lacks has no name")
calls = {}
equal(ns.SetWaypoint(1261), false, "and starts no route")
equal(calls.printed, nil, "without a word")

-- Nearest by travel: 1251 is nearer in a straight line, 1252 across the water but a quicker trip; 1253 is of
-- the other faction and 1254 hostile to both.
npcs[1251] = { name = "Near", side = "", map = 1429, x = 0.91, y = 0.5 }
npcs[1252] = { name = "Quick", side = "", map = 1429, x = 0.95, y = 0.5 }
npcs[1253] = { name = "Horde", side = "H", map = 1429, x = 0.905, y = 0.5 }
npcs[1254] = { name = "Hostile", map = 1429, x = 0.905, y = 0.5 }
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
local sellers = { 1253, 1254, 1251, 1252 }
equal(ns.NearestNPC(sellers), 1251, "without byTravel the straight-line nearest wins")
equal(placed, 2, "each NPC this character can deal with is placed in the world")
equal(estimated, 0, "without byTravel nothing is estimated")
equal(ns.NearestNPC(sellers, true), 1252, "byTravel prefers the quicker trip")
equal(estimated, 2, "only this faction's vendors are estimated")
equal(placed, 2, "and placed only once")
seconds = {}
equal(ns.NearestNPC(sellers, true), 1251, "no estimate keeps the straight-line nearest")
combat, estimated = true, 0
equal(ns.NearestNPC(sellers, true), 1251, "in combat the straight-line nearest wins")
equal(estimated, 0, "nothing is estimated in combat")
combat, env.ShortestPathForever = false, nil
equal(ns.NearestNPC(sellers, true), 1251, "without Shortest Path Forever the straight-line nearest wins")
env.ShortestPathForever = { API = { version = 1 } }
equal(ns.NearestNPC(sellers, true), 1251, "an API without Estimate keeps the straight-line nearest")

-- A dungeon NPC has no map point: only a chat line, and no route started.
calls = {}
npcs[1255] = { name = "Sneed", area = 1581 }
equal(ns.SetWaypoint(1255), false, "a dungeon NPC starts no route")
equal(calls.printed, "Sneed is in The Deadmines.", "and says where it is")
equal(ns.NearestNPC({ 1255, 1261 }), nil, "and is nobody's nearest vendor")

Client.report("waypoint_spec")
