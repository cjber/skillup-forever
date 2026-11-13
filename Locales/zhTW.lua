-- Machine translated (2026-10-16); corrections welcome: https://github.com/cjber/skillup-forever/issues/new?template=translation.yml
local _, ns = ...
if GetLocale() ~= "zhTW" then
	return
end
local L = ns.L

L["%d %s"] = "%d %s"
L["%d crafts to %d, %s"] = "製造%d次至%d，%s"
L["%d crafts to %d, %s, at %s"] = "製造%d次至%d，%s，地點：%s"
L["%d more"] = "還有%d個"
L["%d of %d"] = "%d/%d"
L["%d reagents have no price"] = "%d 種材料沒有價格"
L["%d to %d"] = "%d至%d"
L["%d, from %d to %d"] = "%d次，從%d到%d"
L["%dd ago"] = "%d天前"
L["%s %d"] = "%s %d"
L["%s (%d): bundled %d, classic-db %d"] = "%s（%d）：內建%d，classic-db %d"
L["%s (%d): bundled %s, the trainer wants %d"] = "%s（%d）：內建%s，訓練師要求%d"
L["%s (unlearned)"] = "%s（未學）"
L["%s is at %s."] = "%s位於%s。"
L["%s is in %s."] = "%s在%s。"
L["%s trainer"] = "%s訓練師"
L["%s until %d"] = "%s直到%d"
L["%s, %d"] = "%s，%d"
L["%s, %s, to %d"] = "%s，%s，至%d"
L["%s, source unknown"] = "%s，來源不明"
L["%s: %d moved, %d confirmed at a trainer, %d wrong."] =
	"%s：移動%d個，在訓練師處確認%d個，錯誤%d個。"
L["+%d more"] = "另有%d個"
L["/skillup skipped lists the recipes you skipped, with their IDs."] =
	"/skillup skipped 列出你跳過的配方及其ID。"
L["/skillup unskip <recipe ID> shows one again, /skillup unskip all every one."] =
	"/skillup unskip <recipe ID> 恢復顯示一個，/skillup unskip all 恢復全部。"
L["A Reagents tab on a merchant's window that lists the reagents your tracked routes still need from that merchant and their total cost. Buy them from the merchant's own window."] =
	"在商人視窗顯示材料分頁，列出你追蹤的路線仍需要向該商人購買的材料及其總費用。請在商人視窗中購買。"
L["A material your professions gather costs what selling it would bring instead of nothing: its auction price after the 5% cut, or its vendor sell price if that is more. Used for the route and the costs on recipe rows. Auction prices need Auctionator or TradeSkillMaster."] =
	"你的專業技能採集的材料按出售所得計價，而不是免費：扣除5%手續費後的拍賣價，或較高時按商人收購價。用於路線和配方列的成本。拍賣價需要Auctionator/TradeSkillMaster。"
L["Keeps the shared Forever tracker where you put it. The grip at its top no longer drags it."] =
	"將共用的 Forever 追蹤器保持在您放置的位置。頂部的拖曳握把不再移動它。"
L["Lock the tracker"] = "鎖定追蹤器"

L["AH"] = "拍賣場"
L["Add the start of each recipe's difficulty range. This is separate from the skill needed to learn it."] =
	"顯示每個配方難度區間的起點。這與學習它所需的技能不同。"
L["Addon"] = "插件"
L["Adventure Guide Forever can plan this quest chain."] = "Adventure Guide Forever可以規劃這條任務鏈。"
L["Also for this slot"] = "此部位的其他物品"
L["Annotate trainer recipes"] = "標註訓練師配方"
L["Another craft makes this recipe, not yours."] = "此配方由其他專業技能製造，而不是你的。"
L["Another crafter"] = "其他製造者"
L["At the %d cap: no trainer teaches the next rank."] = "已達上限%d：沒有訓練師教授下一等級。"
L["At the cursor"] = "滑鼠位置"
L["AtlasLoot is installed but not running: enable it in the AddOns list, or update it if out of date."] =
	"AtlasLoot已安裝但未執行：請在插件列表中啟用，或在過期時更新。"
L["Attach to quest tracker"] = "附著到任務追蹤器"
L["Auction house"] = "拍賣場"
L["Auction price if higher"] = "拍賣價（若較高）"
L["Auctionator hasn't seen these reagents yet: scan the auction house with it to price them."] =
	"Auctionator尚未見過這些材料：請用它掃描拍賣場以取得價格。"
L["Auctionator's scan when the auction house opens is off: turn it on in Auctionator, Basic Options."] =
	"Auctionator在開啟拍賣場時的掃描已關閉：請在Auctionator的「Basic Options」中開啟。"
