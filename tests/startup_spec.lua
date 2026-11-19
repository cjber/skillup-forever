-- Run from the repository root: luajit tests/startup_spec.lua
-- /skillup opens the settings, so they register before the rest of startup: a later step that fails on a player's
-- own setup must not leave the command silent (#866).
local Client = dofile("tests/client.lua")

-- InitCatalogue, InitLive and InitPrices ran before the settings until #866; the steps after them keep any later move
-- of the settings from slipping behind a step that can fail.
for _, step in ipairs({ "InitCatalogue", "InitLive", "InitPrices", "AttachItemTooltips", "InitShopping" }) do
	-- The files load as shipped; only that step's call raises, before the addon's ADDON_LOADED runs.
	local c = Client.load({ boot = false })
	assert(type(c.ns[step]) == "function", step .. " is a startup step")
	c.ns[step] = function()
		error("injected failure in " .. step)
	end
	assert(not pcall(c.Boot), "the injected failure stops the rest of startup")
	c.EnterWorld()
	c.Advance(0)
	c.G.SlashCmdList.SKILLUPFOREVER("")
	assert(c.settingsOpens == 1, "/skillup opens the settings when " .. step .. " fails")
end

print("startup_spec: ok")
