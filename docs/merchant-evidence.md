# Merchant observations

`ns.MerchantOffers.current` holds the current merchant window's ordered offers.
Each row belongs to its window session and transient index. Two rows for the same
NPC and product remain separate, including different token requirements. Closing
the merchant revokes the window. Historical records never populate this table.

Each offer records the readable original components in `rawInfo`, validated
`price` and `stackCount`, raw `numAvailable`, product identity, build/version,
interface and project ID when available, observation time and source revision.
Missing money or quantity stays unknown. No previous vendor or auction quote is
inherited. Product-side `currencyID` never identifies a required currency.

`rawCostCount` and `costs` retain every reported requirement slot, including
missing slots. Each records raw texture, quantity, link and currency name.
`requirementsComplete` requires valid money and bundle amounts, a consistent
explicit extended-cost flag/count, and positive integral quantities and stable
typed identities for every slot. There is no three-cost truncation. An item link
is resolved only through `C_Item.GetItemInfoInstant`; a currency link only through
`C_CurrencyInfo.GetCurrencyIDFromLink`. Names and textures never supply identity.
A name-only currency requirement stays incomplete. Duplicate typed requirements
are summed when quoting a bundle, rather than checking each against the same
balance independently.

Capabilities are recorded separately for structured item info, cost count, each
cost slot and identity resolver, native maximum, affordability and build. Missing,
failed and unreadable calls do not disable independent observations.
`isPurchasable`, `isUsable` and `canAfford` preserve separate booleans, including
false. `rawNativeMaximum` retains the native answer; `maxPurchaseItems` validates
its integral form. It is a dated per-purchase ceiling, never stock or future
supply. `rawCanAfford` retains the affordability answer independently.

`MerchantOffers.Quote(offer, bundles)` returns only integer-bundle arithmetic:
item units, money and all token/currency requirements. `BundleBound` takes an
explicit wallet and typed balances and intersects their whole-bundle bounds with
the native ceiling. This is conditional arithmetic, not a successful-order or
supply certificate. It never uses stock. `RouteDemand.QuoteOrders` quotes explicit
current offer selections, rejecting replaced observations so a reordered index
cannot silently select a different offer. It does not choose orders, alter live
shopping counts, or set the coverage job's `costKnown`.

Positive stock units remain unverified. No `stockUnit` is written: neither
multiplication nor division by bundle size is justified. Raw -1 is preserved,
but no `certifiedUnlimited` or future replenishment guarantee is written. Raw
zero is a sold-out observation. Access, travel/setup cost, refill timing and
future availability remain unknown; none defaults to zero.

Every changed component, including a token identity or independent capability,
emits `sourceEvidence` through `Core/Changes.lua`. Identical observations emit
nothing. A new observation timestamp changes freshness, preserving the dated
evidence contract. RouteDemand's existing observer revokes its certificates on
this event.

## Historical compatibility

`ns.db.merchantEvidence[npcID][itemID]` remains the last dated product observation
at that NPC, separate from the complete window. For duplicate product rows it
retains the last row for compatibility; complete-offer consumers use the window.
`price`, `stackCount`, `hasExtendedCost` and `numAvailable` retain their existing
validated meanings. `unitCopper` is the money-only quotient, absent for extended
costs. `stockSource` remains `C_MerchantFrame.GetItemInfo.numAvailable`; `stock`
keeps the legacy count or `"unlimited"` normalization. That string does not certify
future supply. `ns.db.stock` remains the separate historical maximum.

Sparse old records remain untouched. Never reconstruct quantities, bundle totals
or availability from their unit prices or historical maxima.

## Source contract

Inspected Blizzard-authored UI source through Gethe's public mirror at Forever
revision [`bebcb6bf309cf41b41bd74f8ca651e6a105b2676`](https://github.com/Gethe/wow-ui-source/tree/bebcb6bf309cf41b41bd74f8ca651e6a105b2676),
version 1.60.1.70938. This is source evidence, not a native runtime observation.

- [MerchantFrameDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/MerchantFrameDocumentation.lua)
  declares structured quote fields and separate eligibility booleans, without
  stock units or a definition of native maximum/supply.
- [Mainline MerchantFrame.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/MerchantFrame.lua)
  lines 713-741 use item units in the splitter and native ceiling; lines 802-812
  scale non-money costs by item count divided by bundle size. Currency-name rows
  do not participate in the explicit item-token affordability loop. The UI's
  three displayed cost slots are not a documented native requirement limit.
- [Vanilla MerchantFrame.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_UIPanels_Game/Vanilla/MerchantFrame.lua)
  uses the legacy tuple API and equivalent bundle formulas. File presence does
  not prove which family the running client selects. The observer currently
  captures structured info only; absent capability leaves the quote incomplete.
- [ItemButtonTemplate.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua)
  displays positive stock unchanged and hides nonpositive values. This does not
  establish item-versus-bundle units or a -1 unlimited guarantee.

`tests/merchant_offers_spec.lua` and `tests/source_evidence_spec.lua` exercise the
real TOC event path with synthetic inputs. They never buy anything. Illustrative
UI renders and source tests are not native proof.

Issue #563 remains open: stock semantics, feasible repeated acquisitions, shared
inventory, economic count selection, source access and measured/explicit travel
or farm inputs still need integration. No fixed 95% policy or optimality claim
follows from these observations.

The conditional adaptive provider in `Core/SupplySources.lua` checks explicit
laws against these current observations before registering its prepared reader.
Positive raw stock requires an explicit item/bundle relation. Raw `-1` supports
only an explicitly restricted finite opportunity domain, without a native stock
claim. False purchase eligibility, sold-out positive pools and excessive
transaction ceilings cannot be overridden by declarations. Native affordability
is kept separate from fixed access: the existing RouteDemand snapshot reads the
wallet and typed balances and the finite evaluator checks complete atomic
payments, including fares. See [supply-policy.md](supply-policy.md).
