-- Dumps the generated Data files as JSON lines for tools/check_refresh.py's refresh guard: one line per record
-- the player could lose, with only the fields the guard compares. Run as:
--   luajit tools/data_dump.lua <data-dir> <out.jsonl>
-- <data-dir> holds the five files tools/gen_*.py write (Thresholds, Recipes, Trainer, Sources, Vendor). Each is
-- loaded with a stub ns, exactly as the addon loads it, so the dump cannot drift from what the game reads.
-- An output of false is dumped as "none"; absent fields are left out of the line, and object keys are sorted,
-- so the same data dumps byte for byte identically.
local data, output = ...
if not data or not output then
	error("usage: luajit tools/data_dump.lua <data-dir> <out.jsonl>")
end

local escapes = {
	['"'] = '\\"',
	["\\"] = "\\\\",
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
}

local function json_string(value)
	local body = value:gsub('[%c"\\]', function(char)
		return escapes[char] or ("\\u%04x"):format(char:byte())
	end)
	return '"' .. body .. '"'
end

local json

local function json_table(value)
	-- An array is a table whose keys are exactly 1..n; anything else is an object with sorted keys.
	local count = 0
	local array = true
	for key in pairs(value) do
		count = count + 1
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
			array = false
		end
	end
	if array then
		local items = {}
		for index = 1, count do
			items[index] = json(value[index])
		end
		return "[" .. table.concat(items, ",") .. "]"
	end
	local keys = {}
	for key in pairs(value) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	local parts = {}
	for _, key in ipairs(keys) do
		parts[#parts + 1] = json_string(key) .. ":" .. json(value[key])
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

function json(value)
	local kind = type(value)
	if kind == "nil" then
		return "null"
	elseif kind == "boolean" then
		return tostring(value)
	elseif kind == "number" then
		return ("%.14g"):format(value)
	elseif kind == "string" then
		return json_string(value)
	elseif kind == "table" then
		return json_table(value)
	end
	return error("cannot serialize a " .. kind)
end

local ns = {}
for _, name in ipairs({ "Thresholds", "Recipes", "Trainer", "Sources", "Vendor" }) do
	local path = data .. "/" .. name .. ".lua"
	local handle = assert(io.open(path, "r"))
	local source = handle:read("*a")
	handle:close()
	local chunk = assert(loadstring(source, "@" .. path))
	-- The files read the addon's name and their namespace off varargs; a stub keeps the tables here.
	assert(setfenv(chunk, {}))
	chunk("SkillUpForever", ns)
end

local lines = {}

local function add(line)
	lines[#lines + 1] = line
end

local function ids(values)
	local list = {}
	for id in pairs(values) do
		list[#list + 1] = id
	end
	table.sort(list)
	return list
end

-- recipe: the skill-up thresholds
for _, id in ipairs(ids(ns.Thresholds or {})) do
	local row = ns.Thresholds[id]
	add({ kind = "recipe", id = id, orange = row[1], yellow = row[2], green = row[3], grey = row[4] })
end

-- craft: what a recipe makes and consumes
for _, id in ipairs(ids(ns.RecipeData or {})) do
	local row = ns.RecipeData[id]
	local reagents = {}
	for index, reagent in ipairs(row.reagents or {}) do
		reagents[index] = { i = reagent.itemID, q = reagent.quantity }
	end
	if next(reagents) == nil then
		reagents = nil
	end
	local out
	if row.output == false then
		out = "none"
	elseif type(row.output) == "table" then
		out = { i = row.output.itemID, q = row.output.quantity }
	end
	add({ kind = "craft", id = id, skill = row.skillLine, reagents = reagents, output = out })
end

-- trainer_fee: the base fee and required skill a trainer asks for a recipe
for _, id in ipairs(ids(ns.TrainerFees or {})) do
	local row = ns.TrainerFees[id]
	add({ kind = "trainer_fee", id = id, fee = row[1], req = row[2] })
end

-- trainer_set: the trainers who teach a recipe, expanded from the shared sets
for _, id in ipairs(ids(ns.RecipeTrainerSets or {})) do
	local trainers = {}
	for index, npc in ipairs((ns.TrainerSets or {})[ns.RecipeTrainerSets[id]] or {}) do
		trainers[index] = npc
	end
	add({ kind = "trainer_set", id = id, trainers = trainers })
end

-- trainer_rank: the rank trainings a trainer teaches above Apprentice
for _, id in ipairs(ids(ns.TrainerRanks or {})) do
	local ranks = {}
	for index, row in ipairs(ns.TrainerRanks[id]) do
		ranks[index] = { row[1], row[2], row[3], row[4] }
	end
	add({ kind = "trainer_rank", id = id, ranks = ranks })
end

-- rank_quest: the quests that teach a profession rank
for _, id in ipairs(ids(ns.RankQuests or {})) do
	local quests = {}
	for index, row in ipairs(ns.RankQuests[id]) do
		quests[index] = { cap = row[1], quest = row[2], req = row[3], level = row[4], side = row[5] }
	end
	add({ kind = "rank_quest", id = id, quests = quests })
end

-- rank_book: the books that teach a profession rank
for _, id in ipairs(ids(ns.RankBooks or {})) do
	local books = {}
	for index, row in ipairs(ns.RankBooks[id]) do
		books[index] = { cap = row[1], item = row[2], fee = row[3], req = row[4], level = row[5] }
	end
	add({ kind = "rank_book", id = id, books = books })
end

-- profession_trainers: which trainer teaches which profession, at what cap
for _, id in ipairs(ids(ns.ProfessionTrainers or {})) do
	local trainers = {}
	for index, row in ipairs(ns.ProfessionTrainers[id]) do
		trainers[index] = { npc = row[1], cap = row[2] }
	end
	add({ kind = "profession_trainers", id = id, trainers = trainers })
end

-- recipe_scroll: the pattern or recipe item that teaches a recipe
for _, id in ipairs(ids(ns.RecipeScrolls or {})) do
	local row = ns.RecipeScrolls[id]
	add({ kind = "recipe_scroll", id = id, item = row[1], req = row[2] })
end

-- scroll: a recipe scroll's named drops and world-drop marking
local scrolls = {}
for id in pairs(ns.ScrollDrops or {}) do
	scrolls[id] = true
end
for id in pairs(ns.WorldDrops or {}) do
	scrolls[id] = true
end
for _, id in ipairs(ids(scrolls)) do
	local drops = {}
	for index, drop in ipairs(ns.ScrollDrops[id] or {}) do
		drops[index] = { npc = drop[1], chance = drop[2] }
	end
	if next(drops) == nil then
		drops = nil
	end
	add({ kind = "scroll", id = id, world = ns.WorldDrops[id] == true or nil, drops = drops })
end

-- gather: the gathering skill that yields a reagent
for _, id in ipairs(ids(ns.GatheredBy or {})) do
	add({ kind = "gather", id = id, skill = ns.GatheredBy[id] })
end

-- loot: the reagents creatures carry
for _, id in ipairs(ids(ns.LootedFrom or {})) do
	add({ kind = "loot", id = id })
end

-- vendor_price: what a vendor sells a reagent for
for _, id in ipairs(ids(ns.VendorPrices or {})) do
	add({ kind = "vendor_price", id = id, price = ns.VendorPrices[id] })
end

-- vendor_stock: the vendors whose limited stock an item shares
for _, id in ipairs(ids(ns.LimitedStock or {})) do
	local stock = {}
	for index, npc in ipairs(ids(ns.LimitedStock[id])) do
		stock[index] = { npc = npc, count = ns.LimitedStock[id][npc] }
	end
	add({ kind = "vendor_stock", id = id, stock = stock })
end

-- node: the gathering skill and rank a node asks for, keyed by its enUS name
local nodes = {}
for name in pairs(ns.NodeSkills or {}) do
	nodes[#nodes + 1] = name
end
table.sort(nodes)
for _, name in ipairs(nodes) do
	local row = ns.NodeSkills[name]
	add({ kind = "node", name = name, skill = row[1], req = row[2] })
end

local file = assert(io.open(output, "w"))
for _, line in ipairs(lines) do
	assert(file:write(json(line), "\n"))
end
assert(file:close())

local counts = {}
for _, line in ipairs(lines) do
	counts[line.kind] = (counts[line.kind] or 0) + 1
end
local summary = {}
for _, kind in ipairs({
	"recipe",
	"craft",
	"trainer_fee",
	"trainer_set",
	"trainer_rank",
	"rank_quest",
	"rank_book",
	"profession_trainers",
	"recipe_scroll",
	"scroll",
	"gather",
	"loot",
	"vendor_price",
	"vendor_stock",
	"node",
}) do
	if counts[kind] then
		summary[#summary + 1] = ("%s %d"):format(kind, counts[kind])
	end
end
print(("data_dump: %s -> %s"):format(table.concat(summary, ", "), output))
