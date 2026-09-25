---@type string, SkillUpNamespace
local _, ns = ...

-- English phrases are the keys, so a phrase with no translation shows in English.
-- Locales/phrases.txt (tools/phrases.py) lists them for CurseForge's localization import.
local L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
ns.L = L
