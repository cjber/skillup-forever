---@type string, SkillUpNamespace
local _, ns = ...
if ns.broken then
	return
end
local L = ns.L

-- The supply page is a small native form. Everything the merchant shows now is read-only on the row; every
-- future law is a control the player sets before SupplyDraft.Apply can publish it. No price, stock, delivery or
-- travel law is inferred from the observation, and no number is prefilled.
--
-- Work, state, coordinate and exact-number limits are the solver's capacity, not the player's assumptions about
-- the game. They are owned here and never shown: the shared frame advances a job by 64 operations per update, so
-- these limits only say how much one applying session may try, not how much the merchant will sell.
local FIXED_OPTIONS = {
	workLimit = 100000,
	stateLimit = 1000,
	coordinateLimit = 32,
	probabilityTolerance = 1e-9,
	costTolerance = 1e-8,
	visitTolerance = 1e-9,
}
local ADAPTIVE_OPTIONS = {
	workLimit = 1000000,
	stateLimit = 1000,
	coordinateLimit = 32,
	limbLimit = 256,
}

-- Session data, not player text: a provenance/scope pair for each typed law, and the scope of a finite search
-- restriction the player set on an otherwise unlimited merchant listing.
local PROVENANCE = "player entered for the current merchant window"
local RESTRICTION = "player limit for an unlimited merchant listing"

local ROW_PITCH = 22
local INPUT_WIDTH = 72
local CHECK = 22
local OFFERS_TOP = -400

---@type SkillUpSupplyPage
local page
---@type integer?
local selected
local alphaBox, adaptiveBox, failureBox
local alphaLabel, adaptiveLabel, failureLabel
---@type SkillUpSupplyLabel?
local status
---@type SkillUpSupplyLabel?
local readout
---@type SkillUpSupplyApply?
local apply
-- Every addressable control, by name, so the callbacks and a spec read the form the same way.
---@type table<string, any>
local fields = {}
-- The merchant observation the form was last built for. A replaced window or offer clears typed laws.
local rendered = "\0"
local applying = false
local dirty = false
-- One frame per merchant slot, reused for the life of the page: an ordinary refresh never makes a row.
---@type table<integer, SkillUpSupplyRow>
local rows = {}
local Refresh
-- The page's own vertical rhythm; the scroll content starts every offer below the readout.
local layout = { alphaY = -56, adaptiveY = -80, failureY = -104, applyY = -132, statusY = -164, readoutY = -186 }

local function Money(copper)
	if copper == nil then
		return L["price unknown"]
	end
	if ns.Model and ns.FormatNet then
		return ns.FormatNet(ns.Model.RoundMoney(math.abs(copper)), copper < 0)
	end
	return tostring(copper)
end

local function ItemName(itemID)
	local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
	return name or L["item %d"]:format(itemID)
end

---@param cost table
---@return string
local function CostName(cost)
	if type(cost.currencyName) == "string" and cost.currencyName ~= "" then
		return cost.currencyName
	end
	if cost.kind == "item" and cost.id then
		return ItemName(cost.id)
	end
	if cost.id then
		return L["currency %d"]:format(cost.id)
	end
	return L["an unknown payment"]
end

---@param parent Frame
---@param text string
---@param x number
---@param y number
---@param width number
---@return SkillUpSupplyLabel
local function Label(parent, text, x, y, width)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall") --[[@as SkillUpSupplyLabel]]
	label:SetPoint("TOPLEFT", x, y)
	label:SetWidth(width)
	label:SetJustifyH("LEFT")
	label:SetText(text)
	return label
end

---@param parent Frame
---@param name string
---@param x number
---@param y number
---@param width number
---@return SkillUpSupplyInput
local function Input(parent, name, x, y, width)
	local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate") --[[@as SkillUpSupplyInput]]
	box:SetSize(width, 20)
	box:SetPoint("TOPLEFT", x, y)
	box:SetAutoFocus(false)
	box:SetMaxLetters(32)
	box.name = name
	box:SetScript("OnTextChanged", function()
		Refresh()
	end)
	fields[name] = box
	return box
end

local function Checked(name)
	local field = fields[name]
	return field ~= nil and field:GetChecked() == true
end

local function Number(name)
	local field = fields[name]
	local text = field and field:GetText() or ""
	if text == "" then
		return nil
	end
	local value = tonumber(text)
	if value == nil or value ~= value or value < 0 or value >= math.huge then
		return nil
	end
	return value
