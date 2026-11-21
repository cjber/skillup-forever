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

L["Craft next follows the estimated route."] = "Craft next follows the estimated route."

L["Include Working Overtime estimate"] = "Include Working Overtime estimate"
L["Adds an estimated 4 percentage points per Working Overtime rank to yellow and green skill-up chances. Whether the game adds the talent's bonus as points or multiplies the chance by it is not confirmed yet, so this starts off and chances use the base formula."] =
	"Adds an estimated 4 percentage points per Working Overtime rank to yellow and green skill-up chances. Whether the game adds the talent's bonus as points or multiplies the chance by it is not confirmed yet, so this starts off and chances use the base formula."

L["Supply policy"] = "Supply policy"
L["Route-wide starting chance (required, no default)"] = "Route-wide starting chance (required, no default)"
L["Adaptive continuation"] = "Adaptive continuation"
L["Open the profession and a merchant window."] = "Open the profession and a merchant window."
L["Apply policy"] = "Apply policy"
L["Applied. Coverage and cost will update from the explicit policy."] =
	"Applied. Coverage and cost will update from the explicit policy."
L["Unknown: open the profession and a merchant before entering supply laws."] =
	"Unknown: open the profession and a merchant before entering supply laws."
L["Offer %d: item %s, observed stock %s"] = "Offer %d: item %s, observed stock %s"

L["currency %d"] = "currency %d"
L["an unknown payment"] = "an unknown payment"
L["Name the stock each offer draws on, or give this offer its own stock."] =
	"Name the stock each offer draws on, or give this offer its own stock."
L["The merchant shows no limit: limit the search to the number you will buy."] =
	"The merchant shows no limit: limit the search to the number you will buy."
L["The stock you assume does not match what the merchant shows."] =
	"The stock you assume does not match what the merchant shows."
L["Enter a starting chance between 1 and 100."] = "Enter a starting chance between 1 and 100."
L["The merchant sells none of this route's reagents."] = "The merchant sells none of this route's reagents."
L["The merchant's offer for %s is incomplete."] = "The merchant's offer for %s is incomplete."
L["Every offer needs its price to stay as shown."] = "Every offer needs its price to stay as shown."
L["Fill in every value this offer needs."] = "Fill in every value this offer needs."
L["The merchant sells fewer purchases at a time than that."] = "The merchant sells fewer purchases at a time than that."
L["Offers that draw on one stock pool need the same stock."] = "Offers that draw on one stock pool need the same stock."
L["Offers at one vendor need the same trip costs and values."] =
	"Offers at one vendor need the same trip costs and values."
L["Enter the chance each later purchase arrives, from 0 to 100."] =
	"Enter the chance each later purchase arrives, from 0 to 100."
L["Check that the first purchase arrives for certain at every offer."] =
	"Check that the first purchase arrives for certain at every offer."
L["One item or payment needs one leftover value."] = "One item or payment needs one leftover value."
L["Offers that use one payment need the same value for it."] = "Offers that use one payment need the same value for it."
L["The merchant changed. Check the form again."] = "The merchant changed. Check the form again."
L["The merchant did not change, but the assumptions did. Check the form again."] =
	"The merchant did not change, but the assumptions did. Check the form again."
L["The merchant shows this offer sold out."] = "The merchant shows this offer sold out."
L["The merchant does not say how much is left."] = "The merchant does not say how much is left."
L["The merchant will not sell this offer to you now."] = "The merchant will not sell this offer to you now."
L["Choose the unit the stock count is in."] = "Choose the unit the stock count is in."
L["The assumptions were rejected. Fill in every value and check each offer."] =
	"The assumptions were rejected. Fill in every value and check each offer."
