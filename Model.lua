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

-- Rounds to the two largest coins so a row stays short: 1g 23s, 45s, 80c.
function Model.RoundMoney(copper)
	local unit = copper >= 1000000 and 10000 or copper >= 10000 and 100 or copper >= 100 and 100 or 1
	return math.max(math.floor(copper / unit + 0.5), 1) * unit
end
