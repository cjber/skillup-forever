-- Machine translated (2026-10-16); corrections welcome: https://github.com/cjber/skillup-forever/issues/new?template=translation.yml
local _, ns = ...
if GetLocale() ~= "koKR" then
	return
end
local L = ns.L
L["Show money beside each recipe. Turning this off keeps prices in the recipe tooltip."] =
	"각 제조법 옆에 금액을 표시합니다. 끄면 가격은 제조법 툴팁에만 표시됩니다." -- mt
L["Show prices on recipe rows"] = "제조법 줄에 가격 표시" -- mt
L["Show recipe tooltip on hover"] = "마우스를 올리면 제조법 툴팁 표시" -- mt
L["Show the SkillUp tooltip beside the Professions window when hovering a recipe. Turn it off to keep the reagents clear."] =
	"제조법에 마우스를 올리면 전문 기술 창 옆에 SkillUp 툴팁을 표시합니다. 끄면 재료가 가려지지 않습니다." -- mt

L["%d %s"] = "%d %s"
L["%d more"] = "%d개 더"
L["%d of %d"] = "%d / %d"
L["%d reagents have no price"] = "%d개의 재료에 가격이 없습니다"
L["%d to %d"] = "%d~%d"
L["%d, from %d to %d"] = "%d회, %d에서 %d까지"
L["%dd ago"] = "%d일 전"
L["%s %d"] = "%s %d"
L["%s (%d): bundled %d, classic-db %d"] = "%s (%d): 내장 %d, classic-db %d"
L["%s (%d): bundled %s, the trainer wants %d"] = "%s (%d): 내장 %s, 전문가 요구 %d"
L["%s (unlearned)"] = "%s (배우지 않음)"
L["%s is at %s."] = "%s은(는) %s에 있습니다."
L["%s is in %s."] = "%s은(는) %s에 있습니다."
L["%s trainer"] = "%s 기술 전문가"
L["%s until %d"] = "%s (%d까지)"
L["%s, %d"] = "%s, %d"
L["%s, %s, to %d"] = "%s, %s, %d까지"
L["%s, source unknown"] = "%s, 출처 알 수 없음"
L["%s: %d moved, %d confirmed at a trainer, %d wrong."] = "%s: 이동 %d, 전문가에서 확인 %d, 틀림 %d."
L["+%d more"] = "+%d개 더"
L["/skillup skipped lists the recipes you skipped, with their IDs."] =
	"/skillup skipped: 건너뛴 제조법을 ID와 함께 보여줍니다."
L["/skillup unskip <recipe ID> shows one again, /skillup unskip all every one."] =
	"/skillup unskip <recipe ID>는 하나를, /skillup unskip all은 모두 다시 보여줍니다."
L["A Reagents tab on a merchant's window that lists the reagents your tracked routes still need from that merchant and their total cost. Buy them from the merchant's own window."] =
	"상인 창에 재료 탭을 추가해 추적 중인 경로가 이 상인에게서 아직 필요한 재료와 총 비용을 보여 줍니다. 구매는 상인 창에서 직접 하세요."
L["A material your professions gather costs what selling it would bring instead of nothing: its auction price after the 5% cut, or its vendor sell price if that is more. Used for the route and the costs on recipe rows. Auction prices need Auctionator, TradeSkillMaster, AHDB, Naowh Forever or Forever Ledger."] =
	"전문 기술로 채집하는 재료의 비용을 0 대신 판매 시 얻을 금액으로 계산합니다: 5% 수수료를 뺀 경매 가격, 또는 그보다 높으면 상점 판매 가격. 경로와 제조법 행의 비용에 쓰입니다. 경매 가격은 Auctionator/TradeSkillMaster / AHDB / Naowh Forever / Forever Ledger가 필요합니다."
L["Keeps the shared Forever tracker where you put it. The grip at its top no longer drags it."] =
	"공유 Forever 추적기를 놓은 자리에 유지합니다. 위쪽 손잡이로 더 이상 끌 수 없습니다."
L["Lock the tracker"] = "추적기 잠금"

L["AH"] = "경매장"
L["Add the start of each recipe's difficulty range. This is separate from the skill needed to learn it."] =
	"각 제조법의 난이도 구간 시작점을 표시합니다. 배우는 데 필요한 숙련도와는 별개입니다."
L["Addon"] = "애드온"
L["Also for this slot"] = "이 슬롯의 다른 아이템"
L["Annotate trainer recipes"] = "전문가 제조법에 정보 표시"
L["Another craft makes this recipe, not yours."] =
	"이 제조법은 내 전문 기술이 아닌 다른 기술로 만듭니다."
L["Another crafter"] = "다른 제작자"
L["At the %d cap: no trainer teaches the next rank."] =
	"최대 %d: 다음 단계를 가르치는 전문가가 없습니다."
L["At the cursor"] = "커서 위치"
L["AtlasLoot is installed but not running: enable it in the AddOns list, or update it if out of date."] =
	"AtlasLoot가 설치되었지만 실행 중이 아닙니다: 애드온 목록에서 켜거나, 오래된 버전이면 업데이트하세요."
L["Auction house"] = "경매장"
L["Auction price if higher"] = "더 높으면 경매 가격"
L["Auctionator hasn't seen these reagents yet: scan the auction house with it to price them."] =
	"Auctionator가 아직 이 재료들을 보지 못했습니다: 경매장을 검색해 가격을 확인하세요."
L["Auctionator's scan when the auction house opens is off: turn it on in Auctionator, Basic Options."] =
	'경매장을 열 때 Auctionator 검색이 꺼져 있습니다: Auctionator의 "Basic Options"에서 켜세요.'
L["Auctionator, %s"] = "Auctionator, %s"
L["Back"] = "등"
L["Beside the Professions window"] = "전문 기술 창 옆"
L["Buy %d %s"] = "%d개 구매: %s"
L["Buy %s"] = "%s 구매" -- mt
L["Buy %s at %d"] = "%s 구매 (%d)" -- mt
L["Buy all"] = "모두 구매"
L["Buy and read %s at %d"] = "%s 구매 후 읽기 (%d)"
L["Buy and read %s at %d (level %d)"] = "%s 구매 후 읽기 (%d, 레벨 %d)"
L["Buy reagents"] = "재료 구매"
L["Buy reagents at the auction house"] = "경매장에서 재료 구매"
L["Can learn it"] = "배울 수 있음"
L["Cheapest skill-up"] = "가장 저렴한 숙련도 상승"
L["Chest"] = "가슴"
L["Click for a waypoint to %s."] = "클릭하면 %s(으)로 웨이포인트를 설정합니다."
L["Click for a waypoint."] = "클릭하면 웨이포인트를 설정합니다."
L["Click to craft %d."] = "클릭하면 %d개 제작합니다."
L["Click to open the recipe."] = "클릭하면 제조법을 엽니다."
L["Click to show a recipe again."] = "클릭하면 제조법을 다시 표시합니다."
L["Close"] = "닫기"
L["Complete %s at %d"] = "%s 완료 (%d)"
L["Complete %s at %d (level %d)"] = "%s 완료 (%d, 레벨 %d)"
L["Complete %s first: you're at your cap."] = "먼저 %s을(를) 완료하세요: 숙련도가 최대입니다."
L["Cost"] = "비용"
L["Count what crafts sell for"] = "제작품 판매 가격 반영"
L["Craft %d %s"] = "%d개 제작: %s"
L["Craft %d of %d× %s"] = "제작 %d / %d× %s"
L["Craft %d× %s"] = "제작 %d× %s"
L["Craft %s"] = "%s 제작"
L["Craft"] = "제작"
L["Craft next"] = "다음 제작"
L["Crafted gear"] = "제작 장비"
L["Crafts"] = "제작 횟수"
L["Don't count it"] = "반영 안 함"
L["Dropped by"] = "획득처"
L["Each"] = "개당"
L["Every recipe that uses it"] = "이 재료를 쓰는 모든 제조법"
L["Fee"] = "수수료"
L["Fees"] = "수수료"
L["Feet"] = "발"
L["Finger"] = "손가락"
L["First used at"] = "처음 쓰이는 숙련도"
L["Gather %d %s"] = "%d개 채집: %s"
L["Gathering skill on nodes"] = "채집물의 채집 숙련도"
L["Hands"] = "손"
L["Have (bags and bank)"] = "보유 (가방과 은행)"
L["Head"] = "머리"
L["Herb and ore node tooltips show the skill they need and its colour at yours. Skinnable corpses show ? until the skinning rule is confirmed on Forever."] =
	"약초와 광맥 툴팁에 필요한 숙련도와 내 숙련도 기준 색상을 표시합니다. 무두질 가능한 시체는 Forever에서 무두질 규칙이 확인될 때까지 ?로 표시됩니다."
