-- Run from the repository root: luajit tests/route_spec.lua
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local available = 2
local queries = 0
local ns = {
	IsLearned = function()
		return true
	end,
}
local env = setmetatable({
	C_Spell = {
		GetSpellName = function()
			return "Test recipe"
		end,
	},
	C_TradeSkillUI = {
		GetCraftableCount = function(recipeID)
			equal(recipeID, 42, "queries the first route recipe")
			queries = queries + 1
			return available
		end,
	},
}, { __index = _G })
assert(loadfile("Locales/enUS.lua"))("SkillUpForever", ns)
setfenv(assert(loadfile("Route.lua")), env)("SkillUpForever", ns)
ns.OpenSkillLine = function()
	return 171
end

local profession = { skillLine = 171, name = "Alchemy", capped = false, max = 75, modifier = 0 }
local route = { segments = { { recipeID = 42, fromSkill = 10, toSkill = 15, crafts = 5 } }, ranks = {} }
local craft = ns.NextCraft(profession, route)
equal(craft.count, 2, "the client count limits the batch even when bags would allow more")
equal(craft.recipeID, 42, "an available batch can be crafted")
available = 12
craft = ns.NextCraft(profession, route)
equal(craft.count, 5, "never crafts beyond the planned segment")
available = 0
craft = ns.NextCraft(profession, route)
equal(craft.recipeID, nil, "zero available disables crafting")
equal(craft.reason, "Missing reagents for this step.", "zero available explains the disabled button")
equal(queries, 3, "rechecks the client count after changes")

-- A segment past the cap stops where skill-ups do, until the next rank is trained.
ns.Model = {
	Get = function()
		return { 1, 60, 80, 100 }
	end,
	Chance = function(_, skill)
		return skill < 72 and 1 or 0.5
	end,
}
available = 99
route = { segments = { { recipeID = 42, fromSkill = 70, toSkill = 95, crafts = 40 } }, ranks = {} }
equal(ns.NextCraft(profession, route).count, 8, "crafts only to the cap: 2 sure then 3 half-chance points")

print("route_spec: " .. checks .. " checks passed")
