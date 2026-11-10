-- Machine translated (2026-10-16); corrections welcome: https://github.com/cjber/skillup-forever/issues/new?template=translation.yml
local _, ns = ...
if GetLocale() ~= "koKR" then
	return
end
local L = ns.L

L["%d %s"] = "%d %s"
L["%d crafts to %d, %s"] = "%d회 제작, %d까지, %s"
L["%d crafts to %d, %s, at %s"] = "%d회 제작, %d까지, %s, 장소: %s"
L["%d more"] = "%d개 더"
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
L["%s, %d/%d"] = "%s, %d/%d"
L["%s, %s, to %d"] = "%s, %s, %d까지"
L["%s, source unknown"] = "%s, 출처 알 수 없음"
L["%s: %d moved, %d confirmed at a trainer, %d wrong."] = "%s: 이동 %d, 전문가에서 확인 %d, 틀림 %d."
L["+%d more"] = "+%d개 더"
L["/su skipped lists the recipes you skipped, with their IDs."] =
	"/su skipped: 건너뛴 제조법을 ID와 함께 보여줍니다."
L["/su unskip <recipe ID> shows one again, /su unskip all every one."] =
	"/su unskip <recipe ID>는 하나를, /su unskip all은 모두 다시 보여줍니다."
L["A Reagents tab on a merchant's window that lists the reagents your tracked routes still need from that merchant and their total cost. Buy them from the merchant's own window."] =
	"상인 창에 재료 탭을 추가해 추적 중인 경로가 이 상인에게서 아직 필요한 재료와 총 비용을 보여 줍니다. 구매는 상인 창에서 직접 하세요."
L["A material your professions gather costs what selling it would bring instead of nothing: its auction price after the 5% cut, or its vendor sell price if that is more. Used for the route and the costs on recipe rows. Auction prices need Auctionator or TradeSkillMaster."] =
	"전문 기술로 채집하는 재료의 비용을 0 대신 판매 시 얻을 금액으로 계산합니다: 5% 수수료를 뺀 경매 가격, 또는 그보다 높으면 상점 판매 가격. 경로와 제조법 행의 비용에 쓰입니다. 경매 가격은 Auctionator/TradeSkillMaster가 필요합니다."
L["Keeps the shared Forever tracker where you put it. The grip at its top no longer drags it."] =
	"공유 Forever 추적기를 놓은 자리에 유지합니다. 위쪽 손잡이로 더 이상 끌 수 없습니다."
L["Lock the tracker"] = "추적기 잠금"
L["Tracker background"] = "추적기 배경"

L["AH"] = "경매장"
L["Add the start of each recipe's difficulty range. This is separate from the skill needed to learn it."] =
	"각 제조법의 난이도 구간 시작점을 표시합니다. 배우는 데 필요한 숙련도와는 별개입니다."
L["Addon"] = "애드온"
L["Adventure Guide Forever can plan this quest chain."] =
	"Adventure Guide Forever로 이 연계 퀘스트를 계획할 수 있습니다."
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
L["Attach to quest tracker"] = "퀘스트 추적기에 붙이기"
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
L["Copy link"] = "링크 복사"
L["Copy the address, then open it in your browser."] = "주소를 복사한 후 브라우저에서 여십시오."
L["Cost"] = "비용"
L["Count what crafts sell for"] = "제작품 판매 가격 반영"
L["Craft %d %s"] = "%d개 제작: %s"
L["Craft %d of %d× %s"] = "제작 %d / %d× %s"
L["Craft %d× %s"] = "제작 %d× %s"
L["Craft %s"] = "%s 제작"
L["Craft next"] = "다음 제작"
L["Crafted gear"] = "제작 장비"
L["Crafts"] = "제작 횟수"
L["Don't count it"] = "반영 안 함"
L["Don't suggest this again"] = "다시 제안하지 않기"
L["Drag to move"] = "끌어서 이동"
L["Dropped by"] = "획득처"
L["Each"] = "개당"
L["Each click puts the next one in the search box; press Search."] =
	"클릭할 때마다 다음 재료가 검색창에 들어갑니다. 검색을 누르세요."
