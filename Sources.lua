local _, ns = ...

-- Where recipe scrolls come from (bundled from classic-db) and how to get there.

local FACTION_CODES = { Alliance = "A", Horde = "H" }

local function Usable(npcID)
	local faction = ns.SourceNPCs[npcID][2]
	return faction == "" or faction == FACTION_CODES[UnitFactionGroup("player")]
end

-- The NPC's zone and map position, resolved by the client from its world spawn so
-- overlapping zone rectangles can't mislabel it; a dungeon has only its name.
function ns.NPCLocation(npcID)
	local name, _, map, x, y = unpack(ns.SourceNPCs[npcID])
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

function ns.LocationText(where)
	if where.map then
		return string.format("%s  %.0f, %.0f", where.label, where.x * 100, where.y * 100)
	end
	return where.label
end

-- UnitPosition's first value is the world's north axis, as classic-db's x is.
local function Distance(npcID)
	local px, py, _, instance = UnitPosition("player")
	local _, _, map, x, y = unpack(ns.SourceNPCs[npcID])
	if not px or map ~= instance then
		return math.huge
	end
	return (px - x) ^ 2 + (py - y) ^ 2
end

-- Of these NPCs, the nearest this character can deal with (vendors of the other
-- faction won't trade), else nil.
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
-- a quest, a named drop, a world drop; nil when only the other faction sells it.
local function Kind(source)
	local vendor = source.vendors and ns.NearestNPC(source.vendors, true)
	if vendor then
		return source.limited and 2 or 1, vendor
	elseif source.quests then
		return 3
	elseif source.drops then
		return 4, source.drops[1][1]
	elseif source.world then
		return 5
	end
end

local KIND_TEXT = { "vendor", "limited vendor", "quest", "drop", "world drop" }

-- Scroll recipes of this profession, not trainer-taught nor learned, that could
-- be learned by `skill` (effective) and still skill up there, easiest to get and
-- then furthest-reaching first.
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
function ns.ScrollPrice(source)
	local price = ns.Price(source.item)
	return price and price.copper or (source.price and source.price > 0 and source.price) or nil
end

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

function ns.AddSourceLines(tooltip, source)
	for _, npcID in ipairs(source.vendors or {}) do
		AddNPC(tooltip, "Sold by", npcID, source.limited and "  (limited)" or nil, Usable(npcID))
	end
	for _, questID in ipairs(source.quests or {}) do
		GameTooltip_AddColoredDoubleLine(
			tooltip,
			"Quest",
			ns.SourceQuests[questID],
			NORMAL_FONT_COLOR,
			HIGHLIGHT_FONT_COLOR
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
function ns.NearestTrainer(profession, cap)
	local trainers = {}
	for _, row in ipairs(ns.ProfessionTrainers[profession.skillLine] or {}) do
		if row[2] >= cap then
			trainers[#trainers + 1] = row[1]
		end
	end
	return ns.NearestNPC(trainers, true)
end

function ns.NearestVendor(itemID)
	local vendors = ns.ReagentVendors[itemID]
	return vendors and ns.NearestNPC(vendors, true)
end

-- "Nearest trainer  Name" over its zone and coordinates, and what a click does.
function ns.AddNearest(tooltip, label, npcID)
	if not npcID then
		return
	end
	GameTooltip_AddBlankLineToTooltip(tooltip)
	AddNPC(tooltip, label, npcID, nil, true)
	GameTooltip_AddInstructionLine(tooltip, "Click for a waypoint.")
end
