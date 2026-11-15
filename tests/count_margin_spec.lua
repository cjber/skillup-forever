local ns = {}
assert(loadfile("Core/Model.lua"))("SkillUpForever", ns)
assert(loadfile("Core/Demand.lua"))("SkillUpForever", ns)
local input = {
	held = {},
	legs = {
		{
			fromSkill = 1,
			toSkill = 2,
			skillUps = 1,
			thresholds = { 0, 0, 0, 2 },
			use = { [1] = 1 },
			rawConsumption = true,
			deterministicOutput = true,
		},
		{
			fromSkill = 1,
			toSkill = 2,
			skillUps = 1,
			thresholds = { 0, 0, 0, 2 },
			use = { [1] = 1 },
			rawConsumption = true,
			deterministicOutput = true,
		},
	},
}
local basket = ns.Demand.ChooseBasket(input, { { [1] = 2 }, { [1] = 4 } }, 100, { [1] = 1 })
assert(basket and basket[1] == 4, "joint margin buys extra stock when shortfall is expensive")
local _, reason = ns.Demand.ChooseBasket(input, { { [1] = 2 } }, 100, {})
assert(reason == "observed basket cost unavailable", "unknown source cost stays unknown")
print("count margin: ok")
