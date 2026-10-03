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

Fees come from the classic trainer data (CMaNGOS). A trainer you have visited quotes its own fees, for recipes and for the ranks it still offers, and those then win.

### Prices

Reagents show where each price comes from and how old it is, and the page flags auction prices older than a day. Auction prices need [Auctionator](https://www.curseforge.com/wow/addons/auctionator); without it, a reagent sold only at the auction house has no price.

### When the route stops short

If nothing you know skills up far enough, the route stops there and says so. It then lists the recipes from vendors, quests and drops that would carry it on, easiest to get first:

1. a vendor of your faction
2. limited supply
3. quests
4. named drops
5. world drops

Each shows the scroll's price (`?` when nothing prices it) and how far it reaches. Hover one for every vendor, quest and drop with its zone and coordinates. Click it for a waypoint to the nearest vendor or the likeliest drop.

### Waypoints

*Train* steps and vendor reagents name the nearest trainer (one who teaches that far, of your faction) or vendor, with its zone and coordinates. A click sets a waypoint there.

- With [Shortest Path Forever](https://www.curseforge.com/wow/addons/shortest-path-forever) installed, you get its travel route, and "nearest" means quickest to reach by its travel time.
- Otherwise [TomTom](https://www.curseforge.com/wow/addons/tomtom)'s arrow, else the map's own.

## Shopping list

Beside the route is every reagent it needs, with how many you have (bags and bank), green once covered. Hover one for what your other characters hold ([Syndicator](https://www.curseforge.com/wow/addons/syndicator), same realm and faction).

### Gathered reagents

With *Reagents you gather are free* on (the default), anything another of your professions gathers costs nothing: Light Leather with Skinning, ore with Mining, herbs with Herbalism. The route can use it, and it's listed as *gather*.

### Track

*Track* puts the list in the objective tracker beside your quests, like `12/20 Linen Cloth`, kept up to date as you buy, craft and skill up.

- Click the training line or a vendor reagent's line for a waypoint to the nearest trainer or vendor. Hover it to see who and where.
- Its header menu crafts the next step while that profession is open, and sets a waypoint to a trainer or to a vendor for a missing reagent.

### Buying

- **At a vendor:** *Buy tracked reagents* on the merchant window buys what that vendor sells, with the total cost on the button.
- **At the auction house:** with [Auctionator](https://www.curseforge.com/wow/addons/auctionator) installed, *To Auctionator* makes a shopping list (`SkillUp: <profession>`, replaced each time) of the auction house reagents still missing. Auction purchases stay manual, as the game requires.
