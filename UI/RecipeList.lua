---@type string, SkillUpNamespace
local _, ns = ...
local L = ns.L

---@type SkillUpRecipeList
local recipeList

-- The recipe list's own numbers at Interface 16001: Camelot's CraftingPage.OverrideArt sets the list 304
-- wide, its ScrollBox is inset 8 from the left and 20 from the right, the tree view leaves 5 at the right,
-- a row's Label starts after the 26-wide SkillUps button, and a locked recipe adds its 17-wide icon before
-- the text (Blizzard_ProfessionsCrafting.xml and Blizzard_ProfessionsRecipeList.xml/.lua). A category indents
-- its recipes by 10 more. These are the room a name has once the list is as wide as the client made it.
local LIST_CHROME = 59
local LABEL_GAP = 10 -- a row's Label keeps this clear at its right edge
-- FitLabel: SkillUp's row text sits 4 from the row's right edge and keeps 10 clear of the name.
local TEXT_GAP = 14
local LOCKED_CHROME = 17
local TREE_INDENT = 10
local SCREEN_MARGIN = 32

-- The widest row the open profession needs, in list width: its indent, name, count, lock, SkillUp's row
-- text and the list's own chrome. Measured when the profession opens, not on a list refresh.
local neededListWidth = 0
-- What that measurement was for: the open profession and the two settings that change a row's text. A
-- refresh from search, filters, a collapsed category, crafting, bags or prices finds the same key and
-- leaves the window's width alone.
local measuredProfession
-- The widths we set, and the client widths they replaced, so a later client resize is not mistaken for ours.
local widenedList, widenedListBase
local widenedFrame, widenedFrameBase
local resizePending = false
---@type FontString
local measure

---@param a number?
---@param b number?
---@return boolean
local function SameWidth(a, b)
	return a ~= nil and b ~= nil and math.abs(a - b) < 0.5
end

-- An added recipe's row text: that it is not learned, and where and at what skill it is learned. Grey,
-- like the name Blizzard greys for a recipe it knows is unlearned.
---@param entry SkillUpUnlearnedRecipe
---@return string
local function UnlearnedText(entry)
	return string.format(L["Not learned · %s"], ns.LearnSourceText(entry))
end

---@param recipeID integer
---@return integer
local function CraftableCount(recipeID)
	return ns.Readable(C_TradeSkillUI.GetCraftableCount(recipeID)) or 0
end

-- The width one recipe needs: its indent, name, count, lock and, when it is on, SkillUp's own row text with
-- the gap FitLabel keeps. Measured with one hidden font string for the whole refresh, not from a row's frame,
-- which only exists while it is on screen.
---@param info TradeSkillRecipeInfo
---@param depth integer
---@return number
local function RecipeWidth(info, depth)
	local recipeInfo = Professions.GetHighestLearnedRecipe(info) or info
	measure:SetText(recipeInfo.name or "")
	local width = depth * TREE_INDENT + measure:GetStringWidth() + LIST_CHROME
	if recipeInfo.skillUpUnlearned then
		measure:SetText(UnlearnedText(recipeInfo.skillUpUnlearned))
		return width + measure:GetStringWidth() + TEXT_GAP
	end
	local count = CraftableCount(recipeInfo.recipeID)
	if count > 0 then
		measure:SetFormattedText(" (%d) ", count)
		width = width + measure:GetStringWidth()
	end
	if recipeInfo.disabled then
		width = width + LOCKED_CHROME
	end
	if ns.db.showRowText then
		measure:SetText(ns.FormatRow(ns.Describe(recipeInfo, ns.SkillContext())))
		width = width + measure:GetStringWidth() + TEXT_GAP
	else
		width = width + LABEL_GAP
	end
	return width
end

-- How many category nodes a recipe sits under in the client's tree, which is the indent the row gets. A
-- category whose parent data is missing still needs its own indent.
---@param categoryID integer?
---@param depths table<integer, integer>
---@return integer
local function CategoryDepth(categoryID, depths)
	if not categoryID or categoryID == 0 then
		return 0
	end
	local depth = depths[categoryID]
	if depth then
		return depth
	end
	depth = 1
	local seen = { [categoryID] = true }
	local info = C_TradeSkillUI.GetCategoryInfo and C_TradeSkillUI.GetCategoryInfo(categoryID)
	local parent = info and info.parentCategoryID
	while parent and parent ~= 0 and not seen[parent] do
		seen[parent] = true
		depth = depth + 1
		local parentInfo = C_TradeSkillUI.GetCategoryInfo(parent)
		parent = parentInfo and parentInfo.parentCategoryID
	end
	depths[categoryID] = depth
	return depth
