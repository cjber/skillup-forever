---@meta

---@class SkillUpSelectedAcquisition
---@field source integer Index in the frozen source list.
---@field offerID string? Source owner's stable distinct-offer identity, when established.
---@field npcID integer? Selected NPC, never replaced with a nearest vendor.
---@field vendor string Shared visit identity.
---@field itemID integer
---@field bundles integer
---@field bundleUnits integer
---@field units integer Gross product units, separate from token payments.
---@field moneyCopper integer Transaction money total.
---@field costs table<string, integer> Complete typed transaction requirements.

---@class SkillUpSupplyChoiceResult: SkillUpResupplyResult
---@field inventoryScope 'bags-and-bank'?
---@field infimumKnown boolean? A proved infimum is distinct from a selected finite order.
---@field objectiveInfimumLower number?
---@field objectiveInfimumUpper number?
---@field nonattainment SkillUpSupplyNonattainment? Exact restricted theorem parameters, with no finite basket.
---@field sourceRevision integer? Source-owner revision of this conditional certificate.
---@field assumptions SkillUpSourceAssumption[]? Owned dated, scoped provenance for the source laws.
---@field items table<integer, integer>? Shared initial raw inventory budget, before initial token payments.
---@field have table<integer, integer>? Fresh inventory snapshot.
---@field orders SkillUpPolicyOrder[]? Selected initial transactions.
---@field quantities integer[]? Bundles by distinct source index.
---@field acquisitions SkillUpSelectedAcquisition[]? Owned INITIAL transactions only, including products used as payment tokens.
---@field initialVisits table<string, number>? One explicit setup/travel charge per selected vendor.
---@field alpha number? Explicit starting coverage constraint.

---@class SkillUpSupplyNonattainment
---@field kind 'free-unlimited-geometric'
---@field chance number In (0,1), interpreted as the exact Model.Chance input.
---@field heldUnits integer
---@field bundleUnits integer
---@field refillUnits integer Positive units per fixed refill.
---@field refillVisitCost number Positive expenditure per refill visit.

---@class SkillUpSupplyChoiceJob
---@field result SkillUpSupplyChoiceResult
---@field Advance fun(self: SkillUpSupplyChoiceJob, work: integer): SkillUpSupplyChoiceResult
---@field Cancel fun(self: SkillUpSupplyChoiceJob)

---@class SkillUpSupplyChoiceProducer
---@field Start fun(input: SkillUpResupplyInput, alpha: number): SkillUpSupplyChoiceJob Immutable inputs, one fixed refill policy.

---@class SkillUpSupplyConfiguration
---@field mode 'fixed'|'adaptive'
---@field read fun(): SkillUpResupplyInput|SkillUpAdaptiveSupplyRequest|nil, string?
---@field alpha number
---@field dirty boolean
---@field job SkillUpSupplyChoiceJob|SkillUpFiniteSelectionJob?
