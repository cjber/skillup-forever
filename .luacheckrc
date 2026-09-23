std = "lua51"
max_line_length = 120
exclude_files = { "tools/.cache/**", ".release/**", ".types/**", "types/**" }
ignore = { "212/_.*" } -- unused args prefixed with _

globals = {
	"SkillUpForeverDB",
	"SkillUpForever_OnAddonCompartmentClick",
	"SLASH_SKILLUPFOREVER1",
	"SLASH_SKILLUPFOREVER2",
	"SlashCmdList",
}

read_globals = {
	"C_TradeSkillUI", "CreateColor", "CreateFrame", "CreateTreeDataProvider", "ScrollBoxConstants", "strcmputf8i", "DEFAULT_CHAT_FRAME", "Enum", "EventRegistry", "EventUtil",
	"GameTooltip", "GameTooltip_AddColoredLine", "GameTooltip_AddDisabledLine", "GameTooltip_InsertFrame",
	"GameTooltip_SetTitle", "hooksecurefunc", "Professions", "ProfessionsFrame", "ScrollUtil",
	"Settings", "strtrim", "UIParent",
	"AuctionHouseFrame", "Auctionator", "C_AuctionHouse", "C_CurrencyInfo", "C_Item", "C_MerchantFrame",
	"GameTooltip_AddBlankLineToTooltip", "GetMerchantItemID", "GetMerchantNumItems", "GetNormalizedRealmName", "time",
	"UnitFactionGroup", "Menu", "MenuResponse", "C_Timer",
	"DIFFICULT_DIFFICULTY_COLOR", "EASY_DIFFICULTY_COLOR", "FAIR_DIFFICULTY_COLOR", "GRAY_FONT_COLOR",
	"HIGHLIGHT_FONT_COLOR", "RED_FONT_COLOR", "TRIVIAL_DIFFICULTY_COLOR",
	"C_Spell", "C_Trainer", "C_TooltipInfo", "ClassTrainerFrame", "ContinuableContainer", "GameTooltip_AddNormalLine",
	"GameTooltip_Hide", "GetMoney", "GetNumTrainerServices", "GetProfessionInfo", "GetProfessions",
	"GetTrainerServiceCost", "GetTrainerServiceInfo", "GetTrainerServiceSkillReq", "GetTrainerServiceStepIndex", "UnitLevel", "PlaySound", "SOUNDKIT", "GameTooltip_AddColoredDoubleLine",
	"GameTooltip_AddHighlightLine", "GameTooltip_AddInstructionLine", "IsModifiedClick", "ChatEdit_InsertLink",
	"HandleModifiedItemClick", "IsShiftKeyDown", "CreateScrollBoxLinearView",
	"GetTrainerTradeskillRankValues", "C_SpellBook", "issecretvalue", "Item", "NORMAL_FONT_COLOR",
	"TooltipDataProcessor", "UnitName", "BuyMerchantItem", "GetMerchantItemMaxStack", "MerchantFrame", "MenuUtil", "Mixin", "ObjectiveTrackerFrame", "ObjectiveTrackerManager", "OBJECTIVE_TRACKER_COLOR", "OBJECTIVE_DASH_STYLE_HIDE",
	"C_Map", "C_SuperTrack", "CreateVector2D", "TomTom", "UiMapPoint", "UnitPosition", "Syndicator", "tContains",
}

files["Data/Thresholds.lua"] = { max_line_length = false }
files["Data/Sources.lua"] = { max_line_length = false }
files["tests/"] = { std = "+luajit" }
