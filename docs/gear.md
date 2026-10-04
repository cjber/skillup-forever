# Crafted gear

The detail behind the README's crafted gear tab. The tab is off by default; turn it on under
*Settings > AddOns > SkillUp Forever > Route and trainer > Show the crafted gear tab*.

## What it lists

Each equipment slot shows the crafted items this character can equip right now, at most three a slot.
An item is left out when its required level is above the character's, when its `AllowableClass`
excludes the class, when the class cannot wear or wield its type, or when a use of the item consumes
it. Within a slot the items are ordered by required level, then by the skill the recipe needs, then by
name, so the newest wearable thing is first.

An item's own skill requirement counts: the goggles and the spanner are engineering items, and they
show only once the character's Engineering is at the rank the item asks for. A weapon type counts only
when the character knows that weapon skill. The character's own skill lines answer that, so a mage
who has trained swords sees them and one who has not does not; the class table below is the fallback
for a character the client cannot answer for, and it holds only what a class wields from creation.

By default the list holds only what the character can make now: the recipes it knows, and the ones
whose skill it already reaches. A *Show gear I cannot make yet* checkbox under the list adds the
rest; the choice is saved per character. With no rows to show, the page says so and points at the
checkbox.

## What a row says

Each row is a full-size item icon with the game's quality border, the item's name in the item-name
font and, under it, the profession and the skill its recipe is learned at, then what the character can
do with the recipe. Rows sit under a slot heading in the game's own scroll box, and the page's title
is the inset's own heading, below the window's title bar and clear of its portrait.

The skill shown is the skill at which the recipe can be learned, which is where the recipe becomes
craftable: the base skill a trainer asks, the skill a scroll asks, or, for a recipe neither teaches,
the bundled data's first threshold. It is not the orange difficulty threshold on its own, which for
many recipes the client leaves at 1.

Each row's status says what the character can do with the recipe:

- *You know it*: the recipe is learned, so it can be crafted now;
- *Can learn it*: the character has the profession and its skill already reaches the recipe;
- *Needs <profession> <skill>*, such as `Needs Leatherworking 240`: the character has the
  profession but its skill is short;
- *Another crafter*: the character does not have the profession.

A known row's status is green; the rest are the game's disabled grey. Clicking a known row opens the
recipe on the crafting page. Clicking a row that can be learned now sets a waypoint to where it is
learned: the nearest trainer who teaches it, or the nearest NPC a recipe scroll comes from. A row the
character cannot make yet does nothing on a click. A row's tooltip states what the click does, and
where a scroll-taught recipe comes from when the addon has read that source.

There are no stat weights and no best-in-slot claim: the tab answers "what is the newest thing I
could have crafted for this slot", nothing more.

## Where the facts come from

`Data/Recipes.lua`'s `ns.ItemGear` holds each crafted item's required level, `AllowableClass`,
`RequiredSkill` and `RequiredSkillRank`, and whether a use consumes it, all from the pinned build's
`ItemSparse`; its class (weapon or armour), subclass (its type) and inventory type (its slot) from the
same build's `Item`. A nonzero charge on any of the item's effects, through `ItemXItemEffect` and
`ItemEffect`, marks a use that consumes it. `tools/gen_recipes.py` writes all of it, and maps an
item's child profession line back to the parent the character trains.

What a class can wear, and from which level, is the small table in `Core/Gear.lua`, read off the
client's `SkillRaceClassInfo` and `SkillLine` for the pinned build: one row per type, the class
mask it covers and the level it starts at. Mail is level 40 for hunters and shamans, plate is level
40 for warriors and paladins, and everything else starts with the character. That table's weapon
rows are only the types a class gets at creation. A trained weapon comes from the character's own
skill lines, read through `C_SkillInfo`.

The skill a recipe needs comes from `Core/Plan.lua`'s `ns.LearnSkill`, which the route page's
difficulty bands use too: `Data/Trainer.lua`'s fee and required base skill when a trainer teaches it,
the catalogue's scroll skill when the player's AtlasLoot names one, else `Data/Thresholds.lua`'s
first value. Which NPC trains which recipe and where a scroll comes from are read in game from
Questie and AtlasLoot, never bundled.
