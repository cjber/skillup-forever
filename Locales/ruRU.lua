-- Machine translated (2026-10-16); corrections welcome: https://github.com/cjber/skillup-forever/issues/new?template=translation.yml
local _, ns = ...
if GetLocale() ~= "ruRU" then
	return
end
local L = ns.L
L["Show SkillUp tooltip details"] = "Показывать подробности подсказок SkillUp"
L["Show SkillUp profession tabs"] = "Показывать вкладки профессий SkillUp"
L["Adds SkillUp's details to tooltips while preserving each individual tooltip choice."] =
	"Добавляет сведения SkillUp в подсказки, сохраняя отдельные настройки подсказок."
L["Shows the route, gear and buffs tabs while preserving each individual tab choice."] =
	"Показывает вкладки маршрута, экипировки и усилений, сохраняя отдельные настройки вкладок."

L["%d %s"] = "%d %s"
L["%d more"] = "еще %d"
L["%d of %d"] = "%d из %d"
L["%d reagents have no price"] = "У %d реагентов нет цены"
L["%d to %d"] = "%d–%d"
L["%d, from %d to %d"] = "%d, с %d до %d"
L["%dd ago"] = "%d дн. назад"
L["%s %d"] = "%s %d"
L["%s (%d): bundled %d, classic-db %d"] = "%s (%d): в аддоне %d, classic-db %d"
L["%s (%d): bundled %s, the trainer wants %d"] = "%s (%d): в аддоне %s, учитель требует %d"
L["%s (unlearned)"] = "%s (не изучено)"
L["%s is at %s."] = "%s находится здесь: %s."
L["%s is in %s."] = "%s находится в зоне %s."
L["%s trainer"] = "Учитель (%s)"
L["%s until %d"] = "%s до %d"
L["%s, %d"] = "%s, %d"
L["%s, %s, to %d"] = "%s, %s, до %d"
L["%s, source unknown"] = "%s, источник неизвестен"
L["%s: %d moved, %d confirmed at a trainer, %d wrong."] =
	"%s: перемещено %d, подтверждено у учителя %d, неверно %d."
L["+%d more"] = "и еще %d"
L["/skillup skipped lists the recipes you skipped, with their IDs."] =
	"/skillup skipped показывает пропущенные рецепты с их ID."
L["/skillup unskip <recipe ID> shows one again, /skillup unskip all every one."] =
	"/skillup unskip <recipe ID> возвращает один рецепт, /skillup unskip all — все."
L["A Reagents tab on a merchant's window that lists the reagents your tracked routes still need from that merchant and their total cost. Buy them from the merchant's own window."] =
	"Вкладка «Реагенты» в окне торговца со списком реагентов, которые ещё нужны вашим отслеживаемым маршрутам у этого торговца, и их общей стоимостью. Покупайте их в окне торговца."
L["A material your professions gather costs what selling it would bring instead of nothing: its auction price after the 5% cut, or its vendor sell price if that is more. Used for the route and the costs on recipe rows. Auction prices need Auctionator, TradeSkillMaster, AHDB or Naowh Forever."] =
	"Материал, который добывают ваши профессии, стоит столько, сколько принесла бы его продажа, а не ноль: цена на аукционе за вычетом 5% комиссии или цена продажи торговцу, если она выше. Учитывается в маршруте и стоимости в строках рецептов. Для цен аукциона нужен Auctionator/TradeSkillMaster / AHDB / Naowh Forever."
L["Keeps the shared Forever tracker where you put it. The grip at its top no longer drags it."] =
	"Оставляет общий трекер Forever там, где вы его поставили. Ручка сверху больше его не перетаскивает."
L["Lock the tracker"] = "Закрепить трекер"

L["AH"] = "Аук."
L["Add the start of each recipe's difficulty range. This is separate from the skill needed to learn it."] =
	"Показывает начало диапазона сложности каждого рецепта. Это не навык, нужный для изучения."
L["Addon"] = "Модификация"
L["Adventure Guide Forever can plan this quest chain."] =
	"Adventure Guide Forever может спланировать эту цепочку заданий."
L["Also for this slot"] = "Еще для этой ячейки"
L["Annotate trainer recipes"] = "Подсказки к рецептам учителя"
L["Another craft makes this recipe, not yours."] =
	"Этот рецепт создает другая профессия, не ваша."
L["Another crafter"] = "Другой ремесленник"
L["At the %d cap: no trainer teaches the next rank."] =
	"Предел %d: ни один учитель не обучает следующему рангу."
L["At the cursor"] = "У курсора"
L["AtlasLoot is installed but not running: enable it in the AddOns list, or update it if out of date."] =
	"AtlasLoot установлен, но не работает: включите его в списке модификаций или обновите, если он устарел."
L["Attach to quest tracker"] = "Прикрепить к списку заданий"
L["Auction house"] = "Аукционный дом"
L["Auction price if higher"] = "Цена аукциона, если выше"
L["Auctionator hasn't seen these reagents yet: scan the auction house with it to price them."] =
	"Auctionator еще не видел эти реагенты: просканируйте им аукцион, чтобы узнать цены."
L["Auctionator's scan when the auction house opens is off: turn it on in Auctionator, Basic Options."] =
	"Сканирование Auctionator при открытии аукциона выключено: включите его в Auctionator, «Basic Options»."
L["Auctionator, %s"] = "Auctionator, %s"
L["Back"] = "Спина"
L["Beside the Professions window"] = "Рядом с окном профессий"
L["Buy %d %s"] = "Купить %d %s"
L["Buy %s"] = "Купить %s" -- mt
L["Buy %s at %d"] = "Купить %s на %d" -- mt
L["Buy all"] = "Купить всё"
L["Buy and read %s at %d"] = "Купить и прочитать %s на %d"
L["Buy and read %s at %d (level %d)"] = "Купить и прочитать %s на %d (уровень %d)"
L["Buy reagents"] = "Купить реагенты"
L["Buy reagents at the auction house"] = "Купить реагенты на аукционе"
L["Can learn it"] = "Можно изучить"
L["Cheapest skill-up"] = "Самый дешевый рост навыка"
L["Chest"] = "Грудь"
L["Click for a waypoint to %s."] = "Щелкните, чтобы поставить точку маршрута: %s."
L["Click for a waypoint."] = "Щелкните, чтобы поставить точку маршрута."
L["Click to craft %d."] = "Щелкните, чтобы создать %d."
L["Click to open the recipe."] = "Щелкните, чтобы открыть рецепт."
L["Click to show a recipe again."] = "Щелкните, чтобы вернуть рецепт."
L["Close"] = "Закрыть"
L["Complete %s at %d"] = "Выполнить %s на %d"
L["Complete %s at %d (level %d)"] = "Выполнить %s на %d (уровень %d)"
L["Complete %s first: you're at your cap."] =
	"Сначала выполните %s: вы достигли предела."
