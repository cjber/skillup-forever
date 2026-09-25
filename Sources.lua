---@type string, SkillUpNamespace
local _, ns = ...
local L = ns.L

-- Where recipe scrolls come from (bundled from classic-db) and how to get there.

local FACTION_CODES = { Alliance = "A", Horde = "H" }

---@param faction string
---@return boolean
local function OurFaction(faction)
	return faction == "" or faction == FACTION_CODES[UnitFactionGroup("player")]
end

---@param npcID integer
---@return boolean
local function Usable(npcID)
	return OurFaction(ns.SourceNPCs[npcID][2])
end

---@param source SkillUpSource
---@param npcID integer
---@return boolean
local function Limited(source, npcID)
	return tContains(source.limited or {}, npcID)
end

-- Vendors of your faction, those that always have the scroll first.
---@param source SkillUpSource
---@param byTravel boolean?
---@return integer?
local function VendorFor(source, byTravel)
	local unlimited, limited = {}, {}
	for _, npcID in ipairs(source.vendors or {}) do
		table.insert(Limited(source, npcID) and limited or unlimited, npcID)
	end
	return ns.NearestNPC(unlimited, byTravel) or ns.NearestNPC(limited, byTravel)
end

---@param source SkillUpSource
---@return integer?
local function QuestFor(source)
	for _, questID in ipairs(source.quests or {}) do
		if OurFaction(ns.SourceQuests[questID][2]) then
			return questID
		end
	end
end

-- The zone map under a point of a continent map: the client's deepest map there,
-- walked up past any dungeon or micro map to its zone, else nil.
---@param continent integer
---@param x number
---@param y number
---@return UiMapDetails?
local function ZoneAt(continent, x, y)
	local info = C_Map.GetMapInfoAtPosition(continent, x, y)
	while info and info.mapType > Enum.UIMapType.Zone and info.parentMapID ~= 0 do
		info = C_Map.GetMapInfo(info.parentMapID)
	end
	return info and info.mapType == Enum.UIMapType.Zone and info or nil
end

-- The NPC's zone and zone map position, resolved by the client from its world spawn
-- so overlapping zone rectangles can't mislabel it; the continent's map when no zone
-- lies under it, and a dungeon has only its name.
---@param npcID integer
---@return SkillUpLocation
function ns.NPCLocation(npcID)
	local npc = ns.SourceNPCs[npcID]
	local name, map, x, y = npc[1], npc[3], npc[4], npc[5]
	local instance = ns.InstanceNames[map]
	if instance then
		return { name = name, label = instance }
	end
	local world = CreateVector2D(x, y)
	local uiMapID, position = C_Map.GetMapPosFromWorldPos(map, world)
	local info = uiMapID and C_Map.GetMapInfo(uiMapID)
	if not (info and position) then
		return { name = name, label = L["unknown location"] }
	end
	local zone = ZoneAt(uiMapID, position:GetXY()) -- multi-value: the continent x, y
	if zone then
		local zoneMapID, zonePosition = C_Map.GetMapPosFromWorldPos(map, world, zone.mapID)
		if zoneMapID == zone.mapID and zonePosition then
			uiMapID, position, info = zoneMapID, zonePosition, zone
		end
	end
	local px, py = position:GetXY()
	return { name = name, label = info.name, map = uiMapID, x = px, y = py }
end

---@param where SkillUpLocation
---@return string
function ns.LocationText(where)
	if where.map then
		return string.format("%s  %.0f, %.0f", where.label, where.x * 100, where.y * 100)
	end
	return where.label
end

-- UnitPosition's first value is the world's north axis, as classic-db's x is.
---@param npcID integer
---@return number
local function Distance(npcID)
	local px, py, _, instance = UnitPosition("player")
	local npc = ns.SourceNPCs[npcID]
	local map, x, y = npc[3], npc[4], npc[5]
	if not px or map ~= instance then
		return math.huge
	end
	return (px - x) ^ 2 + (py - y) ^ 2
end

-- Shortest Path Forever's public API, version 1, when it is loaded; callers still
-- check each function they use.
---@return SkillUpShortestPathAPI?
local function ShortestPath()
	local api = ShortestPathForever and ShortestPathForever.API
	return api and api.version == 1 and api or nil
end

-- How many of the straight-line nearest get a travel estimate: a cold one costs
-- Shortest Path Forever a few milliseconds.
local MAX_ESTIMATES = 6

---@return {map: integer, x: number, y: number}?
local function PlayerMapPosition()
	local map = C_Map.GetBestMapForUnit("player")
	local position = map and C_Map.GetPlayerMapPosition(map, "player")
	if not position then
		return nil
	end
	local x, y = position:GetXY()
	return { map = map, x = x, y = y }
