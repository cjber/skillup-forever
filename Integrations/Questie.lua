---@type string, SkillUpNamespace
local _, ns = ...

-- QuestieDB, read at runtime through its public tables: who sells or drops an item and which quests reward
-- it, where an NPC stands and whose side it is on, and what a quest is called. Nothing of it is bundled.

local ADDON = "QuestieDB"
-- The contract this file was written against. QuestieDB accepts a range, so a newer additive release keeps
-- working; a removed field is caught by Fit.
local CONTRACT = 2
-- Questie can load and never report ready. Past this the database is read as it stands; a ready callback
-- that arrives later reads it again.
local READY_WAIT = 60
local FIELDS = {
	Item = { "vendors", "questRewards", "npcDrops", "class", "teachesSpell" },
	Npc = { "name", "spawns", "zoneID", "friendlyToFaction" },
	Quest = { "requiredRaces", "name" },
}
local RECIPE_CLASS = 9
-- ChrRaces bits: Human, Dwarf, Night Elf, Gnome; Orc, Undead, Tauren, Troll.
local ALLIANCE_RACES, HORDE_RACES = 77, 178
-- friendlyToFaction as the side that can deal with the NPC; hostile to both is nil.
local SIDES = { A = "A", H = "H", AH = "" }

---@class SkillUpQuestie
local Q = {}
ns.Questie = Q

---@type SkillUpQuestieDB?
local lib
---@type SkillUpQuestieZones?
local zones
---@type SkillUpProviderState
local state = "missing"

-- One of ZoneDB's tables, which QuestieDB keeps as Lua source: run with no globals, since it is only a
-- table literal.
---@param source any
---@return table?
local function Table(source)
	local chunk = type(source) == "string" and loadstring(source)
	if not chunk then
		return nil
	end
	setfenv(chunk, {})
	local ok, value = pcall(chunk)
	return ok and type(value) == "table" and value or nil
end

-- QuestieDB as this file reads it, with its zone tables; nil when it is absent or not the one written for.
---@return SkillUpQuestieDB?
---@return SkillUpQuestieZones?
local function Fit()
	local db = LibQuestieDB
	if type(db) ~= "table" or type(db.RequireContract) ~= "function" then
		return nil
	end
	local called, fits = pcall(db.RequireContract, CONTRACT)
	if not (called and fits) or C_AddOns.GetAddOnMetadata(ADDON, "X-Flavor") ~= "Forever" then
		return nil
	end
	for name, fields in pairs(FIELDS) do
		local meta = type(db.Meta) == "table" and db.Meta[name .. "Meta"]
		local keys, reader = meta and meta[name:lower() .. "Keys"], db[name]
		if type(keys) ~= "table" or type(reader) ~= "table" or type(reader.GetAll) ~= "function" then
			return nil
		end
		for _, field in ipairs(fields) do
			if not keys[field] then
				return nil
			end
		end
	end
	local zoneDB = type(db.Support) == "table" and db.Support.Get("ZoneDB")
	local private = type(zoneDB) == "table" and zoneDB.private
	if type(private) ~= "table" or type(db.Item.GetAllIds) ~= "function" then
		return nil
	end
	local area, parent = Table(private.areaIdToUiMapId), Table(private.subZoneToParentZone)
	if not (area and parent) then
		return nil
	end
	return db,
		{
			area = area,
			areaOverride = Table(private.areaIdToUiMapIdOverride) or {},
			parent = parent,
			parentOverride = Table(private.subZoneToParentZoneOverride) or {},
		}
end

local function Settle()
	lib, zones = Fit()
	state = lib and "ready" or (type(LibQuestieDB) == "table" and "unfit" or "missing")
end

-- "missing" without QuestieDB, "unfit" when it is not the one this was written for, "waiting" until Questie
-- has finished its own start, then "ready".
---@return SkillUpProviderState
function Q.State()
	return state
end

-- Looks for QuestieDB and calls `onReady` each time it becomes readable. Safe to call again while it is
-- missing: an addon that loads later is picked up.
---@param onReady fun()
function Q.Start(onReady)
	if state ~= "missing" or type(LibQuestieDB) ~= "table" then
		return
	end
	local api = type(Questie) == "table" and Questie.API
	if type(api) == "table" and type(api.RegisterOnReady) == "function" then
		state = "waiting"
		api.RegisterOnReady(function()
			Settle()
			if state == "ready" then
				onReady()
			end
		end)
		C_Timer.After(READY_WAIT, function()
			if state == "waiting" then
				Settle()
				if state == "ready" then
					onReady()
				end
			end
		end)
		return
	end
	Settle()
	if state == "ready" then
		onReady()
	end
