-- Illustrative provider observations, rendered from the production recipe tooltip.
local Client = dofile("tests/client.lua")
local recipeID, reagentID, outputID = 3275, 2589, 1251
local c = Client.load({
	boot = false,
	auctionator = false,
	tsm = {},
	data = {
		Thresholds = { [recipeID] = { 1, 30, 45, 60 } },
		RecipeData = {
			[recipeID] = {
				skillLine = 129,
				reagents = { { itemID = reagentID, quantity = 1 } },
				output = { itemID = outputID, quantity = 1 },
			},
		},
		TrainerRanks = { [129] = {} },
		VendorPrices = { [reagentID] = 10 },
		GatheredBy = {},
	},
})
local G, ns = c.G, c.ns
local lines, hooks = {}, {}
local tip = {}
function tip.GetName()
	return "GameTooltip"
end
function tip:SetOwner()
	lines = {}
	for _, fn in ipairs(hooks.OnTooltipCleared or {}) do
		fn(self)
	end
end
function tip.AddLine(_, text)
	lines[#lines + 1] = { left = text }
	G["GameTooltipTextLeft" .. #lines] = { line = #lines }
end
function tip:AddDoubleLine(left, right)
	self:AddLine(left)
	lines[#lines].right = right
end
function tip.HookScript(_, key, fn)
	hooks[key] = hooks[key] or {}
	table.insert(hooks[key], fn)
end
function tip.SetPoint() end
function tip.SetMinimumWidth() end
function tip.Show() end
function tip.IsForbidden()
	return false
end
G.GameTooltip = tip
G.GameTooltip_SetTitle = function(self, text)
	self:AddLine(text)
end
G.GameTooltip_AddColoredLine = G.GameTooltip_SetTitle
G.GameTooltip_AddDisabledLine = G.GameTooltip_SetTitle
G.GameTooltip_AddBlankLineToTooltip = function(self)
	self:AddLine(" ")
end
G.HIGHLIGHT_FONT_COLOR, G.RED_FONT_COLOR = {}, {}
G.C_CurrencyInfo = {
	GetCoinTextureString = function(copper)
		return tostring(copper) .. " copper"
	end,
}
G.C_Texture = {
	GetAtlasInfo = function()
		return nil
	end,
}
G.ProfessionsFrame = { ProfessionsOverviewTab = {} }
G.Professions = {
	GetProfessionInfo = function()
		return { skillLevel = 20, maxSkillLevel = 75, displayName = "First Aid" }
	end,
	GetHighestLearnedRecipe = function() end,
}
c.items[reagentID] = { name = "Linen Cloth" }
c.items[outputID] = { name = "Linen Bandage", sell = 3 }
c.known[recipeID] = true
c.professions = { { name = "First Aid", rank = 20, max = 75, id = 129 } }
c.Boot()
c.EnterWorld()
c.Advance(0)
ns.db.craftValue, ns.db.rowCost = "sale", "craft"
local function Quote(text)
	return '"' .. text:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
end
local samples = { { name = "reported", volume = 12.5 }, { name = "zero", volume = 0 }, { name = "unknown" } }
for _, sample in ipairs(samples) do
	G.TSM_API.GetCustomPriceValue = function(source)
		if source == "DBRegionSaleAvg" then
			return 95
		end
		if source == "DBRegionSoldPerDay" then
			return sample.volume
		end
		return 10
	end
	ns.Changed("prices")
	ns.ShowRecipeTooltip(ns, {}, { recipeInfo = { recipeID = recipeID, name = "Linen Bandage", learned = true } })
	local encoded = {}
	for _, line in ipairs(lines) do
		encoded[#encoded + 1] = '{"left":'
			.. Quote(line.left)
			.. (line.right and ',"right":' .. Quote(line.right) or "")
			.. "}"
	end
	print(sample.name .. "\t[" .. table.concat(encoded, ",") .. "]")
end
