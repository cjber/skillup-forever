-- Run from the repository root: luajit tests/core_spec.lua
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

-- An update followed by /reload can leave newly added data files unloaded.
for _, complete in ipairs({ false, true }) do
	local callbacks, messages, initialized, onEvent = {}, {}, 0, nil
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
			return {
				RegisterEvent = function() end,
				UnregisterEvent = function() end,
				SetScript = function(_, script, handler)
					if script == "OnEvent" then
						onEvent = handler
					end
				end,
			}
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
	setfenv(assert(loadfile("Core.lua")), env)("SkillUpForever", ns)
	-- Forever reports the addon loaded while its files run; SavedVariables arrive only after.
	equal(callbacks.SkillUpForever, nil, "init waits for our own ADDON_LOADED")
	env.SkillUpForeverDB = { trackedProfessions = { [165] = true } }
	onEvent(nil, "ADDON_LOADED", "Blizzard_Professions")
	equal(initialized, 0, "another addon's ADDON_LOADED is ignored")
	onEvent(nil, "ADDON_LOADED", "SkillUpForever")
	if complete then
		equal(#messages, 0, "complete install needs no warning")
		equal(initialized, 4, "complete install initializes")
		equal(callbacks.Blizzard_Professions, ns.AttachRecipeList, "profession UI registered")
		equal(callbacks.Blizzard_TrainerUI, ns.AttachTrainer, "trainer UI registered")
		equal(ns.ProfessionSkillLine("Alchemy", 999), 171, "bundled name maps to skill line")
		equal(ns.ProfessionSkillLine("Alchimie", 171), 171, "known reported skill line remains usable")
		equal(ns.db.trackedProfessions[165], true, "SavedVariables that arrive after the files are kept")
		equal(type(ns.db.vendor), "table", "defaults fill the missing keys")
	else
		equal(#messages, 1, "missing files produce one warning")
		equal(messages[1]:find("restart the game", 1, true) ~= nil, true, "warning asks for restart")
		equal(initialized, 0, "missing files stop initialization")
		equal(ns.db, nil, "missing files leave saved settings alone")
	end
end

print("core_spec: " .. checks .. " checks passed")
