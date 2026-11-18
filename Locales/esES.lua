-- Machine translated (2026-10-16); corrections welcome: https://github.com/cjber/skillup-forever/issues/new?template=translation.yml
local _, ns = ...
if GetLocale() ~= "esES" then
	return
end
local L = ns.L
L["Show SkillUp tooltip details"] = "Mostrar detalles de descripción de SkillUp"
L["Show SkillUp profession tabs"] = "Mostrar pestañas de profesiones de SkillUp"
L["Adds SkillUp's details to tooltips while preserving each individual tooltip choice."] =
	"Añade los detalles de SkillUp a las descripciones y conserva cada ajuste individual."
L["Show money beside each recipe. Turning this off keeps prices in the recipe tooltip."] =
	"Muestra el dinero junto a cada receta. Si lo desactivas, los precios siguen en el tooltip de la receta." -- mt
L["Show prices on recipe rows"] = "Mostrar precios en las filas de recetas" -- mt
L["Show recipe tooltip on hover"] = "Mostrar tooltip de receta al pasar el ratón" -- mt
L["Show the SkillUp tooltip beside the Professions window when hovering a recipe. Turn it off to keep the reagents clear."] =
	"Muestra el tooltip de SkillUp junto a la ventana de profesiones al pasar el ratón por una receta. Desactívalo para ver los componentes sin estorbos." -- mt
L["Shows the route, gear and buffs tabs while preserving each individual tab choice."] =
	"Muestra las pestañas de ruta, equipo y beneficios y conserva cada ajuste individual."

L["%d %s"] = "%d %s"
L["%d more"] = "%d más"
L["%d of %d"] = "%d de %d"
L["%d reagents have no price"] = "%d reactivos no tienen precio"
L["%d to %d"] = "%d a %d"
L["%d, from %d to %d"] = "%d, de %d a %d"
L["%dd ago"] = "hace %d d"
L["%s %d"] = "%s %d"
L["%s (%d): bundled %d, classic-db %d"] = "%s (%d): incluido %d, classic-db %d"
L["%s (%d): bundled %s, the trainer wants %d"] = "%s (%d): incluido %s, el instructor pide %d"
L["%s (unlearned)"] = "%s (sin aprender)"
L["%s is at %s."] = "%s está en %s."
L["%s is in %s."] = "%s está en %s."
L["%s trainer"] = "Instructor de %s"
L["%s until %d"] = "%s hasta %d"
L["%s, %d"] = "%s, %d"
L["%s, %s, to %d"] = "%s, %s, hasta %d"
L["%s, source unknown"] = "%s, origen desconocido"
L["%s: %d moved, %d confirmed at a trainer, %d wrong."] =
	"%s: %d movidas, %d confirmadas con un instructor, %d erróneas."
L["+%d more"] = "+%d más"
L["/skillup skipped lists the recipes you skipped, with their IDs."] =
	"/skillup skipped muestra las recetas que omitiste, con sus ID."
L["/skillup unskip <recipe ID> shows one again, /skillup unskip all every one."] =
	"/skillup unskip <recipe ID> vuelve a mostrar una, /skillup unskip all todas."
L["A Reagents tab on a merchant's window that lists the reagents your tracked routes still need from that merchant and their total cost. Buy them from the merchant's own window."] =
	"Una pestaña Componentes en la ventana del mercader que muestra los componentes que tus rutas seguidas aún necesitan de ese mercader y su coste total. Cómpralos en la propia ventana del mercader."
L["A material your professions gather costs what selling it would bring instead of nothing: its auction price after the 5% cut, or its vendor sell price if that is more. Used for the route and the costs on recipe rows. Auction prices need Auctionator, TradeSkillMaster, AHDB or Naowh Forever."] =
	"Un material que recogen tus profesiones cuesta lo que obtendrías al venderlo en lugar de nada: su precio de subasta tras la comisión del 5 %, o su precio de venta al vendedor si es mayor. Se usa para la ruta y los costes de las filas de recetas. Los precios de subasta necesitan Auctionator/TradeSkillMaster / AHDB / Naowh Forever."
L["Keeps the shared Forever tracker where you put it. The grip at its top no longer drags it."] =
	"Mantiene el rastreador compartido Forever donde lo pones. El tirador de arriba ya no lo arrastra."
L["Lock the tracker"] = "Bloquear el rastreador"

L["AH"] = "CS"
L["Add the start of each recipe's difficulty range. This is separate from the skill needed to learn it."] =
	"Añade el inicio del rango de dificultad de cada receta. No es la habilidad necesaria para aprenderla."
L["Addon"] = "Addon"
L["Also for this slot"] = "También para esta ranura"
L["Annotate trainer recipes"] = "Anotar recetas del instructor"
L["Another craft makes this recipe, not yours."] = "Otra profesión crea esta receta, no la tuya."
L["Another crafter"] = "Otro artesano"
L["At the %d cap: no trainer teaches the next rank."] =
	"En el máximo de %d: ningún instructor enseña el siguiente rango."
L["At the cursor"] = "En el cursor"
L["AtlasLoot is installed but not running: enable it in the AddOns list, or update it if out of date."] =
	"AtlasLoot está instalado pero no se ejecuta: actívalo en la lista de addons o actualízalo si está desfasado."
L["Attach to quest tracker"] = "Anclar al rastreador de misiones"
L["Auction house"] = "Casa de subastas"
L["Auction price if higher"] = "Precio de subasta si es mayor"
L["Auctionator hasn't seen these reagents yet: scan the auction house with it to price them."] =
	"Auctionator aún no ha visto estos componentes: escanea la casa de subastas con él para ponerles precio."
L["Auctionator's scan when the auction house opens is off: turn it on in Auctionator, Basic Options."] =
	'El escaneo de Auctionator al abrir la casa de subastas está desactivado: actívalo en Auctionator, "Basic Options".'