L["Enable Shortest Path Forever for walked routes and boat times."] =
	"도보 경로와 배 시간을 보려면 Shortest Path Forever를 켜세요."
L["Every recipe that uses it"] = "이 재료를 쓰는 모든 제조법"
L["Fee"] = "수수료"
L["Fee %s, requires %s (%d)"] = "수수료 %s, 요구 사항: %s (%d)"
L["Feet"] = "발"
L["Finger"] = "손가락"
L["First used at"] = "처음 쓰이는 숙련도"
L["Forever addons"] = "Forever 애드온"
L["Forever tracker"] = "Forever 추적기"
L["Gather %d %s"] = "%d개 채집: %s"
L["Gathering skill on nodes"] = "채집물의 채집 숙련도"
L["Hands"] = "손"
L["Have (bags and bank)"] = "보유 (가방과 은행)"
L["Head"] = "머리"
L["Herb and ore node tooltips show the skill they need and its colour at yours (English client only). Skinnable corpses show ? until the skinning rule is confirmed on Forever."] =
	"약초와 광맥 툴팁에 필요한 숙련도와 내 숙련도 기준 색상을 표시합니다 (영어 클라이언트 전용). 무두질 가능한 시체는 Forever에서 무두질 규칙이 확인될 때까지 ?로 표시됩니다."
L["Hide this section"] = "이 섹션 숨기기"
L["Install AtlasLoot to see the recipes vendors, quests and drops would add."] =
	"상인, 퀘스트, 전리품으로 얻을 제조법을 보려면 AtlasLoot를 설치하세요."
L["Install Questie and AtlasLoot to see where recipes, vendors and trainers are."] =
	"제조법, 상인, 전문가의 위치를 보려면 Questie와 AtlasLoot를 설치하세요."
L["Install Questie to see vendors, quests and trainers, with waypoints to them."] =
	"상인, 퀘스트, 전문가와 그 웨이포인트를 보려면 Questie를 설치하세요."
L["Installed, turned off"] = "설치됨, 사용 안 함"
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
L["Not installed"] = "설치 안 됨"
L["Not this recipe"] = "이 제조법 제외"
L["Nothing priced you know skills up past %d."] =
	"아는 제조법 중 가격이 있는 것으로는 %d 이상 숙련도가 오르지 않습니다."
L["Nothing to buy for this route."] = "이 경로에 구매할 것이 없습니다."
L["Nothing to craft on this route."] = "이 경로에 제작할 것이 없습니다."
L["Nothing you know skills up past %d."] = "아는 제조법으로는 %d 이상 숙련도가 오르지 않습니다."
L["Off hand"] = "보조장비"
L["On"] = "켬"
L["On %s"] = "%s에서"
L["One line in chat the first time a new version loads."] =
	"새 버전을 처음 불러올 때 대화창에 한 줄 표시합니다."
L["Open"] = "열기"
L["Open %s to craft from here."] = "여기서 제작하려면 %s을(를) 여세요."
L["Open recipe"] = "제조법 열기"
L["Orange, yellow, green and grey thresholds when hovering a recipe."] =
	"제조법에 마우스를 올리면 주황, 노랑, 초록, 회색 구간을 표시합니다."
L["Per craft"] = "제작당"
L["Per skill-up"] = "숙련도 1당"
L["Per skill-up is the cost of one skill point. Per craft is what one craft costs or earns, shown on recipes that no longer give skill too."] =
	"숙련도당은 숙련도 1점을 올리는 비용입니다. 제작당은 한 번 제작할 때 드는 비용이나 수익이며, 더 이상 숙련도가 오르지 않는 제조법에도 표시됩니다."
L["Picks quests for your level and plans them into one journey."] =
	"레벨에 맞는 퀘스트를 골라 하나의 여정으로 계획합니다."
L["Plans the cheapest route to your next profession rank."] =
	"다음 전문 기술 등급까지 가장 저렴한 경로를 계획합니다."
L["Plans the quickest way anywhere and guides you there, with live boat and zeppelin times."] =
	"어디든 가장 빠른 길을 계획해 안내하며, 배와 비행선 시간을 실시간으로 보여줍니다."
