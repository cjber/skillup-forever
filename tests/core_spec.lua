-- Run from the repository root: luajit tests/core_spec.lua
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

-- An update followed by /reload can leave newly added data files unloaded.
for _, complete in ipairs({ false, true }) do
	local callbacks, messages, initialized = {}, {}, 0
	local function Init()
		initialized = initialized + 1
	end
	local ns = {
		InitPrices = Init,
		RegisterSettings = Init,
		AttachItemTooltips = Init,
		InitShopping = Init,
		AttachRecipeList = Init,
		AttachTrainer = Init,
	}
	if complete then
		assert(loadfile("Data/Recipes.lua"))("SkillUpForever", ns)
		ns.TrainerFees, ns.TrainerRanks, ns.RecipeSources = {}, {}, {}
	end
	local env = setmetatable({
		CreateColor = function() end,
		Enum = { TradeskillRelativeDifficulty = { Optimal = 1, Medium = 2, Easy = 3, Trivial = 4 } },
		CreateFrame = function()
			return { RegisterEvent = function() end, SetScript = function() end }
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
	}, { __index = _G })
	-- A save from before auction prices moved to Auctionator.
	env.SkillUpForeverDB = { scanAuctions = true, tracked = { [1] = true }, auctions = {}, vendor = { [1] = 5 } }
	setfenv(assert(loadfile("Core.lua")), env)("SkillUpForever", ns)
	callbacks.SkillUpForever()
	if complete then
		equal(#messages, 0, "complete install needs no warning")
		equal(initialized, 4, "complete install initializes")
		equal(callbacks.Blizzard_Professions, ns.AttachRecipeList, "profession UI registered")
		equal(callbacks.Blizzard_TrainerUI, ns.AttachTrainer, "trainer UI registered")
		equal(ns.ProfessionSkillLine("Alchemy", 999), 171, "bundled name maps to skill line")
		equal(ns.ProfessionSkillLine("Alchimie", 171), 171, "known reported skill line remains usable")
		equal(ns.db.auctions, nil, "the old auction scan table is dropped")
		equal(ns.db.tracked, nil, "the old scan list is dropped")
		equal(ns.db.scanAuctions, nil, "the old scan setting is dropped")
		equal(ns.db.vendor[1], 5, "vendor prices are kept")
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
		RegisterSettings = function() end,
		AttachItemTooltips = function() end,
		InitShopping = function() end,
		TrainerFees = {},
		TrainerRanks = {},
		RecipeSources = {},
	}
	assert(loadfile("Data/Recipes.lua"))("SkillUpForever", ns)
	local env = setmetatable({
		CreateColor = function() end,
		Enum = { TradeskillRelativeDifficulty = { Optimal = 1, Medium = 2, Easy = 3, Trivial = 4 } },
		CreateFrame = function()
			return { RegisterEvent = function() end, SetScript = function() end }
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
		C_AddOns = {
			GetAddOnMetadata = function(name, field)
				assert(name == "SkillUpForever" and field == "Version")
				return version
			end,
		},
	}, { __index = _G })
	setfenv(assert(loadfile("Core.lua")), env)("SkillUpForever", ns)
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
	version = "0.7.0"
	ns.AnnounceUpdate()
	equal(#messages, 1, "a new version prints")
	equal(messages[1]:find("updated to 0.7.0. " .. ns.WHATS_NEW, 1, true) ~= nil, true, "it names the version")
	ns.AnnounceUpdate()
	equal(#messages, 1, "a new version prints once")
	ns.db.whatsNew, version = false, "0.8.0"
	ns.AnnounceUpdate()
	equal(#messages, 1, "the setting off is silent")
	equal(ns.db.lastVersion, "0.8.0", "the setting off still remembers the version")
	ns.db.whatsNew, version = true, "@project-version@"
	ns.AnnounceUpdate()
	equal(#messages, 1, "a dev checkout is silent")
	equal(ns.db.lastVersion, "0.8.0", "a dev checkout's version isn't remembered")
end

print("core_spec: " .. checks .. " checks passed")
