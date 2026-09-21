local _, ns = ...

local CALLER = "SkillUp Forever"
-- Missing reagents shown per profession before "...".
local MAX_OBJECTIVES = 6

local module, buyButton

function ns.HasAuctionator()
	local api = Auctionator and Auctionator.API and Auctionator.API.v1
	return api and api.CreateShoppingList and api.ConvertToSearchString and true or false
end

-- Bags and bank: the client knows bank counts once the bank has been opened.
function ns.Have(itemID)
	return C_Item.GetItemCount(itemID, true)
end

-- What your other characters on this realm and faction hold (bags, bank, mail),
-- most first, when Syndicator is installed: they can mail it over.
function ns.AltCounts(itemID)
	local api = Syndicator and Syndicator.API
	if not (api and api.GetInventoryInfoByItemID and api.IsReady and api.IsReady()) then
		return {}
	end
	local info = api.GetInventoryInfoByItemID(itemID, true, true)
	local me, realm = UnitName("player"), GetNormalizedRealmName()
	local alts = {}
	for _, character in ipairs(info and info.characters or {}) do
		local count = character.bags + character.bank + character.mail
		if count > 0 and not (character.character == me and character.realmNormalized == realm) then
			alts[#alts + 1] = { name = character.character, count = count }
		end
	end
	table.sort(alts, function(a, b)
		return a.count > b.count
	end)
	return alts
end

-- Everything the route uses, as totals: what you have is compared live, so the
-- list stays right as you buy, craft or bank things.
function ns.RouteReagents(route)
	local list = ns.Model.ShoppingList(route.segments, ns.Reagents, function()
		return 0
	end, ns.PriceSource)
	local items = {}
	for _, source in ipairs({ "gather", "vendor", "auction", "unknown" }) do
		for _, item in ipairs(list[source]) do
			items[#items + 1] = { itemID = item.itemID, need = item.count, source = source }
		end
	end
	return items
end

-- Auctionator searches by name, and names of unseen items arrive asynchronously.
local function WithNames(items, callback)
	local container = ContinuableContainer:Create()
	for _, item in ipairs(items) do
		container:AddContinuable(Item:CreateFromItemID(item.itemID))
	end
	container:ContinueOnLoad(callback)
end

-- One list per profession, replaced on each export, of the auction house
-- reagents still missing (emptied when none are). Vendor reagents stay out: an
-- auction search for them would only find resellers, and gathered ones you get yourself.
function ns.SendToAuctionator(profession, items)
	local missing = {}
	for _, item in ipairs(items) do
		local count = item.need - ns.Have(item.itemID)
		if (item.source == "auction" or item.source == "unknown") and count > 0 then
			missing[#missing + 1] = { itemID = item.itemID, count = count }
		end
	end
	local api = Auctionator.API.v1
	local name = "SkillUp: " .. profession
	if #missing == 0 then
		api.CreateShoppingList(CALLER, name, {})
		ns.Print("nothing left to buy at the auction house.")
		return
	end
	WithNames(missing, function()
		local searches = {}
		for _, item in ipairs(missing) do
			searches[#searches + 1] = api.ConvertToSearchString(CALLER, {
				searchString = C_Item.GetItemNameByID(item.itemID),
				isExact = true,
				quantity = item.count,
			})
		end
		api.CreateShoppingList(CALLER, name, searches)
		ns.Print(string.format("sent %d reagents to the Auctionator list '%s'.", #searches, name))
	end)
end

function ns.IsTracked(skillLine)
	return ns.db.trackedProfessions[skillLine] == true
end

-- Every tracked profession of this character with the reagents its route still
-- needs; planned afresh each time, so it follows skill, target, bags and prices.
function ns.TrackedNeeds()
	local tracked = {}
	for skillLine, profession in pairs(ns.RouteProfessions()) do
		if ns.IsTracked(skillLine) then
			local route = ns.PlanRoute(profession)
			tracked[#tracked + 1] = {
				skillLine = skillLine,
				professionInfo = profession,
				route = route,
				items = ns.RouteReagents(route),
				modifier = profession.modifier,
			}
		end
	end
	table.sort(tracked, function(a, b)
		return a.route.profession < b.route.profession
	end)
	return tracked
end

-- What the open merchant sells for gold of the tracked reagents still missing,
-- and its cost. Two professions sharing a reagent need both amounts.
local function MerchantPurchases()
	local missing = {}
	for _, entry in ipairs(ns.TrackedNeeds()) do
		for _, item in ipairs(entry.items) do
			missing[item.itemID] = (missing[item.itemID] or -ns.Have(item.itemID)) + item.need
		end
	end
	local purchases, cost = {}, 0
	for index = 1, GetMerchantNumItems() do
		local itemID = GetMerchantItemID(index)
		local info = C_MerchantFrame.GetItemInfo(index)
		local count = itemID and missing[itemID]
		if count and count > 0 and info and info.price and info.price > 0 and not info.hasExtendedCost then
			local stack = math.max(info.stackCount or 1, 1)
			count = math.ceil(count / stack) * stack
			if info.numAvailable and info.numAvailable >= 0 then
				count = math.min(count, info.numAvailable * stack)
			end
			if count > 0 then
				purchases[#purchases + 1] = { index = index, count = count, stack = stack }
				cost = cost + info.price * count / stack
			end
		end
	end
	return purchases, cost
end

-- BuyMerchantItem counts units, priced per merchant stack, and takes at most
-- GetMerchantItemMaxStack units a call (Blizzard's MerchantFrame does the same).
local function BuyMissing()
	local purchases, cost = MerchantPurchases()
	if cost > GetMoney() then
		ns.Print("not enough money for every missing reagent here.")
		return
	end
	for _, purchase in ipairs(purchases) do
		local perCall = math.max(math.floor(GetMerchantItemMaxStack(purchase.index) / purchase.stack), 1)
			* purchase.stack
		local remaining = purchase.count
		while remaining > 0 do
			local count = math.min(remaining, perCall)
			BuyMerchantItem(purchase.index, count)
			remaining = remaining - count
		end
	end
end

local function RefreshBuyButton()
	if not (MerchantFrame and MerchantFrame:IsShown()) then
		if buyButton then
			buyButton:Hide()
		end
		return
	end
	local purchases, cost = MerchantPurchases()
	if #purchases == 0 then
		if buyButton then
			buyButton:Hide()
		end
		return
	end
	if not buyButton then
		buyButton = CreateFrame("Button", nil, MerchantFrame, "UIPanelButtonTemplate")
		buyButton:SetPoint("BOTTOMRIGHT", MerchantFrame, "TOPRIGHT", 0, 2)
		buyButton:SetScript("OnClick", BuyMissing)
	end
	buyButton:SetText("Buy tracked reagents  " .. C_CurrencyInfo.GetCoinTextureString(cost))
	buyButton:SetSize(buyButton:GetTextWidth() + 32, 22)
	buyButton:Show()
end

function ns.TrackerAttached()
	return module ~= nil and ObjectiveTrackerManager:GetContainerForModule(module) ~= nil
end

function ns.RefreshTracker()
	if module then
		module:MarkDirty()
	end
	RefreshBuyButton()
end

function ns.SetTracked(skillLine, tracked)
	ns.db.trackedProfessions[skillLine] = tracked or nil
	PlaySound(tracked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
	ns.RefreshTracker()
end

local ModuleMixin = { headerText = "Profession reagents" }

function ModuleMixin:OnBlockHeaderClick(block)
	MenuUtil.CreateContextMenu(self:GetContextMenuParent(), function(_, root)
		root:CreateTitle(block.profession)
		-- Only while this profession is open: the client crafts from the open one.
		local craft = ns.NextCraft(block.professionInfo, block.route)
		if craft.recipeID then
			root:CreateButton(craft.text, function()
				C_TradeSkillUI.CraftRecipe(craft.recipeID, craft.count)
			end)
		end
		local trainer = block.steps[1] and ns.NearestTrainer(block.professionInfo, block.steps[1].cap)
		if trainer then
			root:CreateButton("Waypoint to a trainer", function()
				ns.SetWaypoint(trainer)
			end)
		end
		for _, item in ipairs(block.vendorMissing) do
			root:CreateButton("Waypoint to a vendor: " .. item.name, function()
				ns.SetWaypoint(item.vendor)
			end)
		end
		if ns.HasAuctionator() then
			root:CreateButton("Send missing to Auctionator", function()
				ns.SendToAuctionator(block.profession, block.items)
			end)
		end
		root:CreateButton("Stop tracking", function()
			ns.SetTracked(block.id, false)
			ns.RefreshRoute()
		end)
	end)
end

-- Where each training happens, in base skill: ranks when the trainer allows them,
-- recipes where the route first uses them.
local function TrainingSteps(entry)
	local steps = {}
	for _, rank in ipairs(entry.route.ranks) do
		steps[#steps + 1] = { skill = rank.reqSkill, cap = rank.cap, text = ns.RankText(rank) }
	end
	for _, step in ipairs(entry.route.training) do
		local name = C_Spell.GetSpellName(step.recipeID) or ("recipe " .. step.recipeID)
		local skill = step.atSkill - entry.modifier
		-- A trainer teaches recipes needing less than the cap they train to.
		local cap = ns.TrainingFor(entry.professionInfo, step.recipeID)[2] + 1
		steps[#steps + 1] = { skill = skill, cap = cap, text = string.format("Train %s at %d", name, skill) }
	end
	table.sort(steps, function(a, b)
		return a.skill < b.skill
	end)
	return steps
end

-- Compact, quest style, under "Tailoring to 125": the next thing to train, then
-- only the reagents still missing, as "12/20 Linen Cloth". The page has the rest.
function ModuleMixin:LayoutContents()
	for _, entry in ipairs(ns.TrackedNeeds()) do
		local block = self:GetBlock(entry.skillLine)
		block.profession, block.items = entry.route.profession, entry.items
		block.professionInfo, block.vendorMissing, block.route = entry.professionInfo, {}, entry.route
		block:SetHeader(string.format("%s to %d", entry.route.profession, entry.route.target))
		local steps = TrainingSteps(entry)
		block.steps = steps
		if #steps > 0 then
			local more = #steps > 1 and string.format(" |cff808080(+%d more)|r", #steps - 1) or ""
			block:AddObjective("Train", steps[1].text .. more)
		end
		local shown = 0
		for _, item in ipairs(entry.items) do
			local have = ns.Have(item.itemID)
			if have < item.need then
				if shown == MAX_OBJECTIVES then
					block:AddObjective("Extra", "...", nil, nil, OBJECTIVE_DASH_STYLE_HIDE)
					break
				end
				shown = shown + 1
				local name = C_Item.GetItemNameByID(item.itemID)
				if not name then
					C_Item.RequestLoadItemDataByID(item.itemID)
					name = "item " .. item.itemID
				end
				local gather = item.source == "gather" and " |cff808080(gather)|r" or ""
				block:AddObjective(item.itemID, string.format("%d/%d %s%s", have, item.need, name, gather))
				local vendor = item.source == "vendor" and ns.NearestVendor(item.itemID)
				if vendor then
					block.vendorMissing[#block.vendorMissing + 1] = { name = name, vendor = vendor }
				end
			end
		end
		if shown == 0 then
			block:AddObjective("Ready", "Reagents in hand", nil, nil, nil, OBJECTIVE_TRACKER_COLOR.Complete)
		end
		if not self:LayoutBlock(block) then
			return
		end
	end
end

-- Attaching is a no-op until Blizzard's manager has added ObjectiveTrackerFrame as a
-- container. Its Init is scheduled as a closure over the original function, so hooking
-- Init never fires; AddContainer is looked up on the table and can be hooked.
local function Attach()
	ObjectiveTrackerManager:SetModuleContainer(module, ObjectiveTrackerFrame)
end

local function CreateModule()
	if not (ObjectiveTrackerManager and ObjectiveTrackerFrame) then
		ns.Print("the objective tracker isn't available, so tracked reagents can't be shown.")
		return
	end
	module = CreateFrame("Frame", "SkillUpForeverObjectiveTracker", UIParent, "ObjectiveTrackerModuleTemplate")
	Mixin(module, ModuleMixin)
	module:SetHeader(ModuleMixin.headerText)
	-- Above every Blizzard section (quests start at 1), so quests filling the tracker
	-- can't push it out of sight.
	module.uiOrder = -2
	hooksecurefunc(ObjectiveTrackerManager, "AddContainer", function(_, container)
		if container == ObjectiveTrackerFrame then
			Attach()
		end
	end)
	Attach()
	C_Timer.After(5, function()
		if not ObjectiveTrackerManager:GetContainerForModule(module) then
			ns.Print("couldn't add tracked reagents to the objective tracker; please report it.")
		end
	end)
end

function ns.InitShopping()
	CreateModule()
	local events = CreateFrame("Frame")
	for _, event in ipairs({
		"BAG_UPDATE_DELAYED",
		"ITEM_DATA_LOAD_RESULT",
		"SKILL_LINES_CHANGED",
		"TRADE_SKILL_LIST_UPDATE",
		"MERCHANT_SHOW",
		"MERCHANT_UPDATE",
		"MERCHANT_CLOSED",
	}) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", ns.RefreshTracker)
end