L["Install AtlasLoot to see the recipes vendors, quests and drops would add."] =
	"상인, 퀘스트, 전리품으로 얻을 제조법을 보려면 AtlasLoot를 설치하세요."
L["Install QuestieDB and AtlasLoot to see where recipes, vendors and trainers are."] =
	"제조법, 상인, 전문가의 위치를 보려면 QuestieDB와 AtlasLoot를 설치하세요."
L["Install QuestieDB to see vendors, quests and trainers, with waypoints to them."] =
	"상인, 퀘스트, 전문가와 그 웨이포인트를 보려면 QuestieDB를 설치하세요."
L["Its trainer should teach these at your skill now:"] =
	"지금 숙련도로 전문가에게 다음을 배울 수 있어야 합니다:"
L["Kept in the Auctionator list '%s'."] = "Auctionator 목록 '%s'에 저장되었습니다."
L["Latest Auctionator prices."] = "최신 Auctionator 가격."
L["Latest Auctionator prices: rescan to update old prices."] =
	"최신 Auctionator 가격: 오래된 가격은 다시 검색해 갱신하세요."
L["Learn a crafting profession to plan a route."] = "경로를 계획하려면 제작 전문 기술을 배우세요."
L["Legs"] = "다리"
L["Level %d"] = "레벨 %d"
L["Level %d %s"] = "레벨 %d %s"
L["Made at"] = "제작 장소"
L["Main hand"] = "주장비"
L["Missing reagents for this step."] = "이 단계에 필요한 재료가 부족합니다."
L["Money on recipe rows"] = "제조법 줄의 금액"
L["Nearest trainer"] = "가장 가까운 전문가"
L["Nearest vendor"] = "가장 가까운 상인"
L["Neck"] = "목"
L["Need %d more %s"] = "%d개 더 필요: %s"
L["Need a %s in your bags."] = "가방에 %s이(가) 필요합니다."
L["Needs %s %d"] = "%s %d 필요"
L["Needs %s, sells back %s"] = "%s 필요, %s 회수"
L["Needs %s, sells back %s (incomplete)"] = "%s 필요, %s 회수 (불완전)"
L["Net per craft"] = "제작당 순비용"
L["Newest recipes first"] = "최신 제조법 먼저"
L["Next to the recipe"] = "제조법 옆"
L["No crafted gear for your level and class yet."] = "아직 레벨과 직업에 맞는 제작 장비가 없습니다."
L["No crafted gear you can make yet. Tick the box above to see gear you cannot make."] =
	"아직 만들 수 있는 장비가 없습니다. 만들 수 없는 장비를 보려면 위의 상자를 선택하세요."
L["No skill data for this recipe yet."] = "이 제조법의 숙련도 정보가 아직 없습니다."
L["No trainer teaches this rank: a book does."] = "이 단계는 전문가가 아닌 책으로 배웁니다."
L["No trainer teaches this rank: a quest does."] = "이 단계는 전문가가 아닌 퀘스트로 배웁니다."
L["Not in this route: you chose Not this recipe."] =
	'경로에서 제외됨: "이 제조법 제외"를 선택했습니다.'
L["Not this recipe"] = "이 제조법 제외"
L["Nothing priced you know skills up past %d."] =
	"아는 제조법 중 가격이 있는 것으로는 %d 이상 숙련도가 오르지 않습니다."
L["Nothing to buy for this route."] = "이 경로에 구매할 것이 없습니다."
L["Nothing to craft on this route."] = "이 경로에 제작할 것이 없습니다."
L["Nothing you know skills up past %d."] = "아는 제조법으로는 %d 이상 숙련도가 오르지 않습니다."
L["Off hand"] = "보조장비"
L["On %s"] = "%s에서"
L["One line in chat the first time a new version loads."] =
	"새 버전을 처음 불러올 때 대화창에 한 줄 표시합니다."
L["Open"] = "열기"
L["Open %s to craft from here."] = "여기서 제작하려면 %s을(를) 여세요."
L["Open recipe"] = "제조법 열기"
L["Per craft"] = "제작당"
L["Per skill-up"] = "숙련도 1당"
L["Per skill-up is the cost of one skill point. Per craft is what one craft costs or earns, shown on recipes that no longer give skill too."] =
	"숙련도당은 숙련도 1점을 올리는 비용입니다. 제작당은 한 번 제작할 때 드는 비용이나 수익이며, 더 이상 숙련도가 오르지 않는 제조법에도 표시됩니다."
L["Price"] = "가격"
L["Prices"] = "가격"
L["Profession reagents"] = "전문 기술 재료"
L["Profit per craft"] = "제작당 이익"
L["Profit per skill-up"] = "숙련도 1당 이익"
L["Quest"] = "퀘스트"
L["Quest giver"] = "퀘스트 NPC"
L["Raises your skill cap to %d."] = "최대 숙련도를 %d(으)로 올립니다."
L["Ranged"] = "원거리 장비"
L["Read %s at %d"] = "%s 읽기 (%d)"
L["Read %s at %d (level %d)"] = "%s 읽기 (%d, 레벨 %d)"
L["Read %s first: you're at your cap."] = "먼저 %s을(를) 읽으세요: 숙련도가 최대입니다."
L["Reagent tooltips"] = "재료 툴팁"
L["Reagents"] = "재료"
L["Reagents  (have / need)"] = "재료  (보유 / 필요)"
L["Reagents for"] = "재료:"
L["Reagents in hand"] = "재료 준비됨"
L["Reagents still needed"] = "아직 필요한 재료"
L["Recipe rows"] = "제조법 행"
L["Recipe tooltip position"] = "제조법 툴팁 위치"
L["Recipes from vendors, quests and drops that would carry it on:"] =
	"계속 올리는 데 쓸 수 있는 상인, 퀘스트, 전리품 제조법:"
