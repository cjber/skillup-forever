-- Machine translated (2026-10-16); corrections welcome: https://github.com/cjber/skillup-forever/issues/new?template=translation.yml
local _, ns = ...
if GetLocale() ~= "deDE" then
	return
end
local L = ns.L

L["%d %s"] = "%d %s"
L["%d crafts to %d, %s"] = "%d-mal herstellen bis %d, %s"
L["%d crafts to %d, %s, at %s"] = "%d-mal herstellen bis %d, %s, an: %s"
L["%d more"] = "%d weitere"
L["%d to %d"] = "%d bis %d"
L["%d, from %d to %d"] = "%d, von %d bis %d"
L["%dd ago"] = "vor %d T."
L["%s %d"] = "%s %d"
L["%s (%d): bundled %d, classic-db %d"] = "%s (%d): mitgeliefert %d, classic-db %d"
L["%s (%d): bundled %s, the trainer wants %d"] = "%s (%d): mitgeliefert %s, der Lehrer verlangt %d"
L["%s (unlearned)"] = "%s (nicht erlernt)"
L["%s is at %s."] = "%s ist bei %s."
L["%s is in %s."] = "%s ist in %s."
L["%s trainer"] = "Lehrer für %s"
L["%s until %d"] = "%s bis %d"
L["%s, %d"] = "%s, %d"
L["%s, %d/%d"] = "%s, %d/%d"
L["%s, %s, to %d"] = "%s, %s, bis %d"
L["%s, source unknown"] = "%s, Quelle unbekannt"
L["%s: %d moved, %d confirmed at a trainer, %d wrong."] = "%s: %d verschoben, %d beim Lehrer bestätigt, %d falsch."
L["+%d more"] = "+%d weitere"
L["/su skipped lists the recipes you skipped, with their IDs."] =
	"/su skipped listet die übersprungenen Rezepte mit ihren IDs auf."
L["/su unskip <recipe ID> shows one again, /su unskip all every one."] =
	"/su unskip <recipe ID> zeigt eines wieder an, /su unskip all alle."
L["A Reagents tab on a merchant's window that lists the reagents your tracked routes still need from that merchant and their total cost. Buy them from the merchant's own window."] =
	"Ein Reiter „Reagenzien“ am Händlerfenster, der die Reagenzien auflistet, die Eure verfolgten Routen bei diesem Händler noch brauchen, samt Gesamtkosten. Kauft sie im Fenster des Händlers selbst."
L["A material your professions gather costs what selling it would bring instead of nothing: its auction price after the 5% cut, or its vendor sell price if that is more. Used for the route and the costs on recipe rows. Auction prices need Auctionator or TradeSkillMaster."] =
	"Ein Material, das Eure Berufe sammeln, kostet, was sein Verkauf einbrächte, statt nichts: sein Auktionspreis nach 5 % Gebühr oder sein Verkaufspreis beim Händler, falls höher. Gilt für die Route und die Kosten in den Rezeptzeilen. Auktionspreise brauchen Auctionator/TradeSkillMaster."
L["Keeps the shared Forever tracker where you put it. The grip at its top no longer drags it."] =
	"Hält die gemeinsame Forever-Verfolgung dort, wo Ihr sie hingelegt habt. Der Griff oben zieht sie nicht mehr."
L["Lock the tracker"] = "Verfolgung sperren"
L["Tracker background"] = "Hintergrund der Verfolgung"

L["Show thresholds bar on the recipe"] = "Fertigkeitsbalken beim Rezept anzeigen" -- mt
L["The Forever addons are free, with nothing locked behind them. If they help, you can buy me a coffee."] =
	"Die Forever-Addons sind kostenlos, und nichts ist hinter einer Bezahlung versteckt. Wenn sie Euch helfen, könnt Ihr mir einen Kaffee spendieren." -- mt
L["The orange, yellow, green and grey thresholds and where your skill sits, under the recipe in the Professions window. Turn it off if it covers the reagents."] =
	"Die orangen, gelben, grünen und grauen Schwellen und wo Eure Fertigkeit liegt, unter dem Rezept im Berufsfenster. Ausschalten, wenn er die Reagenzien verdeckt." -- mt
L["AH"] = "AH"
L["Add the start of each recipe's difficulty range. This is separate from the skill needed to learn it."] =
	"Zeigt den Beginn des Schwierigkeitsbereichs jedes Rezepts. Das ist nicht die Fertigkeit, die zum Erlernen nötig ist."
L["Addon"] = "Addon"
L["Adventure Guide Forever can plan this quest chain."] = "Adventure Guide Forever kann diese Questreihe planen."
L["Also for this slot"] = "Auch für diesen Platz"
L["Annotate trainer recipes"] = "Lehrerrezepte ergänzen"
L["Another craft makes this recipe, not yours."] = "Ein anderer Beruf stellt dies her, nicht Eurer."
L["Another crafter"] = "Anderer Hersteller"
L["At the %d cap: no trainer teaches the next rank."] = "Am Maximum von %d: Kein Lehrer lehrt den nächsten Rang."
L["At the cursor"] = "Am Mauszeiger"
L["AtlasLoot is installed but not running: enable it in the AddOns list, or update it if out of date."] =
	"AtlasLoot ist installiert, läuft aber nicht: Aktiviert es in der Addon-Liste oder aktualisiert es, falls veraltet."
L["Attach to quest tracker"] = "An Questzielverfolgung anheften"
L["Auction house"] = "Auktionshaus"
L["Auction price if higher"] = "Auktionspreis, falls höher"
L["Auctionator hasn't seen these reagents yet: scan the auction house with it to price them."] =
	"Auctionator kennt diese Reagenzien noch nicht: Durchsucht damit das Auktionshaus, um sie zu bepreisen."
L["Auctionator's scan when the auction house opens is off: turn it on in Auctionator, Basic Options."] =
	"Auctionators Scan beim Öffnen des Auktionshauses ist aus: Schaltet ihn in Auctionator unter „Basic Options“ ein."