L["Auctionator, %s"] = "Auctionator, %s"
L["Back"] = "Espalda"
L["Beside the Professions window"] = "Junto a la ventana de profesiones"
L["Buy %d %s"] = "Comprar %d %s"
L["Buy %s"] = "Comprar %s" -- mt
L["Buy %s at %d"] = "Comprar %s a %d" -- mt
L["Buy all"] = "Comprar todo"
L["Buy and read %s at %d"] = "Comprar y leer %s a %d"
L["Buy and read %s at %d (level %d)"] = "Comprar y leer %s a %d (nivel %d)"
L["Buy reagents"] = "Comprar componentes"
L["Buy reagents at the auction house"] = "Comprar componentes en la casa de subastas"
L["Can learn it"] = "Puedes aprenderla"
L["Cheapest skill-up"] = "Subida de habilidad más barata"
L["Chest"] = "Pecho"
L["Click for a waypoint to %s."] = "Haz clic para un punto de ruta a %s."
L["Click for a waypoint."] = "Haz clic para un punto de ruta."
L["Click to craft %d."] = "Haz clic para crear %d."
L["Click to open the recipe."] = "Haz clic para abrir la receta."
L["Click to show a recipe again."] = "Haz clic para volver a mostrar una receta."
L["Close"] = "Cerrar"
L["Complete %s at %d"] = "Completar %s a %d"
L["Complete %s at %d (level %d)"] = "Completar %s a %d (nivel %d)"
L["Complete %s first: you're at your cap."] = "Completa primero %s: estás en tu máximo."
L["Cost"] = "Coste"
L["Count what crafts sell for"] = "Contar el valor de venta de lo creado"
L["Craft %d %s"] = "Crear %d %s"
L["Craft %d of %d× %s"] = "Crear %d de %d× %s"
L["Craft %d× %s"] = "Crear %d× %s"
L["Craft %s"] = "Crear %s"
L["Craft"] = "Crear"
L["Craft next"] = "Crear la siguiente"
L["Crafted gear"] = "Equipo creado"
L["Crafts"] = "Creaciones"
L["Don't count it"] = "No contarlo"
L["Dropped by"] = "Lo suelta"
L["Each"] = "Cada uno"
L["Every recipe that uses it"] = "Todas las recetas que lo usan"
L["Fee"] = "Tarifa"
L["Fees"] = "Tarifas"
L["Feet"] = "Pies"
L["Finger"] = "Dedo"
L["First used at"] = "Se usa desde"
L["Gather %d %s"] = "Recoger %d %s"
L["Gathering skill on nodes"] = "Habilidad de recolección en vetas y hierbas"
L["Hands"] = "Manos"
L["Have (bags and bank)"] = "Tienes (bolsas y banco)"
L["Head"] = "Cabeza"
L["Herb and ore node tooltips show the skill they need and its colour at yours (English client only). Skinnable corpses show ? until the skinning rule is confirmed on Forever."] =
	"Las descripciones de hierbas y vetas muestran la habilidad que requieren y su color según la tuya (solo cliente en inglés). Los cadáveres desollables muestran ? hasta que se confirme la regla de desuello en Forever."
L["Install AtlasLoot to see the recipes vendors, quests and drops would add."] =
	"Instala AtlasLoot para ver las recetas que añadirían vendedores, misiones y botines."
L["Install QuestieDB and AtlasLoot to see where recipes, vendors and trainers are."] =
	"Instala QuestieDB y AtlasLoot para ver dónde están recetas, vendedores e instructores."
L["Install QuestieDB to see vendors, quests and trainers, with waypoints to them."] =
	"Instala QuestieDB para ver vendedores, misiones e instructores, con puntos de ruta."
L["Its trainer should teach these at your skill now:"] =
	"Su instructor debería enseñarte esto con tu habilidad actual:"
L["Kept in the Auctionator list '%s'."] = 'Guardado en la lista de Auctionator "%s".'
L["Latest Auctionator prices."] = "Últimos precios de Auctionator."
L["Latest Auctionator prices: rescan to update old prices."] =
	"Últimos precios de Auctionator: vuelve a escanear para actualizar los antiguos."
L["Learn a crafting profession to plan a route."] = "Aprende una profesión de fabricación para planear una ruta."
L["Legs"] = "Piernas"
L["Level %d"] = "Nivel %d"
L["Level %d %s"] = "Nivel %d %s"
L["Made at"] = "Se crea en"
L["Main hand"] = "Mano principal"
L["Missing reagents for this step."] = "Faltan componentes para este paso."
L["Money on recipe rows"] = "Dinero en las filas de recetas"
L["Nearest trainer"] = "Instructor más cercano"
L["Nearest vendor"] = "Vendedor más cercano"
L["Neck"] = "Cuello"
L["Need %d more %s"] = "Faltan %d %s"
L["Need a %s in your bags."] = "Necesitas %s en tus bolsas."
L["Needs %s %d"] = "Requiere %s %d"
L["Needs %s, sells back %s"] = "Necesita %s, devuelve %s"
L["Needs %s, sells back %s (incomplete)"] = "Necesita %s, devuelve %s (incompleto)"
L["Net per craft"] = "Neto por creación"
L["Newest recipes first"] = "Recetas más recientes primero"
L["Next to the recipe"] = "Junto a la receta"
L["No crafted gear for your level and class yet."] = "Aún no hay equipo creado para tu nivel y clase."
L["No crafted gear you can make yet. Tick the box above to see gear you cannot make."] =
	"Aún no hay equipo que puedas crear. Marca la casilla de arriba para ver el que no puedes crear."
L["No skill data for this recipe yet."] = "Aún no hay datos de habilidad para esta receta."
L["No trainer teaches this rank: a book does."] = "Ningún instructor enseña este rango: lo enseña un libro."
L["No trainer teaches this rank: a quest does."] = "Ningún instructor enseña este rango: lo enseña una misión."
L["Not in this route: you chose Not this recipe."] = 'No está en esta ruta: elegiste "Esta receta no".'
L["Not this recipe"] = "Esta receta no"
L["Nothing priced you know skills up past %d."] = "Nada con precio que conozcas sube la habilidad más allá de %d."
L["Nothing to buy for this route."] = "Nada que comprar para esta ruta."
L["Nothing to craft on this route."] = "Nada que crear en esta ruta."
L["Nothing you know skills up past %d."] = "Nada que conozcas sube la habilidad más allá de %d."
L["Off hand"] = "Mano secundaria"
L["On %s"] = "En %s"
L["One line in chat the first time a new version loads."] =
	"Una línea en el chat la primera vez que se carga una versión nueva."
L["Open"] = "Abrir"
L["Open %s to craft from here."] = "Abre %s para crear desde aquí."
L["Open recipe"] = "Abrir receta"
L["Per craft"] = "Por fabricación"
L["Per skill-up"] = "Por subida de habilidad"
L["Per skill-up is the cost of one skill point. Per craft is what one craft costs or earns, shown on recipes that no longer give skill too."] =
	"Por subida de habilidad es el coste de un punto de habilidad. Por fabricación es lo que cuesta o gana una fabricación, también en recetas que ya no dan habilidad."
L["Price"] = "Precio"
L["Prices"] = "Precios"
L["Profession reagents"] = "Componentes de profesión"
L["Profit per craft"] = "Beneficio por creación"
L["Profit per skill-up"] = "Beneficio por subida de habilidad"
L["Quest"] = "Misión"
L["Quest giver"] = "Asignador de misiones"
L["Raises your skill cap to %d."] = "Sube tu máximo de habilidad a %d."
L["Ranged"] = "A distancia"
L["Read %s at %d"] = "Leer %s a %d"
L["Read %s at %d (level %d)"] = "Leer %s a %d (nivel %d)"
L["Read %s first: you're at your cap."] = "Lee primero %s: estás en tu máximo."
L["Reagent cost divided by skill-up chance, on recipe rows and in the tooltip. Common vendor reagents are priced from the start and updated at merchants you visit, reagents you gather cost what they would sell for unless you turn that off under Prices, and auction prices need Auctionator, TradeSkillMaster, AHDB or Naowh Forever."] =
	"Coste de componentes dividido por la probabilidad de subir habilidad, en las filas de recetas y en la descripción. Los componentes comunes de vendedor tienen precio desde el principio y se actualizan en los mercaderes que visitas; los que recoges cuestan su valor de venta salvo que desactives esa opción en Precios; los precios de subasta necesitan Auctionator/TradeSkillMaster / AHDB / Naowh Forever."
