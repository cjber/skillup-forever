-- Machine translated (2026-10-16); corrections welcome: https://github.com/cjber/skillup-forever/issues/new?template=translation.yml
local _, ns = ...
if GetLocale() ~= "zhCN" then
	return
end
local L = ns.L
L["Show money beside each recipe. Turning this off keeps prices in the recipe tooltip."] =
	"在每个配方旁显示金钱。关闭后价格仍显示在配方鼠标提示中。" -- mt
L["Show prices on recipe rows"] = "在配方行显示价格" -- mt
L["Show recipe tooltip on hover"] = "悬停时显示配方提示" -- mt
L["Show the SkillUp tooltip beside the Professions window when hovering a recipe. Turn it off to keep the reagents clear."] =
	"悬停配方时在专业窗口旁显示 SkillUp 提示。关闭可避免遮挡材料。" -- mt

L["%d %s"] = "%d %s"
L["%d more"] = "还有%d个"
L["%d of %d"] = "%d/%d"
L["%d reagents have no price"] = "%d 种材料没有价格"
L["%d to %d"] = "%d至%d"
L["%d, from %d to %d"] = "%d次，从%d到%d"
L["%dd ago"] = "%d天前"
L["%s %d"] = "%s %d"
L["%s (%d): bundled %d, classic-db %d"] = "%s（%d）：内置%d，classic-db %d"
L["%s (%d): bundled %s, the trainer wants %d"] = "%s（%d）：内置%s，训练师要求%d"
L["%s (unlearned)"] = "%s（未学习）"
L["%s is at %s."] = "%s位于%s。"
L["%s is in %s."] = "%s在%s。"
L["%s trainer"] = "%s训练师"
L["%s until %d"] = "%s直到%d"
L["%s, %d"] = "%s，%d"
L["%s, %s, to %d"] = "%s，%s，至%d"
L["%s, source unknown"] = "%s，来源未知"
L["%s: %d moved, %d confirmed at a trainer, %d wrong."] =
	"%s：移动%d个，在训练师处确认%d个，错误%d个。"
L["+%d more"] = "另有%d个"
L["/skillup skipped lists the recipes you skipped, with their IDs."] =
	"/skillup skipped 列出你跳过的配方及其ID。"
L["/skillup unskip <recipe ID> shows one again, /skillup unskip all every one."] =
	"/skillup unskip <recipe ID> 恢复显示一个，/skillup unskip all 恢复全部。"
L["A Reagents tab on a merchant's window that lists the reagents your tracked routes still need from that merchant and their total cost. Buy them from the merchant's own window."] =
	"在商人窗口显示材料标签页，列出你追踪的路线仍需要从该商人处购买的材料及其总费用。请在商人窗口中购买。"
L["A material your professions gather costs what selling it would bring instead of nothing: its auction price after the 5% cut, or its vendor sell price if that is more. Used for the route and the costs on recipe rows. Auction prices need Auctionator, TradeSkillMaster, AHDB or Naowh Forever."] =
	"你的专业采集的材料按出售所得计价，而不是免费：扣除5%手续费后的拍卖价，或更高时按商人收购价。用于路线和配方行的成本。拍卖价需要Auctionator/TradeSkillMaster / AHDB / Naowh Forever。"
L["Keeps the shared Forever tracker where you put it. The grip at its top no longer drags it."] =
	"将共享的 Forever 追踪器保持在您放置的位置。顶部的拖拽手柄不再移动它。"
L["Lock the tracker"] = "锁定追踪器"

L["AH"] = "拍卖行"
L["Add the start of each recipe's difficulty range. This is separate from the skill needed to learn it."] =
	"显示每个配方难度区间的起点。这与学习它所需的技能不同。"
L["Addon"] = "插件"
L["Also for this slot"] = "此部位的其他物品"
L["Annotate trainer recipes"] = "标注训练师配方"
L["Another craft makes this recipe, not yours."] = "此配方由其他专业制造，而不是你的专业。"
L["Another crafter"] = "其他制造者"
L["At the %d cap: no trainer teaches the next rank."] = "已达上限%d：没有训练师教授下一等级。"
L["At the cursor"] = "鼠标位置"
L["AtlasLoot is installed but not running: enable it in the AddOns list, or update it if out of date."] =
	"AtlasLoot已安装但未运行：请在插件列表中启用，或在过期时更新。"
L["Attach to quest tracker"] = "附着到任务追踪栏"
L["Auction house"] = "拍卖行"
L["Auction price if higher"] = "拍卖价（若更高）"
L["Auctionator hasn't seen these reagents yet: scan the auction house with it to price them."] =
	"Auctionator尚未见过这些材料：请用它扫描拍卖行以获取价格。"
L["Auctionator's scan when the auction house opens is off: turn it on in Auctionator, Basic Options."] =
	"Auctionator在打开拍卖行时的扫描已关闭：请在Auctionator的“Basic Options”中开启。"
