# Crafted gear

The detail behind the README's crafted gear tab. The tab is off by default; turn it on under
*Settings > AddOns > SkillUp Forever > Route and trainer > Show the crafted gear tab*.

## What it shows

The page is a second character sheet. One item slot sits in each of the character sheet's equipment
slots: head, neck, shoulder, back, chest and wrist down the left; hands, waist, legs, feet, one ring
and one trinket down the right; and the main hand, off hand and ranged slots along the bottom. The
shirt, tabard and ammo slots are left out, as no crafted gear goes in them. The sheet's two ring slots
share one list, as do its two trinket slots, and a two-handed weapon shares the main-hand list with a
one-hander: an item's inventory type names the slot it goes in, not which of a pair.

Each slot shows the newest item this character could craft for it: a full-size item icon in the game's
quality border. A slot with nothing to show draws the character sheet's own empty-slot art, dimmed. A
pick the character already knows carries the game's own check mark; a pick it cannot make yet is
desaturated. Hovering a slot shows that pick's game item tooltip, then what the addon knows of its
recipe. Clicking a slot selects it, and the selected slot carries the stock selection highlight.

An item is left out when its required level is above the character's, when its `AllowableClass`
excludes the class, when the class cannot wear or wield its type, or when a use of the item consumes
it. Within a slot the items are ordered by required level, then by the skill the recipe needs, then by
name, so the newest wearable thing is first.

An item's own skill requirement counts: the goggles and the spanner are engineering items, and they
show only once the character's Engineering is at the rank the item asks for. A weapon type counts only
when the character knows that weapon skill. The character's own skill lines answer that, so a mage
who has trained swords sees them and one who has not does not; the class table below is the fallback
for a character the client cannot answer for, and it holds only what a class wields from creation.

By default every slot holds only what the character can make now: the recipes it knows, and the ones
whose skill it already reaches. A *Show gear I cannot make yet* checkbox sits in the page header, above
the doll; the choice is saved per character. With nothing at all to show, the middle pane says so and
points at the checkbox.

## The detail pane

The pane in the middle draws the selected slot's pick the way the game draws a recipe: the pick's
large icon in its quality border, its name in the item's quality colour at a stock header size, a line
for its required level and type, the profession and the skill at which it is learned, and what the
character can do with it in plain words.

Under those sit its reagents, one full-size item row each, with how many the bags and bank hold of
what the recipe needs. Under them is one button whose label says what it does: *Open recipe* for a
recipe the character knows, setting a waypoint to where it is taught for one it can learn now, and
disabled with the reason otherwise. *Also for this slot* lists the slot's other picks as full-size
item rows; clicking one makes it the pane's item.

A recipe whose learn skill the data does not know is never called learnable and prints no skill: the
pane says its source is unknown.

Each pick's status says what the character can do with the recipe:

- *You know it*: the recipe is learned, so it can be crafted now;
- *Can learn it*: the character has the profession and its skill already reaches the recipe;
- *Needs <profession> <skill>*, such as `Needs Leatherworking 240`: the character has the
  profession but its skill is short;
- *Another crafter*: the character does not have the profession.

There are no stat weights and no best-in-slot claim: the tab answers "what is the newest thing I
could craft for this slot", nothing more.

## Where the facts come from

`Data/Recipes.lua`'s `ns.ItemGear` holds each crafted item's required level, `AllowableClass`,
`RequiredSkill` and `RequiredSkillRank`, and whether a use consumes it, all from the pinned build's
`ItemSparse`; its class (weapon or armour), subclass (its type) and inventory type (its slot) from the
same build's `Item`. A nonzero charge on any of the item's effects, through `ItemXItemEffect` and
`ItemEffect`, marks a use that consumes it. `tools/gen_recipes.py` writes all of it, and maps an
item's child profession line back to the parent the character trains.

The same generator writes `ns.RecipeScrolls`: for each recipe spell, the pattern or recipe item that
teaches it, from `ItemEffect` and `ItemXItemEffect`, and the skill that item asks for, from
`ItemSparse`. That is a recipe's real learn requirement: the client's own `SkillLineAbility` orange
sits at its placeholder 1 for most recipes, so it is never used as the requirement.

What a class can wear, and from which level, is the small table in `Core/Gear.lua`, read off the
client's `SkillRaceClassInfo` and `SkillLine` for the pinned build: one row per type, the class
mask it covers and the level it starts at. Mail is level 40 for hunters and shamans, plate is level
40 for warriors and paladins, and everything else starts with the character. That table's weapon
rows are only the types a class gets at creation. A trained weapon comes from the character's own
skill lines, read through `C_SkillInfo`.

The skill a recipe needs comes from `Core/Plan.lua`'s `ns.LearnSkill`, which the route page's
difficulty bands use too: `Data/Trainer.lua`'s required base skill when a trainer teaches it, else
`ns.RecipeScrolls`'s own requirement, else the catalogue's scroll skill when the player's AtlasLoot
names one, else nothing the data knows. Which NPC trains which recipe and where a scroll comes from
are read in game from Questie and AtlasLoot, never bundled.
