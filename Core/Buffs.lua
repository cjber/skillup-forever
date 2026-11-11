---@type string, SkillUpNamespace
local _, ns = ...

if ns.broken then
	return
end
local L = ns.L

-- The buffs page's listing rule: every recipe of the open profession whose product leaves a buff, grouped
-- into one row per buff effect, and the skill axis those rows hang on. The game owns the words: a row is
-- named by the client's own string for its effect, and only an effect without one falls back to its spell.

-- SpellEffect aura types the client has a row name for, from its own SpellAura enums.
local MOD_STAT = 29
local MOD_SKILL = 30
local MOD_DAMAGE_DONE = 13
local MOD_HEALING_DONE = 135
local MOD_CRIT_PCT = 290
local MOD_SPEED_ALWAYS = 129
local MOD_ARMOR = 18
local MOD_BONUS_ARMOR = 465
local MOD_RESISTANCE = 22
local MOD_STAT_PCT = 69
local MOD_ATTACK_POWER = 99
-- A misc value's school mask for all of magic at once, which is not one school.
local ALL_MAGIC = 126
-- The client's stat order, as its character sheet lists them: Strength, Agility, Stamina, Intellect, Spirit.
local STATS = 5

-- The client's own words for an effect, by aura type and misc value. This is exact data: each entry names
-- the GlobalString and the misc value's meaning, and an effect the client has no string for returns nil so
-- the row takes its spell's name instead. Never read the effect's description text.
local LABELS = {
	-- The stat index: 0 Strength through 4 Spirit.
	[MOD_STAT] = function(misc)
		return misc >= 0 and misc < STATS and _G["SPELL_STAT" .. (misc + 1) .. "_NAME"] or nil
	end,
	-- A percentage of the same stat, which the character sheet still calls by the stat's name.
	[MOD_STAT_PCT] = function(misc)
		return misc >= 0 and misc < STATS and _G["SPELL_STAT" .. (misc + 1) .. "_NAME"] or nil
	end,
	[MOD_ATTACK_POWER] = function()
		return STAT_ATTACK_POWER
	end,
	-- Spell damage at every magic school at once; one school's mask has no row name of its own.
	[MOD_DAMAGE_DONE] = function(misc)
		if misc == ALL_MAGIC then
			return STAT_SPELLDAMAGE
		end
		return nil
	end,
	[MOD_HEALING_DONE] = function()
		return STAT_SPELLHEALING
	end,
	[MOD_CRIT_PCT] = function()
		return STAT_CRITICAL_STRIKE
	end,
	[MOD_SPEED_ALWAYS] = function()
		return STAT_MOVEMENT_SPEED
	end,
	[MOD_ARMOR] = function()
		return STAT_ARMOR
	end,
	-- Bonus armour is the character sheet's armour, so it draws the same row as MOD_ARMOR.
	[MOD_BONUS_ARMOR] = function()
		return STAT_ARMOR
	end,
	-- A school mask, named by its one school; every magic school at once is the client's own "Resistance".
	[MOD_RESISTANCE] = function(misc)
		if misc == ALL_MAGIC then
			return RESISTANCE_LABEL
		end
		local school, bit = 1, 2
		while bit <= 64 do
			if bit == misc then
				return _G["RESISTANCE" .. school .. "_NAME"]
			end
			school, bit = school + 1, bit * 2
		end
		return nil
	end,
	-- The skill line the buff raises, named by the profession data the addon already carries or the
	-- client's own skill list.
	[MOD_SKILL] = function(misc)
		for name, skillLine in pairs(ns.ProfessionSkillLines or {}) do
			if skillLine == misc then
				return name
			end
		end
		local info = C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID and C_SkillInfo.GetSkillLineInfoByID(misc)
		return info and info.name
	end,
}

-- A second aura type whose effect is another type's row, so both share that row's key: bonus armour is
-- the one Armor row MOD_ARMOR names.
local SAME_ROW = { [MOD_BONUS_ARMOR] = MOD_ARMOR }

