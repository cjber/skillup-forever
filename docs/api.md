# Addon API

Other addons read SkillUp Forever's answers through `SkillUpForever.API` (`version = 1`). Every read returns a fresh
table on every call, so a caller may keep it or change it: it is never the addon's own table. On ForeverCore 1.3.2 or
later, `ForeverCore.APIKit.Addons()` also lists the API.

`version` changes only when a published member breaks: its arguments, the shape of its result or its meaning. An
addition keeps `version` at 1 and raises `minor`, so check that a function exists before calling it. The current
`minor` is 6; the history:

| minor | added |
|---|---|
| 1 | `Professions`, `Navigate` and `OpenRecipes`, the first published API |
| 2 | `ShoppingList`, the tracked routes' shopping list |
| 3 | each shopping row's `target`, the base skill its plan buys to |
| 4 | `RequiredMaterials` and `SubComponents`, a recipe's inputs after known sub-crafts |
| 5 | `Subscribe`, the not-ready answers below, and a fresh `Professions` table on every call |
| 6 | `IsTracked`, `SetTracked`, `ShoppingTrip`, `Professions` limits, `Stats`, `Leaderboard` |

## Not ready

A read with nothing to answer returns `nil, reason`, where `reason` says whether to ask again:

| reason | meaning |
|---|---|
| `"loading"` | the saved variables are still loading, so ask again later |
| `"none"` | there is nothing to answer, for example a recipe SkillUp does not know |

An `"invalid"` answer means the argument itself is wrong, not that the data is unready: asking again will not help.
`Professions` answers it for a malformed `limits` table, and `Leaderboard` for a limit that is not a whole number of
zero or more.

## Reads

`Professions(limits?)` returns one entry per profession this character can level, most actionable first: one whose
next step can be done from the bags, then a tracked one, then the nearest to doing. It returns `nil, "loading"`
before the saved variables load. `limits` may hold `steps` and `recipes`, each a whole number from 1 to 25, to
replace the defaults of three and five for that call only. A missing field keeps its default, and a bad one returns
`nil, "invalid"`. Each entry is:

| field | |
|---|---|
| `name` | the profession's localized name |
| `skillLineID` | the skill line |
| `icon` | the profession icon's file ID |
| `rank` | base skill, the number the Professions window shows |
| `maxRank` | the current cap |
| `title` | the rank name at the cap, for example `"Journeyman"`, when SkillUp has one |
| `steps` | the route's steps, in order: at most three by default, or the call's `limits.steps` |
| `recipes` | the route's crafts: at most five by default, or the call's `limits.recipes` |
| `reagents` | the route's reagents for the whole route |

A step is:

| field | |
|---|---|
| `kind` | `"buy"`, `"craft"`, `"train"` or `"gather"` |
| `text` | a short imperative line, for example `"Craft 4 Toughened Leather Gloves"` |
| `detail` | `"142 to 145"`, or `"Name, Zone · fee"` when it names an NPC |
| `itemID` | the reagent to get, the craft's product, or the book or recipe scroll to buy, read or hold |
| `spellID` | the recipe to craft or train |
| `questID` | the quest that teaches a rank (a `"train"` step) |
| `count` | how many to get or craft |
| `cost` | copper to buy or train |
| `nav` | whether `Navigate` can route to the vendor, trainer or quest giver this step names |

A recipe is:

| field | |
|---|---|
| `spellID`, `itemID`, `name` | the recipe, its product and the product's name |
| `count` | crafts planned |
| `fromRank`, `toRank` | the base skill range the crafts are planned for |
| `learned` | whether this character knows it |
| `color` | `"orange"`, `"yellow"`, `"green"` or `"grey"`, the game's colour at `fromRank` when it shows one |
| `trainAt` | where the route first trains it, while it is still to learn |
| `cost` | its training fee in copper, while it is still to learn |

A reagent is `{ itemID, need, have, source }`: how many the whole route needs, how many the bags and bank hold, and
`"vendor"`, `"craft"`, `"gather"` or `"auction"` when SkillUp can tell how it is got.

`Navigate(skillLineID, stepIndex)` sets a waypoint to the vendor, trainer or quest giver of that step when the step
has one, and returns whether it did. It is a request, not a read: ask it for a player's action, never to test the
route.

