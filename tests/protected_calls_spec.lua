-- Run from the repository root: luajit tests/protected_calls_spec.lua
-- A source guard: no shipped addon file may call a client function that is protected. The client refuses a
-- protected call from addon code, and the taint can block the player's own actions afterwards (#327).
local Client = dofile("tests/client.lua")
local equal = Client.equal

local function Read(path)
	local file = assert(io.open(path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
end

-- The TOC is the addon's own list of files: scan the shipped Core, UI and Integrations sources, never the
-- generated Data or the translations.
local function AddonFiles()
	local files = {}
	for line in Read("SkillUpForever.toc"):gmatch("[^\r\n]+") do
		local path = line:gsub("\\", "/")
		if path:match("^Core/.*%.lua$") or path:match("^UI/.*%.lua$") or path:match("^Integrations/.*%.lua$") then
			files[#files + 1] = path
		end
	end
	return files
end

-- A comment is not a call: drop "--" to the end of each line before matching. A "--" inside a string would
-- hide the rest of that line, which is safe here: this guard refuses only what it can see.
local function Code(text)
	return text:gsub("%-%-[^\n]*", "")
end

-- BuyMerchantItem is deliberately absent: this client does not protect it, so the merchant buy button stays.
local FORBIDDEN = {
	{ "%f[%a]Pickup%w*%s*%(", "protected pickup" },
	{ "C_TradeSkillUI%.Craft%w*%s*%(", "protected craft" },
	{ "%f[%a]Use%u%w*%s*%(", "protected item use" },
	{ "C_Container%.%w*Use%w*%s*%(", "protected container use" },
	{ "%f[%a]Cast%u%w*%s*%(", "protected spell cast" },
	{ "%f[%a]RunMacro%w*%s*%(", "protected macro run" },
	{ "SetAttribute%s*%(%s*[^)]*[Mm]acro", "macro attribute" },
}

local checked, violations = 0, {}
for _, path in ipairs(AddonFiles()) do
	checked = checked + 1
	local code = Code(Read(path))
	local line = 0
	for text in (code .. "\n"):gmatch("([^\n]*)\n") do
		line = line + 1
		for _, rule in ipairs(FORBIDDEN) do
			if text:find(rule[1]) then
				violations[#violations + 1] = string.format("%s:%d: %s", path, line, rule[2])
			end
		end
	end
end

equal(checked >= 20, true, "the guard reads the shipped Core, UI and Integrations files")
equal(table.concat(violations, "\n"), "", "no addon file calls a protected client function")
Client.report("protected_calls_spec")
