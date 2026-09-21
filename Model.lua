local _, ns = ...
local Model = {}
ns.Model = Model

function Model.Get(recipeID)
	return ns.Thresholds and ns.Thresholds[recipeID]
end

function Model.Color(t, skill)
	if not t then
		return nil
	end
	if skill < t[1] then
		return "red"
	end
	if skill < t[2] then
		return "orange"
	end
	if skill < t[3] then
		return "yellow"
	end
	if skill < t[4] then
		return "green"
	end
	return "grey"
end

function Model.Chance(t, skill)
	if not t or t[4] <= t[2] or skill < t[1] then
		return nil
	end
	if skill < t[2] then
		return 1
	end
	if skill >= t[4] then
		return 0
	end
	return (t[4] - skill) / (t[4] - t[2])
end

-- Copper for one craft, or nil when any reagent has no known price: a partial
-- sum would rank a recipe as cheap only because we can't price its reagents.
function Model.RecipeCost(reagents, price)
	if not reagents then
		return nil
	end
	local total = 0
	for _, reagent in ipairs(reagents) do
		local each = price(reagent.itemID)
		if not each then
			return nil
		end
		total = total + each * reagent.quantity
	end
	return total
end

-- Expected spend per skill point: one craft costs `cost` and succeeds with `chance`.
function Model.CostPerSkillUp(cost, chance)
	if not cost or not chance or chance <= 0 then
		return nil
	end
	return cost / chance
end

-- Inputs are already filtered to learned recipes of one profession, with prices
-- frozen by the caller. Inventory affects shopping, never recipe selection.
function Model.PlanRoute(snapshot)
	local route = {
		segments = {},
		expectedCost = 0,
		reachedSkill = snapshot.skill,
		excluded = { unpriced = 0 },
	}
	local priced = {}
	for _, recipe in ipairs(snapshot.recipes) do
		if recipe.netCost == nil then
			route.excluded.unpriced = route.excluded.unpriced + 1
		else
			priced[#priced + 1] = recipe
		end
	end
	while route.reachedSkill < snapshot.target do
		local skill = route.reachedSkill
		local best, bestCost, bestChance
		for _, recipe in ipairs(priced) do
			local chance = Model.Chance(recipe.thresholds, skill)
			local cost = Model.CostPerSkillUp(recipe.netCost, chance)
			if cost and (not best or cost < bestCost or (cost == bestCost and recipe.recipeID < best.recipeID)) then
				best, bestCost, bestChance = recipe, cost, chance
			end
		end
		if not best then
			route.stopReason = "no_recipe"
			break
		end
		local segment = route.segments[#route.segments]
		if not segment or segment.recipeID ~= best.recipeID then
			segment = { recipeID = best.recipeID, fromSkill = skill, toSkill = skill, expectedCrafts = 0 }
			route.segments[#route.segments + 1] = segment
		end
		segment.toSkill = skill + 1
		segment.expectedCrafts = segment.expectedCrafts + 1 / bestChance
		route.expectedCost = route.expectedCost + bestCost
		route.reachedSkill = skill + 1
	end
	for _, segment in ipairs(route.segments) do
		segment.crafts = math.ceil(segment.expectedCrafts)
	end
	return route
end

-- Reach comes first when the learned route is blocked; compare costs only for
-- equal endpoints. Each candidate is a separate purchase, charged exactly once.
function Model.RecommendTraining(snapshot, services)
	local baseline = Model.PlanRoute(snapshot)
	local recipes = {}
	for index, recipe in ipairs(snapshot.recipes) do
		recipes[index] = recipe
	end
	local candidate = { skill = snapshot.skill, target = snapshot.target, recipes = recipes }
	local best
	for _, service in ipairs(services) do
		recipes[#snapshot.recipes + 1] = service
		local route = Model.PlanRoute(candidate)
		local savings = baseline.expectedCost - (route.expectedCost + service.fee)
		local helps = route.reachedSkill > baseline.reachedSkill
			or (route.reachedSkill == baseline.reachedSkill and savings > 0)
		if
			helps
			and (
				not best
				or route.reachedSkill > best.reachedSkill
				or (route.reachedSkill == best.reachedSkill and savings > best.savings)
				or (
					route.reachedSkill == best.reachedSkill
					and savings == best.savings
					and service.recipeID < best.recipeID
				)
			)
		then
			best = { recipeID = service.recipeID, savings = savings, reachedSkill = route.reachedSkill }
		end
	end
	return best
end

function Model.ShoppingList(segments, reagentsOf, owned, sourceOf)
	local needed = {}
	for _, segment in ipairs(segments) do
		for _, reagent in ipairs(reagentsOf(segment.recipeID) or {}) do
			needed[reagent.itemID] = (needed[reagent.itemID] or 0) + segment.crafts * reagent.quantity
		end
	end
	local list = { vendor = {}, auction = {}, unknown = {} }
	for itemID, quantity in pairs(needed) do
		local count = math.max(0, quantity - owned(itemID))
		if count > 0 then
			local source = sourceOf(itemID)
			local bucket = source == "vendor" and list.vendor
				or (source == "scan" or source == "auctionator") and list.auction
				or list.unknown
			bucket[#bucket + 1] = { itemID = itemID, count = count }
		end
	end
	for _, bucket in pairs(list) do
		table.sort(bucket, function(a, b)
			return a.itemID < b.itemID
		end)
	end
	return list
end

function Model.BuildReagentIndex(recipeData)
	local index = {}
	for recipeID, recipe in pairs(recipeData) do
		local seen = {}
		for _, reagent in ipairs(recipe.reagents) do
			local itemID = reagent.itemID
			if not seen[itemID] then
				index[itemID] = index[itemID] or {}
				local recipes = index[itemID]
				recipes[#recipes + 1] = recipeID
				seen[itemID] = true
			end
		end
	end
	for _, recipes in pairs(index) do
		table.sort(recipes)
	end
	return index
end

function Model.MatchTrainerService(names, skillLine, name)
	local profession = names and names[skillLine]
	return profession and profession[name] or nil
end

-- What one crafted item is worth under `mode`, and where that came from. Auction
-- value is net of the house's 5% cut and only counts when it beats the vendor.
local AUCTION_CUT = 0.05
function Model.CraftValue(sell, auction, mode)
	if mode == "none" then
		return nil
	end
	local vendor = sell and sell > 0 and sell or nil
	local resale = mode == "auction" and auction and auction * (1 - AUCTION_CUT) or nil
	if resale and (not vendor or resale > vendor) then
		return resale, "auction"
	end
	return vendor, vendor and "vendor" or nil
end

-- Rounds to the two largest coins so a row stays short: 1g 23s, 45s, 80c.
function Model.RoundMoney(copper)
	local unit = copper >= 1000000 and 10000 or copper >= 10000 and 100 or copper >= 100 and 100 or 1
	return math.max(math.floor(copper / unit + 0.5), 1) * unit
end
