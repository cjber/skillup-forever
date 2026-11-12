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
L["This route is mostly %s: %d recipes are left out until their reagents are priced."] =
	"This route is mostly %s: %d recipes are left out until their reagents are priced."
L["Price self-supplied reagents at auction values"] = "Price self-supplied reagents at auction values"
L["A reagent you gather, loot or already own costs what selling it would bring - its auction price after the 5% cut, or its vendor sell price if that is more - instead of counting as free. With no market price it stays unpriced rather than free. Auction prices need Auctionator or TradeSkillMaster."] =
	"A reagent you gather, loot or already own costs what selling it would bring - its auction price after the 5% cut, or its vendor sell price if that is more - instead of counting as free. With no market price it stays unpriced rather than free. Auction prices need Auctionator or TradeSkillMaster."
L["Tooltips stay cheap while the pointer rests on an item."] = "Tooltips stay cheap while the pointer rests on an item."
L["%s: %s"] = "%s: %s"
L["%s drops in %s"] = "%s drops in %s"
L["Made by %s %d"] = "Made by %s %d"
L["Made by %s"] = "Made by %s"
L["SkillUp"] = "SkillUp"
L["Route"] = "Route"
L["Buffs"] = "Buffs"
L["spell %d"] = "spell %d"
L["%s at %d"] = "%s at %d"
L["Only for level %d"] = "Only for level %d"
L["No buff items for your level yet."] = "No buff items for your level yet."
L["This profession makes no buff items."] = "This profession makes no buff items."
L["Known"] = "Known"
L["Learn now"] = "Learn now"
L["Later"] = "Later"
L["Above your level"] = "Above your level"
L["A tab at the bottom of the Professions window with a route to your target skill and its reagents. It opens from the SkillUp side tab, beside the crafted gear and buffs tabs. Tracked professions stay in the objective tracker either way."] =
	"A tab at the bottom of the Professions window with a route to your target skill and its reagents. It opens from the SkillUp side tab, beside the crafted gear and buffs tabs. Tracked professions stay in the objective tracker either way."
L["A tab at the bottom of the Professions window listing the newest crafted item this character can equip in each slot. It opens from the SkillUp side tab, beside the route and buffs tabs."] =
	"A tab at the bottom of the Professions window listing the newest crafted item this character can equip in each slot. It opens from the SkillUp side tab, beside the route and buffs tabs."
L["A tab at the bottom of the Professions window listing the buff consumables this profession makes, by the skill they unlock at and what each one is for. It opens from the SkillUp side tab, beside the route and crafted gear tabs."] =
	"A tab at the bottom of the Professions window listing the buff consumables this profession makes, by the skill they unlock at and what each one is for. It opens from the SkillUp side tab, beside the route and crafted gear tabs."
L["Buffs by %s skill"] = "Buffs by %s skill"
L["Skill  %d/%d"] = "Skill  %d/%d"
L["Other crafters"] = "Other crafters"
L["No profession here makes buff items."] = "No profession here makes buff items."
L["Nothing is tracked for %s."] = "Nothing is tracked for %s."
L["+%d more to train"] = "+%d more to train"
L["Also train"] = "Also train"
