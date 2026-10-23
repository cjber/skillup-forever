-- Run from the repository root: luajit tests/trainer_export_spec.lua
-- /su export trainers (#124): the requirements a trainer actually showed this character, as the table literal
-- tools/gen_trainer.py's SEEN_REQUIREMENTS takes. The text a player copies is read back with loadstring: if it is
-- not valid Lua, the export is worthless, so every case here proves the round trip.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local COOKING, SMITHING = 185, 164
local BREAD, HAMMER, STEW = 37836, 9985, 9001

-- The table the exported text defines, loaded the way a player's paste would be.
local function Parse(text)
	local chunk = loadstring(text)
	if not chunk then
		return nil
	end
	local env = {}
	setfenv(chunk, env)
	chunk()
	return env.SEEN_REQUIREMENTS
end

local function Load(trainer)
	local c = Client.load({
		boot = false,
		saved = { trainer = trainer },
		data = {
			Thresholds = {
				[BREAD] = { 1, 30, 35, 38 },
				[STEW] = { 1, 40, 50, 60 },
				[HAMMER] = { 1, 100, 150, 200 },
			},
			RecipeData = {
				[BREAD] = { skillLine = COOKING, reagents = {} },
				[STEW] = { skillLine = COOKING, reagents = {} },
				[HAMMER] = { skillLine = SMITHING, reagents = {} },
			},
			TrainerFees = { [BREAD] = { 30, 25 }, [HAMMER] = { 900, 110 } },
			TrainerRanks = {},
			TrainerInferred = {},
			VendorPrices = {},
			ProfessionSkillLines = { Cooking = COOKING, Blacksmithing = SMITHING },
		},
	})
	c.spells[BREAD] = "Spice Bread"
	c.spells[STEW] = "Mystery Stew"
	c.spells[HAMMER] = "Bronze Warhammer"
	c.professions = { { name = "Cooking", icon = 1, rank = 60, max = 75, id = COOKING } }
	c.Boot()
	return c
end

-- The lines /su export shows, as one string.
local function Export(c)
	local lines = c.ns.TrainerExport()
	return table.concat(lines, "\n"), lines
end

-- Only a requirement a trainer showed is exported: a row that saved the bundled one alone has seen nothing.
do
	local c = Load({
		[COOKING] = { [BREAD] = { 40, 25, 25 }, [STEW] = { 40, 40 } },
		[SMITHING] = { [HAMMER] = { 900, 110, 110 } },
	})
	local text, lines = Export(c)
	equal(lines[1], "SEEN_REQUIREMENTS = {", "the table opens")
	equal(lines[#lines], "}", "and closes")
	local seen = Parse(text)
	equal(seen ~= nil, true, "the export is valid Lua:\n" .. text)
	equal(seen[BREAD], 25, "a requirement a trainer showed is exported")
	equal(seen[HAMMER], 110, "and each profession's")
	equal(seen[STEW], nil, "a row that showed no requirement is left out")
	equal(text:find("-- Spice Bread, Cooking", 1, true) ~= nil, true, "the recipe and its profession are named")
	equal(text:find("-- Bronze Warhammer, Blacksmithing", 1, true) ~= nil, true, "the other profession too")
	equal(#c.errors, 0, "no errors")
end

-- Two skill lines that recorded one recipe: the longest requirement wins, and the table stays one entry.
do
	local c = Load({
		[COOKING] = { [BREAD] = { 40, 25, 25 } },
		[SMITHING] = { [BREAD] = { 40, 25, 60 } },
	})
	local text, lines = Export(c)
	equal(#lines, 3, "one entry, between the braces: " .. text)
	equal(Parse(text)[BREAD], 60, "the longest requirement seen wins")
end

-- Nothing seen yet: a line telling the player what to do, and no window.
do
	local c = Load({})
	equal(#c.ns.TrainerExport(), 0, "nothing seen exports nothing")
	local before = #c.frames
	c.G.SlashCmdList.SKILLUPFOREVER("export trainers")
	equal(#c.frames, before, "no window opens")
	local last = c.chat[#c.chat]
	equal(last:find("no trainer requirement seen yet", 1, true) ~= nil, true, "chat says what to do: " .. last)
end

-- The command shows the table in the copy window, selected, and /su export alone is the same thing.
do
	local c = Load({ [COOKING] = { [BREAD] = { 40, 25, 25 } } })
	c.G.SlashCmdList.SKILLUPFOREVER("export trainers")
	local edit = c.focus
	equal(edit ~= nil, true, "the export opens in the copy window")
	local text = edit and edit:GetText() or ""
	equal(text:find("SEEN_REQUIREMENTS = {", 1, true) ~= nil, true, "holding the table: " .. text)
	equal(edit and edit.highlighted, text, "all of it selected for copying")
	equal(Parse(text)[BREAD], 25, "and it still loads as Lua")
	c.G.SlashCmdList.SKILLUPFOREVER("export")
	equal(c.focus and c.focus:GetText(), text, "/su export is the same export")
	equal(#c.errors, 0, "no errors")
end

-- /su help lists it.
do
	local c = Load({})
	c.G.SlashCmdList.SKILLUPFOREVER("help")
	local listed = false
	for _, message in ipairs(c.chat) do
		listed = listed or message:find("/su export", 1, true) ~= nil
	end
	equal(listed, true, "/su help lists /su export")
end

Client.report("trainer_export_spec")