L["Price"] = "가격"
L["Price %s, requires %s (%d)"] = "가격 %s, 요구 사항: %s (%d)"
L["Prices"] = "가격"
L["Profession reagents"] = "전문 기술 재료"
L["Profit per craft"] = "제작당 이익"
L["Profit per skill-up"] = "숙련도 1당 이익"
L["Quest"] = "퀘스트"
L["Quest automation, rare alerts and merchant handling for the default UI."] =
	"기본 UI용 퀘스트 자동화, 희귀 몬스터 알림, 상인 거래 처리."
L["Quest giver"] = "퀘스트 NPC"
L["Quest, requires %s (%d)"] = "퀘스트, 요구 사항: %s (%d)"
L["Raises your skill cap to %d."] = "최대 숙련도를 %d(으)로 올립니다."
L["Ranged"] = "원거리 장비"
L["Read %s at %d"] = "%s 읽기 (%d)"
L["Read %s at %d (level %d)"] = "%s 읽기 (%d, 레벨 %d)"
L["Read %s first: you're at your cap."] = "먼저 %s을(를) 읽으세요: 숙련도가 최대입니다."
L["Reagent cost divided by skill-up chance, on recipe rows and in the tooltip. Common vendor reagents are priced from the start and updated at merchants you visit, reagents you gather are free unless you value them under Prices, and auction prices need Auctionator or TradeSkillMaster."] =
	"재료 비용을 숙련도 상승 확률로 나눈 값을 제조법 행과 툴팁에 표시합니다. 흔한 상점 재료는 처음부터 가격이 있고 방문한 상인에서 갱신됩니다. 채집하는 재료는 가격 설정에서 값을 매기지 않으면 무료이며, 경매 가격은 Auctionator/TradeSkillMaster가 필요합니다."
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
L["Route"] = "경로"
L["Route and trainer"] = "경로와 전문가"
L["Route incomplete: %d recipes left out, their reagents not priced yet."] =
	"경로 미완성: 제조법 %d개 제외됨, 재료 가격이 아직 없습니다."
L["Route needs"] = "경로 필요량"
L["Route: %d/%d · %s to %d"] = "경로: %d/%d · %s → %d"
L["Scan the auction house with Auctionator, or visit a vendor, to price reagents."] =
	"재료 가격을 알려면 Auctionator로 경매장을 검색하거나 상인을 방문하세요."
L["Scroll"] = "제조법"
L["Search"] = "검색"
L["Search reagents at the auction house"] = "경매장에서 재료 검색"
L["Sells for"] = "판매 가격"
L["Sells for x%g"] = "판매 가격 x%g"
L["Set waypoint"] = "웨이포인트 설정"
L["Shift-click to link the scroll."] = "Shift-클릭으로 제조법을 링크합니다."
L["Shift: used in %d of your recipes"] = "Shift: 내 제조법 %d개에 사용"
L["Shoulder"] = "어깨"
L["Show a quiet line where one of my other Forever addons would help. Only for addons you don't have."] =
	"제 다른 Forever 애드온이 도움이 될 만한 곳에 조용히 한 줄을 표시합니다. 설치하지 않은 애드온만 해당됩니다."
L["Show again: %s"] = "다시 표시: %s"
L["Show cost per skill-up"] = "숙련도 1당 비용 표시"
L["Show gear I cannot make yet"] = "아직 만들 수 없는 장비도 표시"
L["Show profession routes in the objective tracker. Hiding them keeps your tracked professions and targets."] =
	"목표 추적기에 전문 기술 경로를 표시합니다. 숨겨도 추적 중인 전문 기술과 목표는 유지됩니다."
L["Show skill on recipe rows"] = "제조법 행에 숙련도 표시"
L["Show skill range start on rows"] = "행에 구간 시작점 표시"
L["Show the merchant Reagents tab"] = "상인 재료 탭 표시"
L["Show the crafted gear tab"] = "제작 장비 탭 표시"
L["Show the levelling route tab"] = "숙련도 경로 탭 표시"
L["Show thresholds tooltip"] = "구간 툴팁 표시"
L["Show tracked professions"] = "추적 중인 전문 기술 표시"
L["Shows the Legacy challenges you can advance in each zone."] =
	"각 지역에서 진행할 수 있는 유산 도전을 보여줍니다."
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
L["Sort recipes in one list, learned first, then unlearned. Default restores categories."] =
	'제조법을 한 목록으로 정렬합니다. 배운 것 먼저, 그다음 배우지 않은 것. "기본"은 분류를 되돌립니다.'