L["Auctionator, %s"] = "Auctionator，%s"
L["Back"] = "背部"
L["Beside the Professions window"] = "專業技能視窗旁邊"
L["Buy %d %s"] = "購買%d個%s"
L["Buy %s"] = "購買%s" -- mt
L["Buy %s at %d"] = "在%2$d購買%1$s" -- mt
L["Buy all"] = "全部購買"
L["Buy and read %s at %d"] = "購買並閱讀%s（技能%d）"
L["Buy and read %s at %d (level %d)"] = "購買並閱讀%s（技能%d，等級%d）"
L["Buy reagents"] = "購買材料"
L["Buy reagents at the auction house"] = "在拍賣場購買材料"
L["Can learn it"] = "可以學習"
L["Cheapest skill-up"] = "最便宜的技能提升"
L["Chest"] = "胸部"
L["Click for a waypoint to %s."] = "點擊設定前往%s的導航點。"
L["Click for a waypoint."] = "點擊設定導航點。"
L["Click to craft %d."] = "點擊製造%d個。"
L["Click to open the recipe."] = "點擊開啟配方。"
L["Click to show a recipe again."] = "點擊恢復顯示一個配方。"
L["Close"] = "關閉"
L["Complete %s at %d"] = "完成%s（技能%d）"
L["Complete %s at %d (level %d)"] = "完成%s（技能%d，等級%d）"
L["Complete %s first: you're at your cap."] = "請先完成%s：你已達上限。"
L["Cost"] = "成本"
L["Count what crafts sell for"] = "計入製造品的售價"
L["Craft %d %s"] = "製造%d個%s"
L["Craft %d of %d× %s"] = "製造%d/%d× %s"
L["Craft %d× %s"] = "製造%d× %s"
L["Craft %s"] = "製造%s"
L["Craft"] = "製造"
L["Craft next"] = "製造下一個"
L["Crafted gear"] = "製造裝備"
L["Crafts"] = "製造次數"
L["Don't count it"] = "不計入"
L["Dropped by"] = "掉落自"
L["Each"] = "單價"
L["Enable Shortest Path Forever for walked routes and boat times."] =
	"啟用Shortest Path Forever以取得步行路線和船隻時刻。"
L["Every recipe that uses it"] = "所有使用它的配方"
L["Fee"] = "費用"
L["Fees"] = "費用"
L["Feet"] = "腳"
L["Finger"] = "手指"
L["First used at"] = "首次使用於"
L["Forever addons"] = "Forever插件"
L["Gather %d %s"] = "採集%d個%s"
L["Gathering skill on nodes"] = "採集點的採集技能"
L["Hands"] = "手"
L["Have (bags and bank)"] = "已有（背包和銀行）"
L["Head"] = "頭部"
L["Herb and ore node tooltips show the skill they need and its colour at yours (English client only). Skinnable corpses show ? until the skinning rule is confirmed on Forever."] =
	"草藥和礦脈的滑鼠提示會顯示所需技能及其相對你技能的顏色（僅限英文用戶端）。可剝皮的屍體在Forever上的剝皮規則確認前顯示?。"
L["Install AtlasLoot to see the recipes vendors, quests and drops would add."] =
	"安裝AtlasLoot以查看商人、任務和掉落可提供的配方。"
L["Install QuestieDB and AtlasLoot to see where recipes, vendors and trainers are."] =
	"安裝QuestieDB和AtlasLoot以查看配方、商人和訓練師的位置。"
L["Install QuestieDB to see vendors, quests and trainers, with waypoints to them."] =
	"安裝QuestieDB以查看商人、任務和訓練師，並可設定導航點。"
L["Its trainer should teach these at your skill now:"] = "以你現在的技能，訓練師應該能教你這些："
L["Kept in the Auctionator list '%s'."] = "已儲存在Auctionator列表「%s」中。"
L["Latest Auctionator prices."] = "最新的Auctionator價格。"
L["Latest Auctionator prices: rescan to update old prices."] =
	"最新的Auctionator價格：重新掃描以更新舊價格。"
L["Learn a crafting profession to plan a route."] = "學習一個製造專業技能來規劃路線。"
L["Legs"] = "腿部"
L["Level %d"] = "等級%d"
L["Level %d %s"] = "等級%d %s"
L["Made at"] = "製造地點"
L["Main hand"] = "主手"
L["Missing reagents for this step."] = "此步驟缺少材料。"
L["Money on recipe rows"] = "配方列中的金額"
L["Nearest trainer"] = "最近的訓練師"
L["Nearest vendor"] = "最近的商人"
L["Neck"] = "頸部"
L["Need %d more %s"] = "還需要%d個%s"
L["Need a %s in your bags."] = "背包中需要%s。"
L["Needs %s %d"] = "需要%s %d"
L["Needs %s, sells back %s"] = "需要 %s，賣出返還 %s"
L["Needs %s, sells back %s (incomplete)"] = "需要 %s，賣出返還 %s（不完整）"
L["Net per craft"] = "每次製造淨成本"
L["Newest recipes first"] = "最新配方優先"
L["Next to the recipe"] = "配方旁邊"
L["No crafted gear for your level and class yet."] = "暫無適合你等級和職業的製造裝備。"
L["No crafted gear you can make yet. Tick the box above to see gear you cannot make."] =
	"暫無你能製造的裝備。勾選上方的選項以查看你不能製造的裝備。"