end

-- Which profession the list is showing, and what a row shows besides its name.
---@return string
local function ProfessionKey()
	local info = ProfessionsFrame and ProfessionsFrame.professionInfo
	local professionID = info and info.professionID
	if not professionID then
		local base = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
		professionID = base and base.professionID
	end
	return table.concat({
		tostring(professionID or ""),
		tostring(ns.db.wideRecipeList),
		tostring(ns.db.showRowText),
	}, ":")
end

-- Defined with the bundled unlearned recipe it also measures; Fit calls it once the file is loaded.
local MeasureProfession

-- The list and the window with it grow by the room the widest name needs beyond the client's own widths.
-- Combat defers the change: a resize waits for PLAYER_REGEN_ENABLED, never an OnUpdate. With the setting off,
-- the client's widths go back.
function ns.FitRecipeListWidth()
	if not (recipeList and ProfessionsFrame) then
		return
	end
	MeasureProfession()
	if InCombatLockdown and InCombatLockdown() then
		resizePending = true
		return
	end
	resizePending = false

	local listWidth = recipeList:GetWidth()
	local frameWidth = ProfessionsFrame:GetWidth()
	if not SameWidth(listWidth, widenedList) then
		widenedList, widenedListBase = nil, listWidth
	end
	if not SameWidth(frameWidth, widenedFrame) then
		widenedFrame, widenedFrameBase = nil, frameWidth
	end

	local extra = 0
	if ns.db.wideRecipeList and recipeList:IsVisible() and neededListWidth > 0 then
		extra = math.max(0, neededListWidth - widenedListBase)
		local screen = UIParent and UIParent:GetWidth() or 0
		if screen > 0 then
			extra = math.min(extra, math.max(0, screen - 2 * SCREEN_MARGIN - widenedFrameBase))
		end
		if extra < 1 then
			extra = 0
		end
	end

	local targetList = widenedListBase + extra
	local targetFrame = widenedFrameBase + extra
	if listWidth ~= targetList then
		recipeList:SetWidth(targetList)
	end
	if frameWidth ~= targetFrame then
		ProfessionsFrame:SetWidth(targetFrame)
	end
	if ns.FitFrameArt then
		ns.FitFrameArt(extra)
	end
	if extra > 0 then
		widenedList, widenedFrame = targetList, targetFrame
	else
		widenedList, widenedFrame = nil, nil
	end
end

-- The row's own Init sized the label for Blizzard's right-hand widgets only;
-- shrink it again so a long recipe name truncates instead of running under our text.
---@param row SkillUpRecipeRow
---@param text FontString
local function FitLabel(row, text)
	local count = row.Count:IsShown() and row.Count:GetStringWidth() or 0
	local locked = row.LockedIcon:IsShown() and row.LockedIcon:GetWidth() + 2 or 0
	local available = row:GetWidth() - row.SkillUps:GetWidth() - count - locked - text:GetStringWidth() - 14
	if row.Label:GetWidth() > available then
		row.Label:SetWidth(math.max(available, 40))
	end
end

-- Our row text, keyed by the client's row rather than stored on it: a field an addon writes into a Blizzard
-- frame is a taint risk on that frame's own click path (#350), and the recipe row is the frame the player
-- clicks. A weak key lets a released row be collected.
---@type table<SkillUpRecipeRow, FontString>
local rowTexts = setmetatable({}, { __mode = "k" })