L["Required skill, skill-up chance and cost on profession trainer recipes, and which one is best to train next for your route."] =
	"기술 전문가 제조법에 요구 숙련도, 숙련도 상승 확률, 비용을 표시하고, 경로상 다음에 배우기 좋은 것을 알려줍니다."
L["Requires"] = "요구 사항"
L["Replan"] = "다시 계획"
L["Route"] = "경로"
L["Route and trainer"] = "경로와 전문가"
L["Route incomplete: %d recipes left out because their costs or sale values are unknown."] =
	"경로 미완성: 비용이나 판매 가치가 알려지지 않아 제조법 %d개가 제외되었습니다."
L["Route needs"] = "경로 필요량"
L["Route: %d/%d · %s to %d"] = "경로: %d/%d · %s → %d"
L["Sales"] = "판매"
L["Scales the shared Forever tracker. 100% matches the game's own tracker."] =
	"공유 Forever 추적기의 크기를 조절합니다. 100%는 게임 추적기와 같습니다."
L["Scan the auction house with Auctionator, or visit a vendor, to price reagents."] =
	"재료 가격을 알려면 Auctionator로 경매장을 검색하거나 상인을 방문하세요."
L["Scroll"] = "제조법"
L["Search"] = "검색"
L["Sells for"] = "판매 가격"
L["Sells for x%g"] = "판매 가격 x%g"
L["Set waypoint"] = "웨이포인트 설정"
L["Shift-click to link the scroll."] = "Shift-클릭으로 제조법을 링크합니다."
L["Shift: used in %d of your recipes"] = "Shift: 내 제조법 %d개에 사용"
L["Shoulder"] = "어깨"
L["Show again: %s"] = "다시 표시: %s"
L["Show gear I cannot make yet"] = "아직 만들 수 없는 장비도 표시"
L["Show profession routes in the objective tracker. Hiding them keeps your tracked professions and targets."] =
	"목표 추적기에 전문 기술 경로를 표시합니다. 숨겨도 추적 중인 전문 기술과 목표는 유지됩니다."
L["Show skill on recipe rows"] = "제조법 행에 숙련도 표시"
L["Show skill range start on rows"] = "행에 구간 시작점 표시"
L["Show the merchant Reagents tab"] = "상인 재료 탭 표시"
L["Show the crafted gear tab"] = "제작 장비 탭 표시"
L["Show the levelling route tab"] = "숙련도 경로 탭 표시"
L["Show tracked professions"] = "추적 중인 전문 기술 표시"
L["Skill  %d/%d     Target"] = "숙련도  %d/%d     목표"
L["Skill points a craft"] = "제작당 숙련도"
L["Skill range start"] = "구간 시작점"
L["Skill range starts at %d"] = "구간 시작: %d"
L["Skill-up chance"] = "숙련도 상승 확률"
L["Skill-up chance and cost per skill-up at the right of each recipe."] =
	"각 제조법 오른쪽에 숙련도 상승 확률과 숙련도 1당 비용을 표시합니다."
L["Skill-up chance: %d%%"] = "숙련도 상승 확률: %d%%"
L["SkillUp report"] = "SkillUp 보고서"
L["Skipped (%d)"] = "건너뜀 (%d)"
L["Skipped (%d):"] = "건너뜀 (%d):"
L["Sold by"] = "판매처"
L["Sort by"] = "정렬 기준"
L["Sort recipes"] = "제조법 정렬"
L["Source"] = "출처"
L["Source unknown"] = "출처 알 수 없음"
L["Stop tracking"] = "추적 해제"
L["Subtract what the crafted item sells for from its cost. Auction prices need Auctionator, TradeSkillMaster, AHDB, Naowh Forever or Forever Ledger, are after the 5% cut, and may not sell."] =
	"제작 아이템의 판매 가격을 비용에서 뺍니다. 경매 가격은 Auctionator/TradeSkillMaster / AHDB / Naowh Forever / Forever Ledger가 필요하고, 5% 수수료를 뺀 값이며, 팔리지 않을 수도 있습니다."
L["Taught by %s trainers."] = "%s 기술 전문가가 가르칩니다."
L["The place this recipe is taught isn't known yet."] =
	"이 제조법을 배우는 곳은 아직 알려지지 않았습니다."
L["The rest comes from a vendor or your gathering."] = "나머지는 상인이나 채집으로 얻습니다."
L["The route asks for %d to reach %d in 9 runs of 10; a worse run needs more."] =
	"경로는 %d개로 10번 중 9번은 %d에 도달한다고 봅니다. 운이 나쁘면 더 필요합니다."
L["The source of this recipe isn't known."] = "이 제조법의 출처는 알려지지 않았습니다."
L["To buy"] = "구매할 금액"
L["Tool"] = "도구"
L["Tooltips and sorting"] = "툴팁과 정렬"
L["Track"] = "추적"
L["Tracker scale"] = "추적기 크기"
L["Train %s"] = "%s 배우기"
L["Train %s at %d"] = "%s 배우기 (%d)"
L["Train %s at %d (level %d)"] = "%s 배우기 (%d, 레벨 %d)"
L["Train %s first."] = "먼저 %s을(를) 배우세요."
L["Train %s first: you're at your cap."] = "먼저 %s을(를) 배우세요: 숙련도가 최대입니다."
L["Trinket"] = "장신구"
L["Update QuestieDB to see vendors, quests and trainers, with waypoints to them."] =
	"상인, 퀘스트, 전문가와 그 웨이포인트를 보려면 QuestieDB를 업데이트하세요."
L["Used in"] = "사용처"
L["Value gathered materials at what they'd sell for"] = "채집한 재료를 판매 가격으로 계산"
L["Vendor"] = "상인"
L["Vendor reagents"] = "상점 재료"
L["Vendor sell price"] = "상점 판매 가격"
L["Visit a vendor to price reagents. Auction prices need Auctionator, TradeSkillMaster, AHDB, Naowh Forever or Forever Ledger."] =
	"재료 가격을 알려면 상인을 방문하세요. 경매 가격은 Auctionator/TradeSkillMaster / AHDB / Naowh Forever / Forever Ledger가 필요합니다."
L["Waist"] = "허리"
L["Waypoint to a trainer"] = "전문가로 웨이포인트"
L["Waypoint to a vendor: %s"] = "상인으로 웨이포인트: %s"
L["Waypoint to the quest giver: %s"] = "퀘스트 NPC로 웨이포인트: %s"
L["What's new after an update"] = "업데이트 후 새로운 점"
L["Where the tooltip goes when you hover a recipe. Beside the window, it stays clear of the reagents."] =
	"제조법에 마우스를 올렸을 때 툴팁이 나타나는 위치입니다. 창 옆에 두면 재료를 가리지 않습니다."
L["World drop"] = "무작위 전리품"
L["Wrist"] = "손목"
L["You have it"] = "보유 중"
L["You have this book: read it."] = "이 책을 가지고 있습니다: 읽으세요."
L["You know it"] = "배움"
L["You: %d"] = "나: %d"
L["Your bags allow %d of the route's %d."] = "가방 공간: %d개 가능 (경로 필요량 %d개)."
L["Your bags and bank have enough."] = "가방과 은행에 충분히 있습니다."
L["can't identify the profession %s (%s); please report it."] =
	"전문 기술 %s (%s)을(를) 식별할 수 없습니다. 제보해 주세요."
