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

## Finite adaptive continuation

`Core/FiniteAcquisition.lua` is a separate, opt-in evaluator for a fixed initial
order and a state-dependent continuation. Its explicit contract is
`adaptive-finite`, `independent-round-trips`, `independent-bundle-outcomes` and
`expected-expenditure-plus-terminal-carry-plus-failure-loss`. It does not replace
the fixed-refill selector or choose a production policy.

The caller supplies finite nonreplenishing shared opportunity pools, fixed access
and prices, and independent per-bundle delivery probabilities. Each attempted
bundle consumes its opportunity units, even on failure. A declared
`payOnFailure` decides whether failed deliveries also pay the quoted money and
typed tokens. A grouped action reserves all possible payments against its
pre-action balances. Delivered products can fund a later visit, never their own
atomic batch. Transaction ceilings split legal transactions within one grouped
vendor visit, rather than bounding the total basket.

Monetary trip fares debit the shared wallet on every attempted visit. Separate
travel opportunity values affect the objective without increasing or decreasing
that wallet. Every fare and value, including zero, must be explicit. Initial
deliveries are declared certain and share the same finite pools as later actions.

The objective includes expected money, token opportunity and visit opportunity
expenditure, plus explicit nonnegative terminal carrying values and an explicit
loss on unfinished termination. Carry is an additional holding or disposal cost,
not a second charge for purchased inventory. No failure loss or carry valuation
is defaulted. With zero loss, stopping can correctly win; its completion
probability remains visible. Starting-only coverage C0 uses net inventory after
initial payments and disables all later acquisitions. Adaptive completion Ppi
is reported separately. This evaluator does not select an initial basket or
claim a chance-constrained optimum.

The complete finite action domain contains stop, feasible craft, and all feasible
positive source-quantity vectors. Every purchase outcome lowers the finite
opportunity sum. A craft lowers pooled consumables, or must deterministically
advance a stage without consumption. This lexicographic rank proves a finite
DAG without an invented basket cap. Probabilistic zero-consumption crafts,
restock, waiting, location-dependent travel, subcrafts and output reuse require
other transition laws and are rejected by this contract.

Explicit-stack backward induction compares exact nonnegative dyadic values of
the declared binary64 probabilities and valuations. Outward bounds are published
only after exact action selection. The certificate includes state/action/edge
counts, canonical balance and pool coordinates, owned source-index bindings and
delivery/objective/trip laws with dated assumptions, and each selected state-dependent
action with its successors. Zero-probability outcomes are excluded before child
states are evaluated. Explicit work, state, coordinate and exact-number limb
budgets, plus a checked exact exponent range, return unknown on exhaustion; they do not truncate the feasible domain.
Inputs remain immutable for the job lifetime. Getters do not advance jobs.

## Deterministic crafted kernel

The pure finite evaluator also accepts `route.version = "crafted-deterministic-v1"`.
The native adapter accepts this contract only through an explicit current
recipe-evidence declaration. Raw-demand and fixed-refill APIs retain their
consumption-only contract. The caller supplies complete deterministic laws; no law is inferred from
pricing means, schematic output bounds or a cheapest-maker estimate.

A crafted route supplies dense `recipes` and ordered `legs`, `held`, zero `buy`,
`coverage = "maximum-craft-only-completion"` and
`prerequisites = "already-satisfied"`. Each leg identifies a declared main recipe
and supplies the existing effective-skill interval, thresholds and optional
skill-up count. Each recipe has a unique positive `recipeID`, positive
`professionID`, role `main` or `auxiliary`, fixed boolean `available`, nonempty
`scope`, complete sparse integer item `use` and `produce` maps, and
`productionLaw = "deterministic-completed-attempt"`. Production must contain a
positive item quantity. `evidence` contains an integer `revision` and nonempty
`allocation` and `clientBuild` identities. These are caller declarations, not
native gameplay verification. Recipe maps are keyed by item ID, so each item has
one summed quantity rather than duplicate rows.

Recipes may supply `eligibility = {fromSkill, toSkill, fixedSkill?}` with
inclusive nonnegative integer bounds, including singleton intervals. For auxiliaries only, with
`fixedSkill`, the recipe checks that unchanged effective skill; otherwise it
checks the active main stage's effective skill. The same craft action gate
applies in both coverage and economic policies. Absent eligibility preserves
the legacy fixed `available` law.

Dynamic eligibility requires an explicit `route.skillCap` physical gain law.
A successful main attempt grants the whole `skillUps` count (default one),
bounded by that effective cap. Targets and grey thresholds do not truncate
that successful gain. Contiguous leg targets select main recipes; overshoot
carries across legs and skips targets already reached. Prepared stages retain
the exact effective skill, including modifiers. Without `skillCap`, legacy
routes retain their existing target-clipped planning stages. The certificate
owns the cap, recipe bounds and each main stage's skill.