L["No skill data for this recipe yet."] = "此配方暫無技能資料。"
L["No trainer teaches this rank: a book does."] = "沒有訓練師教授此等級：需要書籍。"
L["No trainer teaches this rank: a quest does."] = "沒有訓練師教授此等級：需要任務。"
L["Not in this route: you chose Not this recipe."] = "不在此路線中：你選擇了「不要此配方」。"
L["Not this recipe"] = "不要此配方"
L["Nothing priced you know skills up past %d."] = "你已知且有價格的配方都無法將技能提升到%d以上。"
L["Nothing to buy for this route."] = "此路線無需購買任何物品。"
L["Nothing to craft on this route."] = "此路線無需製造任何物品。"
L["Nothing you know skills up past %d."] = "你已知的配方都無法將技能提升到%d以上。"
L["Off hand"] = "副手"
L["On %s"] = "在%s"
L["One line in chat the first time a new version loads."] = "新版本首次載入時在聊天框顯示一行。"
L["Open"] = "開啟"
L["Open %s to craft from here."] = "開啟%s以便在此製造。"
L["Open recipe"] = "開啟配方"
L["Orange, yellow, green and grey thresholds when hovering a recipe."] =
	"滑鼠停在配方上時顯示橙、黃、綠、灰的分界點。"
L["Per craft"] = "每次製作"
L["Per skill-up"] = "每點技能"
L["Per skill-up is the cost of one skill point. Per craft is what one craft costs or earns, shown on recipes that no longer give skill too."] =
	"每點技能是提升一點技能的成本。每次製作是一次製作的成本或收益，不再提升技能的配方也會顯示。"
L["Price"] = "價格"
L["Prices"] = "價格"
L["Profession reagents"] = "專業技能材料"
L["Profit per craft"] = "每次製造利潤"
L["Profit per skill-up"] = "每點技能利潤"
L["Quest"] = "任務"
L["Quest giver"] = "任務給予者"
L["Raises your skill cap to %d."] = "將你的技能上限提高到%d。"
L["Ranged"] = "遠程"
L["Read %s at %d"] = "閱讀%s（技能%d）"
L["Read %s at %d (level %d)"] = "閱讀%s（技能%d，等級%d）"
L["Read %s first: you're at your cap."] = "請先閱讀%s：你已達上限。"
L["Reagent cost divided by skill-up chance, on recipe rows and in the tooltip. Common vendor reagents are priced from the start and updated at merchants you visit, reagents you gather are free unless you value them under Prices, and auction prices need Auctionator or TradeSkillMaster."] =
	"材料成本除以技能提升機率，顯示在配方列和滑鼠提示中。常見商人材料一開始就有價格，並在你造訪商人時更新；你採集的材料免費，除非你在「價格」中為其定價；拍賣價需要Auctionator/TradeSkillMaster。"
L["Reagent tooltips"] = "材料滑鼠提示"
L["Reagents"] = "材料"
L["Reagents  (have / need)"] = "材料  （已有 / 需要）"
L["Reagents for"] = "材料用於"
L["Reagents in hand"] = "材料已備齊"
L["Reagents still needed"] = "仍需的材料"
L["Recipe rows"] = "配方列"
L["Recipe tooltip position"] = "配方提示位置"
L["Recipes from vendors, quests and drops that would carry it on:"] =
	"可以繼續提升的商人、任務和掉落配方："
L["Required skill, skill-up chance and cost on profession trainer recipes, and which one is best to train next for your route."] =
	"在專業技能訓練師的配方上顯示所需技能、技能提升機率和成本，並指出你的路線下一步最適合學習哪個。"
L["Requires"] = "需要"
L["Replan"] = "重新規劃"
L["Route"] = "路線"
L["Route and trainer"] = "路線和訓練師"
L["Route incomplete: %d recipes left out, their reagents not priced yet."] =
	"路線不完整：遺漏了%d個配方，其材料尚無價格。"
