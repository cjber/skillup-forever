---@type string, SkillUpNamespace
local _, ns = ...

if ns.broken then
	return
end
local L = ns.L

-- What the crafted gear and buffs pages say about a recipe and do with it. Each page owns its own frames;
-- these are the words and the one action they share.

---@class SkillUpPageParts
local Parts = {}
ns.PageParts = Parts

-- A menu built from a list scrolls past 20 rows of 20 px; a submenu never clamps to the screen (WFA-36).
Parts.MENU_EXTENT = 20 * 20

-- The route page's header, shared by every page that picks a profession: a WowStyle1DropdownTemplate at the
-- window's own place, and the profession's rank beside it. `setupMenu` fills the dropdown's root.
---@param parent Frame
---@param setupMenu fun(root: RootMenuDescriptionProxy)
---@return DropdownButton dropdown
---@return FontString skill
function Parts.CreateHeader(parent, setupMenu)
	local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate") --[[@as DropdownButton]]
	dropdown:SetWidth(180)
	-- Clear of the portrait, which overhangs the top-left corner.
	dropdown:SetPoint("TOPLEFT", 76, -32)
	dropdown:SetupMenu(function(_, root)
		root:SetScrollMode(Parts.MENU_EXTENT)
		setupMenu(root)
	end)
	ns.StepDropdownUnderGamepad(dropdown)
	local skill = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	skill:SetPoint("LEFT", dropdown, "RIGHT", 16, 0)
	return dropdown, skill
end

---@param itemID integer
---@return ColorMixin?
function Parts.QualityColor(itemID)
	local quality = C_Item.GetItemQualityByID(itemID)
	if not quality then
		return nil
	end
	local red, green, blue = C_Item.GetItemQualityColor(quality)
	return CreateColor(red, green, blue)
end

-- What the character can do with the recipe in plain words. A recipe whose requirement the data does
-- not know is not called learnable, and says its source is unknown instead.
---@param item SkillUpGearItem|SkillUpBuffItem
---@return string
function Parts.Status(item)
	if item.state == "known" then
		return L["You know it"]
	elseif item.state == "trainable" then
		return L["Can learn it"]
	elseif item.state == "needs" then
		return string.format(L["Needs %s %d"], item.profession, item.skill)
	elseif item.skill == nil then
		return L["Source unknown"]
	end
	return L["Another crafter"]
end

-- The profession and the skill its recipe is learned at, or that the data does not know the skill.
---@param item SkillUpGearItem|SkillUpBuffItem
---@return string
function Parts.LearnedAt(item)
	if item.skill then
		return string.format(L["%s, %d"], item.profession, item.skill)
	end
	return string.format(L["%s, source unknown"], item.profession)
end

-- Where a trainable recipe is learned, else nil: the trainer or the scroll's source, read the way
-- the route page reads them.
---@param item SkillUpGearItem|SkillUpBuffItem
---@param professions table<integer, SkillUpProfession>
---@return integer?
function Parts.RecipeNPC(item, professions)
	local profession = professions[item.skillLine]
	return profession and ns.RecipeNPC(profession, item.recipeID) or nil
end

-- The game's item tooltip for the pick, under it what the addon knows of its recipe and what a click
-- does or why it cannot.
---@param item SkillUpGearItem|SkillUpBuffItem
---@param professions table<integer, SkillUpProfession>
---@return fun(tooltip: GameTooltip)
function Parts.ItemTooltip(item, professions)
	return function(tooltip)
		tooltip:SetItemByID(item.itemID)
		GameTooltip_AddBlankLineToTooltip(tooltip)
		if item.state ~= "needs" then
			GameTooltip_AddNormalLine(tooltip, Parts.LearnedAt(item))
		end
		GameTooltip_AddNormalLine(tooltip, Parts.Status(item))
		local profession = professions[item.skillLine]
		if item.state == "known" then
			GameTooltip_AddInstructionLine(tooltip, L["Click to open the recipe."])
		elseif item.state == "trainable" and profession then
			if ns.TrainingFor(profession, item.recipeID) then
				ns.AddNearest(tooltip, L["Nearest trainer"], Parts.RecipeNPC(item, professions))
			else
				local source = ns.Catalogue.Recipe(item.recipeID)
				if source then
					ns.AddSourceLines(tooltip, source)
				end
				local npcID = Parts.RecipeNPC(item, professions)
				if npcID then
					ns.AddNearest(tooltip, L["Source"], npcID, true)
				end
			end
		end
	end
end

-- The page's one button: open a known recipe, set a waypoint to where a trainable one is taught, or
-- nothing with the reason why.
---@param item SkillUpGearItem|SkillUpBuffItem
---@param professions table<integer, SkillUpProfession>
---@return string text
---@return boolean enabled
---@return fun()? click
---@return string? reason
function Parts.Action(item, professions)
	if item.state == "known" then
		return L["Open recipe"], true, function()
			C_TradeSkillUI.OpenRecipe(item.recipeID)
		end
	end
	if item.state == "trainable" then
		local npcID = Parts.RecipeNPC(item, professions)
		if npcID then
			return L["Set waypoint"], true, function()
				ns.SetWaypoint(npcID)
			end
		end
		return L["Set waypoint"], false, nil, L["The place this recipe is taught isn't known yet."]
	end
	if item.skill == nil then
		return L["Set waypoint"], false, nil, L["The source of this recipe isn't known."]
	end
	if item.state == "needs" then
		return L["Set waypoint"], false, nil, string.format(L["Needs %s %d"], item.profession, item.skill)
	end
	return L["Set waypoint"], false, nil, L["Another craft makes this recipe, not yours."]
end

-- The buffs page's one action: the gear page's, except that another crafter's recipe says so in the reason
-- the button shows when it cannot be used.
---@param item SkillUpBuffItem
---@param professions table<integer, SkillUpProfession>
---@return string text
---@return boolean enabled
---@return fun()? click
---@return string? reason
function Parts.BuffAction(item, professions)
	if item.state == "other" then
		return L["Set waypoint"], false, nil, L["Another crafter"]
	end
	return Parts.Action(item, professions)
end

---@param item SkillUpGearItem|SkillUpBuffItem
---@return string
function Parts.ItemName(item)
	if item.name then
		return item.name
	end
	local name = C_Item.GetItemNameByID(item.itemID)
	if name then
		return name
	end
	-- ITEM_DATA_LOAD_RESULT redraws once the name arrives.
	C_Item.RequestLoadItemDataByID(item.itemID)
	return string.format(L["item %d"], item.itemID)
end
