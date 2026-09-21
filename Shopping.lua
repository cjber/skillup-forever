local _, ns = ...

local CALLER = "SkillUp Forever"

function ns.HasAuctionator()
	local api = Auctionator and Auctionator.API and Auctionator.API.v1
	return api and api.CreateShoppingList and api.ConvertToSearchString and true or false
end

-- Bags and bank: the client knows bank counts once the bank has been opened.
local function Owned(itemID)
	return C_Item.GetItemCount(itemID, true)
end

local function Needs(route)
	return ns.Model.ShoppingList(route.segments, ns.Reagents, Owned, ns.PriceSource)
end

local function ItemName(itemID)
	return C_Item.GetItemNameByID(itemID) or ("item " .. itemID)
end

local BUCKETS = {
	{ "vendor", "From a vendor" },
	{ "auction", "From the auction house" },
	{ "unknown", "No price seen" },
}

function ns.ShowShoppingTooltip(owner, route)
	if not route then
		return
	end
	local needs = Needs(route)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip_SetTitle(GameTooltip, "Reagents still needed")
	local any = false
	for _, bucket in ipairs(BUCKETS) do
		local items = needs[bucket[1]]
		if #items > 0 then
			any = true
			GameTooltip_AddNormalLine(GameTooltip, bucket[2])
			for _, item in ipairs(items) do
				GameTooltip:AddDoubleLine(ItemName(item.itemID), "x" .. item.count, 1, 1, 1, 1, 1, 1)
			end
		end
	end
	if not any then
		GameTooltip_AddDisabledLine(GameTooltip, "You already have everything.")
	end
	GameTooltip:Show()
end

local function PrintNeeds(needs)
	for _, bucket in ipairs(BUCKETS) do
		local items = needs[bucket[1]]
		if #items > 0 then
			local parts = {}
			for _, item in ipairs(items) do
				parts[#parts + 1] = string.format("%s x%d", ItemName(item.itemID), item.count)
			end
			ns.Print(bucket[2] .. ": " .. table.concat(parts, ", "))
		end
	end
end

-- Auctionator searches by name, and names of unseen items arrive asynchronously.
local function WithNames(items, callback)
	local container = ContinuableContainer:Create()
	for _, item in ipairs(items) do
		container:AddContinuable(Item:CreateFromItemID(item.itemID))
	end
	container:ContinueOnLoad(callback)
end

-- One list per profession, replaced on each export. Vendor reagents stay in chat:
-- an auction search for them would only find resellers.
local function SendToAuctionator(profession, needs)
	local items = {}
	for _, bucket in ipairs({ needs.auction, needs.unknown }) do
		for _, item in ipairs(bucket) do
			items[#items + 1] = item
		end
	end
	if #items == 0 then
		return
	end
	WithNames(items, function()
		local api = Auctionator.API.v1
		local searches = {}
		for _, item in ipairs(items) do
			searches[#searches + 1] = api.ConvertToSearchString(
				CALLER,
				{ searchString = ItemName(item.itemID), isExact = true, quantity = item.count }
			)
		end
		local name = "SkillUp: " .. profession
		api.CreateShoppingList(CALLER, name, searches)
		ns.Print(string.format("sent %d reagents to the Auctionator list '%s'.", #searches, name))
	end)
end

function ns.ExportShopping(route)
	if not route then
		return
	end
	local needs = Needs(route)
	if #needs.vendor + #needs.auction + #needs.unknown == 0 then
		ns.Print("you already have every reagent for this route.")
		return
	end
	if ns.HasAuctionator() then
		SendToAuctionator(route.profession, needs)
		if #needs.vendor > 0 then
			PrintNeeds({ vendor = needs.vendor, auction = {}, unknown = {} })
		end
	else
		PrintNeeds(needs)
	end
end