L["Route needs"] = "路線需要"
L["Route: %d/%d · %s to %d"] = "路線：%d/%d · %s至%d"
L["Sales"] = "出售"
L["Scales the shared Forever tracker. 100% matches the game's own tracker."] =
	"調整共用Forever追蹤器的大小。100%與遊戲本身的追蹤器一致。"
L["Scan the auction house with Auctionator, or visit a vendor, to price reagents."] =
	"用Auctionator掃描拍賣場或造訪商人來取得材料價格。"
L["Scroll"] = "配方"
L["Search"] = "搜尋"
L["Search reagents at the auction house"] = "在拍賣場搜尋材料"
L["Sells for"] = "售價"
L["Sells for x%g"] = "售價 x%g"
L["Set waypoint"] = "設定導航點"
L["Shift-click to link the scroll."] = "Shift-點擊以連結配方。"
L["Shift: used in %d of your recipes"] = "Shift：用於你的%d個配方"
L["Shoulder"] = "肩部"
L["Show again: %s"] = "恢復顯示：%s"
L["Show cost per skill-up"] = "顯示每點技能成本"
L["Show gear I cannot make yet"] = "顯示我還不能製造的裝備"
L["Show profession routes in the objective tracker. Hiding them keeps your tracked professions and targets."] =
	"在目標追蹤器中顯示專業技能路線。隱藏時會保留你追蹤的專業技能和目標。"
L["Show skill on recipe rows"] = "在配方列顯示技能"
L["Show skill range start on rows"] = "在列上顯示區間起點"
L["Show the merchant Reagents tab"] = "顯示商人材料分頁"
L["Show the crafted gear tab"] = "顯示製造裝備標籤頁"
L["Show the levelling route tab"] = "顯示升級路線標籤頁"
L["Show thresholds tooltip"] = "顯示分界點提示"
L["Show tracked professions"] = "顯示追蹤的專業技能"
L["Skill  %d/%d     Target"] = "技能  %d/%d     目標"
L["Skill points a craft"] = "每次製造技能點"
L["Skill range start"] = "區間起點"
L["Skill range starts at %d"] = "區間起點為%d"
L["Skill-up chance"] = "技能提升機率"
L["Skill-up chance and cost per skill-up at the right of each recipe."] =
	"在每個配方右側顯示技能提升機率和每點技能成本。"
L["Skill-up chance: %d%%"] = "技能提升機率：%d%%"
L["SkillUp report"] = "SkillUp報告"
L["Skipped (%d)"] = "已跳過（%d）"
L["Skipped (%d):"] = "已跳過（%d）："
L["Sold by"] = "出售者"
L["Sort by"] = "分類方式為"
L["Sort recipes"] = "配方排序"
L["Sort recipes in one list, learned first, then unlearned. Default restores categories."] =
	"將配方排成一個列表，已知的在前，未學的在後。「預設值」恢復分類。"
L["Source"] = "來源"
L["Source unknown"] = "來源不明"
L["Stop tracking"] = "停止追蹤"
L["Subtract what the crafted item sells for from its cost. Auction prices need Auctionator or TradeSkillMaster, are after the 5% cut, and may not sell."] =
	"從成本中減去製造物品的售價。拍賣價需要Auctionator/TradeSkillMaster，已扣除5%手續費，且不一定能賣出。"
L["Taught by %s trainers."] = "由%s訓練師教授。"
L["The place this recipe is taught isn't known yet."] = "尚不清楚在哪裡學習此配方。"
L["The rest comes from a vendor or your gathering."] = "其餘來自商人或你的採集。"
L["The route asks for %d to reach %d in 9 runs of 10; a worse run needs more."] =
	"路線按%d個計算，十次中有九次能達到%d；運氣差時需要更多。"
L["The source of this recipe isn't known."] = "此配方的來源不明。"
L["These reagents have no vendor price. Auction prices need Auctionator or TradeSkillMaster."] =
	"這些材料沒有商人價格。拍賣價需要Auctionator/TradeSkillMaster。"
L["To buy"] = "待購買"
L["Tool"] = "工具"
L["Tooltips and sorting"] = "滑鼠提示和排序"
L["Track"] = "追蹤"
L["Tracked routes (Shift for all)"] = "追蹤的路線（Shift顯示全部）"
L["Tracker scale"] = "追蹤器大小"
L["Train %s"] = "學習%s"
L["Train %s at %d"] = "學習%s（技能%d）"
L["Train %s at %d (level %d)"] = "學習%s（技能%d，等級%d）"
L["Train %s first."] = "請先學習%s。"
L["Train %s first: you're at your cap."] = "請先學習%s：你已達上限。"
L["Trinket"] = "飾品"
L["Turn this off to drag the shared Forever tracker anywhere on screen."] =
	"關閉此項後可將共用的Forever追蹤器拖曳到螢幕任意位置。"
