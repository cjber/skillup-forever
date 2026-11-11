-- Run from the repository root: luajit tests/core_spec.lua
local Client = dofile("tests/client.lua")
local equal = Client.equal
local TOC = Client.TocMetadata()

-- The host globals Core/Core.lua loads against: chat lines go to `messages`, load callbacks to `callbacks`.
local function Env(messages, callbacks)
	return setmetatable({
		C_AddOns = {
			GetAddOnMetadata = function(_, field)
				return TOC[field]
			end,
		},
		CreateColor = function() end,
		Enum = { TradeskillRelativeDifficulty = { Optimal = 1, Medium = 2, Easy = 3, Trivial = 4 } },
		CreateFrame = function()
			return { RegisterEvent = function() end, SetScript = function() end }
		end,
		UnitName = function()
			return "Tester"
		end,
		GetNormalizedRealmName = function()
			return "Realm"
		end,
		GetBuildInfo = function()
			return "1.60.1", "70205", "Sep 24 2026", 16001, "wow", "1.60.1.70205"
		end,
		time = function()
			return 0
		end,
		SlashCmdList = {},
		DEFAULT_CHAT_FRAME = {
			AddMessage = function(_, message)
				messages[#messages + 1] = message
			end,
		},
		EventUtil = {
			ContinueOnAddOnLoaded = function(name, callback)
				callbacks[name] = callback
			end,
		},
		ForeverCore = {
			API = 1,
			Register = function(_, spec)
				return {
					SafeCall = pcall,
					Attach = function() end,
					Report = {},
					title = spec.title,
				}
			end,
		},
	}, { __index = _G })
end

-- An update followed by /reload can leave newly added files unloaded.
for _, complete in ipairs({ false, true }) do
	local callbacks, messages, initialized = {}, {}, 0
	local function Init()
		initialized = initialized + 1
	end
	local ns = {
		InitPrices = Init,
		InitLive = Init,
		RegisterSettings = Init,
		AttachItemTooltips = Init,
		InitShopping = Init,
		AttachRecipeList = Init,
		AttachTrainer = Init,
	}
	if complete then
		ns.Stats = {}
		assert(loadfile("Data/Recipes.lua"))("SkillUpForever", ns)
		ns.TrainerFees, ns.TrainerRanks, ns.Catalogue = {}, {}, {}
		ns.InitCatalogue = function() end
		ns.PlanRoute, ns.Changed, ns.WhenEvent = Init, Init, function() end
		ns.CraftedGear = Init
		ns.ReportLines = Init
	end
	local env = Env(messages, callbacks)
	-- A save from before auction prices moved to Auctionator, and one with vendors and a price store from
	-- before builds were recorded.
	env.SkillUpForeverDB = {
		scanAuctions = true,
		tracked = { [1] = true },
		auctions = {},
		vendor = { [1] = 5 },
		stock = {
			[1] = { [7] = 5, [8] = false },
			[2] = { [9] = 0, [10] = "many" },
			[3] = 4,
			bad = { [11] = 3 },
		},
		priceDays = { Realm = { [1] = { [1] = 5 } } },
		latestPrice = false,
		sellers = {
			[7] = { name = "Unstamped", items = {} },
			[8] = { name = "Stamped", build = "70204", items = {} },
		},
	}
	assert(loadfile("Locales/enUS.lua"))("SkillUpForever", ns)
	setfenv(assert(loadfile("Core/Core.lua")), env)("SkillUpForever", ns)
	callbacks.SkillUpForever()
	if complete then
		equal(#messages, 0, "complete install needs no warning")
		equal(initialized, 5, "complete install initializes")
		equal(callbacks.Blizzard_Professions, ns.AttachRecipeList, "profession UI registered")
		equal(callbacks.Blizzard_TrainerUI, ns.AttachTrainer, "trainer UI registered")
		equal(ns.ProfessionSkillLine("Alchemy", 999), 171, "bundled name maps to skill line")
		equal(ns.ProfessionSkillLine("Alchimie", 171), 171, "known reported skill line remains usable")
		-- A gathering profession has no skill-up recipe, yet prices what it gathers by its skill line.
		equal(ns.ProfessionSkillLine("Skinning", 999), 393, "a gathering profession maps by name")
		equal(ns.ProfessionSkillLine("Herbalism", 999), 182, "a gathering profession maps by name")
		equal(ns.ProfessionSkillLine("Fishing", 999), 356, "a gathering profession maps by name")
		equal(ns.ProfessionSkillLine("", 0), nil, "the client's blank profession is none")
		equal(#messages, 0, "and is not reported")
		equal(ns.db.auctions, nil, "the old auction scan table is dropped")
		equal(ns.db.tracked, nil, "the old scan list is dropped")
		equal(ns.db.scanAuctions, nil, "the old scan setting is dropped")
		equal(ns.db.vendor[1], 5, "vendor prices are kept")
		equal(ns.db.stock[1][7], 5, "stock seen at a vendor is kept")
		equal(ns.db.stock[1][8], false, "an unlimited vendor stays unlimited")
		equal(ns.db.stock[2][9], nil, "a zero stock is forgotten")
		equal(ns.db.stock[2][10], nil, "a stock that is not a count is forgotten")
		equal(ns.db.stock[3], nil, "a stock row that is not a table is forgotten")
		equal(ns.db.stock.bad, nil, "a stock row for no item is forgotten")
		equal(ns.db.gatherFree, nil, "the old account-wide gather setting is dropped")
		equal(ns.db.priceDays, nil, "obsolete auction history is dropped")
		equal(ns.db.latestPrice, nil, "obsolete auction price option is dropped")
		equal(ns.db.sellers[7].build, "70205", "a vendor saved without a build is stamped with this one")
		equal(ns.db.sellers[8].build, "70204", "a vendor that already has a build keeps it")
		equal(ns.db.builds[#ns.db.builds], "70205", "this build is remembered")
		equal(ns.CollectMode(), "auction", "a character with no saved choice buys reagents")
		ns.SetCollectMode("auction")
		equal(ns.db.collectModes["Tester-Realm"], "auction", "the choice is saved under this character's key")
		equal(ns.CollectMode(), "auction", "and reads back for this character")
		ns.SetCollectMode("gather")
		equal(ns.CollectMode(), "gather", "and back")
	else
		equal(#messages, 1, "missing files produce one warning")
		equal(messages[1]:find("restart the game", 1, true) ~= nil, true, "warning asks for restart")
		equal(initialized, 0, "missing files stop initialization")
		equal(ns.db, nil, "missing files leave saved settings alone")
	end
end

-- What's new: one chat line after an update, from saved variables that may not have loaded.
do
	local callbacks, messages, version = {}, {}, "0.6.0"
	local ns = {
		InitPrices = function() end,
		InitLive = function() end,
		RegisterSettings = function() end,
		AttachItemTooltips = function() end,
		InitShopping = function() end,
		TrainerFees = {},
		TrainerRanks = {},
		PlanRoute = function() end,
		Changed = function() end,
		WhenEvent = function() end,
		Catalogue = {},
		InitCatalogue = function() end,
		CraftedGear = function() end,
		ReportLines = function() end,
		Stats = {},
	}
	assert(loadfile("Data/Recipes.lua"))("SkillUpForever", ns)
	local env = Env(messages, callbacks)
	env.C_AddOns = {
		GetAddOnMetadata = function(name, field)
			assert(name == "SkillUpForever")
			if field == "Version" then
				return version
			end
			return TOC[field]
		end,
	}
	assert(loadfile("Locales/enUS.lua"))("SkillUpForever", ns)
	setfenv(assert(loadfile("Core/Core.lua")), env)("SkillUpForever", ns)
	ns.AnnounceUpdate()
	equal(#messages, 0, "nothing before the saved variables load")
	-- Forever often loads no saved variables at all (forever-bugs#34).
	env.SkillUpForeverDB = nil
	callbacks.SkillUpForever()
	ns.AnnounceUpdate()
	equal(#messages, 0, "a first install is silent")
	equal(ns.db.lastVersion, "0.6.0", "a first install remembers its version")
	ns.AnnounceUpdate()
	equal(#messages, 0, "the same version is silent")
	-- The next patch above a release is the version a core sync's maintenance entry carries.
	local function Bump(release)
		local major, minor, patch = release:match("^(%d+)%.(%d+)%.(%d+)$")
		return ("%s.%s.%d"):format(major, minor, tonumber(patch) + 1)
	end
	local headline = ns.WHATS_NEW_VERSION
	local maintenance, next = Bump(headline), Bump(Bump(headline))
	version = headline
	ns.AnnounceUpdate()
	equal(#messages, 1, "a release with a headline prints")
	equal(
		messages[1]:find("updated to " .. headline .. ". " .. ns.WHATS_NEW, 1, true) ~= nil,
		true,
		"it names the version"
	)
	ns.AnnounceUpdate()
	equal(#messages, 1, "a new version prints once")
	version = maintenance
	ns.AnnounceUpdate()
	equal(#messages, 1, "a maintenance release says nothing new")
	equal(ns.db.lastVersion, maintenance, "a maintenance release still remembers its version")
	ns.db.whatsNew, version = false, next
	ns.AnnounceUpdate()
	equal(#messages, 1, "the setting off is silent")
	equal(ns.db.lastVersion, next, "the setting off still remembers the version")
	ns.db.whatsNew, version = true, "@project-version@"
	ns.AnnounceUpdate()
	equal(#messages, 1, "a dev checkout is silent")
	equal(ns.db.lastVersion, next, "a dev checkout's version isn't remembered")
	-- Suggest companion addons became Suggest my other Forever addons: off stays off, once; on by default.
	equal(ns.db.suggestFamily, true, "the family hints are on for a first install")
	env.SkillUpForeverDB = { companionHints = false }
	callbacks.SkillUpForever()
	equal(ns.db.suggestFamily, false, "companion hints turned off turn the family hints off")
	equal(ns.db.companionHints, nil, "and the old setting goes")
	ns.db.suggestFamily = true
	callbacks.SkillUpForever()
	equal(ns.db.suggestFamily, true, "turned back on, it stays on: the migration ran once")
	env.SkillUpForeverDB = { companionHints = true }
	callbacks.SkillUpForever()
	equal(ns.db.suggestFamily, true, "companion hints left on keep the family hints on")
	env.SkillUpForeverDB = { companionHints = false, suggestFamily = true }
	callbacks.SkillUpForever()
	equal(ns.db.suggestFamily, true, "a family setting already saved wins")
	-- A saved choice the menu doesn't offer goes back to its default; a valid one stays.
	env.SkillUpForeverDB =
		{ craftValue = "auctoin", sortMode = "coost", reagentTooltip = "typo", recipeTooltip = "nowhere" }
	callbacks.SkillUpForever()
	equal(ns.db.craftValue, "vendor", "an unknown craft value resets")
	equal(ns.db.sortMode, "blizzard", "an unknown sort resets")
	equal(ns.db.reagentTooltip, "route", "an unknown reagent tooltip mode resets")
	equal(ns.db.recipeTooltip, "window", "an unknown recipe tooltip position resets to beside the window")
	env.SkillUpForeverDB = { craftValue = "auction", sortMode = "cost", reagentTooltip = "full", recipeTooltip = "row" }
	callbacks.SkillUpForever()
	equal(ns.db.craftValue, "auction", "a valid craft value stays")
	equal(ns.db.sortMode, "cost", "a valid sort stays")
	equal(ns.db.reagentTooltip, "full", "a valid reagent tooltip mode stays")
	equal(ns.db.recipeTooltip, "row", "a valid recipe tooltip position stays")
	env.SkillUpForeverDB = { sortMode = "newest" }
	callbacks.SkillUpForever()
	equal(ns.db.sortMode, "newest", "the newest-recipe sort stays")
	-- A trainer requirement saved as 0 (an unknown one, before) is dropped; a recorded one stays.
	env.SkillUpForeverDB = { trainer = { [185] = { [1] = { 40, 0 }, [2] = { 50, 30 }, [3] = { 60 } } } }
	callbacks.SkillUpForever()
	equal(ns.db.trainer[185][1], nil, "a requirement saved as 0 is dropped")
	equal(ns.db.trainer[185][3], nil, "and one saved without any")
	equal(ns.db.trainer[185][2][2], 30, "a recorded requirement stays")
	-- Issue #124: the requirement a trainer showed is kept only as a skill; a profession saved as no table goes.
	env.SkillUpForeverDB = {
		trainer = {
			[185] = { [1] = { 40, 30, 25 }, [2] = { 50, 30, "x" }, [3] = { 60, 30, 0 }, ["4"] = { 60, 30, 30 } },
			[186] = 5,
			["164"] = {},
		},
	}
	callbacks.SkillUpForever()
	equal(ns.db.trainer[185][1][3], 25, "a shown requirement stays")
	equal(ns.db.trainer[185][2][3], nil, "one that is no number is forgotten")
	equal(ns.db.trainer[185][3][3], nil, "and one of 0")
	equal(ns.db.trainer[185][3][2], 30, "while the row itself stays")
	equal(ns.db.trainer[186], nil, "a profession saved as no table is dropped")
	equal(ns.db.trainer["164"], nil, "and one saved under no number")
	equal(ns.db.trainer[185]["4"], nil, "as is a recipe")
end

-- The update line belongs to the release it ships in: the newest CHANGELOG.md entry with a bold lead. The Unreleased
-- section is work in progress and does not count until the version is cut, and a core sync's maintenance entry has no
-- bold lead, so it changes nothing a player sees. 0.9.2 and 0.9.3 went out still announcing 0.9.1's.
do
	local function Read(path)
		local file = assert(io.open(path))
		local text = file:read("*a")
		file:close()
		return text
	end
	local core = Read("Core/Core.lua")
	-- Stylua wraps a long assignment: the value may start on the next line.
	local whatsNew = core:match('\nns%.WHATS_NEW =%s*L%["([^"]+)"%]')
	local whatsNewVersion = core:match('\nns%.WHATS_NEW_VERSION = "([^"]+)"')

	-- Each entry is its heading and its text up to the next heading; only versioned headings count, so Unreleased is
	-- skipped.
	local function Releases(text)
		local found = {}
		local nextSearch = 1
		while true do
			local start, finish, release = text:find("\n## %[(%d+%.%d+%.%d+)%] %- %d%d%d%d%-%d%d%-%d%d\n", nextSearch)
			if not start then
				return found
			end
			local following = text:find("\n## %[", finish + 1)
			found[#found + 1] = { version = release, body = text:sub(finish + 1, (following or #text + 1) - 1) }
			nextSearch = finish + 1
		end
	end

	-- The packager ships text files with CRLF line endings, so the packaged CHANGELOG.md is read the same way.
	local function Headline(text)
		for _, release in ipairs(Releases("\n" .. (text:gsub("\r\n", "\n")))) do
			local headline = release.body:match("%- %*%*(.-)%*%*")
			if headline then
				return release.version, headline
			end
		end
	end

	local newestVersion, newestHeadline = Headline(Read("CHANGELOG.md"))
	equal(newestVersion ~= nil, true, "CHANGELOG.md has a release with a bold lead")
	equal(whatsNewVersion, newestVersion, "the update line is the newest release with a bold lead")
	equal(whatsNew, newestHeadline, "the update line is that release's headline")

	-- A core sync's maintenance entry sits on top with no bold lead: the release below it still has the headline.
	local maintenance = table.concat({
		"## [9.9.9] - 2026-11-12",
		"",
		"<!-- forever-core-sync -->",
		"",
		"- Ships with the same shared code as your other Forever addons, so they keep working together.",
		"",
		"## [9.9.8] - 2026-11-11",
		"",
		"- **A real headline.** What it says.",
	}, "\n")
	local maintenanceVersion, maintenanceHeadline = Headline(maintenance)
	equal(maintenanceVersion, "9.9.8", "a maintenance entry on top is skipped for the newest version")
	equal(maintenanceHeadline, "A real headline.", "and for its headline")
end

Client.report("core_spec")