L["Source"] = "출처"
L["Source unknown"] = "출처 알 수 없음"
L["Stop tracking"] = "추적 해제"
L["Subtract what the crafted item sells for from its cost. Auction prices need Auctionator or TradeSkillMaster, are after the 5% cut, and may not sell."] =
	"제작 아이템의 판매 가격을 비용에서 뺍니다. 경매 가격은 Auctionator/TradeSkillMaster가 필요하고, 5% 수수료를 뺀 값이며, 팔리지 않을 수도 있습니다."
L["Suggest my other Forever addons"] = "제 다른 Forever 애드온 추천"
L["Taught by %s trainers."] = "%s 기술 전문가가 가르칩니다."
L["The Forever addons are free, with nothing locked behind them. If they help, you can buy me a coffee."] =
	"Forever 애드온은 무료이며 잠긴 기능이 없습니다. 도움이 되셨다면 커피 한 잔 사 주세요." -- mt
L["The place this recipe is taught isn't known yet."] =
	"이 제조법을 배우는 곳은 아직 알려지지 않았습니다."
L["The recipe list grows to the longest recipe name in the open profession, and the window with it, up to the room your screen has. Turn it off to keep the window's own width."] =
	"열린 전문 기술에서 가장 긴 제조법 이름에 맞춰 제조법 목록과 창이 넓어지며, 화면 크기까지만 넓어집니다. 끄면 창의 원래 너비를 유지합니다."
L["The rest comes from a vendor or your gathering."] = "나머지는 상인이나 채집으로 얻습니다."
L["The route asks for %d to reach %d in 9 runs of 10; a worse run needs more."] =
	"경로는 %d개로 10번 중 9번은 %d에 도달한다고 봅니다. 운이 나쁘면 더 필요합니다."
L["The source of this recipe isn't known."] = "이 제조법의 출처는 알려지지 않았습니다."
L["The text is selected. Press Ctrl+C (Cmd+C on a Mac) to copy it, then paste it into your bug report."] =
	"텍스트가 선택되었습니다. Ctrl+C(Mac은 Cmd+C)로 복사한 뒤 버그 보고서에 붙여 넣으세요."
L["The tracker is locked. Turn off Lock the tracker to move it."] =
	"추적기가 잠겨 있습니다. 추적기 잠금을 끄면 이동할 수 있습니다."
L["These reagents have no vendor price. Auction prices need Auctionator or TradeSkillMaster."] =
	"이 재료들은 상점 가격이 없습니다. 경매 가격은 Auctionator/TradeSkillMaster가 필요합니다."
L["This addon"] = "이 애드온"
L["To buy"] = "구매할 금액"
L["Tool"] = "도구"
L["Tooltips and sorting"] = "툴팁과 정렬"
L["Total %s"] = "합계 %s"
L["Track"] = "추적"
L["Tracked routes (Shift for all)"] = "추적 중인 경로 (Shift: 전체)"
L["Train %s"] = "%s 배우기"
L["Train %s at %d"] = "%s 배우기 (%d)"
L["Train %s at %d (level %d)"] = "%s 배우기 (%d, 레벨 %d)"
L["Train %s first."] = "먼저 %s을(를) 배우세요."
L["Train %s first: you're at your cap."] = "먼저 %s을(를) 배우세요: 숙련도가 최대입니다."
L["Trinket"] = "장신구"
L["Turn this off to drag the shared Forever tracker anywhere on screen."] =
	"끄면 공유 Forever 추적기를 화면 어디로든 끌 수 있습니다."
L["Update Questie to see vendors, quests and trainers, with waypoints to them."] =
	"상인, 퀘스트, 전문가와 그 웨이포인트를 보려면 Questie를 업데이트하세요."
