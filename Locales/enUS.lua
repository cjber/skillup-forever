---@type string, SkillUpNamespace
local _, ns = ...

-- English phrases are the keys, so a phrase with no translation shows in English. A translation is
-- Locales/<locale>.lua after this file in the TOC; Locales/phrases.txt is its template.
local L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
L["Unlearned recipe order"] = "Unlearned recipe order"
L["How recipes you have not learned are ordered. Learned recipes keep the selected recipe order."] =
	"How recipes you have not learned are ordered. Learned recipes keep the selected recipe order."
ns.L = L
L["This route is mostly %s: %d recipes are left out until their costs or sale values are known."] =
	"This route is mostly %s: %d recipes are left out until their costs or sale values are known."
L["Price self-supplied reagents at auction values"] = "Price self-supplied reagents at auction values"
L["A reagent you gather, loot or already own costs what selling it would bring - its auction price after the 5% cut, or its vendor sell price if that is more - instead of counting as free. With no market price it stays unpriced rather than free. Auction prices need Auctionator, TradeSkillMaster, AHDB, Naowh Forever or Forever Ledger."] =
	"A reagent you gather, loot or already own costs what selling it would bring - its auction price after the 5% cut, or its vendor sell price if that is more - instead of counting as free. With no market price it stays unpriced rather than free. Auction prices need Auctionator, TradeSkillMaster, AHDB, Naowh Forever or Forever Ledger."
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
L["Counts include spares for an estimated %d%% chance to finish the whole route."] =
	"Counts include spares for an estimated %d%% chance to finish the whole route."
L["Restock visit cost"] = "Restock visit cost"
L["Not counted"] = "Not counted"
L["What one trip to buy more reagents is worth, in copper, when a run takes more crafts than planned. It is added to that reagent's purchase price only when it happens. Leave it at zero to count no trip."] =
	"What one trip to buy more reagents is worth, in copper, when a run takes more crafts than planned. It is added to that reagent's purchase price only when it happens. Leave it at zero to count no trip."
L["Region sale average"] = "Region sale average"
L["Region sale average if higher"] = "Region sale average if higher"
L["Region sale averages need TradeSkillMaster and its desktop app. They estimate value from reported regional sales and purchases, with the vendor price as a floor. They do not guarantee a sale."] =
	"Region sale averages need TradeSkillMaster and its desktop app. They estimate value from reported regional sales and purchases, with the vendor price as a floor. They do not guarantee a sale."

L["Route incomplete: %d recipes left out because their costs or sale values are unknown."] =
	"Route incomplete: %d recipes left out because their costs or sale values are unknown."

L["Open %s from your spellbook."] = "Open %s from your spellbook."

L["Recipes on Shift"] = "Recipes on Shift"
L["Show recipes on Shift or always. Off hides reagent details, including route needs."] =
	"Show recipes on Shift or always. Off hides reagent details, including route needs."
L["Show route needs on item tooltips"] = "Show route needs on item tooltips"
L["Show how much of an item your tracked routes still need. Turn this off to keep recipe details without the route line."] =
	"Show how much of an item your tracked routes still need. Turn this off to keep recipe details without the route line."

L["Craft counts and shopping quantities are estimates. You may need more reagents."] =
	"Craft counts and shopping quantities are estimates. You may need more reagents."

L["Supply estimate: calculating."] = "Supply estimate: calculating."

L["Supply estimate: not enough information."] = "Supply estimate: not enough information."

L["Supply estimate: no starting purchase meets the target."] = "Supply estimate: no starting purchase meets the target."

L["Supply estimate: cancelled."] = "Supply estimate: cancelled."

L["Supply estimate: ready."] = "Supply estimate: ready."

L["Supply estimate: no cheapest purchase exists under these assumptions."] =
	"Supply estimate: no cheapest purchase exists under these assumptions."

L["Target chance of finishing with starting supplies: %s%%."] =
	"Target chance of finishing with starting supplies: %s%%."

L["unknown"] = "unknown"

L["%s%% to %s%%"] = "%s%% to %s%%"

L["Chance of finishing with starting supplies: %s."] = "Chance of finishing with starting supplies: %s."

L["Chance of finishing with later purchases: %s."] = "Chance of finishing with later purchases: %s."

L["Starting inventory: bags only."] = "Starting inventory: bags only."

L["Starting inventory: bags and bank."] = "Starting inventory: bags and bank."

L["These chances assume the stated skill-up rates, prices, availability and delivery of later purchases."] =
	"These chances assume the stated skill-up rates, prices, availability and delivery of later purchases."

L["Include Working Overtime estimate"] = "Include Working Overtime estimate"
L["Adds an estimated 4 percentage points per Working Overtime rank to yellow and green skill-up chances. Whether the game adds the talent's bonus as points or multiplies the chance by it is not confirmed yet, so this starts off and chances use the base formula."] =
	"Adds an estimated 4 percentage points per Working Overtime rank to yellow and green skill-up chances. Whether the game adds the talent's bonus as points or multiplies the chance by it is not confirmed yet, so this starts off and chances use the base formula."

L["Route-wide starting chance (required, no default)"] = "Route-wide starting chance (required, no default)"
L["Adaptive continuation"] = "Adaptive continuation"
L["Applied. Coverage and cost will update from the explicit policy."] =
	"Applied. Coverage and cost will update from the explicit policy."
L["Unknown: open the profession and a merchant before entering supply laws."] =
	"Unknown: open the profession and a merchant before entering supply laws."
L["Offer %d: item %s, observed stock %s"] = "Offer %d: item %s, observed stock %s"

L["%s, uses materials you have"] = "%s, uses materials you have"
L["No trainer of your faction teaches this recipe."] = "No trainer of your faction teaches this recipe."
L["%s (level %d)"] = "%s (level %d)"

L["Clicking a recipe selects it again under every sort."] = "Clicking a recipe selects it again under every sort."

L["A lighter Route page."] = "A lighter Route page."
L["Show reagent search"] = "Show reagent search"
L["Click Search in the Professions window to find missing reagents. Without Auctionator, each click fills the auction house search box with the next reagent."] =
	"Click Search in the Professions window to find missing reagents. Without Auctionator, each click fills the auction house search box with the next reagent."
L["Keep Auctionator shopping lists"] = "Keep Auctionator shopping lists"
L["Save lists for tracked routes set to Buy reagents and for recipe searches. Turn this off to stop saving lists and keep using Search."] =
	"Save lists for tracked routes set to Buy reagents and for recipe searches. Turn this off to stop saving lists and keep using Search."
