# Addon API

Other addons read SkillUp Forever's answers through `SkillUpForever.API` (`version = 1`). Every read returns a fresh
table on every call, so a caller may keep it or change it: it is never the addon's own table. On ForeverCore 1.3.2 or
later, `ForeverCore.APIKit.Addons()` also lists the API.

`version` changes only when a published member breaks: its arguments, the shape of its result or its meaning. An
addition keeps `version` at 1 and raises `minor`, so check that a function exists before calling it. The current
`minor` is 15; the history:

| minor | added |
|---|---|
| 1 | `Professions`, `Navigate` and `OpenRecipes`, the first published API |
| 2 | `ShoppingList`, the tracked routes' shopping list |
| 3 | each shopping row's `target`, the base skill its plan buys to |
| 4 | `RequiredMaterials` and `SubComponents`, a recipe's inputs after known sub-crafts |
| 5 | `Subscribe`, the not-ready answers below, and a fresh `Professions` table on every call |
| 6 | `IsTracked`, `SetTracked`, `ShoppingTrip`, `Professions` limits, `Stats`, `Leaderboard` |
| 7 | `Recipes`, `Recipe`, `RecipeRequirement`, `Characters` and `Knows` |
| 8 | conditional selected initial acquisition records on steps and shopping items |
| 9 | profession source-evidence status and conditional supply certificates with dated provenance |
| 10 | proved `unattained` supply status and free-unlimited geometric nonattainment parameters |
| 11 | complete adaptive finite supply certificates, scope and selection proof |
| 12 | alpha-free recipe evidence status and opt-in declared crafted snapshot provenance |
| 13 | copied revision-owned shopping supply summary |
| 14 | copied current economic `nextAction` guidance on professions |
| 15 | `RecipeSources`, the catalogue sources of a recipe's teaching item |

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
| `recipeEvidence` | alpha-free recipe declaration status, with stable missing-law reason codes |
| `sourceEvidence` | structured source-law evidence for the current merchant window, available without a coverage target |
| `nextAction` | optional current read-only economic guidance for adaptive mode, described below |
| `supply` | optional conditional fixed or adaptive selection status and complete result, described below |

`nextAction` is absent in ordinary estimate mode. In adaptive mode it has `kind`
(`"craft"`, `"purchase"`, `"stop"` or `"unsupported"`), `conditional = true` and
`inventoryScope = "bags-only"`. Published actions carry a monotone publication
`generation`, exact economic `state`, `resources` (`stage`, ordered `balances`,
ordered `stock`, `wallet`), `coordinates`, `pools` and declared source/recipe revisions.
The stage is a compiled stage index. Generation is not a resource revision.
Getters copy prepared records and never read resources, run a reader or advance work.

A craft names the declared `recipeID`, `role` and `count = 1`. It is recipe-open
guidance only (`executable = false`): the addon does not arm Create, CreateAll or
Shift batch paths for it. The native page controls any subsequent player crafting.
Stop distinguishes `reason = "complete"` from `"economic-stop"`; the economic
policy may stop even when the separate maximum-coverage policy would craft.
Unsupported includes `"unpublished-or-stale"`, `"action-unavailable"`,
`"economic-root-missing"` or `"recipe-binding-missing"`. Adaptive mode never
falls back to an estimated craft while calculating, stale, unknown or infeasible.

A purchase has `phase = "initial"` or `"continuation"`, `atomic = true`,
`executable = false` and `reason = "atomic-purchase-not-executable"`. `orders`
retains the whole indivisible basket: each entry has `source`, `bundles` and its
complete source `binding`, including offer/NPC identity, typed costs, product,
ceiling and finite pool. `visits` holds monetary fares, `visitValues` opportunity
values and `assumptions` dated session/slot provenance when declared. These are
conditional instructions, never addon purchases or substitute reagent baskets.
Initial purchases remain outstanding against the pre-payment state; `postInitialState`
names the hypothetical delivered root, not an authorized current state. Repeated reads,
opening a recipe and partial resource changes cannot reconcile delivery or traverse
successors. Relevant observations revoke the owner and require fresh publication.
The `steps` array remains explanatory route material, not an adaptive action fallback.

