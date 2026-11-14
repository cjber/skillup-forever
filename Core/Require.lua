local _, ns = ...

-- The game refuses to load this addon when ForeverCore is absent (## Dependencies), but an older ForeverCore still
-- loads. Its API version stays at 1 while it adds members, so a core is out of date when a member this addon calls is
-- missing, never because of a version comparison.
--
-- API 1 has the report window, the tracker host, the family suggestions, the map, settings and context menu openers,
-- all of which this addon calls. The API kit arrived after it
-- (ForeverCore 1.1.0) and Core/API.lua builds this addon's own API on its Hub and NotReady. Publishing to the suite's
-- list (APIKit.Publish) is guarded by the kit's minor, so an older kit is not a reason to stop. The tracker section
-- and line arrived after it too (ForeverCore 1.2.0): UI/Shopping.lua builds its section with Section.Create and makes
-- its lines clickable with Line.SetInteractive. UI/Pages.lua registers the Professions side tab with
-- ProfessionTabs.Register (ForeverCore 1.4.0) and UI/RecipeList.lua sizes the window with ProfessionTabs.SetMinWidth
-- (ForeverCore 1.5.0). ProfessionTabs minor 2 (ForeverCore 1.8.1) hides the client's page beneath SkillUp's, so an
-- older core leaves this addon's page over the native one and the addon stops.
--
-- The warning itself is Core/ForeverRequire.lua, shared by every Forever addon: one line on screen, never a chat
-- message, naming the addon to update and never ForeverCore.
local ready = ForeverCore ~= nil
	and type(ForeverCore.APIKit) == "table"
	and type(ForeverCore.APIKit.Hub) == "function"
	and type(ForeverCore.APIKit.NotReady) == "function"
	and type(ForeverCore.TrackerSection) == "table"
	and type(ForeverCore.TrackerSection.Create) == "function"
	and type(ForeverCore.TrackerLine) == "table"
	and type(ForeverCore.TrackerLine.SetInteractive) == "function"
	and type(ForeverCore.ProfessionTabs) == "table"
	and type(ForeverCore.ProfessionTabs.Register) == "function"
	and type(ForeverCore.ProfessionTabs.SetMinWidth) == "function"
	and (tonumber(ForeverCore.ProfessionTabs.minor) or 0) >= 2

ns.ForeverRequire(ready)