`OpenRecipes(skillLineID)` opens the Professions window on that profession, where SkillUp's recipe colours and route
tab are, and returns whether the client opened it. It is a request too, for a player's click.

## Tracking

`IsTracked(skillLineID)` returns whether that profession is tracked in the objective tracker, the same saved choice
the route page's Track button writes. It returns `nil, "loading"` before the saved variables load.

`SetTracked(skillLineID, tracked)` sets that choice and returns `true` when it changed the setting, or `false` for an
unknown or unlearned skill line, a non-boolean `tracked`, or a value it already had. It returns `nil, "loading"`
before the saved variables load. It is a request, not a read. Unlike the player's own click, it plays no checkbox
sound.

## Shopping list

`ShoppingList(skillLineID)` returns a fresh list for each tracked route, for one profession when `skillLineID` is
given, sorted by profession name. It is empty when no tracked route matches, and before the saved variables load.
Each entry is:

| field | |
|---|---|
| `profession` | the route's localized name |
| `skillLine` | the skill line |
| `target` | the base skill the route's plan buys to, the number the route tab's Target box shows |
| `items` | the missing items, gathered first, then vendor, then auction house, then unknown, by item ID inside each |
| `total` | copper for the priced missing items |
| `unpriced` | how many missing items have no price |

An item is `{ itemID, need, have, missing, source, price, priceAge, cost, alt }`: `need` for the route, `have` in the
bags and bank, and `missing` the difference; `price` is copper each when one is known, and `cost` the price of the
missing units; `priceAge` is the whole days since Auctionator saw the price, when it came from there; `alt` is a
fresh list of `{ name, count }`, this character's other characters that hold it, most first.

## Shopping trip

`ShoppingTrip(skillLineID?)` starts the same route the shopping list's own button does, for one profession when
`skillLineID` is given, and returns whether the route was started. It is a request, for a player's click.

## Materials

`RequiredMaterials(recipeID, crafts)` returns the recipe's raw inputs after known, cheaper sub-crafts are expanded,
as fresh `{ itemID, count }` rows, for `crafts` crafts (one unless given). `SubComponents(recipeID, crafts)` returns
the known cheaper recipes it expands, as fresh rows with `recipeID`, `itemID`, `crafts` and `made`. Both return
`nil, "none"` when SkillUp has no such recipe, or when `crafts` is not a positive whole number.

`RequiredMaterials` is the source of truth for a recipe's materials: Commissions Forever's same-named function
forwards to it.

## Stats

`Stats()` returns one fresh local row, not a wire payload:

| field | |
|---|---|
| `addon` | always `"SkillUpForever"` |
| `metric` | always `"recipes_observed_learned"` |
| `subject` | always `"all"` |
| `value` | this character's distinct recipes observed as learned |
| `eventUnix` | optional, the last observation's time, absent before the first one |

## Subscribe

`Subscribe(callback)` calls `callback(changes)` on the frame after the answers above change, at most once per burst of
changes and never in the call that made the change. `changes` is a fresh table each call with these keys:

| key | |
|---|---|
| `professions` | `Professions` may answer differently: a step, recipe, reagent, rank or the order changed |
| `shopping` | `ShoppingList` may answer differently: a tracked route, its target, a price or a bag count changed |

Both keys are set together, because SkillUp drops all its answers through one change signal. A tracking change also
sets both, since the list's order and the shopping list follow it. Read the answer you use again rather than
replaying the change.

Only the subscribers there when the dispatch began are called: one added by a callback waits for the next burst. Each
callback runs under SkillUp's own error handling, so an error in one reaches the error report and the others still
run. It returns a function that unsubscribes, safe to call twice. A callback that is not a function is an error. While
the saved variables are still loading nothing is read or sent, and a subscriber taken before then hears the first
change after they load.

```lua
local api = SkillUpForever and SkillUpForever.API
if not (api and api.version == 1) then
	return
end
local function Show()
	local professions, reason = api.Professions()
	if not professions then
		-- "loading": ask again when Subscribe next calls.
		return
	end
	for _, profession in ipairs(professions) do
		local first = profession.steps[1]
		if first then
			print(profession.name, first.text)
		end
	end
end
if type(api.Subscribe) == "function" then
	api.Subscribe(function(changes)
		if changes.professions then
			Show()
		end
	end)
end
Show()
```