L["Auctionator, %s"] = "Auctionator，%s"
L["Back"] = "背部"
L["Beside the Professions window"] = "专业窗口旁边"
L["Buy %d %s"] = "购买%d个%s"
L["Buy %s"] = "购买%s" -- mt
L["Buy %s at %d"] = "在%2$d购买%1$s" -- mt
L["Buy all"] = "全部购买"
L["Buy and read %s at %d"] = "购买并阅读%s（技能%d）"
L["Buy and read %s at %d (level %d)"] = "购买并阅读%s（技能%d，等级%d）"
L["Buy reagents"] = "购买材料"
L["Buy reagents at the auction house"] = "在拍卖行购买材料"
L["Can learn it"] = "可以学习"
L["Cheapest skill-up"] = "最便宜的技能提升"
L["Chest"] = "胸部"
L["Click for a waypoint to %s."] = "点击设置前往%s的路径点。"
L["Click for a waypoint."] = "点击设置路径点。"
L["Click to craft %d."] = "点击制造%d个。"
L["Click to open the recipe."] = "点击打开配方。"
L["Click to show a recipe again."] = "点击恢复显示一个配方。"
L["Close"] = "关闭"
L["Complete %s at %d"] = "完成%s（技能%d）"
L["Complete %s at %d (level %d)"] = "完成%s（技能%d，等级%d）"
L["Complete %s first: you're at your cap."] = "请先完成%s：你已达上限。"
L["Cost"] = "成本"
L["Count what crafts sell for"] = "计入制造品的售价"
L["Craft %d %s"] = "制造%d个%s"
L["Craft %d of %d× %s"] = "制造%d/%d× %s"
L["Craft %d× %s"] = "制造%d× %s"
L["Craft %s"] = "制造%s"
L["Craft"] = "制造"
L["Craft next"] = "制造下一个"
L["Crafted gear"] = "制造装备"
L["Crafts"] = "制造次数"
L["Don't count it"] = "不计入"
L["Dropped by"] = "掉落自"
L["Each"] = "单价"
L["Every recipe that uses it"] = "所有使用它的配方"
L["Fee"] = "费用"
L["Fees"] = "费用"
L["Feet"] = "脚"
L["Finger"] = "手指"
L["First used at"] = "首次使用于"
L["Gather %d %s"] = "采集%d个%s"
L["Gathering skill on nodes"] = "采集点的采集技能"
L["Hands"] = "手部"
L["Have (bags and bank)"] = "已有（背包和银行）"
L["Head"] = "头部"
L["Herb and ore node tooltips show the skill they need and its colour at yours. Skinnable corpses show ? until the skinning rule is confirmed on Forever."] =
	"草药和矿脉的鼠标提示会显示所需技能及其相对你技能的颜色。可剥皮的尸体在Forever上的剥皮规则确认前显示?。"
L["Install AtlasLoot to see the recipes vendors, quests and drops would add."] =
	"安装AtlasLoot以查看商人、任务和掉落可提供的配方。"
L["Install QuestieDB and AtlasLoot to see where recipes, vendors and trainers are."] =
	"安装QuestieDB和AtlasLoot以查看配方、商人和训练师的位置。"
L["Install QuestieDB to see vendors, quests and trainers, with waypoints to them."] =
	"安装QuestieDB以查看商人、任务和训练师，并可设置路径点。"
L["Its trainer should teach these at your skill now:"] = "以你现在的技能，训练师应该能教你这些："
L["Kept in the Auctionator list '%s'."] = "已保存在Auctionator列表“%s”中。"
L["Latest Auctionator prices."] = "最新的Auctionator价格。"
L["Latest Auctionator prices: rescan to update old prices."] =
	"最新的Auctionator价格：重新扫描以更新旧价格。"
L["Learn a crafting profession to plan a route."] = "学习一个制造专业来规划路线。"
L["Legs"] = "腿部"
L["Level %d"] = "等级%d"
L["Level %d %s"] = "等级%d %s"
L["Made at"] = "制造地点"
L["Main hand"] = "主手"
L["Missing reagents for this step."] = "此步骤缺少材料。"
L["Money on recipe rows"] = "配方行中的金额"
L["Nearest trainer"] = "最近的训练师"
L["Nearest vendor"] = "最近的商人"
L["Neck"] = "颈部"
L["Need %d more %s"] = "还需要%d个%s"
L["Need a %s in your bags."] = "背包中需要%s。"
L["Needs %s %d"] = "需要%s %d"
L["Needs %s, sells back %s"] = "需要 %s，卖出返还 %s"
L["Needs %s, sells back %s (incomplete)"] = "需要 %s，卖出返还 %s（不完整）"
L["Net per craft"] = "每次制造净成本"
L["Newest recipes first"] = "最新配方优先"
L["Next to the recipe"] = "配方旁边"
L["No crafted gear for your level and class yet."] = "暂无适合你等级和职业的制造装备。"
L["No crafted gear you can make yet. Tick the box above to see gear you cannot make."] =
	"暂无你能制造的装备。勾选上方的选项以查看你不能制造的装备。"
L["No skill data for this recipe yet."] = "此配方暂无技能数据。"
L["No trainer teaches this rank: a book does."] = "没有训练师教授此等级：需要书籍。"
L["No trainer teaches this rank: a quest does."] = "没有训练师教授此等级：需要任务。"
L["Not in this route: you chose Not this recipe."] = "不在此路线中：你选择了“不要此配方”。"
L["Not this recipe"] = "不要此配方"
L["Nothing priced you know skills up past %d."] = "你已知且有价格的配方都无法将技能提升到%d以上。"
L["Nothing to buy for this route."] = "此路线无需购买任何物品。"
L["Nothing to craft on this route."] = "此路线无需制造任何物品。"
L["Nothing you know skills up past %d."] = "你已知的配方都无法将技能提升到%d以上。"
L["Off hand"] = "副手"
L["On %s"] = "在%s"
L["One line in chat the first time a new version loads."] = "新版本首次加载时在聊天框显示一行。"
L["Open"] = "打开"
L["Open %s to craft from here."] = "打开%s以便在此制造。"
L["Open recipe"] = "打开配方"
L["Per craft"] = "每次制作"
L["Per skill-up"] = "每点技能"
L["Per skill-up is the cost of one skill point. Per craft is what one craft costs or earns, shown on recipes that no longer give skill too."] =
	"每点技能是提升一点技能的成本。每次制作是一次制作的成本或收益，不再提升技能的配方也会显示。"
L["Price"] = "价格"
L["Prices"] = "价格"
L["Profession reagents"] = "专业材料"
L["Profit per craft"] = "每次制造利润"
L["Profit per skill-up"] = "每点技能利润"
L["Quest"] = "任务"
L["Quest giver"] = "任务NPC"
L["Raises your skill cap to %d."] = "将你的技能上限提高到%d。"
L["Ranged"] = "远程"
L["Read %s at %d"] = "阅读%s（技能%d）"
L["Read %s at %d (level %d)"] = "阅读%s（技能%d，等级%d）"
L["Read %s first: you're at your cap."] = "请先阅读%s：你已达上限。"
L["Reagent tooltips"] = "材料鼠标提示"
L["Reagents"] = "材料"
L["Reagents  (have / need)"] = "材料  （已有 / 需要）"
L["Reagents for"] = "材料用于"
L["Reagents in hand"] = "材料已备齐"
L["Reagents still needed"] = "仍需的材料"
L["Recipe rows"] = "配方行"
L["Recipe tooltip position"] = "配方提示位置"
L["Recipes from vendors, quests and drops that would carry it on:"] =
	"可以继续提升的商人、任务和掉落配方："