L["Auctionator, %s"] = "Auctionator, %s"
L["Back"] = "Rücken"
L["Beside the Professions window"] = "Neben dem Berufsfenster"
L["Buy %d %s"] = "%d %s kaufen"
L["Buy %s"] = "%s kaufen" -- mt
L["Buy %s at %d"] = "%s bei %d kaufen" -- mt
L["Buy all"] = "Alle kaufen"
L["Buy and read %s at %d"] = "%s kaufen und bei %d lesen"
L["Buy and read %s at %d (level %d)"] = "%s kaufen und bei %d lesen (Stufe %d)"
L["Buy reagents"] = "Reagenzien kaufen"
L["Buy reagents at the auction house"] = "Reagenzien im Auktionshaus kaufen"
L["Can learn it"] = "Erlernbar"
L["Cheapest skill-up"] = "Günstigster Fertigkeitspunkt"
L["Chest"] = "Brust"
L["Click for a waypoint to %s."] = "Klickt für einen Wegpunkt zu %s."
L["Click for a waypoint."] = "Klickt für einen Wegpunkt."
L["Click to craft %d."] = "Klickt, um %d herzustellen."
L["Click to open the recipe."] = "Klickt, um das Rezept zu öffnen."
L["Click to show a recipe again."] = "Klickt, um ein Rezept wieder anzuzeigen."
L["Close"] = "Schließen"
L["Complete %s at %d"] = "%s bei %d abschließen"
L["Complete %s at %d (level %d)"] = "%s bei %d abschließen (Stufe %d)"
L["Complete %s first: you're at your cap."] = "Schließt zuerst %s ab: Ihr seid am Maximum."
L["Copy link"] = "Link kopieren"
L["Copy the address, then open it in your browser."] = "Kopiert die Adresse und öffnet sie dann in Eurem Browser."
L["Cost"] = "Kosten"
L["Count what crafts sell for"] = "Verkaufswert der Herstellungen anrechnen"
L["Craft %d %s"] = "%d %s herstellen"
L["Craft %d of %d× %s"] = "%d von %d× %s herstellen"
L["Craft %d× %s"] = "%d× %s herstellen"
L["Craft %s"] = "%s herstellen"
L["Craft next"] = "Als Nächstes herstellen"
L["Crafted gear"] = "Hergestellte Ausrüstung"
L["Crafts"] = "Herstellungen"
L["Don't count it"] = "Nicht anrechnen"
L["Don't suggest this again"] = "Nicht mehr vorschlagen"
L["Drag to move"] = "Ziehen zum Verschieben"
L["Dropped by"] = "Erbeutet von"
L["Each"] = "Je"
L["Each click puts the next one in the search box; press Search."] =
	"Jeder Klick setzt das nächste ins Suchfeld; dann auf „Suchen“ klicken."
L["Enable Shortest Path Forever for walked routes and boat times."] =
	"Aktiviert Shortest Path Forever für Laufwege und Schiffszeiten."
L["Every recipe that uses it"] = "Jedes Rezept, das es nutzt"
L["Fee"] = "Gebühr"
L["Fee %s, requires %s (%d)"] = "Gebühr %s, benötigt %s (%d)"
L["Feet"] = "Füße"
L["Finger"] = "Finger"
L["First used at"] = "Zuerst gebraucht bei"
L["Forever addons"] = "Forever-Addons"
L["Forever tracker"] = "Forever-Verfolgung"
L["Gather %d %s"] = "%d %s sammeln"
L["Gathering skill on nodes"] = "Sammelfertigkeit an Vorkommen"
L["Hands"] = "Hände"
L["Have (bags and bank)"] = "Vorhanden (Taschen und Bank)"
L["Head"] = "Kopf"
L["Herb and ore node tooltips show the skill they need and its colour at yours (English client only). Skinnable corpses show ? until the skinning rule is confirmed on Forever."] =
	"Tooltips von Kräutern und Erzvorkommen zeigen die nötige Fertigkeit und ihre Farbe bei Eurer (nur im englischen Client). Kürschnerbare Leichen zeigen ?, bis die Kürschnerregel auf Forever bestätigt ist."
L["Hide this section"] = "Diesen Abschnitt ausblenden"
L["Install AtlasLoot to see the recipes vendors, quests and drops would add."] =
	"Installiert AtlasLoot, um die Rezepte von Händlern, Quests und Beute zu sehen."
L["Install Questie and AtlasLoot to see where recipes, vendors and trainers are."] =
	"Installiert Questie und AtlasLoot, um zu sehen, wo Rezepte, Händler und Lehrer sind."
L["Install Questie to see vendors, quests and trainers, with waypoints to them."] =
	"Installiert Questie, um Händler, Quests und Lehrer mit Wegpunkten zu sehen."
L["Installed, turned off"] = "Installiert, deaktiviert"
L["Its trainer should teach these at your skill now:"] =
	"Der Lehrer sollte Euch bei Eurer Fertigkeit jetzt Folgendes lehren:"
L["Kept in the Auctionator list '%s'."] = "In der Auctionator-Liste „%s“ gespeichert."
L["Latest Auctionator prices."] = "Neueste Auctionator-Preise."
L["Latest Auctionator prices: rescan to update old prices."] =
	"Neueste Auctionator-Preise: Scannt erneut, um alte Preise zu erneuern."
L["Learn a crafting profession to plan a route."] = "Erlernt einen Herstellungsberuf, um eine Route zu planen."
L["Legs"] = "Beine"
L["Level %d"] = "Stufe %d"
L["Level %d %s"] = "Stufe %d %s"
L["Made at"] = "Hergestellt an"
L["Main hand"] = "Waffenhand"
L["Missing reagents for this step."] = "Für diesen Schritt fehlen Reagenzien."
L["Money on recipe rows"] = "Geld in Rezeptzeilen"
L["Nearest trainer"] = "Nächster Lehrer"
L["Nearest vendor"] = "Nächster Händler"
L["Neck"] = "Hals"
L["Need %d more %s"] = "Noch %d %s nötig"
L["Need a %s in your bags."] = "Ihr braucht %s in Euren Taschen."
L["Needs %s %d"] = "Benötigt %s %d"
L["Net per craft"] = "Netto pro Herstellung"
L["Newest recipes first"] = "Neueste Rezepte zuerst"
L["Next to the recipe"] = "Neben dem Rezept"
L["No crafted gear for your level and class yet."] = "Noch keine hergestellte Ausrüstung für Eure Stufe und Klasse."
L["No crafted gear you can make yet. Tick the box above to see gear you cannot make."] =
	"Noch keine Ausrüstung, die Ihr herstellen könnt. Setzt oben das Häkchen, um Ausrüstung zu sehen, die Ihr nicht herstellen könnt."