L["Used in"] = "사용처"
L["Value gathered materials at what they'd sell for"] = "채집한 재료를 판매 가격으로 계산"
L["Vendor"] = "상인"
L["Vendor reagents"] = "상점 재료"
L["Vendor sell price"] = "상점 판매 가격"
L["Visit a vendor to price reagents. Auction prices need Auctionator or TradeSkillMaster."] =
	"재료 가격을 알려면 상인을 방문하세요. 경매 가격은 Auctionator/TradeSkillMaster가 필요합니다."
L["Waist"] = "허리"
L["Waypoint to a trainer"] = "전문가로 웨이포인트"
L["Waypoint to a vendor: %s"] = "상인으로 웨이포인트: %s"
L["Waypoint to the quest giver: %s"] = "퀘스트 NPC로 웨이포인트: %s"
L["What hovering an item says about your professions: how much of it your tracked routes need (hold Shift for every recipe that uses it), every such recipe and its colour, or nothing."] =
	"아이템에 마우스를 올렸을 때 전문 기술 정보를 표시하는 방식: 추적 중인 경로의 필요량 (Shift를 누르면 그 재료를 쓰는 모든 제조법), 해당 제조법 전체와 색상, 또는 표시 안 함."
L["What's new after an update"] = "업데이트 후 새로운 점"
L["Where the tooltip goes when you hover a recipe. Beside the window, it stays clear of the reagents."] =
	"제조법에 마우스를 올렸을 때 툴팁이 나타나는 위치입니다. 창 옆에 두면 재료를 가리지 않습니다."
L["While the auction house is open, the Professions window offers a search for the selected recipe's reagents: as many as the crafts you choose still need after your bags and bank. Auctionator's shopping list carries the quantities; without it, each click puts the next reagent in the search box."] =
	"경매장이 열려 있으면 전문 기술 창에서 선택한 제조법의 재료를 검색할 수 있습니다: 가방과 은행을 뺀 뒤 선택한 제작 횟수에 아직 필요한 만큼입니다. Auctionator 구매 목록이 수량을 담고, 없으면 클릭할 때마다 다음 재료가 검색창에 들어갑니다."
L["Widen the recipe list to fit recipe names"] = "제조법 이름에 맞게 제조법 목록 넓히기"
L["With Shortest Path Forever, a click leads you there."] =
	"Shortest Path Forever가 있으면 클릭 한 번으로 그곳까지 안내합니다."
L["With Shortest Path Forever, this picks the nearest by travel time and leads you there."] =
	"Shortest Path Forever가 있으면 이동 시간 기준으로 가장 가까운 곳을 골라 안내합니다."
L["World drop"] = "무작위 전리품"
L["Wrist"] = "손목"
L["You have it, requires %s (%d)"] = "보유 중, 요구 사항: %s (%d)"
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
L["the objective tracker isn't available, so tracked reagents can't be shown."] =
	"목표 추적기를 쓸 수 없어 추적 재료를 표시할 수 없습니다."
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
L[", "] = ", "
L[", price seen %d days ago"] = ", %d일 전 확인한 가격"
L["/su export - show the trainer requirements this character has seen, to paste into a report"] =
	"/su export - 이 캐릭터가 확인한 전문가 요구 조건을 표시합니다. 보고서에 붙여 넣을 수 있습니다."
L["/su issue - report a bug or request a feature with a ready-made GitHub issue link"] =
	"/su issue - GitHub 이슈 링크가 준비된 상태로 버그를 신고하거나 기능을 요청합니다."
L["/su report - show a report to copy into a bug report"] =
	"/su report - 버그 보고서에 복사할 보고서를 표시합니다."
L[": "] = ": "
L["A buy trip needs Shortest Path Forever."] =
	"구매 경로를 계획하려면 Shortest Path Forever가 필요합니다."