L["Reagent tooltips"] = "Descripciones de componentes"
L["Reagents"] = "Componentes"
L["Reagents  (have / need)"] = "Componentes  (tienes / necesitas)"
L["Reagents for"] = "Componentes para"
L["Reagents in hand"] = "Componentes listos"
L["Reagents still needed"] = "Componentes que faltan"
L["Recipe rows"] = "Filas de recetas"
L["Recipe tooltip position"] = "Posición de la descripción de recetas"
L["Recipes from vendors, quests and drops that would carry it on:"] =
	"Recetas de vendedores, misiones y botines que permitirían seguir:"
L["Required skill, skill-up chance and cost on profession trainer recipes, and which one is best to train next for your route."] =
	"Habilidad requerida, probabilidad de subida y coste en las recetas de los instructores de profesión, y cuál conviene aprender después para tu ruta."
L["Requires"] = "Requiere"
L["Replan"] = "Replanificar"
L["Route"] = "Ruta"
L["Route and trainer"] = "Ruta e instructor"
L["Route incomplete: %d recipes left out because their costs or sale values are unknown."] =
	"Ruta incompleta: se omiten %d recetas porque sus costes o valores de venta son desconocidos."
L["Route needs"] = "La ruta necesita"
L["Route: %d/%d · %s to %d"] = "Ruta: %d/%d · %s hasta %d"
L["Sales"] = "Ventas"
L["Scales the shared Forever tracker. 100% matches the game's own tracker."] =
	"Cambia el tamaño del rastreador Forever compartido. 100 % coincide con el rastreador del juego."
L["Scan the auction house with Auctionator, or visit a vendor, to price reagents."] =
	"Escanea la casa de subastas con Auctionator o visita a un vendedor para poner precio a los componentes."
L["Scroll"] = "Receta"
L["Search"] = "Buscar"
L["Search reagents at the auction house"] = "Buscar componentes en la casa de subastas"
L["Sells for"] = "Se vende por"
L["Sells for x%g"] = "Se vende por x%g"
L["Set waypoint"] = "Fijar punto de ruta"
L["Shift-click to link the scroll."] = "Mayús-clic para enlazar la receta."
L["Shift: used in %d of your recipes"] = "Mayús: se usa en %d de tus recetas"
L["Shoulder"] = "Hombro"
L["Show again: %s"] = "Se vuelve a mostrar: %s"
L["Show cost per skill-up"] = "Mostrar coste por subida de habilidad"
L["Show gear I cannot make yet"] = "Mostrar equipo que aún no puedo crear"
L["Show profession routes in the objective tracker. Hiding them keeps your tracked professions and targets."] =
	"Muestra las rutas de profesión en el rastreador de objetivos. Ocultarlas conserva tus profesiones seguidas y objetivos."
L["Show skill on recipe rows"] = "Mostrar habilidad en las filas"
L["Show skill range start on rows"] = "Mostrar inicio del rango en las filas"
L["Show the merchant Reagents tab"] = "Mostrar la pestaña Componentes del mercader"
L["Show the crafted gear tab"] = "Mostrar la pestaña de equipo creado"
L["Show the levelling route tab"] = "Mostrar la pestaña de ruta de progreso"
L["Show tracked professions"] = "Mostrar profesiones seguidas"
L["Skill  %d/%d     Target"] = "Habilidad  %d/%d     Objetivo"
L["Skill points a craft"] = "Puntos de habilidad por creación"
L["Skill range start"] = "Inicio del rango"
L["Skill range starts at %d"] = "El rango empieza en %d"
L["Skill-up chance"] = "Probabilidad de subida"
L["Skill-up chance and cost per skill-up at the right of each recipe."] =
	"Probabilidad de subida y coste por subida a la derecha de cada receta."
L["Skill-up chance: %d%%"] = "Probabilidad de subida: %d%%"
L["SkillUp report"] = "Informe de SkillUp"
L["Skipped (%d)"] = "Omitidas (%d)"
L["Skipped (%d):"] = "Omitidas (%d):"
L["Sold by"] = "Lo vende"
L["Sort by"] = "Ordenar por"
L["Sort recipes"] = "Ordenar recetas"
L["Source"] = "Origen"
L["Source unknown"] = "Origen desconocido"
L["Stop tracking"] = "Dejar de seguir"
L["Subtract what the crafted item sells for from its cost. Auction prices need Auctionator, TradeSkillMaster, AHDB or Naowh Forever, are after the 5% cut, and may not sell."] =
	"Resta del coste lo que vale vender el objeto creado. Los precios de subasta necesitan Auctionator/TradeSkillMaster / AHDB / Naowh Forever, son tras la comisión del 5 % y puede que no se vendan."
L["Taught by %s trainers."] = "Lo enseñan los instructores de %s."
L["The place this recipe is taught isn't known yet."] = "Aún no se sabe dónde se enseña esta receta."
L["The rest comes from a vendor or your gathering."] = "El resto viene de un vendedor o de tu recolección."
L["The route asks for %d to reach %d in 9 runs of 10; a worse run needs more."] =
	"La ruta cuenta con %d para llegar a %d 9 de cada 10 veces; con peor suerte harán falta más."
L["The source of this recipe isn't known."] = "Se desconoce el origen de esta receta."
L["To buy"] = "Por comprar"
L["Tool"] = "Herramienta"
L["Tooltips and sorting"] = "Descripciones y orden"
L["Track"] = "Seguir"
L["Tracker scale"] = "Tamaño del rastreador"
L["Train %s"] = "Aprender %s"
L["Train %s at %d"] = "Aprender %s a %d"
L["Train %s at %d (level %d)"] = "Aprender %s a %d (nivel %d)"
L["Train %s first."] = "Aprende primero %s."
L["Train %s first: you're at your cap."] = "Aprende primero %s: estás en tu máximo."
L["Trinket"] = "Alhaja"
L["Turn this off to drag the shared Forever tracker anywhere on screen."] =
	"Desactívalo para arrastrar el rastreador Forever compartido a cualquier lugar de la pantalla."
L["Update QuestieDB to see vendors, quests and trainers, with waypoints to them."] =
	"Actualiza QuestieDB para ver vendedores, misiones e instructores, con puntos de ruta."
L["Used in"] = "Se usa en"
L["Value gathered materials at what they'd sell for"] = "Valorar los materiales recogidos a su precio de venta"
L["Vendor"] = "Vendedor"
L["Vendor reagents"] = "Componentes de vendedor"
L["Vendor sell price"] = "Precio de venta al vendedor"
L["Visit a vendor to price reagents. Auction prices need Auctionator, TradeSkillMaster, AHDB or Naowh Forever."] =
	"Visita a un vendedor para poner precio a los componentes. Los precios de subasta necesitan Auctionator/TradeSkillMaster / AHDB / Naowh Forever."