L["No skill data for this recipe yet."] = "Noch keine Fertigkeitsdaten für dieses Rezept."
L["No trainer teaches this rank: a book does."] = "Kein Lehrer lehrt diesen Rang: ein Buch."
L["No trainer teaches this rank: a quest does."] = "Kein Lehrer lehrt diesen Rang: eine Quest."
L["Not in this route: you chose Not this recipe."] =
	"Nicht in dieser Route: Ihr habt „Nicht dieses Rezept“ gewählt."
L["Not installed"] = "Nicht installiert"
L["Not this recipe"] = "Nicht dieses Rezept"
L["Nothing priced you know skills up past %d."] = "Nichts Bepreistes, das Ihr kennt, bringt Fertigkeit über %d."
L["Nothing to buy for this route."] = "Für diese Route ist nichts zu kaufen."
L["Nothing to craft on this route."] = "Auf dieser Route ist nichts herzustellen."
L["Nothing you know skills up past %d."] = "Nichts, das Ihr kennt, bringt Fertigkeit über %d."
L["Off hand"] = "Schildhand"
L["On"] = "An"
L["On %s"] = "Bei %s"
L["One line in chat the first time a new version loads."] =
	"Eine Chatzeile, wenn eine neue Version zum ersten Mal lädt."
L["Open"] = "Öffnen"
L["Open %s to craft from here."] = "Öffnet %s, um von hier aus herzustellen."
L["Open recipe"] = "Rezept öffnen"
L["Orange, yellow, green and grey thresholds when hovering a recipe."] =
	"Schwellen für Orange, Gelb, Grün und Grau beim Überfahren eines Rezepts."
L["Per craft"] = "Pro Herstellung"
L["Per skill-up"] = "Pro Fertigkeitspunkt"
L["Per skill-up is the cost of one skill point. Per craft is what one craft costs or earns, shown on recipes that no longer give skill too."] =
	"Pro Fertigkeitspunkt sind die Kosten für einen Punkt. Pro Herstellung ist, was eine Herstellung kostet oder einbringt, auch bei Rezepten, die keine Fertigkeit mehr geben."
L["Picks quests for your level and plans them into one journey."] =
	"Wählt Quests für Eure Stufe und plant sie zu einer Reise."
L["Plans the cheapest route to your next profession rank."] =
	"Plant den günstigsten Weg zu Eurem nächsten Berufsrang."
L["Plans the quickest way anywhere and guides you there, with live boat and zeppelin times."] =
	"Plant den schnellsten Weg überallhin und führt Euch dorthin, mit aktuellen Zeiten für Schiffe und Zeppeline."
L["Price"] = "Preis"
L["Price %s, requires %s (%d)"] = "Preis %s, benötigt %s (%d)"
L["Prices"] = "Preise"
L["Profession reagents"] = "Berufsreagenzien"
L["Profit per craft"] = "Gewinn pro Herstellung"
L["Profit per skill-up"] = "Gewinn pro Fertigkeitspunkt"
L["Quest"] = "Quest"
L["Quest automation, rare alerts and merchant handling for the default UI."] =
	"Questautomatik, Warnungen bei seltenen Gegnern und Händlerhilfe für die Standardoberfläche."
L["Quest giver"] = "Questgeber"
L["Quest, requires %s (%d)"] = "Quest, benötigt %s (%d)"
L["Raises your skill cap to %d."] = "Hebt Euer Fertigkeitsmaximum auf %d."
L["Ranged"] = "Distanz"
L["Read %s at %d"] = "%s bei %d lesen"
L["Read %s at %d (level %d)"] = "%s bei %d lesen (Stufe %d)"
L["Read %s first: you're at your cap."] = "Lest zuerst %s: Ihr seid am Maximum."
L["Reagent cost divided by skill-up chance, on recipe rows and in the tooltip. Common vendor reagents are priced from the start and updated at merchants you visit, reagents you gather are free unless you value them under Prices, and auction prices need Auctionator or TradeSkillMaster."] =
	"Reagenzkosten geteilt durch die Chance auf einen Fertigkeitspunkt, in Rezeptzeilen und im Tooltip. Gängige Händlerreagenzien haben von Anfang an einen Preis, der bei besuchten Händlern aktualisiert wird; gesammelte Reagenzien sind kostenlos, außer Ihr bewertet sie unter „Preise“; Auktionspreise brauchen Auctionator/TradeSkillMaster."
L["Reagent tooltips"] = "Reagenz-Tooltips"
L["Reagents"] = "Reagenzien"
L["Reagents  (have / need)"] = "Reagenzien  (vorhanden / nötig)"
L["Reagents for"] = "Reagenzien für"
L["Reagents in hand"] = "Reagenzien vorhanden"
L["Reagents still needed"] = "Noch nötige Reagenzien"
L["Recipe rows"] = "Rezeptzeilen"
L["Recipe tooltip position"] = "Position des Rezept-Tooltips"
L["Recipes from vendors, quests and drops that would carry it on:"] =
	"Rezepte von Händlern, Quests und Beute, mit denen es weitergeht:"
L["Required skill, skill-up chance and cost on profession trainer recipes, and which one is best to train next for your route."] =
	"Benötigte Fertigkeit, Chance auf Fertigkeitspunkt und Kosten bei Rezepten von Berufslehrern, und welches Ihr für Eure Route als Nächstes lernen solltet."
L["Requires"] = "Benötigt"
L["Route"] = "Route"
L["Route and trainer"] = "Route und Lehrer"
L["Route incomplete: %d recipes left out, their reagents not priced yet."] =
	"Route unvollständig: %d Rezepte ausgelassen, ihre Reagenzien haben noch keinen Preis."