end

-- QuestieDB's ID lists are shared and read-only: a sorted copy of the numbers in one.
---@param ids any
---@return integer[]
local function IDs(ids)
	local copy = {}
	for _, id in ipairs(type(ids) == "table" and ids or {}) do
		if type(id) == "number" then
			copy[#copy + 1] = id
		end
	end
	table.sort(copy)
	return copy
end

-- Who sells an item, the quests that reward it, who drops it, and the recipe it teaches when it is a scroll.
---@param itemID integer
---@return SkillUpItemSources?
function Q.Item(itemID)
	local values = lib and lib.Item.GetAll(itemID, FIELDS.Item)
	if not values then
		return nil
	end
	local teaches = values[4] == RECIPE_CLASS and tonumber(values[5]) or 0
	return {
		vendors = IDs(values[1]),
		quests = IDs(values[2]),
		drops = IDs(values[3]),
		teaches = teaches > 0 and teaches or nil,
	}
end

-- Every item QuestieDB knows: its own shared list, never to be written to.
---@return integer[]
function Q.ItemIDs()
	return lib and lib.Item.GetAllIds() or {}
end

-- An area's zone map, or its parent zone's.
---@param area integer
---@return integer?
local function Map(area)
	if not zones then
		return nil
	end
	local map = zones.areaOverride[area] or zones.area[area]
	local parent = not map and (zones.parentOverride[area] or zones.parent[area])
	map = map or (parent and (zones.areaOverride[parent] or zones.area[parent]))
	return type(map) == "number" and map or nil
end

-- One spawn to point at: in the NPC's usual area when it spawns there (else its lowest area), the spawn
-- nearest the middle of that area's spawns. QuestieDB gives 0-100 on the area's map; a spawn inside a
-- dungeon has no map point (-1, -1), so only its area is kept.
---@param spawns any
---@param home any
---@return integer? area
---@return number? x
---@return number? y
local function Spawn(spawns, home)
	if type(spawns) ~= "table" then
		return nil
	end
	local area = type(spawns[home]) == "table" and home or nil
	if not area then
		for candidate in pairs(spawns) do
			if type(candidate) == "number" and (not area or candidate < area) then
				area = candidate
			end
		end
	end
	local spots, sumX, sumY = {}, 0, 0
	for _, xy in ipairs(area and type(spawns[area]) == "table" and spawns[area] or {}) do
		local x, y = tonumber(xy[1]), tonumber(xy[2])
		if x and y and x >= 0 and x <= 100 and y >= 0 and y <= 100 then
			spots[#spots + 1] = { x, y }
			sumX, sumY = sumX + x, sumY + y
		end
	end
	local best, bestDistance
	for _, spot in ipairs(spots) do
		local distance = (spot[1] - sumX / #spots) ^ 2 + (spot[2] - sumY / #spots) ^ 2
		if not bestDistance or distance < bestDistance then
			best, bestDistance = spot, distance
		end
	end
	if not best then
		return area
	end
	return area, best[1] / 100, best[2] / 100
end

-- An NPC's name, the side that can deal with it, and where it stands: a zone map position in 0-1, or only
-- its area when it is in a dungeon.
---@param npcID integer
---@return SkillUpSourceNPC?
function Q.NPC(npcID)
	local values = lib and lib.Npc.GetAll(npcID, FIELDS.Npc)
	if not (values and type(values[1]) == "string") then
		return nil
	end
	local npc = { name = values[1], side = SIDES[values[4]] }
	local area, x, y = Spawn(values[2], values[3])
	local map = area and x and Map(area)
	if map then
		npc.map, npc.x, npc.y = map, x, y
	else
		npc.area = area
	end
	return npc
end

-- A quest's title and the side that may take it ("" for both).
---@param questID integer
---@return SkillUpSourceQuest?
function Q.Quest(questID)
	local values = lib and lib.Quest.GetAll(questID, FIELDS.Quest)
	if not (values and type(values[2]) == "string") then
		return nil
	end
	local races = tonumber(values[1]) or 0
	local alliance, horde = bit.band(races, ALLIANCE_RACES) ~= 0, bit.band(races, HORDE_RACES) ~= 0
	return { title = values[2], side = alliance == horde and "" or alliance and "A" or "H" }
end