L["Required skill, skill-up chance and cost on profession trainer recipes, and which one is best to train next for your route."] =
	"在专业训练师的配方上显示所需技能、技能提升几率和成本，并指出你的路线下一步最适合学习哪个。"
L["Requires"] = "需要"
L["Replan"] = "重新规划"
L["Route"] = "路线"
L["Route and trainer"] = "路线和训练师"
L["Route incomplete: %d recipes left out because their costs or sale values are unknown."] =
	"路线不完整：%d 个配方因成本或出售价值未知而被排除。"
L["Route needs"] = "路线需要"
L["Route: %d/%d · %s to %d"] = "路线：%d/%d · %s至%d"
L["Sales"] = "出售"
L["Scales the shared Forever tracker. 100% matches the game's own tracker."] =
	"调整共享Forever追踪栏的大小。100%与游戏自身的追踪栏一致。"
L["Scan the auction house with Auctionator, or visit a vendor, to price reagents."] =
	"用Auctionator扫描拍卖行或访问商人来获取材料价格。"
L["Scroll"] = "配方"
L["Search"] = "搜索"
L["Show reagent search and keep shopping lists"] = "显示材料搜索并维护购物清单"
L["Sells for"] = "售价"
L["Sells for x%g"] = "售价 x%g"
L["Set waypoint"] = "设置路径点"
L["Shift-click to link the scroll."] = "Shift-点击以链接配方。"
L["Shift: used in %d of your recipes"] = "Shift：用于你的%d个配方"
L["Shoulder"] = "肩部"
L["Show again: %s"] = "恢复显示：%s"
L["Show gear I cannot make yet"] = "显示我还不能制造的装备"
L["Show profession routes in the objective tracker. Hiding them keeps your tracked professions and targets."] =
	"在目标追踪栏中显示专业路线。隐藏时会保留你追踪的专业和目标。"
L["Show skill on recipe rows"] = "在配方行显示技能"
L["Show skill range start on rows"] = "在行上显示区间起点"
L["Show the merchant Reagents tab"] = "显示商人材料标签页"
L["Show the crafted gear tab"] = "显示制造装备标签页"
L["Show the levelling route tab"] = "显示升级路线标签页"
L["Show tracked professions"] = "显示追踪的专业"
L["Skill  %d/%d     Target"] = "技能  %d/%d     目标"
L["Skill points a craft"] = "每次制造技能点"
L["Skill range start"] = "区间起点"
L["Skill range starts at %d"] = "区间起点为%d"
L["Skill-up chance"] = "技能提升几率"
L["Skill-up chance and cost per skill-up at the right of each recipe."] =
	"在每个配方右侧显示技能提升几率和每点技能成本。"
L["Skill-up chance: %d%%"] = "技能提升几率：%d%%"
L["SkillUp report"] = "SkillUp报告"
L["Skipped (%d)"] = "已跳过（%d）"
L["Skipped (%d):"] = "已跳过（%d）："
L["Sold by"] = "出售者"
L["Sort by"] = "排序"
L["Sort recipes"] = "配方排序"
L["Source"] = "来源"
L["Source unknown"] = "来源未知"
L["Stop tracking"] = "取消追踪"
L["Subtract what the crafted item sells for from its cost. Auction prices need Auctionator, TradeSkillMaster, AHDB or Naowh Forever, are after the 5% cut, and may not sell."] =
	"从成本中减去制造物品的售价。拍卖价需要Auctionator/TradeSkillMaster / AHDB / Naowh Forever，已扣除5%手续费，且不一定能卖出。"
L["Taught by %s trainers."] = "由%s训练师教授。"
L["The place this recipe is taught isn't known yet."] = "尚不清楚在哪里学习此配方。"
L["The rest comes from a vendor or your gathering."] = "其余来自商人或你的采集。"
L["The route asks for %d to reach %d in 9 runs of 10; a worse run needs more."] =
	"路线按%d个计算，十次中有九次能达到%d；运气差时需要更多。"
L["The source of this recipe isn't known."] = "此配方的来源未知。"
L["To buy"] = "待购买"
L["Tool"] = "工具"
L["Tooltips and sorting"] = "鼠标提示和排序"
L["Track"] = "追踪"
L["Tracker scale"] = "追踪栏大小"
L["Train %s"] = "学习%s"
L["Train %s at %d"] = "学习%s（技能%d）"
L["Train %s at %d (level %d)"] = "学习%s（技能%d，等级%d）"
L["Train %s first."] = "请先学习%s。"
L["Train %s first: you're at your cap."] = "请先学习%s：你已达上限。"
L["Trinket"] = "饰品"
L["Turn this off to drag the shared Forever tracker anywhere on screen."] =
	"关闭此项后可将共享的Forever追踪栏拖到屏幕任意位置。"
L["Update QuestieDB to see vendors, quests and trainers, with waypoints to them."] =
	"更新QuestieDB以查看商人、任务和训练师，并可设置路径点。"
L["Used in"] = "用于"
L["Value gathered materials at what they'd sell for"] = "按售价计算采集的材料"
L["Vendor"] = "商人"
L["Vendor reagents"] = "商人材料"
L["Vendor sell price"] = "商人收购价"
L["Visit a vendor to price reagents. Auction prices need Auctionator, TradeSkillMaster, AHDB or Naowh Forever."] =
	"访问商人以获取材料价格。拍卖价需要Auctionator/TradeSkillMaster / AHDB / Naowh Forever。"
L["Waist"] = "腰部"
L["Waypoint to a trainer"] = "前往训练师的路径点"
L["Waypoint to a vendor: %s"] = "前往商人的路径点：%s"
L["Waypoint to the quest giver: %s"] = "前往任务NPC的路径点：%s"
L["What's new after an update"] = "更新后的新内容"
L["Where the tooltip goes when you hover a recipe. Beside the window, it stays clear of the reagents."] =
	"鼠标指向配方时提示显示的位置。放在窗口旁边就不会挡住材料。"
L["Click Search in the Professions window to look for the reagents your chosen crafts still need. With Auctionator, SkillUp also keeps shopping lists for tracked routes set to Buy reagents. Without Auctionator, each click fills the auction house search box with the next reagent."] =
	"点击专业技能窗口中的搜索，查找所选制作数量仍缺少的材料。安装 Auctionator 后，SkillUp 还会维护已追踪且启用了购买材料的路线的购物清单。未安装 Auctionator 时，每次点击都会将下一种材料填入拍卖行搜索框。"