L["Route needs"] = "Route braucht"
L["Route: %d/%d · %s to %d"] = "Route: %d/%d · %s bis %d"
L["Scan the auction house with Auctionator, or visit a vendor, to price reagents."] =
	"Durchsucht das Auktionshaus mit Auctionator oder besucht einen Händler, um Reagenzien zu bepreisen."
L["Scroll"] = "Rezept"
L["Search"] = "Suchen"
L["Search reagents at the auction house"] = "Reagenzien im Auktionshaus suchen"
L["Sells for"] = "Verkaufswert"
L["Sells for x%g"] = "Verkaufswert x%g"
L["Set waypoint"] = "Wegpunkt setzen"
L["Shift-click to link the scroll."] = "Umschalt-Klick, um das Rezept zu verlinken."
L["Shift: used in %d of your recipes"] = "Umschalt: in %d Eurer Rezepte verwendet"
L["Shoulder"] = "Schulter"
L["Show a quiet line where one of my other Forever addons would help. Only for addons you don't have."] =
	"Zeigt eine unauffällige Zeile, wo eines meiner anderen Forever-Addons helfen würde. Nur für Addons, die Ihr nicht habt."
L["Show again: %s"] = "Wieder angezeigt: %s"
L["Show cost per skill-up"] = "Kosten pro Fertigkeitspunkt zeigen"
L["Show gear I cannot make yet"] = "Auch nicht herstellbare Ausrüstung zeigen"
L["Show profession routes in the objective tracker. Hiding them keeps your tracked professions and targets."] =
	"Berufsrouten in der Questzielverfolgung zeigen. Ausblenden behält Eure verfolgten Berufe und Ziele."
L["Show skill on recipe rows"] = "Fertigkeit in Rezeptzeilen zeigen"
L["Show skill range start on rows"] = "Bereichsbeginn in Zeilen zeigen"
L["Show the merchant Reagents tab"] = "Reiter „Reagenzien“ beim Händler anzeigen"
L["Show the crafted gear tab"] = "Reiter „Hergestellte Ausrüstung“ zeigen"
L["Show the levelling route tab"] = "Reiter „Leveling-Route“ zeigen"
L["Show thresholds tooltip"] = "Schwellen-Tooltip zeigen"
L["Show tracked professions"] = "Verfolgte Berufe zeigen"
L["Shows the Legacy challenges you can advance in each zone."] =
	"Zeigt die Vermächtnis-Herausforderungen, die Ihr in jeder Zone voranbringen könnt."
L["Skill  %d/%d     Target"] = "Fertigkeit  %d/%d     Ziel"
L["Skill points a craft"] = "Fertigkeitspunkte pro Herstellung"
L["Skill range start"] = "Bereichsbeginn"
L["Skill range starts at %d"] = "Bereich beginnt bei %d"
L["Skill-up chance"] = "Chance auf Fertigkeitspunkt"
L["Skill-up chance and cost per skill-up at the right of each recipe."] =
	"Chance auf Fertigkeitspunkt und Kosten pro Punkt rechts neben jedem Rezept."
L["Skill-up chance: %d%%"] = "Chance auf Fertigkeitspunkt: %d%%"
L["SkillUp report"] = "SkillUp-Bericht"
L["Skipped (%d)"] = "Übersprungen (%d)"
L["Skipped (%d):"] = "Übersprungen (%d):"
L["Sold by"] = "Verkauft von"
L["Sort by"] = "Sortieren nach"
L["Sort recipes"] = "Rezepte sortieren"
L["Sort recipes in one list, learned first, then unlearned. Default restores categories."] =
	"Rezepte in einer Liste sortieren, erst erlernte, dann nicht erlernte. „Standard“ stellt die Kategorien wieder her."
L["Source"] = "Quelle"
L["Source unknown"] = "Quelle unbekannt"
L["Stop tracking"] = "Nicht mehr verfolgen"
L["Subtract what the crafted item sells for from its cost. Auction prices need Auctionator or TradeSkillMaster, are after the 5% cut, and may not sell."] =
	"Zieht den Verkaufswert des hergestellten Gegenstands von seinen Kosten ab. Auktionspreise brauchen Auctionator/TradeSkillMaster, gelten nach 5 % Gebühr und verkaufen sich vielleicht nicht."
L["Suggest my other Forever addons"] = "Meine anderen Forever-Addons vorschlagen"
L["Taught by %s trainers."] = "Gelehrt von Lehrern für %s."
L["The place this recipe is taught isn't known yet."] = "Wo dieses Rezept gelehrt wird, ist noch unbekannt."
L["The recipe list grows to the longest recipe name in the open profession, and the window with it, up to the room your screen has. Turn it off to keep the window's own width."] =
	"Die Rezeptliste wird so breit wie der längste Rezeptname im geöffneten Beruf, und das Fenster mit ihr, bis zur Breite Eures Bildschirms. Ausschalten behält die Fensterbreite des Spiels."
L["The rest comes from a vendor or your gathering."] = "Der Rest kommt von einem Händler oder aus Eurem Sammeln."
L["The route asks for %d to reach %d in 9 runs of 10; a worse run needs more."] =
	"Die Route rechnet mit %d, um in 9 von 10 Fällen %d zu erreichen; mit weniger Glück braucht Ihr mehr."
L["The source of this recipe isn't known."] = "Die Quelle dieses Rezepts ist unbekannt."
L["The text is selected. Press Ctrl+C (Cmd+C on a Mac) to copy it, then paste it into your bug report."] =
	"Der Text ist markiert. Drückt Strg+C (Cmd+C auf dem Mac) zum Kopieren und fügt ihn dann in Euren Fehlerbericht ein."
L["The tracker is locked. Turn off Lock the tracker to move it."] =
	"Die Verfolgung ist gesperrt. Schaltet Verfolgung sperren aus, um sie zu verschieben."
L["These reagents have no vendor price. Auction prices need Auctionator or TradeSkillMaster."] =
	"Diese Reagenzien haben keinen Händlerpreis. Auktionspreise brauchen Auctionator/TradeSkillMaster."
