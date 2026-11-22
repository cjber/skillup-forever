# Conditional supply calculations

`Core/Resupply.lua` evaluates one explicit refill policy. `Core/SupplyChoice.lua`
selects an initial order for that policy over a complete finite domain. Neither
module discovers a source or treats a merchant observation as future supply.
The route's ordinary craft counts remain estimates until a caller supplies the
required contract and a selection completes. There is no default coverage target.

## Required contract

The caller supplies an immutable `SkillUpResupplyInput`, defined in
`types/Resupply.lua`, and an explicit starting coverage target `alpha` in `(0, 1]`.
Each source is a distinct offer with an item identity, integer bundle size,
complete typed item/currency costs, money price, per-transaction maximum, shared
stock identity and units consumed, vendor identity, access law and fixed price
law. Shared stock, wallet and token balances are debited together. Item tokens
and recipe reagents use the same inventory pool. A transaction's products cannot
pay for another transaction in the same atomic batch.

Every shortage attempts the same declared batch. A feasible batch must enable
the next craft. Distinct vendors each charge one explicit additive round trip
per batch; several transactions at one vendor share that visit. An infeasible
atomic batch charges nothing and ends the run. Partial purchases, a paid trip
that discovers unavailable stock, intermediate crafting, bank-token transfers,
route-output reuse and general travel itineraries require additional transition
models and are unsupported here. The reader never buys anything.

Stock is either a declared nonnegative integer in explicit units or the explicit
mathematical law `"unlimited"`. Raw merchant `numAvailable`, including `-1`, does
not establish either law. Eligibility, native purchase maxima and affordability
also establish no future guarantee. Missing price, token value, travel cost,
access or stock law stays unknown; none inherits a quote or a zero cost.

## Results and numerical bounds

`coverageLower` and `coverageUpper` enclose C0, completion using the initial
post-purchase inventory alone. `successLower` and `successUpper` enclose Ppi,
completion after the refill policy. The explicit `alpha` constrains C0. Expected
cost includes initial purchases, later purchases, token opportunity values and
visits, including expenditure on runs that fail to finish.

Probability flows through pooled inventory, stage, wallet and stock states.
Crafting consumes reagents on failure as well as success. Arithmetic bounds
round outwards. A remaining probability tail alone does not bound expected
cost: with K stages and minimum positive success chance p, expected remaining
attempts are at most K/p. At most one fixed batch is attempted per craft attempt.
The implementation conservatively bounds remaining reward by pending upper
probability mass times `(K/p + 1)` times the fixed batch's upper reward.
Zero chances, overflow and exhausted work/state/coordinate budgets return
unknown. These are conditional mathematical bounds using `Model.Chance`, not
empirical promises about the game's random number generator.

The initial-order selector derives each offer's upper quantity from finite
stock, money or typed token balances before the initial atomic batch. It checks
every combination, splits quantities into legal transactions and retains shared
resource constraints. It certifies a winner only when its upper cost bound is
no greater than every potentially feasible competitor's lower bound. Coverage
or objective intervals that prevent this comparison remain unknown. Paid unlimited sources first search expanding finite domains for a feasible
incumbent. Its total expected upper cost bounds every competing initial money
outlay, giving a complete finite domain. An unbounded free dimension requires a
separate dominance or nonattainment proof and otherwise stays unknown;
there is no arbitrary basket cutoff or claim of a global policy optimum.

The selector proves one free-unlimited nonattainment case. It requires exactly
one source, one skill-up stage with chance `p` strictly between zero and one,
one unit of that source's item consumed per attempt, no money or token payment,
zero initial visit cost, a positive refill visit cost `R`, a positive fixed
refill of `B` units, and explicit `alpha < 1`. All these laws are conditional
inputs. This fixed-refill expenditure objective contains no additional carrying
or capacity term; additional contract fields are excluded from this proof.

Let `q = 1-p`, `h` be held units, `u` units per bundle and `n` initial bundles.
The expected later expenditure is `R*q^(h+n*u)/(1-q^B)`. It is positive for
every finite `n`, strictly decreases as `n` grows, and tends to zero. Some finite
`n` meets any `alpha < 1`, so zero is the exact infimum and no finite feasible
basket attains it. The result is `unattained`, with proof parameters and no
selected orders, inventory budget or coverage certificate. It is distinct from
an unresolved search. Alpha equal to one stays unknown here, as a separate
finite feasibility question. Arithmetic quantity limits do not invent a physical
capacity or turn the infimum into an attained optimum.

