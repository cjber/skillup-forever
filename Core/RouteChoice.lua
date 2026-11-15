---@type string, SkillUpNamespace
local _, ns = ...

if ns.broken then
	return
end

-- Selects among already validated transition candidates. State is the shared
-- purchased inventory, so a reagent carried into the next leg is not charged twice.
---@param segments table[]
---@param held table<integer, integer>
---@param maxStates integer?
---@return table[]?, number?, string?
function ns.SelectRouteChoices(segments, held, maxStates)
	maxStates = maxStates or 256
	local states = { { stock = held, choices = {}, cost = 0 } }
	for index, segment in ipairs(segments) do
		local nextStates = {}
		for _, state in ipairs(states) do
			for _, candidate in ipairs(segment.candidates or {}) do
				if type(candidate.use) == "table" and type(candidate.cost) == "table" then
					local stock, key = {}, {}
					for item, count in pairs(state.stock) do
						stock[item] = count
					end
					local purchase = 0
					for item, count in pairs(candidate.use) do
						local available = stock[item] or 0
						local unit = candidate.cost[item]
						if type(unit) ~= "number" or unit < 0 or unit ~= unit or unit == math.huge then
							purchase = nil
							break
						end
						purchase = purchase + math.max(count - available, 0) * unit
						stock[item] = math.max(available - count, 0)
					end
					if not purchase then
						goto continue
					end
					for item, count in pairs(stock) do
						key[#key + 1] = item .. "=" .. count
					end
					table.sort(key)
					local stateKey = table.concat(key, ",")
					local previous = nextStates[stateKey]
					local choices = {}
					for k, value in pairs(state.choices) do
						choices[k] = value
					end
					choices[index] = candidate
					if not previous or state.cost + purchase < previous.cost then
						nextStates[stateKey] = { stock = stock, choices = choices, cost = state.cost + purchase }
					end
				end
				::continue::
			end
		end
		local count = 0
		for _, state in pairs(nextStates) do
			count = count + 1
			states[count] = state
		end
		if count > maxStates then
			return nil, nil, "route choice state budget exceeded"
		end
		for i = count + 1, #states do
			states[i] = nil
		end
	end
	local best
	for _, state in ipairs(states) do
		if not best or state.cost < best.cost then
			best = state
		end
	end
	return best and best.choices, best and best.cost
end