L["This addon"] = "Dieses Addon"
L["To buy"] = "Zu kaufen"
L["Tool"] = "Werkzeug"
L["Tooltips and sorting"] = "Tooltips und Sortierung"
L["Total %s"] = "Gesamt %s"
L["Track"] = "Verfolgen"
L["Tracked routes (Shift for all)"] = "Verfolgte Routen (Umschalt für alle)"
L["Train %s"] = "%s lernen"
L["Train %s at %d"] = "%s bei %d lernen"
L["Train %s at %d (level %d)"] = "%s bei %d lernen (Stufe %d)"
L["Train %s first."] = "Lernt zuerst %s."
L["Train %s first: you're at your cap."] = "Lernt zuerst %s: Ihr seid am Maximum."
L["Trinket"] = "Schmuck"
L["Turn this off to drag the shared Forever tracker anywhere on screen."] =
	"Schaltet dies aus, um die gemeinsame Forever-Verfolgung frei zu verschieben."
L["Update Questie to see vendors, quests and trainers, with waypoints to them."] =
	"Aktualisiert Questie, um Händler, Quests und Lehrer mit Wegpunkten zu sehen."
L["Used in"] = "Verwendet in"
L["Value gathered materials at what they'd sell for"] = "Gesammelte Materialien zum Verkaufswert rechnen"
L["Vendor"] = "Händler"
L["Vendor reagents"] = "Händlerreagenzien"
L["Vendor sell price"] = "Verkaufspreis beim Händler"
L["Visit a vendor to price reagents. Auction prices need Auctionator or TradeSkillMaster."] =
	"Besucht einen Händler, um Reagenzien zu bepreisen. Auktionspreise brauchen Auctionator/TradeSkillMaster."
L["Waist"] = "Taille"
L["Waypoint to a trainer"] = "Wegpunkt zu einem Lehrer"
L["Waypoint to a vendor: %s"] = "Wegpunkt zu einem Händler: %s"
L["Waypoint to the quest giver: %s"] = "Wegpunkt zum Questgeber: %s"
L["What hovering an item says about your professions: how much of it your tracked routes need (hold Shift for every recipe that uses it), every such recipe and its colour, or nothing."] =
	"Was ein Gegenstand beim Überfahren über Eure Berufe sagt: wie viel Eure verfolgten Routen davon brauchen (Umschalt halten für jedes Rezept, das ihn nutzt), jedes solche Rezept mit Farbe, oder nichts."
L["What's new after an update"] = "Neuerungen nach einem Update"
L["Where the tooltip goes when you hover a recipe. Beside the window, it stays clear of the reagents."] =
	"Wo der Tooltip erscheint, wenn Ihr mit der Maus über ein Rezept fahrt. Neben dem Fenster verdeckt er die Reagenzien nicht."
L["While the auction house is open, the Professions window offers a search for the selected recipe's reagents: as many as the crafts you choose still need after your bags and bank. Auctionator's shopping list carries the quantities; without it, each click puts the next reagent in the search box."] =
	"Bei offenem Auktionshaus bietet das Berufsfenster eine Suche nach den Reagenzien des gewählten Rezepts an: so viele, wie die gewählten Herstellungen nach Taschen und Bank noch brauchen. Auctionators Einkaufsliste übernimmt die Mengen; ohne sie setzt jeder Klick das nächste Reagenz ins Suchfeld."
L["Widen the recipe list to fit recipe names"] = "Rezeptliste an Rezeptnamen anpassen"
L["With Shortest Path Forever, a click leads you there."] = "Mit Shortest Path Forever führt Euch ein Klick dorthin."
L["With Shortest Path Forever, this picks the nearest by travel time and leads you there."] =
	"Mit Shortest Path Forever wählt dies den nach Reisezeit nächsten und führt Euch dorthin."
L["World drop"] = "Weltbeute"
L["Wrist"] = "Handgelenke"
L["You have it, requires %s (%d)"] = "Vorhanden, benötigt %s (%d)"
L["You have this book: read it."] = "Ihr habt dieses Buch: Lest es."
L["You know it"] = "Bekannt"
L["You: %d"] = "Ihr: %d"
L["Your bags allow %d of the route's %d."] = "Eure Taschen reichen für %d der %d der Route."
L["Your bags and bank have enough."] = "Eure Taschen und Bank haben genug."
L["can't identify the profession %s (%s); please report it."] = "Beruf %s (%s) nicht erkannt; bitte meldet das."
L["couldn't add tracked reagents to the objective tracker; please report it."] =
	"Verfolgte Reagenzien konnten nicht zur Questzielverfolgung hinzugefügt werden; bitte meldet das."
L["crafts"] = "Herstellungen"
L["drop"] = "Beute"
L["every skipped recipe is back in the route."] = "Alle übersprungenen Rezepte sind wieder in der Route."
L["files are missing: restart the game (not /reload) after updating."] =
	"Dateien fehlen: Startet das Spiel nach dem Update neu (nicht /reload)."
L["for %s"] = "für %s"
L["gather"] = "sammeln"
L["green"] = "grün"
L["grey"] = "grau"
L["item %d"] = "Gegenstand %d"
L["level %d"] = "Stufe %d"
L["makes %d %s"] = "stellt %d %s her"
L["no price"] = "kein Preis"
L["no skipped recipes: right-click a step on the route page and choose Not this recipe."] =
	"Keine übersprungenen Rezepte: Rechtsklickt einen Schritt auf der Routenseite und wählt „Nicht dieses Rezept“."
L["no trainer requirements to check."] = "Keine Lehreranforderungen zu prüfen."
L["none"] = "keine"
L["nothing to search for here: what's missing comes from a vendor or your gathering."] =
	"Hier gibt es nichts zu suchen: Was fehlt, kommt von einem Händler oder aus Eurem Sammeln."
L["open a profession first."] = "Öffnet zuerst einen Beruf."
L["open the auction house's Buy tab, then search again."] =
	"Öffnet den Reiter „Kaufen“ im Auktionshaus und sucht dann erneut."
L["orange"] = "orange"
L["over 3 weeks ago"] = "vor über 3 Wochen"
L["profession %d"] = "Beruf %d"
L["quest"] = "Quest"
L["recipe %d"] = "Rezept %d"
L["route set to %s, %s."] = "Route zu %s gesetzt, %s."
L["searching for %s: you need %d more."] = "Suche nach %s: Ihr braucht noch %d."
L["sorting failed and has been turned off: %s"] = "Sortierung fehlgeschlagen und ausgeschaltet: %s"
L["the %s book"] = "das Buch %s"
L["the %s quest"] = "die Quest %s"
L["the objective tracker isn't available, so tracked reagents can't be shown."] =
	"Die Questzielverfolgung ist nicht verfügbar, verfolgte Reagenzien können nicht angezeigt werden."
