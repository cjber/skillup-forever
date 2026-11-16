-- Behaviour checks for the player-owned Supply page. This deliberately loads the real UI, MerchantOffers,
-- SupplySources and SupplyDraft with a small native-widget harness, not a copy of their callbacks.
local checks = 0
local function Check(value, message)
	checks = checks + 1
	assert(value, message)
end

local function Frame(_, _, parent)
	local f = { children = {}, scripts = {}, shown = false, text = "", checked = false }
	if parent then
		parent.children[#parent.children + 1] = f
	end
	function f:SetScript(name, fn)
		self.scripts[name] = fn
	end
	function f:Show()
		self.shown = true
		if self.scripts.OnShow then
			self.scripts.OnShow(self)
		end
	end
	function f:Hide()
		self.shown = false
		if self.scripts.OnHide then
			self.scripts.OnHide(self)
		end
	end
	function f:IsShown()
		return self.shown
	end
	function f:SetText(value)
		self.text = value
		if self.scripts.OnTextChanged then
			self.scripts.OnTextChanged(self)
		end
	end
	function f:GetText()
		return self.text
	end
	function f:SetChecked(value)
		self.checked = value
	end
	function f:GetChecked()
		return self.checked
	end
	function f:SetEnabled(value)
		self.enabled = value
	end
	function f:IsEnabled()
		return self.enabled ~= false
	end
	function f:SetShown(value)
		self.shown = value
	end
	function f:SetPoint(...)
		self.point = { ... }
	end
	function f:SetAllPoints(...)
		self.allPoints = { ... }
	end
	function f:SetSize(width, height)
		self.width, self.height = width, height
	end
	function f:SetWidth(width)
		self.width = width
	end
	function f:GetWidth()
		return self.width or 0
	end
	function f:SetHeight(value)
		self.height = value
	end
	function f:GetHeight()
		return self.height or 100
	end
	function f:SetScrollChild(child)
		self.scrollChild = child
	end
	function f:SetAutoFocus(value)
		self.autoFocus = value
	end
	function f:SetMaxLetters(value)
		self.maxLetters = value
	end
	function f:SetNumeric(value)
		self.numeric = value
	end
	function f:SetJustifyH(value)
		self.justify = value
	end
	function f:SetTextColor(...)
		self.textColor = { ... }
	end
	function f:SetValue(value)
		self.value = value
	end
	function f:GetChildren()
		return unpack(self.children)
	end
	function f:CreateFontString()
		return Frame("FontString", nil, self)
	end
	return f
end

local ProfessionsFrame = Frame("Frame")
local registered
local ns = {
	broken = false,
	L = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	}),
	db = { showProfessionTabs = true, showRouteTab = true },
	Pages = {
		Register = function(spec)
			registered = spec
		end,
	},
	Model = {
		RoundMoney = function(value)
			return value
		end,
	},
	FormatNet = function(value)
		return tostring(value)
	end,
	SupplySummaryText = function(summary)
		return "summary " .. tostring(summary.status)
	end,
	SupplyUIRevision = 0,
}
local stale = {}
local changes = 0
ns.Readable = function(value)
	return value
end
ns.WhenStale = function(name, handler)
	stale[name] = handler
end
ns.WhenStaleObserver = function() end
ns.WhenEvent = function() end
-- The real Changes frame redraws this page for every change that lists supplyPage; the spec's stand-in runs it
-- for all of them, so a missing redraw shows up as a stale form.
ns.Changed = function(_)
	changes = changes + 1
	if stale.supplyPage then
		stale.supplyPage()
	end
end

local professions = {
	[197] = { name = "Leatherworking", skillLine = 197, base = 200, max = 225, modifier = 0 },
	[164] = { name = "Blacksmithing", skillLine = 164, base = 100, max = 150, modifier = 0 },
}
local open = 197
ns.RouteProfessions = function()
	return professions
end
ns.OpenSkillLine = function()
	return open
end
ns.PlanRoute = function(profession)
	return { profession = profession, target = profession.max, crafts = { 1, 2 }, unpriced = 0, steps = {} }