L["couldn't add tracked reagents to the objective tracker; please report it."] =
	"추적 재료를 목표 추적기에 추가하지 못했습니다. 제보해 주세요."
L["crafts"] = "회 제작분"
L["drop"] = "전리품"
L["every skipped recipe is back in the route."] = "건너뛴 제조법이 모두 경로에 돌아왔습니다."
L["files are missing: restart the game (not /reload) after updating."] =
	"파일이 없습니다: 업데이트 후 게임을 다시 시작하세요 (/reload 아님)."
L["for %s"] = "%s용"
L["gather"] = "채집"
L["green"] = "초록"
L["grey"] = "회색"
L["item %d"] = "아이템 %d"
L["level %d"] = "레벨 %d"
L["makes %d %s"] = "%d개 생산: %s"
L["no price"] = "가격 없음"
L["no skipped recipes: right-click a step on the route page and choose Not this recipe."] =
	'건너뛴 제조법이 없습니다: 경로 페이지에서 단계를 오른쪽 클릭하고 "이 제조법 제외"를 선택하세요.'
L["no trainer requirements to check."] = "확인할 전문가 요구 사항이 없습니다."
L["none"] = "없음"
L["nothing to search for here: what's missing comes from a vendor or your gathering."] =
	"여기서 검색할 것이 없습니다: 부족한 것은 상인이나 채집으로 얻습니다."
L["open a profession first."] = "먼저 전문 기술 창을 여세요."
L["open the auction house's Buy tab, then search again."] = "경매장의 구매 탭을 연 뒤 다시 검색하세요."
L["orange"] = "주황"
L["over 3 weeks ago"] = "3주 이상 전"
L["profession %d"] = "전문 기술 %d"
L["quest"] = "퀘스트"
L["recipe %d"] = "제조법 %d"
L["route set to %s, %s."] = "%s(으)로 경로 설정, %s."
L["searching for %s: you need %d more."] = "%s 검색 중: %d개 더 필요합니다."
L["sorting failed and has been turned off: %s"] = "정렬에 실패하여 꺼졌습니다: %s"
L["the %s book"] = "%s 책"
L["the %s quest"] = "%s 퀘스트"
L["the reagent names are still loading; search again in a moment."] =
	"재료 이름을 불러오는 중입니다. 잠시 후 다시 검색하세요."
L["today"] = "오늘"
L["tracked, but the objective tracker section isn't attached; please report it."] =
	"추적 중이지만 목표 추적기 항목이 붙어 있지 않습니다. 제보해 주세요."
L["unknown age"] = "시점 알 수 없음"
L["unknown location"] = "위치 알 수 없음"
L["updated to %s. %s"] = "%s(으)로 업데이트됨. %s"
L["vendor"] = "상인"
L["waypoint set to %s, %s."] = "%s(으)로 웨이포인트 설정, %s."
L["world drop"] = "무작위 전리품"
L["yellow"] = "노랑"
L["you gather it (%s)"] = "직접 채집 (%s)"
L["you gather it (%s), valued at its AH price"] = "직접 채집 (%s), 경매장 가격으로 계산"
L["you gather it (%s), valued at its vendor sell price"] = "직접 채집 (%s), 상점 판매 가격으로 계산"
L["your bags and bank already hold the reagents for that many."] =
	"가방과 은행에 그만큼의 재료가 이미 있습니다."
L["No step yet: learn or train a %s recipe that skills up."] =
	"아직 단계가 없습니다: 숙련도가 오르는 %s 제조법을 배우거나 익히세요."
L["Show thresholds bar on the recipe"] = "제조법에 숙련도 기준 막대 표시" -- mt
L["The orange, yellow, green and grey thresholds and where your skill sits, under the recipe in the Professions window. Turn it off if it covers the reagents."] =
	"주황, 노랑, 초록, 회색 기준과 현재 숙련도 위치를 전문 기술 창의 제조법 아래에 표시합니다. 재료를 가리면 끄세요." -- mt
L["%s (%s to %d)"] = "%s (%s %d까지)" -- mt
L["Buying for %s"] = "%s을(를) 위해 구매" -- mt
L["  %d items have no price yet"] = "  %d개 아이템은 아직 가격이 없습니다"
L["%d x %s - %s each"] = "%d x %s - 개당 %s"
L["%d x %s - price unknown"] = "%d x %s - 가격 없음"
L["%s to %d"] = "%s, %d까지"
L[" · "] = " · "
L[", "] = ", "
L[", price seen %d days ago"] = ", %d일 전 확인한 가격"
L["/skillup export - show the trainer requirements this character has seen, to paste into a report"] =
	"/skillup export - 이 캐릭터가 확인한 전문가 요구 조건을 표시합니다. 보고서에 붙여 넣을 수 있습니다."
L["/skillup issue - report a bug or request a feature with a ready-made GitHub issue link"] =
	"/skillup issue - GitHub 이슈 링크가 준비된 상태로 버그를 신고하거나 기능을 요청합니다."
L["/skillup report - show a report to copy into a bug report"] =
	"/skillup report - 버그 보고서에 복사할 보고서를 표시합니다."
L[": "] = ": "
L["A buy trip needs Shortest Path Forever."] =
	"구매 경로를 계획하려면 Shortest Path Forever가 필요합니다."
L["Copy list"] = "목록 복사"
L["Copy shopping list"] = "구매 목록 복사"
L["Gather"] = "채집"
L["Need %d, have %d, missing %d  %s  %s each  %s"] = "필요 %d, 보유 %d, 부족 %d  %s  개당 %s  %s"
L["No tracked profession"] = "추적 중인 전문 기술 없음"
L["Nothing is missing from the shopping list."] = "구매 목록에서 빠진 것이 없습니다."
L["Nothing to buy"] = "구매할 것 없음"
L["Plan buy trip"] = "구매 경로 계획"
L["Plan this route again from today's prices and recipes."] =
	"오늘의 가격과 제작법으로 이 경로를 다시 계획합니다."
L["Shopping list"] = "구매 목록"
L["Shortest Path Forever cannot plan the full trip; setting a waypoint to the first vendor."] =
	"Shortest Path Forever가 전체 경로를 계획할 수 없습니다. 첫 상인으로 웨이포인트를 설정합니다."
L["Shortest Path Forever is needed to plan this trip."] =
	"이 경로를 계획하려면 Shortest Path Forever가 필요합니다."
L["SkillUp Forever shopping list"] = "SkillUp Forever 구매 목록"
L["The text is selected. Press Ctrl+C (Cmd+C on a Mac) to copy it."] =
	"텍스트가 선택되었습니다. Ctrl+C(Mac은 Cmd+C)로 복사하십시오."
L["Total for priced items: "] = "가격이 있는 아이템 합계: "
L["Unknown"] = "알 수 없음"
L["no trainer requirement seen yet: open a profession trainer, then try again."] =
	"아직 확인한 전문가 요구 조건이 없습니다. 전문 기술 전문가를 연 뒤 다시 시도하십시오."
L["on %s"] = "%s 보유"
L["price unknown"] = "가격 없음"
L["Unpin recipe"] = "제조법 고정 해제" -- mt
L["Pin for skill-ups"] = "숙련도 상승에 고정" -- mt
L["Right-click to pin or skip this recipe."] =
	"오른쪽 클릭으로 이 제조법을 고정하거나 제외합니다." -- mt
