-- Run from the repository root: luajit tests/live_scan_spec.lua
-- Issue #958: the open window's recipe list is read a chunk a frame, so opening the Professions window does
-- not spend the whole list in one tick, and a burst of list events during a scan joins the one in flight.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local c = Client.load()
local ns = c.ns

-- Let start-up's own timers settle, then hold the next frame's timers so each queued chunk is a frame.
c.Advance(0)
local later = c.G.C_Timer.After
local queued = {}
c.G.C_Timer.After = function(delay, fn)
	if delay == 0 then
		queued[#queued + 1] = fn
	else
		later(delay, fn)
	end
end
local inFrame = false
local function Frame()
	inFrame = true
	local due, fresh = queued, {}
	queued = fresh
	for _, fn in ipairs(due) do
		fn()
	end
	inFrame = false
	return #due
end

local FIRST, COUNT, CHUNK = 900000, 500, 64
local ids = {}
for index = 1, COUNT do
	local recipeID = FIRST + index
	ids[index] = recipeID
	c.live[recipeID] = {
		info = { learned = true, maxTrivialLevel = 300, numSkillUps = 1, relativeDifficulty = 1 },
	}
end

local reads = 0
local realInfo = c.G.C_TradeSkillUI.GetRecipeInfo
c.G.C_TradeSkillUI.GetRecipeInfo = function(recipeID)
	reads = reads + 1
	return realInfo(recipeID)
end
local function Populated()
	local count = 0
	for _, recipeID in ipairs(ids) do
		if ns.LiveRecipes[recipeID] then
			count = count + 1
		end
	end
	return count
end

-- One open: the event schedules the scan, the first frame reads one chunk, and the rest follow frame by frame.
c.Fire("TRADE_SKILL_LIST_UPDATE")
equal(reads, 0, "the event itself reads no recipe")
equal(Frame() > 0, true, "the scan waits for the next frame")
equal(reads, CHUNK, "the first frame reads one chunk")
equal(Populated(), CHUNK, "and keeps that chunk's live recipes")
equal(Frame() > 0, true, "the next chunk follows on the following frame")
equal(reads, CHUNK * 2, "for another chunk only")
while Frame() > 0 do
end
equal(reads, COUNT, "every recipe is read once the chunks finish")
equal(Populated(), COUNT, "and every live recipe is kept")

-- An event during a scan owes exactly one follow-up pass, which reads the list again rather than the
-- event being lost; a burst collapses into that one pass instead of one scan per event.
reads = 0
local lists = 0
local realAll = c.G.C_TradeSkillUI.GetAllRecipeIDs
c.G.C_TradeSkillUI.GetAllRecipeIDs = function()
	if inFrame then
		lists = lists + 1
	end
	return realAll()
end
c.Fire("TRADE_SKILL_LIST_UPDATE")
Frame()
equal(reads, CHUNK, "the second scan starts with one chunk")
equal(lists, 1, "and reads the list once")
for _ = 1, 5 do
	c.Fire("TRADE_SKILL_LIST_UPDATE")
end
while Frame() > 0 do
end
equal(lists, 2, "the events during the scan owe exactly one more pass")
equal(reads, COUNT * 2, "and that follow-up reads the whole list again")
c.G.C_TradeSkillUI.GetAllRecipeIDs = realAll

Client.report("live_scan_spec")
