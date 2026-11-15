# Merchant observations

`ns.db.merchantEvidence[npcID][itemID]` stores the last observation at that NPC's
open merchant window. It is evidence, not an offer availability, access, travel,
restock or replenishment guarantee.

`price` is the original bundle's money total in copper; `stackCount` is its
original positive integral quantity. Both are optional and validated separately.
`unitCopper` is the quotient only for a valid money-only quote. Extended-cost
observations retain `hasExtendedCost = true`, including a zero money component,
and have no `unitCopper`. The flag requires non-money costs; it does not enumerate
the required currencies or tokens. Consumers must not treat `price = 0` as free.
Historical records without these raw fields remain unchanged. Never reconstruct
a one-item bundle or total from their unit quote.

`numAvailable` retains the validated raw API stock count, including zero and the
-1 unlimited sentinel. `stockSource` identifies
`C_MerchantFrame.GetItemInfo.numAvailable`. `stock` remains the legacy normalized
count or `"unlimited"`. The positive count's item-versus-bundle unit has not been
established by the inspected source, so no `stockUnit` is written and consumers
must not multiply it by `stackCount` or use it as an economic quantity. Historical
maximum stock in `ns.db.stock` is separate from this dated observation.

`observedAt` uses server Unix seconds. Any component change, including a bundle
change with the same unit quote and timestamp, emits `sourceEvidence` through
`Core/Changes.lua`. An identical repeat emits nothing. This invalidates source
evidence consumers only; it does not claim an economic plan has been recomputed.

## Source contract

Inspected Blizzard UI source mirror revision
[`297d7aaaa736f346b3e036f38ee088eaf7f8c07f`](https://github.com/Gethe/wow-ui-source/tree/297d7aaaa736f346b3e036f38ee088eaf7f8c07f):

- [MerchantFrameDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/297d7aaaa736f346b3e036f38ee088eaf7f8c07f/Interface/AddOns/Blizzard_APIDocumentationGenerated/MerchantFrameDocumentation.lua)
  defines `price`, `stackCount`, `numAvailable` and `hasExtendedCost` on the info record.
- [MerchantFrame.lua](https://github.com/Gethe/wow-ui-source/blob/297d7aaaa736f346b3e036f38ee088eaf7f8c07f/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/MerchantFrame.lua)
  divides `price` by `stackCount` for affordability, passes `stackCount` to the item
  count and stack splitter, passes `numAvailable` to the stock display, and treats
  zero stock as unavailable. Extended-cost handling is separate from money.

These establish bundle money semantics and stock provenance, not a verified
positive stock unit or Forever runtime behavior. The real TOC merchant-event
regression is `tests/source_evidence_spec.lua`; no in-game proof is implied.

The live resupply adapter still needs verified stock units, complete extended-cost
requirements, current eligibility and acquisition/travel inputs. Shared inventory,
bundle purchasing and the whole-route cost/risk policy still need integration.
This producer prerequisite does not complete #563 or certify an optimal policy.