`sourceEvidence` has `status` (`"unavailable"` or `"conditional"`), `sourceRevision`,
`scope = "current-merchant-window"`, `missing` and `assumptions`. Each missing record has a
`code` and, when known, `offerID` and `field`. A conditional status means that the explicitly
requested products have declared laws in the current window. It does not establish all
sources available to the player, or an optimal acquisition policy. No coverage target is
chosen by reading this field.

`recipeEvidence` has `status` (`"unsupported"` or `"conditional"`),
`recipeRevision`, `scope = "declared-finite-recipes"` and `missing` records with
stable `code` and optional `recipeID`. Without an explicit completed-attempt
law declaration it reports `recipe-production-law-missing`, even if native
schematic bounds are equal. Conditional means a complete declared finite
universe, never verified native production or an all-live-recipe optimum.
See [Recipe evidence](recipe-evidence.md).

`supply`, when a caller has configured a policy and target, is the selection result:
`status`, `reasons`, `costKnown`, explicit `alpha`, C0 `coverageLower/Upper`, Ppi
`successLower/Upper`, `costLower/Upper`, `visitsLower/Upper`, and selected initial
`orders`, `quantities`, `acquisitions` and `initialVisits` when complete. Source-owned
results also carry paired `sourceRevision` and `assumptions`. Each assumption retains
`offerID`, `field`, law `revision`, `provenance`, validity `scope`, `observedAt`,
`observationRevision`, `session` and `index`. These are conditional mathematical
results for one declared refill policy, not empirical gameplay guarantees. All nested
tables are fresh copies. Missing, calculating or unknown results provide no optimum certificate.

Adaptive results retain `service = "adaptive-finite"`, `inventoryScope = "bags-only"`,
`items` as gross initial inventory targets, native pre-payment `have`, exact-selection
proof `selection`, and the complete finite policy `certificate`. C0 uses net inventory
after item-token payments; Ppi includes the selected future actions. Objective, carry,
failure-loss and expenditure bounds remain separate. The certificate owns source
bindings, typed payments, canonical coordinates, trip laws and selected actions.
Initial step and shopping quotes use only `acquisition.moneyCopper` and its complete
typed `costs`. Monetary visit fares remain in the certificate and objective.
Certified reagent and shopping counts use native holdings in the declared scope.
A missing certified coordinate has no `have` or `missing` count and never reads the
bags-and-bank display fallback. A certified zero remains zero.

A selector may instead report `status = "unattained"`, `costKnown = false`,
`infimumKnown = true` and exact `objectiveInfimumLower/Upper`, with no finite
`orders`, `items` or coverage certificate. Its `nonattainment` record has
`kind = "free-unlimited-geometric"`, `chance`, `heldUnits`, `bundleUnits`,
`refillUnits` and `refillVisitCost`. This proves the restricted mathematical
infimum described in [Conditional supply calculations](supply-policy.md), not
a recommended finite basket or an observed future supply guarantee.

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

When an explicit source contract and coverage target have produced a completed conditional selection, each
initial purchase step also has `acquisition`: `{ source, offerID?, npcID?, vendor, itemID, bundles, bundleUnits,
units, moneyCopper, costs }`. `source` is the index in the frozen policy, and `offerID` identifies a distinct offer
when the source owner establishes one. `costs` maps complete typed `item:ID` or `currency:ID` requirements to their
transaction totals. `cost` is the transaction's money component, excluding token opportunity values and travel.
The NPC is the selected offer's NPC; an unknown identity disables navigation. These records describe initial
orders, not future refill orders or a promise that a purchase will succeed.

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

A reagent is `{ itemID, need, have, source }`: how many the whole route needs, native holdings in the certified scope, or bags and bank without a certificate, and
`"vendor"`, `"craft"`, `"gather"` or `"auction"` when SkillUp can tell how it is got.

`Navigate(skillLineID, stepIndex)` sets a waypoint to the vendor, trainer or quest giver of that step when the step
has one, and returns whether it did. It is a request, not a read: ask it for a player's action, never to test the
route.

`OpenRecipes(skillLineID)` selects the native recipe page when that profession is already open and returns `true`.
If it is closed or another profession is open, it tells the player to open the requested profession from their
spellbook and returns `false`. The client blocks addons from opening professions. Combat or an unknown profession
returns `false`. It is a request for a player's click.