L["Cost"] = "Стоимость"
L["Count what crafts sell for"] = "Учитывать цену продажи созданного"
L["Craft %d %s"] = "Создать %d %s"
L["Craft %d of %d× %s"] = "Создать %d из %d× %s"
L["Craft %d× %s"] = "Создать %d× %s"
L["Craft %s"] = "Создать %s"
L["Craft"] = "Создать"
L["Craft next"] = "Создать следующее"
L["Crafted gear"] = "Созданное снаряжение"
L["Crafts"] = "Созданий"
L["Don't count it"] = "Не учитывать"
L["Dropped by"] = "Добыча с"
L["Each"] = "За шт."
L["Enable Shortest Path Forever for walked routes and boat times."] =
	"Включите Shortest Path Forever для пеших маршрутов и расписания кораблей."
L["Every recipe that uses it"] = "Все рецепты, где он нужен"
L["Fee"] = "Плата"
L["Fees"] = "Сборы"
L["Feet"] = "Ступни"
L["Finger"] = "Палец"
L["First used at"] = "Впервые нужен на"
L["Forever addons"] = "Модификации Forever"
L["Gather %d %s"] = "Добыть %d %s"
L["Gathering skill on nodes"] = "Навык сбора на месторождениях"
L["Hands"] = "Кисти рук"
L["Have (bags and bank)"] = "Есть (сумки и банк)"
L["Head"] = "Голова"
L["Herb and ore node tooltips show the skill they need and its colour at yours (English client only). Skinnable corpses show ? until the skinning rule is confirmed on Forever."] =
	"Подсказки трав и рудных жил показывают нужный навык и его цвет для вашего (только английский клиент). Для свежуемых трупов показывается ?, пока правило снятия шкур не подтверждено на Forever."
L["Install AtlasLoot to see the recipes vendors, quests and drops would add."] =
	"Установите AtlasLoot, чтобы видеть рецепты от торговцев, заданий и добычи."
L["Install QuestieDB and AtlasLoot to see where recipes, vendors and trainers are."] =
	"Установите QuestieDB и AtlasLoot, чтобы видеть, где рецепты, торговцы и учителя."
L["Install QuestieDB to see vendors, quests and trainers, with waypoints to them."] =
	"Установите QuestieDB, чтобы видеть торговцев, задания и учителей с точками маршрута."
L["Its trainer should teach these at your skill now:"] =
	"Учитель уже должен обучить вас этому при вашем навыке:"
L["Kept in the Auctionator list '%s'."] = "Сохранено в списке Auctionator «%s»."
L["Latest Auctionator prices."] = "Последние цены Auctionator."
L["Latest Auctionator prices: rescan to update old prices."] =
	"Последние цены Auctionator: просканируйте снова, чтобы обновить старые."
L["Learn a crafting profession to plan a route."] =
	"Изучите ремесленную профессию, чтобы спланировать маршрут."
L["Legs"] = "Ноги"
L["Level %d"] = "Уровень %d"
L["Level %d %s"] = "Уровень %d, %s"
L["Made at"] = "Создается у"
L["Main hand"] = "Правая рука"
L["Missing reagents for this step."] = "Для этого шага не хватает реагентов."
L["Money on recipe rows"] = "Деньги в строках рецептов"
L["Nearest trainer"] = "Ближайший учитель"
L["Nearest vendor"] = "Ближайший торговец"
L["Neck"] = "Шея"
L["Need %d more %s"] = "Нужно еще %d %s"
L["Need a %s in your bags."] = "Нужен предмет в сумках: %s."
L["Needs %s %d"] = "Требуется %s %d"
L["Needs %s, sells back %s"] = "Нужно %s, вернёт %s"
L["Needs %s, sells back %s (incomplete)"] = "Нужно %s, вернёт %s (неполно)"
L["Net per craft"] = "Итого за создание"
L["Newest recipes first"] = "Сначала новые рецепты"
L["Next to the recipe"] = "Рядом с рецептом"
L["No crafted gear for your level and class yet."] =
	"Пока нет созданного снаряжения для вашего уровня и класса."
L["No crafted gear you can make yet. Tick the box above to see gear you cannot make."] =
	"Пока нет снаряжения, которое вы можете создать. Отметьте флажок выше, чтобы видеть то, что вы создать не можете."
L["No skill data for this recipe yet."] =
	"Для этого рецепта пока нет данных о навыке."
L["No trainer teaches this rank: a book does."] =
	"Этому рангу обучает не учитель, а книга."
L["No trainer teaches this rank: a quest does."] =
	"Этому рангу обучает не учитель, а задание."
L["Not in this route: you chose Not this recipe."] =
	"Не в маршруте: вы выбрали «Не этот рецепт»."
L["Not this recipe"] = "Не этот рецепт"
L["Nothing priced you know skills up past %d."] =
	"Ничто известное вам с ценой не повышает навык выше %d."
L["Nothing to buy for this route."] = "Для этого маршрута покупать нечего."
L["Nothing to craft on this route."] = "На этом маршруте создавать нечего."
L["Nothing you know skills up past %d."] =
	"Ничто известное вам не повышает навык выше %d."
L["Off hand"] = "Левая рука"
L["On %s"] = "На %s"
L["One line in chat the first time a new version loads."] =
	"Одна строка в чате при первой загрузке новой версии."
L["Open"] = "Открыть"
L["Open %s to craft from here."] = "Откройте %s, чтобы создавать отсюда."
L["Open recipe"] = "Открыть рецепт"
L["Orange, yellow, green and grey thresholds when hovering a recipe."] =
	"Пороги оранжевого, желтого, зеленого и серого цвета при наведении на рецепт."
L["Per craft"] = "За создание"
L["Per skill-up"] = "За очко навыка"
L["Per skill-up is the cost of one skill point. Per craft is what one craft costs or earns, shown on recipes that no longer give skill too."] =
	"За единицу навыка — стоимость одного очка навыка. За создание — сколько стоит или приносит одно создание, в том числе для рецептов, которые больше не повышают навык."
L["Price"] = "Цена"
L["Prices"] = "Цены"
L["Profession reagents"] = "Реагенты профессий"
L["Profit per craft"] = "Прибыль за создание"
L["Profit per skill-up"] = "Прибыль за очко навыка"
L["Quest"] = "Задание"
L["Quest giver"] = "Выдает задание"
L["Raises your skill cap to %d."] = "Повышает предел навыка до %d."
L["Ranged"] = "Дальний бой"
L["Read %s at %d"] = "Прочитать %s на %d"
L["Read %s at %d (level %d)"] = "Прочитать %s на %d (уровень %d)"
L["Read %s first: you're at your cap."] =
	"Сначала прочитайте %s: вы достигли предела."
L["Reagent cost divided by skill-up chance, on recipe rows and in the tooltip. Common vendor reagents are priced from the start and updated at merchants you visit, reagents you gather cost what they would sell for unless you turn that off under Prices, and auction prices need Auctionator, TradeSkillMaster, AHDB or Naowh Forever."] =
	"Стоимость реагентов, деленная на шанс повышения навыка, в строках рецептов и в подсказке. Обычные реагенты торговцев имеют цену сразу и обновляются у посещенных торговцев; добываемые вами реагенты стоят столько, сколько принесёт их продажа, если не отключить это в разделе «Цены»; для цен аукциона нужен Auctionator/TradeSkillMaster / AHDB / Naowh Forever."
