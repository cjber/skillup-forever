-- Run from the repository root: luajit tests/recipe_tooltip_spec.lua
-- The recipe list's tooltip and its skill bar. Blizzard's GameTooltip_InsertFrame measured the tooltip to fit
-- the bar in, and from our handler those measurements were secret: "attempt to perform arithmetic on a secret
-- number value", blamed on SkillUp (#161). The bar goes in on our own blank lines, hangs from a line we know,
-- and nothing reads the tooltip's size, line count or spacing.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local BANDAGE, LINEN, BANDAGE_ITEM = 1, 3, 50
local TRAINED, SCROLLED, SCROLL_ITEM = 2, 4, 51

local c = Client.load({
	boot = false,
	data = {
		Thresholds = {
			[BANDAGE] = { 1, 30, 45, 60 },
			[TRAINED] = { 1, 25, 50, 75 },
			[SCROLLED] = { 1, 30, 45, 60 },
		},
		RecipeData = {
			[BANDAGE] = {
				skillLine = 129,
				reagents = { { itemID = LINEN, quantity = 1 } },
				output = { itemID = BANDAGE_ITEM, quantity = 1 },
			},
			[TRAINED] = {
				skillLine = 129,
				reagents = { { itemID = LINEN, quantity = 2 } },
				output = { itemID = BANDAGE_ITEM, quantity = 1 },
			},
			[SCROLLED] = {
				skillLine = 129,
				reagents = { { itemID = LINEN, quantity = 1 } },
				output = { itemID = BANDAGE_ITEM, quantity = 1 },
			},
		},
		TrainerFees = { [TRAINED] = { 10, 40 } },
		RecipeScrolls = { [SCROLLED] = { SCROLL_ITEM, 45 } },
		TrainerRanks = { [129] = {} },
		ItemSellPrices = {},
		GatheredBy = {},
		VendorPrices = { [LINEN] = 10 },
		ProfessionTrainers = {},
	},
})
local G, ns = c.G, c.ns

