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

local cached, count = nil, 0

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
	return true
end

-- This character's locally observed recipe total.
function Stats.Local()
	local record = Record()
	return record and count or 0, record and record.eventUnix
end