L["the reagent names are still loading; search again in a moment."] =
	"Die Reagenznamen laden noch; sucht gleich noch einmal."
L["today"] = "heute"
L["tracked, but the objective tracker section isn't attached; please report it."] =
	"Verfolgt, aber der Abschnitt in der Questzielverfolgung ist nicht angeheftet; bitte meldet das."
L["unknown age"] = "Alter unbekannt"
L["unknown location"] = "unbekannter Ort"
L["updated to %s. %s"] = "auf %s aktualisiert. %s"
L["vendor"] = "Händler"
L["waypoint set to %s, %s."] = "Wegpunkt zu %s gesetzt, %s."
L["world drop"] = "Weltbeute"
L["yellow"] = "gelb"
L["you gather it (%s)"] = "Ihr sammelt es (%s)"
L["you gather it (%s), valued at its AH price"] = "Ihr sammelt es (%s), zum AH-Preis bewertet"
L["you gather it (%s), valued at its vendor sell price"] = "Ihr sammelt es (%s), zum Händlerverkaufspreis bewertet"
L["your bags and bank already hold the reagents for that many."] =
	"Eure Taschen und Bank haben die Reagenzien dafür schon."
L["No step yet: learn or train a %s recipe that skills up."] =
	"Noch kein Schritt: lernt oder erlernt ein %s-Rezept, das Fertigkeit bringt."
L["%s (%s to %d)"] = "%s (%s bis %d)" -- mt
L["Buying for %s"] = "Einkauf für %s" -- mt
L["  %d items have no price yet"] = "  %d Gegenstände haben noch keinen Preis"
L["%d x %s - %s each"] = "%d x %s - je %s"
L["%d x %s - price unknown"] = "%d x %s - Preis unbekannt"
L["%s to %d"] = "%s bis %d"
L[", "] = ", "
L[", price seen %d days ago"] = ", Preis vor %d Tagen gesehen"
L["/su export - show the trainer requirements this character has seen, to paste into a report"] =
	"/su export - zeigt die Lehreranforderungen, die dieser Charakter gesehen hat, zum Einfügen in einen Bericht"
L["/su issue - report a bug or request a feature with a ready-made GitHub issue link"] =
	"/su issue - meldet einen Fehler oder wünscht eine Funktion, mit fertigem GitHub-Issue-Link"
L["/su report - show a report to copy into a bug report"] =
	"/su report - zeigt einen Bericht zum Kopieren in einen Fehlerbericht"
L[": "] = ": "
L["A buy trip needs Shortest Path Forever."] = "Eine Einkaufsreise braucht Shortest Path Forever."
L["Bug"] = "Fehler"
L["Bug: "] = "Fehler: "
L["Copy issue link"] = "Issue-Link kopieren"
L["Copy list"] = "Liste kopieren"
L["Copy report"] = "Bericht kopieren"
L["Feature request"] = "Funktionswunsch"
L["Feature request: "] = "Funktionswunsch: "
L["Gather"] = "Sammeln"
L["Need %d, have %d, missing %d  %s  %s each  %s"] = "Braucht %d, habt %d, fehlen %d  %s  je %s  %s"
L["No tracked profession"] = "Kein Beruf verfolgt"
L["Nothing is missing from the shopping list."] = "Auf der Einkaufsliste fehlt nichts."
L["Nothing to buy"] = "Nichts zu kaufen"
L["Plan buy trip"] = "Einkaufsreise planen"
L["Report a bug or request a feature"] = "Fehler melden oder Funktion wünschen"
L["Shopping list"] = "Einkaufsliste"
L["Shortest Path Forever cannot plan the full trip; setting a waypoint to the first vendor."] =
	"Shortest Path Forever kann die ganze Reise nicht planen; Wegpunkt zum ersten Händler wird gesetzt."
L["Shortest Path Forever is needed to plan this trip."] = "Für diese Reise wird Shortest Path Forever benötigt."
L["SkillUp Forever shopping list"] = "SkillUp Forever Einkaufsliste"
L["The link is selected. Press Ctrl+C (Cmd+C on a Mac), then paste into a browser; GitHub opens a filled-in issue."] =
	"Der Link ist markiert. Drückt Strg+C (Cmd+C auf dem Mac) und fügt ihn dann in einen Browser ein; GitHub öffnet ein vorausgefülltes Issue."
L["The text is selected. Press Ctrl+C (Cmd+C on a Mac) to copy it."] =
	"Der Text ist markiert. Drückt Strg+C (Cmd+C auf dem Mac), um ihn zu kopieren."
L["Title"] = "Titel"
L["Total for priced items: "] = "Gesamt für bepreiste Gegenstände: "
L["Unknown"] = "Unbekannt"
L["What happened, or what you would like"] = "Was passiert ist oder was Ihr Euch wünscht"
L["no trainer requirement seen yet: open a profession trainer, then try again."] =
	"noch keine Lehreranforderung gesehen: Öffnet einen Berufslehrer und versucht es dann erneut."
L["on %s"] = "bei %s"
L["price unknown"] = "Preis unbekannt"
L["Unpin recipe"] = "Rezept lösen" -- mt
L["Pin for skill-ups"] = "Für Fertigkeitspunkte anheften" -- mt
L["Right-click to pin or skip this recipe."] = "Rechtsklick zum Anheften oder Überspringen dieses Rezepts." -- mt
L["Unpin: %s"] = "Lösen: %s" -- mt
L["Pinned for skill-ups."] = "Für Fertigkeitspunkte angeheftet." -- mt
L["Skill range unknown."] = "Fertigkeitsbereich unbekannt." -- mt
L["Already grey: no skill-ups."] = "Bereits grau: keine Fertigkeitspunkte." -- mt
L["Requires skill %d."] = "Benötigt Fertigkeit %d." -- mt
L["Learn this recipe first."] = "Lernt zuerst dieses Rezept." -- mt
L["Reagents not priced yet."] = "Reagenzpreise noch unbekannt." -- mt
L["Outside this route or a newer pin takes priority."] =
	"Außerhalb dieser Route oder ein neueres angeheftetes Rezept hat Vorrang." -- mt