L["Reagent tooltips"] = "Подсказки реагентов"
L["Reagents"] = "Реагенты"
L["Reagents  (have / need)"] = "Реагенты  (есть / нужно)"
L["Reagents for"] = "Реагенты для"
L["Reagents in hand"] = "Реагенты собраны"
L["Reagents still needed"] = "Еще нужны реагенты"
L["Recipe rows"] = "Строки рецептов"
L["Recipe tooltip position"] = "Положение подсказки рецепта"
L["Recipes from vendors, quests and drops that would carry it on:"] =
	"Рецепты от торговцев, заданий и добычи, с которыми можно продолжить:"
L["Required skill, skill-up chance and cost on profession trainer recipes, and which one is best to train next for your route."] =
	"Требуемый навык, шанс повышения и стоимость в рецептах учителей профессий, а также какой изучить следующим для вашего маршрута."
L["Requires"] = "Требуется"
L["Replan"] = "Перепланировать"
L["Route"] = "Маршрут"
L["Route and trainer"] = "Маршрут и учитель"
L["Route incomplete: %d recipes left out because their costs or sale values are unknown."] =
	"Маршрут неполный: исключено рецептов: %d. Их затраты или стоимость продажи неизвестны."
L["Route needs"] = "Нужно маршруту"
L["Route: %d/%d · %s to %d"] = "Маршрут: %d/%d • %s до %d"
L["Sales"] = "Продажа"
L["Scales the shared Forever tracker. 100% matches the game's own tracker."] =
	"Меняет размер общей панели отслеживания Forever. 100% – как панель отслеживания игры."
L["Scan the auction house with Auctionator, or visit a vendor, to price reagents."] =
	"Просканируйте аукцион с Auctionator или посетите торговца, чтобы узнать цены реагентов."
L["Scroll"] = "Рецепт"
L["Search"] = "Поиск"
L["Search reagents at the auction house"] = "Искать реагенты на аукционе"
L["Sells for"] = "Продается за"
L["Sells for x%g"] = "Продается за x%g"
L["Set waypoint"] = "Поставить точку маршрута"
L["Shift-click to link the scroll."] = "SHIFT+щелчок — ссылка на рецепт."
L["Shift: used in %d of your recipes"] = "SHIFT: используется в ваших рецептах: %d"
L["Shoulder"] = "Плечо"
L["Show again: %s"] = "Снова показан: %s"
L["Show cost per skill-up"] = "Показывать стоимость за очко навыка"
L["Show gear I cannot make yet"] =
	"Показывать снаряжение, которое я пока не могу создать"
L["Show profession routes in the objective tracker. Hiding them keeps your tracked professions and targets."] =
	"Показывать маршруты профессий в списке задач. Скрытие сохраняет отслеживаемые профессии и цели."
L["Show skill on recipe rows"] = "Навык в строках рецептов"
L["Show skill range start on rows"] = "Начало диапазона в строках"
L["Show the merchant Reagents tab"] = "Показывать вкладку «Реагенты» у торговца"
L["Show the crafted gear tab"] = "Вкладка созданного снаряжения"
L["Show the levelling route tab"] = "Вкладка маршрута прокачки"
L["Show thresholds tooltip"] = "Подсказка с порогами"
L["Show tracked professions"] = "Показывать отслеживаемые профессии"
L["Skill  %d/%d     Target"] = "Навык  %d/%d     Цель"
L["Skill points a craft"] = "Очков навыка за создание"
L["Skill range start"] = "Начало диапазона"
L["Skill range starts at %d"] = "Диапазон начинается с %d"
L["Skill-up chance"] = "Шанс повышения навыка"
L["Skill-up chance and cost per skill-up at the right of each recipe."] =
	"Шанс повышения навыка и стоимость за очко справа от каждого рецепта."
L["Skill-up chance: %d%%"] = "Шанс повышения навыка: %d%%"
L["SkillUp report"] = "Отчет SkillUp"
L["Skipped (%d)"] = "Пропущено (%d)"
L["Skipped (%d):"] = "Пропущено (%d):"
L["Sold by"] = "Продает"
L["Sort by"] = "Сортировка"
L["Sort recipes"] = "Сортировка рецептов"
L["Source"] = "Источник"
L["Source unknown"] = "Источник неизвестен"
L["Stop tracking"] = "Не отслеживать"
L["Subtract what the crafted item sells for from its cost. Auction prices need Auctionator, TradeSkillMaster, AHDB or Naowh Forever, are after the 5% cut, and may not sell."] =
	"Вычитает из стоимости цену продажи созданного предмета. Для цен аукциона нужен Auctionator/TradeSkillMaster / AHDB / Naowh Forever, они указаны за вычетом 5% комиссии, и предмет может не продаться."
L["Taught by %s trainers."] = "Обучают учителя (%s)."
L["The place this recipe is taught isn't known yet."] =
	"Где обучают этому рецепту, пока неизвестно."
L["The rest comes from a vendor or your gathering."] =
	"Остальное — от торговца или из вашей добычи."
L["The route asks for %d to reach %d in 9 runs of 10; a worse run needs more."] =
	"Маршрут рассчитывает на %d, чтобы достичь %d в 9 случаях из 10; при меньшей удаче понадобится больше."
L["The source of this recipe isn't known."] = "Источник этого рецепта неизвестен."
L["To buy"] = "К покупке"
L["Tool"] = "Инструмент"
L["Tooltips and sorting"] = "Подсказки и сортировка"
L["Track"] = "Отслеживать"
L["Tracker scale"] = "Размер панели отслеживания"
L["Train %s"] = "Изучить %s"
L["Train %s at %d"] = "Изучить %s на %d"
L["Train %s at %d (level %d)"] = "Изучить %s на %d (уровень %d)"
L["Train %s first."] = "Сначала изучите %s."
L["Train %s first: you're at your cap."] = "Сначала изучите %s: вы достигли предела."
L["Trinket"] = "Аксессуар"
L["Turn this off to drag the shared Forever tracker anywhere on screen."] =
	"Выключите, чтобы перетаскивать общее окно отслеживания Forever в любое место экрана."
L["Update QuestieDB to see vendors, quests and trainers, with waypoints to them."] =
	"Обновите QuestieDB, чтобы видеть торговцев, задания и учителей с точками маршрута."
L["Used in"] = "Используется в"
L["Value gathered materials at what they'd sell for"] =
	"Оценивать добытые материалы по цене продажи"
L["Vendor"] = "Торговец"
L["Vendor reagents"] = "Реагенты торговцев"
L["Vendor sell price"] = "Цена продажи торговцу"
L["Visit a vendor to price reagents. Auction prices need Auctionator, TradeSkillMaster, AHDB or Naowh Forever."] =
	"Посетите торговца, чтобы узнать цены реагентов. Для цен аукциона нужен Auctionator/TradeSkillMaster / AHDB / Naowh Forever."
