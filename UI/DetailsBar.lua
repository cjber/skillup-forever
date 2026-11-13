---@type string, SkillUpNamespace
local _, ns = ...

if ns.broken then
	return
end

-- The recipe tooltip's skill bar on the crafting page itself (#172): the selected recipe's orange, yellow, green
-- and grey thresholds with the pip at your skill, just under the recipe, instead of only on the hover. It draws
-- the tooltip's own bar (ns.CreateSkillBar and ns.LayoutSkillBar) from the same numbers.

-- The details pane stacks the recipe's icon and name, the client's own description slot beneath them, then the
-- reagents header. The bar goes in the name's column, under the name or the tool requirement the client draws
-- below it, so it clears the icon; and it only draws where the client has left it that room above the reagents
-- header, so a wrapped name or a tool line that filled the space keeps it hidden instead of covering anything.
-- A native description takes that space too, and keeps the bar hidden as before (#660, #674).
local BAR_GAP = 2

---@class SkillUpDetailsBar : Frame
---@field bar SkillUpBar
---@field form SkillUpSchematicForm
---@field nativeDescription FontString?

---@type SkillUpDetailsBar?
local frame
---@type integer?
local recipeID

---@param description FontString?
---@return boolean
local function DescriptionVisible(description)
	return description ~= nil
		and description.IsShown ~= nil
		and description:IsShown()
		and description.GetText ~= nil
		and (description:GetText() or "") ~= ""
end

-- What the bar draws for a recipe at a skill: its four thresholds and where the player's skill sits on them.
-- Nothing without thresholds, a skill to place, or all four numbers.
---@param t number[]?
---@param skill number?
---@return number[]? thresholds
---@return number? skill
function ns.DetailsBar(t, skill)
	if not t or not skill or not t[1] or not t[2] or not t[3] or not t[4] then
		return nil
	end
	return t, skill
end

-- The recipe whose bar is drawn: the highest learned version of the selected one, as the recipe tooltip draws it.
---@param info TradeSkillRecipeInfo?
---@return integer?
function ns.DetailsBarRecipe(info)
	local recipeInfo = info and (Professions.GetHighestLearnedRecipe(info) or info)
	return recipeInfo and recipeInfo.recipeID or nil
end

-- The client's frame the bar sits under: the tool requirement when the recipe has one, else the recipe's name.
-- Both start at the icon's right edge, so the bar's column clears the icon; both are the client's own frames, so
-- a long name or a missing tool line moves the bar with them.
---@param form SkillUpSchematicForm
---@return FontString?
function ns.DetailsBarAnchor(form)
	local tools = form.RequiredTools
	if tools ~= nil and tools.IsShown ~= nil and tools:IsShown() then
		return tools
	end
	return form.OutputText
end

-- Whether the client leaves the bar its height between that frame's bottom and the reagents header, in the
-- pane's own coordinates. A recipe with no reagents has no header to clear; nil means the client has not laid
-- the pane out yet, so the caller keeps the bar rather than hiding it on a guess.
---@param form SkillUpSchematicForm
---@param anchor FontString
---@param height number
---@return boolean? room
function ns.DetailsBarRoom(form, anchor, height)
	local reagents = form.Reagents
	if reagents == nil or reagents.IsShown == nil or not reagents:IsShown() then
		return true
	end
	if anchor.GetBottom == nil or reagents.GetTop == nil then
		return nil
	end
	local bottom, top = anchor:GetBottom(), reagents:GetTop()
	if bottom == nil or top == nil then
		return nil
	end
	return bottom - top >= height + BAR_GAP
end

local function Refresh()
	if not frame then
		return
	end
	local form = frame.form
	local ctx = ns.SkillContext()
	local t, skill = ns.DetailsBar(recipeID and ns.RangeThresholds(ctx, recipeID), ctx and ctx.skill)
	local anchor = ns.DetailsBarAnchor(form)
	if
		t == nil
		or skill == nil
		or not ns.db.detailsBar
		or DescriptionVisible(frame.nativeDescription)
		or anchor == nil
		or ns.DetailsBarRoom(form, anchor, frame.bar:GetHeight()) == false
	then
		frame:SetShown(false)
		return
	end
	ns.LayoutSkillBar(frame.bar, t, skill)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -BAR_GAP)
	frame.bar:Show()
	frame:SetShown(true)
end

-- The window's selection is kept even while the bar is hidden, so turning the setting back on draws it again.
---@param _ Frame
---@param info TradeSkillRecipeInfo?
local function OnRecipeSelected(_, info)
	recipeID = ns.DetailsBarRecipe(info)
	Refresh()
end

-- The bar is our own frame, parented to the crafting page and anchored to the client's own name and reagents
-- frames: nothing of the pane's own points, scripts or callbacks is touched, so it stays safe in combat and
-- through Create All.
function ns.AttachDetailsBar()
	local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
	---@cast page SkillUpCraftingPage
	local form = page and page.SchematicForm
	if frame or not form then
		return
	end
	local details = CreateFrame("Frame", nil, page) --[[@as SkillUpDetailsBar]]
	details.form = form
	details.nativeDescription = form.Description
	details.bar = ns.LayoutSkillBar(ns.CreateSkillBar(), { 1, 26, 41, 56 }, 1)
	details:SetSize(250, details.bar:GetHeight())
	details.bar:SetParent(details)
	details.bar:ClearAllPoints()
	details.bar:SetPoint("TOPLEFT", details, "TOPLEFT")
	details:Hide()
	frame = details
	EventRegistry:RegisterCallback("ProfessionsRecipeListMixin.Event.OnRecipeSelected", OnRecipeSelected, details)
	local info = form.GetRecipeInfo and form:GetRecipeInfo()
	OnRecipeSelected(details, info)
	ns.WhenStale("detailsBar", Refresh)
	-- A reopened window draws the profession it opens with once Blizzard has chosen its recipe.
	ns.WhenEvent("TRADE_SKILL_SHOW", function()
		C_Timer.After(0, Refresh)
	end)
end