L["Open a profession to see its plan and coverage."] = "Open a profession to see its plan and coverage."
L["Plan: %s, %s to %s, %d crafts."] = "Plan: %s, %s to %s, %d crafts."
L["Unpriced crafts: %d."] = "Unpriced crafts: %d."
L["Your target chance: %s%%."] = "Your target chance: %s%%."
L["Margin over your target: %s points."] = "Margin over your target: %s points."
L["Below your target by %s points."] = "Below your target by %s points."
L["craft"] = "craft"
L["buy"] = "buy"
L["stop"] = "stop"
L["Next step: %s."] = "Next step: %s."
L["Open a profession to set its supply policy."] = "Open a profession to set its supply policy."
L["This profession has no plan to supply yet."] = "This profession has no plan to supply yet."
L["Open a merchant to set this profession's supply policy."] = "Open a merchant to set this profession's supply policy."
L["Ready to apply these assumptions."] = "Ready to apply these assumptions."
L["no limit"] = "no limit"
L["Offer %d: %s"] = "Offer %d: %s"
L["The merchant shows %s in stock, %s per purchase, at most %s purchases."] =
	"The merchant shows %s in stock, %s per purchase, at most %s purchases."
L["Price: %s."] = "Price: %s."
L["Also costs %s %s."] = "Also costs %s %s."
L["I can buy this offer"] = "I can buy this offer"
L["The price stays as shown"] = "The price stays as shown"
L["Stock I assume is left"] = "Stock I assume is left"
L["The stock does not run out"] = "The stock does not run out"
L["The stock count is in items, not purchases"] = "The stock count is in items, not purchases"
L["This offer keeps its own stock"] = "This offer keeps its own stock"
L["Limit the search to the stock I typed"] = "Limit the search to the stock I typed"
L["Stock pool name"] = "Stock pool name"
L["Purchases allowed per visit"] = "Purchases allowed per visit"
L["First trip cost (copper)"] = "First trip cost (copper)"
L["Later trip cost (copper)"] = "Later trip cost (copper)"
L["First trip value to you (copper)"] = "First trip value to you (copper)"
L["Later trip value to you (copper)"] = "Later trip value to you (copper)"
L["Chance each later purchase arrives (%)"] = "Chance each later purchase arrives (%)"
L["The first purchase arrives for certain"] = "The first purchase arrives for certain"
L["I pay even when a purchase does not arrive"] = "I pay even when a purchase does not arrive"
L["Leftover value of one %s (copper)"] = "Leftover value of one %s (copper)"
L["Value of one %s (copper)"] = "Value of one %s (copper)"
L["These are your own assumptions. The merchant's window only shows what it shows now."] =
	"These are your own assumptions. The merchant's window only shows what it shows now."
L["Chance of finishing with starting supplies (%)"] = "Chance of finishing with starting supplies (%)"
L["Plan later purchases too"] = "Plan later purchases too"
L["Cost of an unfinished route (copper)"] = "Cost of an unfinished route (copper)"
L["Applied. The plan and its coverage follow these assumptions."] =
	"Applied. The plan and its coverage follow these assumptions."
L["%s, uses materials you have"] = "%s, uses materials you have"
L["Supply"] = "Supply"
L["No trainer of your faction teaches this recipe."] = "No trainer of your faction teaches this recipe."
L["%s (level %d)"] = "%s (level %d)"

L["Clicking a recipe selects it again under every sort."] = "Clicking a recipe selects it again under every sort."

L["Forever Ledger prices reagents."] = "Forever Ledger prices reagents."
L["Show reagent search"] = "Show reagent search"
L["Click Search in the Professions window to find missing reagents. Without Auctionator, each click fills the auction house search box with the next reagent."] =
	"Click Search in the Professions window to find missing reagents. Without Auctionator, each click fills the auction house search box with the next reagent."
L["Keep Auctionator shopping lists"] = "Keep Auctionator shopping lists"
L["Save lists for tracked routes set to Buy reagents and for recipe searches. Turn this off to stop saving lists and keep using Search."] =
	"Save lists for tracked routes set to Buy reagents and for recipe searches. Turn this off to stop saving lists and keep using Search."
