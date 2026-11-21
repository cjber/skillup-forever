---@meta

---@class SkillUpSourceLaw
---@field value any Explicit conditional value, never inferred from quote or historical maximum.
---@field provenance string Nonempty authority or assumption origin.
---@field scope string Nonempty validity scope.

---@class SkillUpSourceStockLaw
---@field key string Shared stock identity.
---@field unit string The unit the pool is counted in.
---@field perBundle integer Units one purchase consumes from the pool.
---@field available integer|'unlimited' Finite units left, or the explicit unlimited law.
---@field law 'finite-no-restock'|'unlimited'
---@field observedUnits 'items'|'bundles'|'finite-domain-restriction'? How the typed count relates to native raw stock.
---@field restriction string? Why an unlimited native listing got a finite search domain.

---@class SkillUpSourceLaws
---@field access SkillUpSourceLaw Boolean current/future access assumption.
---@field price SkillUpSourceLaw Explicit fixed quote-price assumption.
---@field stock SkillUpSourceLaw {key, perBundle, available, law}; finite-no-restock or explicit unlimited.
---@field vendor SkillUpSourceLaw Shared visit identity.
---@field ceiling SkillUpSourceLaw Integral per-transaction bundle ceiling.
---@field initialVisit SkillUpSourceLaw Nonnegative initial incremental visit cost.
---@field refillVisit SkillUpSourceLaw Nonnegative later round-trip cost.
---@field tokenValues table<string, SkillUpSourceLaw> Nonnegative values for every typed requirement.

---@class SkillUpSourceUnavailable
---@field code string
---@field offerID string?
---@field field string?

---@class SkillUpSourceRefillOrder
---@field offerID string Session-scoped distinct offer identity, never a transient source index.
---@field bundles integer

---@class SkillUpSourceAssumption
---@field observedAt integer
---@field observationRevision string
---@field session integer
---@field index integer
---@field offerID string
---@field field string
---@field revision integer
---@field provenance string
---@field scope string
---@field clientBuild string?
---@field projectID integer?
---@field poolUnit string?
---@field observedUnits string?
---@field restriction string?

---@class SkillUpDeclaredSource
---@field offer SkillUpObservedMerchantOffer
---@field revision integer
---@field evidence SkillUpSourceAssumption[]
---@field valid boolean
---@field quote SkillUpMerchantQuote
---@field tokenValues table<string, number>
---@field stock {key: string, perBundle: integer, available: integer|'unlimited', law: 'finite-no-restock'|'unlimited'}
---@field access boolean
---@field vendor string
---@field ceiling integer
---@field initialVisit number
---@field refillVisit number

---@class SkillUpSupplySourceOwner
---@field DeclareAdaptive fun(offer: SkillUpObservedMerchantOffer, version: integer, laws: SkillUpAdaptiveSourceLaws): boolean, SkillUpSourceUnavailable[]?
---@field DeclareEconomics fun(version: integer, laws: SkillUpAdaptiveEconomicLaws): boolean, SkillUpSourceUnavailable[]?
---@field ReadAdaptive fun(options: SkillUpAdaptiveSourceOptions, products: table<integer, true>, crafted: SkillUpCraftedSourceToken?): SkillUpAdaptiveSupplyRequest?, SkillUpSourceUnavailable[]
---@field InspectAdaptive fun(products: table<integer, true>, workLimit: integer): SkillUpSourceEvidence Alpha-free inspection with explicit assembly budget. Recipe coordinate completeness is checked by RouteDemand.
---@field ConfigureAdaptive fun(skillLine: integer, alpha: number, options: SkillUpAdaptiveSourceOptions, products: table<integer, true>, crafted: SkillUpCraftedSourceToken?): boolean, string?
---@field Inspect fun(products: table<integer, true>): SkillUpSourceEvidence No alpha or solver required.
---@field Declare fun(offer: SkillUpObservedMerchantOffer, version: integer, laws: SkillUpSourceLaws): boolean, SkillUpSourceUnavailable[]?
---@field Read fun(options: SkillUpPolicyOptions, refillOrders: SkillUpSourceRefillOrder[], products: table<integer, true>): SkillUpResupplyInput?, SkillUpSourceUnavailable[]
---@field Configure fun(skillLine: integer, alpha: number, options: SkillUpPolicyOptions, refillOrders: SkillUpSourceRefillOrder[], products: table<integer, true>): boolean, string?

---@class SkillUpSourceEvidence
---@field status 'conditional'|'unavailable'
---@field scope 'current-merchant-window' Does not establish completeness beyond the observed window.
---@field sourceRevision integer
---@field missing SkillUpSourceUnavailable[] Structured missing law or observation fields.
---@field assumptions SkillUpSourceAssumption[]

---@class SkillUpAdaptiveSourceLaws
---@field access SkillUpSourceLaw Fixed boolean access, consistent with current native eligibility.
---@field price SkillUpSourceLaw Explicit 'fixed' price law.
---@field vendor SkillUpSourceLaw Shared visit identity.
---@field ceiling SkillUpSourceLaw Positive integral bundle ceiling within observed item-unit maximum.
---@field stock SkillUpSourceLaw Explicit finite-no-restock {key, unit, available, perBundle, observedUnits, restriction?}. observedUnits is items, bundles or finite-domain-restriction.
---@field initialDelivery SkillUpSourceLaw Explicit 'certain' initial-delivery assumption.
---@field futureDelivery SkillUpSourceLaw Explicit {chance, payOnFailure} independent bundle law.

---@class SkillUpAdaptiveEconomicLaws
---@field initialVisitMoney SkillUpSourceLaw Map of vendor to integer wallet fare, including explicit zero.
---@field refillVisitMoney SkillUpSourceLaw Map of vendor to integer wallet fare.
---@field initialVisitValue SkillUpSourceLaw Map of vendor to nonnegative opportunity value.
---@field refillVisitValue SkillUpSourceLaw Map of vendor to nonnegative opportunity value.
---@field tokenValues SkillUpSourceLaw Complete typed payment coordinate values.
---@field terminalCarry SkillUpSourceLaw Complete modeled coordinate carry values, including recipe outputs.
---@field failureLoss SkillUpSourceLaw Explicit nonnegative unfinished termination loss.

---@class SkillUpAdaptiveDeclaredSource
---@field offer SkillUpObservedMerchantOffer
---@field revision integer
---@field evidence SkillUpSourceAssumption[]
---@field valid boolean
---@field quote SkillUpMerchantQuote
---@field stock {key: string, unit: string, available: integer, perBundle: integer, observedUnits: string, restriction: string?}
---@field access boolean
---@field vendor string
---@field ceiling integer
---@field delivery {chance: number, payOnFailure: boolean}

---@class SkillUpAdaptiveEconomics: SkillUpFiniteObjectiveLaws
---@field session integer Economic laws bind this merchant session.
---@field revision integer
---@field evidence SkillUpSourceAssumption[]

---@class SkillUpAdaptiveSourceOptions
---@field workLimit integer
---@field stateLimit integer
---@field coordinateLimit integer
---@field limbLimit integer

---@class SkillUpCraftedSourceToken
---@field version 'crafted-adapter-v1'
---@field revision integer
---@field skillLine integer

---@class SkillUpAdaptiveEconomicMaps
---@field tokenValues table<string, number>
---@field terminalCarry table<string, number>
---@field initialVisitMoney table<string, integer>
---@field refillVisitMoney table<string, integer>
---@field initialVisitValue table<string, number>
---@field refillVisitValue table<string, number>
