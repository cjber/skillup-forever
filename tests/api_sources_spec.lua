-- Public source reads over synthetic client providers, including the catalogue queue.
local Client = dofile("tests/client.lua")
local equal = Client.equal
local c = Client.load({
	boot = false,
	data = {
		RecipeData = { [101] = { skillLine = 197, reagents = {} }, [102] = { skillLine = 197, reagents = {} } },
		ScrollDrops = { [201] = { { 301, 12.5 }, { 302, 5 }, { 303, 1 }, { 999, 2 } } },
		WorldDrops = { [201] = true },
	},
	questie = {
		items = { [201] = { vendors = { 301, 302, 303, 999 }, quests = { 401, 402, 999 } } },
		npcs = {
			[301] = { name = "Friendly", side = "AH", spawns = { [10] = { { 50, 50 } } } },
			[302] = { name = "Horde", side = "H", spawns = { [10] = { { 50, 50 } } } },
			[303] = { name = "Unknown side", spawns = { [10] = { { 50, 50 } } } },
		},
		quests = { [401] = { name = "Shared", races = 0 }, [402] = { name = "Horde quest", races = 178 } },
		areas = { [10] = 10 },
	},
	atlasLoot = { recipes = { [201] = { 8, 40, 101 } } },
})
local API = c.G.SkillUpForever.API
local result, reason = API.RecipeSources(101)
equal(result, nil, "no sources before saved variables")
equal(reason, "loading", "saved variables are loading")
c.maps = { [0] = { mapID = 10, name = "Source Zone" } }
c.Boot()
result, reason = API.RecipeSources(999)
equal(result, nil, "unknown recipe")
equal(reason, "none", "unknown recipe has no source")
result, reason = API.RecipeSources(101)
equal(result, nil, "first read queues profession sources")
equal(reason, "loading", "queue is loading")
for _ = 1, 30 do
	c.Advance(0)
end
result = assert(API.RecipeSources(101))
equal(result.itemID, 201, "teaching item")
equal(result.world, true, "world drop")
equal(#result.vendors, 3, "unnamed vendors omitted")
equal(#result.quests, 2, "unnamed quests omitted")
equal(#result.drops, 3, "unnamed droppers omitted")
for _, rows in ipairs({ result.vendors, result.drops }) do
	for _, row in ipairs(rows) do
		equal(row.usable, row.npcID == 301, "NPC faction including unknown side")
		equal(row.zone, c.ns.NPCLocation(row.npcID).label, "tooltip location")
	end
end
for _, quest in ipairs(result.quests) do
	equal(quest.usable, quest.questID == 401, "quest faction")
end
equal(result.drops[1].chance, 12.5, "drop percent")
result.vendors[1].name = "changed"
result.quests[1].title = "changed"
result.drops[1].chance = 99
local fresh = assert(API.RecipeSources(101))
equal(fresh.vendors[1].name == "changed", false, "fresh vendor record")
equal(fresh.quests[1].title == "changed", false, "fresh quest record")
equal(fresh.drops[1].chance, 12.5, "fresh drop record")
result, reason = API.RecipeSources(102)
equal(result, nil, "recipe without teaching item")
equal(reason, "none", "no teaching item is known")
print("api_sources_spec: ok")
