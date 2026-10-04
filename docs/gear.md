# Crafted gear

The detail behind the README's crafted gear tab. The tab is off by default; turn it on under
*Settings > AddOns > SkillUp Forever > Route and trainer > Show the crafted gear tab*.

## What it lists

Each equipment slot shows the newest crafted items this character can equip right now, at most three
a slot. Newest is the item's required level, so a level 20 shaman sees level 20 leather and lower,
and once level 40 arrives the mail appears. An item is left out when its required level is above the
character's, when the class cannot wear or wield its type at that level, or when its
`AllowableClass` excludes the class.

Every row carries the item's own icon, quality colour and tooltip, the profession and skill its
recipe needs, and whether the character knows the recipe, has the profession to learn it, or needs
another crafter.

There are no stat weights and no best-in-slot claim: the tab answers "what is the newest thing I
could have crafted for this slot", nothing more.

## Where the facts come from

`Data/Recipes.lua`'s `ns.ItemGear` holds each crafted item's required level and `AllowableClass`
from the pinned build's `ItemSparse`, and its class (weapon or armour), subclass (its type) and
inventory type (its slot) from the same build's `Item`. `tools/gen_recipes.py` writes both.

What a class can wear or wield, and from which level, is the small table in `Core/Gear.lua`, read off
the client's `SkillRaceClassInfo` and `SkillLine` for the pinned build: one row per type, the class
mask it covers and the level it starts at. Mail is level 40 for hunters and shamans, plate is level
40 for warriors and paladins, polearms are level 20, and everything else starts with the character.
