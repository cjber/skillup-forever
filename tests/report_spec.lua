-- Run from the repository root: luajit tests/report_spec.lua
-- /su report (cjber/adventure-guide-forever#156): one selected block of text with the versions, the character,
-- SkillUp's own lines (settings, providers, each profession's route, the audit, the trainer checks), the errors
-- ns.SafeCall caught and the other addons, never longer than one message; ns.SafeCall keeps errors and still
-- reports them.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local function has(text, part, label)
	equal(text:find(part, 1, true) ~= nil, true, ("%s: %q in\n%s"):format(label, part, text))
end

local BANDAGE, SILK = 1, 3
local function Load()
	local c = Client.load({
		saved = { routeTargets = { [129] = 40 } },
		data = {
			Thresholds = { [BANDAGE] = { 1, 30, 45, 60 } },
			RecipeData = { [BANDAGE] = { skillLine = 129, reagents = { { itemID = SILK, quantity = 1 } } } },
			TrainerFees = {},
			TrainerRanks = {},
			TrainerInferred = {},
			VendorPrices = { [SILK] = 10 },
		},
	})
	c.level = 18
	c.known[BANDAGE] = true
	c.items[SILK] = { name = "Linen Cloth" }
	c.professions = { { name = "First Aid", icon = 1, rank = 10, max = 75, id = 129 } }
	c.Boot()
	return c
end

-- The report window: the frame /su report made, with its edit box.
local function Window(c)
	local edit = c.focus
	return edit and edit:GetParent():GetParent():GetParent(), edit
end

do
	local c = Load()
	c.addons = { { "Questie", "9.1.0" }, { "ShortestPathForever", "0.9.0" } }
	local before = #c.frames
	c.G.SlashCmdList.SKILLUPFOREVER("report")
	local frame, edit = Window(c)
	equal(edit ~= nil, true, "the report's edit box has the focus")
	local text = edit:GetText()
	equal(edit.highlighted, text, "the whole report is selected")
	equal(frame.title, "SkillUp report", "its title")
	equal(frame:IsShown(), true, "shown")
	has(text, "SkillUpForever 1.2.3 | WoW 1.60.1 (", "versions, build and locale")
	has(text, "Character: level 18 Orc SHAMAN", "character")
	has(text, "Place: map ", "place")
	has(text, "Settings: crafts count vendor, gathered free, reagent tooltips route, sort blizzard", "settings")
	has(text, "Providers: QuestieDB missing, AtlasLoot missing, Auctionator ready", "providers")
	has(text, "First Aid [129]: 10+0/75; route to 40 reaches 40, ", "each profession and its route")
	has(text, "Audit: no profession open", "the audit needs an open profession")
	has(text, "Trainers: nothing to check", "the trainer checks")
	has(text, "Errors: none caught", "no errors yet")
	has(text, "Other addons (2): Questie 9.1.0, ShortestPathForever 0.9.0", "the other addons with versions")
	equal(#text <= 2000, true, "one message")

	-- Read-only: a key typed in the box puts the report back, selected.
	edit.text, edit.highlighted = "x", nil
	edit.scripts.OnTextChanged(edit, true)
	equal(edit:GetText(), text, "typing restores the report")
	equal(edit.highlighted, text, "and selects it again")
	edit.scripts.OnEscapePressed(edit)
	equal(frame:IsShown(), false, "Escape hides it")
	local made = #c.frames - before
	c.G.SlashCmdList.SKILLUPFOREVER("report")
	equal(frame:IsShown(), true, "shown again")
	equal(#c.frames - before, made, "the window is made once")
	equal(#c.errors, 0, "no errors")
end

-- ns.SafeCall: pcall's answers, and each failure kept and passed to the error handler.
do
	local c = Load()
	local ns = c.ns
	c.allowErrors = true
	local ok, a, b, d = ns.SafeCall("test", function(x)
		return x, nil, 3
	end, 1)
	equal(ok, true, "SafeCall: ok")
	equal(a, 1, "SafeCall: first result")
	equal(b, nil, "SafeCall: a nil result kept in place")
	equal(d, 3, "SafeCall: last result")
	local failed, message = ns.SafeCall("test", error, "boom", 0)
	equal(failed, false, "SafeCall: failure")
	equal(message, "boom", "SafeCall: the error")
	equal(#c.errors, 1, "SafeCall: passed to the error handler")
	ns.SafeCall("test", error, "boom", 0)
	equal(ns.CaughtErrors()[1].count, 2, "SafeCall: a repeat is counted")
	for index = 1, 6 do
		ns.SafeCall("many", error, "error " .. index, 0)
	end
	local caught = ns.CaughtErrors()
	equal(#caught, 5, "SafeCall: the last five kept")
	equal(caught[5].message, "error 6", "SafeCall: newest kept")

	-- A failing view stops neither the others nor the event: the error is kept with the stale view's name.
	local after = 0
	ns.WhenStale("gear", function()
		error("gear failed", 0)
	end)
	ns.WhenStale("tooltip", function()
		after = after + 1
	end)
	ns.Changed("sources")
	equal(after, 1, "the view after a failing one still redraws")
	caught = ns.CaughtErrors()
	equal(caught[#caught].label, "stale gear", "the failure is kept under the view's name")

	c.G.SlashCmdList.SKILLUPFOREVER("report")
	local _, edit = Window(c)
	local text = edit:GetText()
	has(text, "Errors (5):", "report: the caught errors")
	has(text, "- [stale gear] x1 gear failed", "report: newest first")
	equal(#text <= 2000, true, "report: still one message")
end

-- Many other addons: the list says how many more, and the report stays one message.
do
	local c = Load()
	for index = 1, 300 do
		c.addons[index] = { ("SomeAddon%03d"):format(index), "1.0." .. index }
	end
	c.G.SlashCmdList.SKILLUPFOREVER("report")
	local _, edit = Window(c)
	local text = edit:GetText()
	equal(#text <= 2000, true, "many addons: one message")
	has(text, "Other addons (300): SomeAddon001 1.0.1, ", "many addons: counted")
	equal(text:find("SomeAddon300", 1, true), nil, "many addons: the last left out")
end

Client.report("report_spec")
