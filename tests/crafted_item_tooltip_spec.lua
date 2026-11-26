-- Run from the repository root: luajit tests/crafted_item_tooltip_spec.lua
local Client = dofile("tests/client.lua")
local equal = Client.equal

local POTION, HERB = 60, 61
local c = Client.load({
	saved = { craftValue = "none", priceSource = "tsm" },
	tsm = { [POTION] = 1000 },
	data = {
		RecipeData = {
			[100] = {
				skillLine = 171,
				reagents = { { itemID = HERB, quantity = 1 } },
				output = { itemID = POTION, quantity = 1 },
			},
			[101] = {
				skillLine = 171,
				reagents = { { itemID = HERB, quantity = 3 } },
				output = { itemID = POTION, quantity = 4 },
			},
		},
		ItemSellPrices = { [POTION] = 500 },
	},
})
local G = c.G
local posts = c.postCalls[G.Enum.TooltipDataType.Item]
local post = posts[#posts]
G.C_CurrencyInfo.GetCoinTextureString = tostring
G.GameTooltip_AddNormalLine = function(tooltip, line)
	table.insert(tooltip.lines, line)
end

local function Tooltip()
	return {
		lines = {},
		IsForbidden = function()
			return false
		end,
		HookScript = function(self, script, hook)
			self[script] = hook
		end,
	}
end

local bagTooltip, linkTooltip = Tooltip(), Tooltip()
local item = { id = POTION }
local link = { id = POTION, hyperlink = "item:60" }
post(bagTooltip, item)
equal(#bagTooltip.lines, 0, "crafted item prices are off by default")

c.SetSetting("craftedItemTooltip", true)
post(bagTooltip, item)
equal(bagTooltip.lines[1], "Crafting cost: ? / Auctionator sale: ?", "missing prices stay unknown")
local other = Tooltip()
post(other, { id = HERB })
equal(#other.lines, 0, "items without a maker have no comparison")

c.auction[HERB] = 80
c.AuctionatorScan()
post(linkTooltip, link)
equal(linkTooltip.lines[1], "Crafting cost: 60 / Auctionator sale: ?", "cheapest per item uses the batch yield")

c.auction[POTION], c.auction[HERB] = 200, 100
post(linkTooltip, link)
equal(#linkTooltip.lines, 1, "a repeated item post does not duplicate the line")
local reopened = Tooltip()
post(reopened, link)
equal(reopened.lines[1], linkTooltip.lines[1], "reopening a link uses the cached line before the scan arrives")

c.AuctionatorScan()
linkTooltip:OnTooltipCleared()
linkTooltip.lines = {}
post(linkTooltip, link)
equal(linkTooltip.lines[1], "Crafting cost: 75 / Auctionator sale: 190", "a scan refreshes both prices for chat links")

c.auction[HERB] = nil
c.AuctionatorScan()
local unknownCost = Tooltip()
post(unknownCost, item)
equal(
	unknownCost.lines[1],
	"Crafting cost: ? / Auctionator sale: 190",
	"a known sale still shows without a reagent price"
)

c.SetSetting("craftedItemTooltip", false)
local disabled = Tooltip()
post(disabled, link)
equal(#disabled.lines, 0, "turning the option off hides the comparison again")

print("crafted_item_tooltip_spec: ok")
