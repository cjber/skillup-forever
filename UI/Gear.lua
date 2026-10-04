---@type string, SkillUpNamespace
local _, ns = ...
local L = ns.L

-- The crafted gear page: one side tab on the Professions window listing, per equipment slot, the
-- newest items this character can equip. The listing rule is Core/Gear.lua's; this draws it.

---@type SkillUpGearPage
local page
---@type SkillUpSideTab
local tab

---@param itemID integer
---@return ColorMixin
local function QualityColor(itemID)
	local quality = C_Item.GetItemQualityByID(itemID)
	if not quality then
		return ns.COLORS.unknown
	end
	local red, green, blue = C_Item.GetItemQualityColor(quality)
	return CreateColor(red, green, blue)
end

---@param item SkillUpGearItem
---@return string
local function Status(item)
	if item.learned then
		return L["You know it"]
	elseif item.learnable then
		return L["Can learn it"]
	end
	return L["Another crafter"]
end

---@param item SkillUpGearItem
---@return fun(tooltip: GameTooltip)
local function ItemTooltip(item)
	return function(tooltip)
		tooltip:SetItemByID(item.itemID)
		GameTooltip_AddBlankLineToTooltip(tooltip)
		GameTooltip_AddNormalLine(tooltip, string.format(L["%s, %d"], item.profession, item.skill))
		GameTooltip_AddNormalLine(tooltip, Status(item))
	end
end

local function Render()
	local _, _, classID = UnitClass("player")
	local slots = ns.CraftedGear(UnitLevel("player"), classID)
	if #slots == 0 then
		page.List:Message(L["No crafted gear for your level and class yet."])
		page.List:Finish()
		return
	end
	page.List:Message(L["The newest item you can craft and wear in each slot, not a best-in-slot list."])
	for _, slot in ipairs(slots) do
		page.List:Message(slot.name, NORMAL_FONT_COLOR)
		for _, item in ipairs(slot.items) do
			local name = C_Item.GetItemNameByID(item.itemID)
			if not name then
				-- ITEM_DATA_LOAD_RESULT redraws once the name arrives.
				C_Item.RequestLoadItemDataByID(item.itemID)
				name = string.format(L["item %d"], item.itemID)
			end
			page.List:Add({
				icon = C_Item.GetItemIconByID(item.itemID),
				text = name,
				note = Status(item),
				values = { tostring(item.skill), item.profession },
				color = QualityColor(item.itemID),
				tooltip = ItemTooltip(item),
			})
		end
	end
	page.List:Finish()
end

local function SelectPage()
	if ns.HideRoute then
		ns.HideRoute()
	end
	ProfessionsFrame.CraftingPage:Hide()
	ProfessionsFrame.BookPage:Hide()
	page:Show()
	ProfessionsFrame:RightTabSelected(tab)
end

-- Blizzard's own tabs show their page explicitly, which hands the window back.
local function Deselect()
	page:Hide()
	tab:SetChecked(false)
end
ns.HideGear = Deselect

-- Blizzard reselects its profession tab on skill updates; keep ours checked while our page shows.
local function SyncChecks()
	local shown = page:IsShown()
	tab:SetChecked(shown)
	if shown then
		ProfessionsFrame.ProfessionsOverviewTab:SetChecked(false)
		for _, professionTab in ipairs(ProfessionsFrame.rightProfessionTabs or {}) do
			professionTab:SetChecked(false)
		end
		if ns.RouteTab then
			ns.RouteTab:SetChecked(false)
		end
	end
end

-- Directly under the route tab, or under the last profession tab when that is off.
local function PlaceTab()
	local above = ProfessionsFrame.ProfessionsOverviewTab
	if ns.RouteTab and ns.RouteTab:IsShown() then
		above = ns.RouteTab
	else
		for _, professionTab in ipairs(ProfessionsFrame.rightProfessionTabs or {}) do
			if professionTab:IsShown() then
				above = professionTab
			end
		end
	end
	tab:ClearAllPoints()
	tab:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -2)
end

-- The tab can be turned off in settings; an open page goes back to crafting.
local function RefreshTab()
	tab:SetShown(ns.db.showGearTab)
	PlaceTab()
	if not ns.db.showGearTab and page:IsShown() then
		Deselect()
		ProfessionsFrame.CraftingPage:Show()
	end
end

local function Refresh()
	RefreshTab()
	if page:IsShown() then
		Render()
	end
end

---@param name string
---@return Frame
local function CreateInset(name)
	local inset = CreateFrame("Frame", nil, page, "InsetFrameTemplate") --[[@as Frame]]
	local title = inset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("BOTTOMLEFT", inset, "TOPLEFT", 4, 4)
	title:SetText(name)
	return inset
end

local function CreatePage()
	page = CreateFrame("Frame", nil, ProfessionsFrame) --[[@as SkillUpGearPage]]
	page:SetAllPoints(ProfessionsFrame.CraftingPage)
	page:SetFrameLevel(ProfessionsFrame.CraftingPage:GetFrameLevel())
	page:Hide()
	local inset = CreateInset(L["Crafted gear"])
	inset:SetPoint("TOPLEFT", 16, -88)
	inset:SetPoint("BOTTOMRIGHT", -16, 16)
	page.List = ns.CreateList(inset, {
		{ title = L["Skill"], width = 40 },
		{ title = L["Profession"], width = 110 },
	})
	page:SetScript("OnShow", Render)
end

local function CreateTab()
	tab = CreateFrame("Frame", nil, ProfessionsFrame, "LargeSideTabButtonTemplate") --[[@as SkillUpSideTab]]
	tab.Icon:SetTexture("Interface\\Icons\\INV_Chest_Chain_05")
	tab:SetFillToInterior(true)
	tab.tooltipText = L["Crafted gear"]
	tab:EnableMouse(true)
	tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
		if button == "LeftButton" and upInside then
			SelectPage()
		end
	end)
	PlaceTab()
	RefreshTab()
	ns.GearTab = tab
	ns.PlaceGearTab = PlaceTab
	ProfessionsFrame:HookScript("OnShow", PlaceTab)
	page:HookScript("OnShow", SyncChecks)
end

function ns.AttachGear()
	CreatePage()
	CreateTab()
	ProfessionsFrame.CraftingPage:HookScript("OnShow", Deselect)
	ProfessionsFrame.BookPage:HookScript("OnShow", Deselect)
	-- A reopened window starts on the crafting page, as Blizzard expects.
	ProfessionsFrame:HookScript("OnHide", function()
		if page:IsShown() then
			Deselect()
			ProfessionsFrame.CraftingPage:Show()
		end
	end)
	ns.WhenStale("gear", Refresh)
end