L["Update QuestieDB to see vendors, quests and trainers, with waypoints to them."] =
	"更新QuestieDB以查看商人、任務和訓練師，並可設定導航點。"
L["Used in"] = "用於"
L["Value gathered materials at what they'd sell for"] = "按售價計算採集的材料"
L["Vendor"] = "商人"
L["Vendor reagents"] = "商人材料"
L["Vendor sell price"] = "商人收購價"
L["Visit a vendor to price reagents. Auction prices need Auctionator or TradeSkillMaster."] =
	"造訪商人以取得材料價格。拍賣價需要Auctionator/TradeSkillMaster。"
L["Waist"] = "腰部"
L["Waypoint to a trainer"] = "前往訓練師的導航點"
L["Waypoint to a vendor: %s"] = "前往商人的導航點：%s"
L["Waypoint to the quest giver: %s"] = "前往任務給予者的導航點：%s"
L["What hovering an item says about your professions: how much of it your tracked routes need (hold Shift for every recipe that uses it), every such recipe and its colour, or nothing."] =
	"滑鼠停在物品上時顯示的專業技能資訊：你追蹤的路線需要多少（按住Shift查看所有使用它的配方）、所有此類配方及其顏色，或不顯示。"
L["What's new after an update"] = "更新後的新內容"
L["Where the tooltip goes when you hover a recipe. Beside the window, it stays clear of the reagents."] =
	"滑鼠指向配方時提示顯示的位置。放在視窗旁邊就不會擋住材料。"
L["While the auction house is open, the Professions window offers a search for the selected recipe's reagents: as many as the crafts you choose still need after your bags and bank. Auctionator's shopping list carries the quantities; without it, each click puts the next reagent in the search box."] =
	"拍賣場開啟時，專業技能視窗可以搜尋所選配方的材料：數量為扣除背包和銀行後，你選擇的製造次數仍需要的數量。Auctionator的購物清單會帶上數量；沒有它時，每次點擊會把下一個材料填入搜尋框。"
L["With Shortest Path Forever, a click leads you there."] = "有Shortest Path Forever時，點擊即可帶你前往。"
L["With Shortest Path Forever, this picks the nearest by travel time and leads you there."] =
	"有Shortest Path Forever時，會按路程時間選擇最近的並帶你前往。"
L["World drop"] = "世界掉落"
L["Wrist"] = "手腕"
L["You have it"] = "已擁有"
L["You have this book: read it."] = "你有這本書：閱讀它。"
L["You know it"] = "已知"
L["You: %d"] = "你：%d"
L["Your bags allow %d of the route's %d."] = "你的背包可放下%d個（路線需要%d個）。"
L["Your bags and bank have enough."] = "你的背包和銀行中已足夠。"
L["can't identify the profession %s (%s); please report it."] =
	"無法識別專業技能%s（%s）；請回報此問題。"
L["couldn't add tracked reagents to the objective tracker; please report it."] =
	"無法將追蹤的材料加入目標追蹤器；請回報此問題。"
L["crafts"] = "次製造"
L["drop"] = "掉落"
L["every skipped recipe is back in the route."] = "所有跳過的配方都已回到路線中。"
L["files are missing: restart the game (not /reload) after updating."] =
	"檔案遺失：更新後請重新啟動遊戲（而不是/reload）。"
L["for %s"] = "用於%s"
L["gather"] = "採集"
L["green"] = "綠色"
L["grey"] = "灰色"
L["item %d"] = "物品%d"
L["level %d"] = "等級%d"
L["makes %d %s"] = "製造%d個%s"
L["no price"] = "無價格"
L["no skipped recipes: right-click a step on the route page and choose Not this recipe."] =
	"沒有跳過的配方：在路線頁面右鍵點擊一個步驟並選擇「不要此配方」。"
L["no trainer requirements to check."] = "沒有需要檢查的訓練師要求。"
L["none"] = "無"
L["nothing to search for here: what's missing comes from a vendor or your gathering."] =
	"這裡沒有可搜尋的：缺少的來自商人或你的採集。"
L["open a profession first."] = "請先開啟一個專業技能。"
L["open the auction house's Buy tab, then search again."] =
	"請開啟拍賣場的購買標籤頁，然後再次搜尋。"
L["orange"] = "橙色"
L["over 3 weeks ago"] = "超過3週前"
L["profession %d"] = "專業技能%d"
L["quest"] = "任務"
L["recipe %d"] = "配方%d"
L["route set to %s, %s."] = "已設定前往%s的路線，%s。"
L["searching for %s: you need %d more."] = "正在搜尋%s：你還需要%d個。"
L["sorting failed and has been turned off: %s"] = "排序失敗，已關閉：%s"
L["the %s book"] = "書籍%s"
L["the %s quest"] = "任務%s"
L["the reagent names are still loading; search again in a moment."] =
	"材料名稱仍在載入；請稍後再次搜尋。"
