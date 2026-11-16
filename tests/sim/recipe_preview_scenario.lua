-- luacheck: read globals scenario ADDON
local ForeverCore = dofile("tests/forever_core.lua")

local function RecipeRow(sim, recipeID)
	for _, row in ipairs(sim:recipeRows()) do
		if row.recipeInfo.recipeID == recipeID then
			return row.frame, row.recipeInfo
		end
	end
end

local function PreviewButton(row)
	for _, child in ipairs({ row:GetChildren() }) do
		if child:IsObjectType("Button") and child:IsVisible() and child:IsMouseClickEnabled() then
			return child
		end
	end
end

local function FindText(frame, excluded, text)
	if frame == excluded or not frame:IsShown() or frame:GetAlpha() == 0 then
		return nil
	end
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType("FontString") and region:IsShown() and (region:GetText() or ""):find(text, 1, true) then
			return region
		end
	end
	for _, child in ipairs({ frame:GetChildren() }) do
		local result = FindText(child, excluded, text)
		if result then
			return result
		end
	end
end

scenario("clicking an unlearned recipe previews it without changing the crafting selection", {
	addons = ForeverCore.addons(),
}, function(sim)
	local learned, unlearned = 2660, 2665
	local name = "Coarse Sharpening Stone"
	local previewName = name .. " (unlearned)"
	local tool = "Blacksmith Hammer"
	local hasToolRequirement, toolMet = true, true
	sim.world.professions = {
		{
			skillLineID = 164,
			name = "Blacksmithing",
			skill = 30,
			max = 75,
			categories = { { id = 1, name = "Materials" } },
			recipes = {
				{ id = learned, name = "Rough Sharpening Stone", category = 1, itemID = 2862 },
			},
		},
	}
	-- The client has spell, item and tool data. SkillUp's bundle supplies the unlearned row, its ingredient
	-- and the trainer requirement.
	sim.world.spells[unlearned] = { name = name }
	sim.items[2863] = { name = name, icon = 135248, sell = 20 }
	sim.items[2836] = { name = "Coarse Stone", link = "|Hitem:2836|h[Coarse Stone]|h", icon = 135236, count = 2 }
	sim.impl["C_TradeSkillUI.GetRecipeRequirements"] = function(recipeID)
		if recipeID == unlearned and hasToolRequirement then
			return { { type = sim.G.Enum.RecipeRequirementType.Totem, name = tool, met = toolMet } }
		end
		return {}
	end
	sim.impl["C_CurrencyInfo.GetCoinTextureString"] = function(copper)
		return copper .. " copper"
	end
	-- Mock the native color wrapper so the simulator retains the formatted amount and sign.
	sim.impl["C_ColorUtil.WrapTextInColor"] = function(text, color)
		return ("|c%02x%02x%02x%02x%s|r"):format(
			(color.a or 1) * 255,
			color.r * 255,
			color.g * 255,
			color.b * 255,
			text
		)
	end
	sim.G.AUCTIONATOR_L_TO_CRAFT_COLON = "To craft:"
	sim.G.AUCTIONATOR_L_PROFIT_COLON = "Profit:"
	local skinnedButton
	sim.G.EllesmereUI = {
		RegisterSkin = function(addon, apply)
			assert(addon == ADDON, "the Close button skin is registered under SkillUp")
			apply({
				Button = function(button)
					skinnedButton = button
				end,
			})
		end,
		GetBlizzWindowStyle = function(window)
			assert(window == "professions", "the preview uses the Professions skin setting")
			return "eui"
		end,
	}
	sim:login({ savedVariables = { SkillUpForeverDB = { showUnlearned = true, vendor = { [2836] = 45 } } } })

	local page = sim:openProfessions(164).CraftingPage
	local list, form = page.RecipeList, page.SchematicForm
	assert(sim.G.C_TradeSkillUI.GetRecipeInfo(unlearned) == nil, "the preview recipe is absent from the client")
	local learnedRow = assert(RecipeRow(sim, learned), "the learned recipe is listed")
	sim:click(learnedRow)
	assert(form:GetRecipeInfo().recipeID == learned, "the learned recipe occupies the crafting form")
	local learnedBand = assert(FindText(page, list, "You: 30"), "the learned recipe's skill band is visible")
	form.OutputText:SetFont("Fonts\\ARIALN.TTF", 19, "OUTLINE")
	-- Model another addon's reskin on the native schematic. The preview should reuse these layers.
	local background = form:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints(form)
	background:SetColorTexture(0.2, 0.3, 0.4, 1)
	local border = form:CreateTexture(nil, "BORDER")
	border:SetAllPoints(form)
	border:SetColorTexture(0.5, 0.6, 0.7, 1)
	local skinBackdrop = sim.G.CreateFrame("Frame", nil, form)
	skinBackdrop:SetAllPoints(form)
	local skinLayer = sim.G.CreateFrame("Frame", nil, skinBackdrop)
	skinLayer:SetAllPoints(skinBackdrop)
	local skinFill = skinLayer:CreateTexture(nil, "BACKGROUND")
	skinFill:SetAllPoints(skinLayer)
	skinFill:SetColorTexture(0.15, 0.22, 0.29, 1)
	local styleAlphas = {
		[form] = 0.8,
		[skinBackdrop] = 0.65,
		[form.NineSlice] = 0.9,
		[background] = 0.7,
		[border] = 0.6,
	}
	for region, alpha in pairs(styleAlphas) do
		region:SetAlpha(alpha)
	end
	local function AssertNativeStyle()
		for region, alpha in pairs(styleAlphas) do
			assert(region:GetAlpha() == alpha, "the native pane and its decoration keep their original alpha")
		end
		assert(background:GetEffectiveAlpha() > 0, "the schematic background is visible")
		assert(border:GetEffectiveAlpha() > 0, "the schematic border is visible")
		assert(skinFill:GetEffectiveAlpha() > 0, "a texture in a custom backdrop frame is visible")
	end
	local nativeAlphas = {
		[form.OutputText] = 0.6,
		[page.CreateButton] = 0.9,
		[page.CreateAllButton] = 1,
		[page.CreateMultipleInputBox] = 0.7,
	}
	for frame, alpha in pairs(nativeAlphas) do
		frame:SetAlpha(alpha)
	end
	local function AssertNativeRestored()
		AssertNativeStyle()
		for region, alpha in pairs(nativeAlphas) do
			assert(region:GetAlpha() == alpha, "native recipe content and controls recover their previous alpha")
		end
		assert(form.OutputIcon:IsVisible() and form.OutputIcon:GetEffectiveAlpha() > 0, "the learned output is visible")
		assert(learnedBand:IsVisible() and learnedBand:GetEffectiveAlpha() > 0, "the learned skill band is visible")
	end
	AssertNativeRestored()

	local function PreviewPane()
		for _, child in ipairs({ page:GetChildren() }) do
			if FindText(child, list, name) then
				return child
			end
		end
	end

	local function OpenPreview()
		local row, info = RecipeRow(sim, unlearned)
		assert(row and info.skillUpUnlearned, "the bundled recipe is listed")
		assert(not row:IsMouseClickEnabled(), "the native unlearned row cannot select a crafting recipe")
		sim:click(assert(PreviewButton(row), "the unlearned row has its own preview click target"))
		sim:expectNoErrors(ADDON)
		local pane = assert(PreviewPane(), "the preview shows the recipe name in the details area")
		AssertNativeStyle()
		for _, region in ipairs({ pane:GetRegions() }) do
			assert(
				not region:IsObjectType("Texture") or region:GetDrawLayer() ~= "BACKGROUND",
				"the preview does not cover the native background with another texture"
			)
		end
		local create = page.CreateButton
		assert(create:IsShown(), "the learned recipe's native Create button remains laid out")
		local x, y = create:GetCenter()
		assert(pane:IsMouseClickEnabled(), "the preview catches clicks")
		assert(
			pane:GetFrameLevel() > create:GetFrameLevel(),
			string.format(
				"preview level %d must be above Create level %d",
				pane:GetFrameLevel(),
				create:GetFrameLevel()
			)
		)
		local left, right, bottom, top = pane:GetLeft(), pane:GetRight(), pane:GetBottom(), pane:GetTop()
		assert(
			x > left and x < right and y > bottom and y < top,
			string.format(
				"Create center (%g, %g) is outside the preview (%g, %g) to (%g, %g)",
				x,
				y,
				left,
				bottom,
				right,
				top
			)
		)
		local heading = assert(FindText(pane, nil, "Reagents:"), "the native reagent heading appears")
		assert(
			heading:GetText() == sim.G.PROFESSIONS_REAGENT_CONTAINER_LABEL,
			"the preview uses the native reagent heading"
		)
		local ingredient = assert(FindText(pane, nil, "2/1 Coarse Stone"), "the reagent count appears before its name")
		assert(ingredient:GetText() == "2/1 Coarse Stone", "the count and reagent name share the native-style label")
		local source = assert(FindText(pane, nil, "Trainer 40"), "the preview shows how to learn it")
		assert(source:GetText() == "Trainer 40", "the source line only shows how to learn the recipe")
		for region in pairs(nativeAlphas) do
			assert(region:GetAlpha() == 0, "native recipe content and controls cannot show through the preview")
		end
		assert(form.OutputIcon:GetEffectiveAlpha() == 0, "the learned output is absent from the preview")
		assert(learnedBand:GetEffectiveAlpha() == 0, "the learned recipe's skill band is absent from the preview")
		assert(form:GetRecipeInfo().recipeID == learned, "the native form still holds the learned recipe")
		return pane
	end

	local pane = OpenPreview()
	local cost = assert(FindText(pane, nil, "To craft:"), "the preview uses the Auctionator crafting cost caption")
	local profit = assert(FindText(pane, nil, "Profit:"), "the preview shows profit when sale value is known")
	local loss = profit:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	assert(cost:GetText():find("45 copper", 1, true), "expected a 45 copper one-craft cost: " .. cost:GetText())
	assert(loss:find("Profit: -25 copper", 1, true), "expected a 25 copper loss: " .. loss)
	local close = assert(FindText(pane, nil, "Close"), "the preview has a Close button"):GetParent()
	assert(skinnedButton == close, "the preview's Close button uses the active Professions skin")
	assert(close:GetRight() == page.CreateButton:GetRight(), "the preview footer aligns with the native button")
	assert(close:GetBottom() == page.CreateButton:GetBottom(), "the preview footer sits at the native button height")
	sim:click(close)
	assert(not PreviewPane(), "the skinned footer closes the preview")
	assert(form:GetRecipeInfo().recipeID == learned, "the footer leaves the learned recipe selected")
	AssertNativeRestored()
	pane = OpenPreview()
	local scroll = pane.Scroll
	assert(scroll:IsObjectType("ScrollFrame") and scroll.ScrollBar == nil, "the preview viewport has no scrollbar")
	for _, child in ipairs({ pane:GetChildren() }) do
		assert(not (child.Track and child.Track.Thumb), "the preview has no separate scrollbar")
	end
	local body = scroll:GetScrollChild()
	body:SetHeight(scroll:GetHeight() + 96)
	local wheel = assert(scroll:GetScript("OnMouseWheel"), "long recipes can still be scrolled with the mouse wheel")
	sim:input(wheel, scroll, -1)
	assert(scroll:GetVerticalScroll() > 0, "the wheel moves through overflowing recipe details")
	sim:input(wheel, scroll, -100)
	assert(scroll:GetVerticalScroll() == scroll:GetVerticalScrollRange(), "scrolling stops at the bottom of the recipe")
	sim:input(wheel, scroll, 100)
	assert(scroll:GetVerticalScroll() == 0, "scrolling back stops at the top of the recipe")

	local title = assert(FindText(pane, nil, previewName), "the preview title includes its unlearned status")
	assert(title:GetText() == previewName, "the unlearned status is part of the recipe title")
	local file, height, flags = title:GetFont()
	assert(file == "Fonts\\ARIALN.TTF" and height == 19 and flags == "OUTLINE", "the preview inherits the live font")
	local output = title:GetParent().Button
	assert(output:GetTop() == form.OutputIcon:GetTop(), "the output icon matches the native top inset")
	local firstLineY = title:GetTop() - title:GetLineHeight() / 2
	local _, nativeTitleY = form.OutputText:GetCenter()
	assert(math.abs(firstLineY - nativeTitleY) < 0.01, "the first title line matches the native height")
	assert(output.CircleMask and not output:IsMouseClickEnabled(), "the preview output uses the native read-only icon")
	assert(output.Icon:GetTexture() == 135248, "the native output button shows the crafted item icon")
	-- The output template centers its rim on the item. The simulator can leave the texture's own anchors unresolved.
	local ring = output.IconBorder
	local x, y = output:GetCenter()
	local halfWidth, halfHeight = ring:GetWidth() / 2, ring:GetHeight() / 2
	assert(halfWidth > output.Icon:GetWidth() / 2, "the native rim extends beyond the item texture")
	assert(
		x - halfWidth >= scroll:GetLeft()
			and x + halfWidth <= scroll:GetRight()
			and y + halfHeight <= scroll:GetTop()
			and y - halfHeight >= scroll:GetBottom(),
		"the output icon border fits inside the preview viewport"
	)
	local bar = assert(FindText(pane, nil, "You: 30")):GetParent()
	local barLeft, barBottom, _, barHeight = bar:GetScaledRect()
	local titleLeft, titleBottom = title:GetScaledRect()
	assert(math.abs(barLeft - titleLeft) < 0.01, "the skill bar aligns with the title")
	local requirements = assert(FindText(pane, nil, tool), "the required tool is visible")
	local _, requirementsBottom, _, requirementsHeight = requirements:GetScaledRect()
	assert(requirementsBottom + requirementsHeight <= titleBottom, "the required tool appears below the title")
	local barTopWithRequirement = barBottom + barHeight
	assert(barTopWithRequirement <= requirementsBottom, "the required tool appears above the skill bar")
	assert(bar:IsShown(), "the skill bar is visible when enabled")
	local metRequirements = requirements:GetText()
	toolMet = false
	sim:tick(0.1)
	local missingTool = sim.G.RED_FONT_COLOR:WrapTextInColorCode(tool)
	assert(requirements:GetText():find(missingTool, 1, true), "station range refreshes without a bag or list event")
	toolMet = true
	sim:tick(0.1)
	assert(requirements:GetText() == metRequirements, "returning to station range clears the missing requirement color")
	toolMet = false
	sim.G.SkillUpForeverDB.detailsBar = false
	sim:event("BAG_UPDATE_DELAYED")
	assert(not bar:IsShown(), "the preview obeys the thresholds bar setting")
	assert(requirements:GetText():find(missingTool, 1, true), "the preview highlights the missing tool")
	sim.G.SkillUpForeverDB.detailsBar = true
	sim:event("BAG_UPDATE_DELAYED")
	assert(bar:IsShown(), "turning the setting back on restores the thresholds")
	local reagent = assert(FindText(pane, nil, "2/1 Coarse Stone")):GetParent()
	assert(
		reagent.Button.SlotBackground and not reagent.Button:IsMouseClickEnabled(),
		"the preview reagent uses the native read-only slot"
	)
	assert(reagent.Button.Icon:GetTexture() == 135236, "the native reagent slot shows the reagent icon")
	assert(not reagent.Button.Count:IsShown(), "the icon has no overlapping count")
	sim:hover(reagent)
	local tooltip = assert(sim.G.SkillUpForeverRecipePreviewTooltip, "the preview owns its reagent tooltip")
	assert(tooltip:IsShown() and tooltip:IsOwned(reagent), "the reagent shows its item tooltip")
	for field, slot in pairs(sim.taint.slots[sim.G.GameTooltip] or {}) do
		assert(slot.addon ~= ADDON, "the preview reagent wrote to Blizzard's tooltip: " .. tostring(field))
	end
	sim:leave()
	local lateArtwork = form:CreateTexture(nil, "ARTWORK")
	lateArtwork:SetAllPoints(form)
	lateArtwork:SetColorTexture(0.8, 0.2, 0.1, 1)
	lateArtwork:SetAlpha(0.5)
	nativeAlphas[lateArtwork] = lateArtwork:GetAlpha()
	sim.items[2836].count = 0
	hasToolRequirement = false
	sim:event("BAG_UPDATE_DELAYED")
	assert(FindText(pane, nil, "0/1 Coarse Stone"), "the preview refreshes the count in the reagent label")
	assert(not FindText(pane, nil, tool), "the preview hides the requirements line without a required tool")
	local _, barBottomWithoutRequirement, _, barHeightWithoutRequirement = bar:GetScaledRect()
	local barTopWithoutRequirement = barBottomWithoutRequirement + barHeightWithoutRequirement
	assert(barTopWithoutRequirement <= titleBottom, "the skill bar stays below the title")
	assert(barTopWithoutRequirement > barTopWithRequirement, "the skill bar moves up without a required tool")
	assert(lateArtwork:GetEffectiveAlpha() == 0, "content added during a preview is masked on refresh")
	AssertNativeStyle()
	sim.items[2836].count = 2
	-- The client emits its selection-changed event only for a different recipe ID.
	learnedRow = assert(RecipeRow(sim, learned), "the learned row is still present")
	sim:click(learnedRow)
	assert(not FindText(page, list, name), "clicking the already-selected learned row dismisses the preview")
	assert(form:GetRecipeInfo().recipeID == learned, "the learned recipe is available for crafting again")
	AssertNativeRestored()

	OpenPreview()
	sim:setGamepad(true)
	assert(not FindText(page, list, name), "switching to gamepad dismisses the mouse preview")
	assert(form:GetRecipeInfo().recipeID == learned, "the gamepad returns to the same native recipe")
	AssertNativeRestored()
	sim:setGamepad(false)
	OpenPreview()
	sim:closeProfessions()
	sim:openProfessions(164)
	assert(not PreviewPane(), "reopening Professions returns to the native pane")
	AssertNativeRestored()
	pane = OpenPreview()
	-- A schematic arriving after the preview opens must replace the bundled data.
	local getSchematic = sim.impl["C_TradeSkillUI.GetRecipeSchematic"]
	sim.impl["C_TradeSkillUI.GetRecipeSchematic"] = function(id, ...)
		if id ~= unlearned then
			return getSchematic(id, ...)
		end
		return {
			outputItemID = 2863,
			quantityMin = 2,
			quantityMax = 4,
			reagentSlotSchematics = {
				{
					reagentType = sim.G.Enum.CraftingReagentType.Basic,
					quantityRequired = 3,
					reagents = { { itemID = 2836 } },
				},
			},
		}
	end
	-- The older simulator's generated API omits this entry exposed by Forever.
	sim.G.C_TradeSkillUI.GetAllRecipeIDs = function()
		return { learned, unlearned }
	end
	sim:event("TRADE_SKILL_LIST_UPDATE")
	assert(FindText(pane, nil, "2/3 Coarse Stone"), "recipe invalidation redraws the live reagent amount")
	assert(output.Count:GetText() == "2-4", "the output icon shows the exact live yield range")
	sim:closeProfessions()
	sim:expectNoErrors(ADDON)
end)