---@param row SkillUpRecipeRow
---@param elementData SkillUpTreeNode
local function DecorateRow(row, elementData)
	local data = elementData and elementData:GetData()
	if not data then
		return
	end
	local info = data.recipeInfo
	if not info then
		return
	end

	local recipeInfo = Professions.GetHighestLearnedRecipe(info) or info
	local entry = recipeInfo.skillUpUnlearned

	-- The client's own count says how many the bags can make; give it the parentheses the list reads better
	-- with, and keep it whether or not our row text is on.
	local count = not entry and CraftableCount(recipeInfo.recipeID) or 0
	if count > 0 then
		row.Count:SetFormattedText(" (%d) ", count)
		row.Count:Show()
	else
		row.Count:Hide()
	end

	local text = rowTexts[row]
	if not text then
		text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight_NoShadow")
		text:SetJustifyH("RIGHT")
		rowTexts[row] = text
	end
	if entry then
		text:ClearAllPoints()
		text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		text:SetText(UnlearnedText(entry))
		text:SetTextColor(GRAY_FONT_COLOR:GetRGB())
		text:Show()
		FitLabel(row, text)
		-- A recipe this character has not learned cannot be selected or crafted: clicks stay off, while
		-- mouse motion stays on so the row still raises the recipe tooltip.
		if row.EnableMouse then
			row:EnableMouse(false)
		end
		if row.SetMouseMotionEnabled then
			row:SetMouseMotionEnabled(true)
		end
		return
	end
	if row.EnableMouse then
		row:EnableMouse(true)
	end
	if not ns.db.showRowText then
		text:Hide()
		return
	end

	local d = ns.Describe(recipeInfo, ns.SkillContext())
	text:ClearAllPoints()
	if row.LockedIcon:IsShown() then
		text:SetPoint("RIGHT", row.LockedIcon, "LEFT", -2, 0)
	else
		text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	end
	text:SetText(ns.FormatRow(d))
	text:SetTextColor(ns.RowColor(d):GetRGB())
	text:Show()
	FitLabel(row, text)
end

