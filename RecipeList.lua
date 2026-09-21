local _, ns = ...

local recipeList

local function FormatRow(d)
	if not d.thresholds then
		return "?"
	end
	-- A recipe you can't make yet keeps its requirement: it's the only useful number.
	if not d.chance then
		return tostring(d.thresholds[1])
	end
	local parts = {}
	if ns.db.showSkill then
		parts[#parts + 1] = tostring(d.thresholds[1])
	end
	parts[#parts + 1] = string.format("%d%%", math.floor(d.chance * 100 + 0.5))
	if ns.db.showCost and d.perSkillUp then
		parts[#parts + 1] = C_CurrencyInfo.GetCoinTextureString(ns.Model.RoundMoney(d.perSkillUp))
	end
	return table.concat(parts, " · ")
end

-- The row's own Init sized the label for Blizzard's right-hand widgets only;
-- shrink it again so a long recipe name truncates instead of running under our text.
local function FitLabel(row, text)
	local count = row.Count:IsShown() and row.Count:GetStringWidth() or 0
	local locked = row.LockedIcon:IsShown() and row.LockedIcon:GetWidth() + 2 or 0
	local available = row:GetWidth() - row.SkillUps:GetWidth() - count - locked - text:GetStringWidth() - 14
	if row.Label:GetWidth() > available then
		row.Label:SetWidth(math.max(available, 40))
	end
end

local function DecorateRow(_, row, node)
	local data = node and node:GetData()
	if not (data and data.recipeInfo) then
		return
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

	local recipeInfo = Professions.GetHighestLearnedRecipe(data.recipeInfo) or data.recipeInfo
	local d = ns.Describe(recipeInfo, ns.SkillContext())
	text:ClearAllPoints()
	if row.LockedIcon:IsShown() then
		text:SetPoint("RIGHT", row.LockedIcon, "LEFT", -2, 0)
	else
		text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	end
	text:SetText(FormatRow(d))
	text:SetTextColor(ns.COLORS[d.chance and d.color or (d.thresholds and "red" or "unknown")]:GetRGB())
	text:Show()
	FitLabel(row, text)
end

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

-- Recipes are compared by our key; anything else (categories, padding rows,
-- ties) falls through to Blizzard's comparator, so structure is untouched.
local function WrapComparator(original, key, ctx)
	return function(a, b)
		local ar, br = a:GetData().recipeInfo, b:GetData().recipeInfo
		if ar and br then
			local ka, kb = key(ar, ctx), key(br, ctx)
			if ka ~= kb then
				return ka < kb
			end
		end
		return original(a, b)
	end
end

local function SortTree(node, key, ctx)
	for _, child in ipairs(node:GetNodes()) do
		local original = child.sortComparator
		if original and child:GetData().categoryInfo then
			local wrapped = WrapComparator(original, key, ctx)
			child:SetSortComparator(wrapped, false, true)
			table.sort(child:GetNodes(), wrapped)
		end
		SortTree(child, key, ctx)
	end
end

local function ApplySort(scrollBox)
	local key = SORT_KEYS[ns.db.sortMode]
	local dataProvider = scrollBox:GetDataProvider()
	if not key or not dataProvider or not dataProvider.GetRootNode then
		return
	end
	local ok, err = pcall(SortTree, dataProvider:GetRootNode(), key, ns.SkillContext())
	if not ok then
		ns.db.sortMode = "blizzard"
		ns.Print("sorting failed and has been turned off: " .. tostring(err))
		return
	end
	-- The provider caches its flattened rows; without this the list keeps drawing
	-- the order it had before we sorted.
	dataProvider:Invalidate()
end

-- A "Sort by" section at the bottom of Blizzard's own Filter menu. The same menu
-- serves other recipe lists, so only the crafting page's dropdown gets it.
local function AddSortMenu(owner, rootDescription)
	if owner ~= recipeList.FilterDropdown then
		return
	end
	rootDescription:CreateDivider()
	rootDescription:CreateTitle("Sort by")
	for _, option in ipairs(ns.SORT_OPTIONS) do
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
	-- No iterateExisting: it calls back as (frame, data), not (owner, frame, data),
	-- and the list is still empty when Blizzard_Professions finishes loading.
	ScrollUtil.AddInitializedFrameCallback(recipeList.ScrollBox, DecorateRow, ns)
	hooksecurefunc(recipeList.ScrollBox, "SetDataProvider", ApplySort)
	hooksecurefunc(recipeList.ScrollBox, "SetDataProvider", ns.LearnReagents)
	EventRegistry:RegisterCallback("Professions.RecipeListOnEnter", ns.ShowRecipeTooltip, ns)
	Menu.ModifyMenu("MENU_PROFESSIONS_FILTER", AddSortMenu)
end

-- Rebuilding through the crafting page re-runs Blizzard's provider, which our
-- SetDataProvider hook then re-sorts.
function ns.RefreshRecipeList()
	if recipeList and recipeList:IsVisible() and ProfessionsFrame.professionInfo then
		ProfessionsFrame.CraftingPage:Init(ProfessionsFrame.professionInfo)
	end
end
