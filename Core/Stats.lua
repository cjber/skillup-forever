---@type string, SkillUpNamespace
local _, ns = ...

if ns.broken then
	return
end

-- Distinct own-character recipe observations, independent of recipes currently known. A profession drop never
-- erases these observations. No old learned flag is treated as a newly observed learning event.
---@class SkillUpStats
local Stats = {}
ns.Stats = Stats

local METRIC = "recipes_observed_learned"
local TAB_ICON = "Interface\\Icons\\Trade_BlackSmithing"
local cached, count, pending = nil, 0, false

local function Character()
	return ns.db and ns.CharacterKey()
end

local function Record()
	local key = Character()
	if not key then
		return nil
	end
	local record = ns.db.observedRecipes[key]
	if type(record) ~= "table" or type(record.ids) ~= "table" then
		record = { ids = {}, eventUnix = 0 }
		ns.db.observedRecipes[key] = record
	end
	if cached ~= record then
		count = 0
		for id, seen in pairs(record.ids) do
			if type(id) == "number" and id > 0 and id < math.huge and id % 1 == 0 and seen == true then
				count = count + 1
			else
				record.ids[id] = nil
			end
		end
		local stamp = record.eventUnix
		if type(stamp) ~= "number" or stamp < 1 or stamp % 1 ~= 0 or stamp > GetServerTime() + 300 then
			record.eventUnix = 0
		end
		cached = record
	end
	return record
end

local function Enabled()
	return ns.db ~= nil and ns.db.statsShare ~= false
end

local peer = ForeverCore.PeerStats.New({
	addon = "skillup",
	safeCall = ns.core.SafeCall,
	enabled = Enabled,
	db = function()
		local key = Character()
		if key then
			if type(ns.db.peerStats[key]) ~= "table" then
				ns.db.peerStats[key] = {}
			end
			return ns.db.peerStats[key]
		end
	end,
	snapshot = function()
		local record = Record()
		return record
				and count > 0
				and record.eventUnix > 0
				and { { metric = METRIC, subject = "all", value = count, eventUnix = record.eventUnix } }
			or {}
	end,
	metrics = { [METRIC] = { subject = "all" } },
})

-- Each scan can observe hundreds of recipes; offer its final total once on the next frame.
local function Schedule()
	if pending then
		return
	end
	pending = true
	C_Timer.After(0, function()
		pending = false
		peer:Sync()
	end)
end

---@param recipeID integer
---@return boolean
function Stats.Observe(recipeID)
	if type(recipeID) ~= "number" or recipeID <= 0 or recipeID >= math.huge or recipeID % 1 ~= 0 then
		return false
	end
	local record = Record()
	if not record or record.ids[recipeID] then
		return false
	end
	record.ids[recipeID] = true
	record.eventUnix = GetServerTime()
	count = count + 1
	Schedule()
	return true
end

function Stats.SetEnabled(enabled)
	peer:SetEnabled(enabled == true)
end

-- Whether this character shares and shows peer totals, the switch the public API reports as `sharing`.
---@return boolean
function Stats.Sharing()
	return Enabled()
end

-- The current character's total, which both boards measure from.
local function Local()
	local record = Record()
	return record and count or 0, record and record.eventUnix
end

function Stats.Board()
	local value, unix = Local()
	return peer:Board(METRIC, "all", value, unix)
end

function Stats.WeekBoard()
	local value, unix = Local()
	return peer:WeekBoard(METRIC, "all", value, unix)
end

---@return integer
function Stats.Revision()
	return peer:Revision()
end

-- One row per ranked player, in the shared window's shape. The all-time board keeps the cumulative total in the value
-- column; the weekly board draws the progress since the reset there and the cumulative total in grey.
---@param scope ForeverLeaderboardsScope
---@return ForeverLeaderboardsRow[]
local function Board(scope)
	local weekly = scope == "week"
	local ranked = weekly and Stats.WeekBoard() or Stats.Board()
	local totals
	if weekly then
		totals = {}
		for _, row in ipairs(Stats.Board()) do
			totals[row.identity] = row.value
			totals[row.name:lower()] = row.value
		end
	end
	local rows = {}
	for _, row in ipairs(ranked) do
		local total = totals and (totals[row.identity] or totals[row.name:lower()])
		rows[#rows + 1] = {
			name = row.name,
			value = row.value,
			extra = total and (total .. " " .. ns.L["total"]) or nil,
			you = row.self == true,
		}
	end
	return rows
end

--- Open Forever Leaderboards on this addon's tab.
function Stats.Open()
	ForeverCore.Leaderboards:Open("skillup")
end

ns.WhenEvent("PLAYER_LOGIN", Schedule)

ForeverCore.Leaderboards:Register("skillup", {
	title = ns.TITLE,
	icon = TAB_ICON,
	metric = ns.L["Recipes observed"],
	board = Board,
	revision = Stats.Revision,
	sharing = Enabled,
	setSharing = function(shared)
		Settings.SetValue("SkillUpForever_statsShare", shared == true)
	end,
	safeCall = ns.core.SafeCall,
})
