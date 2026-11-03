-- Own-character observations and their thin adapter to Core's bounded peer protocol.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local c = Client.load({ saved = { learned = { ["Tester-Realm"] = { [3275] = true } } } })
local ns, G = c.ns, c.G
local sent = {}
G.IsInGuild = function()
	return true
end
G.C_ChatInfo = {
	SendAddonMessage = function(_, payload, channel)
		sent[#sent + 1] = { payload = payload, channel = channel }
		return 0
	end,
}

local function Own(client)
	for _, row in ipairs(client.ns.Stats.Board()) do
		if row.self then
			return row.value
		end
	end
end

local function Scan()
	c.Fire("TRADE_SKILL_LIST_UPDATE")
	c.Advance(0)
end

local function Receive(sender, value, addon, subject)
	local payload = ("1|%s|recipes_observed_learned|%s|%s|%d"):format(
		addon or "skillup",
		subject or "all",
		tostring(value),
		G.GetServerTime()
	)
	c.Fire("CHAT_MSG_ADDON", "WFAStats", payload, "GUILD", sender)
end

equal(ns.db.statsShare, true, "new participation defaults on")
equal(Own(c), 0, "old learned flags are not new observations")
c.live[3275] = { info = { learned = true } }
c.live[3276] = { info = { learned = true } }
c.Fire("TRADE_SKILL_LIST_UPDATE")
c.Fire("NEW_RECIPE_LEARNED")
c.Advance(0)
equal(Own(c), 2, "the own-character scan counts distinct learned IDs")
equal(#sent, 1, "the complete scan offers one snapshot")
equal(sent[1].channel, "GUILD", "only the available guild channel")
equal(sent[1].payload:find("|all|2|", 1, true) ~= nil, true, "the snapshot is the final count")
Scan()
equal(Own(c), 2, "repeated events and scans do not add recipes")
equal(#sent, 1, "unchanged observations do not resend")

c.live[3275].info.learned = false
Scan()
equal(Own(c), 2, "forgetting a recipe keeps the observation")
c.live[3275].info.learned = true
Scan()
equal(Own(c), 2, "relearning cannot count the same ID twice")

G.C_TradeSkillUI.IsTradeSkillLinked = function()
	return true
end
c.live[3277] = { info = { learned = true } }
Scan()
equal(Own(c), 2, "linked recipes are another character's observations")
G.C_TradeSkillUI.IsTradeSkillLinked = function()
	return false
end
G.C_TradeSkillUI.IsTradeSkillGuild = function()
	return true
end
Scan()
equal(Own(c), 2, "guild recipe views cannot inflate the score")
G.C_TradeSkillUI.IsTradeSkillGuild = function()
	return false
end

Receive("Zulu-Realm", 8)
Receive("Alpha-Realm", 8)
local board = ns.Stats.Board()
equal(#board, 3, "reported guild rows join the personal row")
equal(board[1].name, "Alpha", "equal totals have deterministic name order")
equal(board[3].self, true, "the personal row remains present")
Receive("Foreign-Realm", 99, "agf")
Receive("Bad-Realm", "nan")
Receive("WrongSubject-Realm", 99, nil, "3275")
equal(#ns.Stats.Board(), 3, "foreign, malformed and wrong-subject rows are ignored")

Scan()
equal(Own(c), 3, "a new own-character ID is counted")
ns.Stats.Observe(3278)
local before = #sent
c.SetSetting("statsShare", false)
equal(#ns.Stats.Board(), 1, "turning sharing off hides cached peers immediately")
Receive("Hidden-Realm", 100)
c.Advance(10)
equal(#sent, before, "opt-out cancels queued sends and a pending scan offer")
equal(Own(c), 4, "opt-out keeps local observations")
ns.Stats.Observe(3279)
c.Advance(0)
equal(Own(c), 5, "local observations continue while sharing is off")
equal(#sent, before, "observing locally cannot send while disabled")
c.SetSetting("statsShare", true)
c.Advance(10)
equal(#ns.Stats.Board(), 3, "re-enable restores cached peers without the rejected hidden row")
equal(#sent > before, true, "re-enable shares the latest local total")
equal(ns.Stats.Observe(0), false, "invalid recipe IDs are not observations")
equal(ns.Stats.Observe(math.huge), false, "infinite recipe IDs are not observations")

c.player.name = "Alt"
equal(Own(c), 0, "an alt does not inherit the first character's score")
equal(#ns.Stats.Board(), 1, "peer cache belongs to the character too")
ns.Stats.Observe(3275)
equal(Own(c), 1, "the alt has its own distinct observations")
c.player.name = "Tester"
equal(Own(c), 5, "switching back restores the original character's history")

local saved = G.SkillUpForeverDB
saved.statsShare = false
local reloaded = Client.load({ saved = saved })
equal(Own(reloaded), 5, "reload restores the deduplicated score")
equal(reloaded.ns.db.statsShare, false, "reload preserves a saved opt-out")
equal(#reloaded.ns.Stats.Board(), 1, "reload with sharing off hides cached peers")
reloaded.G.SlashCmdList.SKILLUPFOREVER("leaderboard")
equal(reloaded.chat[1]:find("observed learned", 1, true) ~= nil, true, "the label describes observations")
equal(reloaded.chat[#reloaded.chat]:find("Sharing is off", 1, true) ~= nil, true, "chat exposes participation")
reloaded.live[3275] = { info = { learned = true } }
reloaded.Fire("TRADE_SKILL_LIST_UPDATE")
reloaded.Advance(0)
equal(Own(reloaded), 5, "the same recipe observed after reload still counts once")
reloaded.G.SlashCmdList.SKILLUPFOREVER("share on")
equal(reloaded.ns.db.statsShare, true, "the slash command updates the setting")
reloaded.G.SlashCmdList.SKILLUPFOREVER("share off")
equal(reloaded.ns.db.statsShare, false, "the slash command preserves an explicit opt-out")
equal(#reloaded.ns.Stats.Board(), 1, "the slash command hides peers immediately")
reloaded.ns.Stats = nil
equal(pcall(reloaded.G.SlashCmdList.SKILLUPFOREVER, "leaderboard"), true, "missing update files are safe")

Client.report("stats_spec")
