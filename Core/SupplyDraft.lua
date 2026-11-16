---@type string, SkillUpNamespace
local _, ns = ...
if ns.broken then
	return
end

-- Player configuration boundary. This module owns a deep copy of the draft and
-- only forwards complete, explicit records to SupplySources. It never fills a
-- law from a quote, native eligibility, or a default.
local Draft = {}

local function Copy(value, seen)
	if type(value) ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] then
		return nil, "cyclic-draft"
	end
	seen[value] = true
	local result = {}
	for key, item in pairs(value) do
		local copied, reason
		copied, reason = Copy(item, seen)
		if reason then
			return nil, reason
		end
		result[key] = copied
	end
	seen[value] = nil
	return result
end

local function Positive(value)
	return type(value) == "number" and value == value and value < math.huge and value >= 1 and value % 1 == 0
end

local function RequiredTable(value, name, errors)
	if type(value) ~= "table" then
		errors[#errors + 1] = { code = "draft-section-required", field = name }
		return false
	end
	return true
end

local function DenseDeclarations(value)
	if type(value) ~= "table" then
		return false
	end
	local count, maximum = 0, 0
	for key in pairs(value) do
		if not Positive(key) then
			return false
		end
		count = count + 1
		maximum = math.max(maximum, key)
	end
	return count == maximum
end

local function Validate(draft)
	local errors = {}
	if type(draft) ~= "table" then
		return false, { { code = "draft-required" } }
	end
	if not Positive(draft.skillLine) then
		errors[#errors + 1] = { code = "skill-line-required", field = "skillLine" }
	end
	if type(draft.alpha) ~= "number" or draft.alpha ~= draft.alpha or draft.alpha <= 0 or draft.alpha > 1 then
		errors[#errors + 1] = { code = "starting-coverage-required", field = "alpha" }
	end
	if not RequiredTable(draft.products, "products", errors) then
		return false, errors
	end
	for itemID, included in pairs(draft.products) do
		if not Positive(itemID) or included ~= true then
			errors[#errors + 1] = { code = "explicit-product-identity-required", field = "products" }
		end
	end
	if draft.fixed then
		if not RequiredTable(draft.fixed, "fixed", errors) then
			return false, errors
		end
		if type(draft.fixed.options) ~= "table" or type(draft.fixed.refillOrders) ~= "table" then
			errors[#errors + 1] = { code = "fixed-policy-sections-required", field = "fixed" }
		end
	end
	if draft.adaptive then
		if not RequiredTable(draft.adaptive, "adaptive", errors) then
			return false, errors
		end
		if type(draft.adaptive.options) ~= "table" then
			errors[#errors + 1] = { code = "adaptive-options-required", field = "adaptive" }
		end
	end
	if (draft.fixed and draft.adaptive) or (not draft.fixed and not draft.adaptive) then
		errors[#errors + 1] = { code = "exactly-one-policy-required", field = "policy" }
	end
	if draft.fixed and type(draft.offers) ~= "table" then
		errors[#errors + 1] = { code = "fixed-offers-required", field = "offers" }
	end
	for _, field in ipairs({ "offers", "adaptiveOffers" }) do
		if draft[field] ~= nil and not DenseDeclarations(draft[field]) then
			errors[#errors + 1] = { code = "dense-offer-declarations-required", field = field }
			return false, errors
		end
	end
	if type(draft.offers) == "table" then
		for index, declaration in ipairs(draft.offers) do
			if
				type(declaration) ~= "table"
				or type(declaration.offer) ~= "table"
				or not Positive(declaration.version)
				or type(declaration.laws) ~= "table"
			then
				errors[#errors + 1] = { code = "invalid-fixed-offer-declaration", field = "offers[" .. index .. "]" }
			end
		end
	end
	if draft.adaptive and (type(draft.adaptiveOffers) ~= "table" or type(draft.economics) ~= "table") then
		errors[#errors + 1] = { code = "adaptive-evidence-required", field = "adaptiveOffers" }
	end
	if type(draft.adaptiveOffers) == "table" then
		for index, declaration in ipairs(draft.adaptiveOffers) do
			if
				type(declaration) ~= "table"
				or type(declaration.offer) ~= "table"
				or not Positive(declaration.version)
				or type(declaration.laws) ~= "table"
			then
				errors[#errors + 1] =
					{ code = "invalid-adaptive-offer-declaration", field = "adaptiveOffers[" .. index .. "]" }
			end
		end
	end
	if draft.economics ~= nil and type(draft.economics) ~= "table" then
		errors[#errors + 1] = { code = "economic-laws-required", field = "economics" }
	end
	if next(draft.products) == nil then
		errors[#errors + 1] = { code = "product-universe-required", field = "products" }
	end
	return #errors == 0, errors
end

---@param draft table Player-owned explicit configuration.
---@return SkillUpSupplyDraft? ownedDraft
---@return table[] errors
function Draft.Validate(draft)
	local ok, errors = Validate(draft)
	if not ok then
		return nil, errors
	end
	local owned, reason = Copy(draft)
	if not owned then
		return nil, { { code = reason } }
	end
	for index, declaration in ipairs(draft.offers or {}) do
		owned.offers[index].offer = declaration.offer
	end
	for index, declaration in ipairs(draft.adaptiveOffers or {}) do
		owned.adaptiveOffers[index].offer = declaration.offer
	end
	---@cast owned SkillUpSupplyDraft
	return owned, {}
end

---@param draft table Validated explicit configuration.
---@return boolean, table[]?
function Draft.Apply(draft)
	local owned, errors = Draft.Validate(draft)
	if not owned then
		return false, errors
	end
	return ns.SupplySources._ApplyDraft(owned)
end

---@cast Draft SkillUpSupplyDraftAPI
ns.SupplyDraft = Draft
