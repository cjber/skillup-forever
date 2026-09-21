std = "lua51"
max_line_length = 120
exclude_files = { "tools/.cache/**", ".release/**" }
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
	"GetTrainerServiceCost", "GetTrainerServiceInfo", "GetTrainerServiceSkillReq", "GetTrainerServiceStepIndex",
	"GetTrainerTradeskillRankValues", "IsPlayerSpell", "issecretvalue", "Item", "NORMAL_FONT_COLOR",
	"TooltipDataProcessor", "UnitName", "BuyMerchantItem", "GetMerchantItemMaxStack", "MerchantFrame",
}

files["Data/Thresholds.lua"] = { max_line_length = false }
files["tests/"] = { std = "+luajit", globals = { "arg" } }
