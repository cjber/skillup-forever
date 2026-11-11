local _, ns = ...

-- The game refuses to load this addon when ForeverCore is absent (## Dependencies), but an older ForeverCore still
-- loads. Its API version, the shared API kit and the tracker section API say whether it has everything this addon
-- calls, so an out-of-date one stops the addon's own files here with one line on screen, never a chat message.
-- TrackerSection and TrackerLine arrived in ForeverCore 1.2.0, ProfessionTabs in 1.4.0 and its SetMinWidth in
-- ProfessionTabs.minor 1 (tools/forever-core.txt).
if
	ForeverCore == nil
	or (ForeverCore.API or 0) < 1
	or ForeverCore.APIKit == nil
	or ForeverCore.TrackerSection == nil
	or ForeverCore.TrackerLine == nil
	or ForeverCore.ProfessionTabs == nil
	or (ForeverCore.ProfessionTabs.minor or 0) < 1
then
	ns.broken = true
	local errors = rawget(_G, "UIErrorsFrame")
	if errors then
		errors:AddMessage("SkillUp Forever needs ForeverCore, which is missing or too old.", 1, 0.1, 0.1)
	end
end
