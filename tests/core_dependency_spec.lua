-- Run from the repository root: luajit tests/core_dependency_spec.lua
-- SkillUp Forever requires ForeverCore. This spec covers the two places the handover is the addon's: the one-line
-- stop for a ForeverCore older than the shared modules the addon calls, and the tracker settings it hands to the
-- shared column once.
local Client = dofile("tests/client.lua")

-- A fresh install, as ForeverCore would see it: saved variables are core's own.
local c = Client.load({
	saved = {
		trackerHost = { attached = false, locked = true, scale = 1.5, backdropOpacity = 0.5, x = 120, y = -240 },
	},
})
local ns, G = c.ns, c.G

-- The section joins the shared column once the world loads, as core's own sections do.
c.EnterWorld()
c.Advance(0)

-- The addon registers once, and the same name returns core's one context for it.
assert(ns.core ~= nil, "the addon registered its ForeverCore services")
assert(ns.core == G.ForeverCore.Register("SkillUpForever"), "Register is idempotent for the addon's name")
assert(type(ns.core.SafeCall) == "function", "the context carries the addon's SafeCall")
assert(type(ns.core.Report.Show) == "function", "and its own report window")

-- The saved trackerHost is a Forever Core setting now: the host copies it once and the addon drops its copy.
local settings = G.ForeverCoreDB.trackerHost
assert(settings, "the shared host has its settings")
assert(settings.migrated == true, "the copy is marked done")
assert(settings.attached == false, "the saved attachment carries over")
assert(settings.locked == true, "the saved Lock carries over")
assert(settings.scale == 1.5, "the saved scale carries over")
assert(settings.backdropOpacity == 0.5, "the saved background carries over")
assert(settings.x == 120 and settings.y == -240, "the saved detached position carries over")
assert(ns.db.trackerHost == nil, "the addon no longer keeps its own tracker table")

local module = G.SkillUpForeverObjectiveTracker
assert(module ~= nil, "the tracker section exists")
assert(G.ForeverCore.TrackerHost.IsAttached(module), "and hangs in the one shared column")

-- An older ForeverCore stops the addon's own files with one line in the error frame, never chat.
local function Require(foreverCore)
	local lines = {}
	local env = {
		UIErrorsFrame = {
			AddMessage = function(_, text, red, green, blue)
				lines[#lines + 1] = { text = text, red = red, green = green, blue = blue }
			end,
		},
		ForeverCore = foreverCore,
	}
	env._G = env
	setmetatable(env, { __index = _G })
	local addon = {}
	setfenv(assert(loadfile("Core/Require.lua")), env)("SkillUpForever", addon)
	return addon, lines
end

local broken, lines = Require(nil)
assert(broken.broken == true, "a missing ForeverCore stops the addon")
assert(#lines == 1 and lines[1].text:find("ForeverCore", 1, true), "and says so in one error line")
local old, oldLines = Require({ API = 0 })
assert(old.broken == true and #oldLines == 1, "a ForeverCore older than API 1 stops the addon too")
local noKit, noKitLines = Require({ API = 1 })
assert(noKit.broken == true and #noKitLines == 1, "one without the API kit stops it the same way")
local noSection, noSectionLines = Require({ API = 1, APIKit = {} })
assert(noSection.broken == true and #noSectionLines == 1, "one older than the tracker section API stops it too")
local noTabs, noTabsLines = Require({ API = 1, APIKit = {}, TrackerSection = {}, TrackerLine = {} })
assert(noTabs.broken == true and #noTabsLines == 1, "one older than the Professions tabs API stops it too")
local noWidth, noWidthLines = Require({
	API = 1,
	APIKit = {},
	TrackerSection = {},
	TrackerLine = {},
	ProfessionTabs = {},
})
assert(noWidth.broken == true and #noWidthLines == 1, "one older than ProfessionTabs.minor 1 stops it too")
local oldMinor, oldMinorLines = Require({
	API = 1,
	APIKit = {},
	TrackerSection = {},
	TrackerLine = {},
	ProfessionTabs = { minor = 0 },
})
assert(oldMinor.broken == true and #oldMinorLines == 1, "minor 0 has no SetMinWidth and stops it")
local ready, readyLines = Require({
	API = 1,
	APIKit = {},
	TrackerSection = {},
	TrackerLine = {},
	ProfessionTabs = { minor = 1 },
})
assert(ready.broken == nil, "API 1 with the kit and ProfessionTabs.minor 1 runs the addon")
assert(#readyLines == 0, "and says nothing")

print("core_dependency_spec: ok")