L["today"] = "今天"
L["tracked, but the objective tracker section isn't attached; please report it."] =
	"已追蹤，但目標追蹤器中的區塊未附著；請回報此問題。"
L["unknown age"] = "時間不明"
L["unknown location"] = "位置不明"
L["updated to %s. %s"] = "已更新到%s。%s"
L["vendor"] = "商人"
L["waypoint set to %s, %s."] = "已設定前往%s的導航點，%s。"
L["world drop"] = "世界掉落"
L["yellow"] = "黃色"
L["you gather it (%s)"] = "你自己採集（%s）"
L["you gather it (%s), valued at its AH price"] = "你自己採集（%s），按拍賣價計算"
L["you gather it (%s), valued at its vendor sell price"] = "你自己採集（%s），按商人收購價計算"
L["your bags and bank already hold the reagents for that many."] =
	"你的背包和銀行已有足夠這麼多次的材料。"
L["No step yet: learn or train a %s recipe that skills up."] =
	"暫無步驟：學習或訓練一個能提升技能點的%s配方。"
L["Show thresholds bar on the recipe"] = "在配方上顯示技能門檻條" -- mt
L["The orange, yellow, green and grey thresholds and where your skill sits, under the recipe in the Professions window. Turn it off if it covers the reagents."] =
	"橙色、黃色、綠色和灰色門檻以及你的技能位置，顯示在專業視窗的配方下方。如果遮住材料請關閉。" -- mt
L["%s (%s to %d)"] = "%s（%s 至 %d）" -- mt
L["Buying for %s"] = "為 %s 採購" -- mt
L["  %d items have no price yet"] = "  %d 件物品還沒有價格"
L["%d x %s - %s each"] = "%d x %s - 每個 %s"
L["%d x %s - price unknown"] = "%d x %s - 價格未知"
L["%s to %d"] = "%s至%d"
L[", "] = "，"
L[", price seen %d days ago"] = "，%d 天前的價格"
L["/skillup export - show the trainer requirements this character has seen, to paste into a report"] =
	"/skillup export - 顯示此角色見過的訓練師要求，以便貼到報告中"
L["/skillup issue - report a bug or request a feature with a ready-made GitHub issue link"] =
	"/skillup issue - 回報錯誤或請求功能，並附上現成的 GitHub issue 連結"
L["/skillup report - show a report to copy into a bug report"] =
	"/skillup report - 顯示報告，以便複製到錯誤回報中"
L[": "] = "："
L["A buy trip needs Shortest Path Forever."] = "購買行程需要 Shortest Path Forever。"
L["Copy list"] = "複製清單"
L["Copy shopping list"] = "複製購物清單"
L["Gather"] = "採集"
L["Need %d, have %d, missing %d  %s  %s each  %s"] = "需要 %d，現有 %d，缺少 %d  %s  每個 %s  %s"
L["No tracked profession"] = "沒有追蹤的專業"
L["Nothing is missing from the shopping list."] = "購物清單裡沒有缺少的東西。"
L["Nothing to buy"] = "沒有要買的東西"
L["Plan buy trip"] = "規劃購買"
L["Plan this route again from today's prices and recipes."] = "依照今天的價格和配方重新規劃此路線。"
L["Shopping list"] = "購物清單"
L["Shortest Path Forever cannot plan the full trip; setting a waypoint to the first vendor."] =
	"Shortest Path Forever 無法規劃整個行程；已設定前往第一個商人的導航點。"
L["Shortest Path Forever is needed to plan this trip."] = "規劃此行程需要 Shortest Path Forever。"
L["SkillUp Forever shopping list"] = "SkillUp Forever 購物清單"
L["The text is selected. Press Ctrl+C (Cmd+C on a Mac) to copy it."] =
	"文字已選取。按Ctrl+C（Mac上為Cmd+C）複製。"
L["Total for priced items: "] = "有價格物品合計："
L["Unknown"] = "未知"
L["no trainer requirement seen yet: open a profession trainer, then try again."] =
	"尚未見到訓練師要求：開啟專業訓練師，然後再試一次。"