end
local routeProducts = { 10, 11 }
ns.RouteReagents = function()
	local rows = {}
	for _, itemID in ipairs(routeProducts) do
		rows[#rows + 1] = { itemID = itemID }
	end
	return rows
end

local fixedPublications, adaptivePublications = 0, 0
local lastFixed, lastAdaptive
ns.RouteDemand = {
	ConfigureSupply = function(_, read, alpha)
		Check(alpha > 0 and alpha <= 1, "fixed owner keeps a fractional starting chance")
		if ns.rejectConfiguration then
			return false, "configuration-rejected"
		end
		local request, missing = read()
		Check(request ~= nil and missing == nil, "fixed owner publishes a complete source contract")
		lastFixed = request
		fixedPublications = fixedPublications + 1
		return true
	end,
	ConfigureAdaptiveSupply = function(_, read, alpha)
		Check(alpha > 0 and alpha <= 1, "adaptive owner keeps a fractional starting chance")
		local request, missing = read()
		Check(request ~= nil and missing == nil, "adaptive owner publishes a complete request")
		lastAdaptive = request
		adaptivePublications = adaptivePublications + 1
		return true
	end,
	Summary = function()
		return { status = "complete", alpha = 0.7, successLower = 0.65, successUpper = 0.75 }
	end,
	NextAction = function()
		return { kind = "craft" }
	end,
}
ns.rejectConfiguration = false

local env = setmetatable({
	CreateFrame = Frame,
	GetServerTime = function()
		return 1
	end,
	ProfessionsFrame = ProfessionsFrame,
	EventUtil = {
		ContinueOnAddOnLoaded = function(_, fn)
			fn()
		end,
	},
	math = math,
	ipairs = ipairs,
	pairs = pairs,
	next = next,
	tonumber = tonumber,
	tostring = tostring,
	string = string,
	table = table,
	type = type,
	format = string.format,
	C_Item = nil,
}, { __index = _G })
setfenv(assert(loadfile("Integrations/MerchantOffers.lua")), env)("SkillUpForever", ns)
setfenv(assert(loadfile("Core/SupplySources.lua")), env)("SkillUpForever", ns)
setfenv(assert(loadfile("Core/SupplyDraft.lua")), env)("SkillUpForever", ns)
setfenv(assert(loadfile("UI/Supply.lua")), env)("SkillUpForever", ns)
ns.AttachSupply()
Check(registered and registered.page, "supply page registers through Pages")
local page = registered.page
page:SetWidth(700)

ns.MerchantOffers.Open()
local function Offer(index, itemID, options)
	options = options or {}
	local offer = {
		index = index,
		session = ns.MerchantOffers.session,
		itemID = itemID,
		npcID = options.npcID or 500,
		observedAt = 1,
		sourceRevision = "test",
		requirementsComplete = true,
		stackCount = options.stackCount or 1,
		price = options.price or 5,
		costs = options.costs or {},
		numAvailable = options.numAvailable or 2,
		maxPurchaseItems = options.maxPurchaseItems or 4,
		isPurchasable = options.isPurchasable ~= false,
	}
	return offer
end
local offerA, offerB = Offer(1, 10), Offer(2, 11)
ns.MerchantOffers.Replace({ offerA, offerB })
page:Show()

local function Walk(frame, result)
	result = result or {}
	for _, child in ipairs(frame.children or {}) do
		if child.name then
			result[child.name] = child
		end
		Walk(child, result)
	end
	return result
end
local fields = Walk(page)
local function Collect()
	fields = Walk(page)
	return fields
end
local function Set(name, value)
	local field = Collect()[name]
	Check(field, "field exists: " .. name)
	field:SetText(tostring(value))
end
local function Toggle(name, value)
	local field = Collect()[name]
	Check(field, "checkbox exists: " .. name)
	field:SetChecked(value ~= false)
	if field.scripts.OnClick then
		field.scripts.OnClick(field)
	end
end
local function ClickApply()
	local field = Collect().apply
	Check(field and field.scripts.OnClick, "native apply button exists")
	field.scripts.OnClick(field)
end
local function Text(name)
	local field = Collect()[name]
	return field and field.text or nil
end
local function Controls()
	local count = 0
	local function Count(frame)
		for _, child in ipairs(frame.children or {}) do
			if child.field or child.controls then
				count = count + 1
			end
			Count(child)
		end
	end
	Count(page)
	return count
end
local function Rows()
	local count = 0
	for _, child in ipairs(page.content.children or {}) do
		if child.controls then
			count = count + 1
		end
	end
	return count
end
local function Fits(width)
	local function CheckFrame(frame, visible)
		for _, child in ipairs(frame.children or {}) do
			local shown = visible and child.shown ~= false
			if shown and child.point and child.point[1] == "TOPLEFT" and type(child.point[2]) == "number" then
				local x = child.point[2]
				Check(type(x) == "number" and x >= 0, "control starts inside the scroll content")
				if child.width then
					Check(
						x + child.width <= width + 0.01,
						"control ends inside the scroll content: "
							.. tostring(child.name)
							.. " x "
							.. tostring(x)
							.. " width "
							.. tostring(child.width)
							.. " text "
							.. tostring(child.text)
					)
				end
			end
			CheckFrame(child, shown)
		end
	end
	CheckFrame(page.content, true)
end

-- The page's own shell and the readout are present before any law is typed.
Check(page.content and page.scroll and page.scroll.scrollChild == page.content, "page uses a scroll child")
Check(fields.alphaPercent and fields.alphaPercent.numeric ~= true, "chance input accepts fractional values")
Check(Text("status") == "Enter a starting chance between 1 and 100.", "an empty form asks for the starting chance")
Check(Collect().apply.enabled == false, "an empty form cannot apply")
Check(page.content.width == 560, "content fits the wide window")
Fits(560)
Check(Text("readout"):find("Plan: Leatherworking", 1, true) ~= nil, "readout names the plan")
Check(Text("readout"):find("Below your target by 5.00 points.", 1, true) ~= nil, "readout shows the margin")
Check(Text("readout"):find("Next step: craft.", 1, true) ~= nil, "readout shows the next modeled step")

-- A fixed policy needs a price consent, an access choice, a stock and both trip costs on every offer.
Set("alphaPercent", 70)
for index, offer in ipairs({ offerA, offerB }) do
	local prefix = "offer" .. index .. "."
	Toggle(prefix .. "access", true)
	Toggle(prefix .. "priceStays", true)
	Toggle(prefix .. "ownStock", true)
	Set(prefix .. "stock", offer.numAvailable)
	Set(prefix .. "ceiling", 2)
	Set(prefix .. "initialMoney", 0)
	Set(prefix .. "refillMoney", 0)
end
Toggle("offer2.priceStays", false)
Check(Collect().apply.enabled == false, "an offer without a price consent cannot apply")
ClickApply()
Check(fixedPublications == 0, "no price consent publishes nothing")
Check(Text("status") == "Every offer needs its price to stay as shown.", "the form says which consent is missing")
Toggle("offer2.priceStays", true)
Check(Collect().apply.enabled == true, "a complete fixed form can apply")
ClickApply()
Check(fixedPublications == 1, "the fixed form reaches the real source owner")
Check(lastFixed and lastFixed.service == "fixed-batch", "the fixed contract is published")
Check(lastFixed.sources[1].stockKey ~= lastFixed.sources[2].stockKey, "two own-stock offers keep separate pools")
Check(ns.SupplyUIRevision == 1, "a successful apply advances the revision")
Check(Text("status") == "Applied. The plan and its coverage follow these assumptions.", "an apply is confirmed")

-- Reopening the same window keeps every typed law and consent; a repeat apply uses a new revision. A hidden
-- page registers no redraw at all, so a change elsewhere runs no handler for it.
local pageWatch = {}
local realWhenStale = ns.WhenStale
ns.WhenStale = function(name, handler)
	if name == "supplyPage" then
		pageWatch[#pageWatch + 1] = handler
	end
	return realWhenStale(name, handler)
end
page:Hide()
Check(pageWatch[#pageWatch] == nil, "a hidden Supply page registers no redraw")
page:Show()
Check(pageWatch[#pageWatch] ~= nil, "a shown Supply page registers its redraw")
ns.WhenStale = realWhenStale
Check(Collect()["offer1.initialMoney"]:GetText() == "0", "reopening the same observation keeps typed laws")
Check(Collect()["offer1.priceStays"]:GetChecked() == true, "reopening keeps a checkbox consent")
ClickApply()
Check(fixedPublications == 2 and ns.SupplyUIRevision == 2, "a repeat apply uses a fresh revision")

-- Two offers at one vendor cannot last-write-wins a trip cost, and a shared payment cannot hold two values.
Set("offer1.initialMoney", 0)
Set("offer2.initialMoney", 5)
Check(Collect().apply.enabled == false, "conflicting trip costs at one vendor cannot apply")
ClickApply()
Check(fixedPublications == 2, "conflicting trip costs publish nothing")
Check(
	Text("status") == "Offers at one vendor need the same trip costs and values.",
	"the form names the vendor conflict"
)
Set("offer2.initialMoney", 0)
Check(Collect().apply.enabled == true, "matching trip costs can apply")

-- A replacement merchant window with a shared payment: the same token key must carry one value.
ns.MerchantOffers.Open()
local tokenOfferA = Offer(1, 10, {
	costs = { { slot = 1, kind = "currency", id = 42, quantity = 1, currencyName = "Token" } },
})
local tokenOfferB = Offer(2, 11, {
	costs = { { slot = 1, kind = "currency", id = 42, quantity = 1, currencyName = "Token" } },
})
ns.MerchantOffers.Replace({ tokenOfferA, tokenOfferB })
ns.Changed("sourceEvidence")
Check(Collect().alphaPercent:GetText() == "", "a replaced window clears typed values")
for index in ipairs({ tokenOfferA, tokenOfferB }) do
	local prefix = "offer" .. index .. "."
	Toggle(prefix .. "priceStays", true)
	Toggle(prefix .. "ownStock", true)
	Set(prefix .. "stock", 2)
	Set(prefix .. "ceiling", 2)
	Set(prefix .. "initialMoney", 0)
	Set(prefix .. "refillMoney", 0)
	Set(prefix .. "token.currency:42", 3)
end
Set("alphaPercent", 70)
Set("offer2.token.currency:42", 4)
Check(Collect().apply.enabled == false, "one payment with two values cannot apply")
Check(
	Text("status") == "Offers that use one payment need the same value for it.",
	"the form names the shared payment conflict"
)
Set("offer2.token.currency:42", 3)
Check(Collect().apply.enabled == true, "one shared payment value can apply")
ClickApply()
Check(fixedPublications == 3, "the shared payment publishes")
Check(lastFixed.tokenValues["currency:42"] == 3, "the shared token value reaches the fixed contract")

-- One stock pool with two counts is refused before the source owner sees it.
for index = 1, 2 do
	local prefix = "offer" .. index .. "."
	Toggle(prefix .. "ownStock", false)
	Set(prefix .. "pool", "shared")
end
Set("offer1.stock", 2)
Set("offer2.stock", 3)
Check(Collect().apply.enabled == false, "one stock pool with two counts cannot apply")
Check(
	Text("status") == "Offers that draw on one stock pool need the same stock.",
	"the form names the shared pool conflict"
)
Set("offer2.stock", 2)
ClickApply()
Check(fixedPublications == 4, "one shared stock law publishes")

-- An unlimited merchant listing is an explicit fixed-mode choice; adaptive mode needs a finite restriction.
ns.MerchantOffers.Open()
local single = Offer(1, 10)
ns.MerchantOffers.Replace({ single })
routeProducts = { 10 }
ns.Changed("sourceEvidence")
for _, name in ipairs({ "offer1.priceStays", "offer1.ownStock" }) do
	Toggle(name, true)
end
Set("alphaPercent", 70)
Set("offer1.stock", 2)
Set("offer1.ceiling", 2)
Set("offer1.initialMoney", 0)
Set("offer1.refillMoney", 0)
Toggle("offer1.unlimited", true)
Check(Collect().apply.enabled == true, "fixed mode accepts an explicit unlimited stock")
ClickApply()
Check(fixedPublications == 5, "an unlimited fixed policy publishes")
Check(lastFixed.stock.S == nil, "an unlimited pool is not a finite stock count")
Check(lastFixed.sources[1].stockKey == "offer:3:1", "own stock keys the exact offer")

-- Adaptive mode removes the unlimited choice and needs a delivery chance, a sure first purchase and values.
Toggle("adaptive", true)
Check(
	Collect()["offer1.unlimited"] == nil or Collect()["offer1.unlimited"]:IsShown() == false,
	"adaptive mode hides the unlimited stock choice"
)
Set("offer1.stock", 2)
Set("offer1.initialValue", 1)
Set("offer1.refillValue", 1)
Set("offer1.chancePercent", 50)
Set("offer1.carryItem", 0)
Set("failureLoss", 0)
Toggle("offer1.initialPaid", false)
Check(Collect().apply.enabled == false, "an uncertain first purchase cannot apply")
ClickApply()
Check(adaptivePublications == 0, "an uncertain first purchase publishes nothing")
Toggle("offer1.initialPaid", true)
Check(Collect().apply.enabled == true, "a complete adaptive form can apply")
ClickApply()
Check(adaptivePublications == 1, "the adaptive form reaches the real source owner")
Check(lastAdaptive and lastAdaptive.policy.service == "adaptive-finite", "the adaptive contract is published")
Check(lastAdaptive.policy.failureLoss == 0, "the typed failure loss reaches the adaptive policy")
Check(lastAdaptive.policy.terminalCarry["item:10"] == 0, "the typed leftover value reaches the adaptive policy")
Check(lastAdaptive.policy.tokenValues["currency:42"] == nil, "an offer with no typed payment publishes none")
Toggle("offer1.payFailure", true)
ClickApply()
Check(adaptivePublications == 2, "the failure payment consent republishes")
Check(lastAdaptive.policy.sources[1].futureDelivery.payOnFailure == true, "the consent reaches the delivery law")

-- A native unlimited listing is usable in adaptive mode only through an explicit finite search restriction.
ns.MerchantOffers.Open()
local unlimited = Offer(1, 10, { numAvailable = -1 })
ns.MerchantOffers.Replace({ unlimited })
ns.Changed("sourceEvidence")
Toggle("adaptive", true)
for _, name in ipairs({ "offer1.priceStays", "offer1.ownStock", "offer1.initialPaid" }) do
	Toggle(name, true)
end
Set("alphaPercent", 70)
Set("offer1.stock", 4)
Set("offer1.ceiling", 2)
Set("offer1.initialMoney", 0)
Set("offer1.refillMoney", 0)
Set("offer1.initialValue", 1)
Set("offer1.refillValue", 1)
Set("offer1.chancePercent", 50)
Set("offer1.carryItem", 0)
Set("failureLoss", 0)
Check(Collect().apply.enabled == false, "an unlimited native listing needs an explicit restriction")
Check(
	Text("status") == "The merchant shows no limit: limit the search to the number you will buy.",
	"the form names the unlimited listing"
)
Toggle("offer1.restrict", true)
Check(Collect().apply.enabled == true, "an explicit restriction makes the adaptive form applyable")
local beforeRestricted = adaptivePublications
ClickApply()
Check(adaptivePublications == beforeRestricted + 1, "a restricted adaptive policy publishes")
Check(lastAdaptive.policy.stock[lastAdaptive.policy.sources[1].stockKey] == 4, "the restriction reaches the policy")

-- Repeated canonical redraws keep the typed form and never add a row or a control.
local beforeControls, beforeRows = Controls(), Rows()
for _ = 1, 5 do
	stale.supplyPage()
	ns.Changed("sourceEvidence")
	ns.Changed("supply")
end
Check(Collect().alphaPercent:GetText() == "70", "an ordinary refresh keeps typed values")
Check(Collect()["offer1.chancePercent"]:GetText() == "50", "an ordinary refresh keeps adaptive values")
Check(Rows() == beforeRows, "an ordinary refresh adds no row")
Check(Controls() == beforeControls, "an ordinary refresh adds no control")

-- A merchant rescan in one session hands back equal offers in new tables with a newer observation time: the same
-- offers keep the form as typed. A changed offer still resets it.
local function Rescan(offer, change)
	local copy = {}
	for key, value in pairs(offer) do
		copy[key] = value
	end
	copy.observedAt = (offer.observedAt or 1) + 1
	if change then
		change(copy)
	end
	return copy
end
ns.MerchantOffers.Replace({ Rescan(unlimited) })
ns.Changed("merchant")
Check(Collect().alphaPercent:GetText() == "70", "a rescan of the same offers keeps typed values")
Check(Collect()["offer1.chancePercent"]:GetText() == "50", "a rescan keeps adaptive values")
Check(Collect()["offer1.carryItem"]:GetText() == "0", "a rescan keeps a leftover value")
ns.MerchantOffers.Replace({
	Rescan(unlimited, function(copy)
		copy.price = 99
	end),
})
ns.Changed("merchant")
Check(Collect().alphaPercent:GetText() == "", "a changed offer clears typed values")

-- A new window clears consent and values, and still reuses its rows.
local replacement = Offer(1, 10)
ns.MerchantOffers.Open()
ns.MerchantOffers.Replace({ replacement })
ns.Changed("sourceEvidence")
Check(Collect().alphaPercent:GetText() == "", "a replacement window clears the starting chance")
Check(Collect()["offer1.access"]:GetChecked() == false, "a replacement window clears access consent")
Check(Rows() == beforeRows, "a replacement window reuses the rows")
Check(Controls() <= beforeControls + 2, "a replacement window adds no row controls")

-- Closing the merchant leaves the form asking for one.
ns.MerchantOffers.Replace(nil)
ns.Changed("merchant")
Check(Text("status") == "Open a merchant to set this profession's supply policy.", "a closed merchant is named")
Check(Collect().apply.enabled == false, "a closed merchant cannot apply")

-- The window switching profession moves the form; a removed profession is forgotten, not drawn stale.
ns.MerchantOffers.Replace({ Offer(1, 10) })
ns.Changed("merchant")
open = 164
ns.Changed("window")
Check(Text("readout"):find("Plan: Blacksmithing", 1, true) ~= nil, "a profession change redraws its plan")
professions[164] = nil
open = nil
ns.Changed("professions")
Check(
	Text("status") == "Open a profession to set its supply policy.",
	"a removed profession is forgotten rather than drawn stale"
)
Check(Collect().apply.enabled == false, "a removed profession cannot apply")

-- The same form fits a narrow window without a control leaving the scroll content.
professions[197] = { name = "Leatherworking", skillLine = 197, base = 200, max = 225, modifier = 0 }
open = 197
page:SetWidth(360)
ns.Changed("window")
Check(page.content.width == 316, "content narrows with the window")
Fits(316)

-- A rejected configuration publishes nothing, keeps the revision and can be retried.
routeProducts = { 10 }
ns.MerchantOffers.Open()
ns.MerchantOffers.Replace({ Offer(1, 10) })
ns.Changed("sourceEvidence")
Toggle("offer1.priceStays", true)
Toggle("offer1.ownStock", true)
Set("alphaPercent", 70)
Set("offer1.stock", 2)
Set("offer1.ceiling", 2)
Set("offer1.initialMoney", 0)
Set("offer1.refillMoney", 0)
local beforeFixed, beforeChanges = fixedPublications, changes
local beforeRevision = ns.SupplyUIRevision
ns.rejectConfiguration = true
ClickApply()
Check(fixedPublications == beforeFixed and changes == beforeChanges, "a rejected configuration publishes no change")
Check(ns.SupplyUIRevision == beforeRevision, "a rejected configuration keeps the revision for a retry")
ns.rejectConfiguration = false
ClickApply()
Check(
	fixedPublications == beforeFixed + 1 and ns.SupplyUIRevision == beforeRevision + 1,
	"a retry applies at a fresh revision"
)

-- A product and another offer's payment can name one item: its leftover value is one terminal coordinate, so two
-- typed values stop the apply instead of the last one winning.
routeProducts = { 10, 11 }
ns.MerchantOffers.Open()
local priced = Offer(1, 10)
local token = Offer(2, 11, {
	price = 0,
	costs = { { slot = 1, kind = "item", id = 10, quantity = 1 } },
})
ns.MerchantOffers.Replace({ priced, token })
ns.Changed("merchant")
Toggle("adaptive", true)
for index = 1, 2 do
	local prefix = "offer" .. index .. "."
	for _, name in ipairs({ "priceStays", "ownStock", "initialPaid" }) do
		Toggle(prefix .. name, true)
	end
	Set(prefix .. "stock", 2)
	Set(prefix .. "ceiling", 2)
	Set(prefix .. "initialMoney", 0)
	Set(prefix .. "refillMoney", 0)
	Set(prefix .. "initialValue", 0)
	Set(prefix .. "refillValue", 0)
	Set(prefix .. "chancePercent", 100)
end
Set("offer1.carryItem", 1)
Set("offer2.carryItem", 0)
Set("offer2.token.item:10", 0)
Set("failureLoss", 0)
Set("alphaPercent", 70)
Set("offer2.carry.item:10", 2)
Check(Collect().apply.enabled == false, "an item with two leftover values cannot apply")
Check(Text("status") == "One item or payment needs one leftover value.", "the form names the item leftover conflict")
Set("offer2.carry.item:10", 1)
Check(Collect().apply.enabled == true, "one leftover value for an item can apply")
local beforeShared = adaptivePublications
ClickApply()
Check(adaptivePublications == beforeShared + 1, "the shared item leftover value publishes")
Check(lastAdaptive.policy.terminalCarry["item:10"] == 1, "the shared leftover value reaches the policy")

print("supply_ui_spec: " .. checks .. " checks passed")