L["Bug"] = "버그"
L["Bug: "] = "버그: "
L["Copy issue link"] = "이슈 링크 복사"
L["Copy list"] = "목록 복사"
L["Copy report"] = "보고서 복사"
L["Feature request"] = "기능 요청"
L["Feature request: "] = "기능 요청: "
L["Gather"] = "채집"
L["Need %d, have %d, missing %d  %s  %s each  %s"] = "필요 %d, 보유 %d, 부족 %d  %s  개당 %s  %s"
L["No tracked profession"] = "추적 중인 전문 기술 없음"
L["Nothing is missing from the shopping list."] = "구매 목록에서 빠진 것이 없습니다."
L["Nothing to buy"] = "구매할 것 없음"
L["Plan buy trip"] = "구매 경로 계획"
L["Report a bug or request a feature"] = "버그 신고 또는 기능 요청"
L["Shopping list"] = "구매 목록"
L["Shortest Path Forever cannot plan the full trip; setting a waypoint to the first vendor."] =
	"Shortest Path Forever가 전체 경로를 계획할 수 없습니다. 첫 상인으로 웨이포인트를 설정합니다."
L["Shortest Path Forever is needed to plan this trip."] =
	"이 경로를 계획하려면 Shortest Path Forever가 필요합니다."
L["SkillUp Forever shopping list"] = "SkillUp Forever 구매 목록"
L["The link is selected. Press Ctrl+C (Cmd+C on a Mac), then paste into a browser; GitHub opens a filled-in issue."] =
	"링크가 선택되었습니다. Ctrl+C(Mac은 Cmd+C)로 복사한 뒤 브라우저에 붙여 넣으십시오. GitHub에서 내용이 채워진 이슈가 열립니다."
L["The text is selected. Press Ctrl+C (Cmd+C on a Mac) to copy it."] =
	"텍스트가 선택되었습니다. Ctrl+C(Mac은 Cmd+C)로 복사하십시오."
L["Title"] = "제목"
L["Total for priced items: "] = "가격이 있는 아이템 합계: "
L["Unknown"] = "알 수 없음"
L["What happened, or what you would like"] = "무슨 일이 있었는지 또는 원하는 점"
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
L["/su share on|off - control sharing with guild and group"] =
	"/su share on|off - 길드 및 파티와의 공유 설정"
L["Share observed recipe totals with guild and group"] = "관찰한 제조법 합계를 길드 및 파티와 공유"
L["(you)"] = "(나)"
L["All time"] = "전체 기간"
L["Forever Leaderboards"] = "Forever Leaderboards"
L["Forever standing"] = "Forever 종합 순위"
L["Forever: %s overall"] = "Forever: 종합 %s"
L["Forever: %s overall this week"] = "Forever: 이번 주 종합 %s"
L["No one has reported yet."] = "아직 아무도 보고하지 않았습니다."
L["Others' values are player-reported."] = "다른 플레이어의 값은 플레이어가 보고한 것입니다."
L["Overall"] = "종합"
L["Player"] = "플레이어"
L["Points for placing on each addon's board."] = "각 애드온 순위표에 오른 점수입니다."
L["Rank"] = "순위"
L["Recipes observed"] = "관찰한 제작법"
L["Share my progress"] = "내 진행 상황 공유"
L["This week"] = "이번 주"
L["Uses Forever addons"] = "Forever 애드온 사용 중"
L["Your guild and group"] = "내 길드와 파티"
L["Players you've met"] = "만난 플레이어" -- mt
L["boards"] = "순위표"
L["1st"] = "1위"
L["2nd"] = "2위"
L["3rd"] = "3위"
L["4th"] = "4위"
L["5th"] = "5위"
L["6th"] = "6위"
L["7th"] = "7위"
L["8th"] = "8위"
L["board"] = "순위표"
L["/su leaderboard - open Forever Leaderboards on this addon's tab (also /su stats)"] =
	"/su leaderboard - 이 애드온 탭에서 Forever Leaderboards를 엽니다 (/su stats도 가능)"
L["total"] = "합계"
L["On by default. Turn off to stop sending and receiving totals and hide other players. Local observations stay."] =
	"기본적으로 켜져 있습니다. 끄면 합계 송수신이 중단되고 다른 플레이어가 숨겨집니다. 로컬 관찰 기록은 유지됩니다."