L["Pinned: %s"] = "Angeheftet: %s" -- mt
L["The newest pin takes priority where skill ranges overlap."] =
	"Bei überlappenden Fertigkeitsbereichen hat das zuletzt angeheftete Rezept Vorrang." -- mt
L["Pinned (%d)"] = "Angeheftet (%d)" -- mt
L["/su share on|off - control sharing with guild and group"] = "/su share on|off - Teilen mit Gilde und Gruppe steuern"
L["Share observed recipe totals with guild and group"] = "Beobachtete Rezeptsummen mit Gilde und Gruppe teilen"
L["(you)"] = "(du)"
L["All time"] = "Gesamte Zeit"
L["Forever Leaderboards"] = "Forever Leaderboards"
L["Forever standing"] = "Forever-Gesamtwertung"
L["Forever: %s overall"] = "Forever: %s insgesamt"
L["Forever: %s overall this week"] = "Forever: %s insgesamt diese Woche"
L["No one has reported yet."] = "Noch hat niemand etwas gemeldet."
L["Others' values are player-reported."] = "Werte anderer sind Spielerangaben."
L["Overall"] = "Gesamt"
L["Player"] = "Spieler"
L["Points for placing on each addon's board."] = "Punkte für einen Platz auf der Rangliste jedes Addons."
L["Rank"] = "Rang"
L["Recipes observed"] = "Beobachtete Rezepte"
L["Share my progress"] = "Meinen Fortschritt teilen"
L["This week"] = "Diese Woche"
L["Uses Forever addons"] = "Nutzt Forever-Addons"
L["Your guild and group"] = "Deine Gilde und Gruppe"
L["Players you've met"] = "Spieler, denen du begegnet bist" -- mt
L["boards"] = "Ranglisten"
L["1st"] = "1."
L["2nd"] = "2."
L["3rd"] = "3."
L["4th"] = "4."
L["5th"] = "5."
L["6th"] = "6."
L["7th"] = "7."
L["8th"] = "8."
L["board"] = "Liste"
L["/su leaderboard - open Forever Leaderboards on this addon's tab (also /su stats)"] =
	"/su leaderboard - öffnet Forever Leaderboards auf der Registerkarte dieses Addons (auch /su stats)"
L["total"] = "gesamt"
L["On by default. Turn off to stop sending and receiving totals and hide other players. Local observations stay."] =
	"Standardmäßig aktiv. Ausschalten beendet Senden und Empfangen und blendet andere Spieler aus. Lokale Beobachtungen bleiben erhalten."
L["crafted"] = "hergestellt" -- mt
L["List unlearned recipes"] = "Nicht erlernte Rezepte auflisten"
L["Adds the recipes of the open profession you have not learned under an Unlearned divider, greyed and marked with a trainer or recipe item and the skill it asks. They cannot be selected or crafted."] =
	"Fügt die Rezepte des geöffneten Berufs, die du noch nicht erlernt hast, unter einem Trenner „Nicht erlernt“ hinzu, ausgegraut und mit Lehrer oder Rezept und der verlangten Fertigkeit markiert. Sie lassen sich weder auswählen noch herstellen."
L["Not learned · %s"] = "Nicht erlernt · %s"
L["Trainer"] = "Lehrer"
L["Recipe item"] = "Rezept"
L["listing unlearned recipes failed: %s"] = "Auflisten nicht erlernter Rezepte fehlgeschlagen: %s"
L["Nothing on this route can be gathered, fished or looted by you, so the switch changes nothing for it."] =
	"Auf dieser Route könnt Ihr nichts sammeln, fischen oder von Kreaturen erbeuten, der Schalter ändert hier also nichts." -- mt
L["On, a reagent you could gather, fish or loot from creatures is priced at a vendor or the auction house. Off, getting it yourself costs nothing."] =
	"An: Ein Reagenz, das Ihr sammeln, fischen oder von Kreaturen erbeuten könntet, wird zum Händler- oder Auktionspreis gerechnet. Aus: Es selbst zu besorgen kostet nichts." -- mt
L["On, a reagent you could gather, fish or loot from creatures is priced at a vendor or the auction house. Off, getting it yourself costs what it would sell for."] =
	"An: Ein Reagenz, das Ihr sammeln, fischen oder von Kreaturen erbeuten könntet, wird zum Händler- oder Auktionspreis gerechnet. Aus: Es selbst zu besorgen kostet seinen Verkaufswert." -- mt
L["Loot %d %s from creatures"] = "%d %s von Kreaturen erbeuten" -- mt
L["you loot it from creatures"] = "Ihr erbeutet es von Kreaturen" -- mt
L["you loot it from creatures, valued at its AH price"] = "Ihr erbeutet es von Kreaturen, zum Auktionspreis bewertet" -- mt
L["you loot it from creatures, valued at its vendor sell price"] =
	"Ihr erbeutet es von Kreaturen, zum Händlerverkaufspreis bewertet" -- mt
L["Shift-click crafts all %d."] = "Umschalt-Klick stellt alle %d her." -- mt
L["The game's Craft button is not ready for this recipe."] =
	"Die Herstellen-Schaltfläche des Spiels ist für dieses Rezept nicht bereit." -- mt
L["vendor, limited stock"] = "Händler, begrenzter Vorrat" -- mt
L["Sells %d at a time"] = "Verkauft %d auf einmal" -- mt
L["This route is mostly %s: %d recipes are left out until their reagents are priced."] =
	"Diese Route besteht überwiegend aus %s: %d Rezepte bleiben ausgelassen, bis ihre Reagenzien einen Preis haben." -- mt