L["World drop"] = "世界掉落"
L["Wrist"] = "手腕"
L["You have it"] = "已拥有"
L["You have this book: read it."] = "你有这本书：阅读它。"
L["You know it"] = "已学会"
L["You: %d"] = "你：%d"
L["Your bags allow %d of the route's %d."] = "你的背包可放下%d个（路线需要%d个）。"
L["Your bags and bank have enough."] = "你的背包和银行中已足够。"
L["can't identify the profession %s (%s); please report it."] = "无法识别专业%s（%s）；请报告此问题。"
L["couldn't add tracked reagents to the objective tracker; please report it."] =
	"无法将追踪的材料添加到目标追踪栏；请报告此问题。"
L["crafts"] = "次制造"
L["drop"] = "掉落"
L["every skipped recipe is back in the route."] = "所有跳过的配方都已回到路线中。"
L["files are missing: restart the game (not /reload) after updating."] =
	"文件缺失：更新后请重启游戏（而不是/reload）。"
L["for %s"] = "用于%s"
L["gather"] = "采集"
L["green"] = "绿色"
L["grey"] = "灰色"
L["item %d"] = "物品%d"
L["level %d"] = "等级%d"
L["makes %d %s"] = "制造%d个%s"
L["no price"] = "无价格"
L["no skipped recipes: right-click a step on the route page and choose Not this recipe."] =
	"没有跳过的配方：在路线页面右键点击一个步骤并选择“不要此配方”。"
L["no trainer requirements to check."] = "没有需要检查的训练师要求。"
L["none"] = "无"
L["nothing to search for here: what's missing comes from a vendor or your gathering."] =
	"这里没有可搜索的：缺少的来自商人或你的采集。"
L["open a profession first."] = "请先打开一个专业。"
L["open the auction house's Buy tab, then search again."] =
	"请打开拍卖行的购买标签页，然后再次搜索。"
L["orange"] = "橙色"
L["over 3 weeks ago"] = "超过3周前"
L["profession %d"] = "专业%d"
L["quest"] = "任务"
L["recipe %d"] = "配方%d"
L["route set to %s, %s."] = "已设置前往%s的路线，%s。"
L["searching for %s: you need %d more."] = "正在搜索%s：你还需要%d个。"
L["sorting failed and has been turned off: %s"] = "排序失败，已关闭：%s"
L["the %s book"] = "书籍%s"
L["the %s quest"] = "任务%s"
L["the reagent names are still loading; search again in a moment."] =
	"材料名称仍在加载；请稍后再次搜索。"
L["today"] = "今天"
L["tracked, but the objective tracker section isn't attached; please report it."] =
	"已追踪，但目标追踪栏中的分区未附着；请报告此问题。"
L["unknown age"] = "时间未知"
L["unknown location"] = "位置未知"
L["updated to %s. %s"] = "已更新到%s。%s"
L["vendor"] = "商人"
L["waypoint set to %s, %s."] = "已设置前往%s的路径点，%s。"
L["world drop"] = "世界掉落"
L["yellow"] = "黄色"
L["you gather it (%s)"] = "你自己采集（%s）"
L["you gather it (%s), valued at its AH price"] = "你自己采集（%s），按拍卖价计算"
L["you gather it (%s), valued at its vendor sell price"] = "你自己采集（%s），按商人收购价计算"
L["your bags and bank already hold the reagents for that many."] =
	"你的背包和银行已有足够这么多次的材料。"
L["No step yet: learn or train a %s recipe that skills up."] =
	"暂无步骤：学习或训练一个能提升技能点的%s配方。"
L["Show thresholds bar on the recipe"] = "在配方上显示技能阈值条" -- mt
L["The orange, yellow, green and grey thresholds and where your skill sits, under the recipe in the Professions window. Turn it off if it covers the reagents."] =
	"橙色、黄色、绿色和灰色阈值以及你的技能位置，显示在专业窗口的配方下方。如果遮挡材料请关闭。" -- mt
L["%s (%s to %d)"] = "%s（%s 至 %d）" -- mt
L["Buying for %s"] = "为 %s 采购" -- mt
L["  %d items have no price yet"] = "  %d 件物品还没有价格"
L["%d x %s - %s each"] = "%d x %s - 每个 %s"
L["%d x %s - price unknown"] = "%d x %s - 价格未知"
L["%s to %d"] = "%s至%d"
L[" · "] = " · "
L[", "] = "，"
L[", price seen %d days ago"] = "，%d 天前的价格"
L["/skillup export - show the trainer requirements this character has seen, to paste into a report"] =
	"/skillup export - 显示此角色见过的训练师要求，以便粘贴到报告中"
L["/skillup issue - report a bug or request a feature with a ready-made GitHub issue link"] =
	"/skillup issue - 报告错误或请求功能，并附上现成的 GitHub issue 链接"
L["/skillup report - show a report to copy into a bug report"] =
	"/skillup report - 显示报告，以便复制到错误报告中"
L[": "] = "："
L["A buy trip needs Shortest Path Forever."] = "购买行程需要 Shortest Path Forever。"
L["Copy list"] = "复制列表"
L["Copy shopping list"] = "复制购物清单"
L["Gather"] = "采集"
L["Need %d, have %d, missing %d  %s  %s each  %s"] = "需要 %d，已有 %d，缺少 %d  %s  每个 %s  %s"
L["No tracked profession"] = "没有追踪的专业"
L["Nothing is missing from the shopping list."] = "购物清单里没有缺少的东西。"
L["Nothing to buy"] = "没有可买的东西"
L["Plan buy trip"] = "规划购买"
L["Plan this route again from today's prices and recipes."] = "根据今天的价格和配方重新规划此路线。"
L["Shopping list"] = "购物清单"
L["Shortest Path Forever cannot plan the full trip; setting a waypoint to the first vendor."] =
	"Shortest Path Forever 无法规划整个行程；已设置前往第一个商人的路径点。"
