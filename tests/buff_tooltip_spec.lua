-- Run from the repository root: luajit tests/buff_tooltip_spec.lua
-- Issue #357: a buff recipe's tooltip says what the buff does, in the game's own words, and the nearest zone each
-- of its reagents drops in; a buff consumable's own tooltip says which profession and skill make it.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local FIRST_AID, ALCHEMY = 129, 171
local BUFF_RECIPE, PLAIN_RECIPE, HIGHER_MAKER, UNTRAINED_MAKER = 1, 2, 3, 4
local BUFF_ITEM, PLAIN_ITEM, THIRD_ITEM = 101, 102, 103
local LINEN, THREAD, SILK = 201, 202, 203
local BUFF_SPELL = 500
local BUFF_NAME, BUFF_DESCRIPTION = "Elixir of Wisdom", "Increases Intellect by 5 for 5 min."
-- A hostile creature with no faction at all still drops its loot for anyone to take.
local HOSTILE_NEAR, FAR, FAR_TWIN, FARTHER = 301, 302, 303, 304

local c = Client.load({
	boot = false,
	data = {
		Thresholds = {
			[BUFF_RECIPE] = { 30, 45, 60, 75 },
			[PLAIN_RECIPE] = { 1, 30, 45, 60 },
			[HIGHER_MAKER] = { 100, 120, 140, 160 },
		},
		RecipeData = {
			[BUFF_RECIPE] = {
				skillLine = FIRST_AID,
				reagents = { { itemID = LINEN, quantity = 1 } },
				output = { itemID = BUFF_ITEM, quantity = 1 },
			},
			[PLAIN_RECIPE] = {
				skillLine = FIRST_AID,
				reagents = { { itemID = LINEN, quantity = 1 } },
				output = { itemID = PLAIN_ITEM, quantity = 1 },
			},
			[HIGHER_MAKER] = {
				skillLine = ALCHEMY,
				reagents = { { itemID = THREAD, quantity = 1 } },
				output = { itemID = BUFF_ITEM, quantity = 1 },
			},
			-- A buff whose maker has no thresholds in the bundle: the line names only the profession.
			[UNTRAINED_MAKER] = {
				skillLine = FIRST_AID,
				reagents = { { itemID = LINEN, quantity = 1 } },
				output = { itemID = THIRD_ITEM, quantity = 1 },
			},
		},
		BuffItems = { [BUFF_ITEM] = BUFF_SPELL, [THIRD_ITEM] = BUFF_SPELL },
		TrainerFees = {},
		TrainerRanks = { [FIRST_AID] = {}, [ALCHEMY] = {} },
		ItemSellPrices = {},
		GatheredBy = {},
		VendorPrices = { [LINEN] = 10, [THREAD] = 10 },
		ProfessionTrainers = {},
	},
	questie = {
		items = {
			[LINEN] = { class = 7, drops = { HOSTILE_NEAR, FAR } },
			[THREAD] = { class = 7, drops = { FAR, FARTHER } },
			[SILK] = { class = 7, drops = { FAR, FAR_TWIN } },
		},
		npcs = {
			[HOSTILE_NEAR] = { name = "Hostile Drudge", spawns = { [10] = { { 2, 2 } } } },
			[FAR] = { name = "Far Drudge", spawns = { [20] = { { 40, 40 } } } },
			[FAR_TWIN] = { name = "Far Twin", spawns = { [20] = { { 60, 60 } } } },
			[FARTHER] = { name = "Farther Drudge", spawns = { [30] = { { 50, 50 } } } },
		},
		areas = { [10] = 10, [20] = 20, [30] = 30 },
	},
})
local G, ns = c.G, c.ns

c.maps = {
	[0] = { mapID = 10, name = "Darkshire" },
	[2] = { mapID = 20, name = "Zephras Isle" },
	[3] = { mapID = 30, name = "The Barrens" },
}

