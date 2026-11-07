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
L["SkillUp's recipe board joins the shared Forever Leaderboards window."] =
	"SkillUp's recipe board joins the shared Forever Leaderboards window."
L["The recipe list fits long recipe names, and says how many you can make beside them."] =
	"The recipe list fits long recipe names, and says how many you can make beside them."
L["The recipe list grows to the longest recipe name in the open profession, and the window with it, up to the room your screen has. Turn it off to keep the window's own width."] =
	"The recipe list grows to the longest recipe name in the open profession, and the window with it, up to the room your screen has. Turn it off to keep the window's own width."
L["Widen the recipe list to fit recipe names"] = "Widen the recipe list to fit recipe names"