L["Waist"] = "Cintura"
L["Waypoint to a trainer"] = "Punto de ruta a un instructor"
L["Waypoint to a vendor: %s"] = "Punto de ruta a un vendedor: %s"
L["Waypoint to the quest giver: %s"] = "Punto de ruta al asignador de misiones: %s"
L["What's new after an update"] = "Novedades tras una actualización"
L["Where the tooltip goes when you hover a recipe. Beside the window, it stays clear of the reagents."] =
	"Dónde aparece la descripción al pasar el cursor sobre una receta. Junto a la ventana, no tapa los componentes."
L["While the auction house is open, the Professions window offers a search for the selected recipe's reagents: as many as the crafts you choose still need after your bags and bank. Auctionator's shopping list carries the quantities; without it, each click puts the next reagent in the search box."] =
	"Con la casa de subastas abierta, la ventana de profesiones ofrece buscar los componentes de la receta seleccionada: tantos como aún necesiten las creaciones que elijas tras contar tus bolsas y banco. La lista de compras de Auctionator lleva las cantidades; sin ella, cada clic pone el siguiente componente en el cuadro de búsqueda."
L["World drop"] = "Objeto del mundo"
L["Wrist"] = "Muñeca"
L["You have it"] = "Lo tienes"
L["You have this book: read it."] = "Tienes este libro: léelo."
L["You know it"] = "La conoces"
L["You: %d"] = "Tú: %d"
L["Your bags allow %d of the route's %d."] = "Tus bolsas permiten %d de los %d de la ruta."
L["Your bags and bank have enough."] = "Tus bolsas y banco tienen suficiente."
L["can't identify the profession %s (%s); please report it."] =
	"no se reconoce la profesión %s (%s); por favor, infórmalo."
L["couldn't add tracked reagents to the objective tracker; please report it."] =
	"no se pudieron añadir los componentes seguidos al rastreador de objetivos; por favor, infórmalo."
L["crafts"] = "creaciones"
L["drop"] = "botín"
L["every skipped recipe is back in the route."] = "todas las recetas omitidas vuelven a estar en la ruta."
L["files are missing: restart the game (not /reload) after updating."] =
	"faltan archivos: reinicia el juego (no /reload) tras actualizar."
L["for %s"] = "para %s"
L["gather"] = "recoger"
L["green"] = "verde"
L["grey"] = "gris"
L["item %d"] = "objeto %d"
L["level %d"] = "nivel %d"
L["makes %d %s"] = "crea %d %s"
L["no price"] = "sin precio"
L["no skipped recipes: right-click a step on the route page and choose Not this recipe."] =
	'no hay recetas omitidas: haz clic derecho en un paso de la página de ruta y elige "Esta receta no".'
L["no trainer requirements to check."] = "no hay requisitos de instructor que comprobar."
L["none"] = "ninguno"
L["nothing to search for here: what's missing comes from a vendor or your gathering."] =
	"nada que buscar aquí: lo que falta viene de un vendedor o de tu recolección."
L["open a profession first."] = "abre primero una profesión."
L["open the auction house's Buy tab, then search again."] =
	"abre la pestaña Comprar de la casa de subastas y vuelve a buscar."
L["orange"] = "naranja"
L["over 3 weeks ago"] = "hace más de 3 semanas"
L["profession %d"] = "profesión %d"
L["quest"] = "misión"
L["recipe %d"] = "receta %d"
L["route set to %s, %s."] = "ruta fijada a %s, %s."
L["searching for %s: you need %d more."] = "buscando %s: necesitas %d más."
L["sorting failed and has been turned off: %s"] = "la ordenación falló y se ha desactivado: %s"
L["the %s book"] = "el libro %s"
L["the %s quest"] = "la misión %s"
L["the reagent names are still loading; search again in a moment."] =
	"los nombres de los componentes aún se están cargando; vuelve a buscar en un momento."
L["today"] = "hoy"
L["tracked, but the objective tracker section isn't attached; please report it."] =
	"seguido, pero la sección del rastreador de objetivos no está anclada; por favor, infórmalo."
L["unknown age"] = "antigüedad desconocida"
L["unknown location"] = "ubicación desconocida"
L["updated to %s. %s"] = "actualizado a %s. %s"
L["vendor"] = "vendedor"
L["waypoint set to %s, %s."] = "punto de ruta fijado a %s, %s."
L["world drop"] = "objeto del mundo"
L["yellow"] = "amarillo"
L["you gather it (%s)"] = "lo recoges tú (%s)"
L["you gather it (%s), valued at its AH price"] = "lo recoges tú (%s), valorado a su precio en la CS"
L["you gather it (%s), valued at its vendor sell price"] =
	"lo recoges tú (%s), valorado a su precio de venta al vendedor"
L["your bags and bank already hold the reagents for that many."] =
	"tus bolsas y banco ya tienen los componentes para esa cantidad."
L["No step yet: learn or train a %s recipe that skills up."] =
	"Aún no hay paso: aprende o entrena una receta de %s que suba habilidad."
L["Show thresholds bar on the recipe"] = "Mostrar la barra de umbrales en la receta" -- mt
L["The orange, yellow, green and grey thresholds and where your skill sits, under the recipe in the Professions window. Turn it off if it covers the reagents."] =
	"Los umbrales naranja, amarillo, verde y gris y dónde está tu habilidad, bajo la receta en la ventana de profesiones. Desactívalo si tapa los componentes." -- mt
L["%s (%s to %d)"] = "%s (%s hasta %d)" -- mt
L["Buying for %s"] = "Comprando para %s" -- mt
L["  %d items have no price yet"] = "  %d objetos aún no tienen precio"
L["%d x %s - %s each"] = "%d x %s - %s cada uno"
L["%d x %s - price unknown"] = "%d x %s - precio desconocido"
L["%s to %d"] = "%s a %d"
L[" · "] = " · "
L[", "] = ", "
L[", price seen %d days ago"] = ", precio visto hace %d días"
L["/skillup export - show the trainer requirements this character has seen, to paste into a report"] =
	"/skillup export - muestra los requisitos de instructor que ha visto este personaje, para pegar en un informe"
L["/skillup issue - report a bug or request a feature with a ready-made GitHub issue link"] =
	"/skillup issue - informa de un error o pide una función con un enlace de issue de GitHub listo para usar"
L["/skillup report - show a report to copy into a bug report"] =
	"/skillup report - muestra un informe para copiar en un informe de error"
L[": "] = ": "
L["A buy trip needs Shortest Path Forever."] = "Un viaje de compra necesita Shortest Path Forever."
L["Copy list"] = "Copiar lista"
L["Copy shopping list"] = "Copiar lista de compras"
L["Gather"] = "Recolección"
L["Need %d, have %d, missing %d  %s  %s each  %s"] = "Necesitas %d, tienes %d, faltan %d  %s  %s cada uno  %s"
L["No tracked profession"] = "Ninguna profesión seguida"
L["Nothing is missing from the shopping list."] = "No falta nada en la lista de compras."
L["Nothing to buy"] = "No hay nada que comprar"
L["Plan buy trip"] = "Planificar la compra"
L["Plan this route again from today's prices and recipes."] =
	"Vuelve a planificar esta ruta con los precios y recetas de hoy."
