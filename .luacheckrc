std = "lua51"
max_line_length = 120
exclude_files = { "tools/.cache/**", ".release/**", ".types/**", "types/**", ".claude/**", ".bugpatrol/runs/**", ".speedpatrol/runs/**", ".sloppatrol/runs/**" }
ignore = { "212/_.*" } -- unused args prefixed with _

globals = { "ForeverFamily", "ForeverLeaderboards", "ForeverTrackerHost",
	"SkillUpForeverDB",
	"SkillUpForever",
	"SkillUpForever_OnAddonCompartmentClick",
	"SLASH_SKILLUPFOREVER1",
	"SLASH_SKILLUPFOREVER2",
	"SLASH_FOREVERLEADERBOARDS1",
	"SLASH_FOREVERLEADERBOARDS2",
	"SlashCmdList",
}

read_globals = { "CreateFramePoolCollection", "C_XMLUtil", "C_DateAndTime",
	"C_ChatInfo", "GetServerTime", "GetTime", "IsInGuild", "IsInGroup", "IsInRaid", "GetCursorPosition",
	"C_TradeSkillUI", "CreateColor", "CreateFrame", "CreateTreeDataProvider", "ScrollBoxConstants", "strcmputf8i", "DEFAULT_CHAT_FRAME", "Enum", "EventRegistry", "EventUtil",
	"GameTooltip", "GameTooltip_AddColoredLine", "GameTooltip_AddDisabledLine", "GameTooltip_InsertFrame",
	"GameTooltip_SetTitle", "hooksecurefunc", "Professions", "ProfessionsFrame", "ScrollUtil",
	"Settings", "strtrim", "UIParent",
	"Auctionator", "TSM_API", "C_CurrencyInfo", "C_Item", "C_MerchantFrame",
	"GameTooltip_AddBlankLineToTooltip", "GetBuildInfo", "GetMerchantItemID", "GetMerchantNumItems", "GetNormalizedRealmName", "GetRealmName", "time",
	"UnitFactionGroup", "Menu", "MenuResponse", "C_Timer",
	"DIFFICULT_DIFFICULTY_COLOR", "EASY_DIFFICULTY_COLOR", "FAIR_DIFFICULTY_COLOR", "GRAY_FONT_COLOR",
	"HIGHLIGHT_FONT_COLOR", "RED_FONT_COLOR", "TRIVIAL_DIFFICULTY_COLOR",
	"C_SkillInfo", "C_PaperDollInfo", "C_Spell", "Spell", "C_Texture", "C_Trainer", "C_TooltipInfo", "ClassTrainerFrame", "ContinuableContainer", "GameTooltip_AddNormalLine",
	"GameTooltip_Hide", "GetMoney", "GetNumTrainerServices", "GetProfessionInfo", "GetProfessions",
	"GetTrainerServiceCost", "GetTrainerServiceInfo", "GetTrainerServiceSkillReq", "GetTrainerServiceStepIndex", "UnitLevel", "UnitClass", "PlaySound", "SOUNDKIT", "GameTooltip_AddColoredDoubleLine",
	"GameTooltip_AddHighlightLine", "GameTooltip_AddInstructionLine", "IsModifiedClick", "ChatFrameUtil",
	"HandleModifiedItemClick", "IsShiftKeyDown", "CreateScrollBoxListLinearView", "CreateDataProvider", "CreateSettingsButtonInitializer",
	"GetTrainerTradeskillRankValues", "C_SpellBook", "C_Traits", "issecretvalue", "Item", "NORMAL_FONT_COLOR",
	"TooltipDataProcessor", "UnitName", "UnitGUID", "BuyMerchantItem", "GetMerchantItemMaxStack", "MerchantFrame", "PanelTemplates_SelectTab", "PanelTemplates_DeselectTab", "PanelTemplates_TabResize", "GetItemButtonIconTexture", "MenuUtil", "Mixin", "ObjectiveTrackerFrame", "OBJECTIVE_TRACKER_COLOR", "OBJECTIVE_DASH_STYLE_HIDE",
	"C_Map", "C_SuperTrack", "CreateVector2D", "TomTom", "UiMapPoint", "UnitPosition", "Syndicator", "tContains",
	"ShortestPathForever", "InCombatLockdown", "GetLocale", "C_AddOns",
	"STAT_ATTACK_POWER", "STAT_ARMOR", "STAT_SPELLDAMAGE", "STAT_SPELLHEALING",
	"STAT_CRITICAL_STRIKE", "STAT_MOVEMENT_SPEED", "RESISTANCE_LABEL",
	"LibQuestieDB", "Questie", "AtlasLoot", "bit", "debugprofilestop", "loadstring", "setfenv",
	"UNKNOWN", "UNIT_SKINNABLE_LEATHER", "UNIT_SKINNABLE_HERB", "UNIT_SKINNABLE_ROCK", "UnitRace", "geterrorhandler", "debugstack", "date", "ChatFontNormal", "UISpecialFrames", "APPRENTICE", "JOURNEYMAN", "EXPERT", "ARTISAN", "DEFAULT", "OFF", "TOTAL",
	"RAID_CLASS_COLORS", "GREEN_FONT_COLOR", "GetGuildRosterInfo", "GetNumGuildMembers",
}

files["Data/Thresholds.lua"] = { max_line_length = false }
files["Data/Sources.lua"] = { max_line_length = false }
files["Locales/"] = { max_line_length = false } -- one phrase per line, however long
files["tests/"] = { std = "+luajit" }
read_globals[#read_globals + 1] = "EditModeManagerFrame"
read_globals[#read_globals + 1] = "AuctionHouseFrame"

read_globals[#read_globals + 1] = "MinimalSliderWithSteppersMixin"
read_globals[#read_globals + 1] = "InputUtil"
read_globals[#read_globals + 1] = "UIErrorsFrame"
read_globals[#read_globals + 1] = "DropdownButtonMixin"
read_globals[#read_globals + 1] = "MenuInputContext"
-- Core/OpenSettings.lua: the client's secure settings panel opener.
read_globals[#read_globals + 1] = "CreateSecureDelegate"
read_globals[#read_globals + 1] = "C_SettingsUtil"