L["on %s"] = "在%s身上"
L["price unknown"] = "價格未知"
L["Unpin recipe"] = "取消釘選配方" -- mt
L["Pin for skill-ups"] = "釘選以提升技能" -- mt
L["Right-click to pin or skip this recipe."] = "右鍵點擊可釘選或略過此配方。" -- mt
L["Unpin: %s"] = "取消釘選：%s" -- mt
L["Pinned for skill-ups."] = "已釘選以提升技能。" -- mt
L["Skill range unknown."] = "技能範圍未知。" -- mt
L["Already grey: no skill-ups."] = "已經變灰：無法提升技能。" -- mt
L["Requires skill %d."] = "需要技能 %d。" -- mt
L["Learn this recipe first."] = "請先學習此配方。" -- mt
L["Reagents not priced yet."] = "材料尚無價格。" -- mt
L["Outside this route or a newer pin takes priority."] = "不在此路線內，或較新釘選的配方優先。" -- mt
L["Pinned: %s"] = "已釘選：%s" -- mt
L["The newest pin takes priority where skill ranges overlap."] =
	"技能範圍重疊時，最近釘選的配方優先。" -- mt
L["Pinned (%d)"] = "已釘選（%d）" -- mt
L["crafted"] = "製作" -- mt
L["List unlearned recipes"] = "列出未學習的配方"
L["Adds the recipes of the open profession you have not learned under an Unlearned divider, greyed and marked with a trainer or recipe item and the skill it asks. They cannot be selected or crafted."] =
	"在「未學習」分隔線下列出目前專業中你尚未學習的配方，以灰色顯示，並標明訓練師或配方以及所需技能。它們無法被選取或製作。"
L["Not learned · %s"] = "未學習 · %s"
L["Trainer"] = "訓練師"
L["Recipe item"] = "配方"
L["listing unlearned recipes failed: %s"] = "列出未學習的配方失敗：%s"
L["Nothing on this route can be gathered, fished or looted by you, so the switch changes nothing for it."] =
	"這條路線沒有你可以採集、釣魚或從生物身上拾取的東西，所以此開關不會改變什麼。" -- mt
L["Loot %d %s from creatures"] = "從生物身上拾取 %d 個%s" -- mt
L["you loot it from creatures"] = "你從生物身上拾取" -- mt
L["you loot it from creatures, valued at its AH price"] = "你從生物身上拾取，按拍賣場價格計算" -- mt
L["you loot it from creatures, valued at its vendor sell price"] =
	"你從生物身上拾取，按商人出售價格計算" -- mt
L["Shift-click crafts all %d."] = "按住Shift點擊製造全部%d個。" -- mt
L["The game's Craft button is not ready for this recipe."] = "遊戲內建的製造按鈕尚未對這份配方就緒。" -- mt
L["vendor, limited stock"] = "商人，庫存有限" -- mt
L["Sells %d at a time"] = "每次出售 %d 個" -- mt
L["This route is mostly %s: %d recipes are left out until their reagents are priced."] =
	"這條路線主要需要%s：在材料定價前有%d個配方被排除。" -- mt
L["Price self-supplied reagents at auction values"] = "Price self-supplied reagents at auction values" -- mt
L["A reagent you gather, loot or already own costs what selling it would bring - its auction price after the 5% cut, or its vendor sell price if that is more - instead of counting as free. With no market price it stays unpriced rather than free. Auction prices need Auctionator or TradeSkillMaster."] =
	"A reagent you gather, loot or already own costs what selling it would bring - its auction price after the 5% cut, or its vendor sell price if that is more - instead of counting as free. With no market price it stays unpriced rather than free. Auction prices need Auctionator/TradeSkillMaster." -- mt

