-- luacheck: read globals scenario ADDON
-- #674: the selected recipe's skill band is drawn in the details pane. On a recipe with no description it sat
-- over the lower half of the recipe icon and ran its "You" line into the client's Reagents header. The band now
-- anchors to the client's own recipe name and reagent header frames, so it clears both. This walks the player's
-- way there (open the Professions window on a recipe with no description) and measures the real frames under
-- Blizzard's UI source.
local ForeverCore = dofile("tests/forever_core.lua")

scenario("The selected recipe's skill band clears the recipe icon and the Reagents header", {
	addons = ForeverCore.addons(),
}, function(sim)
	sim.world.professions = {
		{
			skillLineID = 197,
			name = "Tailoring",
			skill = 93,
			max = 150,
			categories = { { id = 1, name = "Cloth" } },
			recipes = {
				{
					id = 12079,
					name = "Double-Stitched Woolen Shoulders",
					category = 1,
					itemID = 7048,
					reagents = { { 4338, 3 }, { 10290, 1 } },
				},
			},
		},
	}
	sim:login()
	local ns
	for _, entry in ipairs(sim.loader.addons) do
		if entry.name == ADDON then
			ns = entry.ns
		end
	end
	assert(ns, "the full addon namespace loaded")

	local frame = sim:openProfessions(197)
	local form = frame.CraftingPage.SchematicForm
	local band
	local function find(child)
		if child.bar ~= nil and child.nativeDescription ~= nil then
			band = child
			return
		end
		for _, grandchild in ipairs({ child:GetChildren() }) do
			find(grandchild)
		end
	end
	find(frame.CraftingPage)
	assert(band, "the selected recipe's band is attached to the crafting page")
	assert(band:IsShown(), "the band draws for a recipe with no description")
	assert((form.Description:GetText() or "") == "", "the recipe in this report has no native description")

	-- The two frames the report saw it cover: the recipe's icon above it and the client's Reagents header below.
	local icon, reagents = form.OutputIcon, form.Reagents
	assert(icon and reagents, "the client laid out the icon and the Reagents header")
	assert(
		band:GetLeft() >= icon:GetRight(),
		"the band starts to the right of the recipe icon: " .. band:GetLeft() .. " < " .. icon:GetRight()
	)
	assert(
		band:GetTop() <= form.OutputText:GetBottom(),
		"the band sits under the recipe's name, not over it: " .. band:GetTop() .. " > " .. form.OutputText:GetBottom()
	)
	assert(
		band:GetBottom() > reagents:GetTop(),
		"the band clears the Reagents header: " .. band:GetBottom() .. " <= " .. reagents:GetTop()
	)
	assert(
		band.bar.you:GetBottom() > reagents:GetTop(),
		"the 'You' line clears the Reagents header: " .. band.bar.you:GetBottom() .. " <= " .. reagents:GetTop()
	)
	assert(band:GetRight() <= form:GetRight(), "the band stays inside the details pane")
	assert(band.bar.you:GetText() == "You: 93", "the band names the player's skill")
end)