L["Shortest Path Forever is needed to plan this trip."] = "规划此行程需要 Shortest Path Forever。"
L["SkillUp Forever shopping list"] = "SkillUp Forever 购物清单"
L["The text is selected. Press Ctrl+C (Cmd+C on a Mac) to copy it."] =
	"文本已选中。按Ctrl+C（Mac上为Cmd+C）复制。"
L["Total for priced items: "] = "有价格物品合计："
L["Unknown"] = "未知"
L["no trainer requirement seen yet: open a profession trainer, then try again."] =
	"尚未见到训练师要求：打开专业训练师，然后重试。"
L["on %s"] = "在%s身上"
L["price unknown"] = "价格未知"
L["Unpin recipe"] = "取消固定配方" -- mt
L["Pin for skill-ups"] = "固定用于提升技能" -- mt
L["Right-click to pin or skip this recipe."] = "右键点击可固定或跳过此配方。" -- mt
L["Unpin: %s"] = "取消固定：%s" -- mt
L["Pinned for skill-ups."] = "已固定用于提升技能。" -- mt
L["Skill range unknown."] = "技能范围未知。" -- mt
L["Already grey: no skill-ups."] = "已经变灰：无法提升技能。" -- mt
L["Requires skill %d."] = "需要技能 %d。" -- mt
L["Learn this recipe first."] = "请先学习此配方。" -- mt
L["Reagents not priced yet."] = "材料尚无价格。" -- mt
L["Outside this route or a newer pin takes priority."] = "不在此路线内，或较新固定的配方优先。" -- mt
L["Pinned: %s"] = "已固定：%s" -- mt
L["The newest pin takes priority where skill ranges overlap."] =
	"技能范围重叠时，最近固定的配方优先。" -- mt
L["Pinned (%d)"] = "已固定（%d）" -- mt
L["crafted"] = "制作" -- mt
L["List unlearned recipes"] = "列出未学习的配方"
L["Adds the recipes of the open profession you have not learned under an Unlearned divider, greyed and marked with a trainer or recipe item and the skill it asks. Click a row to preview the recipe."] =
	"在“未学习”分隔线下列出当前专业中你尚未学习的配方，以灰色显示，并标明训练师或配方以及所需技能。点击条目可预览配方。"
L["Not learned · %s"] = "未学习 · %s"
L["Trainer"] = "训练师"
L["Recipe item"] = "配方"
L["listing unlearned recipes failed: %s"] = "列出未学习的配方失败：%s"
L["Nothing on this route can be gathered, fished or looted by you, so the switch changes nothing for it."] =
	"这条路线没有你可以采集、钓鱼或从生物身上拾取的东西，所以此开关不会改变什么。" -- mt
L["Loot %d %s from creatures"] = "从生物身上拾取 %d 个%s" -- mt
L["you loot it from creatures"] = "你从生物身上拾取" -- mt
L["you loot it from creatures, valued at its AH price"] = "你从生物身上拾取，按拍卖行价格计算" -- mt
L["you loot it from creatures, valued at its vendor sell price"] =
	"你从生物身上拾取，按商人出售价格计算" -- mt
L["Shift-click crafts all %d."] = "按住Shift点击制造全部%d个。" -- mt
L["The game's Craft button is not ready for this recipe."] = "游戏自带的制造按钮尚未对这份配方就绪。" -- mt
L["vendor, limited stock"] = "商人，库存有限" -- mt
L["Sells %d at a time"] = "每次出售 %d 个" -- mt
L["This route is mostly %s: %d recipes are left out until their costs or sale values are known."] =
	"此路线主要使用 %s：%d 个配方会在成本或出售价值确定后加入。"
L["Price self-supplied reagents at auction values"] = "Price self-supplied reagents at auction values" -- mt
L["A reagent you gather, loot or already own costs what selling it would bring - its auction price after the 5% cut, or its vendor sell price if that is more - instead of counting as free. With no market price it stays unpriced rather than free. Auction prices need Auctionator, TradeSkillMaster, AHDB or Naowh Forever."] =
	"A reagent you gather, loot or already own costs what selling it would bring - its auction price after the 5% cut, or its vendor sell price if that is more - instead of counting as free. With no market price it stays unpriced rather than free. Auction prices need Auctionator/TradeSkillMaster / AHDB / Naowh Forever." -- mt