L["Waist"] = "Пояс"
L["Waypoint to a trainer"] = "Точка маршрута к учителю"
L["Waypoint to a vendor: %s"] = "Точка маршрута к торговцу: %s"
L["Waypoint to the quest giver: %s"] = "Точка маршрута к тому, кто дает задание: %s"
L["What's new after an update"] = "Что нового после обновления"
L["Where the tooltip goes when you hover a recipe. Beside the window, it stays clear of the reagents."] =
	"Где появляется подсказка при наведении на рецепт. Рядом с окном она не закрывает реагенты."
L["While the auction house is open, the Professions window offers a search for the selected recipe's reagents: as many as the crafts you choose still need after your bags and bank. Auctionator's shopping list carries the quantities; without it, each click puts the next reagent in the search box."] =
	"Пока открыт аукцион, окно профессий предлагает поиск реагентов выбранного рецепта: столько, сколько еще нужно для выбранного числа созданий с учетом сумок и банка. Список покупок Auctionator передает количество; без него каждый щелчок вставляет следующий реагент в поле поиска."
L["With Shortest Path Forever, a click leads you there."] =
	"С Shortest Path Forever щелчок приведет вас туда."
L["With Shortest Path Forever, this picks the nearest by travel time and leads you there."] =
	"С Shortest Path Forever выбирается ближайший по времени пути, и вас ведут туда."
L["World drop"] = "Случайная добыча"
L["Wrist"] = "Запястья"
L["You have it"] = "У вас есть"
L["You have this book: read it."] = "У вас есть эта книга: прочитайте ее."
L["You know it"] = "Изучено"
L["You: %d"] = "Вы: %d"
L["Your bags allow %d of the route's %d."] =
	"В сумках хватает места на %d из %d для маршрута."
L["Your bags and bank have enough."] = "В сумках и банке достаточно."
L["can't identify the profession %s (%s); please report it."] =
	"не удалось определить профессию %s (%s); пожалуйста, сообщите об этом."
L["couldn't add tracked reagents to the objective tracker; please report it."] =
	"не удалось добавить отслеживаемые реагенты в список задач; пожалуйста, сообщите об этом."
L["crafts"] = "созданий"
L["drop"] = "добыча"
L["every skipped recipe is back in the route."] =
	"все пропущенные рецепты возвращены в маршрут."
L["files are missing: restart the game (not /reload) after updating."] =
	"не хватает файлов: перезапустите игру (не /reload) после обновления."
L["for %s"] = "для %s"
L["gather"] = "добыча"
L["green"] = "зеленый"
L["grey"] = "серый"
L["item %d"] = "предмет %d"
L["level %d"] = "уровень %d"
L["makes %d %s"] = "создает %d %s"
L["no price"] = "нет цены"
L["no skipped recipes: right-click a step on the route page and choose Not this recipe."] =
	"пропущенных рецептов нет: щелкните правой кнопкой по шагу на странице маршрута и выберите «Не этот рецепт»."
L["no trainer requirements to check."] = "нет требований учителей для проверки."
L["none"] = "нет"
L["nothing to search for here: what's missing comes from a vendor or your gathering."] =
	"здесь искать нечего: недостающее — от торговца или из вашей добычи."
L["open a profession first."] = "сначала откройте профессию."
L["open the auction house's Buy tab, then search again."] =
	"откройте вкладку «Купить» на аукционе и повторите поиск."
L["orange"] = "оранжевый"
L["over 3 weeks ago"] = "более 3 недель назад"
L["profession %d"] = "профессия %d"
L["quest"] = "задание"
L["recipe %d"] = "рецепт %d"
L["route set to %s, %s."] = "маршрут проложен: %s, %s."
L["searching for %s: you need %d more."] = "поиск: %s; нужно еще %d."
L["sorting failed and has been turned off: %s"] = "сортировка не удалась и выключена: %s"
L["the %s book"] = "книга «%s»"
L["the %s quest"] = "задание «%s»"
L["the reagent names are still loading; search again in a moment."] =
	"названия реагентов еще загружаются; повторите поиск чуть позже."
L["today"] = "сегодня"
L["tracked, but the objective tracker section isn't attached; please report it."] =
	"отслеживается, но раздел в списке задач не прикреплен; пожалуйста, сообщите об этом."
L["unknown age"] = "возраст неизвестен"
L["unknown location"] = "место неизвестно"
L["updated to %s. %s"] = "обновлено до %s. %s"
L["vendor"] = "торговец"
L["waypoint set to %s, %s."] = "точка маршрута поставлена: %s, %s."
L["world drop"] = "случайная добыча"
L["yellow"] = "желтый"
L["you gather it (%s)"] = "вы добываете это (%s)"
L["you gather it (%s), valued at its AH price"] = "вы добываете это (%s), по цене аукциона"
L["you gather it (%s), valued at its vendor sell price"] =
	"вы добываете это (%s), по цене продажи торговцу"
L["your bags and bank already hold the reagents for that many."] =
	"в сумках и банке уже есть реагенты на это количество."
L["No step yet: learn or train a %s recipe that skills up."] =
	"Пока нет шага: изучите или освойте рецепт (%s), повышающий навык."
L["Show thresholds bar on the recipe"] = "Показывать полосу порогов на рецепте" -- mt
L["The orange, yellow, green and grey thresholds and where your skill sits, under the recipe in the Professions window. Turn it off if it covers the reagents."] =
	"Оранжевый, жёлтый, зелёный и серый пороги и ваше место на них, под рецептом в окне профессий. Отключите, если она закрывает реагенты." -- mt
L["%s (%s to %d)"] = "%s (%s до %d)" -- mt
L["Buying for %s"] = "Покупка для %s" -- mt
L["  %d items have no price yet"] = "  %d предметов пока без цены"
L["%d x %s - %s each"] = "%d x %s - %s за штуку"
L["%d x %s - price unknown"] = "%d x %s - цена неизвестна"
L["%s to %d"] = "%s до %d"
L[" · "] = " • "
L[", "] = ", "
L[", price seen %d days ago"] = ", цена замечена %d дн. назад"
L["/skillup export - show the trainer requirements this character has seen, to paste into a report"] =
	"/skillup export - показать требования учителя, которые видел этот персонаж, чтобы вставить их в отчет"
L["/skillup issue - report a bug or request a feature with a ready-made GitHub issue link"] =
	"/skillup issue - сообщить об ошибке или попросить новую возможность с готовой ссылкой на issue GitHub"
L["/skillup report - show a report to copy into a bug report"] =
	"/skillup report - показать отчет, чтобы скопировать его в сообщение об ошибке"
L[": "] = ": "
L["A buy trip needs Shortest Path Forever."] =
	"Для поездки за покупками нужен Shortest Path Forever."
