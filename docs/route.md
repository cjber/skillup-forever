# Levelling route and shopping list

The detail behind the README's *Levelling route* and *Shopping list* features.

## Levelling route

A map tab under the Professions window's side tabs opens a SkillUp page. Pick any of your professions that craft (it starts on the open one) and type a target skill. The page lists the cheapest crafts to get there, like `12× Heavy Linen Bandage to 90`, each with its cost, then the total.

### How it picks

- Each skill point takes the recipe with the lowest cost per skill-up at that point.
- Recipes a trainer teaches are included when they pay for themselves, shown as a *Train* step with its fee. The fee is counted once, and never before the trainer would teach them.
- Recipes with an unpriced reagent are left out and counted.

### The steps

Steps are a table of recipe, crafts, target skill and cost. Hover one for the crafted item, its colour bands, the reagents for that step and its cost, or click it to open the recipe.

*Craft* under the route crafts its first step as many times as it needs and your bags allow, while that profession is open.

### Training

The target can go past your current cap, up to the last rank a trainer teaches. The route then adds *Train Journeyman/Expert/Artisan* steps with the fee, the skill the trainer wants and, while you are below it, the level.

Fees come from the classic trainer data (CMaNGOS), which also says who trains what. A trainer you have visited quotes its own fees, for recipes and for the ranks it still offers, and those then win.

### Prices

Reagents show where each price comes from and how old it is, and the page flags auction prices older than a day. Auction prices need [Auctionator](https://www.curseforge.com/wow/addons/auctionator); without it, a reagent sold only at the auction house has no price.

### When the route stops short

If nothing you know skills up far enough, the route stops there and says so. It then lists the recipes from vendors, quests and drops that would carry it on, easiest to get first:

1. a vendor of your faction
2. quests
3. named drops
4. world drops

These come from the [Questie](https://www.curseforge.com/wow/addons/questie) and [AtlasLoot](https://www.curseforge.com/wow/addons/atlaslootclassic) you have installed. AtlasLoot says which scroll teaches which recipe; Questie says who sells it, which quest rewards it and where they are. Without one, a line says which to install, and the list holds what the other can still tell.

Each shows the scroll's price (what it cost at the auction house or at a merchant's window you have opened, `?` until then) and how far it reaches. Hover one for its vendors (the nearest four, and a count of the rest), quests and drops, with zone and coordinates. Click it for a waypoint to the nearest vendor or the likeliest drop.

### Waypoints

*Train* steps and vendor reagents name the nearest trainer (one who teaches that far, of your faction) or vendor, with its zone and coordinates. A click sets a waypoint there. A *Nearest vendor* button in the route page does the same for every vendor reagent the route still needs at once. Names and places come from Questie: without it a step names nobody and its tooltip says so.

- With [Shortest Path Forever](https://www.curseforge.com/wow/addons/shortest-path-forever) installed, you get its travel route, and "nearest" means quickest to reach by its travel time.
- Otherwise [TomTom](https://www.curseforge.com/wow/addons/tomtom)'s arrow, else the map's own.

## Shopping list

Beside the route is every reagent it needs, with how many you have (bags and bank), green once covered. Hover one for what your other characters hold ([Syndicator](https://www.curseforge.com/wow/addons/syndicator), same realm and faction).

### Gathered reagents

*Buy reagents at the auction house* in the route page chooses where a reagent another of your professions could gather comes from: off, it costs nothing, so the route uses it and the list says *gather*; on, it is bought and priced at a vendor or the auction house like any other reagent. The choice is saved for this character.

### Track

*Track* puts the list in the objective tracker beside your quests, like `12/20 Linen Cloth`, kept up to date as you buy, craft and skill up.

Opening a profession's own window, or a trainer that teaches it, starts tracking that profession on its own when its route still has steps, so the tracker and its waypoints arrive without pressing *Track*. A profession you stop tracking by hand stays stopped until you track it again.

- Click the training line or a vendor reagent's line for a waypoint to the nearest trainer or vendor. Hover it to see who and where.
- Its header menu crafts the next step while that profession is open, and sets a waypoint to a trainer or to a vendor for a missing reagent.

### Buying

- **At a vendor:** *Buy tracked reagents* on the merchant window buys what that vendor sells, with the total cost on the button.
- **At the auction house:** with [Auctionator](https://www.curseforge.com/wow/addons/auctionator) installed, *To Auctionator* makes a shopping list (`SkillUp: <profession>`, replaced each time) of the auction house reagents still missing. Auction purchases stay manual, as the game requires.
