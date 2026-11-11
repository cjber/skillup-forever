-- Run from the repository root: luajit tests/character_key_spec.lua
-- The per-character key early in loading, when GetNormalizedRealmName still returns nil: the realm falls back to
-- GetRealmName in the normalized form, and with no realm at all every per-character setting reads its default and
-- saves nothing, rather than raising "attempt to concatenate a nil value".
local Client = dofile("tests/client.lua")
local equal = Client.equal

local c = Client.load({})
local ns, G = c.ns, c.G

equal(ns.CharacterKey(), "Tester-Realm", "the normalized realm when the client has it")

G.GetNormalizedRealmName = function()
	return nil
end
G.GetRealmName = function()
	return "Pyrewood Village"
end
equal(ns.CharacterKey(), "Tester-PyrewoodVillage", "spaces stripped from the display realm")
G.GetRealmName = function()
	return "Azjol-Nerub"
end
equal(ns.CharacterKey(), "Tester-AzjolNerub", "hyphens stripped from the display realm")
equal(ns.NormalizedRealm(), "AzjolNerub", "the realm Shopping compares alts with")

G.GetRealmName = function()
	return nil
end
equal(ns.CharacterKey(), nil, "no key while the client has no realm")
equal(ns.NormalizedRealm(), nil, "no realm either")

local FIELDS = { "collectModes", "showAllGear", "skippedRecipes", "learned" }
local function Keys(field)
	local count = 0
	for _ in pairs(ns.db[field]) do
		count = count + 1
	end
	return count
end
local before = {}
for _, field in ipairs(FIELDS) do
	before[field] = Keys(field)
end
equal(ns.CollectMode(), "auction", "the collect mode reads its default")
ns.SetCollectMode("gather")
equal(ns.CollectMode(), "auction", "and saves nothing")
equal(ns.ShowAllGear(), false, "show all gear reads its default")
ns.SetShowAllGear(true)
equal(ns.ShowAllGear(), false, "and saves nothing")
equal(ns.IsSkipped(3275), false, "no recipe is skipped")
ns.SetSkipped(3275, true)
equal(ns.IsSkipped(3275), false, "and a skip is not saved")
equal(#ns.SkippedRecipes(), 0, "the skipped list is empty")
ns.NoteLearnedRecipe(3275, true)
for _, field in ipairs(FIELDS) do
	equal(Keys(field), before[field], field .. " is untouched")
end

Client.report("character_key_spec")