-- Shared debug log (Forever Core's Core/Log.lua).
L["Only buffs for your level"] = "僅顯示適合你等級的增益"
L["Lists only the recipes whose product is a buff you can use at your level: elixirs, flasks, Well Fed food, protection potions, stones, oils and armour kits. Highest required level first. Learned recipes come first, then unlearned ones when those are listed."] =
	"僅列出產物是你在目前等級可使用的增益的配方：藥劑、精煉藥劑、飽食食物、防護藥水、磨刀石、油和護甲套裝。所需等級最高的排在最前。已學習的配方排在前，未學習的配方在列出時排在後面。"
L["%s: %s"] = "%s：%s" -- mt
L["%s drops in %s"] = "%s 在 %s 掉落" -- mt
L["Made by %s %d"] = "%s %d 製作" -- mt
L["Made by %s"] = "%s 製作" -- mt
L["%s at %d"] = "%s（%d）" -- mt
L["A tab at the bottom of the Professions window listing the buff consumables this profession makes, by the skill they unlock at and what each one is for. It opens from the SkillUp side tab, beside the route and crafted gear tabs."] =
	"專業技能視窗底部的一個標籤頁，依解鎖所需的技能與用途列出該專業製造的增益消耗品。從 SkillUp 側邊標籤頁開啟，位於路線與製造裝備標籤頁旁。" -- mt
L["A tab at the bottom of the Professions window listing the newest crafted item this character can equip in each slot. It opens from the SkillUp side tab, beside the route and buffs tabs."] =
	"專業技能視窗底部的一個標籤頁，列出此角色每個部位可裝備的最新製造物品。從 SkillUp 側邊標籤頁開啟，位於路線與增益標籤頁旁。" -- mt
L["A tab at the bottom of the Professions window with a route to your target skill and its reagents. It opens from the SkillUp side tab, beside the crafted gear and buffs tabs. Tracked professions stay in the objective tracker either way."] =
	"專業技能視窗底部的一個標籤頁，顯示通往目標技能及其材料的路線。從 SkillUp 側邊標籤頁開啟，位於製造裝備與增益標籤頁旁。追蹤的專業無論如何都會留在目標追蹤器中。" -- mt
L["Above your level"] = "高於你的等級" -- mt
L["Buffs"] = "增益" -- mt
L["Known"] = "已知" -- mt
L["Later"] = "稍後" -- mt
L["Learn now"] = "現在可學" -- mt
L["No buff items for your level yet."] = "還沒有適合你等級的增益物品。" -- mt
L["Only for level %d"] = "僅限等級 %d" -- mt
L["Show the buffs tab"] = "顯示增益標籤頁" -- mt
L["SkillUp"] = "SkillUp" -- mt
L["This profession makes no buff items."] = "該專業不製造增益物品。" -- mt
L["spell %d"] = "法術 %d" -- mt
L["Buffs by %s skill"] = "%s 增益" -- mt
L["Skill  %d/%d"] = "技能  %d/%d" -- mt
L["Other crafters"] = "其他工匠" -- mt
L["No profession here makes buff items."] = "沒有專業製造增益物品。" -- mt
L["Latest TradeSkillMaster prices."] = "最新的 TradeSkillMaster 價格。" -- mt
L["TradeSkillMaster"] = "TradeSkillMaster" -- mt
L["TradeSkillMaster has no price for these reagents: update its AuctionDB with the TSM desktop app."] =
	"TradeSkillMaster 沒有這些材料的價格：使用 TSM 桌面應用程式更新其 AuctionDB。" -- mt
L["Update TradeSkillMaster's AuctionDB with the TSM desktop app, or visit a vendor, to price reagents."] =
	"使用 TSM 桌面應用程式更新 TradeSkillMaster 的 AuctionDB，或拜訪商人，為材料定價。" -- mt
L["Waiting for Questie to finish loading."] = "正在等待Questie載入完畢。"
L["Nothing is tracked for %s."] = "沒有正在追蹤的 %s。" -- mt
L["+%d more to train"] = "還有 %d 項要學習" -- mt
L["Also train"] = "還要學習" -- mt
L["Auctionator list: %s. Open the auction house, Shopping tab, pick it and Search; buy each row with a click."] =
	"Auctionator 清單：%s。開啟拍賣場，進入「購買」分頁，選擇該清單並搜尋；每次點擊購買一列。"
L["On (the default), a reagent you could gather, fish or loot from creatures is bought at a vendor or the auction house. Off, getting it yourself costs nothing."] =
	"開啟（預設）：你可以採集、釣魚或從生物身上剝取的試劑會從商人或拍賣場購買。關閉：自行取得不花費任何東西。"
L["On (the default), a reagent you could gather, fish or loot from creatures is bought at a vendor or the auction house. Off, getting it yourself costs what it would sell for."] =
	"開啟（預設）：你可以採集、釣魚或從生物身上剝取的試劑會從商人或拍賣場購買。關閉：自行取得花費其出售價值。"
L["Shift + wheel, or drag, scrolls the timeline sideways."] =
	"按住 Shift 滾動滾輪，或拖曳，可橫向捲動時間軸。"
L["SkillUp's list"] = "SkillUp 的清單"
L["Timeline"] = "時間軸"
L["Turning Buy reagents on writes an Auctionator list with every auction reagent still missing."] =
	"開啟「購買試劑」會寫入一個 Auctionator 清單，包含所有仍缺少的拍賣場試劑。"
L["Without Auctionator, a recipe's Search button fills the game's own auction box one reagent at a time."] =
	"沒有 Auctionator 時，配方的「搜尋」按鈕會一次一個試劑地填入遊戲自帶的拍賣搜尋框。"
L["%s: %s is out of date. Update it to fix this."] = "%s：%s 已過期。請更新它來解決此問題。" -- mt
L["%s: %s are out of date. Update them to fix this."] = "%s：%s 已過期。請更新它們來解決此問題。" -- mt
L["%s could not start. Reinstall %s to fix this."] = "%s 無法啟動。請重新安裝 %s 來解決此問題。" -- mt
L["The skill band clears the recipe icon and the Reagents header."] =
	"技能條不再遮住配方圖示和「材料」標題。" -- mt
