# Crafted gear

The detail behind the README's crafted gear tab. The tab is off by default; turn it on under
*Settings > AddOns > SkillUp Forever > Route and trainer > Show the crafted gear tab*.

## What it lists

Each equipment slot shows the crafted items this character can equip right now, at most three a slot.
An item is left out when its required level is above the character's, when its `AllowableClass`
excludes the class, when the class cannot wear or wield its type, or when a use of the item consumes
it. Within a slot the items are ordered by required level, then by the recipe's skill, then by name,
so the newest wearable thing is first.

An item's own skill requirement counts: the goggles and the spanner are engineering items, and they
show only once the character's Engineering is at the rank the item asks for. A weapon type counts only
when the character knows that weapon skill. The character's own skill lines answer that, so a mage
who has trained swords sees them and one who has not does not; the class table below is the fallback
for a character the client cannot answer for, and it holds only what a class wields from creation.

Every row carries the item's own icon, quality colour and tooltip, the profession and skill its
recipe needs, and whether the character knows the recipe, has the profession to learn it, or needs
another crafter.

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