`Recipes(skillLineID?)` returns sorted bundled recipe IDs, optionally filtered to one skill line. It returns
`nil, "none"` when no matching profession exists. `Recipe(recipeID)` returns a fresh `{ skillLineID, output,
reagents }` record, where `output` is `{ itemID, quantity }` or `false`. `RecipeRequirement(recipeID)` returns the
known `{ skill, source, recipeItem?, trainerFee? }` learn requirement in base profession skill, or `nil, "none"` when SkillUp cannot establish
one. `Characters()` lists saved character keys, and `Knows(characterKey, recipeID)` reads a saved learned flag,
returning `nil, "invalid"` for an unknown recipe or malformed key.

`RecipeSources(recipeID)` returns a fresh `{ itemID, vendors, quests, drops, world }` record for the item that
teaches the recipe, from the same catalogue as SkillUp's tooltips. Vendors are `{ npcID, name, zone, usable }`,
quests are `{ questID, title, usable }`, and drops are `{ npcID, name, zone, chance, usable }`. Only NPCs and quests
the catalogue can name are listed. `zone` is SkillUp's location label, `chance` is a percentage, and `world` is
true for a world drop. `usable` applies the tooltip's faction rule to vendors, quests and droppers: both-faction
sources and this character's faction are usable; opposing or unknown factions are false.
It returns `nil, "loading"` while saved variables load or the profession's sources are being read: ask again
shortly. It returns `nil, "none"` when no teaching item is known, including an unknown recipe ID.

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
| `supplySummary` | current conditional supply status, described below |
| `profession` | the route's localized name |
| `skillLine` | the skill line |
| `target` | the base skill the route's plan buys to, the number the route tab's Target box shows |
| `items` | the missing items, gathered first, then vendor, then auction house, then unknown, by item ID inside each |
| `total` | copper for the priced missing items |
| `unpriced` | how many missing items have no price |

`supplySummary` is a fresh record with `status`: `unconfigured`, `calculating`, `complete`,
`unknown`, `infeasible`, `unattained` or `cancelled`. When supplied, `alpha` is the explicit starting
coverage constraint, including zero. `service` names the declared `fixed-batch` or `adaptive-finite`
model, `inventoryScope` names its holdings scope, and `conditional = true` identifies supplied assumptions.
Only a current complete result whose owner also publishes the certified `items` and `have` exposes `coverageLower/Upper` (C0, completion from starting supplies
alone) and `successLower/Upper` (Ppi, completion with modeled later acquisitions). Reads never dispatch
source readers or advance jobs. A completed job awaiting inventory publication remains `calculating`.
A cancelled configured job remains `cancelled` until replacement work is queued. Displayed probability
bounds round outward to two decimal places; these API bounds remain unchanged. Without configuration, quantities remain ordinary estimates, with no
coverage target or probability assigned. Craft next continues to use the ordinary route estimate; it does
not execute the conditional certificate.

The production adaptive provider and execution remain separate work for #563: establish live source
eligibility, verified stock units and complete typed payments, measured or explicit travel and farm
inputs, and recipe gain laws; supply a fresh complete request through
`RouteDemand.ConfigureAdaptiveSupply` on each input revision. A later executor must follow the
selected state-dependent continuation, reconcile actual purchases and craft outcomes, and invalidate
or replan when observations differ. This presentation adds neither a provider nor that executor,
and assigns no default confidence constraint.

An item is `{ itemID, need, have, missing, source, price, priceAge, cost, alt }`: `need` for the route, `have` in the
certified scope, or bags and bank without a certificate, and `missing` the difference; `price` is copper each when one is known, and `cost` the price of the
missing units; `priceAge` is the whole days since the auction source observed the price, when known; `alt` is a
fresh list of `{ name, count }`, this character's other characters that hold it, most first.
Each row exposes `inventoryScope = "bags-only"` for adaptive native holdings or
`"bags-and-bank"` for fixed and ordinary route holdings. `have` and `missing` are
absent when the certified coordinate is unknown.

With a completed conditional selection, a shopping item has `acquisitions`, the selected initial transactions
for that product. `cost` sums their money components; `price` and `priceAge` are absent because a bundle with typed
payments has no interchangeable display-price quote. Tokens and visit costs are separate from this money total.
Steps and shopping items preserve the same selected offers, including several offers for one product. An empty
`acquisitions` list means no purchase was selected; consumers must not substitute another vendor or price.
The result remains conditional on explicit source laws and an explicit coverage target. Ordinary estimates have
no acquisition certificate. Inventory or source revisions revoke a completed selection.

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