L["Price self-supplied reagents at auction values"] = "Price self-supplied reagents at auction values" -- mt
L["A reagent you gather, loot or already own costs what selling it would bring - its auction price after the 5% cut, or its vendor sell price if that is more - instead of counting as free. With no market price it stays unpriced rather than free. Auction prices need Auctionator or TradeSkillMaster."] =
	"A reagent you gather, loot or already own costs what selling it would bring - its auction price after the 5% cut, or its vendor sell price if that is more - instead of counting as free. With no market price it stays unpriced rather than free. Auction prices need Auctionator/TradeSkillMaster." -- mt

-- Shared debug log (Forever Core's Core/Log.lua).
L["Debug log is off."] = "Das Debug-Protokoll ist aus."
L["Debug log is on for this session."] = "Das Debug-Protokoll ist für diese Sitzung an."
L["Debug log is on and pinned for this character."] =
	"Das Debug-Protokoll ist an und für diesen Charakter dauerhaft aktiviert."
L["Debug log is already on and pinned for this character."] =
	"Das Debug-Protokoll ist bereits an und für diesen Charakter dauerhaft aktiviert."
L["Debug log is off for this session; it is still pinned."] =
	"Das Debug-Protokoll ist für diese Sitzung aus; es bleibt dauerhaft aktiviert."
L["Debug log is off and unpinned."] = "Das Debug-Protokoll ist aus und nicht mehr dauerhaft aktiviert."
L["No addon has attached its log yet."] = "Noch kein Addon hat sein Protokoll angehängt."
L["%s (last %d):"] = "%s (letzte %d):"
L["%s: no lines yet."] = "%s: noch keine Zeilen."
L["Usage: /forever debug, /forever debug pin, /forever debug off, /forever debug show"] =
	"Verwendung: /forever debug, /forever debug pin, /forever debug off, /forever debug show"
L["This menu needs mouse and keyboard."] = "Dieses Menü braucht Maus und Tastatur."
L["Only buffs for your level"] = "Nur Buffs für Eure Stufe"
L["Lists only the recipes whose product is a buff you can use at your level: elixirs, flasks, Well Fed food, protection potions, stones, oils and armour kits. Highest required level first. Learned recipes come first, then unlearned ones when those are listed."] =
	"Listet nur Rezepte, deren Ergebnis ein Buff ist, den Ihr auf Eurer Stufe nutzen könnt: Elixiere, Fläschchen, Sättigungsessen, Schutztränke, Schleifsteine, Öle und Rüstungssets. Höchste benötigte Stufe zuerst. Erlernte Rezepte zuerst, dann nicht erlernte, wenn diese aufgelistet werden."
L["%s: %s"] = "%s: %s" -- mt
L["%s drops in %s"] = "%s: Beute in %s" -- mt
L["Made by %s %d"] = "Hergestellt von %s %d" -- mt
L["Made by %s"] = "Hergestellt von %s" -- mt
L["%s at %d"] = "%s bei %d" -- mt
L["A tab at the bottom of the Professions window listing the buff consumables this profession makes, by the skill they unlock at and what each one is for. It opens from the SkillUp side tab, beside the route and crafted gear tabs."] =
	"Ein Reiter unten im Berufefenster, der die Stärkungsmittel dieses Berufs nach der Fertigkeit auflistet, ab der sie verfügbar sind, und wofür jedes gut ist. Er öffnet sich über den SkillUp-Seitenreiter, neben dem Routen- und dem Ausrüstungsreiter." -- mt
L["A tab at the bottom of the Professions window listing the newest crafted item this character can equip in each slot. It opens from the SkillUp side tab, beside the route and buffs tabs."] =
	"Ein Reiter unten im Berufefenster, der für jeden Platz den neuesten hergestellten Gegenstand zeigt, den dieser Charakter anlegen kann. Er öffnet sich über den SkillUp-Seitenreiter, neben dem Routen- und dem Stärkungsreiter." -- mt
L["A tab at the bottom of the Professions window with a route to your target skill and its reagents. It opens from the SkillUp side tab, beside the crafted gear and buffs tabs. Tracked professions stay in the objective tracker either way."] =
	"Ein Reiter unten im Berufefenster mit einer Route zu Eurer Zielfertigkeit und ihren Reagenzien. Er öffnet sich über den SkillUp-Seitenreiter, neben dem Ausrüstungs- und dem Stärkungsreiter. Verfolgte Berufe bleiben so oder so in der Questzielverfolgung." -- mt
L["Above your level"] = "Über Eurer Stufe" -- mt
L["Buffs"] = "Stärkungen" -- mt
L["Known"] = "Bekannt" -- mt
L["Later"] = "Später" -- mt
L["Learn now"] = "Jetzt lernen" -- mt
L["No buff items for your level yet."] = "Noch keine Stärkungsgegenstände für Eure Stufe." -- mt
L["Only for level %d"] = "Nur für Stufe %d" -- mt
L["Show the buffs tab"] = "Stärkungsreiter anzeigen" -- mt
L["SkillUp"] = "SkillUp" -- mt
L["This profession makes no buff items."] = "Dieser Beruf stellt keine Stärkungsgegenstände her." -- mt
L["spell %d"] = "Zauber %d" -- mt
L["Buffs by %s skill"] = "Stärkungen durch %s" -- mt
L["Skill  %d/%d"] = "Fertigkeit  %d/%d" -- mt
L["Other crafters"] = "Andere Handwerker" -- mt
L["No profession here makes buff items."] = "Kein Beruf stellt hier Stärkungsgegenstände her." -- mt
L["Latest TradeSkillMaster prices."] = "Neueste TradeSkillMaster-Preise." -- mt
L["TradeSkillMaster"] = "TradeSkillMaster" -- mt
L["TradeSkillMaster has no price for these reagents: update its AuctionDB with the TSM desktop app."] =
	"TradeSkillMaster hat keinen Preis für diese Reagenzien: Aktualisiert seine AuctionDB mit der TSM-Desktop-App." -- mt
L["Update TradeSkillMaster's AuctionDB with the TSM desktop app, or visit a vendor, to price reagents."] =
	"Aktualisiert TradeSkillMasters AuctionDB mit der TSM-Desktop-App oder besucht einen Händler, um Reagenzien zu bepreisen." -- mt
L["The tracker no longer flashes while you hover equippable items."] =
	"Der Tracker flackert nicht mehr, wenn ihr ausrüstbare Gegenstände überfährt." -- mt
