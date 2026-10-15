---@type string, SkillUpNamespace
local _, ns = ...

-- SkillUp's own lines in /su report (cjber/adventure-guide-forever#156): the settings that change a number, the
-- data providers, each profession with its route, then /su audit's and /su trainers' lines, each cut so the
-- caught errors after them still fit in one message. English throughout, so a report reads the same in every
-- locale.

-- How many of a list's detail lines the report keeps; the rest are counted.
local DETAIL_SHOWN = 6

-- `lines` with at most DETAIL_SHOWN of `details` after them, indented, and how many more there were.
---@param lines string[]
---@param details string[]
---@param from integer the first detail in `details`
local function AddDetails(lines, details, from)
	local shown = 0
	for index = from, #details do
		if shown == DETAIL_SHOWN then
			lines[#lines + 1] = ("  and %d more"):format(#details - index + 1)
			return
		end
		shown = shown + 1
		lines[#lines + 1] = "  " .. details[index]
	end
end

---@param state string|boolean
---@return string
local function Provider(state)
	return state == true and "ready" or state == false and "missing" or tostring(state)
end

-- The report's SkillUp lines.
---@return string[]
function ns.ReportLines()
	local db = ns.db
	local lines = {
		("Settings: crafts count %s, gathered %s, reagent tooltips %s, sort %s"):format(
			db.craftValue,
			db.valueGathered and "valued" or "free",
			db.reagentTooltip,
			db.sortMode
		),
		("Providers: QuestieDB %s, AtlasLoot %s, Auctionator %s"):format(
			ns.Questie.State(),
			Provider(ns.AtlasLoot.Ready() or (ns.AtlasLoot.Idle() and "off") or false),
			Provider(ns.HasAuctionator())
		),
	}
	local routable = ns.RouteProfessions()
	local skillLines = {}
	for skillLine in pairs(ns.PlayerProfessions()) do
		skillLines[#skillLines + 1] = skillLine
	end
	table.sort(skillLines)
	local professions = ns.PlayerProfessions()
	for _, skillLine in ipairs(skillLines) do
		local p = professions[skillLine]
		local line = ("%s [%d]: %d+%d/%d"):format(p.name, skillLine, p.base, p.modifier, p.max)
		local profession = routable[skillLine]
		if profession then
			local plan = ns.PlanRoute(profession)
			line = line
				.. ("; route to %d reaches %d, %d steps, %s"):format(
					plan.target,
					plan.reached,
					#plan.steps,
					ns.RouteBlocked(plan) or plan.stopReason or "ok"
				)
		end
		lines[#lines + 1] = line
	end
	local audit = ns.AuditLines()
	if audit then
		lines[#lines + 1] = "Audit: " .. audit[1]
		AddDetails(lines, audit, 2)
	else
		lines[#lines + 1] = "Audit: no profession open"
	end
	-- /su trainers' summary for this character's professions only, and its detail lines.
	local names = {}
	for _, p in pairs(professions) do
		names[p.name] = true
	end
	local summaries, details = {}, {}
	for _, line in ipairs(ns.TrainerReport()) do
		if line:find("^  ") then
			details[#details + 1] = strtrim(line)
		elseif names[line:match("^(.-):")] then
			summaries[#summaries + 1] = line
		end
	end
	lines[#lines + 1] = "Trainers: " .. (summaries[1] and table.concat(summaries, " ") or "nothing to check")
	AddDetails(lines, details, 1)
	return lines
end