-- The game's tooltip: it keeps its lines, the font string each line is drawn in and its script hooks. A read
-- of its geometry, line count or spacing fails the spec: those are what came back secret.
local lines, hooks = {}, {}
local doubleLines = {}
local minimumWidth, owner, points
local tooltip = setmetatable({
	GetName = function()
		return "GameTooltip"
	end,
	SetOwner = function(self, frame, anchor)
		owner, points, lines, doubleLines = { frame, anchor }, {}, {}, {}
		for _, hook in ipairs(hooks.OnTooltipCleared or {}) do
			hook(self)
		end
	end,
	AddLine = function(_, text)
		lines[#lines + 1] = text
		G["GameTooltipTextLeft" .. #lines] = rawget(G, "GameTooltipTextLeft" .. #lines) or { line = #lines }
	end,
	AddDoubleLine = function(self, left, right)
		doubleLines[#doubleLines + 1] = { left, right }
		self:AddLine(left)
	end,
	SetPoint = function(_, ...)
		points[#points + 1] = { ... }
	end,
	SetMinimumWidth = function(_, width)
		minimumWidth = width
	end,
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
G.GameTooltip_SetTitle = function(self, text)
	self:AddLine(text)
end
G.GameTooltip_AddColoredLine = function(self, text)
	self:AddLine(text)
end
G.GameTooltip_AddDisabledLine = G.GameTooltip_AddColoredLine
G.GameTooltip_AddBlankLineToTooltip = function(self)
	self:AddLine(" ")
end
G.HIGHLIGHT_FONT_COLOR, G.RED_FONT_COLOR = {}, {}
G.C_CurrencyInfo = {
	GetCoinTextureString = function(copper)
		return tostring(copper)
	end,
}
G.C_Texture = {
	GetAtlasInfo = function()
		return nil
	end,
}
-- The Professions window and its first side tab, on the window's right edge.
local overviewTab = {}
G.ProfessionsFrame = { ProfessionsOverviewTab = overviewTab }
G.Professions = {
	GetProfessionInfo = function()
		return { skillLevel = 20, maxSkillLevel = 75, displayName = "First Aid" }
	end,
	GetHighestLearnedRecipe = function() end,
}

c.items[LINEN] = { name = "Linen Cloth" }
c.items[BANDAGE_ITEM] = { name = "Linen Bandage", sell = 3 }
c.known[BANDAGE] = true
c.professions = { { name = "First Aid", rank = 20, max = 75, id = 129 } }
c.Boot()
c.EnterWorld()
c.Advance(0)

-- Every frame the addon made, so the bar can be found once the tooltip has made it.
local made = {}
for _, frame in ipairs(c.frames) do
	made[frame] = true
end

local row = {}
local recipe = { recipeID = BANDAGE, name = "Linen Bandage", learned = true }
ns.ShowRecipeTooltip(ns, row, { recipeInfo = recipe })

equal(lines[1], "Linen Bandage", "the title")
equal(lines[2], "Skill range starts at 1", "the line above the bar")
local blanks = 0
while lines[2 + blanks + 1] == " " do
	blanks = blanks + 1
end
-- 10 for the bar, 30 for its labels and 4 above it, at 14 a line.
equal(blanks, 4, "the bar has four blank lines of its own")
equal(lines[2 + blanks + 1]:match("^Skill%-up chance") ~= nil, true, "and the chance follows them")
equal(minimumWidth, 250, "the tooltip is at least as wide as the bar")

-- The bar is the first frame the tooltip made.
local bar
for _, frame in ipairs(c.frames) do
	bar = bar or (not made[frame] and frame or nil)
end
equal(bar ~= nil, true, "the tooltip makes its bar")
equal(bar:IsShown(), true, "and shows it")

-- Put into the tooltip and anchored to the first blank line, a line the addon added rather than one it read.
local anchors, parent = {}, nil
bar.SetPoint = function(_, point, relative, ...)
	anchors[#anchors + 1] = { point, relative, ... }
end
bar.SetParent = function(_, frame)
	parent = frame
end
ns.ShowRecipeTooltip(ns, row, { recipeInfo = recipe })
equal(parent, tooltip, "the bar is put into the tooltip")
equal(#anchors, 1, "the bar has one anchor")
equal(anchors[1][1], "TOPLEFT", "at its top left")
equal(anchors[1][2], G.GameTooltipTextLeft3, "on the first blank line, after the title and the line above")
equal(anchors[1][5], -4, "four below its top")
equal(#hooks.OnTooltipCleared, 1, "the tooltip's clearing is hooked once, however often it shows")

-- Cleared for something else, the tooltip loses the bar.
tooltip:SetOwner({}, "ANCHOR_RIGHT")
equal(bar:IsShown(), false, "a cleared tooltip hides the bar")

-- Where the tooltip goes (#163): beside the window by default, past its side tabs, so it never covers the
-- reagents; at the cursor; or next to the recipe row, as before.
equal(ns.db.recipeTooltip, "window", "the tooltip goes beside the window by default")
ns.ShowRecipeTooltip(ns, row, { recipeInfo = recipe })
equal(owner[1], row, "the row owns it, so leaving the row hides it")
equal(owner[2], "ANCHOR_NONE", "placed by hand")
equal(#points, 1, "at one point")
equal(points[1][1], "TOPLEFT", "its top left")
equal(points[1][2], overviewTab, "beside the first side tab")
equal(points[1][3], "TOPRIGHT", "on its right")
c.SetSetting("recipeTooltip", "cursor")
ns.ShowRecipeTooltip(ns, row, { recipeInfo = recipe })
equal(owner[2], "ANCHOR_CURSOR", "at the cursor")
equal(#points, 0, "with no point of its own")
c.SetSetting("recipeTooltip", "row")
ns.ShowRecipeTooltip(ns, row, { recipeInfo = recipe })
equal(owner[1] == row and owner[2], "ANCHOR_RIGHT", "or next to the recipe row")

-- Issue #412: the recipe list sets the same recipe's tooltip again and again. The built lines, reagent
-- rows included, are kept by recipe id, so a repeated set draws them instead of building them again.
ns.Changed("recipes")
local builds = 0
local describe = ns.Describe
ns.Describe = function(...)
	builds = builds + 1
	return describe(...)
end
ns.ShowRecipeTooltip(ns, row, { recipeInfo = recipe })
ns.ShowRecipeTooltip(ns, row, { recipeInfo = recipe })
equal(builds, 1, "the same recipe's tooltip is built once, however often it is set")
ns.Describe = describe

-- An unlearned recipe the addon added gets the same tooltip, with where it is learned as well: its row
-- already carries the source, so the hover never rebuilds the unlearned list, the route or the prices.
local function HasLine(text)
	for _, line in ipairs(lines) do
		if line == text then
			return true
		end
	end
	return false
end
local rebuilt
ns.PlanRoute = function()
	rebuilt = "route"
end
ns.InitPrices = function()
	rebuilt = "prices"
end
ns.UnlearnedRecipes = function()
	rebuilt = "unlearned list"
end
ns.ShowRecipeTooltip(ns, row, {
	recipeInfo = {
		recipeID = TRAINED,
		name = "Unlearned Trainer",
		learned = false,
		skillUpUnlearned = {
			recipeID = TRAINED,
			name = "Unlearned Trainer",
			kind = "trainer",
			skill = 40,
			thresholds = { 1, 25, 50, 75 },
		},
	},
})
equal(lines[1], "Unlearned Trainer", "the added row keeps its title")
equal(HasLine("Skill range starts at 1"), true, "and its skill range")
equal(HasLine("Skill-up chance: 100%"), true, "the chance still colours the tooltip")
equal(HasLine("Not learned · Trainer 40"), true, "the tooltip says where it is learned and at what skill")
equal(HasLine("Linen Cloth x2"), true, "each reagent's count is listed")
local total
for _, pair in ipairs(doubleLines) do
	if pair[1] == "Reagents" then
		total = pair[2]
	end
end
equal(total, "20", "one craft's reagents are priced from the addon's sources")
equal(rebuilt, nil, "hovering rebuilds neither the route, the prices nor the unlearned list")

-- A recipe the client lists unlearned and the bundle places by a recipe item reads the same tables.
ns.ShowRecipeTooltip(ns, row, { recipeInfo = { recipeID = SCROLLED, name = "Unlearned Recipe Item", learned = false } })
equal(lines[1], "Unlearned Recipe Item", "the client's own unlearned row gets the tooltip too")
equal(HasLine("Not learned · Recipe item 45"), true, "with the recipe item and the skill it asks")

Client.report("recipe_tooltip_spec")