-- The game's tooltip: it keeps its lines and its script hooks. A read of its geometry fails the spec, as the
-- sizes come back secret from the recipe list (#161).
local lines, hooks = {}, {}
local tooltip = setmetatable({
	GetName = function()
		return "GameTooltip"
	end,
	SetOwner = function(self)
		lines = {}
		for _, hook in ipairs(hooks.OnTooltipCleared or {}) do
			hook(self)
		end
	end,
	AddLine = function(_, text)
		lines[#lines + 1] = text
		G["GameTooltipTextLeft" .. #lines] = rawget(G, "GameTooltipTextLeft" .. #lines) or { line = #lines }
	end,
	AddDoubleLine = function(self, left)
		self:AddLine(left)
	end,
	SetPoint = function() end,
	SetMinimumWidth = function() end,
	HookScript = function(_, script, fn)
		hooks[script] = hooks[script] or {}
		table.insert(hooks[script], fn)
	end,
	Show = function() end,
	IsForbidden = function()
		return false
	end,
}, {
	__index = function(_, key)
		error("the recipe tooltip read the tooltip's " .. key)
	end,
})
G.GameTooltip = tooltip
G.GameTooltip_InsertFrame = function()
	error("GameTooltip_InsertFrame measures the tooltip, and its sizes can be secret")
end
G.GameTooltip_SetTitle = function(_, text)
	tooltip:AddLine(text)
end
G.GameTooltip_AddColoredLine = function(_, text)
	tooltip:AddLine(text)
end
G.GameTooltip_AddDisabledLine = G.GameTooltip_AddColoredLine
G.GameTooltip_AddBlankLineToTooltip = function()
	tooltip:AddLine(" ")
end
G.HIGHLIGHT_FONT_COLOR, G.RED_FONT_COLOR = {}, {}
G.C_Texture = {
	GetAtlasInfo = function()
		return nil
	end,
}
G.IsShiftKeyDown = function()
	return false
end
G.ProfessionsFrame = { ProfessionsOverviewTab = {} }
G.Professions = {
	GetProfessionInfo = function()
		return { skillLevel = 40, maxSkillLevel = 75, displayName = "First Aid" }
	end,
	GetHighestLearnedRecipe = function() end,
}

c.items[LINEN] = { name = "Linen Cloth" }
c.items[THREAD] = { name = "Spider Silk" }
c.items[SILK] = { name = "Silk Cloth" }
c.items[BUFF_ITEM] = { name = "Elixir of Wisdom", sell = 3 }
c.items[PLAIN_ITEM] = { name = "Plain Bandage", sell = 3 }
c.items[THIRD_ITEM] = { name = "Third Elixir", sell = 3 }
c.spells[BUFF_SPELL] = BUFF_NAME
c.spellDescriptions[BUFF_SPELL] = BUFF_DESCRIPTION
c.spellCached[BUFF_SPELL] = true
c.tradeSkillNames[FIRST_AID] = "First Aid"
c.tradeSkillNames[ALCHEMY] = "Alchemy"
c.known[BUFF_RECIPE] = true
c.professions = { { name = "First Aid", rank = 40, max = 75, id = FIRST_AID } }
c.Boot()
c.EnterWorld()
c.Advance(0)

local row = {}
---@param recipeID integer
---@param name string
local function Show(recipeID, name)
	ns.ShowRecipeTooltip(ns, row, { recipeInfo = { recipeID = recipeID, name = name, learned = true } })
end

---@param text string
---@return integer?
local function Index(text)
	for index, line in ipairs(lines) do
		if line == text then
			return index
		end
	end
end

---@param text string
---@return boolean
local function Has(text)
	return Index(text) ~= nil
end

--[[ A buff recipe: the buff in the game's own words, and where its reagent drops ]]

local BUFF_TEXT = BUFF_NAME .. ": " .. BUFF_DESCRIPTION
Show(BUFF_RECIPE, "Elixir of Wisdom")
equal(lines[1], "Elixir of Wisdom", "the title")
equal(Has(BUFF_TEXT), true, "the buff in the game's own words")
equal(Has("Linen Cloth drops in Darkshire"), false, "no zone is named until Questie has been read")

c.Advance(0)
Show(BUFF_RECIPE, "Elixir of Wisdom")
equal(Has(BUFF_TEXT), true, "the buff stays on the tooltip")
equal(Has("Linen Cloth drops in Darkshire"), true, "the nearest dropper's zone is named")
equal(Has("Linen Cloth drops in Zephras Isle"), false, "not the far dropper's zone, whoever drops it")
equal((Index(BUFF_TEXT) or 0) < (Index("Linen Cloth drops in Darkshire") or 0), true, "the buff comes first")

-- A recipe whose product leaves no buff says neither.
Show(PLAIN_RECIPE, "Plain Bandage")
equal(Has(BUFF_TEXT), false, "a plain recipe says nothing about a buff")
equal(Has("Linen Cloth drops in Darkshire"), false, "nor where its reagents drop")

--[[ A spell the client has not loaded: its name alone, then its description once it arrives ]]

c.spellCached[BUFF_SPELL] = false
local changed = 0
local realChanged = ns.Changed
ns.Changed = function(kind)
	if kind == "names" then
		changed = changed + 1
	end
	return realChanged(kind)
end
Show(BUFF_RECIPE, "Elixir of Wisdom")
equal(Has(BUFF_NAME), true, "an unloaded spell gives its name alone")
equal(Has(BUFF_TEXT), false, "with no description to show")
Show(BUFF_RECIPE, "Elixir of Wisdom")
equal(#(c.spellLoads[BUFF_SPELL] or {}), 1, "the client is asked for the spell once, however many tooltips wait")
equal(changed, 0, "nothing has changed yet")
c.LoadSpellData(BUFF_SPELL)
equal(changed, 1, "the description arriving redraws the tooltips that showed the name")
Show(BUFF_RECIPE, "Elixir of Wisdom")
equal(Has(BUFF_TEXT), true, "and the next tooltip has the game's own description")

--[[ A buff consumable's own tooltip: the profession and skill that make it ]]

local drawn = {}
local itemTooltip = {
	IsForbidden = function()
		return false
	end,
	AddDoubleLine = function(_, left)
		drawn[#drawn + 1] = left
	end,
}
G.GameTooltip_AddNormalLine = function(_, text)
	drawn[#drawn + 1] = text
end
G.GameTooltip_AddBlankLineToTooltip = function()
	drawn[#drawn + 1] = " "
end
local itemPost = c.postCalls[G.Enum.TooltipDataType.Item][#c.postCalls[G.Enum.TooltipDataType.Item]]

local function ItemLines(itemID)
	drawn = {}
	itemPost(itemTooltip, { id = itemID })
	return drawn
end

local made = ItemLines(BUFF_ITEM)
equal(made[1], " ", "the maker line has a blank line above it")
equal(made[2], "Made by First Aid 30", "the maker with the lowest skill range start names its profession and skill")

c.SetSetting("reagentTooltip", "full")
made = ItemLines(BUFF_ITEM)
equal(made[2], "Made by First Aid 30", "the full tooltip puts the maker line first too")

-- A maker the bundle has no thresholds for names only its profession.
local untrained = ItemLines(THIRD_ITEM)
equal(untrained[2], "Made by First Aid", "without thresholds the line names the profession alone")

-- An item that leaves no buff has no maker line.
equal(#ItemLines(PLAIN_ITEM), 0, "a plain item has no made-by line")

--[[ Where the droppers are when none can be ranked: one shared zone map, or nothing ]]

equal(ns.DropZone(THREAD), nil, "nothing drops in a zone until its droppers are read")
c.Advance(0)
equal(ns.DropZone(THREAD), nil, "two far droppers in different zones name none of them")
equal(ns.DropZone(SILK), nil, "whose droppers are read in turn")
c.Advance(0)
equal(ns.DropZone(SILK), "Zephras Isle", "two far droppers in one zone map name that zone")

Client.report("buff_tooltip_spec")
