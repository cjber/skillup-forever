-- Run from the repository root: luajit tests/curseforge_trainer_spec.lua
local Client = dofile("tests/client.lua")
local c = Client.load()
local G, ns = c.G, c.ns
c.professions = { { name = "Engineering", id = 202, rank = 50, max = 75 } }
c.level = 20
local hooks = {}
G.hooksecurefunc = function(name, callback)
	hooks[name] = callback
end
G.ClassTrainerFrame = G.CreateFrame("Frame")
G.ClassTrainerFrame.ScrollBox = { ForEachFrame = function() end }
G.ClassTrainerFrame.skillStepButton = G.CreateFrame("Button")
G.ClassTrainerFrame.skillStepButton:Hide()
G.GetNumTrainerServices = function()
	return 1
end
G.GetTrainerServiceInfo = function()
	return "Rough Copper Bomb", "available", nil, 1
end
G.GetTrainerServiceCost = function()
	return 100
end
local shown
G.GetTrainerServiceSkillReq = function()
	return "Engineering", shown
end
G.GetTrainerTradeskillRankValues = function()
	return 50, 75, 0
end
G.GetTrainerServiceStepIndex = function() end
G.C_TooltipInfo = {
	GetTrainerService = function()
		return { id = 3923 }
	end,
}
ns.AttachTrainer()
local function Visit(required)
	shown = required
	hooks.ClassTrainerFrame_Update()
	c.Advance(0)
end
Visit(0)
Client.equal(
	ns.TrainingFor({ skillLine = 202 }, 3923)[2],
	30,
	"an absent zero requirement keeps the bundled skill gate"
)
Client.equal(ns.db.trainer[202][3923][3], nil, "zero is not recorded as an observed skill requirement")
Visit(nil)
Client.equal(ns.TrainingFor({ skillLine = 202 }, 3923)[2], 30, "an absent nil requirement keeps the same skill gate")
Visit(35)
Client.equal(ns.TrainingFor({ skillLine = 202 }, 3923)[2], 35, "a positive live requirement replaces the bundle")
Client.equal(ns.db.trainer[202][3923][3], 35, "the positive observation remains reportable")
Client.report("curseforge_trainer_spec")
