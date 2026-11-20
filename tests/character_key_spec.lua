-- Run from the repository root: luajit tests/character_key_spec.lua
-- The per-character key is ForeverCore's (#916). On a Forever realm the client has no realm name, so two characters
-- sharing a first name stay apart by surname and server; on a named realm the key is "Name-Realm" as before. With no
-- name or GUID yet, every per-character setting reads its default and saves nothing.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local c = Client.load({})
local ns, G = c.ns, c.G

equal(ns.CharacterKey(), "Tester Surname-6941", "a Forever realm keys by name, surname and server")
equal(ns.CharacterKey(), G.ForeverCore.CharacterKey(), "the key is ForeverCore's")
c.player.surname = "Other"
equal(ns.CharacterKey(), "Tester Other-6941", "a second Tester on the server has their own key")
c.player.surname = "Surname"

c.player.realm = "Realm"
equal(ns.CharacterKey(), "Tester-Realm", "a named realm keeps its Name-Realm key")
c.player.realm = ""

local UnitGUID = G.UnitGUID
G.UnitGUID = function()
	return nil
end
equal(ns.CharacterKey(), nil, "no key while the client has no player GUID")

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

G.UnitGUID = UnitGUID
equal(ns.CharacterKey(), "Tester Surname-6941", "the key arrives once the GUID does")

Client.report("character_key_spec")