-- Shared debug log (ForeverCore's Core/Log.lua).
L["Only buffs for your level"] = "仅显示适合你等级的增益"
L["Lists only the recipes whose product is a buff you can use at your level: elixirs, flasks, Well Fed food, protection potions, stones, oils and armour kits. Highest required level first. Learned recipes come first, then unlearned ones when those are listed."] =
	"仅列出产物是你在当前等级可使用的增益的配方：药剂、合剂、饱食食物、防护药水、磨刀石、油和护甲套装。所需等级最高的排在最前。已学习的配方排在前，未学习的配方在列出时排在后面。"
L["%s: %s"] = "%s：%s" -- mt
L["%s drops in %s"] = "%s 在 %s 掉落" -- mt
L["Made by %s %d"] = "%s %d 制作" -- mt
L["Made by %s"] = "%s 制作" -- mt
L["%s at %d"] = "%s（%d）" -- mt
L["A tab at the bottom of the Professions window listing the buff consumables this profession makes, by the skill they unlock at and what each one is for. It opens from the SkillUp side tab, beside the route and crafted gear tabs."] =
	"专业窗口底部的一个标签页，按解锁所需的技能和用途列出该专业制造的增益消耗品。从 SkillUp 侧边标签页打开，位于路線和制造装备标签页旁。" -- mt
L["A tab at the bottom of the Professions window listing the newest crafted item this character can equip in each slot. It opens from the SkillUp side tab, beside the route and buffs tabs."] =
	"专业窗口底部的一个标签页，列出此角色每个部位可装备的最新制造物品。从 SkillUp 侧边标签页打开，位于路線和增益标签页旁。" -- mt
L["A tab at the bottom of the Professions window with a route to your target skill and its reagents. It opens from the SkillUp side tab, beside the crafted gear and buffs tabs. Tracked professions stay in the objective tracker either way."] =
	"专业窗口底部的一个标签页，显示通往目标技能及其材料的路線。从 SkillUp 侧边标签页打开，位于制造装备和增益标签页旁。跟踪的专业无论如何都会留在目标追踪器中。" -- mt
L["Above your level"] = "高于你的等级" -- mt
L["Buffs"] = "增益" -- mt
L["Known"] = "已知" -- mt
L["Later"] = "稍后" -- mt
L["Learn now"] = "现在可学" -- mt
L["No buff items for your level yet."] = "还没有适合你等级的增益物品。" -- mt
L["Only for level %d"] = "仅限等级 %d" -- mt
L["Show the buffs tab"] = "显示增益标签页" -- mt
L["Show the supply tab"] = "显示补给标签页" -- mt
L["A tab at the bottom of the Professions window where you set what a merchant will sell and deliver, so the route can plan around it. It opens from the SkillUp side tab, beside the route tab."] =
	"专业窗口底部的一个标签页，用于设置商人将出售和交付的物品，以便路线据此规划。从 SkillUp 侧边标签页打开，位于路线标签页旁。" -- mt
L["SkillUp"] = "SkillUp" -- mt
L["This profession makes no buff items."] = "该专业不制造增益物品。" -- mt
L["spell %d"] = "法术 %d" -- mt
L["Buffs by %s skill"] = "%s 增益" -- mt
L["Skill  %d/%d"] = "技能  %d/%d" -- mt
L["Other crafters"] = "其他工匠" -- mt
L["No profession here makes buff items."] = "没有专业制造增益物品。" -- mt
L["Latest TradeSkillMaster prices."] = "最新的 TradeSkillMaster 价格。" -- mt
L["TradeSkillMaster"] = "TradeSkillMaster" -- mt
L["TradeSkillMaster has no price for these reagents: update its AuctionDB with the TSM desktop app."] =
	"TradeSkillMaster 没有这些材料的价格：使用 TSM 桌面应用更新其 AuctionDB。" -- mt
L["Update TradeSkillMaster's AuctionDB with the TSM desktop app, or visit a vendor, to price reagents."] =
	"使用 TSM 桌面应用更新 TradeSkillMaster 的 AuctionDB，或访问商人，为材料定价。" -- mt
L["Waiting for Questie to finish loading."] = "正在等待Questie加载完毕。"
L["Nothing is tracked for %s."] = "没有正在追踪的 %s。" -- mt
L["+%d more to train"] = "还有 %d 项要学习" -- mt
L["Also train"] = "还要学习" -- mt
L["Auctionator list: %s. Open the auction house, Shopping tab, pick it and Search; buy each row with a click."] =
	"Auctionator 列表：%s。打开拍卖行，进入“购买”标签，选择该列表并搜索；每次点击购买一行。"
L["On (the default), a reagent you could gather, fish or loot from creatures is bought at a vendor or the auction house. Off, getting it yourself costs nothing."] =
	"开启（默认）：你可以采集、钓鱼或从生物身上剥取的试剂会从商人或拍卖行购买。关闭：自己获取不花费任何东西。"
L["On (the default), a reagent you could gather, fish or loot from creatures is bought at a vendor or the auction house. Off, getting it yourself costs what it would sell for."] =
	"开启（默认）：你可以采集、钓鱼或从生物身上剥取的试剂会从商人或拍卖行购买。关闭：自己获取花费其出售价值。"
L["Shift + wheel, or drag, scrolls the timeline sideways."] =
	"按住 Shift 滚动滚轮，或拖动，可横向滚动时间线。"
L["Timeline"] = "时间线"
L["Turning Buy reagents on writes an Auctionator list with every auction reagent still missing."] =
	"开启“购买试剂”会写入一个 Auctionator 列表，包含所有仍缺少的拍卖行试剂。"
L["Without Auctionator, a recipe's Search button fills the game's own auction box one reagent at a time."] =
	"没有 Auctionator 时，配方的“搜索”按钮会一次一个试剂地填入游戏自带的拍卖搜索框。"
L["%s needs ForeverCore. Install it from CurseForge, or choose Reinstall on ForeverCore in the CurseForge app."] =
	"%s 需要 ForeverCore。请从 CurseForge 安装，或在 CurseForge 应用中为 ForeverCore 选择重新安装。" -- mt
L["%s: the installed ForeverCore is another addon (%s). Remove it and install ForeverCore from CurseForge."] =
	"%s：已安装的 ForeverCore 是另一个插件（%s）。请移除它并从 CurseForge 安装 ForeverCore。" -- mt
L["%s: ForeverCore is turned off. Enable it in the AddOns list to fix this."] =
	"%s：ForeverCore 已禁用。请在插件列表中启用它来解决此问题。" -- mt
L["%s: %s is out of date. Update it to fix this."] = "%s：%s 已过期。请更新它来解决此问题。" -- mt
L["%s: %s are out of date. Update them to fix this."] = "%s：%s 已过期。请更新它们来解决此问题。" -- mt
L["%s could not start. Reinstall %s to fix this."] = "%s 无法启动。请重新安装 %s 来解决此问题。" -- mt
L["Region sale average"] = "地区平均成交价"
L["Region sale average if higher"] = "较高时使用地区平均成交价"
L["Region sale averages need TradeSkillMaster and its desktop app. They estimate value from reported regional sales and purchases, with the vendor price as a floor. They do not guarantee a sale."] =
	"地区平均成交价需要 TradeSkillMaster 及其桌面应用。此价格根据已记录的地区买卖估算价值，且不低于商店售出价。此价格不保证物品能够售出。"

L["Counts include spares for an estimated %d%% chance to finish the whole route."] =
	"数量包含预留，以估计 %d%% 的概率完成整条路线。" -- mt
L["Restock visit cost"] = "补货往返费用" -- mt
L["Not counted"] = "不计入" -- mt
L["What one trip to buy more reagents is worth, in copper, when a run takes more crafts than planned. It is added to that reagent's purchase price only when it happens. Leave it at zero to count no trip."] =
	"当一次制作需要比计划更多的次数时，一趟去购买更多材料的费用值多少铜币。它只在实际发生时加到该材料的购买价格上。保持为零则不计算往返费用。" -- mt
L["%s (%s)"] = "%s (%s)"
L["%s profit per craft"] = "每次制造 %s 利润"
L["%s profit per skill-up"] = "每点技能 %s 利润"
L["Auction price"] = "拍卖价格"
L["Auction prices from"] = "拍卖价格来源"
L["Auctionator"] = "Auctionator"

L["Skill %d to %d, %s"] = "技能%d至%d，%s" -- mt
L["Skill %d to %d, %s, at %s"] = "技能%d至%d，%s，地点：%s" -- mt
L["%s, uses materials you have"] = "%s，使用你已有的材料" -- mt
L["Unlearned recipe order"] = "未学配方排序" -- mt
L["How recipes you have not learned are ordered. Learned recipes keep the selected recipe order."] =
	"尚未学会的配方的排序方式。已学配方保留所选的排序方式。" -- mt
L["TSM regional sales per day"] = "TSM地区每日销量" -- mt
L["Average sold per auction house in your region, reported by TSM."] =
	"TSM报告的所在地区每个拍卖行的平均销量。" -- mt

L["Open %s from your spellbook."] = "从法术书中打开%s。"

L["Recipes on Shift"] = "按住Shift显示配方" -- mt
L["Show recipes on Shift or always. Off hides reagent details, including route needs."] =
	"按住Shift或始终显示配方。关闭后会隐藏材料详情，包括路线需求。" -- mt
L["Show route needs on item tooltips"] = "在物品提示中显示路线需求" -- mt
L["Show how much of an item your tracked routes still need. Turn this off to keep recipe details without the route line."] =
	"显示追踪路线还需要多少此物品。关闭后可保留配方详情，但隐藏路线行。" -- mt

L["Have (bags only)"] = "拥有（仅背包）" -- mt

L["%s%% to %s%%"] = "%s%%至%s%%" -- mt
L["Adds an estimated 4 percentage points per Working Overtime rank to yellow and green skill-up chances. Whether the game adds the talent's bonus as points or multiplies the chance by it is not confirmed yet, so this starts off and chances use the base formula."] =
	"每一级Working Overtime为黄色和绿色配方的技能提升几率增加估算的4个百分点。游戏是以百分点加上天赋加成还是以其倍乘几率尚未确认，因此默认关闭，几率使用基础公式。" -- mt
L["Chance of finishing with later purchases: %s."] = "后续继续购买时的完成几率：%s。" -- mt
L["Chance of finishing with starting supplies: %s."] = "仅用起始物资的完成几率：%s。" -- mt
L["Craft counts and shopping quantities are estimates. You may need more reagents."] =
	"制作次数和采购数量均为估算。你可能需要更多材料。" -- mt
L["Craft next follows the estimated route."] = "「制造下一个」会遵循预计路线。" -- mt
L["Include Working Overtime estimate"] = "计入Working Overtime估算" -- mt
L["Starting inventory: bags and bank."] = "起始库存：背包和银行。" -- mt
L["Starting inventory: bags only."] = "起始库存：仅背包。" -- mt
L["Supply estimate: calculating."] = "物资估算：正在计算。" -- mt
L["Supply estimate: cancelled."] = "物资估算：已取消。" -- mt
L["Supply estimate: no cheapest purchase exists under these assumptions."] =
	"物资估算：在这些假设下，不存在费用最低的采购方案。" -- mt
L["Supply estimate: no starting purchase meets the target."] =
	"物资估算：没有起始采购方案能达到目标。" -- mt
L["Supply estimate: not enough information."] = "物资估算：信息不足。" -- mt
L["Supply estimate: ready."] = "物资估算：已就绪。" -- mt
L["Target chance of finishing with starting supplies: %s%%."] = "仅用起始物资完成的目标几率：%s%%。" -- mt
L["These chances assume the stated skill-up rates, prices, availability and delivery of later purchases."] =
	"这些几率以所列技能提升几率、价格、供货情况以及后续采购物资送达为前提。" -- mt
L["unknown"] = "未知" -- mt

L["currency %d"] = "货币 %d" -- mt
L["an unknown payment"] = "一项未知支付" -- mt
L["Name the stock each offer draws on, or give this offer its own stock."] =
	"请命名每项报价所用的库存，或让它使用自己的库存。" -- mt
L["The merchant shows no limit: limit the search to the number you will buy."] =
	"商人没有显示上限：请将搜索限制在你要购买的数量。" -- mt
L["The stock you assume does not match what the merchant shows."] = "你假设的库存与商人显示的不符。" -- mt
L["Enter a starting chance between 1 and 100."] = "请输入 1 到 100 之间的起始几率。" -- mt
L["The merchant sells none of this route's reagents."] = "商人不出售此路线的任何材料。" -- mt
L["The merchant's offer for %s is incomplete."] = "%s 的商人报价不完整。" -- mt
L["Every offer needs its price to stay as shown."] = "每项报价都需要价格保持显示的样子。" -- mt
L["Fill in every value this offer needs."] = "请填写这项报价所需的每个数值。" -- mt
L["The merchant sells fewer purchases at a time than that."] = "商人一次出售的购买次数少于此数。" -- mt
L["Offers that draw on one stock pool need the same stock."] = "共用同一库存的报价需要相同的库存。" -- mt
L["Offers at one vendor need the same trip costs and values."] =
	"同一商人的报价需要相同的行程费用和价值。" -- mt
L["Enter the chance each later purchase arrives, from 0 to 100."] =
	"请输入之后每次购买到达的几率，0 到 100。" -- mt
L["Check that the first purchase arrives for certain at every offer."] =
	"请为每项报价确认第一次购买一定到达。" -- mt
L["One item or payment needs one leftover value."] = "一件物品或一项支付需要一个剩余价值。" -- mt
L["Offers that use one payment need the same value for it."] =
	"使用同一支付的报价需要该支付具有相同价值。" -- mt
L["The merchant changed. Check the form again."] = "商人已更换。请重新检查表单。" -- mt
L["The merchant did not change, but the assumptions did. Check the form again."] =
	"商人没有更换，但假设变了。请重新检查表单。" -- mt
L["The merchant shows this offer sold out."] = "商人显示这项报价已售罄。" -- mt
L["The merchant does not say how much is left."] = "商人没有说明还剩多少。" -- mt
L["The merchant will not sell this offer to you now."] = "商人现在不会向你出售这项报价。" -- mt
L["Choose the unit the stock count is in."] = "请选择库存计数的单位。" -- mt
L["The assumptions were rejected. Fill in every value and check each offer."] =
	"假设被拒绝。请填写每个数值并检查每项报价。" -- mt
L["Open a profession to see its plan and coverage."] = "打开一个专业以查看其计划和覆盖率。" -- mt
L["Plan: %s, %s to %s, %d crafts."] = "计划：%s，%s 到 %s，%d 次制作。" -- mt
L["Unpriced crafts: %d."] = "无价格的制作：%d。" -- mt
L["Your target chance: %s%%."] = "你的目标几率：%s%%。" -- mt
L["Margin over your target: %s points."] = "高于目标的余量：%s 个百分点。" -- mt
L["Below your target by %s points."] = "低于目标 %s 个百分点。" -- mt
L["craft"] = "制作" -- mt
L["buy"] = "购买" -- mt
L["stop"] = "停止" -- mt
L["Next step: %s."] = "下一步：%s。" -- mt
L["Open a profession to set its supply policy."] = "打开一个专业以设置其补给策略。" -- mt
L["This profession has no plan to supply yet."] = "这个专业还没有可补给的计划。" -- mt
L["Open a merchant to set this profession's supply policy."] =
	"打开一个商人以设置这个专业的补给策略。" -- mt
L["Ready to apply these assumptions."] = "可以应用这些假设了。" -- mt
L["no limit"] = "无上限" -- mt
L["Offer %d: %s"] = "报价 %d：%s" -- mt
L["The merchant shows %s in stock, %s per purchase, at most %s purchases."] =
	"商人显示库存 %s，每次购买 %s，最多 %s 次购买。" -- mt
L["Price: %s."] = "价格：%s。" -- mt
L["Also costs %s %s."] = "还需 %s %s。" -- mt
L["I can buy this offer"] = "我可以购买这项报价" -- mt
L["The price stays as shown"] = "价格保持显示的样子" -- mt
L["Stock I assume is left"] = "我假设剩余的库存" -- mt
L["The stock does not run out"] = "库存不会用完" -- mt
L["The stock count is in items, not purchases"] = "库存按物品计算，而不是按购买次数" -- mt
L["This offer keeps its own stock"] = "这项报价保留自己的库存" -- mt
L["Limit the search to the stock I typed"] = "将搜索限制在我输入的库存" -- mt
L["Stock pool name"] = "库存名称" -- mt
L["Purchases allowed per visit"] = "每次拜访允许的购买次数" -- mt
L["First trip cost (copper)"] = "首次行程费用（铜币）" -- mt
L["Later trip cost (copper)"] = "之后行程费用（铜币）" -- mt
L["First trip value to you (copper)"] = "首次行程对你的价值（铜币）" -- mt
L["Later trip value to you (copper)"] = "之后行程对你的价值（铜币）" -- mt
L["Chance each later purchase arrives (%)"] = "之后每次购买到达的几率（%）" -- mt
L["The first purchase arrives for certain"] = "第一次购买一定到达" -- mt
L["I pay even when a purchase does not arrive"] = "购买没有到达时我也付款" -- mt
L["Leftover value of one %s (copper)"] = "一个 %s 的剩余价值（铜币）" -- mt
L["Value of one %s (copper)"] = "一个 %s 的价值（铜币）" -- mt
L["These are your own assumptions. The merchant's window only shows what it shows now."] =
	"这些是你自己的假设。商人窗口只显示它现在显示的内容。" -- mt
L["Chance of finishing with starting supplies (%)"] = "用初始库存完成的几率（%）" -- mt
L["Plan later purchases too"] = "也计划之后的购买" -- mt
L["Cost of an unfinished route (copper)"] = "未完成路线的成本（铜币）" -- mt
L["Applied. The plan and its coverage follow these assumptions."] =
	"已应用。计划和覆盖率遵循这些假设。" -- mt
L["Supply"] = "补给" -- mt

L["Supply policy"] = "补给策略" -- mt
L["Open the profession and a merchant window."] = "请打开专业和商人窗口。" -- mt
L["Apply policy"] = "应用策略" -- mt
L["No trainer of your faction teaches this recipe."] = "你的阵营没有训练师教授这个配方。" -- mt
L["%s (level %d)"] = "%s（等级 %d）" -- mt

L["Highest craft profit"] = "单次制造利润最高" -- mt

L["AHDB"] = "AHDB" -- mt

L["Naowh Forever"] = "Naowh Forever" -- mt

L["AHDB, %s"] = "AHDB, %s" -- mt

L["Naowh Forever, %s"] = "Naowh Forever, %s" -- mt

L["you loot it from creatures, would sell for %s"] = "从生物身上拾取，可售得%s" -- mt

L["you gather it (%s), would sell for %s"] = "自行采集（%s），可售得%s" -- mt

L["Scan the auction house with AHDB, or visit a vendor, to price reagents."] =
	"使用AHDB扫描拍卖行，或拜访商人以获取材料价格。" -- mt

L["Update Naowh Forever's auction data, or visit a vendor, to price reagents."] =
	"更新Naowh Forever的拍卖数据，或拜访商人以获取材料价格。" -- mt

L["Choose Auctionator, TradeSkillMaster, AHDB or Naowh Forever. The chosen price wins; the others fill gaps. Tooltips show the observation's age when known."] =
	"选择Auctionator、TradeSkillMaster、AHDB或Naowh Forever。优先采用所选来源的价格，其他来源补充缺失价格。已知记录时间时，鼠标提示会显示其距今时间。" -- mt

L["Sort recipes in one list, learned first, then unlearned. Highest craft profit includes grey recipes. Default restores categories."] =
	"将配方排在同一列表中，已学会的在前，未学会的在后。单次制造利润排序包含灰色配方。默认恢复分类。" -- mt

L["These reagents have no vendor price. Auction prices need Auctionator, TradeSkillMaster, AHDB or Naowh Forever."] =
	"这些材料没有商人价格。拍卖价需要Auctionator/TradeSkillMaster, AHDB, Naowh Forever。" -- mt
L["Adaptive guidance names the recipe. Select it and choose how many to craft in the profession window."] =
	"自适应指引会给出配方。选中它，然后在专业窗口中选择制作数量。" -- mt
L["Select %s in the recipe list first."] = "请先在配方列表中选择%s。" -- mt

L["Herb and ore node tooltips show the skill they need in every client language."] =
	"草药和矿脉的鼠标提示会以客户端的所有语言显示所需技能等级。" -- mt
