-- Run from the repository root: luajit tests/details_bar_spec.lua
-- The crafting page's own skill bar (#172): which recipe it draws, what it draws for that recipe at the player's
-- skill, and the setting that hides it. The frame itself is checked in game; this is the arithmetic around it,
-- and that the bar the tooltip and the details pane share lays out its bands, labels and pip the same for both.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local BANDAGE, LEARNED_BANDAGE, HEAVY = 1, 2, 3

-- The bar's art asks the client for these atlases; each is fitted at its own aspect.
local ATLASES = { ["Professions-skillbar-bg"] = { width = 451, height = 29 } }

local c = Client.load({
	data = {
		Thresholds = {
			[BANDAGE] = { 1, 30, 45, 60 },
			[LEARNED_BANDAGE] = { 35, 55, 70, 85 },
			[HEAVY] = { 80, 95, 110, 125 },
		},
		RecipeData = {
			[BANDAGE] = { skillLine = 129 },
			[LEARNED_BANDAGE] = { skillLine = 129 },
			[HEAVY] = { skillLine = 129 },
		},
		TrainerFees = {},
		TrainerRanks = { [129] = {} },
		ItemSellPrices = {},
		GatheredBy = {},
		VendorPrices = {},
		ProfessionTrainers = {},
	},
})
local G, ns = c.G, c.ns

G.C_Texture = {
	GetAtlasInfo = function(atlas)
		return ATLASES[atlas] or { width = 10, height = 14 }
	end,
}
G.Professions = {
	GetProfessionInfo = function()
		return { skillLevel = 40, maxSkillLevel = 300, displayName = "First Aid" }
	end,
	-- Blizzard's own pick: the higher rank of a recipe this character has learned.
	GetHighestLearnedRecipe = function(info)
		return info and info.higher or nil
	end,
}

-- The details bar is on until it is turned off.
equal(ns.DEFAULTS.detailsBar, true, "the details bar is on by default")
equal(ns.db.detailsBar, true, "and a fresh character starts with it on")

-- What it draws: the four thresholds and the player's skill, or nothing when there is no skill data to draw.
local t, skill = ns.DetailsBar({ 1, 30, 45, 60 }, 40)
equal(t and t[3], 45, "the recipe's thresholds")
equal(skill, 40, "and the player's skill")
equal(ns.DetailsBar(nil, 40), nil, "no thresholds, no bar")
equal(ns.DetailsBar({ 1, 30, 45, 60 }, nil), nil, "no skill, no bar")
equal(ns.DetailsBar({ 1, 30, 45 }, 40), nil, "a threshold set of the wrong size is no bar")

-- Which recipe: the selected one, or the higher rank of it this character has learned, as the tooltip draws it.
local base = { recipeID = BANDAGE }
local higher = { recipeID = LEARNED_BANDAGE }
base.higher = higher
equal(ns.DetailsBarRecipe(base), LEARNED_BANDAGE, "the highest learned rank of the selected recipe")
equal(ns.DetailsBarRecipe(higher), LEARNED_BANDAGE, "which is the recipe itself when that is the highest")
equal(ns.DetailsBarRecipe({ recipeID = HEAVY }), HEAVY, "a recipe with no higher rank is drawn as it is")
equal(ns.DetailsBarRecipe(nil), nil, "nothing selected, no recipe")

local ctx = ns.SkillContext()
equal(ctx and ctx.skill, 40, "the player's live skill")
t, skill = ns.DetailsBar(ns.Model.Get(LEARNED_BANDAGE), ctx and ctx.skill)
equal(t[4], 85, "the learned rank's grey")
equal(skill, 40, "at the skill the window reports")

-- Where the bar hangs: under the recipe's name and description, inside the details pane's art.
equal(ns.DetailsBarTop() <= -60, true, "the bar sits past the details pane's top, under the recipe")

-- The tooltip's bar and the details pane's are one drawing: one function lays out a bar of either caller's
-- making, over [orange, grey + tail] as the tooltip always has.
local made = ns.CreateSkillBar()
equal(made:IsShown(), false, "a made bar starts hidden, for its caller to place and show")
equal(#made.segments, 4, "with a band per difficulty")
equal(#made.labels, 4, "and a label per threshold")
equal(ns.LayoutSkillBar(made, t, skill) == made, true, "laying it out keeps the frame it is given")
equal(made.labels[1].text, tostring(t[1]), "the first label is the range's start")
equal(made.labels[4].text, tostring(t[4]), "the last its grey")
equal(made.you.text, "You: 40", "and the player's skill is named at the bar")

-- The bands run left to right in difficulty order, each as wide as its stretch of the thresholds and never
-- past the frame; the tail past grey keeps the grey band and the pip in view once the recipe is grey.
local edges = { t[1], t[2], t[3], t[4] }
for index = 1, 3 do
	equal(edges[index] < edges[index + 1], true, "threshold " .. index .. " is below the next")
end
local lefts = {}
for index, segment in ipairs(made.segments) do
	lefts[index] = segment.points[1][4]
	equal((segment.width or 0) > 0, true, "band " .. index .. " is drawn")
	equal(
		lefts[index] >= 0 and lefts[index] + (segment.width or 0) <= 250,
		true,
		"band " .. index .. " stays in the bar"
	)
end
for index = 2, 4 do
	equal(lefts[index] >= lefts[index - 1], true, "band " .. index .. " starts at or after the one before")
end
-- The pip's x is where the player's skill falls between the first threshold and the grey's tail.
local tail = t[4] + math.max(3, math.floor((t[4] - t[1]) * 0.12 + 0.5))
local expected = (40 - t[1]) / (tail - t[1]) * 250
equal(math.abs(made.marker.points[1][4] - expected) < 0.001, true, "the pip sits at the player's skill")

-- A skill past every threshold is still placed: the bar is the frame's, not the recipe's.
ns.LayoutSkillBar(made, t, 300)
equal(made.marker.points[1][4], 250, "past grey, the pip waits at the bar's end")

Client.report("details_bar_spec")