L["Unpin: %s"] = "고정 해제: %s" -- mt
L["Pinned for skill-ups."] = "숙련도 상승에 고정됨." -- mt
L["Skill range unknown."] = "숙련도 범위를 알 수 없습니다." -- mt
L["Already grey: no skill-ups."] = "이미 회색: 숙련도가 오르지 않습니다." -- mt
L["Requires skill %d."] = "숙련도 %d 필요." -- mt
L["Learn this recipe first."] = "먼저 이 제조법을 배우세요." -- mt
L["Reagents not priced yet."] = "아직 재료 가격이 없습니다." -- mt
L["Outside this route or a newer pin takes priority."] =
	"경로 밖이거나 최근 고정한 제조법이 우선합니다." -- mt
L["Pinned: %s"] = "고정: %s" -- mt
L["The newest pin takes priority where skill ranges overlap."] =
	"숙련도 범위가 겹치면 최근 고정한 제조법이 우선합니다." -- mt
L["Pinned (%d)"] = "고정됨 (%d)" -- mt
L["crafted"] = "제작됨" -- mt
L["List unlearned recipes"] = "배우지 않은 제조법 표시"
L["Adds the recipes of the open profession you have not learned under an Unlearned divider, greyed and marked with a trainer or recipe item and the skill it asks. Click a row to preview the recipe."] =
	"열린 전문 기술에서 배우지 않은 제조법을 '배우지 않음' 구분선 아래에 추가하고, 회색으로 표시하며 교관 또는 제조법과 필요한 숙련도를 함께 보여 줍니다. 항목을 클릭하면 제조법을 미리 볼 수 있습니다."
L["Not learned · %s"] = "배우지 않음 · %s"
L["Trainer"] = "전문 기술 교관"
L["Recipe item"] = "제조법"
L["listing unlearned recipes failed: %s"] = "배우지 않은 제조법을 표시하지 못했습니다: %s"
L["Nothing on this route can be gathered, fished or looted by you, so the switch changes nothing for it."] =
	"이 경로에서는 채집하거나 낚시하거나 몬스터에게서 약탈할 수 있는 것이 없어, 이 스위치는 아무것도 바꾸지 않습니다." -- mt
L["Loot %d %s from creatures"] = "몬스터에게서 %d개 %s 약탈" -- mt
L["you loot it from creatures"] = "몬스터에게서 약탈합니다" -- mt
L["you loot it from creatures, valued at its AH price"] =
	"몬스터에게서 약탈하며 경매 가격으로 계산합니다" -- mt
L["you loot it from creatures, valued at its vendor sell price"] =
	"몬스터에게서 약탈하며 상인 판매 가격으로 계산합니다" -- mt
L["Shift-click crafts all %d."] = "Shift-클릭으로 %d개를 모두 제작합니다." -- mt
L["The game's Craft button is not ready for this recipe."] =
	"게임의 제작 버튼이 이 제조법에 준비되지 않았습니다." -- mt
L["vendor, limited stock"] = "상인, 한정 재고" -- mt
L["Sells %d at a time"] = "한 번에 %d개 판매" -- mt
L["This route is mostly %s: %d recipes are left out until their costs or sale values are known."] =
	"이 경로는 주로 %s을(를) 사용합니다. 비용이나 판매 가치를 알 때까지 제조법 %d개가 제외됩니다."
L["Price self-supplied reagents at auction values"] = "Price self-supplied reagents at auction values" -- mt
L["A reagent you gather, loot or already own costs what selling it would bring - its auction price after the 5% cut, or its vendor sell price if that is more - instead of counting as free. With no market price it stays unpriced rather than free. Auction prices need Auctionator, TradeSkillMaster, AHDB, Naowh Forever or Forever Ledger."] =
	"A reagent you gather, loot or already own costs what selling it would bring - its auction price after the 5% cut, or its vendor sell price if that is more - instead of counting as free. With no market price it stays unpriced rather than free. Auction prices need Auctionator/TradeSkillMaster / AHDB / Naowh Forever / Forever Ledger." -- mt

