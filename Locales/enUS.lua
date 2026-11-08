---@type string, SkillUpNamespace
local _, ns = ...

-- English phrases are the keys, so a phrase with no translation shows in English. A translation is
-- Locales/<locale>.lua after this file in the TOC; Locales/phrases.txt is its template.
local L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
ns.L = L
L["The recipe list grows to the longest recipe name in the open profession, and the window with it, up to the room your screen has. Turn it off to keep the window's own width."] =
	"The recipe list grows to the longest recipe name in the open profession, and the window with it, up to the room your screen has. Turn it off to keep the window's own width."
L["Widen the recipe list to fit recipe names"] = "Widen the recipe list to fit recipe names"
L["This route is mostly %s: %d recipes are left out until their reagents are priced."] =
	"This route is mostly %s: %d recipes are left out until their reagents are priced."
