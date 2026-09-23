-- Run from the repository root: luajit tests/waypoint_spec.lua
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

-- One vendor in Elwynn Forest (uiMapID 1429) at 42.1, 65.9.
local calls
local ns = {
	SourceNPCs = { [1250] = { "Drake Lindgren", "A", 0, -9000, 100 } },
	InstanceNames = {},
	Print = function(message)
		calls.printed = message
	end,
}
local env = setmetatable({
	C_Map = {
		GetMapPosFromWorldPos = function()
			return 1429, {
				GetXY = function()
					return 0.421, 0.659
				end,
			}
		end,
		GetMapInfo = function()
			return { name = "Elwynn Forest" }
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
	ns.SetWaypoint(1250)
end

Run(true)
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

Run(nil)
equal(calls.native and calls.native.x, 0.421, "without Shortest Path Forever the map waypoint is set")
equal(calls.superTracked, true, "without Shortest Path Forever the waypoint is super-tracked")

print("waypoint_spec: " .. checks .. " checks passed")