L["crafted"] = "제작됨" -- mt
L["List unlearned recipes"] = "배우지 않은 제조법 표시"
L["Adds the recipes of the open profession you have not learned under an Unlearned divider, greyed and marked with a trainer or recipe item and the skill it asks. They cannot be selected or crafted."] =
	"열린 전문 기술에서 배우지 않은 제조법을 '배우지 않음' 구분선 아래에 추가하고, 회색으로 표시하며 교관 또는 제조법과 필요한 숙련도를 함께 보여 줍니다. 선택하거나 제작할 수는 없습니다."
L["Not learned · %s"] = "배우지 않음 · %s"
L["Trainer"] = "전문 기술 교관"
L["Recipe item"] = "제조법"
L["listing unlearned recipes failed: %s"] = "배우지 않은 제조법을 표시하지 못했습니다: %s"
L["Nothing on this route can be gathered, fished or looted by you, so the switch changes nothing for it."] =
	"이 경로에서는 채집하거나 낚시하거나 몬스터에게서 약탈할 수 있는 것이 없어, 이 스위치는 아무것도 바꾸지 않습니다." -- mt
L["On, a reagent you could gather, fish or loot from creatures is priced at a vendor or the auction house. Off, getting it yourself costs nothing."] =
	"켜면 채집하거나 낚시하거나 몬스터에게서 약탈할 수 있는 재료를 상인이나 경매장 가격으로 계산합니다. 끄면 직접 구하는 데 비용이 들지 않습니다." -- mt
L["On, a reagent you could gather, fish or loot from creatures is priced at a vendor or the auction house. Off, getting it yourself costs what it would sell for."] =
	"켜면 채집하거나 낚시하거나 몬스터에게서 약탈할 수 있는 재료를 상인이나 경매장 가격으로 계산합니다. 끄면 직접 구하는 데 판매 가격만큼 듭니다." -- mt
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
L["This route is mostly %s: %d recipes are left out until their reagents are priced."] =
	"이 경로는 대부분 %s입니다: 재료 가격이 책정될 때까지 제조법 %d개가 제외됩니다." -- mt
L["Price self-supplied reagents at auction values"] = "Price self-supplied reagents at auction values" -- mt
L["A reagent you gather, loot or already own costs what selling it would bring - its auction price after the 5% cut, or its vendor sell price if that is more - instead of counting as free. With no market price it stays unpriced rather than free. Auction prices need Auctionator or TradeSkillMaster."] =
	"A reagent you gather, loot or already own costs what selling it would bring - its auction price after the 5% cut, or its vendor sell price if that is more - instead of counting as free. With no market price it stays unpriced rather than free. Auction prices need Auctionator/TradeSkillMaster." -- mt

-- Shared debug log (Forever Core's Core/Log.lua).
L["Debug log is off."] = "디버그 기록이 꺼져 있습니다."
L["Debug log is on for this session."] = "이 세션 동안 디버그 기록이 켜져 있습니다."
L["Debug log is on and pinned for this character."] =
	"이 캐릭터에 대해 디버그 기록이 켜져 있고 고정되어 있습니다."
L["Debug log is already on and pinned for this character."] =
	"이 캐릭터에 대해 디버그 기록이 이미 켜져 있고 고정되어 있습니다."
L["Debug log is off for this session; it is still pinned."] =
	"이 세션 동안 디버그 기록이 꺼져 있지만 여전히 고정되어 있습니다."
L["Debug log is off and unpinned."] = "디버그 기록이 꺼져 있고 고정이 해제되었습니다."
L["No addon has attached its log yet."] = "아직 기록을 첨부한 애드온이 없습니다."
L["%s (last %d):"] = "%s (최근 %d개):"
L["%s: no lines yet."] = "%s: 아직 줄이 없습니다."
L["Usage: /forever debug, /forever debug pin, /forever debug off, /forever debug show"] =
	"사용법: /forever debug, /forever debug pin, /forever debug off, /forever debug show"
L["This menu needs mouse and keyboard."] = "이 메뉴는 마우스와 키보드가 필요합니다."
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
L["The tracker no longer flashes while you hover equippable items."] =
	"장비 가능한 물품 위에 마우스를 올려도 추적기가 더 이상 깜빡이지 않습니다." -- mt