end

-- Of these NPCs, the nearest this character can deal with (the other faction's
-- won't trade or train), else nil. With `byTravel` (a click or tooltip, never a
-- redraw) and Shortest Path Forever loaded, the straight-line nearest few are
-- ranked by its travel time instead, so a flight beats a walk around the coast.
---@param npcIDs integer[]
---@param byTravel boolean?
---@return integer?
function ns.NearestNPC(npcIDs, byTravel)
	local candidates = {}
	for index, npcID in ipairs(npcIDs) do
		if Usable(npcID) then
			candidates[#candidates + 1] = { npcID = npcID, distance = Distance(npcID), index = index }
		end
	end
	-- Ties (other continents are all infinitely far) keep the data's order.
	table.sort(candidates, function(a, b)
		if a.distance ~= b.distance then
			return a.distance < b.distance
		end
		return a.index < b.index
	end)
	local best = candidates[1]
	local api = byTravel and best and not InCombatLockdown() and ShortestPath()
	local from = api and type(api.Estimate) == "function" and PlayerMapPosition()
	if api and from then
		local bestSeconds
		for i = 1, math.min(#candidates, MAX_ESTIMATES) do
			local where = ns.NPCLocation(candidates[i].npcID)
			local seconds = where.map and api.Estimate(from.map, from.x, from.y, where.map, where.x, where.y)
			if seconds and (not bestSeconds or seconds < bestSeconds) then
				best, bestSeconds = candidates[i], seconds
			end
		end
	end
	return best and best.npcID
end

-- Shortest Path Forever's route when it takes one (it declines in combat, with its
-- journeys off or without a player position), else TomTom's arrow, else the map's
-- own waypoint, super-tracked; false when there is only a chat line to give.
---@param npcID integer
---@return boolean
function ns.SetWaypoint(npcID)
	local where = ns.NPCLocation(npcID)
	if not where.map then
		ns.Print(string.format(L["%s is in %s."], where.name, where.label))
		return false
	end
	local api = ShortestPath()
	if
		api
		and type(api.Navigate) == "function"
		and api.Navigate("SkillUpForever", where.map, where.x, where.y, where.name)
	then
		ns.Print(string.format(L["route set to %s, %s."], where.name, ns.LocationText(where)))
		return true
	end
	if TomTom and TomTom.AddWaypoint then
		TomTom:AddWaypoint(where.map, where.x, where.y, { title = where.name, from = "SkillUp Forever" })
	elseif C_Map.CanSetUserWaypointOnMap(where.map) then
		C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(where.map, where.x, where.y))
		C_SuperTrack.SetSuperTrackedUserWaypoint(true)
	else
		ns.Print(string.format(L["%s is at %s."], where.name, ns.LocationText(where)))
		return false
	end
	ns.Print(string.format(L["waypoint set to %s, %s."], where.name, ns.LocationText(where)))
	return true
end

-- Best way to get the scroll, easiest first: an unlimited vendor, a limited one,
-- a quest, a named drop, a world drop; nil when only the other faction sells it or
-- may take the quest.
---@param source SkillUpSource
---@return integer?
---@return integer?
local function Kind(source)
	local vendor = VendorFor(source)
	if vendor then
		return Limited(source, vendor) and 2 or 1, vendor
	elseif QuestFor(source) then
		return 3
	elseif source.drops then
		return 4, source.drops[1][1]
	elseif source.world then
		return 5
	end
end

-- Where a suggestion's click goes: the nearest vendor by travel when one sells the
-- scroll, else the likeliest drop.
---@param suggestion SkillUpSuggestion
---@return integer?
function ns.SuggestionNPC(suggestion)
	if suggestion.kind <= 2 then
		return VendorFor(suggestion.source, true)
	end
	return suggestion.npcID
end

local KIND_TEXT = { L["vendor"], L["limited vendor"], L["quest"], L["drop"], L["world drop"] }