L["Copy list"] = "Копировать список"
L["Copy shopping list"] = "Копировать список покупок"
L["Gather"] = "Добыча"
L["Need %d, have %d, missing %d  %s  %s each  %s"] =
	"Нужно %d, есть %d, не хватает %d  %s  %s за штуку  %s"
L["No tracked profession"] = "Нет отслеживаемых профессий"
L["Nothing is missing from the shopping list."] = "В списке покупок все есть."
L["Nothing to buy"] = "Нечего покупать"
L["Plan buy trip"] = "Спланировать покупки"
L["Plan this route again from today's prices and recipes."] =
	"Спланировать этот маршрут заново по сегодняшним ценам и рецептам."
L["Shopping list"] = "Список покупок"
L["Shortest Path Forever cannot plan the full trip; setting a waypoint to the first vendor."] =
	"Shortest Path Forever не может спланировать весь путь; ставится точка маршрута к первому торговцу."
L["Shortest Path Forever is needed to plan this trip."] =
	"Для планирования этого пути нужен Shortest Path Forever."
L["SkillUp Forever shopping list"] = "Список покупок SkillUp Forever"
L["The text is selected. Press Ctrl+C (Cmd+C on a Mac) to copy it."] =
	"Текст выделен. Нажмите Ctrl+C (Cmd+C на Mac), чтобы скопировать его."
L["Total for priced items: "] = "Всего по предметам с ценой: "
L["Unknown"] = "Неизвестно"
L["no trainer requirement seen yet: open a profession trainer, then try again."] =
	"требования учителя пока не видны: откройте учителя профессии и повторите попытку."
L["on %s"] = "у %s"
L["price unknown"] = "цена неизвестна"
L["Unpin recipe"] = "Открепить рецепт" -- mt
L["Pin for skill-ups"] = "Закрепить для повышения навыка" -- mt
L["Right-click to pin or skip this recipe."] =
	"Щёлкните правой кнопкой, чтобы закрепить или пропустить рецепт." -- mt
L["Unpin: %s"] = "Открепить: %s" -- mt
L["Pinned for skill-ups."] = "Закреплён для повышения навыка." -- mt
L["Skill range unknown."] = "Диапазон навыка неизвестен." -- mt
L["Already grey: no skill-ups."] = "Уже серый: навык не повышается." -- mt
L["Requires skill %d."] = "Требуется навык %d." -- mt
L["Learn this recipe first."] = "Сначала изучите этот рецепт." -- mt
L["Reagents not priced yet."] = "Цены на реагенты ещё неизвестны." -- mt
L["Outside this route or a newer pin takes priority."] =
	"Вне этого маршрута или более новый закреплённый рецепт имеет приоритет." -- mt
L["Pinned: %s"] = "Закреплён: %s" -- mt
L["The newest pin takes priority where skill ranges overlap."] =
	"При пересечении диапазонов приоритет у рецепта, закреплённого последним." -- mt
L["Pinned (%d)"] = "Закреплено (%d)" -- mt
L["crafted"] = "создано" -- mt
L["List unlearned recipes"] = "Показывать неизученные рецепты"
L["Adds the recipes of the open profession you have not learned under an Unlearned divider, greyed and marked with a trainer or recipe item and the skill it asks. Click a row to preview the recipe."] =
	"Добавляет неизученные рецепты открытой профессии под разделителем «Не изучено», серым и с пометкой учителя или рецепта и требуемого навыка. Нажмите на строку, чтобы открыть предварительный просмотр рецепта."
L["Not learned · %s"] = "Не изучено • %s"
L["Trainer"] = "Учитель"
L["Recipe item"] = "Рецепт"
L["listing unlearned recipes failed: %s"] =
	"не удалось показать неизученные рецепты: %s"
L["Nothing on this route can be gathered, fished or looted by you, so the switch changes nothing for it."] =
	"На этом маршруте вам нечего собрать, выловить или выбить из существ, поэтому переключатель здесь ничего не меняет." -- mt
L["Loot %d %s from creatures"] = "Выбить %d %s из существ" -- mt
L["you loot it from creatures"] = "вы выбиваете его из существ" -- mt
L["you loot it from creatures, valued at its AH price"] =
	"вы выбиваете его из существ, по цене аукциона" -- mt
L["you loot it from creatures, valued at its vendor sell price"] =
	"вы выбиваете его из существ, по цене продажи торговцу" -- mt
L["Shift-click crafts all %d."] = "Shift-щелчок создает все %d." -- mt
L["The game's Craft button is not ready for this recipe."] =
	"Кнопка «Создать» в игре не готова для этого рецепта." -- mt
L["vendor, limited stock"] = "торговец, ограниченный запас" -- mt
L["Sells %d at a time"] = "Продаёт по %d за раз" -- mt
L["This route is mostly %s: %d recipes are left out until their costs or sale values are known."] =
	"В этом маршруте в основном используется %s: рецептов исключено: %d, пока не станут известны их затраты или стоимость продажи."
L["Price self-supplied reagents at auction values"] = "Price self-supplied reagents at auction values" -- mt
L["A reagent you gather, loot or already own costs what selling it would bring - its auction price after the 5% cut, or its vendor sell price if that is more - instead of counting as free. With no market price it stays unpriced rather than free. Auction prices need Auctionator, TradeSkillMaster, AHDB or Naowh Forever."] =
	"A reagent you gather, loot or already own costs what selling it would bring - its auction price after the 5% cut, or its vendor sell price if that is more - instead of counting as free. With no market price it stays unpriced rather than free. Auction prices need Auctionator/TradeSkillMaster / AHDB / Naowh Forever." -- mt

