-- #840: C_TradeSkillUI.OpenRecipe closes an open Professions window on the Forever client and never reopens it,
-- so no file the client loads may call it. Every SkillUp way to a recipe goes through ns.ShowRecipe instead.
local Client = dofile("tests/client.lua")

local calls = {}
for file in io.lines("SkillUpForever.toc") do
	file = file:gsub("\r", "")
	if file:match("%.lua$") then
		local source = assert(io.open(file:gsub("\\", "/"), "r")):read("*a")
		local line = 0
		for text in (source .. "\n"):gmatch("([^\n]*)\n") do
			line = line + 1
			local code = text:gsub("%-%-.*$", "")
			if code:find("C_TradeSkillUI%.OpenRecipe%f[^%w_]") then
				calls[#calls + 1] = file .. ":" .. line
			end
		end
	end
end
Client.equal(table.concat(calls, ", "), "", "no loaded file calls C_TradeSkillUI.OpenRecipe")
Client.report("open_recipe_spec")