-- Scroll recipes of this profession, not trainer-taught nor learned, that the
-- base skill behind `skill` (effective) can learn and that still skill up at
-- `skill`, easiest to get and then furthest-reaching first.
---@param profession SkillUpContext
---@param skill number
---@return SkillUpSuggestion[]
function ns.RecipeSuggestions(profession, skill)
	local base = skill - profession.modifier
	local found = {}
	for recipeID, source in pairs(ns.RecipeSources) do
		local recipe = ns.RecipeData[recipeID]
		local t = recipe and recipe.skillLine == profession.skillLine and ns.Model.Get(recipeID)
		if
			t
			and source.skill <= base
			and t[4] > skill
			and not ns.IsLearned(recipeID)
			and not ns.TrainingFor(profession, recipeID)
		then
			local kind, npcID = Kind(source)
			found[#found + 1] = kind
					and {
						recipeID = recipeID,
						source = source,
						kind = kind,
						kindText = KIND_TEXT[kind],
						npcID = npcID,
						reach = t[4],
					}
				or nil
		end
	end
	table.sort(found, function(a, b)
		if a.kind ~= b.kind then
			return a.kind < b.kind
		elseif a.reach ~= b.reach then
			return a.reach > b.reach
		end
		return a.recipeID < b.recipeID
	end)
	return found
end

-- The scroll's price: what it last sold for, else the vendor's.
---@param source SkillUpSource
---@return number?
function ns.ScrollPrice(source)
	local price = ns.Price(source.item)
	return price and price.copper or (source.price and source.price > 0 and source.price) or nil
end

---@param tooltip GameTooltip
---@param left string
---@param npcID integer
---@param suffix string?
---@param usable boolean
local function AddNPC(tooltip, left, npcID, suffix, usable)
	local where = ns.NPCLocation(npcID)
	GameTooltip_AddColoredDoubleLine(
		tooltip,
		left,
		where.name .. (suffix or ""),
		NORMAL_FONT_COLOR,
		usable and HIGHLIGHT_FONT_COLOR or RED_FONT_COLOR
	)
	GameTooltip_AddColoredDoubleLine(tooltip, " ", ns.LocationText(where), NORMAL_FONT_COLOR, GRAY_FONT_COLOR)
end

---@param tooltip GameTooltip
---@param source SkillUpSource
function ns.AddSourceLines(tooltip, source)
	for _, npcID in ipairs(source.vendors or {}) do
		AddNPC(tooltip, L["Sold by"], npcID, Limited(source, npcID) and "  " .. L["(limited)"] or nil, Usable(npcID))
	end
	for _, questID in ipairs(source.quests or {}) do
		local title, faction = unpack(ns.SourceQuests[questID])
		GameTooltip_AddColoredDoubleLine(
			tooltip,
			L["Quest"],
			title,
			NORMAL_FONT_COLOR,
			OurFaction(faction) and HIGHLIGHT_FONT_COLOR or RED_FONT_COLOR
		)
	end
	for _, drop in ipairs(source.drops or {}) do
		AddNPC(tooltip, L["Dropped by"], drop[1], string.format("  (%s%%)", drop[2]), true)
	end
	if source.world then
		GameTooltip_AddNormalLine(tooltip, L["World drop"])
	end
end

-- The nearest trainer of this profession, of your faction, who teaches up to `cap`.
---@param profession SkillUpContext
---@param cap number
---@param byTravel boolean?
---@return integer?
function ns.NearestTrainer(profession, cap, byTravel)
	local trainers = {}
	for _, row in ipairs(ns.ProfessionTrainers[profession.skillLine] or {}) do
		if row[2] >= cap then
			trainers[#trainers + 1] = row[1]
		end
	end
	return ns.NearestNPC(trainers, byTravel)
end

---@param itemID integer
---@param byTravel boolean?
---@return integer?
function ns.NearestVendor(itemID, byTravel)
	local vendors = ns.ReagentVendors[itemID]
	return vendors and ns.NearestNPC(vendors, byTravel)
end

local SHORTEST_PATH = "ShortestPathForever"

-- Under a waypoint click: what Shortest Path Forever would add, when it isn't running.
---@param tooltip GameTooltip
function ns.AddCompanionHint(tooltip)
	if not ns.db.companionHints or C_AddOns.IsAddOnLoaded(SHORTEST_PATH) then
		return
	end
	local hint
	if not C_AddOns.DoesAddOnExist(SHORTEST_PATH) then
		hint = L["Install Shortest Path Forever for walked routes and boat times."]
	else
		local _, _, _, _, reason = C_AddOns.GetAddOnInfo(SHORTEST_PATH)
		hint = reason == "DISABLED" and L["Enable Shortest Path Forever for walked routes and boat times."] or nil
	end
	if hint then
		GameTooltip_AddDisabledLine(tooltip, hint)
	end
end

-- "Nearest trainer  Name" over its zone and coordinates, and what a click does.
---@param tooltip GameTooltip
---@param label string
---@param npcID integer?
function ns.AddNearest(tooltip, label, npcID)
	if not npcID then
		return
	end
	GameTooltip_AddBlankLineToTooltip(tooltip)
	AddNPC(tooltip, label, npcID, nil, true)
	GameTooltip_AddInstructionLine(tooltip, L["Click for a waypoint."])
	ns.AddCompanionHint(tooltip)
end
