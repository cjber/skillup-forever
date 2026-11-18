-- luacheck: read globals scenario ADDON
local ForeverCore = dofile("tests/forever_core.lua")

local function FindRecipeRow(sim, recipeID)
	for _, record in ipairs(sim:recipeRows()) do
		if record.recipeInfo.recipeID == recipeID then
			return record.frame, record.recipeInfo
		end
	end
end

local function FindClickTarget(sim, recipeID)
	local row, info = FindRecipeRow(sim, recipeID)
	if row then
		for _, child in ipairs({ row:GetChildren() }) do
			if child:IsObjectType("Button") and child:IsVisible() and child:IsMouseClickEnabled() then
				return child, row, info
			end
		end
	end
end

local function PreviewSelection(row)
	local native = row.SelectedOverlay
	local atlas = assert(native:GetAtlas(), "the native selection texture uses an atlas")
	for _, region in ipairs({ row:GetRegions() }) do
		if
			region ~= native
			and region:IsObjectType("Texture")
			and region:IsVisible()
			and region:GetEffectiveAlpha() > 0
			and region:GetAtlas() == atlas
		then
			local _, _, _, vertexAlpha = region:GetVertexColor()
			assert(vertexAlpha > 0, "the preview selection stays visible when the native texture is masked")
			return region
		end
	end
end

local function DisplaysText(frame, text)
	if not frame:IsVisible() then
		return false
	end
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType("FontString") and region:IsVisible() and region:GetText() == text then
			return true
		end
	end
	for _, child in ipairs({ frame:GetChildren() }) do
		if DisplaysText(child, text) then
			return true
		end
	end
	return false
end