---@type table<string, SkillUpSortKey>
local SORT_KEYS = {
	skill = function(recipeInfo, ctx)
		local t = ns.RangeThresholds(ctx, recipeInfo.recipeID)
		return t and t[1] or math.huge
	end,
	-- Trainers teach recipes in the order of the skill they need, so the highest range start is the one
	-- learned most recently (#486). The start is where a recipe can first be learned, not the client's
	-- placeholder first threshold (#519).
	newest = function(recipeInfo, ctx)
		local t = ns.RangeThresholds(ctx, recipeInfo.recipeID)
		return t and -t[1] or math.huge
	end,
	chance = function(recipeInfo, ctx)
		local chance = ns.Describe(recipeInfo, ctx).chance
		return chance and -chance or math.huge
	end,
	cost = function(recipeInfo, ctx)
		return ns.Describe(recipeInfo, ctx).perSkillUp or math.huge
	end,
}

-- Forever's categories hold one or two recipes each, so sorting inside them changes
-- nothing. A sort instead flattens the list: learned recipes, then unlearned ones.
local replacing = false
-- One failure is said once, not on every redraw.
local warned = false
-- The provider the client built, kept so Default can put it back, and the providers we built ourselves, so
-- neither is taken for the client's. Restoring the client's own provider is what lets Default work without
-- calling the crafting page's Init, which writes the recipe selection and schematic as ours (#350).
---@type SkillUpTreeProvider?
local nativeProvider
---@type table<SkillUpTreeProvider, true>
local builtProviders = setmetatable({}, { __mode = "k" })

---@param node SkillUpTreeNode
---@param learned SkillUpRecipeNodeData[]
---@param unlearned SkillUpRecipeNodeData[]
---@param seen table<integer, boolean>
local function CollectRecipes(node, learned, unlearned, seen)
	for _, child in ipairs(node:GetNodes()) do
		local data = child:GetData()
		local info = data.recipeInfo
		if not info then
			CollectRecipes(child, learned, unlearned, seen)
		elseif not info.favoritesInstance and not seen[info.recipeID] then
			seen[info.recipeID] = true
			-- The client's own node data goes into the sorted provider: a table of ours would be the addon's,
			-- and the selection keeps it for the craft path to read (#350).
			local list = info.learned and learned or unlearned
			list[#list + 1] = data
		end
	end
end

---@param node SkillUpTreeNode
---@param seen table<integer, boolean>
local function CollectIDs(node, seen)
	for _, child in ipairs(node:GetNodes()) do
		local info = child:GetData().recipeInfo
		if info then
			seen[info.recipeID] = true
		else
			CollectIDs(child, seen)
		end
	end
end

-- The row data for one recipe the bundle knows this character has not learned.
---@param entry SkillUpUnlearnedRecipe
---@return TradeSkillRecipeInfo
local function UnlearnedInfo(entry)
	-- A row draws only these fields; the client's full recipe record needs data this recipe has never loaded.
	---@diagnostic disable-next-line: missing-fields
	return {
		recipeID = entry.recipeID,
		name = entry.name,
		learned = false,
		canSkillUp = false,
		skillUpUnlearned = entry,
	} --[[@as TradeSkillRecipeInfo]]
end

-- The width the open profession needs, over every recipe the client lists for it and the bundled unlearned
-- ones, whatever the search, filters and collapsed categories show. Only a different profession or a row
-- setting changes the key, so a list refresh never moves the window. The bundled unlearned recipes are
-- measured whether or not they are listed, so turning that setting on cannot change the width either.
function MeasureProfession()
	local key = ProfessionKey()
	if key == measuredProfession then
		return
	end
	local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetAllRecipeIDs()
	-- A profession event can arrive before the client has its recipes; leave the key unmeasured and let the
	-- list being built measure it.
	if not recipeIDs or #recipeIDs == 0 then
		return
	end
	neededListWidth = 0
	local ctx = ns.SkillContext and ns.SkillContext()
	local seen, depths = {}, {}

	---@param info TradeSkillRecipeInfo
	---@param depth integer
	local function Note(info, depth)
		local width = RecipeWidth(info, depth)
		if width > neededListWidth then
			neededListWidth = width
		end
	end

	for _, recipeID in ipairs(recipeIDs) do
		if not seen[recipeID] then
			seen[recipeID] = true
			local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
			if info then
				Note(info, CategoryDepth(info.categoryID, depths))
			end
		end
	end
	-- Without the open profession's skill there is no unlearned set to measure: leave the key unmeasured so
	-- the list built with it measures the bundle's recipes too.
	if not ctx then
		return
	end
	if ns.UnlearnedRecipes then
		for _, entry in ipairs(ns.UnlearnedRecipes(ctx)) do
			if not seen[entry.recipeID] then
				seen[entry.recipeID] = true
				Note(UnlearnedInfo(entry), 0)
			end
		end
	end
	measuredProfession = key
end

-- The bundled recipes missing from the client's list, in the order ns.UnlearnedRecipes sorted them. A
-- recipe the client does not list has no node data of its own, so its row gets our wrapper around it.
---@param seen table<integer, boolean>
---@param ctx SkillUpContext
---@return SkillUpRecipeNodeData[]
local function UnlearnedMissing(seen, ctx)
	local missing = {}
	for _, entry in ipairs(ns.UnlearnedRecipes(ctx)) do
		if not seen[entry.recipeID] then
			seen[entry.recipeID] = true
			missing[#missing + 1] = { recipeInfo = UnlearnedInfo(entry) }
		end
	end
	return missing
end

---@param list SkillUpRecipeNodeData[]
---@param key SkillUpSortKey
---@param ctx SkillUpContext?
local function SortRecipes(list, key, ctx)
	local keys = {}
	for _, data in ipairs(list) do
		keys[data] = key(data.recipeInfo, ctx)
	end
	table.sort(list, function(a, b)
		if keys[a] ~= keys[b] then
			return keys[a] < keys[b]
		end
		return strcmputf8i(a.recipeInfo.name, b.recipeInfo.name) < 0
	end)
end

---@param source SkillUpTreeProvider
---@param key SkillUpSortKey
---@param ctx SkillUpContext?
---@return SkillUpTreeProvider
local function BuildSorted(source, key, ctx)
	local learned, unlearned, seen = {}, {}, {}
	CollectRecipes(source:GetRootNode(), learned, unlearned, seen)
	if ns.db.showUnlearned and ctx then
		for _, info in ipairs(UnlearnedMissing(seen, ctx)) do
			unlearned[#unlearned + 1] = info
		end
	end
	SortRecipes(learned, key, ctx)
	SortRecipes(unlearned, key, ctx)

	local sorted = CreateTreeDataProvider()
	for _, data in ipairs(learned) do
		sorted:Insert(data)
	end
	-- Blizzard's divider template draws the "Unlearned" label itself.
	if #unlearned > 0 then
		sorted:Insert({ isDivider = true, dividerHeight = #learned > 0 and 70 or 30 })
		for _, data in ipairs(unlearned) do
			sorted:Insert(data)
		end
	end
	return sorted
end

-- The buff filter's default order: highest required level first, then the name SortRecipes breaks ties on.
---@param recipeInfo TradeSkillRecipeInfo
---@return number
local function BuffLevelKey(recipeInfo)
	return -(ns.BuffLevel(recipeInfo.recipeID) or 0)
end

-- The buff filter's flat list: learned recipes whose product is a buff this character can use now, then
-- the unlearned ones under Blizzard's divider when those are listed. A chosen sort mode still orders
-- it; Default puts the highest required level first. An empty match is an empty list, not the client's.
---@param source SkillUpTreeProvider
---@param key SkillUpSortKey?
---@param ctx SkillUpContext?
---@return SkillUpTreeProvider
local function BuildBuffs(source, key, ctx)
	local level = UnitLevel("player") or 0
	local learned, unlearned, seen = {}, {}, {}
	local clientLearned, clientUnlearned = {}, {}
	CollectRecipes(source:GetRootNode(), clientLearned, clientUnlearned, seen)
	for _, data in ipairs(clientLearned) do
		if ns.UsableBuff(data.recipeInfo.recipeID, level) then
			learned[#learned + 1] = data
		end
	end
	-- As in the sorted list, what the client lists unlearned stays, and the bundle's only with the setting on.
	if ns.db.showUnlearned and ctx then
		for _, data in ipairs(UnlearnedMissing(seen, ctx)) do
			clientUnlearned[#clientUnlearned + 1] = data
		end
	end
	for _, data in ipairs(clientUnlearned) do
		if ns.UsableBuff(data.recipeInfo.recipeID, level) then
			unlearned[#unlearned + 1] = data
		end
	end
	key = key or BuffLevelKey
	SortRecipes(learned, key, ctx)
	SortRecipes(unlearned, key, ctx)

	local filtered = CreateTreeDataProvider()
	for _, data in ipairs(learned) do
		filtered:Insert(data)
	end
	-- Blizzard's divider template draws the "Unlearned" label itself.
	if #unlearned > 0 then
		filtered:Insert({ isDivider = true, dividerHeight = #learned > 0 and 70 or 30 })
		for _, data in ipairs(unlearned) do
			filtered:Insert(data)
		end
	end
	return filtered
end

-- Whether this part of the client's tree holds a recipe the list should keep. A favourites entry is a
-- recipe too, so its category stays even when every entry in it is one.
---@param node SkillUpTreeNode
---@return boolean
local function HasRecipe(node)
	for _, child in ipairs(node:GetNodes()) do
		local info = child:GetData().recipeInfo
		if info then
			return true
		elseif HasRecipe(child) then
			return true
		end
	end
	return false
end

-- The client's categories, copied as they are, with the bundled unlearned recipes after them. A copy
-- loses Blizzard's sort comparator, so the order inserted here is the order drawn. A favourite is
-- copied into its favourites category and into its own category, as the native list draws it.
---@param source SkillUpTreeProvider
---@param extra SkillUpRecipeNodeData[]
---@return SkillUpTreeProvider
local function BuildCategories(source, extra)
	local copied = CreateTreeDataProvider()
	local count = 0
	---@param node SkillUpTreeNode
	---@param target SkillUpTreeProvider|SkillUpTreeNode
	local function Clone(node, target)
		for _, child in ipairs(node:GetNodes()) do
			local data = child:GetData()
			if data.recipeInfo then
				count = count + 1
				-- The client's own node data, as in the sorted list: a table of ours would be the addon's and
				-- the selection keeps it for the craft path to read (#350).
				target:Insert(data)
			elseif data.categoryInfo then
				if HasRecipe(child) then
					local category = target:Insert({ categoryInfo = data.categoryInfo })
					if child.IsCollapsed and child:IsCollapsed() and category.SetCollapsed then
						category:SetCollapsed(true)
					end
					Clone(child, category)
				end
			elseif data.isDivider then
				target:Insert({ isDivider = true, dividerHeight = data.dividerHeight })
			elseif data.topPadding or data.bottomPadding then
				target:Insert({ topPadding = data.topPadding, bottomPadding = data.bottomPadding })
			end
		end
	end
	Clone(source:GetRootNode(), copied)
	if #extra > 0 then
		copied:Insert({ isDivider = true, dividerHeight = count > 0 and 70 or 30 })
		for _, data in ipairs(extra) do
			copied:Insert(data)
		end
	end
	return copied
end

---@param source SkillUpTreeProvider
---@param key SkillUpSortKey?
---@param ctx SkillUpContext?
---@return SkillUpTreeProvider?
local function BuildProvider(source, key, ctx)
	if ns.db.buffsOnly then
		return BuildBuffs(source, key, ctx)
	end
	if key then
		return BuildSorted(source, key, ctx)
	end
	if not (ns.db.showUnlearned and ctx) then
		return nil
	end
	local seen = {}
	CollectIDs(source:GetRootNode(), seen)
	local extra = UnlearnedMissing(seen, ctx)
	if #extra == 0 then
		return nil
	end
	return BuildCategories(source, extra)
end

---@param scrollBox SkillUpRecipeScrollBox
local function ApplyList(scrollBox)
	if replacing then
		return
	end
	local source = scrollBox:GetDataProvider()
	if not (source and source.GetRootNode) then
		return
	end
	-- A provider the client built replaces the one we kept; ours replacing itself does not.
	if not builtProviders[source] then
		nativeProvider = source
	end
	-- Rebuild from the client's own provider when ours is already installed, so a redraw never sorts or
	-- copies our own rows.
	local base = builtProviders[source] and nativeProvider or source
	local key = SORT_KEYS[ns.db.sortMode]
	local ok, built = pcall(BuildProvider, base, key, ns.SkillContext())
	if not ok then
		if key then
			ns.SetSortMode("blizzard")
			ns.Print(string.format(L["sorting failed and has been turned off: %s"], tostring(built)))
		elseif not warned then
			warned = true
			ns.Print(string.format(L["listing unlearned recipes failed: %s"], tostring(built)))
		end
		return
	end
	if not built then
		-- Default, with no unlearned recipes to add, brings the client's categories back. Its own provider
		-- is restored in place: asking the crafting page to Init would write its recipe selection and
		-- schematic from addon code, and the craft path reads them (#350).
		if builtProviders[source] and nativeProvider then
			replacing = true
			scrollBox:SetDataProvider(nativeProvider, ScrollBoxConstants.RetainScrollPosition)
			replacing = false
		end
		return
	end
	---@cast built SkillUpTreeProvider
	builtProviders[built] = true
	replacing = true
	scrollBox:SetDataProvider(built, ScrollBoxConstants.RetainScrollPosition)
	replacing = false
end

-- Redraws the rows on screen from what they hold. A settings, price or profession change used to rebuild
-- the list through the crafting page's Init, which wrote Blizzard's recipe selection and schematic from
-- addon code: the craft path reads that state, so a potion or conversion could be refused until /reload
-- (#350). Nothing here changes the client's selection.
local function Redecorate()
	if not (recipeList and recipeList.ScrollBox and recipeList.ScrollBox.ForEachFrame) then
		return
	end
	recipeList.ScrollBox:ForEachFrame(function(row, elementData)
		if elementData and elementData.GetData then
			DecorateRow(row, elementData)
		end
	end)
end

-- A "Sort by" section at the bottom of Blizzard's own Filter menu. The same menu
-- serves other recipe lists, so only the crafting page's dropdown gets it.
---@param owner Region
---@param rootDescription RootMenuDescriptionProxy
local function AddFilterMenu(owner, rootDescription)
	if owner ~= recipeList.FilterDropdown then
		return
	end
	rootDescription:CreateDivider()
	rootDescription:CreateCheckbox(L["Only buffs for your level"], function()
		return ns.db.buffsOnly
	end, function()
		ns.SetBuffsOnly(not ns.db.buffsOnly)
		return MenuResponse.Refresh
	end)
	rootDescription:CreateTitle(L["Sort by"])
	for _, option in ipairs(ns.SORT_OPTIONS) do -- menu-scroll-ok: SORT_OPTIONS is five fixed sort modes
		rootDescription:CreateRadio(option[2], function(mode)
			return ns.db.sortMode == mode
		end, function(mode)
			ns.SetSortMode(mode)
			return MenuResponse.Refresh
		end, option[1])
	end
end

-- Blizzard's Filter menu is opened by the client's own gamepad footer, not by this addon. The section above
-- is addon code reading the saved sort and buff settings, so the client builds that menu under our taint. The
-- gamepad frame manager then takes the menu into its focus in the same call and writes its state as ours; the
-- next secure reader has its protected SetPreferredGamepadInteractTarget refused and blamed on this addon
-- (#454). With the gamepad interface on the client's own filters still show, and both settings stay in the
-- addon's settings page. The modification is withdrawn while the gamepad interface is on, and put back for
-- mouse and keyboard.
---@type { Unregister: fun() }?
local filterMenu
local function SyncFilterMenu()
	if ns.GamepadUI() then
		if filterMenu then
			filterMenu:Unregister()
			filterMenu = nil
		end
	elseif not filterMenu then
		filterMenu = Menu.ModifyMenu("MENU_PROFESSIONS_FILTER", AddFilterMenu)
	end
end

function ns.AttachRecipeList()
	recipeList = ProfessionsFrame.CraftingPage.RecipeList
	measure = recipeList:CreateFontString(nil, "OVERLAY", "GameFontHighlight_NoShadow")
	measure:Hide()
	-- No iterateExisting: it calls back as (frame, data), not (owner, frame, data),
	-- and the list is still empty when Blizzard_Professions finishes loading.
	ScrollUtil.AddInitializedFrameCallback(recipeList.ScrollBox, function(_, row, elementData)
		DecorateRow(row, elementData)
	end, ns)
	recipeList.ScrollBox:RegisterCallback("OnDataProviderReassigned", function(scrollBox)
		ApplyList(scrollBox)
		if replacing then
			return
		end
		ns.FitRecipeListWidth()
	end, recipeList.ScrollBox)
	EventRegistry:RegisterCallback("Professions.RecipeListOnEnter", ns.ShowRecipeTooltip, ns)
	-- The client resets the window's width on a tab change, a page refresh and a show. Fit keeps that width
	-- where the profession's measurement put it; only a different skill line measures again.
	EventRegistry:RegisterCallback("ProfessionsFrame.TabSet", ns.FitRecipeListWidth, ns)
	EventRegistry:RegisterCallback("ProfessionsFrame.Show", ns.FitRecipeListWidth, ns)
	EventRegistry:RegisterCallback("Professions.CraftingDisplayRefresh", ns.FitRecipeListWidth, ns)
	ns.WhenEvent("TRADE_SKILL_SHOW", ns.FitRecipeListWidth)
	ns.WhenEvent("TRADE_SKILL_DATA_SOURCE_CHANGED", ns.FitRecipeListWidth)
	ns.WhenEvent("PLAYER_REGEN_ENABLED", function()
		if resizePending then
			ns.FitRecipeListWidth()
		end
	end)
	ns.WhenEvent("INPUT_DEVICE_INTERFACE_TRANSITION" --[[@as WowEvent]], SyncFilterMenu)
	SyncFilterMenu()
	-- A row setting, a price or a profession changed: redraw the rows and re-sort in place. Never rebuild
	-- the page through Blizzard's Init, which would write its recipe selection and schematic as ours (#350).
	-- Fit measures again only for the two row settings or a new profession, never for a price or a filter.
	ns.WhenStale("recipeList", function()
		if recipeList:IsVisible() and ProfessionsFrame.professionInfo then
			ApplyList(recipeList.ScrollBox)
			Redecorate()
		end
		ns.FitRecipeListWidth()
	end)
	-- The window may already be open when another addon loaded Blizzard_Professions first.
	ns.FitRecipeListWidth()
	ns.AttachRoute()
	ns.AttachGear()
	if ns.AttachBuffs then
		ns.AttachBuffs()
	end
	ns.AttachAuctionSearch()
	ns.AttachDetailsBar()
end
