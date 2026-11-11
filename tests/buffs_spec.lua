-- Run from the repository root: luajit tests/buffs_spec.lua
-- The buffs page's listing rule: one row per buff effect, the skill axis they hang on, and the node each
-- item takes. The game owns the item names and tooltips, so those are stubbed here.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local c = Client.load({
	data = {
		RecipeData = {
			[1] = { skillLine = 185, reagents = {}, output = { itemID = 100, quantity = 1 } },
			[2] = { skillLine = 185, reagents = {}, output = { itemID = 101, quantity = 1 } },
			[3] = { skillLine = 185, reagents = {}, output = { itemID = 102, quantity = 1 } },
			[4] = { skillLine = 185, reagents = {}, output = { itemID = 103, quantity = 1 } },
			[5] = { skillLine = 185, reagents = {}, output = { itemID = 104, quantity = 1 } },
			[6] = { skillLine = 185, reagents = {}, output = { itemID = 105, quantity = 1 } },
			[7] = { skillLine = 185, reagents = {}, output = { itemID = 106, quantity = 1 } },
			[8] = { skillLine = 171, reagents = {}, output = { itemID = 107, quantity = 1 } },
			[9] = { skillLine = 185, reagents = {}, output = { itemID = 108, quantity = 1 } },
			[10] = { skillLine = 185, reagents = {}, output = { itemID = 109, quantity = 1 } },
			[11] = { skillLine = 185, reagents = {}, output = { itemID = 110, quantity = 1 } },
			[12] = { skillLine = 185, reagents = {}, output = { itemID = 111, quantity = 1 } },
			[20] = { skillLine = 164, reagents = {}, output = { itemID = 120, quantity = 1 } },
			[21] = { skillLine = 164, reagents = {}, output = { itemID = 121, quantity = 1 } },
			[22] = { skillLine = 333, reagents = {}, output = { itemID = 122, quantity = 1 } },
			[23] = { skillLine = 171, reagents = {}, output = { itemID = 123, quantity = 1 } },
		},
		-- Strength, Agility, Attack Power, spell damage and both armour effects; item 106 is no buff, and
		-- item 107 belongs to Alchemy.
		BuffItems = {
			[100] = 500,
			[101] = 501,
			[102] = 502,
			[103] = 503,
			[104] = 500,
			[105] = 501,
			[107] = 502,
			[108] = 502,
			[109] = 504,
			[110] = 505,
			[111] = 506,
			[120] = 500,
			[121] = 500,
			[122] = 501,
			[123] = 503,
		},
		BuffEffects = {
			[500] = { 29, 0 },
			[501] = { 29, 1 },
			[502] = { 99, 0 },
			[503] = { 29, 0 },
			[504] = { 13, 126 },
			[505] = { 465, 0 },
			[506] = { 18, 0 },
		},
		ItemGear = {
			[100] = { 0 },
			[101] = { 0 },
			[102] = { 0 },
			[103] = { 0 },
			[104] = { 20 },
			[105] = { 0 },
			[106] = { 0 },
			[107] = { 0 },
			[108] = { 0 },
			[109] = { 0 },
			[110] = { 0 },
			[111] = { 0 },
			[120] = { 0 },
			[121] = { 20 },
			[122] = { 0 },
			[123] = { 0 },
		},
		-- The skill each recipe is learned at, as the pattern or recipe item asks.
		RecipeScrolls = {
			[1] = { 9001, 1 },
			[2] = { 9002, 1 },
			[3] = { 9003, 25 },
			[4] = { 9004, 25 },
			[5] = { 9005, 50 },
			[6] = { 9006, 80 },
			[7] = { 9007, 1 },
			[8] = { 9008, 1 },
			[9] = { 9009, 25 },
			[10] = { 9010, 1 },
			[11] = { 9011, 1 },
			[12] = { 9012, 1 },
			[20] = { 9020, 25 },
			[21] = { 9021, 50 },
			[22] = { 9022, 1 },
			[23] = { 9023, 1 },
		},
		TrainerFees = {},
		TrainerRanks = { [185] = { { 150, 100, 125, 0 } } },
		Thresholds = {},
		VendorPrices = {},
		GatheredBy = {},
		ItemSellPrices = {},
	},
})
local ns = c.ns
c.professions = {
	{ name = "Cooking", rank = 30, max = 75, id = 185 },
	{ name = "Alchemy", rank = 10, max = 75, id = 171 },
}
c.known[1] = true
c.level = 12
-- An Alchemy recipe learned on another day, saved for this character: the page must not need the window
-- to be on Alchemy to know it.
local key = ns.CharacterKey()
ns.db.learned[key] = { [23] = true }
local profession = ns.PlayerProfessions()[185]

