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

-- The widest row the last list refresh held, in list width: its indent, name, count, lock, SkillUp's row
-- text and the list's own chrome.
local neededListWidth = 0
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

-- One pass over the refreshed list remembers the widest row, so no row initializer measures a name.
---@param provider SkillUpTreeProvider?
local function MeasureProvider(provider)
	neededListWidth = 0
	if not provider or not provider.GetRootNode then
		return
	end
	---@param node SkillUpTreeNode
	---@param depth integer
	local function Walk(node, depth)
		for _, child in ipairs(node:GetNodes()) do
			local data = child:GetData()
			local info = data and data.recipeInfo
			if info then
				local width = RecipeWidth(info, depth)
				if width > neededListWidth then
					neededListWidth = width
				end
			else
				Walk(child, depth + 1)
			end
		end
	end
	Walk(provider:GetRootNode(), 0)
end

-- The list and the window with it grow by the room the widest name needs beyond the client's own widths.
-- Combat defers the change: a resize waits for PLAYER_REGEN_ENABLED, never an OnUpdate. With the setting off,
-- the client's widths go back.
function ns.FitRecipeListWidth()
	if not (recipeList and ProfessionsFrame) then
		return
	end
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

---@param _ SkillUpNamespace
---@param row SkillUpRecipeRow
---@param node SkillUpTreeNode
local function DecorateRow(_, row, node)
	local data = node and node:GetData()
	if not data then
		return
	end
	local info = data.recipeInfo
	if not info then
		return
	end

	local recipeInfo = Professions.GetHighestLearnedRecipe(info) or info

	-- The client's own count says how many the bags can make; give it the parentheses the list reads better
	-- with, and keep it whether or not our row text is on.
	local count = CraftableCount(recipeInfo.recipeID)
	if count > 0 then
		row.Count:SetFormattedText(" (%d) ", count)
		row.Count:Show()
	else
		row.Count:Hide()
	end

	local text = row.SkillUpText
	if not text then
		text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight_NoShadow")
		text:SetJustifyH("RIGHT")
		row.SkillUpText = text
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
	skill = function(recipeInfo)
		local t = ns.Model.Get(recipeInfo.recipeID)
		return t and t[1] or math.huge
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

---@param node SkillUpTreeNode
---@param learned TradeSkillRecipeInfo[]
---@param unlearned TradeSkillRecipeInfo[]
---@param seen table<integer, boolean>
local function CollectRecipes(node, learned, unlearned, seen)
	for _, child in ipairs(node:GetNodes()) do
		local info = child:GetData().recipeInfo
		if not info then
			CollectRecipes(child, learned, unlearned, seen)
		elseif not info.favoritesInstance and not seen[info.recipeID] then
			seen[info.recipeID] = true
			local list = info.learned and learned or unlearned
			list[#list + 1] = info
		end
	end
end

---@param list TradeSkillRecipeInfo[]
---@param key SkillUpSortKey
---@param ctx SkillUpContext?
local function SortRecipes(list, key, ctx)
	local keys = {}
	for _, info in ipairs(list) do
		keys[info] = key(info, ctx)
	end
	table.sort(list, function(a, b)
		if keys[a] ~= keys[b] then
			return keys[a] < keys[b]
		end
		return strcmputf8i(a.name, b.name) < 0
	end)
end

---@param source SkillUpTreeProvider
---@param key SkillUpSortKey
---@return SkillUpTreeProvider
local function BuildSorted(source, key)
	local ctx = ns.SkillContext()
	local learned, unlearned = {}, {}
	CollectRecipes(source:GetRootNode(), learned, unlearned, {})
	SortRecipes(learned, key, ctx)
	SortRecipes(unlearned, key, ctx)

	local sorted = CreateTreeDataProvider()
	for _, info in ipairs(learned) do
		sorted:Insert({ recipeInfo = info })
	end
	-- Blizzard's divider template draws the "Unlearned" label itself.
	if #unlearned > 0 then
		sorted:Insert({ isDivider = true, dividerHeight = #learned > 0 and 70 or 30 })
		for _, info in ipairs(unlearned) do
			sorted:Insert({ recipeInfo = info })
		end
	end
	return sorted
end

---@param scrollBox SkillUpRecipeScrollBox
local function ApplySort(scrollBox)
	local key = SORT_KEYS[ns.db.sortMode]
	local source = scrollBox:GetDataProvider()
	if replacing or not key or not source or not source.GetRootNode then
		return
	end
	local ok, sorted = pcall(BuildSorted, source, key)
	if not ok then
		ns.SetSortMode("blizzard")
		ns.Print(string.format(L["sorting failed and has been turned off: %s"], tostring(sorted)))
		return
	end
	replacing = true
	scrollBox:SetDataProvider(sorted, ScrollBoxConstants.RetainScrollPosition)
	replacing = false
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
	rootDescription:CreateTitle(L["Sort by"])
	for _, option in ipairs(ns.SORT_OPTIONS) do -- menu-scroll-ok: SORT_OPTIONS is four fixed sort modes
		rootDescription:CreateRadio(option[2], function(mode)
			return ns.db.sortMode == mode
		end, function(mode)
			ns.SetSortMode(mode)
			return MenuResponse.Refresh
		end, option[1])
	end
end

function ns.AttachRecipeList()
	recipeList = ProfessionsFrame.CraftingPage.RecipeList
	measure = recipeList:CreateFontString(nil, "OVERLAY", "GameFontHighlight_NoShadow")
	measure:Hide()
	-- No iterateExisting: it calls back as (frame, data), not (owner, frame, data),
	-- and the list is still empty when Blizzard_Professions finishes loading.
	ScrollUtil.AddInitializedFrameCallback(recipeList.ScrollBox, DecorateRow, ns)
	recipeList.ScrollBox:RegisterCallback("OnDataProviderReassigned", function(scrollBox)
		ApplySort(scrollBox)
		if replacing then
			return
		end
		MeasureProvider(scrollBox:GetDataProvider())
		ns.FitRecipeListWidth()
	end, recipeList.ScrollBox)
	EventRegistry:RegisterCallback("Professions.RecipeListOnEnter", ns.ShowRecipeTooltip, ns)
	-- The client resets the window's width on a tab change, a page refresh and a show.
	EventRegistry:RegisterCallback("ProfessionsFrame.TabSet", ns.FitRecipeListWidth, ns)
	EventRegistry:RegisterCallback("ProfessionsFrame.Show", ns.FitRecipeListWidth, ns)
	EventRegistry:RegisterCallback("Professions.CraftingDisplayRefresh", ns.FitRecipeListWidth, ns)
	ns.WhenEvent("PLAYER_REGEN_ENABLED", function()
		if resizePending then
			ns.FitRecipeListWidth()
		end
	end)
	Menu.ModifyMenu("MENU_PROFESSIONS_FILTER", AddFilterMenu)
	-- Rebuilding through the crafting page re-runs Blizzard's provider, which our
	-- data-provider callback then re-sorts.
	ns.WhenStale("recipeList", function()
		if recipeList:IsVisible() and ProfessionsFrame.professionInfo then
			ProfessionsFrame.CraftingPage:Init(ProfessionsFrame.professionInfo)
		end
		ns.FitRecipeListWidth()
	end)
	-- The window may already be open when another addon loaded Blizzard_Professions first.
	MeasureProvider(recipeList.ScrollBox:GetDataProvider())
	ns.FitRecipeListWidth()
	ns.AttachRoute()
	ns.AttachGear()
	ns.AttachAuctionSearch()
	ns.AttachDetailsBar()
end
