-- luacheck: read globals scenario
local ForeverCore = dofile("tests/forever_core.lua")

scenario("every surface, in and out of combat and across a reload", { addons = ForeverCore.addons() }, function(sim)
	sim:exercise()
end)