end

local function Whole(name)
	local value = Number(name)
	if value and value >= 1 and value % 1 == 0 then
		return value
	end
end

-- Money is whole copper; a typed fraction is not a price the merchant can have charged.
local function Cash(name)
	local value = Number(name)
	if value and value % 1 == 0 then
		return value
	end
end

local function Text(name)
	local field = fields[name]
	local value = field and field:GetText() or ""
	return value ~= "" and value or nil
end

---@param value any
---@param field string
---@param offer SkillUpObservedMerchantOffer?
---@return SkillUpSourceLaw
local function Law(value, field, offer)
	return {
		value = value,
		provenance = PROVENANCE,
		scope = field .. " for offer " .. tostring(offer and offer.index or 0),
	}
end

---@param offer SkillUpObservedMerchantOffer
---@return string
local function Vendor(offer)
	if type(offer.npcID) == "number" then
		return "npc:" .. tostring(offer.npcID)
	end
	return "current merchant"
end

---@param plan SkillUpPlan
---@return table<integer, true>
local function Products(plan)
	local products = {}
	for _, item in ipairs(ns.RouteReagents(plan) or {}) do
		if item.itemID then
			products[item.itemID] = true
		end
	end
	return products
end

---@return table<integer, SkillUpProfession>
local function Professions()
	return ns.RouteProfessions() or {}
end

-- The open profession, kept while it is still known. A removed profession is forgotten rather than drawing a
-- stale plan, and the window switching professions moves the form to the new one.
local function SelectProfession()
	local professions = Professions()
	local open = ns.OpenSkillLine and ns.OpenSkillLine()
	if open and professions[open] then
		selected = open
	elseif selected and professions[selected] then
		return
	else
		selected = nil
	end
end

---@return SkillUpPlan?
local function CurrentPlan()
	local profession = selected and Professions()[selected]
	return profession and ns.PlanRoute(profession) or nil
end