Main recipes declare `skillEffect = "route"`. Auxiliaries must explicitly declare
`skillEffect = "neutral"`, including neutrality in other professions whose skills
could change a subsequent law. Grey auxiliaries still produce items. Skill-affecting
auxiliaries are rejected until skill state and boundary normalization are modeled.
All rank, training, tool, station and access prerequisites must already hold and
remain fixed. The universe is finite and declared: the optimum is conditional on
those recipes and does not claim to discover every live alternative.

A craft checks all consumption against pre-action inventory, debits it, then
credits products with checked integer arithmetic. Both skill-gain and no-gain
branches produce the same items. Execution failure, refunds, random output and
other effects are excluded by the supplied law. Main recipes are selectable only
in their active leg. Auxiliary recipes are selectable throughout unfinished
states, including when no immediate shortage exists. Item outputs, reagents and
source item-token payments share one balance. Neither crafting nor an acquisition
batch can use its own outputs to fund pre-action requirements. Terminal completion
is absorbing. Every modeled coordinate, including outputs and valuation-only
coordinates, requires an explicit terminal carry value.

The compiler adds an edge from every positively consumed item to every positively
produced item for every declared recipe and rejects cycles, including self-loops.
A deterministic raw-first topological order proves that each non-progress craft
lowers the first changed inventory coordinate. The full lexicographic rank is
remaining opportunity units, remaining main stages, then balances in that item
order. Every positive-probability edge is checked against this rank. A free main
craft is allowed only when its gain is certain; free auxiliaries are rejected.
This sufficient proof needs no depth or inventory cap. Checked integer overflow
and explicit work, state, coordinate or exact arithmetic exhaustion return unknown
without a certificate.

C0 maximizes exact craft-only completion probability over all enabled declared
crafts. Ppi follows the separate minimum-economic-objective policy and may be lower,
including zero when stopping is cheapest. Equal values retain the first action:
stop, active main recipe, then auxiliaries in declaration order. The certificate
owns recipe laws and evidence, stage recipe identities and typed production maps,
the topological item order, rank schema, and separate `coveragePolicy` and `policy`
records with recipe identity, role, state rank and selected successors. Inputs
remain immutable during a job. Callers must cancel both partial and complete jobs
when recipe, allocation, eligibility or production evidence changes; the kernel
also retains existing chance-revision invalidation. The opt-in native snapshot adapter described below connects this contract to
finite selection. No craft instruction consumer is connected.

## Finite initial selection

`FiniteAcquisition.Select(input, alpha)` enumerates the complete initial quantity
domain bounded by the finite opportunity pools. The input's `initialOrders`
decision slot must be explicitly empty. Atomic payments, shared stock, access
and legal transaction ceilings remain the evaluator's feasibility rules. An
empty purchase is a candidate too.

Eligibility requires exact starting-only C0 >= the explicitly supplied alpha.
The selector compares private immutable dyadic coverage and total objective
values, rather than their published rounded bounds. Exact ties retain the first
source vector in declared enumeration order. One aggregate work budget includes
child evaluation and comparison work. An unresolved candidate or exhausted
budget returns unknown, without presenting an incumbent as globally optimal.
Only complete enumeration can certify a selected order or finite infeasibility.

The selected result owns legal initial orders, dense source quantities, the
adaptive policy certificate, and enumeration counts. `have` is the native held
inventory; `items` is held plus gross initial products before item-token
payments. C0 uses net post-payment inventory. Source identities and typed
payments retain that distinction. Cancellation or a probability revision
invalidates private exact values before reuse. This remains opt-in: no alpha,
future law, failure loss or carrying value is chosen for the player.

## Native adaptive snapshot

`RouteDemand.StartAdaptive(plan, request, alpha)` is a separate opt-in native
adapter. The request explicitly contains `inventoryScope = "bags-only"` and a
finite adaptive `policy`; alpha is supplied separately in `[0, 1]`. It does not
replace the existing fixed-policy adapter.

The request and final plan remain immutable while the asynchronous snapshot is
being copied. The copy accepts bounded acyclic plain records and replaces the
caller's route, item balances, currency balances and wallet with owned live
inputs. Copying, coordinate collection, native reads and enumeration advance
only under the job's operation budget. No getter drains the job. Invalidating
route, resources, source evidence or probability cancels partial and completed
jobs, including invalidation during a native read.