scenario("unlearned recipe previews preserve native modified clicks and truncated names", {
	addons = ForeverCore.addons(),
}, function(sim)
	local learned, native, bundled = 2660, 91000, 2665
	local bundledName = "Coarse Sharpening Stone"
	local source = "Quest: A Blacksmith's Lesson"
	sim.world.professions = {
		{
			skillLineID = 164,
			name = "Blacksmithing",
			skill = 30,
			max = 75,
			categories = { { id = 1, name = "Materials" } },
			recipes = {
				{ id = learned, name = "Rough Sharpening Stone", category = 1, itemID = 2862 },
				{ id = native, name = "Quest Sharpening Stone", category = 1, learned = false },
			},
		},
	}
	sim.world.spells[bundled] = { name = bundledName }
	sim.impl["C_TradeSkillUI.GetRecipeSourceText"] = function(recipeID)
		return recipeID == native and source or ""
	end
	sim:login({ savedVariables = { SkillUpForeverDB = { showUnlearned = true, showTooltip = false } } })
	local page = sim:openProfessions(164).CraftingPage
	local form = page.SchematicForm
	assert(form:GetRecipeInfo().recipeID == learned, "the learned recipe is initially selected")

	local nativeClick, nativeRow, nativeInfo = FindClickTarget(sim, native)
	assert(
		nativeClick and nativeInfo.learned == false and not nativeInfo.skillUpUnlearned,
		"the client lists the recipe"
	)
	local bundledClick, bundledRow, bundledInfo = FindClickTarget(sim, bundled)
	assert(bundledClick and bundledInfo.skillUpUnlearned, "SkillUp supplies the other recipe")
	local binding, pasted, tracked
	sim.G.IsModifiedClick = function(action)
		return binding ~= nil and (action == nil or action == binding)
	end
	local link = sim.G.C_TradeSkillUI.GetRecipeInfo(native).hyperlink
	assert(link and link ~= "", "the client supplies a recipe link")
	sim.G.C_TradeSkillUI.GetRecipeLink = function(recipeID)
		assert(recipeID == native, "only the native row requests a recipe link")
		return link
	end
	sim.G.HandleModifiedItemClick = function(recipeLink)
		assert(recipeLink == link, "the native handler receives the exact recipe link")
		if binding == "CHATLINK" then
			pasted = recipeLink
			return true
		end
		return false
	end
	sim.impl["C_TradeSkillUI.IsRecipeTracked"] = function(recipeID, isRecraft)
		assert(recipeID == native and isRecraft == false, "the client checks tracking for the native recipe")
		return tracked or false
	end
	sim.impl["C_TradeSkillUI.SetRecipeTracked"] = function(recipeID, shouldTrack, isRecraft)
		assert(recipeID == native and isRecraft == false, "the client toggles tracking for the native recipe")
		tracked = shouldTrack
	end

	local learnedRow = assert(FindRecipeRow(sim, learned), "the learned row is visible")
	local learnedSelection = learnedRow.SelectedOverlay
	assert(learnedSelection:IsShown(), "the learned row has the native selection")
	learnedSelection:SetAlpha(0.75)

	local alpha = form.OutputText:GetAlpha()
	binding = "CHATLINK"
	sim:click(nativeClick)
	assert(pasted == link and tracked == nil, "chat link uses the native path without toggling tracking")
	assert(form.OutputText:GetAlpha() == alpha, "chat link leaves the learned pane visible")
	binding = "RECIPEWATCHTOGGLE"
	sim:click(nativeClick)
	assert(tracked == true, "the native row can be tracked")
	sim:click(nativeClick)
	assert(tracked == false, "the native row can be untracked")
	assert(form.OutputText:GetAlpha() == alpha, "tracking leaves the learned pane visible")
	sim:click(bundledClick)
	assert(form.OutputText:GetAlpha() == alpha, "a bundled row ignores modified clicks")

	binding = nil
	-- The native row reserves a single line for the name.
	bundledRow.Label:SetWordWrap(false)
	bundledRow.Label:SetWidth(1)
	assert(bundledRow.Label:IsTruncated(), "the bundled row has a truncated label")
	sim:hover(bundledClick)
	local tooltip = sim.G.GameTooltip
	assert(tooltip:IsShown() and tooltip:IsOwned(bundledRow), "the native full-name tooltip appears")
	assert(
		tooltip:NumLines() == 1 and sim.G.GameTooltipTextLeft1:GetText() == bundledName,
		"the tooltip gives the full name"
	)
	sim:leave()
	assert(not tooltip:IsShown(), "leaving the row clears its tooltip")

	-- The client can include a texture's alpha in its vertex color. The simulator tracks them separately.
	local textureMethods = sim.widgets.methods.Texture
	local getVertexColor = textureMethods.GetVertexColor
	textureMethods.GetVertexColor = function(texture)
		local r, g, b, a = getVertexColor(texture)
		return r, g, b, a * texture:GetAlpha()
	end

	sim:click(nativeClick)
	assert(form.OutputText:GetAlpha() == 0, "a plain click still opens the preview")
	assert(DisplaysText(page, source), "the preview shows the recipe's source from the client")
	assert(form:GetRecipeInfo().recipeID == learned, "the learned recipe remains selected")
	assert(
		learnedSelection:IsShown() and learnedSelection:GetAlpha() == 0,
		"the learned selection artwork is masked without changing the native selection"
	)
	assert(not nativeRow.SelectedOverlay:IsShown(), "the preview does not toggle Blizzard's row selection")
	local selection = assert(PreviewSelection(nativeRow), "the preview draws its own native-style selection")
	local left, bottom, width, height = nativeRow.SelectedOverlay:GetRect()
	local x, y, w, h = selection:GetRect()
	assert(left and bottom and width and height, "the native selection has a rectangle")
	assert(x == left and y == bottom and w == width and h == height, "the preview matches the native selection bounds")
	assert(not PreviewSelection(bundledRow), "only the active preview row has selection artwork")

	bundledClick, bundledRow = FindClickTarget(sim, bundled)
	sim:click(assert(bundledClick, "the bundled row is still available"))
	assert(not PreviewSelection(nativeRow), "switching previews clears the previous highlight")
	assert(PreviewSelection(bundledRow), "switching previews highlights the new row")
	assert(learnedSelection:GetAlpha() == 0, "the learned highlight stays masked between previews")

	sim:click(learnedRow)
	assert(not PreviewSelection(bundledRow), "closing the preview clears its highlight")
	assert(learnedSelection:IsShown() and learnedSelection:GetAlpha() == 0.75, "the native highlight is restored")
	assert(form.OutputText:GetAlpha() == alpha, "clicking the learned row restores its details")
	sim:closeProfessions()
	sim:expectNoErrors(ADDON)
end)
