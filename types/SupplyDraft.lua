---@meta

---@class SkillUpSupplyDraft
---@field skillLine integer
---@field alpha number Explicit starting-only completion target in (0,1].
---@field products table<integer, true> Complete competing product universe.
---@field offers SkillUpSupplyDraftOffer[]?
---@field adaptiveOffers SkillUpAdaptiveSupplyDraftOffer[]?
---@field economics {version: integer, laws: SkillUpAdaptiveEconomicLaws}?
---@field fixed {options: SkillUpPolicyOptions, refillOrders: SkillUpSourceRefillOrder[]}?
---@field adaptive {options: SkillUpAdaptiveSourceOptions, crafted: SkillUpCraftedSourceToken?}?

---@class SkillUpSupplyDraftOffer
---@field offer SkillUpObservedMerchantOffer
---@field version integer
---@field laws SkillUpSourceLaws

---@class SkillUpAdaptiveSupplyDraftOffer
---@field offer SkillUpObservedMerchantOffer
---@field version integer
---@field laws SkillUpAdaptiveSourceLaws

---@class SkillUpSupplyDraftAPI
---@field Validate fun(draft: SkillUpSupplyDraft): SkillUpSupplyDraft?, table[]
---@field Apply fun(draft: SkillUpSupplyDraft): boolean, table[]?