L["Shopping list"] = "Lista de compras"
L["Shortest Path Forever cannot plan the full trip; setting a waypoint to the first vendor."] =
	"Shortest Path Forever no puede planificar todo el viaje; se fija un punto de ruta al primer vendedor."
L["Shortest Path Forever is needed to plan this trip."] =
	"Se necesita Shortest Path Forever para planificar este viaje."
L["SkillUp Forever shopping list"] = "Lista de compras de SkillUp Forever"
L["The text is selected. Press Ctrl+C (Cmd+C on a Mac) to copy it."] =
	"El texto está seleccionado. Pulsa Ctrl+C (Cmd+C en Mac) para copiarlo."
L["Total for priced items: "] = "Total de los objetos con precio: "
L["Unknown"] = "Desconocido"
L["no trainer requirement seen yet: open a profession trainer, then try again."] =
	"aún no se ha visto ningún requisito de instructor: abre un instructor de profesión y vuelve a intentarlo."
L["on %s"] = "en %s"
L["price unknown"] = "precio desconocido"
L["Unpin recipe"] = "Desfijar receta" -- mt
L["Pin for skill-ups"] = "Fijar para subir habilidad" -- mt
L["Right-click to pin or skip this recipe."] = "Clic derecho para fijar u omitir esta receta." -- mt
L["Unpin: %s"] = "Desfijar: %s" -- mt
L["Pinned for skill-ups."] = "Fijada para subir habilidad." -- mt
L["Skill range unknown."] = "Rango de habilidad desconocido." -- mt
L["Already grey: no skill-ups."] = "Ya es gris: no aumenta la habilidad." -- mt
L["Requires skill %d."] = "Requiere habilidad %d." -- mt
L["Learn this recipe first."] = "Aprende esta receta primero." -- mt
L["Reagents not priced yet."] = "Aún faltan precios de los componentes." -- mt
L["Outside this route or a newer pin takes priority."] =
	"Fuera de esta ruta o una receta fijada más reciente tiene prioridad." -- mt
L["Pinned: %s"] = "Fijada: %s" -- mt
L["The newest pin takes priority where skill ranges overlap."] =
	"La receta fijada más reciente tiene prioridad cuando los rangos se solapan." -- mt
L["Pinned (%d)"] = "Fijadas (%d)" -- mt
L["crafted"] = "fabricado" -- mt
L["List unlearned recipes"] = "Listar recetas sin aprender"
L["Adds the recipes of the open profession you have not learned under an Unlearned divider, greyed and marked with a trainer or recipe item and the skill it asks. Click a row to preview the recipe."] =
	"Añade las recetas de la profesión abierta que no has aprendido bajo un separador Sin aprender, en gris y marcadas con un instructor o una receta y la habilidad que piden. Haz clic en una fila para ver la vista previa de la receta."
L["Not learned · %s"] = "Sin aprender · %s"
L["Trainer"] = "Instructor"
L["Recipe item"] = "Receta"
L["listing unlearned recipes failed: %s"] = "no se pudieron listar las recetas sin aprender: %s"
L["Nothing on this route can be gathered, fished or looted by you, so the switch changes nothing for it."] =
	"En esta ruta no puedes recoger, pescar ni saquear de criaturas nada, así que la opción no cambia nada." -- mt
L["Loot %d %s from creatures"] = "Saquear %d %s de criaturas" -- mt
L["you loot it from creatures"] = "lo saqueas de criaturas" -- mt
L["you loot it from creatures, valued at its AH price"] = "lo saqueas de criaturas, valorado a su precio de subasta" -- mt
L["you loot it from creatures, valued at its vendor sell price"] =
	"lo saqueas de criaturas, valorado a su precio de venta al vendedor" -- mt
L["Shift-click crafts all %d."] = "Mayús-clic crea los %d." -- mt
L["The game's Craft button is not ready for this recipe."] =
	"El botón Crear del juego no está listo para esta receta." -- mt
L["vendor, limited stock"] = "vendedor, existencias limitadas" -- mt
L["Sells %d at a time"] = "Vende %d a la vez" -- mt
L["This route is mostly %s: %d recipes are left out until their costs or sale values are known."] =
	"Esta ruta consiste principalmente en %s: se omiten %d recetas hasta conocer sus costes o valores de venta."
L["Price self-supplied reagents at auction values"] = "Price self-supplied reagents at auction values" -- mt
L["A reagent you gather, loot or already own costs what selling it would bring - its auction price after the 5% cut, or its vendor sell price if that is more - instead of counting as free. With no market price it stays unpriced rather than free. Auction prices need Auctionator, TradeSkillMaster, AHDB or Naowh Forever."] =
	"A reagent you gather, loot or already own costs what selling it would bring - its auction price after the 5% cut, or its vendor sell price if that is more - instead of counting as free. With no market price it stays unpriced rather than free. Auction prices need Auctionator/TradeSkillMaster / AHDB / Naowh Forever." -- mt