---@param window SkillUpMerchantOfferWindow?
---@return SkillUpObservedMerchantOffer[]?
local function OfferSet(window)
	if not (window and window.offers and #window.offers > 0) then
		return nil
	end
	return window.offers
end

-- The parts of an offer a typed law reads. A rescan can hand back equal offers in new tables and stamp them with
-- a new time; neither is a different window, so the form keeps what the player typed.
local OBSERVED = {
	"itemID",
	"npcID",
	"price",
	"stackCount",
	"numAvailable",
	"maxPurchaseItems",
	"isPurchasable",
	"isUsable",
	"hasExtendedCost",
	"requirementsComplete",
}

---@param offer SkillUpObservedMerchantOffer
---@return string
local function OfferContent(offer)
	local parts = {}
	for _, key in ipairs(OBSERVED) do
		parts[#parts + 1] = tostring(offer[key])
	end
	for _, cost in ipairs(offer.costs or {}) do
		parts[#parts + 1] = table.concat({
			tostring(cost.slot),
			tostring(cost.kind),
			tostring(cost.id),
			tostring(cost.quantity),
		}, ":")
	end
	return table.concat(parts, ";")
end

-- A replacement window or a changed offer, not a restock or a rescan: slot numbers are not identities, and the
-- clock and a table's address are not content, so only those clear the typed laws and every checkbox consent.
---@param window SkillUpMerchantOfferWindow?
---@param offers SkillUpObservedMerchantOffer[]?
---@return string
local function Observation(window, offers)
	if not (window and offers) then
		return "closed"
	end
	local parts = { tostring(window.session) }
	for index, offer in ipairs(offers) do
		parts[#parts + 1] = tostring(index) .. "=" .. OfferContent(offer)
	end
	return table.concat(parts, "|")
end

local function ClearFields()
	for _, field in pairs(fields) do
		if field.SetText then
			field:SetText("")
		end
		if field.SetChecked then
			field:SetChecked(false)
		end
	end
end

-- The finite or unlimited stock law the row asked for. A finite count is checked against what the merchant
-- showed before it can reach the source owner, so the record never claims a stock the window already denies.
---@param field string
---@param offer SkillUpObservedMerchantOffer
---@param quote SkillUpMerchantQuote
---@param adaptive boolean
---@return SkillUpSourceStockLaw?
---@return string?
local function StockLaw(field, offer, quote, adaptive)
	local pool
	if Checked(field .. "ownStock") then
		pool = "offer:" .. tostring(offer.session) .. ":" .. tostring(offer.index)
	else
		pool = Text(field .. "pool")
		if not pool then
			return nil, L["Name the stock each offer draws on, or give this offer its own stock."]
		end
	end
	if not adaptive and Checked(field .. "unlimited") then
		return {
			key = pool,
			unit = "items",
			perBundle = quote.units,
			available = "unlimited",
			law = "unlimited",
		}
	end
	local left = Whole(field .. "stock")
	if not left then
		return nil
	end
	if adaptive and offer.numAvailable == -1 then
		if not Checked(field .. "restrict") then
			return nil, L["The merchant shows no limit: limit the search to the number you will buy."]
		end
		return {
			key = pool,
			unit = "items",
			perBundle = quote.units,
			available = left,
			law = "finite-no-restock",
			observedUnits = "finite-domain-restriction",
			restriction = RESTRICTION,
		}
	end
	local items = Checked(field .. "stockItems")
	local available = items and left or left * quote.units
	local observedUnits = items and "items" or "bundles"
	if adaptive and offer.numAvailable then
		local bundles = available / quote.units
		local observed = items and bundles * quote.units or bundles
		if offer.numAvailable >= 0 and observed ~= offer.numAvailable then
			return nil, L["The stock you assume does not match what the merchant shows."]
		end
	end
	return {
		key = pool,
		unit = observedUnits,
		perBundle = quote.units,
		available = available,
		law = "finite-no-restock",
		observedUnits = observedUnits,
	}
end

-- The whole form as a draft, or the words that keep Apply off. Every economic map is built here, so two offers
-- that name one shared coordinate with different values stop the apply instead of the last one winning.
---@param plan SkillUpPlan
---@param window SkillUpMerchantOfferWindow
---@return SkillUpSupplyDraft?
---@return string?
local function Draft(plan, window)
	local skillLine = selected
	if not skillLine then
		return nil, L["Open a profession to set its supply policy."]
	end
	local offers = OfferSet(window)
	if not offers then
		return nil, L["Open the profession and a merchant window."]
	end
	local percent = Number("alphaPercent")
	local alpha = percent and percent / 100
	if not alpha or alpha <= 0 or alpha > 1 then
		return nil, L["Enter a starting chance between 1 and 100."]
	end
	local products = Products(plan)
	if next(products) == nil then
		return nil, L["The merchant sells none of this route's reagents."]
	end
	local adaptive = Checked("adaptive")
	local version = (ns.SupplyUIRevision or 0) + 1
	local declarations, pools = {}, {}
	local visits = { money = {}, refillMoney = {}, value = {}, refillValue = {} }
	local tokenValues, tokenCarry, itemCarry = {}, {}, {}
	---@param map table<string, number>
	---@param key string
	---@param value number
	---@param conflict string
	---@return string?
	local function Merge(map, key, value, conflict)
		if map[key] ~= nil and map[key] ~= value then
			return conflict
		end
		map[key] = value
	end
	for index, offer in ipairs(offers) do
		if products[offer.itemID] then
			local prefix = "offer" .. index .. "."
			local quote = ns.MerchantOffers.Quote(offer, 1)
			if not quote then
				return nil, L["The merchant's offer for %s is incomplete."]:format(ItemName(offer.itemID))
			end
			if not Checked(prefix .. "priceStays") then
				return nil, L["Every offer needs its price to stay as shown."]
			end
			local ceiling = Whole(prefix .. "ceiling")
			if not ceiling then
				return nil, L["Fill in every value this offer needs."]
			end
			local bound = offer.maxPurchaseItems and math.floor(offer.maxPurchaseItems / quote.units) or nil
			if bound and ceiling > bound then
				return nil, L["The merchant sells fewer purchases at a time than that."]
			end
			local initialMoney = Cash(prefix .. "initialMoney")
			local refillMoney = Cash(prefix .. "refillMoney")
			if not initialMoney or not refillMoney then
				return nil, L["Fill in every value this offer needs."]
			end
			local stock, stockReason = StockLaw(prefix, offer, quote, adaptive)
			if not stock then
				return nil, stockReason or L["Fill in every value this offer needs."]
			end
			local prior = pools[stock.key]
			if
				prior
				and (
					prior.available ~= stock.available
					or prior.perBundle ~= stock.perBundle
					or prior.observedUnits ~= stock.observedUnits
				)
			then
				return nil, L["Offers that draw on one stock pool need the same stock."]
			end
			pools[stock.key] = stock
			local vendor = Vendor(offer)
			local conflict = Merge(
				visits.money,
				vendor,
				initialMoney,
				L["Offers at one vendor need the same trip costs and values."]
			)
			conflict = conflict
				or Merge(
					visits.refillMoney,
					vendor,
					refillMoney,
					L["Offers at one vendor need the same trip costs and values."]
				)
			if conflict then
				return nil, conflict
			end
			local laws = {
				access = Law(Checked(prefix .. "access"), "access", offer),
				price = Law("fixed", "price", offer),
				vendor = Law(vendor, "vendor", offer),
				ceiling = Law(ceiling, "ceiling", offer),
				stock = Law(stock, "stock", offer),
				initialVisit = Law(initialMoney, "initialVisit", offer),
				refillVisit = Law(refillMoney, "refillVisit", offer),
				tokenValues = {},
			}
			if adaptive then
				local initialValue = Cash(prefix .. "initialValue")
				local refillValue = Cash(prefix .. "refillValue")
				if not initialValue or not refillValue then
					return nil, L["Fill in every value this offer needs."]
				end
				conflict = Merge(
					visits.value,
					vendor,
					initialValue,
					L["Offers at one vendor need the same trip costs and values."]
				) or Merge(
					visits.refillValue,
					vendor,
					refillValue,
					L["Offers at one vendor need the same trip costs and values."]
				)
				if conflict then
					return nil, conflict
				end
				local delivered = Number(prefix .. "chancePercent")
				local chance = delivered and delivered / 100
				if not chance or chance > 1 then
					return nil, L["Enter the chance each later purchase arrives, from 0 to 100."]
				end
				if not Checked(prefix .. "initialPaid") then
					return nil, L["Check that the first purchase arrives for certain at every offer."]
				end
				local carry = Number(prefix .. "carryItem")
				if not carry then
					return nil, L["Fill in every value this offer needs."]
				end
				conflict = Merge(
					itemCarry,
					"item:" .. tostring(offer.itemID),
					carry,
					L["One item or payment needs one leftover value."]
				)
				if conflict then
					return nil, conflict
				end
				laws.initialDelivery = Law("certain", "initialDelivery", offer)
				laws.futureDelivery =
					Law({ chance = chance, payOnFailure = Checked(prefix .. "payFailure") }, "futureDelivery", offer)
			end
			for key in pairs(quote.costs) do
				local value = Number(prefix .. "token." .. key)
				if value == nil then
					return nil, L["Fill in every value this offer needs."]
				end
				if adaptive then
					local carry = Number(prefix .. "carry." .. key)
					if carry == nil then
						return nil, L["Fill in every value this offer needs."]
					end
					conflict = Merge(tokenCarry, key, carry, L["One item or payment needs one leftover value."])
				end
				if not adaptive then
					laws.tokenValues[key] = Law(value, "token " .. key, offer)
				end
				conflict = conflict
					or Merge(tokenValues, key, value, L["Offers that use one payment need the same value for it."])
				if conflict then
					return nil, conflict
				end
			end
			declarations[#declarations + 1] = { offer = offer, version = version, laws = laws }
		end
	end
	if #declarations == 0 then
		return nil, L["The merchant sells none of this route's reagents."]
	end
	---@type SkillUpSupplyDraft
	local draft = { skillLine = skillLine, alpha = alpha, products = products }
	if adaptive then
		local failure = Number("failureLoss")
		if not failure then
			return nil, L["Fill in every value this offer needs."]
		end
		draft.adaptiveOffers = declarations
		draft.adaptive = { options = ADAPTIVE_OPTIONS }
		draft.economics = {
			version = version,
			laws = {
				initialVisitMoney = Law(visits.money, "initialVisitMoney"),
				refillVisitMoney = Law(visits.refillMoney, "refillVisitMoney"),
				initialVisitValue = Law(visits.value, "initialVisitValue"),
				refillVisitValue = Law(visits.refillValue, "refillVisitValue"),
				tokenValues = Law(tokenValues, "tokenValues"),
				terminalCarry = Law(tokenCarry, "terminalCarry"),
				failureLoss = Law(failure, "failureLoss"),
			},
		}
		-- The offer item and the typed payments are one terminal-carry map. One item can be both an offer's
		-- product and another offer's payment, so two typed leftovers for it stop the apply rather than the
		-- offer item overwriting the payment.
		for key, value in pairs(itemCarry) do
			local prior = tokenCarry[key]
			if prior ~= nil and prior ~= value then
				return nil, L["One item or payment needs one leftover value."]
			end
			draft.economics.laws.terminalCarry.value[key] = value
		end
	else
		draft.offers = declarations
		draft.fixed = { options = FIXED_OPTIONS, refillOrders = {} }
	end
	return draft
end

-- The player's reason, not an internal code, for every rejection the form can cause. An unmatched code is still
-- shown, because a silent Apply is worse.
local REASONS = {
	["observation-replaced"] = L["The merchant changed. Check the form again."],
	["newer-law-revision-required"] = L["The merchant did not change, but the assumptions did. Check the form again."],
	["inconsistent-shared-source-law"] = L["Offers at one vendor need the same trip costs and values."],
	["inconsistent-token-value"] = L["Offers that use one payment need the same value for it."],
	["inconsistent-shared-pool-law"] = L["Offers that draw on one stock pool need the same stock."],
	["native-stock-conflict"] = L["The merchant shows this offer sold out."],
	["native-stock-unit-conflict"] = L["The stock you assume does not match what the merchant shows."],
	["native-stock-unavailable"] = L["The merchant does not say how much is left."],
	["native-ceiling-conflict"] = L["The merchant sells fewer purchases at a time than that."],
	["native-access-conflict"] = L["The merchant will not sell this offer to you now."],
	["stock-unit-law-missing"] = L["Choose the unit the stock count is in."],
	["missing-terminal-carry"] = L["One item or payment needs one leftover value."],
}

---@param missing any
---@return string
local function Reason(missing)
	local first = type(missing) == "table" and missing[1] or missing
	local code = type(first) == "table" and first.code or first
	if type(code) == "string" and REASONS[code] then
		return REASONS[code]
	end
	return L["The assumptions were rejected. Fill in every value and check each offer."]
end

-- The plan, its probabilities and the next modeled step: the conditional answer this policy produces, always
-- visible beside the form so a player can see what they are about to accept.
---@param plan SkillUpPlan?
local function RenderReadout(plan)
	if not readout then
		return
	end
	local lines = {}
	if not plan then
		lines[1] = L["Open a profession to see its plan and coverage."]
	else
		lines[1] = L["Plan: %s, %s to %s, %d crafts."]:format(
			plan.profession.name,
			tostring(plan.profession.base),
			tostring(plan.target),
			#plan.crafts
		)
		if plan.unpriced and plan.unpriced > 0 then
			lines[#lines + 1] = L["Unpriced crafts: %d."]:format(plan.unpriced)
		end
		local summary = ns.RouteDemand and ns.RouteDemand.Summary and ns.RouteDemand.Summary(plan)
		if summary then
			if summary.alpha then
				lines[#lines + 1] = L["Your target chance: %s%%."]:format(tostring(summary.alpha * 100))
			end
			if summary.status == "complete" and summary.successLower and summary.alpha then
				local points = (summary.successLower - summary.alpha) * 100
				if points >= 0 then
					lines[#lines + 1] = L["Margin over your target: %s points."]:format(string.format("%.2f", points))
				else
					lines[#lines + 1] = L["Below your target by %s points."]:format(string.format("%.2f", -points))
				end
			end
			if ns.SupplySummaryText then
				lines[#lines + 1] = ns.SupplySummaryText(summary)
			end
		end
		local action = ns.RouteDemand and ns.RouteDemand.NextAction and ns.RouteDemand.NextAction(plan)
		if action then
			local kinds = {
				craft = L["craft"],
				purchase = L["buy"],
				stop = L["stop"],
				unsupported = L["unknown"],
			}
			lines[#lines + 1] = L["Next step: %s."]:format(kinds[action.kind] or L["unknown"])
		end
	end
	readout:SetText(table.concat(lines, "\n"))
end

Refresh = function()
	if not (status and apply) then
		return
	end
	local window = ns.MerchantOffers and ns.MerchantOffers.current
	local plan = CurrentPlan()
	local draft, reason
	if not selected then
		reason = L["Open a profession to set its supply policy."]
	elseif not plan then
		reason = L["This profession has no plan to supply yet."]
	elseif not window then
		reason = L["Open a merchant to set this profession's supply policy."]
	elseif not OfferSet(window) then
		reason = L["Open a merchant to set this profession's supply policy."]
	else
		draft, reason = Draft(plan, window)
	end
	status:SetText(reason or L["Ready to apply these assumptions."])
	if reason then
		status:SetTextColor(1, 0.82, 0.2)
	else
		status:SetTextColor(0.2, 1, 0.2)
	end
	apply:SetEnabled(draft ~= nil)
	apply.draft = draft
	RenderReadout(plan)
end

-- Reuse the control this row already made for a name, so a refresh never adds a frame. A control hidden by an
-- earlier mode stays addressable and is shown again when its mode returns.
---@param row SkillUpSupplyRow
---@param name string
---@return any
local function Reuse(row, name)
	local field = fields[name]
	if field and field.row == row then
		row.used[#row.used + 1] = field
		if field.Show then
			field:Show()
		end
		return field
	end
end

---@param row SkillUpSupplyRow
---@param control Region
---@param name string
local function Own(row, control, name)
	local owned = control --[[@as SkillUpSupplyControl]]
	owned.field = name
	owned.row = row
	fields[name] = owned
	row.controls[#row.controls + 1] = owned
	row.used[#row.used + 1] = owned
end

---@param parent Frame
---@param index integer
---@return SkillUpSupplyRow
local function RowFrame(parent, index)
	local row = rows[index]
	if not row then
		row = CreateFrame("Frame", nil, parent) --[[@as SkillUpSupplyRow]]
		row.controls = {}
		rows[index] = row
	end
	return row
end

---@param row SkillUpSupplyRow
---@param index integer
---@param offer SkillUpObservedMerchantOffer
---@param quote SkillUpMerchantQuote
---@param adaptive boolean
---@param width number
---@return number height
local function BuildRow(row, index, offer, quote, adaptive, width)
	local prefix = "offer" .. index .. "."
	row.used = {}
	local y = 0
	local line = 0
	local function Line(text)
		line = line + 1
		local name = prefix .. "line" .. line
		local label = Reuse(row, name)
		if label then
			label:SetText(text)
			label:SetWidth(width)
			label:SetPoint("TOPLEFT", 0, y)
		else
			Own(row, Label(row, text, 0, y, width), name)
		end
		y = y - ROW_PITCH
	end
	local function Pair(text, name)
		local labelName = prefix .. name .. ".label"
		local label = Reuse(row, labelName)
		if label then
			label:SetText(text)
			label:SetWidth(width - INPUT_WIDTH - 8)
			label:SetPoint("TOPLEFT", 0, y - 3)
		else
			Own(row, Label(row, text, 0, y - 3, width - INPUT_WIDTH - 8), labelName)
		end
		local box = Reuse(row, prefix .. name)
		if box then
			box:SetPoint("TOPLEFT", width - INPUT_WIDTH, y)
		else
			Own(row, Input(row, prefix .. name, width - INPUT_WIDTH, y, INPUT_WIDTH), prefix .. name)
		end
		y = y - ROW_PITCH
	end
	local function Choice(text, name)
		local fieldName = prefix .. name
		local box = Reuse(row, fieldName)
		if box then
			box:SetPoint("TOPLEFT", 0, y)
		else
			box = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate") --[[@as SkillUpSupplyCheck]]
			box:SetPoint("TOPLEFT", 0, y)
			box:SetChecked(false)
			box.name = fieldName
			box:SetScript("OnClick", function()
				Refresh()
			end)
			Own(row, box, fieldName)
		end
		local labelName = prefix .. name .. ".label"
		local label = Reuse(row, labelName)
		if label then
			label:SetText(text)
			label:SetWidth(width - CHECK)
			label:SetPoint("TOPLEFT", CHECK, y - 3)
		else
			Own(row, Label(row, text, CHECK, y - 3, width - CHECK), labelName)
		end
		y = y - ROW_PITCH
	end
	local stock = offer.numAvailable == nil and L["unknown"]
		or (offer.numAvailable == -1 and L["no limit"] or tostring(offer.numAvailable))
	local maximum = offer.maxPurchaseItems and tostring(math.floor(offer.maxPurchaseItems / quote.units))
		or L["unknown"]
	Line(L["Offer %d: %s"]:format(index, ItemName(offer.itemID)))
	Line(
		L["The merchant shows %s in stock, %s per purchase, at most %s purchases."]:format(
			stock,
			tostring(quote.units),
			maximum
		)
	)
	Line(L["Price: %s."]:format(Money(quote.moneyCopper)))
	local records = {}
	for _, cost in ipairs(offer.costs or {}) do
		if cost.kind and cost.id then
			records[cost.kind .. ":" .. cost.id] = cost
		end
	end
	for key, quantity in pairs(quote.costs) do
		Line(L["Also costs %s %s."]:format(tostring(quantity), CostName(records[key] or {})))
	end
	if offer.isPurchasable == false then
		Line(L["The merchant will not sell this offer to you now."])
	end
	Choice(L["I can buy this offer"], "access")
	Choice(L["The price stays as shown"], "priceStays")
	Pair(L["Stock I assume is left"], "stock")
	if not adaptive then
		Choice(L["The stock does not run out"], "unlimited")
	end
	Choice(L["The stock count is in items, not purchases"], "stockItems")
	Choice(L["This offer keeps its own stock"], "ownStock")
	if adaptive and offer.numAvailable == -1 then
		Choice(L["Limit the search to the stock I typed"], "restrict")
	end
	Pair(L["Stock pool name"], "pool")
	Pair(L["Purchases allowed per visit"], "ceiling")
	Pair(L["First trip cost (copper)"], "initialMoney")
	Pair(L["Later trip cost (copper)"], "refillMoney")
	if adaptive then
		Pair(L["First trip value to you (copper)"], "initialValue")
		Pair(L["Later trip value to you (copper)"], "refillValue")
		Pair(L["Chance each later purchase arrives (%)"], "chancePercent")
		Choice(L["The first purchase arrives for certain"], "initialPaid")
		Choice(L["I pay even when a purchase does not arrive"], "payFailure")
		Pair(L["Leftover value of one %s (copper)"]:format(ItemName(offer.itemID)), "carryItem")
	end
	local keys = {}
	for key in pairs(quote.costs) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local name = CostName(records[key] or {})
		Pair(L["Value of one %s (copper)"]:format(name), "token." .. key)
		if adaptive then
			Pair(L["Leftover value of one %s (copper)"]:format(name), "carry." .. key)
		end
	end
	row:SetHeight(-y + 6)
	for _, control in ipairs(row.controls) do
		local used = false
		for _, kept in ipairs(row.used) do
			if kept == control then
				used = true
				break
			end
		end
		if not used then
			control:Hide()
		end
	end
	return -y
end

local function ContentWidth()
	local width = page and page.GetWidth and page:GetWidth() or nil
	if type(width) ~= "number" or width <= 0 then
		width = 640
	end
	return math.max(200, math.min(560, width - 44))
end

local function Render()
	if not (status and readout) then
		return
	end
	if applying then
		dirty = true
		return
	end
	local window = ns.MerchantOffers and ns.MerchantOffers.current
	local offers = OfferSet(window)
	local key = Observation(window, offers)
	if key ~= rendered then
		ClearFields()
		rendered = key
	end
	SelectProfession()
	local plan = CurrentPlan()
	local products = plan and Products(plan) or {}
	local width = ContentWidth()
	page.content:SetWidth(width)
	page.title:SetWidth(width)
	page.note:SetWidth(width)
	status:SetWidth(width)
	readout:SetWidth(width)
	alphaLabel:SetWidth(width - INPUT_WIDTH - 8)
	adaptiveLabel:SetWidth(width - CHECK)
	alphaBox:SetPoint("TOPLEFT", width - INPUT_WIDTH, layout.alphaY)
	failureLabel:SetWidth(width - INPUT_WIDTH - 8)
	failureBox:SetPoint("TOPLEFT", width - INPUT_WIDTH, layout.failureY)
	local adaptive = Checked("adaptive")
	local top = OFFERS_TOP
	local built = {}
	if plan and offers then
		for index, offer in ipairs(offers) do
			if products[offer.itemID] then
				local quote = ns.MerchantOffers.Quote(offer, 1)
				if quote then
					local row = RowFrame(page.content, index)
					local height = BuildRow(row, index, offer, quote, adaptive, width)
					row:SetPoint("TOPLEFT", 0, top)
					row:SetPoint("RIGHT", 0, 0)
					row:Show()
					top = top - height - 10
					built[index] = true
				end
			end
		end
	end
	for index, row in pairs(rows) do
		if not built[index] then
			row:Hide()
		end
	end
	page.content:SetHeight(math.max(560, -top + 24))
	Refresh()
	dirty = false
end

local function Create()
	page = CreateFrame("Frame", nil, ProfessionsFrame) --[[@as SkillUpSupplyPage]]
	page:SetAllPoints(ProfessionsFrame)
	page:Hide()
	local scroll = CreateFrame("ScrollFrame", nil, page, "ScrollFrameTemplate") --[[@as ScrollFrame]]
	scroll:SetPoint("TOPLEFT", 12, -12)
	scroll:SetPoint("BOTTOMRIGHT", -28, 18)
	page.scroll = scroll
	page.content = CreateFrame("Frame", nil, scroll)
	page.content:SetWidth(560)
	page.content:SetHeight(560)
	scroll:SetScrollChild(page.content)
	local content = page.content
	page.title = Label(content, L["Supply policy"], 0, -4, 560)
	page.note = Label(
		content,
		L["These are your own assumptions. The merchant's window only shows what it shows now."],
		0,
		-26,
		560
	)
	layout.alphaY = -56
	alphaLabel = Label(content, L["Chance of finishing with starting supplies (%)"], 0, layout.alphaY, 300)
	alphaBox = Input(content, "alphaPercent", 496, layout.alphaY, INPUT_WIDTH)
	alphaBox:SetNumeric(false)
	alphaBox:SetMaxLetters(6)
	layout.adaptiveY = -80
	adaptiveBox = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate") --[[@as SkillUpSupplyCheck]]
	adaptiveBox:SetPoint("TOPLEFT", 0, layout.adaptiveY)
	adaptiveBox:SetChecked(false)
	adaptiveBox.name = "adaptive"
	adaptiveBox:SetScript("OnClick", function()
		Render()
	end)
	fields.adaptive = adaptiveBox
	adaptiveLabel = Label(content, L["Plan later purchases too"], CHECK, layout.adaptiveY - 3, 300)
	layout.failureY = -104
	failureLabel = Label(content, L["Cost of an unfinished route (copper)"], 0, layout.failureY, 260)
	failureBox = Input(content, "failureLoss", 496, layout.failureY, INPUT_WIDTH)
	layout.applyY = -132
	apply = CreateFrame("Button", nil, content, "SharedButtonSmallTemplate") --[[@as SkillUpSupplyApply]]
	apply:SetSize(110, 22)
	apply:SetPoint("TOPLEFT", 0, layout.applyY)
	apply:SetText(L["Apply policy"])
	apply:SetScript("OnClick", function()
		if applying or not (apply and status) then
			return
		end
		Render()
		local draft = apply.draft
		if not draft then
			return
		end
		applying = true
		local ok, missing = ns.SupplyDraft.Apply(draft)
		applying = false
		if ok then
			ns.SupplyUIRevision = (ns.SupplyUIRevision or 0) + 1
		end
		if dirty then
			Render()
		end
		if ok then
			status:SetText(L["Applied. The plan and its coverage follow these assumptions."])
			status:SetTextColor(0.2, 1, 0.2)
		else
			status:SetText(Reason(missing))
			status:SetTextColor(1, 0.4, 0.4)
		end
	end)
	apply:SetEnabled(false)
	apply.draft = nil
	apply.name = "apply"
	layout.statusY = -164
	status = Label(content, L["Open a profession to set its supply policy."], 0, layout.statusY, 560)
	status.name = "status"
	status:SetTextColor(1, 0.82, 0.2)
	layout.readoutY = -186
	readout = Label(content, L["Open a profession to see its plan and coverage."], 0, layout.readoutY, 560)
	readout.name = "readout"
	-- A merchant, source, recipe or supply change redraws only while this page is shown. The form is rebuilt
	-- against the new observation and its rows are reused, so a refresh never leaks a frame. A hidden page owns
	-- no handler at all: every change would otherwise run one to find the page hidden and do nothing.
	page:SetScript("OnShow", function()
		ns.WhenStale("supplyPage", Render)
		Render()
	end)
	page:SetScript("OnHide", function()
		ns.WhenStale("supplyPage", nil)
	end)
	return page
end

local function Enabled()
	return ns.db.showProfessionTabs and ns.db.showRouteTab
end

-- Called by UI/RecipeList.lua with the other pages, so Route stays the page the tab opens first.
function ns.AttachSupply()
	Create()
	ns.Pages.Register({ id = "supply", title = L["Supply"], setting = Enabled, page = page, prepare = Render })
end
