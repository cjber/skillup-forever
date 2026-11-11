-- Run from the repository root: luajit tests/shopping_tracker_anchor_spec.lua
-- The reagent section's place in the column is ForeverCore's now: core builds the section, attaches it after the world
-- loads and owns wherever it hangs. This holds SkillUp to the parts that stay its own: its rows, the
-- old tracker table offered once and the failures core records for the section.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local c = Client.load({
	saved = {
		trackedProfessions = { [129] = true },
		-- SkillUp's own tracker table from before Forever Core kept the column.
		trackerHost = { scale = 1.5, locked = true },
	},
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

-- ForeverCore's TrackerSection.Create built it from the game's module template, mixed SkillUp's rows in and set the
-- header. The section then waits for the world, exactly as core's own quest section does.
equal(module.template, "ObjectiveTrackerModuleTemplate", "core builds the section from the game's template")
equal(module.headerText, "Profession reagents", "with SkillUp's header")
equal(module.uiOrder, nil, "no permanent uiOrder pin is kept")
equal(module.safeCall, ns.core.SafeCall, "the section's failures go to SkillUp's journal")
equal(c.host.IsAttached(module), false, "the section waits for the world to load")
c.EnterWorld()
c.Advance(0)
equal(c.host.IsAttached(module), true, "then joins the shared column")
equal(ns.db.trackerHost, nil, "the old tracker table is offered once, then dropped")
local settings = c.G.ForeverCoreDB.trackerHost
equal(settings.migrated, true, "core marks the copy done")
equal(settings.scale, 1.5, "and keeps the scale the player chose")
equal(settings.locked, true, "and its Lock")

-- One tracked profession with no training step and no missing reagent, so every layout says it is ready. The
-- point here is the section, not the route.
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

-- The addon reads no anchor of its own and re-attaches nothing: a host that answers "not attached" cannot stop the
-- rows, since only core decides where the section hangs and when it is laid out.
local host = c.G.ForeverCore.TrackerHost
c.G.ForeverCore.TrackerHost = {
	Attach = function() end,
	IsAttached = function()
		return false
	end,
}
equal(#c.Tracker(), 1, "the rows are laid out with no anchor of the addon's")
equal(ns.TrackerAttached(), false, "and the attachment answer is core's")
c.G.ForeverCore.TrackerHost = host
equal(ns.TrackerAttached(), true, "the section is still in the column")

-- The section's visibility stays SkillUp's own Options setting: the column offers no Hide this section entry for it,
-- as before the move to core.
equal(module.show, nil, "the section passes no show switch to the column")

-- Core's default CanUpdate holds the layout in combat, where moving a protected frame is refused.
equal(module.CanUpdate(), true, "the section lays itself out out of combat")
c.combat = true
equal(module.CanUpdate(), false, "and holds its last layout in combat")
c.combat = false

-- A layout error is core's to record: the section stays in the column and nothing is printed in chat. Before the
-- move this file caught the error itself, printed a line and hid the section.
c.allowErrors = true
local before = #c.chat
ns.TrackedNeeds = function()
	return { { items = {} } } -- no plan: LayoutEntry raises on its first read
end
local caught = 0
for _, entry in ipairs(ns.core.CaughtErrors()) do
	if entry.message:find("local 'plan'", 1, true) then
		caught = caught + 1
	end
end
equal(module.safeCall("tracker section update", module.Update, module, 500), false, "the failure is caught")
equal(#c.chat, before, "and nothing is printed on screen")
equal(c.host.IsAttached(module), true, "the section stays in the column")
local recorded = 0
for _, entry in ipairs(ns.core.CaughtErrors()) do
	if entry.message:find("local 'plan'", 1, true) then
		recorded = recorded + 1
	end
end
equal(recorded, caught + 1, "and reaches SkillUp's journal once")
c.allowErrors = false

-- A section that never joins the column warns once, in the addon's own words: core calls onUnattached after a few
-- seconds, which is the one warning this file still owns.
local missing = Client.load()
local section = missing.G.SkillUpForeverObjectiveTracker
missing.EnterWorld()
missing.Advance(0)
-- The link to the column is core's, so the spec drops it before core's few seconds are up.
section.parentContainer = nil
missing.Advance(5)
local warnings = 0
for _, line in ipairs(missing.chat) do
	if line:find("couldn't add tracked reagents to the objective tracker", 1, true) then
		warnings = warnings + 1
	end
end
equal(warnings, 1, "a section that never attached says so once")

Client.report("shopping_tracker_anchor_spec")