-- Shared debug log (ForeverCore's Core/Log.lua).
L["Only buffs for your level"] = "내 레벨에 맞는 버프만"
L["Lists only the recipes whose product is a buff you can use at your level: elixirs, flasks, Well Fed food, protection potions, stones, oils and armour kits. Highest required level first. Learned recipes come first, then unlearned ones when those are listed."] =
	"내 레벨에 사용할 수 있는 버프를 만드는 제조법만 표시합니다: 비약, 영약, 잘 먹음 음식, 보호 물약, 연마석, 기름, 방어구 키트. 요구 레벨이 높은 순서입니다. 배운 제조법이 먼저, 배우지 않은 제조법은 해당 목록을 표시할 때 그 뒤에 나옵니다."
L["%s: %s"] = "%s: %s" -- mt
L["%s drops in %s"] = "%s: %s에서 드롭됩니다" -- mt
L["Made by %s %d"] = "%s %d 제작" -- mt
L["Made by %s"] = "%s 제작" -- mt
L["%s at %d"] = "%s, %d" -- mt
L["A tab at the bottom of the Professions window listing the buff consumables this profession makes, by the skill they unlock at and what each one is for. It opens from the SkillUp side tab, beside the route and crafted gear tabs."] =
	"전문 기술 창 하단의 탭으로, 이 전문 기술이 만드는 강화 효과 소모품을 해금 숙련도와 용도별로 보여줍니다. SkillUp 측면 탭에서 경로 및 제작 장비 탭 옆에 열립니다." -- mt
L["A tab at the bottom of the Professions window listing the newest crafted item this character can equip in each slot. It opens from the SkillUp side tab, beside the route and buffs tabs."] =
	"전문 기술 창 하단의 탭으로, 이 캐릭터가 각 슬롯에 착용할 수 있는 가장 최신 제작 아이템을 보여줍니다. SkillUp 측면 탭에서 경로 및 강화 효과 탭 옆에 열립니다." -- mt
L["A tab at the bottom of the Professions window with a route to your target skill and its reagents. It opens from the SkillUp side tab, beside the crafted gear and buffs tabs. Tracked professions stay in the objective tracker either way."] =
	"전문 기술 창 하단의 탭으로, 목표 숙련도와 재료까지의 경로를 보여줍니다. SkillUp 측면 탭에서 제작 장비 및 강화 효과 탭 옆에 열립니다. 추적 중인 전문 기술은 어느 쪽이든 목표 추적기에 남습니다." -- mt
L["Above your level"] = "내 레벨보다 높음" -- mt
L["Buffs"] = "강화 효과" -- mt
L["Known"] = "알려짐" -- mt
L["Later"] = "나중에" -- mt
L["Learn now"] = "지금 배우기" -- mt
L["No buff items for your level yet."] = "아직 내 레벨에 맞는 강화 효과 아이템이 없습니다." -- mt
L["Only for level %d"] = "레벨 %d 전용" -- mt
L["Show the buffs tab"] = "강화 효과 탭 표시" -- mt
L["Show the supply tab"] = "공급 탭 표시" -- mt
L["A tab at the bottom of the Professions window where you set what a merchant will sell and deliver, so the route can plan around it. It opens from the SkillUp side tab, beside the route tab."] =
	"전문 기술 창 하단의 탭으로, 상인이 판매하고 배달할 품목을 정해 경로가 이를 반영하도록 합니다. SkillUp 측면 탭에서 경로 탭 옆에 열립니다." -- mt
L["SkillUp"] = "SkillUp" -- mt
L["This profession makes no buff items."] = "이 전문 기술은 강화 효과 아이템을 만들지 않습니다." -- mt
L["spell %d"] = "주문 %d" -- mt
L["Buffs by %s skill"] = "%s 강화 효과" -- mt
L["Skill  %d/%d"] = "숙련도  %d/%d" -- mt
L["Other crafters"] = "다른 제작자" -- mt
L["No profession here makes buff items."] =
	"여기서 강화 효과 아이템을 만드는 전문 기술이 없습니다." -- mt
L["Latest TradeSkillMaster prices."] = "최신 TradeSkillMaster 가격." -- mt
L["TradeSkillMaster"] = "TradeSkillMaster" -- mt
L["TradeSkillMaster has no price for these reagents: update its AuctionDB with the TSM desktop app."] =
	"TradeSkillMaster에 이 재료의 가격이 없습니다: TSM 데스크톱 앱으로 AuctionDB를 업데이트하세요." -- mt
L["Update TradeSkillMaster's AuctionDB with the TSM desktop app, or visit a vendor, to price reagents."] =
	"TSM 데스크톱 앱으로 TradeSkillMaster의 AuctionDB를 업데이트하거나 상인을 방문하여 재료 가격을 매기세요." -- mt
L["Waiting for Questie to finish loading."] = "Questie 불러오기가 끝나기를 기다리는 중입니다."
L["Nothing is tracked for %s."] = "%s에 대해 추적 중인 항목이 없습니다." -- mt
L["+%d more to train"] = "+%d개 더 배우기" -- mt
L["Also train"] = "추가 학습" -- mt
L["Auctionator list: %s. Open the auction house, Shopping tab, pick it and Search; buy each row with a click."] =
	"Auctionator 목록: %s. 경매장에서 구매 탭을 열고 목록을 선택한 뒤 검색하세요. 각 줄을 클릭하여 구매하세요."
L["On (the default), a reagent you could gather, fish or loot from creatures is bought at a vendor or the auction house. Off, getting it yourself costs nothing."] =
	"켜짐(기본값): 채집, 낚시 또는 생물에게서 얻을 수 있는 재료를 상인이나 경매장에서 삽니다. 꺼짐: 직접 얻는 데 비용이 들지 않습니다."
L["On (the default), a reagent you could gather, fish or loot from creatures is bought at a vendor or the auction house. Off, getting it yourself costs what it would sell for."] =
	"켜짐(기본값): 채집, 낚시 또는 생물에게서 얻을 수 있는 재료를 상인이나 경매장에서 삽니다. 꺼짐: 직접 얻는 비용은 판매 가격만큼 듭니다."
L["Shift + wheel, or drag, scrolls the timeline sideways."] =
	"Shift + 마우스 휠 또는 드래그로 시간선을 옆으로 스크롤합니다."
L["Timeline"] = "시간선"
L["Turning Buy reagents on writes an Auctionator list with every auction reagent still missing."] =
	"재료 구매를 켜면 아직 부족한 모든 경매장 재료가 Auctionator 목록에 기록됩니다."
L["Without Auctionator, a recipe's Search button fills the game's own auction box one reagent at a time."] =
	"Auctionator가 없으면 레시피의 검색 버튼이 게임 자체 경매 검색 상자에 한 번에 하나의 재료를 채웁니다."
L["%s needs ForeverCore. Install it from CurseForge, or choose Reinstall on ForeverCore in the CurseForge app."] =
	"%s에는 ForeverCore가 필요합니다. CurseForge에서 설치하거나 CurseForge 앱에서 ForeverCore의 재설치를 선택하세요." -- mt
L["%s: the installed ForeverCore is another addon (%s). Remove it and install ForeverCore from CurseForge."] =
	"%s: 설치된 ForeverCore는 다른 애드온(%s)입니다. 삭제하고 CurseForge에서 ForeverCore를 설치하세요." -- mt
L["%s: ForeverCore is turned off. Enable it in the AddOns list to fix this."] =
	"%s: ForeverCore가 꺼져 있습니다. 애드온 목록에서 켜서 이 문제를 해결하세요." -- mt
L["%s: %s is out of date. Update it to fix this."] =
	"%s: %s 버전이 오래되었습니다. 문제를 해결하려면 업데이트하세요." -- mt
L["%s: %s are out of date. Update them to fix this."] =
	"%s: %s 버전이 오래되었습니다. 문제를 해결하려면 업데이트하세요." -- mt
L["%s could not start. Reinstall %s to fix this."] =
	"%s을(를) 시작할 수 없습니다. 문제를 해결하려면 %s을(를) 다시 설치하세요." -- mt
L["Region sale average"] = "지역 평균 판매가"
L["Region sale average if higher"] = "더 높으면 지역 평균 판매가"
L["Region sale averages need TradeSkillMaster and its desktop app. They estimate value from reported regional sales and purchases, with the vendor price as a floor. They do not guarantee a sale."] =
	"지역 평균 판매가에는 TradeSkillMaster와 데스크톱 앱이 필요합니다. 보고된 지역 판매 및 구매 기록으로 가치를 추정하며 상점 판매가보다 낮아지지 않습니다. 판매를 보장하지는 않습니다."

L["Counts include spares for an estimated %d%% chance to finish the whole route."] =
	"수량에는 전체 경로를 완료할 약 %d%% 확률을 위한 여유분이 포함되어 있습니다." -- mt
L["Restock visit cost"] = "재보급 방문 비용" -- mt
L["Not counted"] = "계산하지 않음" -- mt
L["What one trip to buy more reagents is worth, in copper, when a run takes more crafts than planned. It is added to that reagent's purchase price only when it happens. Leave it at zero to count no trip."] =
	"예정보다 많은 제작이 필요할 때 재료를 더 사러 가는 한 번의 방문이 구리로 얼마의 가치가 있는지입니다. 실제로 그럴 때만 해당 재료의 구매 가격에 더해집니다. 0으로 두면 방문 비용을 계산하지 않습니다." -- mt
L["%s (%s)"] = "%s (%s)"
L["%s profit per craft"] = "제작당 %s 이익"
L["%s profit per skill-up"] = "기술 숙련당 %s 이익"
L["Auction price"] = "경매 가격"
L["Auction prices from"] = "경매 가격 출처"
L["Auctionator"] = "Auctionator"

L["Skill %d to %d, %s"] = "숙련도 %d~%d, %s" -- mt
L["Skill %d to %d, %s, at %s"] = "숙련도 %d~%d, %s, %s에서" -- mt
L["%s, uses materials you have"] = "%s, 보유한 재료를 사용합니다" -- mt
L["Unlearned recipe order"] = "배우지 않은 제조법 정렬" -- mt
L["How recipes you have not learned are ordered. Learned recipes keep the selected recipe order."] =
	"아직 배우지 않은 제조법의 정렬 방식입니다. 배운 제조법은 선택한 정렬 방식을 유지합니다." -- mt
L["TSM regional sales per day"] = "TSM 지역 일일 판매량" -- mt
L["Average sold per auction house in your region, reported by TSM."] =
	"TSM이 보고한 해당 지역 경매장당 평균 판매량입니다." -- mt

L["Open %s from your spellbook."] = "주문책에서 %s|1을;를; 여세요."

L["Recipes on Shift"] = "Shift로 조제법 표시" -- mt
L["Show recipes on Shift or always. Off hides reagent details, including route needs."] =
	"Shift를 누를 때 또는 항상 조제법을 표시합니다. 끄면 경로에 필요한 수량을 포함한 재료 세부 정보가 숨겨집니다." -- mt
L["Show route needs on item tooltips"] = "아이템 툴팁에 경로 필요 수량 표시" -- mt
L["Show how much of an item your tracked routes still need. Turn this off to keep recipe details without the route line."] =
	"추적 중인 경로에 아직 필요한 아이템 수량을 표시합니다. 이 설정을 끄면 경로 줄 없이 조제법 세부 정보를 볼 수 있습니다." -- mt

L["Have (bags only)"] = "보유 (가방만)" -- mt

L["%s%% to %s%%"] = "%s%%에서 %s%%까지" -- mt
L["Adds an estimated 4 percentage points per Working Overtime rank to yellow and green skill-up chances. Whether the game adds the talent's bonus as points or multiplies the chance by it is not confirmed yet, so this starts off and chances use the base formula."] =
	"Working Overtime 등급마다 노란색 및 녹색 제조법의 숙련도 상승 확률에 추정치 4퍼센트포인트를 더합니다. 게임이 특성 보너스를 포인트로 더하는지 확률에 곱하는지 아직 확인되지 않아 기본으로 꺼져 있으며, 확률은 기본 공식을 사용합니다." -- mt
L["Chance of finishing with later purchases: %s."] = "추가 구매 시 완료 확률: %s." -- mt
L["Chance of finishing with starting supplies: %s."] = "시작 재료로 완료할 확률: %s." -- mt
L["Craft counts and shopping quantities are estimates. You may need more reagents."] =
	"제작 횟수와 구매 수량은 추정치입니다. 재료가 더 필요할 수 있습니다." -- mt
L["Craft next follows the estimated route."] = "다음 제작은 예상 경로를 따릅니다." -- mt
L["Include Working Overtime estimate"] = "Working Overtime 추정치 포함" -- mt
L["Starting inventory: bags and bank."] = "시작 보유량: 가방과 은행." -- mt
L["Starting inventory: bags only."] = "시작 보유량: 가방만." -- mt
L["Supply estimate: calculating."] = "재료 추정: 계산 중." -- mt
L["Supply estimate: cancelled."] = "재료 추정: 취소됨." -- mt
L["Supply estimate: no cheapest purchase exists under these assumptions."] =
	"재료 추정: 이 가정에서는 최저 비용 구매가 존재하지 않습니다." -- mt
L["Supply estimate: no starting purchase meets the target."] =
	"재료 추정: 목표를 충족하는 시작 구매가 없습니다." -- mt
L["Supply estimate: not enough information."] = "재료 추정: 정보가 부족합니다." -- mt
L["Supply estimate: ready."] = "재료 추정: 준비됨." -- mt
L["Target chance of finishing with starting supplies: %s%%."] = "시작 재료로 완료할 목표 확률: %s%%." -- mt
L["These chances assume the stated skill-up rates, prices, availability and delivery of later purchases."] =
	"이 확률은 명시된 숙련도 상승률, 가격, 구매 가능 여부 및 추가 구매분의 인도를 가정합니다." -- mt
L["unknown"] = "알 수 없음" -- mt

L["currency %d"] = "화폐 %d" -- mt
L["an unknown payment"] = "알 수 없는 지불" -- mt
L["Name the stock each offer draws on, or give this offer its own stock."] =
	"각 상품이 어느 재고에서 나오는지 이름을 적거나, 이 상품만의 재고를 지정하세요." -- mt
L["The merchant shows no limit: limit the search to the number you will buy."] =
	"상인은 한도를 표시하지 않습니다: 구매할 수량으로 검색을 제한하세요." -- mt
L["The stock you assume does not match what the merchant shows."] =
	"가정한 재고가 상인이 표시한 것과 맞지 않습니다." -- mt
L["Enter a starting chance between 1 and 100."] = "시작 확률을 1에서 100 사이로 입력하세요." -- mt
L["The merchant sells none of this route's reagents."] = "이 상인은 이 경로의 재료를 팔지 않습니다." -- mt
L["The merchant's offer for %s is incomplete."] = "%s의 상인 상품 정보가 불완전합니다." -- mt
L["Every offer needs its price to stay as shown."] = "모든 상품은 표시된 가격이 유지되어야 합니다." -- mt
L["Fill in every value this offer needs."] = "이 상품에 필요한 값을 모두 입력하세요." -- mt
L["The merchant sells fewer purchases at a time than that."] = "상인은 한 번에 그보다 적게 판매합니다." -- mt
L["Offers that draw on one stock pool need the same stock."] =
	"같은 재고를 쓰는 상품은 같은 재고가 필요합니다." -- mt
L["Offers at one vendor need the same trip costs and values."] =
	"같은 상인의 상품은 같은 이동 비용과 가치가 필요합니다." -- mt
L["Enter the chance each later purchase arrives, from 0 to 100."] =
	"이후 각 구매가 도착할 확률을 0에서 100 사이로 입력하세요." -- mt
L["Check that the first purchase arrives for certain at every offer."] =
	"모든 상품에서 첫 구매가 확실히 도착하는지 확인하세요." -- mt
L["One item or payment needs one leftover value."] =
	"물품이나 지불에는 하나의 잔여 가치가 필요합니다." -- mt
L["Offers that use one payment need the same value for it."] =
	"같은 지불을 쓰는 상품은 그 지불에 같은 가치가 필요합니다." -- mt
L["The merchant changed. Check the form again."] = "상인이 바뀌었습니다. 양식을 다시 확인하세요." -- mt
L["The merchant did not change, but the assumptions did. Check the form again."] =
	"상인은 그대로지만 가정이 바뀌었습니다. 양식을 다시 확인하세요." -- mt
L["The merchant shows this offer sold out."] = "상인은 이 상품을 매진으로 표시합니다." -- mt
L["The merchant does not say how much is left."] = "상인은 얼마나 남았는지 알려주지 않습니다." -- mt
L["The merchant will not sell this offer to you now."] = "상인은 지금 이 상품을 팔지 않습니다." -- mt
L["Choose the unit the stock count is in."] = "재고 수량의 단위를 선택하세요." -- mt
L["The assumptions were rejected. Fill in every value and check each offer."] =
	"가정이 거부되었습니다. 모든 값을 입력하고 각 상품을 확인하세요." -- mt
L["Open a profession to see its plan and coverage."] = "계획과 적용 범위를 보려면 전문기술을 여세요." -- mt
L["Plan: %s, %s to %s, %d crafts."] = "계획: %s, %s에서 %s까지, 제작 %d회." -- mt
L["Unpriced crafts: %d."] = "가격 없는 제작: %d." -- mt
L["Your target chance: %s%%."] = "목표 확률: %s%%." -- mt
L["Margin over your target: %s points."] = "목표보다 높은 여유: %s포인트." -- mt
L["Below your target by %s points."] = "목표보다 %s포인트 낮음." -- mt
L["craft"] = "제작" -- mt
L["buy"] = "구매" -- mt
L["stop"] = "중지" -- mt
L["Next step: %s."] = "다음 단계: %s." -- mt
L["Open a profession to set its supply policy."] = "공급 정책을 정하려면 전문기술을 여세요." -- mt
L["This profession has no plan to supply yet."] = "이 전문기술에는 아직 공급할 계획이 없습니다." -- mt
L["Open a merchant to set this profession's supply policy."] =
	"이 전문기술의 공급 정책을 정하려면 상인을 여세요." -- mt
L["Ready to apply these assumptions."] = "이 가정을 적용할 준비가 되었습니다." -- mt
L["no limit"] = "한도 없음" -- mt
L["Offer %d: %s"] = "상품 %d: %s" -- mt
L["The merchant shows %s in stock, %s per purchase, at most %s purchases."] =
	"상인은 재고 %s, 구매당 %s, 최대 %s회 구매를 표시합니다." -- mt
L["Price: %s."] = "가격: %s." -- mt
L["Also costs %s %s."] = "추가 비용 %s %s." -- mt
L["I can buy this offer"] = "이 상품을 살 수 있습니다" -- mt
L["The price stays as shown"] = "가격은 표시된 대로 유지됩니다" -- mt
L["Stock I assume is left"] = "남아 있다고 가정하는 재고" -- mt
L["The stock does not run out"] = "재고가 떨어지지 않습니다" -- mt
L["The stock count is in items, not purchases"] = "재고 수량은 구매 횟수가 아니라 물품 기준입니다" -- mt
L["This offer keeps its own stock"] = "이 상품은 자체 재고를 유지합니다" -- mt
L["Limit the search to the stock I typed"] = "입력한 재고로 검색 제한" -- mt
L["Stock pool name"] = "재고 이름" -- mt
L["Purchases allowed per visit"] = "방문당 허용 구매 횟수" -- mt
L["First trip cost (copper)"] = "첫 방문 비용(코퍼)" -- mt
L["Later trip cost (copper)"] = "이후 방문 비용(코퍼)" -- mt
L["First trip value to you (copper)"] = "첫 방문의 가치(코퍼)" -- mt
L["Later trip value to you (copper)"] = "이후 방문의 가치(코퍼)" -- mt
L["Chance each later purchase arrives (%)"] = "이후 각 구매가 도착할 확률 (%)" -- mt
L["The first purchase arrives for certain"] = "첫 구매는 확실히 도착합니다" -- mt
L["I pay even when a purchase does not arrive"] = "구매가 도착하지 않아도 지불합니다" -- mt
L["Leftover value of one %s (copper)"] = "%s 하나의 잔여 가치(코퍼)" -- mt
L["Value of one %s (copper)"] = "%s 하나의 가치(코퍼)" -- mt
L["These are your own assumptions. The merchant's window only shows what it shows now."] =
	"이것은 직접 정한 가정입니다. 상인 창은 지금 보이는 것만 보여줍니다." -- mt
L["Chance of finishing with starting supplies (%)"] = "시작 재고로 완료할 확률 (%)" -- mt
L["Plan later purchases too"] = "이후 구매도 계획" -- mt
L["Cost of an unfinished route (copper)"] = "완료하지 못한 경로의 비용(코퍼)" -- mt
L["Applied. The plan and its coverage follow these assumptions."] =
	"적용했습니다. 계획과 적용 범위는 이 가정을 따릅니다." -- mt
L["Supply"] = "공급" -- mt

L["Supply policy"] = "공급 정책" -- mt
L["Open the profession and a merchant window."] = "전문기술과 상인 창을 여세요." -- mt
L["Apply policy"] = "정책 적용" -- mt
L["No trainer of your faction teaches this recipe."] =
	"당신의 진영에는 이 제조법을 가르치는 전문 기술 교관이 없습니다." -- mt
L["%s (level %d)"] = "%s (레벨 %d)" -- mt

L["Highest craft profit"] = "제작당 최고 이익" -- mt

L["AHDB"] = "AHDB" -- mt

L["Naowh Forever"] = "Naowh Forever" -- mt

L["AHDB, %s"] = "AHDB, %s" -- mt

L["Naowh Forever, %s"] = "Naowh Forever, %s" -- mt

L["Forever Ledger"] = "Forever Ledger" -- mt

L["Forever Ledger, %s"] = "Forever Ledger, %s" -- mt

L["you loot it from creatures, would sell for %s"] = "생물에게서 획득, 판매 예상액 %s" -- mt

L["you gather it (%s), would sell for %s"] = "직접 채집 (%s), 판매 예상액 %s" -- mt

L["Scan the auction house with AHDB, or visit a vendor, to price reagents."] =
	"AHDB로 경매장을 검색하거나 상인을 방문하여 재료 가격을 확인하세요." -- mt

L["Update Naowh Forever's auction data, or visit a vendor, to price reagents."] =
	"Naowh Forever의 경매 데이터를 업데이트하거나 상인을 방문하여 재료 가격을 확인하세요." -- mt

L["Run a full scan in Forever Ledger, or visit a vendor, to price reagents."] =
	"Run a full scan in Forever Ledger, or visit a vendor, to price reagents." -- mt

L["Choose Auctionator, TradeSkillMaster, AHDB, Naowh Forever or Forever Ledger. The chosen price wins; the others fill gaps. Tooltips show the observation's age when known."] =
	"Auctionator, TradeSkillMaster, AHDB, Naowh Forever 또는 Forever Ledger를 선택하세요. 선택한 가격이 우선하며 나머지는 누락된 가격을 채웁니다. 확인된 시점을 알면 툴팁에 표시합니다." -- mt

L["Sort recipes in one list, learned first, then unlearned. Highest craft profit includes grey recipes. Default restores categories."] =
	"배운 도안, 배우지 않은 도안 순으로 한 목록에 정렬합니다. 제작당 최고 이익에는 회색 도안도 포함됩니다. 기본값은 분류를 복원합니다." -- mt

L["These reagents have no vendor price. Auction prices need Auctionator, TradeSkillMaster, AHDB, Naowh Forever or Forever Ledger."] =
	"이 재료들은 상점 가격이 없습니다. 경매 가격은 Auctionator/TradeSkillMaster, AHDB, Naowh Forever, Forever Ledger가 필요합니다." -- mt
L["Adaptive guidance names the recipe. Select it and choose how many to craft in the profession window."] =
	"적응형 안내는 제조법을 알려 줍니다. 제조법을 선택하고 전문 기술 창에서 만들 개수를 정하세요." -- mt
L["Select %s in the recipe list first."] = "먼저 제조법 목록에서 %s|1을;를; 선택하세요." -- mt

L["Forever Ledger prices reagents."] = "Forever Ledger가 재료 가격을 알려줍니다." -- mt
L["Show reagent search"] = "재료 검색 표시"
L["Click Search in the Professions window to find missing reagents. Without Auctionator, each click fills the auction house search box with the next reagent."] =
	"전문 기술 창에서 검색을 눌러 부족한 재료를 찾습니다. Auctionator가 없으면 누를 때마다 경매장 검색창에 다음 재료가 입력됩니다."
L["Keep Auctionator shopping lists"] = "Auctionator 쇼핑 목록 유지"
L["Save lists for tracked routes set to Buy reagents and for recipe searches. Turn this off to stop saving lists and keep using Search."] =
	"재료 구매로 설정된 추적 경로와 재료 검색의 목록을 저장합니다. 끄면 목록 저장이 중단되며 검색은 계속 사용할 수 있습니다."