-- Where a row sits: the character sheet's stat order, then the other effects in the order the sheet
-- lists them, then the skill lines. An effect with no string is a row of its own, after the named ones.
---@param aura integer?
---@param misc integer?
---@return integer
local function Order(aura, misc)
	if aura == MOD_STAT or aura == MOD_STAT_PCT then
		if misc and misc >= 0 and misc < STATS then
			return misc + 1
		end
	elseif aura == MOD_ATTACK_POWER then
		return STATS + 1
	elseif aura == MOD_DAMAGE_DONE then
		return STATS + 2
	elseif aura == MOD_HEALING_DONE then
		return STATS + 3
	elseif aura == MOD_CRIT_PCT then
		return STATS + 4
	elseif aura == MOD_SPEED_ALWAYS then
		return STATS + 5
	elseif aura == MOD_ARMOR or aura == MOD_BONUS_ARMOR then
		return STATS + 6
	elseif aura == MOD_RESISTANCE then
		return STATS + 7
	elseif aura == MOD_SKILL then
		return STATS + 8
	end
	return STATS + 9
end

-- The row's name, order and key: the client's word for the effect when it has one, else the spell's own
-- name and a key of its own so two unnamed spells never share a row. An unnamed effect sorts after every
-- named one.
---@param aura integer?
---@param misc integer?
---@param spellID integer
---@return string label
---@return integer order
---@return string key
local function RowName(aura, misc, spellID)
	local label = aura and LABELS[aura] and LABELS[aura](misc)
	if label then
		local rowAura = SAME_ROW[aura] or aura
		local rowMisc = rowAura == aura and misc or 0
		return label, Order(aura, misc), string.format("effect:%d:%d", rowAura, rowMisc)
	end
	label = C_Spell.GetSpellName(spellID) or string.format(L["spell %d"], spellID)
	return label, STATS + 9, string.format("spell:%d", spellID)
end

-- What the character can do with the recipe, as the gear page says it: a known recipe, one its skill
-- already reaches, or one the skill has still to reach.
---@param learned boolean
---@param profession SkillUpContext
---@param skill number
---@return "known"|"trainable"|"needs"
local function State(learned, profession, skill)
	if learned then
		return "known"
	elseif profession.skill >= skill then
		return "trainable"
	end
	return "needs"
end

