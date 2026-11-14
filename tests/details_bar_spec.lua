-- Run from the repository root: luajit tests/details_bar_spec.lua
-- The crafting page's own skill bar (#172): which recipe it draws, what it draws for that recipe at the player's
-- skill, and the setting that hides it. The frame itself is checked in game; this is the arithmetic around it,
-- and that the bar the tooltip and the details pane share lays out its bands, labels and pip the same for both.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local BANDAGE, LEARNED_BANDAGE, HEAVY = 1, 2, 3

-- The bar's art asks the client for these atlases; each is fitted at its own aspect. The band fill is the
-- cooldown manager's 124 by 10 atlas, drawn at its native height.
local ATLASES = { ["Professions-skillbar-bg"] = { width = 451, height = 29 } }
local BAND_ATLAS = "UI-HUD-CoolDownManager-Bar"
local BAND_HEIGHT = 10
local BAR_FILL_WIDTH = 439 * 10 / 18

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

local description = { shown = true, text = "Craft a Basic Campfire." }
function description:IsShown()
	return self.shown
end
function description:GetText()
	return self.text
end
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
	equal(segment.atlas, BAND_ATLAS, "band " .. index .. " draws the cooldown manager fill")
	equal(segment.height, BAND_HEIGHT, "band " .. index .. " is the atlas's native height")
	equal((segment.width or 0) > 0, true, "band " .. index .. " is drawn")
	equal(
		lefts[index] >= 0 and lefts[index] + (segment.width or 0) <= BAR_FILL_WIDTH,
		true,
		"band " .. index .. " stays in the bar's fill"
	)
end
for index = 2, 4 do
	equal(lefts[index] >= lefts[index - 1], true, "band " .. index .. " starts at or after the one before")
end
-- The pip's x is where the player's skill falls between the first threshold and the grey's tail.
local tail = t[4] + math.max(3, math.floor((t[4] - t[1]) * 0.12 + 0.5))
local expected = (40 - t[1]) / (tail - t[1]) * BAR_FILL_WIDTH
equal(math.abs(made.marker.points[1][4] - expected) < 0.001, true, "the pip sits at the player's skill")

-- A skill past every threshold is still placed: the bar is the frame's, not the recipe's.
ns.LayoutSkillBar(made, t, 300)
equal(math.abs(made.marker.points[1][4] - BAR_FILL_WIDTH) < 0.001, true, "past grey, the pip waits at the fill's end")

-- Exercise the attached frame, not only the threshold arithmetic. New bars begin
-- hidden, so showing their parent alone must not count as showing the content.
local create = G.CreateFrame
local details
description.text = "Craft a Basic Campfire."
-- The pane's own frames around the bar, in the pane's coordinates (y grows upwards): the recipe icon, the
-- recipe's name and its optional tool line in the icon's column, and the reagent header beneath them.
local function paneFrame()
	local child = create("Frame", nil, nil)
	child.shown = true
	return child
end
local outputText = paneFrame()
outputText.left, outputText.top, outputText.height = 89, 600, 14
local tools = paneFrame()
tools.left, tools.top, tools.height = 89, 588, 12
tools.shown = false
local reagents = paneFrame()
reagents.left, reagents.top, reagents.height = 27, 520, 20
local form = {
	Description = description,
	OutputText = outputText,
	RequiredTools = tools,
	Reagents = reagents,
	GetRecipeInfo = function()
		return higher
	end,
}
G.CreateFrame = function(...)
	local result = create(...)
	if not details then
		details = result
	end
	return result
end
G.ProfessionsFrame = {
	CraftingPage = {
		SchematicForm = form,
	},
}
local function selectRecipe()
	for _, callback in ipairs(c.callbacks["ProfessionsRecipeListMixin.Event.OnRecipeSelected"]) do
		callback.callback(callback.owner, higher)
	end
end
ns.AttachDetailsBar()
equal(details:IsShown(), false, "a native recipe description suppresses the overlapping details container")
equal(
	details:GetHeight(),
	details.bar:GetHeight(),
	"the container is the bar's own height, so it measures what it draws"
)

-- With no description the bar sits under the recipe's name, in the name's own column: the client's frame is
-- the anchor, so it clears the icon and moves with the pane (#674). The old fixed TOPLEFT on the card overlapped
-- the icon's lower half and ran the "You" line into the reagents header.
description.text = ""
selectRecipe()
equal(details:IsShown(), true, "an empty native description restores the details container")
local anchorPoint = details.points[1]
equal(anchorPoint[1], "TOPLEFT", "the bar is anchored by its top left")
equal(anchorPoint[2], outputText, "under the recipe's own name")
equal(anchorPoint[3], "BOTTOMLEFT", "at the name's bottom left")
equal(anchorPoint[4], 0, "in the name's column")
equal(anchorPoint[5], -2, "one small gap under it")
equal(ns.DetailsBarAnchor(form), outputText, "the name is the anchor when the recipe needs no tool")
equal(
	ns.DetailsBarRoom(form, outputText, details.bar:GetHeight()),
	true,
	"the pane leaves room above the reagent header"
)

-- A recipe that requires a tool has the client's line drawn under the name; the bar goes under that instead.
tools.shown = true
selectRecipe()
equal(ns.DetailsBarAnchor(form), tools, "the tool line is the anchor when the recipe has one")
equal(details.points[1][2], tools, "and the bar is anchored under it")
equal(details:IsShown(), true, "with room left above the reagent header")
tools.shown = false

-- A pane that leaves no room keeps the bar hidden rather than covering the header.
reagents.top = 570
selectRecipe()
equal(ns.DetailsBarRoom(form, outputText, details.bar:GetHeight()), false, "no room above the header")
equal(details:IsShown(), false, "so the bar stays hidden instead of running into it")
reagents.top = 520
selectRecipe()
equal(details:IsShown(), true, "and comes back when the pane leaves room again")

-- The client lays the pane out after the recipe is picked: an unmeasured pane is not a reason to hide the bar.
outputText.GetBottom = function()
	return nil
end
equal(ns.DetailsBarRoom(form, outputText, details.bar:GetHeight()), nil, "an unlaid pane has no measurement")
selectRecipe()
equal(details:IsShown(), true, "so the bar draws where it belongs until the pane can be measured")
outputText.GetBottom = nil
selectRecipe()
equal(ns.DetailsBarRoom(form, outputText, details.bar:GetHeight()), true, "the laid out pane measures again")
equal(details:IsShown(), true, "and the bar stays under the name")

description.text = "Craft a Basic Campfire."
selectRecipe()
equal(details:IsShown(), false, "a repopulated native description suppresses the details container again")

Client.report("details_bar_spec")
