-- Run from the repository root: luajit tests/core_dependency_spec.lua
-- SkillUp Forever requires ForeverCore. This spec covers the two places the handover is the addon's: the one-line
-- stop for a ForeverCore older than API 1, and the tracker settings the addon hands to the shared column once.
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

-- An out-of-date ForeverCore stops the addon's own files with one line in the error frame, never chat. Core's own
-- tests/forever_require_spec.lua holds the shared warning to its naming and plural rules; this spec loads it behind
-- Core/Require.lua's feature checks, which say which ForeverCore is too old for this addon.

-- The client's AddOns list: this addon and ForeverCore, both loaded. GetAddOnDependencies returns its names as
-- varargs, as the client does, not a table.
local function Addons()
	local entries = {
		{ "SkillUpForever", "SkillUp Forever", "v1.5.0", { "ForeverCore" } },
		{ "ForeverCore", "Forever Core", "v1.5.0", {} },
	}
	local function At(index)
		return entries[index]
	end
	return {
		GetNumAddOns = function()
			return #entries
		end,
		GetAddOnInfo = function(index)
			local entry = At(index)
			return entry and entry[1], entry and entry[2]
		end,
		IsAddOnLoaded = function(index)
			return At(index) ~= nil
		end,
		GetAddOnEnableState = function(index)
			return At(index) and 2 or 0
		end,
		GetAddOnDependencies = function(index)
			local entry = At(index)
			if entry then
				return unpack(entry[4])
			end
		end,
		GetAddOnMetadata = function(addon, field)
			for _, entry in ipairs(entries) do
				if entry[1] == addon then
					if field == "Title" then
						return entry[2]
					elseif field == "X-Forever-Core" then
						return entry[3]
					end
				end
			end
		end,
	}
end

local function Require(foreverCore)
	local lines = {}
	local env = {
		UIErrorsFrame = {
			AddMessage = function(_, text, red, green, blue)
				lines[#lines + 1] = { text = text, red = red, green = green, blue = blue }
			end,
		},
		C_AddOns = Addons(),
		ForeverCore = foreverCore,
		UnitName = function()
			return "Tester"
		end,
	}
	env._G = env
	setmetatable(env, { __index = _G })
	local addon = {}
	-- The TOC loads the shared warning before the addon's own Require, which calls it.
	setfenv(assert(loadfile("Core/ForeverRequire.lua")), env)("SkillUpForever", addon)
	setfenv(assert(loadfile("Core/Require.lua")), env)("SkillUpForever", addon)
	return addon, lines
end

-- The API kit arrived after API 1: Core/API.lua builds this addon's own API on its Hub and NotReady.
local broken, lines = Require({ TrackerSection = {}, TrackerLine = {} })
assert(broken.broken == true, "a ForeverCore without the API kit stops the addon")
assert(#lines == 1, "and the shared warning says so in one error line")
assert(lines[1].text == "SkillUp Forever could not start. Reinstall SkillUp Forever to fix this.", lines[1].text)

-- A missing core stops it too; the game normally refuses to load the addon first.
local missing, missingLines = Require(nil)
assert(missing.broken == true, "a missing ForeverCore stops the addon")
assert(#missingLines == 1, "and the shared warning says so in one error line")

-- The tracker section and line arrived after API 1 as well, and UI/Shopping.lua builds on both.
local noSection, noSectionLines = Require({ APIKit = { Hub = function() end, NotReady = function() end } })
assert(noSection.broken == true, "a ForeverCore without the tracker section API stops the addon")
assert(#noSectionLines == 1, "and the shared warning says so in one error line")

-- The Professions tabs arrived in ForeverCore 1.4.0, SetMinWidth in 1.5.0 and minor 2 (native page hidden beneath
-- SkillUp's) in 1.8.1: UI/Pages.lua and UI/RecipeList.lua call both, and the addon's page needs the native one gone.
local noWidth, noWidthLines = Require({
	APIKit = { Hub = function() end, NotReady = function() end },
	TrackerSection = { Create = function() end },
	TrackerLine = { SetInteractive = function() end },
	ProfessionTabs = { Register = function() end, minor = 2 },
})
assert(noWidth.broken == true, "a ForeverCore without ProfessionTabs.SetMinWidth stops the addon")
assert(#noWidthLines == 1, "and the shared warning says so in one error line")

-- A core with both members but minor 1 leaves the client's own page showing beneath SkillUp's.
local oldTabs, oldTabsLines = Require({
	APIKit = { Hub = function() end, NotReady = function() end },
	TrackerSection = { Create = function() end },
	TrackerLine = { SetInteractive = function() end },
	ProfessionTabs = { Register = function() end, SetMinWidth = function() end, minor = 1 },
})
assert(oldTabs.broken == true, "a ForeverCore with ProfessionTabs minor 1 stops the addon")
assert(#oldTabsLines == 1, "and the shared warning says so in one error line")

-- Every member this addon calls is there: the addon runs and says nothing.
local ready, readyLines = Require({
	APIKit = { Hub = function() end, NotReady = function() end },
	TrackerSection = { Create = function() end },
	TrackerLine = { SetInteractive = function() end },
	ProfessionTabs = { Register = function() end, SetMinWidth = function() end, minor = 2 },
})
assert(ready.broken == nil, "a core with every member the addon calls runs it")
assert(#readyLines == 0, "and says nothing")

print("core_dependency_spec: ok")