---@param label string
---@return SkillUpBuffRow?
local function Row(label)
	for _, row in ipairs(ns.BuffRows(profession, c.level, false)) do
		if row.label == label then
			return row
		end
	end
end

---@param label string
---@return string
local function Skills(label)
	local row = Row(label)
	local ids = {}
	for _, item in ipairs(row and row.items or {}) do
		ids[#ids + 1] = item.recipeID
	end
	return table.concat(ids, " ")
end

-- Grouping: one row per buff effect, in the character sheet's stat order, then the sheet's other effects;
-- a product that is no buff and another profession's recipe are left out.
local rows = ns.BuffRows(profession, c.level, false)
equal(#rows, 5, "five buff effect rows")
equal(rows[1].label, "Strength", "the character sheet's first stat comes first")
equal(rows[2].label, "Agility", "then the second")
equal(rows[3].label, "Attack Power", "then Attack Power")
equal(rows[4].label, "Spell Damage", "then spell damage")
equal(rows[5].label, "Armor", "then armour")
equal(Skills("Strength"), "1 4 5", "Strength holds its items in unlock order")
equal(Skills("Agility"), "2 6", "so does Agility")
equal(Skills("Attack Power"), "3 9", "two items at the same skill share the row")
equal(Skills("Spell Damage"), "10", "a spell damage buff takes the client's own name")
equal(Skills("Armor"), "11 12", "bonus armour joins MOD_ARMOR's one Armor row")
equal(Row("Spell 7"), nil, "a product that is no buff is left out")

-- What the character can do with each recipe: known, learnable now, still ahead, and above their level.
local strength = Row("Strength")
equal(strength.items[1].state, "known", "a learned recipe is known")
equal(strength.items[1].learned, true, "and says it is learned")
equal(strength.items[2].state, "trainable", "a recipe the skill reaches can be learned now")
equal(Row("Attack Power").items[1].state, "trainable", "at 25 with Cooking 30 it is learnable")
equal(Row("Agility").items[2].state, "needs", "at 80 it is still ahead")
equal(ns.BuffNodeState(strength.items[1]), "known", "a known node is green")
equal(ns.BuffNodeState(Row("Attack Power").items[1]), "trainable", "a learnable node is yellow")
equal(ns.BuffNodeState(Row("Agility").items[2]), "later", "a node still ahead is grey")

-- A buff item above the character's level is locked; the level switch leaves it out.
equal(strength.items[3].locked, true, "a level 20 item is locked at 12")
equal(ns.BuffNodeState(strength.items[3]), "locked", "and its node is the locked one")
local filtered = ns.BuffRows(profession, c.level, true)
equal(Skills("Strength"), "1 4 5", "the unfiltered row keeps the locked item")
equal(#filtered, 5, "the rows without a locked item stay")
local filteredStrength
for _, row in ipairs(filtered) do
	if row.label == "Strength" then
		filteredStrength = row
	end
end
equal(#filteredStrength.items, 2, "the level switch hides the locked item")
equal(ns.OnlyBuffsForLevel(), false, "the switch is off by default")
ns.SetOnlyBuffsForLevel(true)
equal(ns.OnlyBuffsForLevel(), true, "and saves the choice")

-- The axis runs from 1 to the highest learn skill rounded up to the next 25, and its linear place makes
-- 1..hi fill the node area's view.
local hi = ns.BuffAxis(rows)
equal(hi, 100, "the highest skill, 80, rounds up to 100")
equal(ns.BuffAxis({ { items = { { skill = 160 } } } }), 175, "160 rounds up to 175")
equal(ns.BuffAxis({ { items = { { skill = 250 } } } }), 250, "250 stays 250")
equal(ns.BuffAxis({ { items = { { skill = 1 } } } }), 25, "a lone skill 1 still spans a whole band")

-- Columns: every distinct skill gets one, lined up across rows. Two items at one skill take two slots,
-- and the next column clears them.
local NODE, GAP, COLUMN_GAP = 40, 4, 16
local columns, contentWidth = ns.BuffColumns(rows, hi, 200, NODE, GAP, COLUMN_GAP)
equal(#columns, 4, "four distinct learn skills make four columns")
equal(columns[1].skill, 1, "the first column is the lowest skill")
equal(columns[2].skill, 25, "then the next")
equal(columns[2].slots, 2, "Attack Power's two items at 25 take two slots")
equal(
	columns[3].x >= columns[2].x + 2 * NODE + GAP + COLUMN_GAP,
	true,
	"the next column clears both slots and the gap between columns"
)
equal(contentWidth, columns[4].x + NODE, "the content ends at the last column's right edge")

-- A sparse profession fits the view with no scrolling, because the linear scale fills it.
local sparse = {
	{
		key = "sparse",
		label = "Sparse",
		order = 1,
		items = {
			{ skill = 1, recipeID = 1 },
			{ skill = 100, recipeID = 2 },
		},
	},
}
local sparseColumns, sparseWidth = ns.BuffColumns(sparse, 100, 200, NODE, GAP, COLUMN_GAP)
equal(sparseWidth <= 200, true, "two far-apart items fit the view")
equal(sparseColumns[2].x, 200 - NODE, "the highest skill sits at the view's right edge")
equal(ns.BuffOpenOffset(sparseColumns, 1, sparseWidth, 200), 0, "nothing to scroll, so the view stays at 0")

-- A dense profession is wider than the view, and every node is at or right of its own skill with no
-- overlap.
local dense = {
	{
		key = "dense",
		label = "Dense",
		order = 1,
		items = {
			{ skill = 1, recipeID = 1 },
			{ skill = 25, recipeID = 2 },
			{ skill = 50, recipeID = 3 },
			{ skill = 80, recipeID = 4 },
			{ skill = 150, recipeID = 5 },
			{ skill = 300, recipeID = 6 },
		},
	},
	{
		key = "dense2",
		label = "Dense again",
		order = 2,
		items = { { skill = 1, recipeID = 7 }, { skill = 150, recipeID = 8 }, { skill = 300, recipeID = 9 } },
	},
}
local denseHi = ns.BuffAxis(dense)
local denseColumns, denseWidth = ns.BuffColumns(dense, denseHi, 200, NODE, GAP, COLUMN_GAP)
equal(denseWidth > 200, true, "a dense timeline is wider than the view")
for _, row in ipairs(dense) do
	local xs = ns.BuffRowX(row.items, denseColumns, NODE, GAP)
	for index, item in ipairs(row.items) do
		local linear = (item.skill - 1) * (200 - NODE) / (denseHi - 1)
		equal(xs[index] >= linear - 1e-9, true, "a node is never left of its own skill")
		if index > 1 then
			equal(xs[index] - xs[index - 1] >= NODE, true, "two nodes in a row never overlap")
		end
	end
end
local attackXs = ns.BuffRowX(Row("Attack Power").items, columns, NODE, GAP)
equal(attackXs[2] - attackXs[1], NODE + GAP, "two items at one skill sit a slot apart")

-- The divider sits in the middle of the gap after the last column the cap reaches, and names the rank a
-- trainer teaches next by the skill that trains it, not by its cap.
local divider = ns.BuffDivider(columns, 75, NODE, GAP, COLUMN_GAP)
equal(divider, columns[3].x + NODE + COLUMN_GAP / 2, "the divider is after the skill 50 column's slot")
equal(divider > columns[3].x + NODE, true, "it is past the column it follows")
equal(divider < columns[4].x, true, "and before the next column")
equal(ns.BuffDivider(columns, 300, NODE, GAP, COLUMN_GAP), nil, "no later column means no divider")
local rankName, rankSkill = ns.BuffNextRank(profession)
equal(rankName, "Journeyman", "the next rank above Apprentice is Journeyman")
equal(rankSkill, 125, "and its trainer entry's required skill, not its cap")

-- The view opens on the first column at or above the character's skill, as far as the content allows.
local openColumns = { { skill = 1, x = 0 }, { skill = 150, x = 400 }, { skill = 300, x = 800 } }
equal(ns.BuffOpenOffset(openColumns, 150, 1200, 400), 400, "skill 150's column sits at the left")
equal(ns.BuffOpenOffset(openColumns, 0, 1200, 400), 0, "another crafter opens on the first column")
equal(ns.BuffOpenOffset(openColumns, 300, 1200, 400), 800, "the last column opens at the end, as far as it can")
equal(ns.BuffOpenOffset(openColumns, 1, 400, 400), 0, "content that fits opens at 0")

-- The page's professions: the character's own that make buff items, sorted by name, then every other crafter
-- with buff items, sorted by name. A profession with no buff item is left out of both lists.
local own, others = ns.BuffProfessions(ns.PlayerProfessions())
equal(#own, 2, "two of the character's professions make buff items")
equal(own[1].name, "Alchemy", "the own list is by name")
equal(own[2].name, "Cooking", "so Cooking follows Alchemy")
equal(#others, 2, "two other crafters make buff items")
equal(others[1].name, "Blacksmithing", "the other list is by name")
equal(others[2].name, "Enchanting", "and only professions with buff items are there")
equal(others[1].other, true, "an other crafter carries the other flag")

-- The default selection: the one used last, else the open window's when it makes buffs, else the first own,
-- else the first other crafter.
equal(ns.BuffProfessionDefault(own, others, 333, 185).skillLine, 333, "the last choice wins")
equal(ns.BuffProfessionDefault(own, others, nil, 185).skillLine, 185, "else the window's profession")
equal(ns.BuffProfessionDefault(own, others, nil, 129).skillLine, 171, "else the first own profession")
equal(ns.BuffProfessionDefault({}, others, nil, 129).skillLine, 164, "else the first other crafter")
equal(ns.BuffProfessionDefault({}, {}, nil, 129), nil, "and nothing when no profession makes buffs")

-- An own profession that is not the open one still knows what this character learned, and its skill is the
-- character's own.
local alchemy = ns.PlayerProfessions()[171]
equal(alchemy.skill, 10, "Alchemy's skill comes from the character's professions")
local known = ns.BuffRows(alchemy, c.level, false)
equal(known[1].items[1].recipeID, 23, "its only buff recipe is listed")
equal(known[1].items[1].state, "known", "learned from the saved set, not the window")
equal(known[1].items[1].learned, true, "and marked learned")

-- Another crafter: every node is grey (locked wins), never called known or learnable, and the action says
-- another crafter.
local _, crafters = ns.BuffProfessions(ns.PlayerProfessions())
local smithing = crafters[1]
local smithingRows = ns.BuffRows(smithing, c.level, false)
equal(smithingRows[1].items[1].state, "other", "an other crafter's recipe is not learnable")
equal(smithingRows[1].items[1].learned, false, "and is never called learned")
equal(ns.BuffNodeState(smithingRows[1].items[1]), "later", "its node is the grey one")
equal(ns.BuffNodeState(smithingRows[1].items[2]), "locked", "and a level it cannot use still wins")
local text, enabled, _, reason = ns.PageParts.BuffAction(smithingRows[1].items[1], ns.PlayerProfessions())
equal(text, "Set waypoint", "another crafter's button offers a waypoint")
equal(enabled, false, "but is disabled")
equal(reason, "Another crafter", "with the reason")

-- The choice is saved per character.
ns.SetLastBuffProfession(333)
equal(ns.LastBuffProfession(), 333, "the chosen buff profession is saved")

-- The page's own drag-to-pan: the node area follows the cursor with the left button, a click on a node still
-- selects it, and Shift with the wheel keeps panning. A horizontal MinimalScrollBar under the timeline follows
-- both, and a fade shows at an edge while more lies beyond it (#565).
ns.SetLastBuffProfession(185)
ns.SetOnlyBuffsForLevel(false)
local ProfessionsFrame = c.G.CreateFrame("Frame", "ProfessionsFrame")
ProfessionsFrame:SetSize(673, 594)
ProfessionsFrame.CraftingPage = c.G.CreateFrame("Frame", nil, ProfessionsFrame)
ProfessionsFrame.BookPage = c.G.CreateFrame("Frame", nil, ProfessionsFrame)
ProfessionsFrame.ProfessionsOverviewTab = c.G.CreateFrame("Frame", nil, ProfessionsFrame)
ProfessionsFrame.ProfessionsOverviewTab:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 0, -60)
ProfessionsFrame.ProfessionsOverviewTab:SetSize(43, 55)
ProfessionsFrame.rightProfessionTabs = {}
-- The window's own profession read: no parent profession here, so the saved choice picks Cooking.
c.G.Professions = {
	GetProfessionInfo = function()
		return nil
	end,
}
ns.AttachBuffs()
local page
for _, frame in ipairs(c.frames) do
	if frame.Inset and frame.Rows then
		page = frame
	end
end
equal(page ~= nil, true, "the buffs page is built")
page.Inset:SetWidth(260)
page.Inset:SetHeight(482)
page:Show()
page.Rows:RenderRows()
-- #599: the level switch sits beside the inset's title, its bottom clear of the inset's top edge, so the
-- skill axis and its tick labels below can never run under it at any window width.
local levelPoint = page.Level.points[1]
equal(levelPoint[1], "BOTTOMRIGHT", "the level switch is anchored by its bottom right")
equal(levelPoint[2], page.Inset, "to the inset")
equal(levelPoint[3], "TOPRIGHT", "at its top right")
equal(levelPoint[5] >= 0, true, "with its bottom above the inset, clear of the axis")
equal(page.LevelLabel.points[1][2], page.Level, "and its label follows the switch")
equal(page.HScroll ~= nil, true, "the page has a horizontal scroll bar")
equal(page.HScroll.isHorizontal, true, "built in the client's horizontal mode")
equal(page.HScroll.template, "MinimalScrollBar", "in the client's minimal style, not the trim bar")
equal(page.HScroll.Track.Thumb:GetHeight() > 0, true, "the horizontal thumb has a clickable height")
equal(page.HScroll.Back.points[1][1], "LEFT", "the back arrow is at the left edge")
equal(page.HScroll.Forward.points[1][1], "RIGHT", "the forward arrow is at the right edge")
local maxOffset = page.ContentWidth - page.ViewWidth
equal(maxOffset > 0, true, "the fixture's timeline is wider than the view")
equal(page.HScroll:GetScrollPercentage(), page.ScrollOffset / maxOffset, "the bar starts at the page's offset")
equal(page.FadeLeft:IsShown(), page.ScrollOffset > 0, "the left fade shows only when the view is scrolled in")
equal(page.FadeRight:IsShown(), page.ScrollOffset < maxOffset, "and the right one only while more lies beyond it")

local cursor = 0
c.G.GetCursorPosition = function()
	return cursor, 0
end
local dragStarted = page.ScrollOffset
cursor = 1000
page.Rows.scripts.OnDragStart(page.Rows)
equal(page.Rows.scripts.OnUpdate ~= nil, true, "a left drag starts following the cursor")
cursor = 1040
page.Rows.scripts.OnUpdate(page.Rows)
equal(page.ScrollOffset, math.max(0, dragStarted - 40), "dragging right moves the timeline with the cursor")
equal(page.HScroll:GetScrollPercentage(), page.ScrollOffset / maxOffset, "the horizontal bar follows the drag")
page.Rows.scripts.OnDragStop(page.Rows)
equal(page.Rows.scripts.OnUpdate, nil, "letting go stops the follow")

-- A drag past either end clamps to it.
cursor = 100000
page.Rows.scripts.OnDragStart(page.Rows)
cursor = 0
page.Rows.scripts.OnUpdate(page.Rows)
equal(page.ScrollOffset, maxOffset, "a drag past the right end stops at the content's end")
equal(page.FadeLeft:IsShown(), true, "with a left fade while the view is scrolled in")
equal(page.FadeRight:IsShown(), false, "and none on the right at the end")
equal(page.HScroll:GetScrollPercentage(), 1, "the bar sits at its end too")
page.Rows.scripts.OnDragStop(page.Rows)
cursor = 0
page.Rows.scripts.OnDragStart(page.Rows)
cursor = 100000
page.Rows.scripts.OnUpdate(page.Rows)
equal(page.ScrollOffset, 0, "a drag past the left end stops at the first column")
equal(page.FadeLeft:IsShown(), false, "so the left fade goes")
equal(page.FadeRight:IsShown(), true, "and the right one returns")
equal(page.HScroll:GetScrollPercentage(), 0, "the bar is back at its start")
page.Rows.scripts.OnDragStop(page.Rows)

-- A plain click on a node selects it; a drag that starts on one pans the area instead.
local node = page.RowFrames[1].Nodes[1]
equal(node ~= nil, true, "the first row has a node")
node.scripts.OnClick(node)
equal(page.SelectedItemID, node.item.itemID, "a click on a node selects its item")
local nodeDragStarted = page.ScrollOffset
cursor = 0
node.scripts.OnDragStart(node)
equal(page.Rows.scripts.OnUpdate ~= nil, true, "a drag that starts on a node pans the area")
cursor = -50
page.Rows.scripts.OnUpdate(page.Rows)
equal(page.ScrollOffset, math.min(maxOffset, nodeDragStarted + 50), "and follows the cursor like the area")
node.scripts.OnDragStop(node)
equal(page.Rows.scripts.OnUpdate, nil, "and stops when the node's drag ends")

-- Shift and the wheel still pan the timeline; the plain wheel still scrolls the rows.
c.G.IsShiftKeyDown = function()
	return true
end
local wheelStarted = page.ScrollOffset
local delta = wheelStarted > 0 and 1 or -1
page.Rows.scripts.OnMouseWheel(page.Rows, delta)
equal(
	page.ScrollOffset,
	math.max(0, math.min(wheelStarted - delta * 60, maxOffset)),
	"Shift and the wheel pan the timeline"
)
equal(page.HScroll:GetScrollPercentage(), page.ScrollOffset / maxOffset, "and the bar keeps the same place")
-- Dragging the bar itself scrolls the timeline to the same fraction.
local onScroll = page.HScroll.callbacks and page.HScroll.callbacks.OnScroll
equal(onScroll ~= nil, true, "the bar reports its own drags")
function page.HScroll:SetScrollPercentage(percentage)
	self.scrollPercentage = percentage
	onScroll[1].callback(self, percentage)
end
page.HScroll:SetScrollPercentage(0.5)
equal(page.ScrollOffset, maxOffset / 2, "halfway on the bar is halfway along the timeline")
c.G.IsShiftKeyDown = function()
	return false
end
page.Rows:SetScrollPercentage(0.5)
local beforePlainWheel = page.ScrollOffset
page.Rows.scripts.OnMouseWheel(page.Rows, -1)
equal(page.Rows:GetScrollPercentage() > 0.6, true, "the plain wheel scrolls the rows")
equal(page.ScrollOffset, beforePlainWheel, "and leaves the timeline where it was")

Client.report("buffs_spec")