-- Every buff recipe of this profession, grouped one row per buff effect. Rows come in the client's stat
-- order then by name; each row's items come in the order they unlock. `hideLocked` leaves out an item the
-- character's level cannot use, and a row that empties.
---@param profession SkillUpContext
---@param level number
---@param hideLocked boolean
---@return SkillUpBuffRow[]
function ns.BuffRows(profession, level, hideLocked)
	local byKey = {}
	local rows = {}
	for recipeID, recipe in pairs(ns.RecipeData) do
		local output = recipe.output
		local itemID = output and output.itemID
		local spell = itemID and ns.BuffItems[itemID]
		-- A recipe the data cannot place on the axis has no node to draw.
		local skill = spell and ns.LearnSkill(profession, recipeID) or 0
		if recipe.skillLine == profession.skillLine and spell and skill > 0 then
			local itemLevel = ns.BuffLevel(recipeID) or 0
			local locked = itemLevel > level
			if not (hideLocked and locked) then
				local effect = ns.BuffEffects and ns.BuffEffects[spell]
				local aura, misc = effect and effect[1], effect and effect[2]
				local label, order, key = RowName(aura, misc, spell)
				local row = byKey[key]
				if not row then
					row = { key = key, label = label, order = order, items = {} }
					byKey[key] = row
					rows[#rows + 1] = row
				end
				local other = profession.other == true
				local learned = not other and ns.IsLearned(recipeID) == true
				row.items[#row.items + 1] = {
					recipeID = recipeID,
					itemID = itemID,
					spell = spell,
					skill = skill,
					level = itemLevel,
					profession = profession.name,
					locked = locked,
					learned = learned,
					state = other and "other" or State(learned, profession, skill),
				}
			end
		end
	end
	for _, row in ipairs(rows) do
		table.sort(row.items, function(a, b)
			if a.skill ~= b.skill then
				return a.skill < b.skill
			end
			return a.recipeID < b.recipeID
		end)
	end
	table.sort(rows, function(a, b)
		if a.order ~= b.order then
			return a.order < b.order
		end
		return a.label < b.label
	end)
	return rows
end

-- Every profession line that makes a buff item, cached for the bundled data's lifetime. The Buffs page picks
-- its profession from this, not from the window it is open in.
---@type table<integer, true>?
local buffLines
---@type table?
local buffData
---@return table<integer, true>
function ns.BuffProfessionLines()
	if buffLines and buffData == ns.RecipeData then
		return buffLines
	end
	buffLines, buffData = {}, ns.RecipeData
	for _, recipe in pairs(ns.RecipeData) do
		local output = recipe.output
		local itemID = output and output.itemID
		if itemID and ns.BuffItems[itemID] then
			buffLines[recipe.skillLine] = true
		end
	end
	return buffLines
end

-- The Buffs page's professions: the character's own that make buff items, then every other crafter's, each
-- sorted by name. A crafter the character does not have carries `other`, so its nodes and action say so.
---@param professions table<integer, SkillUpProfession>
---@return SkillUpContext[] own
---@return SkillUpContext[] others
function ns.BuffProfessions(professions)
	local lines = ns.BuffProfessionLines()
	local own, others = {}, {}
	for skillLine in pairs(lines) do
		local profession = professions[skillLine]
		if profession then
			own[#own + 1] = profession
		else
			others[#others + 1] = {
				skillLine = skillLine,
				name = ns.Gear.ProfessionName(skillLine),
				skill = 0,
				base = 0,
				max = 0,
				modifier = 0,
				other = true,
			}
		end
	end
	table.sort(own, function(a, b)
		return a.name < b.name
	end)
	table.sort(others, function(a, b)
		return a.name < b.name
	end)
	return own, others
end

-- The page's selection: the last profession chosen, else the open window's when it makes buffs, else the
-- first of the character's own, else the first other crafter.
---@param own SkillUpContext[]
---@param others SkillUpContext[]
---@param saved integer?
---@param open integer?
---@return SkillUpContext?
function ns.BuffProfessionDefault(own, others, saved, open)
	for _, list in ipairs({ own, others }) do
		for _, profession in ipairs(list) do
			if profession.skillLine == saved then
				return profession
			end
		end
	end
	for _, profession in ipairs(own) do
		if profession.skillLine == open then
			return profession
		end
	end
	return own[1] or others[1]
end

-- The skill axis: from 1 to the highest learn skill shown, rounded up to the next 25. The linear place a
-- skill maps to is (skill - 1) x scale, with the scale that makes 1..hi fill the node area's view.
---@param rows SkillUpBuffRow[]
---@return number hi
function ns.BuffAxis(rows)
	local highest = 1
	for _, row in ipairs(rows) do
		for _, item in ipairs(row.items) do
			if item.skill > highest then
				highest = item.skill
			end
		end
	end
	return math.max(1, math.ceil(highest / 25) * 25)
end

-- The timeline's columns: every distinct learn skill across the rows, in skill order. A column is as
-- wide as the most items any one row has at that skill, so two items at one skill take two slots. Its
-- place is the linear place its skill maps to, moved right only where the previous column would
-- overlap it, so every node still sits under its own skill and columns line up across rows.
---@param rows SkillUpBuffRow[]
---@param hi number
---@param width number the visible width of the node area
---@param node number
---@param gap number between two slots of a column
---@param columnGap number between two columns
---@return SkillUpBuffColumn[] columns
---@return number contentWidth the last column's right edge
function ns.BuffColumns(rows, hi, width, node, gap, columnGap)
	local slots = {}
	for _, row in ipairs(rows) do
		local counts = {}
		for _, item in ipairs(row.items) do
			counts[item.skill] = (counts[item.skill] or 0) + 1
		end
		for skill, count in pairs(counts) do
			if not slots[skill] or slots[skill] < count then
				slots[skill] = count
			end
		end
	end
	local skills = {}
	for skill in pairs(slots) do
		skills[#skills + 1] = skill
	end
	table.sort(skills)
	local scale = math.max(width - node, 0) / math.max(hi - 1, 1)
	local columns = {}
	local right = -columnGap
	for index, skill in ipairs(skills) do
		local count = slots[skill]
		local x = math.max((skill - 1) * scale, right + columnGap)
		local span = count * node + (count - 1) * gap
		columns[index] = { skill = skill, slots = count, x = x, width = span }
		right = x + span
	end
	return columns, math.max(right, 0)
end

-- Where one row's items sit: in their column, in the order they unlock, a slot apart.
---@param items SkillUpBuffItem[]
---@param columns SkillUpBuffColumn[]
---@param node number
---@param gap number
---@return number[] x
function ns.BuffRowX(items, columns, node, gap)
	local bySkill = {}
	for _, column in ipairs(columns) do
		bySkill[column.skill] = column
	end
	local slot = {}
	local xs = {}
	for index, item in ipairs(items) do
		local column = bySkill[item.skill]
		local used = slot[item.skill] or 0
		slot[item.skill] = used + 1
		xs[index] = column and column.x + used * (node + gap) or 0
	end
	return xs
end

-- The rank divider: in the middle of the gap after the last column the character's cap reaches, when a
-- later column exists. The divider is in content units, like the columns.
---@param columns SkillUpBuffColumn[]
---@param max number the character's current cap
---@param node number
---@param gap number
---@param columnGap number
---@return number? x
function ns.BuffDivider(columns, max, node, gap, columnGap)
	local last
	for index, column in ipairs(columns) do
		if column.skill <= max then
			last = index
		end
	end
	if not last or last >= #columns then
		return nil
	end
	local column = columns[last]
	return column.x + column.slots * node + (column.slots - 1) * gap + columnGap / 2
end

-- Where the view opens: the first column at or above the character's skill sits at its left, as far as
-- the content allows. Another crafter has no skill, so its view opens on the first column.
---@param columns SkillUpBuffColumn[]
---@param skill number
---@param contentWidth number
---@param width number
---@return number offset
function ns.BuffOpenOffset(columns, skill, contentWidth, width)
	local maxOffset = math.max(contentWidth - width, 0)
	if maxOffset == 0 then
		return 0
	end
	local x = maxOffset
	for _, column in ipairs(columns) do
		if column.skill >= skill then
			x = column.x
			break
		end
	end
	return math.max(0, math.min(x, maxOffset))
end

-- The next trainer rank above the character's cap: its name and the skill needed to train it. A rank
-- that comes from a book or a quest, so the trainer table does not hold it, has no name.
---@param profession SkillUpContext
---@return string? name
---@return integer? skill
function ns.BuffNextRank(profession)
	local best
	for _, rank in ipairs(ns.TrainerRanks[profession.skillLine] or {}) do
		if rank[1] > profession.max and (not best or rank[1] < best[1]) then
			best = rank
		end
	end
	if not best then
		return nil
	end
	return ns.RankName(best[1]), best[3] or best[1]
end

-- The four node states: a known recipe, one the skill reaches now, one the skill has still to reach, and
-- one the character's level cannot use yet.
---@param item SkillUpBuffItem
---@return "known"|"trainable"|"locked"|"later"
function ns.BuffNodeState(item)
	if item.locked then
		return "locked"
	elseif item.state == "known" then
		return "known"
	elseif item.state == "trainable" then
		return "trainable"
	end
	return "later"
end