The complete modeled inventory domain includes route reagents, every source
product even when inaccessible, typed payments, explicit currency identities,
and token or carrying valuation coordinates. The coordinate budget is checked
before native balance reads. Every item read explicitly excludes bank, uses,
reagent bank and account bank. Missing, unreadable or invalid quantities remain
unknown; caller placeholders and display inventory fallbacks supply no balance.
The completed result carries explicit adaptive service and bags-only scope.
Crafted results also carry `recipeRevision`, `recipeScope` and an owned
`recipeEvidence` snapshot of observations and declarations, separate from the
kernel certificate. Known unmet Plan training/rank steps, native requirements,
rank caps and missing eligibility bounds prevent certification.

Future supply laws and finite pool reconciliation remain the source owner's
responsibility. Native holdings and current merchant observations establish no
future delivery, price or restocking law. Requests without `crafted` retain the raw-consumption contract and reject
subcrafts and output reuse. An explicit `crafted` token selects the separately
versioned [recipe evidence adapter](recipe-evidence.md). It compiles final Plan
legs against the entire declared finite recipe universe, including neutral
auxiliaries, and reads every input and output coordinate. Random production
and skill-affecting auxiliaries remain unsupported.

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

`SelectAdaptiveSupply(plan, request, alpha)` publishes the native adaptive job
through that same plan owner. `ConfigureAdaptiveSupply(skillLine, read, alpha)`
accepts explicit alpha in `[0, 1]` and a reader returning a fresh complete scoped
request on every revision. Fixed `ConfigureSupply` retains `(0, 1]`. Either
configuration API can remove the current mode with a nil reader. Invalid inputs
preserve the existing configuration; replacing modes cancels its owned work and
completed result. Reader failure or nil publishes structured unknown.

These adapters stay session-only. They do not supply a default target or infer a
future law from an observation. No page configures them: the Supply tab was removed.

The shared frame dispatches one dirty profession per update and advances published
jobs within one total 64-operation budget. Getters perform neither task. Only a
current complete result with owned `items` and `have` supplies counts. The plan
retains the whole result, including adaptive service, bags-only scope, selection
proof, source revision, dated assumptions and finite certificate. Route, shopping
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

## Current merchant adaptive provider

`SupplySources.DeclareAdaptive(offer, revision, laws)` binds explicit conditional
laws to the exact current merchant observation. It requires fixed access and
price, vendor identity, a positive bundle ceiling within the observed native
item ceiling, certain initial delivery, independent future delivery probability
and failure payment, and a finite nonreplenishing opportunity pool. Every law
carries its own provenance and scope. Invalid replacements preserve the valid
record. All competing offers for the explicit product set must be declared,
including inaccessible offers.

A stock declaration contains `key`, `unit`, `available`, `perBundle`,
`law = "finite-no-restock"`, and `observedUnits`. Explicit `"items"` or
`"bundles"` relates the pool to raw stock and requires exact whole-bundle
consistency. Raw `-1` only permits `"finite-domain-restriction"` with an explicit
`restriction` scope. This bounds the conditional search domain; it does not
certify native stock. Missing units, sold-out positive pools, unavailable
eligibility, contradictory access and excessive ceilings are rejected.
`canAfford` is a dated observation, not a fixed access law. Fresh shared native
balances decide atomic affordability through RouteDemand.

`DeclareEconomics(revision, laws)` separately owns scoped declarations for
`initialVisitMoney`, `refillVisitMoney`, `initialVisitValue`, `refillVisitValue`,
`tokenValues`, `terminalCarry` and `failureLoss`. Each uses the same
`{value, provenance, scope}` wrapper. Maps contain explicit values, including
zero. Monetary fares debit the wallet; visit opportunity values do not.
Economics bind the current merchant session and require a newer revision to
replace them. Recipe-only coordinate completeness remains the existing snapshot
and kernel's responsibility.

`ReadAdaptive(options, products, crafted?)` returns an owned bags-only request
with explicit work, state, coordinate and limb budgets. `InspectAdaptive(products,
workLimit)` reports source/economic completeness without alpha, resource reads
or solver work. Its conditional status concerns provider inputs, not recipe or
route certification. `ConfigureAdaptive(skillLine, alpha, options, products,
crafted?)` accepts explicit alpha in `[0,1]` and an optional current RecipeEvidence
token. It registers a prepared reader with `RouteDemand.ConfigureAdaptiveSupply`.
Declarations and source revisions prepare requests outside reader dispatch;
RouteDemand retains the single scheduler, fresh native snapshot and publication
authority. No wallet or policy evaluator is added.

Resource events invalidate every adaptive finite pool. A newer explicit
reconciliation for each competing offer is required before republication;
reader calls cannot replenish opportunities. Observation replacement and window
closure prevent old laws from publishing. This provider adds no purchase or
craft execution and no default confidence or economic policy.