-- Shared debug log (ForeverCore's Core/Log.lua).
L["Only buffs for your level"] = "Solo mejoras para tu nivel"
L["Lists only the recipes whose product is a buff you can use at your level: elixirs, flasks, Well Fed food, protection potions, stones, oils and armour kits. Highest required level first. Learned recipes come first, then unlearned ones when those are listed."] =
	"Muestra solo las recetas cuyo producto sea una mejora que puedas usar a tu nivel: elixires, frascos, comida de Bien alimentado, pociones de protección, piedras, aceites y kits de armadura. Primero el nivel requerido más alto. Primero las recetas aprendidas y después las no aprendidas cuando se muestran."
L["%s: %s"] = "%s: %s" -- mt
L["%s drops in %s"] = "%s cae en %s" -- mt
L["Made by %s %d"] = "Fabricado por %s %d" -- mt
L["Made by %s"] = "Fabricado por %s" -- mt
L["%s at %d"] = "%s en %d" -- mt
L["A tab at the bottom of the Professions window listing the buff consumables this profession makes, by the skill they unlock at and what each one is for. It opens from the SkillUp side tab, beside the route and crafted gear tabs."] =
	"Una pestaña en la parte inferior de la ventana de profesiones que lista los consumibles de beneficio que hace esta profesión, por la habilidad a la que se desbloquean y para qué sirve cada uno. Se abre desde la pestaña lateral de SkillUp, junto a las pestañas de ruta y equipo fabricado." -- mt
L["A tab at the bottom of the Professions window listing the newest crafted item this character can equip in each slot. It opens from the SkillUp side tab, beside the route and buffs tabs."] =
	"Una pestaña en la parte inferior de la ventana de profesiones con el objeto fabricado más reciente que este personaje puede equipar en cada ranura. Se abre desde la pestaña lateral de SkillUp, junto a las pestañas de ruta y beneficios." -- mt
L["A tab at the bottom of the Professions window with a route to your target skill and its reagents. It opens from the SkillUp side tab, beside the crafted gear and buffs tabs. Tracked professions stay in the objective tracker either way."] =
	"Una pestaña en la parte inferior de la ventana de profesiones con una ruta hasta tu habilidad objetivo y sus componentes. Se abre desde la pestaña lateral de SkillUp, junto a las pestañas de equipo fabricado y beneficios. Las profesiones seguidas permanecen en el seguimiento de objetivos de todos modos." -- mt
L["Above your level"] = "Por encima de tu nivel" -- mt
L["Buffs"] = "Beneficios" -- mt
L["Known"] = "Conocido" -- mt
L["Later"] = "Más tarde" -- mt
L["Learn now"] = "Aprender ahora" -- mt
L["No buff items for your level yet."] = "Aún no hay objetos de beneficio para tu nivel." -- mt
L["Only for level %d"] = "Solo para nivel %d" -- mt
L["Show the buffs tab"] = "Mostrar la pestaña de beneficios" -- mt
L["Show the supply tab"] = "Mostrar la pestaña de suministro" -- mt
L["A tab at the bottom of the Professions window where you set what a merchant will sell and deliver, so the route can plan around it. It opens from the SkillUp side tab, beside the route tab."] =
	"Una pestaña en la parte inferior de la ventana de profesiones donde indicas lo que un mercader venderá y entregará, para que la ruta lo tenga en cuenta. Se abre desde la pestaña lateral de SkillUp, junto a la pestaña de ruta." -- mt
L["SkillUp"] = "SkillUp" -- mt
L["This profession makes no buff items."] = "Esta profesión no crea objetos de beneficio." -- mt
L["spell %d"] = "hechizo %d" -- mt
L["Buffs by %s skill"] = "Beneficios por %s" -- mt
L["Skill  %d/%d"] = "Habilidad  %d/%d" -- mt
L["Other crafters"] = "Otros artesanos" -- mt
L["No profession here makes buff items."] = "Ninguna profesión crea objetos de beneficio." -- mt
L["Latest TradeSkillMaster prices."] = "Precios más recientes de TradeSkillMaster." -- mt
L["TradeSkillMaster"] = "TradeSkillMaster" -- mt
L["TradeSkillMaster has no price for these reagents: update its AuctionDB with the TSM desktop app."] =
	"TradeSkillMaster no tiene precio para estos componentes: actualiza su AuctionDB con la aplicación de escritorio de TSM." -- mt
L["Update TradeSkillMaster's AuctionDB with the TSM desktop app, or visit a vendor, to price reagents."] =
	"Actualiza la AuctionDB de TradeSkillMaster con la aplicación de escritorio de TSM, o visita a un vendedor, para poner precio a los componentes." -- mt
L["Waiting for Questie to finish loading."] = "Esperando a que Questie termine de cargar."
L["Nothing is tracked for %s."] = "No se sigue nada para %s." -- mt
L["+%d more to train"] = "+%d más por aprender" -- mt
L["Also train"] = "También aprender" -- mt
L["Auctionator list: %s. Open the auction house, Shopping tab, pick it and Search; buy each row with a click."] =
	"Lista de Auctionator: %s. Abre la casa de subastas, la pestaña Compras, elige la lista y Buscar; compra cada fila con un clic."
L["On (the default), a reagent you could gather, fish or loot from creatures is bought at a vendor or the auction house. Off, getting it yourself costs nothing."] =
	"Activado (predeterminado): un reactivo que podrías recolectar, pescar o saquear de criaturas se compra en un vendedor o en la casa de subastas. Desactivado: conseguirlo tú mismo no cuesta nada."
L["On (the default), a reagent you could gather, fish or loot from creatures is bought at a vendor or the auction house. Off, getting it yourself costs what it would sell for."] =
	"Activado (predeterminado): un reactivo que podrías recolectar, pescar o saquear de criaturas se compra en un vendedor o en la casa de subastas. Desactivado: conseguirlo tú mismo cuesta lo que se vendería por él."
L["Shift + wheel, or drag, scrolls the timeline sideways."] =
	"Mayús + rueda, o arrastrar, desplaza la línea de tiempo lateralmente."
L["SkillUp's list"] = "Lista de SkillUp"
L["Timeline"] = "Línea de tiempo"
L["Turning Buy reagents on writes an Auctionator list with every auction reagent still missing."] =
	"Activar Comprar reactivos escribe una lista de Auctionator con todos los reactivos de subasta que aún faltan."
L["Without Auctionator, a recipe's Search button fills the game's own auction box one reagent at a time."] =
	"Sin Auctionator, el botón Buscar de una receta llena la caja de subastas del juego con un reactivo a la vez."
L["%s needs ForeverCore. Install it from CurseForge, or choose Reinstall on ForeverCore in the CurseForge app."] =
	"%s necesita ForeverCore. Instálalo desde CurseForge o elige Reinstalar en ForeverCore en la aplicación de CurseForge." -- mt
L["%s: the installed ForeverCore is another addon (%s). Remove it and install ForeverCore from CurseForge."] =
	"%s: el ForeverCore instalado es otro addon (%s). Elimínalo e instala ForeverCore desde CurseForge." -- mt
L["%s: ForeverCore is turned off. Enable it in the AddOns list to fix this."] =
	"%s: ForeverCore está desactivado. Actívalo en la lista de addons para solucionarlo." -- mt
L["%s: %s is out of date. Update it to fix this."] = "%s: %s está desactualizado. Actualízalo para solucionarlo." -- mt
L["%s: %s are out of date. Update them to fix this."] =
	"%s: %s están desactualizados. Actualízalos para solucionarlo." -- mt
L["%s could not start. Reinstall %s to fix this."] = "%s no pudo iniciarse. Reinstala %s para solucionarlo." -- mt
L["Region sale average"] = "Media regional de ventas"
L["Region sale average if higher"] = "Media regional de ventas si es mayor"
L["Region sale averages need TradeSkillMaster and its desktop app. They estimate value from reported regional sales and purchases, with the vendor price as a floor. They do not guarantee a sale."] =
	"Las medias regionales de ventas requieren TradeSkillMaster y su aplicación de escritorio. Estiman el valor con compras y ventas regionales registradas, con el precio de venta al vendedor como mínimo. No garantizan una venta."

L["Counts include spares for an estimated %d%% chance to finish the whole route."] =
	"Las cantidades incluyen reservas para una probabilidad estimada del %d%% de completar toda la ruta." -- mt
L["Restock visit cost"] = "Coste de una visita de reabastecimiento" -- mt
L["Not counted"] = "No contabilizado" -- mt
L["What one trip to buy more reagents is worth, in copper, when a run takes more crafts than planned. It is added to that reagent's purchase price only when it happens. Leave it at zero to count no trip."] =
	"Cuánto vale en cobre un viaje para comprar más componentes cuando una tanda necesita más fabricaciones de las previstas. Solo se suma al precio de compra de ese componente cuando ocurre. Déjalo en cero para no contar ningún viaje." -- mt
L["%s (%s)"] = "%s (%s)"
L["%s profit per craft"] = "%s de beneficio por creación"
L["%s profit per skill-up"] = "%s de beneficio por subida de habilidad"
L["Auction price"] = "Precio de subasta"
L["Auction prices from"] = "Precios de subasta de"
L["Auctionator"] = "Auctionator"

L["Skill %d to %d, %s"] = "Habilidad de %d a %d, %s" -- mt
L["Skill %d to %d, %s, at %s"] = "Habilidad de %d a %d, %s, en %s" -- mt
L["%s, uses materials you have"] = "%s, usa materiales que ya tienes" -- mt
L["Unlearned recipe order"] = "Orden de recetas sin aprender" -- mt
L["How recipes you have not learned are ordered. Learned recipes keep the selected recipe order."] =
	"Orden de las recetas que aún no has aprendido. Las recetas aprendidas conservan el orden seleccionado." -- mt
L["TSM regional sales per day"] = "Ventas regionales por día según TSM" -- mt
L["Average sold per auction house in your region, reported by TSM."] =
	"Cantidad media vendida por casa de subastas en tu región, según TSM." -- mt

L["Open %s from your spellbook."] = "Abre %s desde tu libro de hechizos."

L["Recipes on Shift"] = "Recetas con Mayús" -- mt
L["Show recipes on Shift or always. Off hides reagent details, including route needs."] =
	"Muestra recetas con Mayús o siempre. Desactivado oculta los detalles de componentes, incluidas las necesidades de las rutas." -- mt
L["Show route needs on item tooltips"] = "Mostrar necesidades de las rutas en las descripciones de objetos" -- mt
L["Show how much of an item your tracked routes still need. Turn this off to keep recipe details without the route line."] =
	"Muestra cuánto de un objeto necesitan todavía tus rutas seguidas. Desactívalo para conservar los detalles de recetas sin la línea de ruta." -- mt

L["Have (bags only)"] = "Tienes (solo bolsas)" -- mt

L["%s%% to %s%%"] = "De %s%% a %s%%" -- mt
L["Adds an estimated 4 percentage points per Working Overtime rank to yellow and green skill-up chances. Whether the game adds the talent's bonus as points or multiplies the chance by it is not confirmed yet, so this starts off and chances use the base formula."] =
	"Añade una estimación de 4 puntos porcentuales por cada rango de Working Overtime a las probabilidades de subir habilidad con recetas amarillas y verdes. Aún no se ha confirmado si el juego suma la bonificación del talento como puntos o multiplica la probabilidad, así que empieza desactivado y las probabilidades usan la fórmula base." -- mt
L["Chance of finishing with later purchases: %s."] = "Probabilidad de terminar con compras posteriores: %s." -- mt
L["Chance of finishing with starting supplies: %s."] = "Probabilidad de terminar con los suministros iniciales: %s." -- mt
L["Craft counts and shopping quantities are estimates. You may need more reagents."] =
	"Las cantidades de fabricaciones y compras son estimaciones. Puede que necesites más componentes." -- mt
L["Craft next follows the estimated route."] = "Crear la siguiente sigue la ruta estimada." -- mt
L["Include Working Overtime estimate"] = "Incluir estimación de Working Overtime" -- mt
L["Starting inventory: bags and bank."] = "Inventario inicial: bolsas y banco." -- mt
L["Starting inventory: bags only."] = "Inventario inicial: solo bolsas." -- mt
L["Supply estimate: calculating."] = "Estimación de suministros: calculando." -- mt
L["Supply estimate: cancelled."] = "Estimación de suministros: cancelada." -- mt
L["Supply estimate: no cheapest purchase exists under these assumptions."] =
	"Estimación de suministros: no existe una compra de coste mínimo con estas suposiciones." -- mt
L["Supply estimate: no starting purchase meets the target."] =
	"Estimación de suministros: ninguna compra inicial alcanza el objetivo." -- mt
L["Supply estimate: not enough information."] = "Estimación de suministros: información insuficiente." -- mt
L["Supply estimate: ready."] = "Estimación de suministros: lista." -- mt
L["Target chance of finishing with starting supplies: %s%%."] =
	"Probabilidad objetivo de terminar con los suministros iniciales: %s%%." -- mt
L["These chances assume the stated skill-up rates, prices, availability and delivery of later purchases."] =
	"Estas probabilidades presuponen las tasas de subida de habilidad, los precios, la disponibilidad y la entrega de compras posteriores indicados." -- mt
L["unknown"] = "desconocido" -- mt

L["Adaptive guidance opens the recommended recipe. Choose how many to craft in the profession window."] =
	"La guía adaptativa abre la receta recomendada. Elige cuántas unidades fabricar en la ventana de profesión." -- mt

L["currency %d"] = "moneda %d" -- mt
L["an unknown payment"] = "un pago desconocido" -- mt
L["Name the stock each offer draws on, or give this offer its own stock."] =
	"Nombrad las existencias de las que sale cada oferta, o dadle existencias propias." -- mt
L["The merchant shows no limit: limit the search to the number you will buy."] =
	"El mercader no muestra límite: limitad la búsqueda a la cantidad que compraréis." -- mt
L["The stock you assume does not match what the merchant shows."] =
	"Las existencias que suponéis no coinciden con lo que muestra el mercader." -- mt
L["Enter a starting chance between 1 and 100."] = "Introducid una probabilidad inicial entre 1 y 100." -- mt
L["The merchant sells none of this route's reagents."] = "El mercader no vende ningún reagente de esta ruta." -- mt
L["The merchant's offer for %s is incomplete."] = "La oferta del mercader para %s está incompleta." -- mt
L["Every offer needs its price to stay as shown."] = "Cada oferta necesita que su precio siga como se muestra." -- mt
L["Fill in every value this offer needs."] = "Rellenad cada valor que necesita esta oferta." -- mt
L["The merchant sells fewer purchases at a time than that."] = "El mercader vende menos compras a la vez que eso." -- mt
L["Offers that draw on one stock pool need the same stock."] =
	"Las ofertas que salen de un mismo montón necesitan las mismas existencias." -- mt
L["Offers at one vendor need the same trip costs and values."] =
	"Las ofertas de un mismo mercader necesitan los mismos costes y valores de viaje." -- mt
L["Enter the chance each later purchase arrives, from 0 to 100."] =
	"Introducid la probabilidad de que llegue cada compra posterior, de 0 a 100." -- mt
L["Check that the first purchase arrives for certain at every offer."] =
	"Marcad que la primera compra llega con seguridad en cada oferta." -- mt
L["One item or payment needs one leftover value."] = "Un objeto o un pago necesita un valor residual." -- mt
L["Offers that use one payment need the same value for it."] =
	"Las ofertas que usan un mismo pago necesitan el mismo valor para él." -- mt
L["The merchant changed. Check the form again."] = "El mercader ha cambiado. Revisad el formulario otra vez." -- mt
L["The merchant did not change, but the assumptions did. Check the form again."] =
	"El mercader no ha cambiado, pero las suposiciones sí. Revisad el formulario otra vez." -- mt
L["The merchant shows this offer sold out."] = "El mercader muestra esta oferta agotada." -- mt
L["The merchant does not say how much is left."] = "El mercader no dice cuánto queda." -- mt
L["The merchant will not sell this offer to you now."] = "El mercader no os venderá esta oferta ahora." -- mt
L["Choose the unit the stock count is in."] = "Elegid la unidad del recuento de existencias." -- mt
L["The assumptions were rejected. Fill in every value and check each offer."] =
	"Las suposiciones fueron rechazadas. Rellenad cada valor y revisad cada oferta." -- mt
L["Open a profession to see its plan and coverage."] = "Abrid una profesión para ver su plan y su cobertura." -- mt
L["Plan: %s, %s to %s, %d crafts."] = "Plan: %s, %s a %s, %d fabricaciones." -- mt
L["Unpriced crafts: %d."] = "Fabricaciones sin precio: %d." -- mt
L["Your target chance: %s%%."] = "Vuestra probabilidad objetivo: %s%%." -- mt
L["Margin over your target: %s points."] = "Margen sobre vuestro objetivo: %s puntos." -- mt
L["Below your target by %s points."] = "Por debajo de vuestro objetivo en %s puntos." -- mt
L["craft"] = "fabricar" -- mt
L["buy"] = "comprar" -- mt
L["stop"] = "parar" -- mt
L["Next step: %s."] = "Siguiente paso: %s." -- mt
L["Open a profession to set its supply policy."] = "Abrid una profesión para fijar su política de suministro." -- mt
L["This profession has no plan to supply yet."] = "Esta profesión aún no tiene un plan que abastecer." -- mt
L["Open a merchant to set this profession's supply policy."] =
	"Abrid un mercader para fijar la política de suministro de esta profesión." -- mt
L["Ready to apply these assumptions."] = "Listo para aplicar estas suposiciones." -- mt
L["no limit"] = "sin límite" -- mt
L["Offer %d: %s"] = "Oferta %d: %s" -- mt
L["The merchant shows %s in stock, %s per purchase, at most %s purchases."] =
	"El mercader muestra %s en existencias, %s por compra, como mucho %s compras." -- mt
L["Price: %s."] = "Precio: %s." -- mt
L["Also costs %s %s."] = "También cuesta %s %s." -- mt
L["I can buy this offer"] = "Puedo comprar esta oferta" -- mt
L["The price stays as shown"] = "El precio se queda como se muestra" -- mt
L["Stock I assume is left"] = "Existencias que supongo que quedan" -- mt
L["The stock does not run out"] = "Las existencias no se agotan" -- mt
L["The stock count is in items, not purchases"] = "El recuento de existencias es en objetos, no en compras" -- mt
L["This offer keeps its own stock"] = "Esta oferta conserva sus propias existencias" -- mt
L["Limit the search to the stock I typed"] = "Limitar la búsqueda a las existencias que escribí" -- mt
L["Stock pool name"] = "Nombre del montón de existencias" -- mt
L["Purchases allowed per visit"] = "Compras permitidas por visita" -- mt
L["First trip cost (copper)"] = "Coste del primer viaje (cobre)" -- mt
L["Later trip cost (copper)"] = "Coste de viajes posteriores (cobre)" -- mt
L["First trip value to you (copper)"] = "Valor del primer viaje para vosotros (cobre)" -- mt
L["Later trip value to you (copper)"] = "Valor de viajes posteriores para vosotros (cobre)" -- mt
L["Chance each later purchase arrives (%)"] = "Probabilidad de que llegue cada compra posterior (%)" -- mt
L["The first purchase arrives for certain"] = "La primera compra llega con seguridad" -- mt
L["I pay even when a purchase does not arrive"] = "Pago aunque una compra no llegue" -- mt
L["Leftover value of one %s (copper)"] = "Valor residual de un %s (cobre)" -- mt
L["Value of one %s (copper)"] = "Valor de un %s (cobre)" -- mt
L["These are your own assumptions. The merchant's window only shows what it shows now."] =
	"Estas son vuestras propias suposiciones. La ventana del mercader solo muestra lo que muestra ahora." -- mt
L["Chance of finishing with starting supplies (%)"] = "Probabilidad de terminar con las existencias iniciales (%)" -- mt
L["Plan later purchases too"] = "Planificar también las compras posteriores" -- mt
L["Cost of an unfinished route (copper)"] = "Coste de una ruta sin terminar (cobre)" -- mt
L["Applied. The plan and its coverage follow these assumptions."] =
	"Aplicado. El plan y su cobertura siguen estas suposiciones." -- mt
L["Supply"] = "Suministro" -- mt

L["Supply policy"] = "Política de suministro" -- mt
L["Open the profession and a merchant window."] = "Abrid la profesión y una ventana de mercader." -- mt
L["Apply policy"] = "Aplicar política" -- mt
L["No trainer of your faction teaches this recipe."] = "Ningún instructor de tu facción enseña esta receta." -- mt
L["%s (level %d)"] = "%s (nivel %d)" -- mt

L["Working Overtime's bonus is left out of chances by default."] =
	"La bonificación de Horas extra no se incluye en las probabilidades por defecto." -- mt

L["Highest craft profit"] = "Mayor beneficio por fabricación" -- mt

L["AHDB"] = "AHDB" -- mt

L["Naowh Forever"] = "Naowh Forever" -- mt

L["AHDB, %s"] = "AHDB, %s" -- mt

L["Naowh Forever, %s"] = "Naowh Forever, %s" -- mt

L["you loot it from creatures, would sell for %s"] = "lo despojas de criaturas, se vendería por %s" -- mt

L["you gather it (%s), would sell for %s"] = "lo recolectas (%s), se vendería por %s" -- mt

L["Scan the auction house with AHDB, or visit a vendor, to price reagents."] =
	"Escanea la casa de subastas con AHDB o visita un vendedor para obtener precios de componentes." -- mt

L["Update Naowh Forever's auction data, or visit a vendor, to price reagents."] =
	"Actualiza los datos de subastas de Naowh Forever o visita un vendedor para obtener precios de componentes." -- mt

L["Choose Auctionator, TradeSkillMaster, AHDB or Naowh Forever. The chosen price wins; the others fill gaps. Tooltips show the observation's age when known."] =
	"Elige Auctionator, TradeSkillMaster, AHDB o Naowh Forever. El precio elegido tiene prioridad; los demás rellenan los huecos. Las descripciones muestran la antigüedad del dato cuando se conoce." -- mt

L["Sort recipes in one list, learned first, then unlearned. Highest craft profit includes grey recipes. Default restores categories."] =
	"Ordena las recetas en una lista, primero las aprendidas y luego las no aprendidas. Mayor beneficio por fabricación incluye recetas grises. Predeterminado restaura las categorías." -- mt

L["These reagents have no vendor price. Auction prices need Auctionator, TradeSkillMaster, AHDB or Naowh Forever."] =
	"Estos componentes no tienen precio de vendedor. Los precios de subasta necesitan Auctionator/TradeSkillMaster, AHDB, Naowh Forever." -- mt
