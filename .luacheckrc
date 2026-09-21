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
	"C_TradeSkillUI", "CreateColor", "CreateFrame", "DEFAULT_CHAT_FRAME", "Enum", "EventRegistry", "EventUtil",
	"GameTooltip", "GameTooltip_AddColoredLine", "GameTooltip_AddDisabledLine", "GameTooltip_InsertFrame",
	"GameTooltip_SetTitle", "hooksecurefunc", "Professions", "ProfessionsFrame", "ScrollBoxConstants", "ScrollUtil",
	"Settings", "strtrim", "UIParent",
	"DIFFICULT_DIFFICULTY_COLOR", "EASY_DIFFICULTY_COLOR", "FAIR_DIFFICULTY_COLOR", "GRAY_FONT_COLOR",
	"HIGHLIGHT_FONT_COLOR", "RED_FONT_COLOR", "TRIVIAL_DIFFICULTY_COLOR",
}

files["Data/Thresholds.lua"] = { max_line_length = false }
files["tests/"] = { std = "+luajit", globals = { "arg" } }
