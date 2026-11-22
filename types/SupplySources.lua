---@meta

---@class SkillUpSourceUnavailable
---@field code string
---@field offerID string?
---@field field string?

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

---@class SkillUpSupplySourceOwner
---@field Inspect fun(products: table<integer, true>): SkillUpSourceEvidence No alpha or solver required.

---@class SkillUpSourceEvidence
---@field status 'conditional'|'unavailable'
---@field scope 'current-merchant-window' Does not establish completeness beyond the observed window.
---@field sourceRevision integer
---@field missing SkillUpSourceUnavailable[] Structured missing law or observation fields.
---@field assumptions SkillUpSourceAssumption[]