## Live ownership and consumers

`Core/SupplySources.lua` owns session-only, revisioned declarations for distinct
current merchant offers. Its production `Inspect(products)` path reports structured
missing observations or laws without requiring alpha or starting a solver. The API
publishes that report on each profession under `sourceEvidence`. Its scope is only
the current merchant window; other vendors, auction supply and future restocks are
not established by that window.

`Declare(offer, revision, laws)` requires a complete dated quote and separate scoped
provenance for access, fixed price, stock identity and units, transaction ceiling,
shared vendor identity, initial and refill visits, and every typed token value.
Finite stock uses the explicit `finite-no-restock` law. Resource revisions require
a newer reconciled declaration; rereading an unchanged declaration cannot restore
stock. An `unlimited` law must be explicitly supplied and is never inferred from
raw merchant stock. Replacement observations revoke their old declarations.

`Read(options, refillOrders, products)` includes all current competing offers for
the explicit product universe, including undeclared offers as missing-law reasons.
Refill orders identify offers by session-scoped `offerID`, not a transient source
index. Shared stock, visit and token laws must agree. `Configure` registers this
reader only with an explicit alpha. Selected results retain the source revision
and owned dated assumptions through the plan and public API.

`RouteDemand.StartPolicy` freezes plain policy records before asynchronous work
and substitutes the final route and fresh native balances. Snapshot copying
counts operations, rejects cycles/metatables and bounds schema depth. Its
operation budget is not a wall-clock or byte-size guarantee.
`RouteDemand.Count` reads native inventory directly, with explicit bank scope
and reagent/account-bank inclusion disabled. Missing, secret or invalid counts
stay unknown. The historical `ns.Have` display fallback is unchanged and cannot
supply certificate evidence. Wallet and currency capabilities are independent.
Bank-only item tokens require an unsupported location transition.

`RouteDemand.SelectSupply(plan, contract, alpha)` owns an asynchronous selection.
At most 64 solver operations run per frame. A completed selection publishes one
`plan.supply` starting raw-inventory budget. Shopping and API acquisition rows
read this same record and its owned selected initial transactions. Each transaction retains its source index,
optional distinct offer/NPC identities, vendor visit identity, bundle output, money and complete typed payments.
Navigation uses only selected NPCs; missing identities never fall back to another vendor. These records describe
initial purchases only, while later costs still evaluate the declared fixed refill batch; recipe craft-count rows retain their attempt estimates.
Getters never start or drain a solver. Replacing or cancelling a selection, or a
route, source, skill, inventory, wallet, currency or bank revision revokes the
record. `ConfigureSupply(skillLine, read, alpha)` keeps a session-only contract reader
and reselects the current unfinished plan after these revisions. The reader must
return fresh complete source laws each time, or nil when they are unavailable.
A copied finite stock record could silently replenish stock after purchases,
so automatic reselection never inherits it. Native balances are read afresh too.
Removing the configuration cancels its result. Source laws remain explicit
conditional assumptions; no observation silently certifies them.

This adapter stays session-only. It supplies no default target and infers no future law from an
observation. No page configures it: the Supply tab was removed.

The shared frame dispatches one dirty profession per update and advances published
jobs within one total 64-operation budget. Getters perform neither task. Only a
current complete result with owned `items` and `have` supplies counts. The plan
retains the whole result, including the selection proof, source revision and
dated assumptions. Route, shopping
and API rows read certified native holdings without a bank-inclusive fallback.
Missing coordinates remain unknown. Initial acquisition quotes retain complete
typed payments and offer money separately from the certificate's monetary fares.

Actual future supply laws, a product choice of coverage target, general policy
optimization and other free-unbounded-domain proofs remain
open in [#563](https://github.com/cjber/skillup-forever/issues/563). There is no
configured default policy and no native gameplay proof for these calculations.

The native balance signatures are pinned to Forever
`bebcb6bf309cf41b41bd74f8ca651e6a105b2676`:
[ItemDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua),
[CurrencyInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/CurrencyInfoDocumentation.lua).
The [merchant observation contract](merchant-evidence.md) documents what the
current window proves and which values remain unknown.
