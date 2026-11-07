-- This addon's board in the shared Forever Leaderboards window, against the stub client.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local c = Client.load({ saved = { learned = { ["Tester-Realm"] = { [3275] = true } } } })
local ns, G = c.ns, c.G
G.IsInGuild = function()
	return true
end
G.C_ChatInfo = {
	SendAddonMessage = function() end,
}

local spec = ns.Leaderboards and ns.Leaderboards.boards.skillup
equal(spec ~= nil, true, "the shared window has this addon's board")
equal(spec.title, "SkillUp Forever", "the tab carries the addon's title")
equal(spec.icon, "Interface\\Icons\\Trade_BlackSmithing", "the tab wears the game's blacksmithing icon")
equal(spec.metric, "Recipes observed", "the heading names the metric")
equal(spec.sharing(), true, "sharing is on unless saved off")
equal(type(spec.revision()), "number", "the revision is a number")

-- Old learned flags are not observations; a scan makes two.
local rows = spec.board("all")
equal(#rows, 1, "only the player's own row before anyone reports")
equal(rows[1].name, "Tester", "the own row carries the player's name")
equal(rows[1].you, true, "the own row is marked as you")
equal(rows[1].class, nil, "the board leaves class to the shared window")
equal(rows[1].value, 0, "old learned flags do not count")
c.live[3275] = { info = { learned = true } }
c.live[3276] = { info = { learned = true } }
c.Fire("TRADE_SKILL_LIST_UPDATE")
c.Fire("NEW_RECIPE_LEARNED")
c.Advance(0)
rows = spec.board("all")
equal(rows[1].value, 2, "the board shows the observed total")
local revision = spec.revision()

-- The weekly board measures from the first value heard this week.
local week = spec.board("week")
equal(week[1].value, 0, "the first weekly read is the baseline")
ns.Stats.Observe(3277)
c.Advance(0)
week = spec.board("week")
equal(week[1].value, 1, "the weekly board counts what changed since the baseline")
equal(spec.revision() > revision, true, "an observation moves the revision")

-- A reported peer joins with the same row shape.
local function Receive(sender, value)
	local payload = ("1|skillup|recipes_observed_learned|all|%d|%d"):format(value, G.GetServerTime())
	c.Fire("CHAT_MSG_ADDON", "WFAStats", payload, "GUILD", sender)
end
Receive("Alpha-Realm", 9)
rows = spec.board("all")
local alpha
for _, row in ipairs(rows) do
	if row.name == "Alpha" then
		alpha = row
	end
end
equal(alpha ~= nil, true, "a reported peer joins the board")
equal(alpha.you, false, "a peer row is not you")
equal(alpha.class, nil, "a peer's class is unknown")
equal(alpha.value, 9, "a peer row carries its total")

-- The window's switch writes the addon's own saved setting.
spec.setSharing(false)
equal(ns.db.statsShare, false, "the window's switch saves an opt-out")
equal(#spec.board("all"), 1, "an opt-out hides peers")
spec.setSharing(true)
equal(ns.db.statsShare, true, "the window's switch saves sharing on")
equal(#spec.board("all"), 2, "sharing on shows peers again")

-- The slash command opens this addon's tab.
local opened
ns.Leaderboards = {
	Open = function(_, key)
		opened = key
	end,
}
G.SlashCmdList.SKILLUPFOREVER("leaderboard")
equal(opened, "skillup", "the slash command opens the skillup tab")

Client.report("leaderboards_integration_spec")
