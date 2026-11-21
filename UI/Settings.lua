---@type string, SkillUpNamespace
local _, ns = ...

if ns.broken then
	return
end
local L = ns.L

-- Options > AddOns > SkillUp Forever: a short index page, then a stock subpage per group so no page grows
-- tall. Every row goes in through Settings.RegisterInitializer, which inserts it from Blizzard's secure delegate.
-- Settings.CreateCheckbox/CreateDropdown insert from our code instead, and the settings search reads every
-- layout, so that tainted it: a restricted button in the results (Social's Discord Sign In) was then blocked
-- and blamed on us.
local category

---@type SkillUpSetting[]
local ownedSettings

-- Build native row data and option tables in secure execution so the menu and gamepad code can read them.
local delegates = {}
local function Secure(fn)
	local delegate = delegates[fn]
	if not delegate then
		local create = _G.CreateSecureDelegate
		delegate = create and create(fn) or fn
		delegates[fn] = delegate
	end
	return delegate
end

---@param target SkillUpCategory
local function Register(target, key, varType, name)
	local setting =
		Settings.RegisterAddOnSetting(target, "SkillUpForever_" .. key, key, ns.db, varType, name, ns.DEFAULTS[key])
	ownedSettings[#ownedSettings + 1] = setting
	setting:SetValueChangedCallback(function()
		if key == "includeWorkingOvertime" then
			ns.SetIncludeWorkingOvertime(ns.db.includeWorkingOvertime)
		elseif key == "auctionShoppingLists" then
			ns.SyncAuctionShoppingLists()
			ns.Changed("settings")
		else
			ns.Changed("settings")
		end
	end)
	return setting
end

---@param target SkillUpCategory
local function Checkbox(target, key, name, tooltip)
	Settings.RegisterInitializer(
		target,
		Secure(Settings.CreateCheckboxInitializer)(Register(target, key, Settings.VarType.Boolean, name), nil, tooltip)
	)
end

-- options: { value, label } pairs, in menu order.
---@param target SkillUpCategory
local function Choice(target, key, name, options, tooltip)
	local setting = Register(target, key, Settings.VarType.String, name)
	local container = Secure(Settings.CreateControlTextContainer)()
	for _, option in ipairs(options) do
		Secure(container.Add)(container, option[1], option[2])
	end
	Settings.RegisterInitializer(
		target,
		Secure(Settings.CreateDropdownInitializer)(
			setting,
			Secure(_G.GenerateClosure)(container.GetData, container),
			tooltip
		)
	)
end

-- A phrase is one key however long, so its line may run past the limit.
-- luacheck: push no max line length
function ns.RegisterSettings()
	category = Settings.RegisterVerticalLayoutCategory(ns.TITLE)
	ownedSettings = {}
	-- Rows are grouped onto a stock subpage each; the category itself is the index, one button per group. A
	-- button goes in through Settings.RegisterInitializer too, and stays out of search (addSearchTags false),
	-- which finds the settings themselves. The page opens through the shared secure opener: Settings.OpenToCategory
	-- is Blizzard's own Lua around a restricted client call, which the client refuses from addon code
	-- (cjber/forever-core#333).
	local function Section(name, rows)
		local subcategory = Settings.RegisterVerticalLayoutSubcategory(category, name)
		---@cast subcategory SkillUpCategory
		rows(subcategory)
		Settings.RegisterInitializer(
			category,
			Secure(CreateSettingsButtonInitializer)(name, L["Open"], function()
				ForeverCore.OpenSettingsPanel(subcategory:GetID())
			end, nil, false)
		)
	end

	Section(L["Recipe rows"], function(rows)
		Checkbox(
			rows,
			"includeWorkingOvertime",
			L["Include Working Overtime estimate"],
			L["Adds an estimated 4 percentage points per Working Overtime rank to yellow and green skill-up chances. Whether the game adds the talent's bonus as points or multiplies the chance by it is not confirmed yet, so this starts off and chances use the base formula."]
		)
		Checkbox(
			rows,
			"showUnlearned",
			L["List unlearned recipes"],
			L["Adds the recipes of the open profession you have not learned under an Unlearned divider, greyed and marked with a trainer or recipe item and the skill it asks. Click a row to preview the recipe."]
		)

		Checkbox(
			rows,
			"buffsOnly",
			L["Only buffs for your level"],
			L["Lists only the recipes whose product is a buff you can use at your level: elixirs, flasks, Well Fed food, protection potions, stones, oils and armour kits. Highest required level first. Learned recipes come first, then unlearned ones when those are listed."]
		)

		Checkbox(
			rows,
			"showRowText",
			L["Show skill on recipe rows"],
			L["Skill-up chance and cost per skill-up at the right of each recipe."]
		)

		Checkbox(
			rows,
			"showRowPrices",
			L["Show prices on recipe rows"],
			L["Show money beside each recipe. Turning this off keeps prices in the recipe tooltip."]
		)

		Choice(
			rows,
			"rowCost",
			L["Money on recipe rows"],
			ns.ROW_COST_OPTIONS,
			L["Per skill-up is the cost of one skill point. Per craft is what one craft costs or earns, shown on recipes that no longer give skill too."]
		)

		Checkbox(
			rows,
			"showSkill",
			L["Show skill range start on rows"],
			L["Add the start of each recipe's difficulty range. This is separate from the skill needed to learn it."]
		)

		Checkbox(
			rows,
			"showTooltip",
			L["Show recipe tooltip on hover"],
			L["Show the SkillUp tooltip beside the Professions window when hovering a recipe. Turn it off to keep the reagents clear."]
		)

		Checkbox(
			rows,
			"detailsBar",
			L["Show thresholds bar on the recipe"],
			L["The orange, yellow, green and grey thresholds and where your skill sits, under the recipe in the Professions window. Turn it off if it covers the reagents."]
		)

		Choice(
			rows,
			"recipeTooltip",
			L["Recipe tooltip position"],
			ns.RECIPE_TOOLTIP_OPTIONS,
			L["Where the tooltip goes when you hover a recipe. Beside the window, it stays clear of the reagents."]
		)

		Choice(
			rows,
			"unlearnedSortMode",
			L["Unlearned recipe order"],
			ns.UNLEARNED_SORT_OPTIONS,
			L["How recipes you have not learned are ordered. Learned recipes keep the selected recipe order."]
		)
	end)

	Section(L["Prices"], function(rows)
		Choice(
			rows,
			"priceSource",
			L["Auction prices from"],
			ns.PRICE_SOURCE_OPTIONS,
			L["Choose Auctionator, TradeSkillMaster, AHDB, Naowh Forever or Forever Ledger. The chosen price wins; the others fill gaps. Tooltips show the observation's age when known."]
		)

		Choice(
			rows,
			"craftValue",
			L["Count what crafts sell for"],
			ns.CRAFT_VALUE_OPTIONS,
			L["Subtract what the crafted item sells for from its cost. Auction prices need Auctionator, TradeSkillMaster, AHDB, Naowh Forever or Forever Ledger, are after the 5% cut, and may not sell."]
				.. " "
				.. L["Region sale averages need TradeSkillMaster and its desktop app. They estimate value from reported regional sales and purchases, with the vendor price as a floor. They do not guarantee a sale."]
		)

		Checkbox(
			rows,
			"valueGathered",
			L["Value gathered materials at what they'd sell for"],
			L["A material your professions gather costs what selling it would bring instead of nothing: its auction price after the 5% cut, or its vendor sell price if that is more. Used for the route and the costs on recipe rows. Auction prices need Auctionator, TradeSkillMaster, AHDB, Naowh Forever or Forever Ledger."]
		)

		Checkbox(
			rows,
			"auctionOnly",
			L["Price self-supplied reagents at auction values"],
			L["A reagent you gather, loot or already own costs what selling it would bring - its auction price after the 5% cut, or its vendor sell price if that is more - instead of counting as free. With no market price it stays unpriced rather than free. Auction prices need Auctionator, TradeSkillMaster, AHDB, Naowh Forever or Forever Ledger."]
		)

		-- The optional cost of one trip to buy more when a leg falls short. Zero is the default: no trip cost is
		-- invented, so the budgets follow the reagent purchase price alone. A set value makes an extra craft on a
		-- risky leg worth more, because it also lowers the chance of that trip.
		local restock = Settings.RegisterProxySetting(
			rows,
			"SkillUpForever_restockCost",
			Settings.VarType.Number,
			L["Restock visit cost"],
			ns.DEFAULTS.restockCost,
			function()
				return ns.db.restockCost or 0
			end,
			function(value)
				local copper = math.max(0, math.floor(tonumber(value) or 0))
				if ns.db.restockCost ~= copper then
					ns.db.restockCost = copper
					ns.Changed("settings")
				end
			end
		)
		---@cast restock SkillUpSetting
		ownedSettings[#ownedSettings + 1] = restock
		local restockOptions = Secure(Settings.CreateSliderOptions)(0, 1000000, 1000)
		Secure(restockOptions.SetLabelFormatter)(
			restockOptions,
			MinimalSliderWithSteppersMixin.Label.Right,
			Secure(_G.GenerateClosure)(_G.securecallfunction, function(value)
				return value > 0 and ns.FormatNet(ns.Model.RoundMoney(value), false) or L["Not counted"]
			end)
		)
		Settings.RegisterInitializer(
			rows,
			Secure(Settings.CreateSliderInitializer)(
				restock,
				restockOptions,
				L["What one trip to buy more reagents is worth, in copper, when a run takes more crafts than planned. It is added to that reagent's purchase price only when it happens. Leave it at zero to count no trip."]
			)
		)
	end)

	Section(L["Route and trainer"], function(rows)
		Checkbox(
			rows,
			"showTracker",
			L["Show tracked professions"],
			L["Show profession routes in the objective tracker. Hiding them keeps your tracked professions and targets."]
		)
		local host = ForeverCore.TrackerHost
		-- The shared column's attach choice, the same row and words in every Forever addon (forever-core#910).
		local sections = ForeverCore.SettingsSections
		if sections and sections.RegisterTrackerAttach then
			sections.RegisterTrackerAttach(rows, "SkillUpForever_trackerAttached")
		end
		-- The shared host owns the scale, so the slider only mirrors it and writes back a percentage of it.
		if host and host.GetScale and host.SetScale then
			local scale = Settings.RegisterProxySetting(
				rows,
				"SkillUpForever_trackerScale",
				Settings.VarType.Number,
				L["Tracker scale"],
				100,
				function()
					return math.floor(host.GetScale() * 100 + 0.5)
				end,
				function(value)
					host.SetScale(value / 100)
				end
			)
			---@cast scale SkillUpSetting
			local scaleOptions = Secure(Settings.CreateSliderOptions)(50, 200, 10)
			Secure(scaleOptions.SetLabelFormatter)(
				scaleOptions,
				MinimalSliderWithSteppersMixin.Label.Right,
				Secure(_G.GenerateClosure)(_G.securecallfunction, function(value)
					return value .. "%"
				end)
			)
			Settings.RegisterInitializer(
				rows,
				Secure(Settings.CreateSliderInitializer)(
					scale,
					scaleOptions,
					L["Scales the shared Forever tracker. 100% matches the game's own tracker."]
				)
			)
		end
		-- Lock keeps the detached column where it is: the grip ignores drag while it is on. It only writes the saved
		-- switch, so it is safe to toggle in combat.
		if host and host.GetSettings and host.SetLocked then
			local lock = Settings.RegisterProxySetting(
				rows,
				"SkillUpForever_trackerLocked",
				Settings.VarType.Boolean,
				L["Lock the tracker"],
				false,
				function()
					return host.GetSettings().locked == true
				end,
				function(value)
					host.SetLocked(value == true)
				end
			)
			---@cast lock SkillUpSetting
			Settings.RegisterInitializer(
				rows,
				Secure(Settings.CreateCheckboxInitializer)(
					lock,
					nil,
					L["Keeps the shared Forever tracker where you put it. The grip at its top no longer drags it."]
				)
			)
		end

		Checkbox(
			rows,
			"showRouteTab",
			L["Show the levelling route tab"],
			L["A tab at the bottom of the Professions window with a route to your target skill and its reagents. It opens from the SkillUp side tab, beside the crafted gear and buffs tabs. Tracked professions stay in the objective tracker either way."]
		)

		Checkbox(
			rows,
			"showGearTab",
			L["Show the crafted gear tab"],
			L["A tab at the bottom of the Professions window listing the newest crafted item this character can equip in each slot. It opens from the SkillUp side tab, beside the route and buffs tabs."]
		)

		Checkbox(
			rows,
			"showBuffsTab",
			L["Show the buffs tab"],
			L["A tab at the bottom of the Professions window listing the buff consumables this profession makes, by the skill they unlock at and what each one is for. It opens from the SkillUp side tab, beside the route and crafted gear tabs."]
		)

		Checkbox(
			rows,
			"showSupplyTab",
			L["Show the supply tab"],
			L["A tab at the bottom of the Professions window where you set what a merchant will sell and deliver, so the route can plan around it. It opens from the SkillUp side tab, beside the route tab."]
		)

		Checkbox(
			rows,
			"merchantButton",
			L["Show the merchant Reagents tab"],
			L["A Reagents tab on a merchant's window that lists the reagents your tracked routes still need from that merchant and their total cost. Buy them from the merchant's own window."]
		)

		Checkbox(
			rows,
			"auctionSearch",
			L["Show reagent search"],
			L["Click Search in the Professions window to find missing reagents. Without Auctionator, each click fills the auction house search box with the next reagent."]
		)

		Checkbox(
			rows,
			"auctionShoppingLists",
			L["Keep Auctionator shopping lists"],
			L["Save lists for tracked routes set to Buy reagents and for recipe searches. Turn this off to stop saving lists and keep using Search."]
		)

		Checkbox(
			rows,
			"showTrainer",
			L["Annotate trainer recipes"],
			L["Required skill, skill-up chance and cost on profession trainer recipes, and which one is best to train next for your route."]
		)
	end)

	Section(L["Tooltips and sorting"], function(rows)
		Choice(
			rows,
			"reagentTooltip",
			L["Reagent tooltips"],
			ns.REAGENT_TOOLTIP_OPTIONS,
			L["Show recipes on Shift or always. Off hides reagent details, including route needs."]
		)

		Checkbox(
			rows,
			"showTooltipRoute",
			L["Show route needs on item tooltips"],
			L["Show how much of an item your tracked routes still need. Turn this off to keep recipe details without the route line."]
		)

		Checkbox(
			rows,
			"gatherTooltip",
			L["Gathering skill on nodes"],
			L["Herb and ore node tooltips show the skill they need and its colour at yours. Skinnable corpses show ? until the skinning rule is confirmed on Forever."]
		)

		Choice(
			rows,
			"sortMode",
			L["Sort recipes"],
			ns.SORT_OPTIONS,
			L["Sort recipes in one list, learned first, then unlearned. Highest craft profit includes grey recipes. Default restores categories."]
		)
	end)

	Section(L["Addon"], function(rows)
		Checkbox(
			rows,
			"whatsNew",
			L["What's new after an update"],
			L["One line in chat the first time a new version loads."]
		)
	end)

	-- Blizzard already resets settings owned by a subpage. The index resets only settings owned by SkillUp,
	-- leaving the shared tracker controls to the subpage that owns them.
	EventRegistry:RegisterCallback("Settings.CategoryDefaulted", function(_, defaulted)
		if defaulted == category then
			for _, setting in ipairs(ownedSettings) do
				setting:SetValueToDefault()
			end
		end
	end, ns)

	Settings.RegisterAddOnCategory(category)
end
-- luacheck: pop

-- Through the setting, so the settings panel and its change callback stay in step.
---@param mode string
function ns.SetSortMode(mode)
	Settings.SetValue("SkillUpForever_sortMode", mode)
end

-- Through the setting, so the settings panel and its change callback stay in step.
---@param on boolean
function ns.SetBuffsOnly(on)
	Settings.SetValue("SkillUpForever_buffsOnly", on)
end

function ns.OpenSettings()
	-- No category when an update's files are missing: Core has already said to restart the game.
	if not category then
		return
	end
	local function Open()
		ForeverCore.OpenSettingsPanel(category:GetID())
	end
	-- Opening the panel reaches a protected call, so it waits for combat to end like the pages do (#489).
	if not ns.Pages.Unlocked(Open) then
		return
	end
	Open()
end
