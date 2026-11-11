# Buffs

The detail behind the README's buffs tab. It is on by default; turn it off under
*Settings > AddOns > SkillUp Forever > Route and trainer > Show the buffs tab*.

## What it shows

The page answers "what buff consumables can this profession make for me, and when". Pick the profession from
its own dropdown; it starts on the open profession when that one makes buffs, then on the last one you chose,
and remembers the choice for this character. One row holds each buff effect the profession's recipes leave:
Strength, Agility, Stamina, Intellect, Spirit, attack power, a fishing skill bonus, and so on. A row is named by the game's own word for the effect, from the same
`SpellEffect` data that says which stat or skill it raises. A buff whose effect the client has no word
for gets a row named by its spell.

Each item sits in the column of the skill at which its recipe is learned, on a timeline from 1 to the
highest learn skill shown, rounded up to the next 25. A column has as many slots as the most items any
one row learns at that skill, so two items learned at one skill take two slots and the next column clears
them. Every node sits under its own skill's number, and the columns line up across rows. A buff the
character knows is a green talent node, one its skill already reaches is yellow, one still ahead is grey,
and one whose required level is above the character's is locked, with the game's lock art. The talent
tree's own line art joins the nodes of a row.

The profession's specialization page is drawn behind the timeline: Cooking, Alchemy, Leatherworking and
the rest, each at its native aspect. A divider marks the gap after the last column the character's
current cap reaches and names the next rank a trainer teaches by the skill that trains it. A legend under
the rows explains the four node states.

Hovering a node shows the game's item tooltip, then what the addon knows of the recipe. Clicking one
fills the strip under the legend: the item's icon and name, the buff in the game's own words, where and
at what skill the recipe is learned, its reagents, and the same action button the crafted gear page has.
A known recipe opens in the Professions window; a learnable one sets a waypoint to where it is taught;
anything else says why it cannot.

The "Only for level N" checkbox hides buffs the character's level cannot use. It is saved per character
and off by default, so the page starts with every buff the profession can make.

The page opens with the first column at or above your current skill at the left of the view, and another
crafter's opens on its first column. Rows scroll when the profession makes more buffs than fit. A thin
horizontal scroll bar under the timeline shows how far sideways the view goes, and a soft fade marks an edge
while more lies beyond it. Drag the timeline sideways to pan it, and Shift with the mouse wheel does the same;
the bar follows both. Hover the bar for the hint. The row labels, legend and detail strip stay where they are,
while the skill numbers, divider, nodes and edges move together.

A profession you do not have can still be picked, under *Other crafters*. Its items are all drawn in the grey
node, its locked nodes stay locked, and it has no rank divider or skill beside the dropdown; the action button
says *Another crafter* and cannot be pressed.

## Where the facts come from

The buff a crafted item leaves is `Data/Recipes.lua`'s `ns.BuffItems`, and the effect that names its row
is `ns.BuffEffects`, both from the pinned build's `ItemEffect`, `ItemXItemEffect` and `SpellEffect`.
`tools/gen_recipes.py` writes them. The skill a recipe is learned at is `ns.LearnSkill`, the same answer
the route page and crafted gear page use, and the item's required level is `ns.BuffLevel`.

The client's own GlobalStrings name the stats and resistances; a skill line's name comes from the
profession data the addon already carries. Nothing reads an effect's description text to decide a row.

The rank a divider names comes from `Data/Trainer.lua`'s `ns.TrainerRanks`: the rank with the smallest
cap above the character's current one, shown with the skill its trainer entry asks for. A rank that comes
from a book or a quest, rather than a trainer, leaves the divider unlabelled so the page never invents a
rank.