-- Shared debug log (ForeverCore's Core/Log.lua).
L["Only buffs for your level"] =
	"Только положительные эффекты для вашего уровня"
L["Lists only the recipes whose product is a buff you can use at your level: elixirs, flasks, Well Fed food, protection potions, stones, oils and armour kits. Highest required level first. Learned recipes come first, then unlearned ones when those are listed."] =
	"Показывает только рецепты, чей предмет дает положительный эффект, доступный вам на вашем уровне: эликсиры, флаконы, еда «Сытость», защитные зелья, точильные камни, масла и наборы для доспехов. Сначала с самым высоким требуемым уровнем. Сначала изученные рецепты, затем неизученные, если они показаны."
L["%s: %s"] = "%s: %s" -- mt
L["%s drops in %s"] = "%s выпадает в %s" -- mt
L["Made by %s %d"] = "Изготовлено: %s %d" -- mt
L["Made by %s"] = "Изготовлено: %s" -- mt
L["%s at %d"] = "%s на %d" -- mt
L["A tab at the bottom of the Professions window listing the buff consumables this profession makes, by the skill they unlock at and what each one is for. It opens from the SkillUp side tab, beside the route and crafted gear tabs."] =
	"Вкладка внизу окна профессий со списком усиливающих расходников этой профессии, по навыку, на котором они открываются, и их назначению. Открывается с боковой вкладки SkillUp, рядом с вкладками маршрута и изготовленной экипировки." -- mt
L["A tab at the bottom of the Professions window listing the newest crafted item this character can equip in each slot. It opens from the SkillUp side tab, beside the route and buffs tabs."] =
	"Вкладка внизу окна профессий: самый новый изготовленный предмет, который этот персонаж может надеть в каждую ячейку. Открывается с боковой вкладки SkillUp, рядом с вкладками маршрута и усилений." -- mt
L["A tab at the bottom of the Professions window with a route to your target skill and its reagents. It opens from the SkillUp side tab, beside the crafted gear and buffs tabs. Tracked professions stay in the objective tracker either way."] =
	"Вкладка внизу окна профессий с маршрутом до целевого навыка и его реагентов. Открывается с боковой вкладки SkillUp, рядом с вкладками изготовленной экипировки и усилений. Отслеживаемые профессии в любом случае остаются в отслеживании целей." -- mt
L["Above your level"] = "Выше вашего уровня" -- mt
L["Buffs"] = "Усиления" -- mt
L["Known"] = "Известно" -- mt
L["Later"] = "Позже" -- mt
L["Learn now"] = "Изучить сейчас" -- mt
L["No buff items for your level yet."] =
	"Пока нет предметов усиления для вашего уровня." -- mt
L["Only for level %d"] = "Только для уровня %d" -- mt
L["Show the buffs tab"] = "Показывать вкладку усилений" -- mt
L["SkillUp"] = "SkillUp" -- mt
L["This profession makes no buff items."] =
	"Эта профессия не создаёт предметы усиления." -- mt
L["spell %d"] = "заклинание %d" -- mt
L["Buffs by %s skill"] = "Усиления: %s" -- mt
L["Skill  %d/%d"] = "Навык  %d/%d" -- mt
L["Other crafters"] = "Другие ремесленники" -- mt
L["No profession here makes buff items."] =
	"Ни одна профессия не создаёт предметы усиления." -- mt
L["Latest TradeSkillMaster prices."] = "Последние цены TradeSkillMaster." -- mt
L["TradeSkillMaster"] = "TradeSkillMaster" -- mt
L["TradeSkillMaster has no price for these reagents: update its AuctionDB with the TSM desktop app."] =
	"У TradeSkillMaster нет цены на эти реагенты: обновите его AuctionDB через приложение TSM для компьютера." -- mt
L["Update TradeSkillMaster's AuctionDB with the TSM desktop app, or visit a vendor, to price reagents."] =
	"Обновите AuctionDB TradeSkillMaster через приложение TSM для компьютера или посетите торговца, чтобы оценить реагенты." -- mt
L["Waiting for Questie to finish loading."] = "Ожидание окончания загрузки Questie."
L["Nothing is tracked for %s."] = "Для %s ничего не отслеживается." -- mt
L["+%d more to train"] = "ещё %d выучить" -- mt
L["Also train"] = "Также выучить" -- mt
L["Auctionator list: %s. Open the auction house, Shopping tab, pick it and Search; buy each row with a click."] =
	"Список Auctionator: %s. Откройте аукцион, вкладку «Покупки», выберите список и нажмите «Поиск»; покупайте каждую строку одним щелчком."
L["On (the default), a reagent you could gather, fish or loot from creatures is bought at a vendor or the auction house. Off, getting it yourself costs nothing."] =
	"Вкл. (по умолчанию): реагент, который можно собрать, выловить или добыть с существ, покупается у торговца или на аукционе. Выкл.: добыть его самостоятельно ничего не стоит."
L["On (the default), a reagent you could gather, fish or loot from creatures is bought at a vendor or the auction house. Off, getting it yourself costs what it would sell for."] =
	"Вкл. (по умолчанию): реагент, который можно собрать, выловить или добыть с существ, покупается у торговца или на аукционе. Выкл.: добыть его самостоятельно стоит столько, за сколько его можно продать."
L["Shift + wheel, or drag, scrolls the timeline sideways."] =
	"Shift + колесо мыши или перетаскивание прокручивает временную шкалу вбок."
L["SkillUp's list"] = "Список SkillUp"
L["Timeline"] = "Временная шкала"
L["Turning Buy reagents on writes an Auctionator list with every auction reagent still missing."] =
	"Если включить «Покупать реагенты», будет записан список Auctionator со всеми недостающими аукционными реагентами."
L["Without Auctionator, a recipe's Search button fills the game's own auction box one reagent at a time."] =
	"Без Auctionator кнопка «Поиск» рецепта заполняет собственную строку поиска аукциона игры по одному реагенту за раз."
L["%s needs ForeverCore. Install it from CurseForge, or choose Reinstall on ForeverCore in the CurseForge app."] =
	"%s требует ForeverCore. Установите его с CurseForge или выберите «Переустановить» для ForeverCore в приложении CurseForge." -- mt
L["%s: the installed ForeverCore is another addon (%s). Remove it and install ForeverCore from CurseForge."] =
	"%s: установленный ForeverCore является другой модификацией (%s). Удалите его и установите ForeverCore с CurseForge." -- mt
L["%s: ForeverCore is turned off. Enable it in the AddOns list to fix this."] =
	"%s: ForeverCore отключён. Включите его в списке модификаций, чтобы исправить это." -- mt
L["%s: %s is out of date. Update it to fix this."] =
	"%s: %s устарел. Обновите его, чтобы это исправить." -- mt
L["%s: %s are out of date. Update them to fix this."] =
	"%s: %s устарели. Обновите их, чтобы это исправить." -- mt
L["%s could not start. Reinstall %s to fix this."] =
	"%s не удалось запустить. Переустановите %s, чтобы это исправить." -- mt
L["Region sale average"] = "Средняя цена продажи в регионе"
L["Region sale average if higher"] = "Средняя цена продажи в регионе, если выше"
L["Region sale averages need TradeSkillMaster and its desktop app. They estimate value from reported regional sales and purchases, with the vendor price as a floor. They do not guarantee a sale."] =
	"Для средних цен продажи в регионе нужны TradeSkillMaster и его приложение для компьютера. Они оценивают стоимость по зарегистрированным региональным продажам и покупкам, но не ниже цены продажи торговцу. Продажа не гарантируется."

L["Counts include spares for an estimated %d%% chance to finish the whole route."] =
	"Количество включает запас для примерно %d%% вероятности пройти весь маршрут." -- mt
L["Restock visit cost"] = "Стоимость похода за пополнением" -- mt
L["Not counted"] = "Не учитывается" -- mt
L["What one trip to buy more reagents is worth, in copper, when a run takes more crafts than planned. It is added to that reagent's purchase price only when it happens. Leave it at zero to count no trip."] =
	"Сколько в меди стоит один поход за дополнительными реагентами, когда на серию уходит больше изготовлений, чем планировалось. Он добавляется к цене покупки этого реагента только когда происходит. Оставьте ноль, чтобы не учитывать походы." -- mt
L["%s (%s)"] = "%s (%s)"
L["%s profit per craft"] = "%s прибыли за создание"
L["%s profit per skill-up"] = "%s прибыли за очко навыка"
L["Auction price"] = "Цена аукциона"
L["Auction prices from"] = "Цены аукциона из"
L["Auctionator"] = "Auctionator"

L["Skill %d to %d, %s"] = "Навык с %d до %d, %s" -- mt
L["Skill %d to %d, %s, at %s"] = "Навык с %d до %d, %s, у: %s" -- mt
L["%s, uses materials you have"] = "%s, использует материалы, которые у вас есть" -- mt
L["Unlearned recipe order"] = "Порядок неизученных рецептов" -- mt
L["How recipes you have not learned are ordered. Learned recipes keep the selected recipe order."] =
	"Порядок рецептов, которые вы ещё не изучили. Изученные рецепты сохраняют выбранный порядок." -- mt
L["TSM regional sales per day"] = "Продажи в регионе за день по данным TSM" -- mt
L["Average sold per auction house in your region, reported by TSM."] =
	"Среднее количество продаж на один аукционный дом в вашем регионе по данным TSM." -- mt

L["Open %s from your spellbook."] = "Откройте %s в книге заклинаний."

L["Recipes on Shift"] = "Рецепты по Shift" -- mt
L["Show recipes on Shift or always. Off hides reagent details, including route needs."] =
	"Показывать рецепты по Shift или всегда. Выключение скрывает сведения о реагентах, включая потребности маршрутов." -- mt
L["Show route needs on item tooltips"] =
	"Показывать потребности маршрутов в подсказках предметов" -- mt
L["Show how much of an item your tracked routes still need. Turn this off to keep recipe details without the route line."] =
	"Показывает, сколько предметов ещё нужно для отслеживаемых маршрутов. Отключите, чтобы оставить сведения о рецептах без строки маршрута." -- mt

L["Have (bags only)"] = "В наличии (только сумки)" -- mt

L["%s%% to %s%%"] = "От %s%% до %s%%" -- mt
L["Adds an unverified 4 percentage points per detected Working Overtime rank to yellow and green skill-up chance estimates. Turn off to use the base chance estimate for costs and routes. Neither estimate is a verified server rule."] =
	"Добавляет непроверенные 4 процентных пункта за каждый обнаруженный ранг Working Overtime к оценке вероятности повышения навыка для жёлтых и зелёных рецептов. Отключите, чтобы использовать базовую оценку вероятности для затрат и маршрутов. Ни одна из оценок не является подтверждённым правилом сервера." -- mt
L["Chance of finishing with later purchases: %s."] =
	"Вероятность завершения с последующими покупками: %s." -- mt
L["Chance of finishing with starting supplies: %s."] =
	"Вероятность завершения с начальными запасами: %s." -- mt
L["Craft counts and shopping quantities are estimates. You may need more reagents."] =
	"Количество изготовлений и объёмы покупок приблизительны. Может потребоваться больше реагентов." -- mt
L["Craft next follows the estimated route."] =
	"Кнопка «Создать следующее» следует расчётному маршруту." -- mt
L["Include Working Overtime estimate"] = "Учитывать оценку Working Overtime" -- mt
L["Starting inventory: bags and bank."] = "Начальные запасы: сумки и банк." -- mt
L["Starting inventory: bags only."] = "Начальные запасы: только сумки." -- mt
L["Supply estimate: calculating."] = "Расчёт запасов: вычисление." -- mt
L["Supply estimate: cancelled."] = "Расчёт запасов: отменён." -- mt
L["Supply estimate: no cheapest purchase exists under these assumptions."] =
	"Расчёт запасов: при этих допущениях самой дешёвой покупки не существует." -- mt
L["Supply estimate: no starting purchase meets the target."] =
	"Расчёт запасов: ни одна начальная покупка не достигает цели." -- mt
L["Supply estimate: not enough information."] =
	"Расчёт запасов: недостаточно информации." -- mt
L["Supply estimate: ready."] = "Расчёт запасов: готов." -- mt
L["Target chance of finishing with starting supplies: %s%%."] =
	"Целевая вероятность завершения с начальными запасами: %s%%." -- mt
L["These chances assume the stated skill-up rates, prices, availability and delivery of later purchases."] =
	"Эти вероятности предполагают указанные шансы повышения навыка, цены, доступность и доставку последующих покупок." -- mt
L["unknown"] = "неизвестно" -- mt

L["Adaptive guidance opens the recommended recipe. Choose how many to craft in the profession window."] =
	"Адаптивные подсказки открывают рекомендуемый рецепт. Выберите количество для изготовления в окне профессии." -- mt

L["currency %d"] = "валюта %d" -- mt
L["an unknown payment"] = "неизвестный платёж" -- mt
L["Name the stock each offer draws on, or give this offer its own stock."] =
	"Назовите запас, из которого берётся каждое предложение, или дайте ему собственный запас." -- mt
L["The merchant shows no limit: limit the search to the number you will buy."] =
	"Торговец не показывает предел: ограничьте поиск количеством, которое вы купите." -- mt
L["The stock you assume does not match what the merchant shows."] =
	"Запас, который вы предполагаете, не совпадает с тем, что показывает торговец." -- mt
L["Enter a starting chance between 1 and 100."] = "Введите начальный шанс от 1 до 100." -- mt
L["The merchant sells none of this route's reagents."] =
	"Торговец не продаёт ни одного реагента этого маршрута." -- mt
L["The merchant's offer for %s is incomplete."] = "Предложение торговца для %s неполное." -- mt
L["Every offer needs its price to stay as shown."] =
	"Для каждого предложения цена должна оставаться такой, как показано." -- mt
L["Fill in every value this offer needs."] =
	"Заполните каждое значение, которое нужно этому предложению." -- mt
L["The merchant sells fewer purchases at a time than that."] =
	"Торговец продаёт меньше покупок за раз." -- mt
L["Offers that draw on one stock pool need the same stock."] =
	"Предложения из одного запаса требуют одного и того же запаса." -- mt
L["Offers at one vendor need the same trip costs and values."] =
	"Предложения у одного торговца требуют одинаковых затрат и ценностей поездки." -- mt
L["Enter the chance each later purchase arrives, from 0 to 100."] =
	"Введите шанс, что каждая следующая покупка придёт, от 0 до 100." -- mt
L["Check that the first purchase arrives for certain at every offer."] =
	"Отметьте, что первая покупка приходит точно, для каждого предложения." -- mt
L["One item or payment needs one leftover value."] =
	"Предмету или платежу нужна одна остаточная ценность." -- mt
L["Offers that use one payment need the same value for it."] =
	"Предложения с одним платежом требуют одинаковой ценности для него." -- mt
L["The merchant changed. Check the form again."] =
	"Торговец сменился. Проверьте форму снова." -- mt
L["The merchant did not change, but the assumptions did. Check the form again."] =
	"Торговец не сменился, но допущения изменились. Проверьте форму снова." -- mt
L["The merchant shows this offer sold out."] =
	"Торговец показывает это предложение распроданным." -- mt
L["The merchant does not say how much is left."] =
	"Торговец не говорит, сколько осталось." -- mt
L["The merchant will not sell this offer to you now."] =
	"Торговец сейчас не продаст вам это предложение." -- mt
L["Choose the unit the stock count is in."] = "Выберите единицу учёта запаса." -- mt
L["The assumptions were rejected. Fill in every value and check each offer."] =
	"Допущения отклонены. Заполните каждое значение и проверьте каждое предложение." -- mt
L["Open a profession to see its plan and coverage."] =
	"Откройте профессию, чтобы увидеть её план и покрытие." -- mt
L["Plan: %s, %s to %s, %d crafts."] = "План: %s, от %s до %s, изготовлений: %d." -- mt
L["Unpriced crafts: %d."] = "Изготовлений без цены: %d." -- mt
L["Your target chance: %s%%."] = "Ваш целевой шанс: %s%%." -- mt
L["Margin over your target: %s points."] = "Запас над целью: %s балла." -- mt
L["Below your target by %s points."] = "Ниже цели на %s балла." -- mt
L["craft"] = "изготовить" -- mt
L["buy"] = "купить" -- mt
L["stop"] = "остановиться" -- mt
L["Next step: %s."] = "Следующий шаг: %s." -- mt
L["Open a profession to set its supply policy."] =
	"Откройте профессию, чтобы задать её политику снабжения." -- mt
L["This profession has no plan to supply yet."] =
	"У этой профессии пока нет плана для снабжения." -- mt
L["Open a merchant to set this profession's supply policy."] =
	"Откройте торговца, чтобы задать политику снабжения этой профессии." -- mt
L["Ready to apply these assumptions."] = "Готово применить эти допущения." -- mt
L["no limit"] = "без предела" -- mt
L["Offer %d: %s"] = "Предложение %d: %s" -- mt
L["The merchant shows %s in stock, %s per purchase, at most %s purchases."] =
	"Торговец показывает %s в запасе, %s за покупку, не более %s покупок." -- mt
L["Price: %s."] = "Цена: %s." -- mt
L["Also costs %s %s."] = "Также стоит %s %s." -- mt
L["I can buy this offer"] = "Я могу купить это предложение" -- mt
L["The price stays as shown"] = "Цена остаётся такой, как показано" -- mt
L["Stock I assume is left"] = "Запас, который, как я предполагаю, остался" -- mt
L["The stock does not run out"] = "Запас не заканчивается" -- mt
L["The stock count is in items, not purchases"] =
	"Запас считается в предметах, а не в покупках" -- mt
L["This offer keeps its own stock"] = "У этого предложения собственный запас" -- mt
L["Limit the search to the stock I typed"] = "Ограничить поиск введённым запасом" -- mt
L["Stock pool name"] = "Название запаса" -- mt
L["Purchases allowed per visit"] = "Покупок за визит разрешено" -- mt
L["First trip cost (copper)"] = "Стоимость первой поездки (медь)" -- mt
L["Later trip cost (copper)"] = "Стоимость следующих поездок (медь)" -- mt
L["First trip value to you (copper)"] = "Ценность первой поездки для вас (медь)" -- mt
L["Later trip value to you (copper)"] = "Ценность следующих поездок для вас (медь)" -- mt
L["Chance each later purchase arrives (%)"] =
	"Шанс, что каждая следующая покупка придёт (%)" -- mt
L["The first purchase arrives for certain"] = "Первая покупка приходит точно" -- mt
L["I pay even when a purchase does not arrive"] = "Я плачу, даже если покупка не пришла" -- mt
L["Leftover value of one %s (copper)"] = "Остаточная ценность одного %s (медь)" -- mt
L["Value of one %s (copper)"] = "Ценность одного %s (медь)" -- mt
L["These are your own assumptions. The merchant's window only shows what it shows now."] =
	"Это ваши собственные допущения. Окно торговца показывает только то, что показывает сейчас." -- mt
L["Chance of finishing with starting supplies (%)"] =
	"Шанс завершить с начальным запасом (%)" -- mt
L["Plan later purchases too"] = "Планировать и последующие покупки" -- mt
L["Cost of an unfinished route (copper)"] =
	"Стоимость незавершённого маршрута (медь)" -- mt
L["Applied. The plan and its coverage follow these assumptions."] =
	"Применено. План и его покрытие следуют этим допущениям." -- mt
L["Supply"] = "Снабжение" -- mt

L["Supply policy"] = "Политика снабжения" -- mt
L["Open the profession and a merchant window."] = "Откройте профессию и окно торговца." -- mt
L["Apply policy"] = "Применить политику" -- mt
L["No trainer of your faction teaches this recipe."] =
	"Ни один учитель вашей фракции не обучает этому рецепту." -- mt
L["%s (level %d)"] = "%s (уровень %d)" -- mt

L["Show minimap button"] = "Показывать кнопку у миникарты" -- mt
L["Show the SkillUp button on the minimap."] = "Показывает кнопку SkillUp у миникарты." -- mt

L["Reagent counts cover the whole route, not each step alone."] =
	"Количество реагентов рассчитано на весь маршрут, а не на каждый шаг по отдельности." -- mt

L["Highest craft profit"] = "Наибольшая прибыль за изготовление" -- mt

L["AHDB"] = "AHDB" -- mt

L["Naowh Forever"] = "Naowh Forever" -- mt

L["AHDB, %s"] = "AHDB, %s" -- mt

L["Naowh Forever, %s"] = "Naowh Forever, %s" -- mt

L["you loot it from creatures, would sell for %s"] =
	"добывается с существ, можно продать за %s" -- mt

L["you gather it (%s), would sell for %s"] = "вы собираете (%s), можно продать за %s" -- mt

L["Scan the auction house with AHDB, or visit a vendor, to price reagents."] =
	"Просканируйте аукцион с AHDB или посетите торговца, чтобы узнать цены реагентов." -- mt

L["Update Naowh Forever's auction data, or visit a vendor, to price reagents."] =
	"Обновите данные аукциона Naowh Forever или посетите торговца, чтобы узнать цены реагентов." -- mt

L["Choose Auctionator, TradeSkillMaster, AHDB or Naowh Forever. The chosen price wins; the others fill gaps. Tooltips show the observation's age when known."] =
	"Выберите Auctionator, TradeSkillMaster, AHDB или Naowh Forever. Выбранная цена имеет приоритет; остальные заполняют пробелы. Подсказки показывают давность наблюдения, если она известна." -- mt

L["Sort recipes in one list, learned first, then unlearned. Highest craft profit includes grey recipes. Default restores categories."] =
	"Сортирует рецепты в одном списке: сначала изученные, затем неизученные. Сортировка по прибыли включает серые рецепты. По умолчанию восстанавливает категории." -- mt

L["These reagents have no vendor price. Auction prices need Auctionator, TradeSkillMaster, AHDB or Naowh Forever."] =
	"У этих реагентов нет цены у торговца. Для цен аукциона нужен Auctionator/TradeSkillMaster, AHDB, Naowh Forever." -- mt
