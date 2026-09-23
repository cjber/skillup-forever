---@type string, SkillUpNamespace
local _, ns = ...

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
---@return integer?
local function VendorFor(source)
	local unlimited, limited = {}, {}
	for _, npcID in ipairs(source.vendors or {}) do
		table.insert(Limited(source, npcID) and limited or unlimited, npcID)
	end
	return ns.NearestNPC(unlimited, true) or ns.NearestNPC(limited, true)
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

-- The NPC's zone and map position, resolved by the client from its world spawn so
-- overlapping zone rectangles can't mislabel it; a dungeon has only its name.
---@param npcID integer
---@return SkillUpLocation
function ns.NPCLocation(npcID)
	local npc = ns.SourceNPCs[npcID]
	local name, map, x, y = npc[1], npc[3], npc[4], npc[5]
	local instance = ns.InstanceNames[map]
	if instance then
		return { name = name, label = instance }
	end
	local uiMapID, position = C_Map.GetMapPosFromWorldPos(map, CreateVector2D(x, y))
	local info = uiMapID and C_Map.GetMapInfo(uiMapID)
	if not (info and position) then
		return { name = name, label = "unknown location" }
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

-- Of these NPCs, the nearest this character can deal with (vendors of the other
-- faction won't trade), else nil.
---@param npcIDs integer[]
---@param vendorsOnly boolean?
---@return integer?
function ns.NearestNPC(npcIDs, vendorsOnly)
	local best, bestDistance
	for _, npcID in ipairs(npcIDs) do
		if not vendorsOnly or Usable(npcID) then
			local distance = Distance(npcID)
			if not best or distance < bestDistance then
				best, bestDistance = npcID, distance
			end
		end
	end
	return best
end

-- TomTom's arrow when it's installed, else the map's own waypoint, super-tracked.
---@param npcID integer
function ns.SetWaypoint(npcID)
	local where = ns.NPCLocation(npcID)
	if not where.map then
		ns.Print(string.format("%s is in %s.", where.name, where.label))
		return
	end
	if TomTom and TomTom.AddWaypoint then
		TomTom:AddWaypoint(where.map, where.x, where.y, { title = where.name, from = "SkillUp Forever" })
	elseif C_Map.CanSetUserWaypointOnMap(where.map) then
		C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(where.map, where.x, where.y))
		C_SuperTrack.SetSuperTrackedUserWaypoint(true)
	else
		ns.Print(string.format("%s is at %s.", where.name, ns.LocationText(where)))
		return
	end
	ns.Print(string.format("waypoint set to %s, %s.", where.name, ns.LocationText(where)))
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

local KIND_TEXT = { "vendor", "limited vendor", "quest", "drop", "world drop" }

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
		AddNPC(tooltip, "Sold by", npcID, Limited(source, npcID) and "  (limited)" or nil, Usable(npcID))
	end
	for _, questID in ipairs(source.quests or {}) do
		local title, faction = unpack(ns.SourceQuests[questID])
		GameTooltip_AddColoredDoubleLine(
			tooltip,
			"Quest",
			title,
			NORMAL_FONT_COLOR,
			OurFaction(faction) and HIGHLIGHT_FONT_COLOR or RED_FONT_COLOR
		)
	end
	for _, drop in ipairs(source.drops or {}) do
		AddNPC(tooltip, "Dropped by", drop[1], string.format("  (%s%%)", drop[2]), true)
	end
	if source.world then
		GameTooltip_AddNormalLine(tooltip, "World drop")
	end
end

-- The nearest trainer of this profession, of your faction, who teaches up to `cap`.
---@param profession SkillUpContext
---@param cap number
---@return integer?
function ns.NearestTrainer(profession, cap)
	local trainers = {}
	for _, row in ipairs(ns.ProfessionTrainers[profession.skillLine] or {}) do
		if row[2] >= cap then
			trainers[#trainers + 1] = row[1]
		end
	end
	return ns.NearestNPC(trainers, true)
end

---@param itemID integer
---@return integer?
function ns.NearestVendor(itemID)
	local vendors = ns.ReagentVendors[itemID]
	return vendors and ns.NearestNPC(vendors, true)
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
	GameTooltip_AddInstructionLine(tooltip, "Click for a waypoint.")
end
