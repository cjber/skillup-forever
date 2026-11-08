-- Run from the repository root: luajit tests/gamepad_menus_spec.lua
-- Under the gamepad interface a Blizzard menu opened from SkillUp's own code takes the gamepad focus under
-- SkillUp's taint, and the next secure window call then has its protected SetPreferredGamepadInteractTarget
-- refused (#398). These are the menus SkillUp opens, a row's right-click, the route's Skipped row and the
-- tracker's header, and the source guard that keeps a new one from going round this wrapper.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local function noop() end

local function Read(path)
	local file = assert(io.open(path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
end

local c = Client.load()
local ns, G = c.ns, c.G

-- The client's menu call, the screen errors and the gamepad check, all read at call time by Core/Core.lua.
local menus, errors = {}, {}
G.MenuUtil = {
	CreateContextMenu = function(owner, generator)
		local menu = { owner = owner, generator = generator }
		menus[#menus + 1] = menu
		return menu
	end,
}
G.UIErrorsFrame = {
	AddMessage = function(_, text, r, g, b)
		errors[#errors + 1] = { text = text, r = r, g = g, b = b }
	end,
}
local gamepad = false
G.InputUtil.IsGamepadUIEnabled = function()
	return gamepad
end

local function Reset()
	menus, errors = {}, {}
end

local function Menu() end

-- A row's right-click goes through the namespace, so the gamepad interface opens no menu and says why.
local rowViewFactory
G.CreateScrollBoxListLinearView = function()
	return {
		SetElementExtent = noop,
		SetElementExtentCalculator = noop,
		SetElementInitializer = noop,
		SetElementFactory = function(_, factory)
			rowViewFactory = factory
		end,
	}
end
local parent = G.CreateFrame("Frame")
local list = ns.CreateList(parent)
list:Begin()
list:Add({ text = "Linen Bandage", menu = Menu })
list:Finish()
local row = G.CreateFrame("Button")
local initializer
rowViewFactory(function(_, init)
	initializer = init
end, list.rows[1])
initializer(row, list.rows[1])

gamepad = true
Reset()
row.scripts.OnClick(row, "RightButton")
equal(#menus, 0, "a row's right-click opens no menu under the gamepad interface")
equal(#errors, 1, "and shows one line instead")
equal(errors[1].text, ns.L["This menu needs mouse and keyboard."], "the line says what the menu needs")
equal(errors[1].r, 1, "in the client's error colour")
equal(errors[1].g, 1, "in the client's error colour")
equal(errors[1].b, 0, "in the client's error colour")

gamepad = false
Reset()
row.scripts.OnClick(row, "RightButton")
equal(#menus, 1, "a row's right-click opens the menu with the gamepad interface off")
equal(menus[1].owner, row, "on the row")
equal(menus[1].generator, Menu, "with the row's own generator")
equal(#errors, 0, "and says nothing")

-- The route's Skipped row reaches the same wrapper, through its own click.
gamepad = true
Reset()
ns.ContextMenu(row, Menu)
equal(#menus, 0, "a direct context menu opens nothing under the gamepad interface")
equal(#errors, 1, "and shows the same line")
gamepad = false
Reset()
ns.ContextMenu(row, Menu)
equal(#menus, 1, "and opens with the gamepad interface off")
equal(menus[1].owner, row, "on its owner")
equal(menus[1].generator, Menu, "with its generator")

-- The tracker's header click, the section's own path into the menu. The stub client leaves out the stock
-- module's context menu parent, so the spec gives it one.
local module = G.SkillUpForeverObjectiveTracker
function module.GetContextMenuParent()
	return module
end
local block = {
	profession = "First Aid",
	plan = { profession = { name = "First Aid", skillLine = 129 }, crafts = {}, ranks = {}, steps = {} },
	steps = {},
}
gamepad = true
Reset()
module:OnBlockHeaderClick(block)
equal(#menus, 0, "the tracker's header opens no menu under the gamepad interface")
equal(#errors, 1, "and shows the line")
gamepad = false
Reset()
module:OnBlockHeaderClick(block)
equal(#menus, 1, "the tracker's header opens its menu with the gamepad interface off")
equal(menus[1].owner, module, "on the tracker's menu parent")
equal(type(menus[1].generator), "function", "filled by the section's generator")

-- The dropdown's OpenMenu steps to the next radio under the gamepad interface and opens the menu otherwise.
local current
local function Radio(name)
	return {
		name = name,
		IsRadio = function()
			return true
		end,
		CanSelect = function()
			return true
		end,
		IsSelected = function()
			return current == name
		end,
		Pick = function()
			current = name
			return true
		end,
	}
end
local first, second = Radio("First"), Radio("Second")
local description = {}
local dropdown = {
	enabled = true,
	IsEnabled = function(self)
		return self.enabled
	end,
	GenerateMenu = function(self)
		self.generated = true
	end,
	CollectSelectionData = function()
		return nil, first
	end,
	GetMenuDescription = function()
		return description
	end,
	Pick = function(self, radio, context)
		self.picked, self.context = radio, context
		return radio:Pick(context)
	end,
}
G.MenuUtil.TraverseMenu = function(_, op)
	if op(first) then
		return true
	end
	return op(second)
end
G.MenuInputContext = { MouseWheel = 7 }
ns.StepDropdownUnderGamepad(dropdown)
gamepad = true
current = nil
dropdown:OpenMenu()
equal(dropdown.generated, true, "a gamepad press regenerates the dropdown's description")
equal(dropdown.picked, first, "and picks the next radio")
equal(dropdown.context, 7, "the way the mouse wheel does")
equal(current, "First", "the pick selects it")

-- With no next radio the press wraps to the first selectable one.
dropdown.CollectSelectionData = function()
	return nil, nil
end
dropdown.picked = nil
current = second
dropdown:OpenMenu()
equal(dropdown.picked, first, "with no next radio the press wraps to the first")

-- With the gamepad interface off the dropdown keeps the client's own OpenMenu, which this stub records.
local opened = 0
G.DropdownButtonMixin = {
	OpenMenu = function(self)
		self:GenerateMenu()
	end,
}
dropdown.GenerateMenu = function(self)
	self.generated = true
	opened = opened + 1
end
gamepad = false
dropdown.picked = nil
dropdown:OpenMenu()
equal(opened, 1, "with the gamepad interface off the client's OpenMenu runs")

-- A source guard: the wrapper is the only door to a context menu, and every dropdown SkillUp builds is
-- wrapped. UI/TrackerHost.lua is vendored and its fallback branch only runs when ns.ContextMenu is missing.
local function AddonFiles()
	local files = {}
	for line in Read("SkillUpForever.toc"):gmatch("[^\r\n]+") do
		local path = line:gsub("\\", "/")
		if path:match("^Core/.*%.lua$") or path:match("^UI/.*%.lua$") or path:match("^Integrations/.*%.lua$") then
			files[#files + 1] = path
		end
	end
	return files
end

-- A comment is not a call.
local function Code(text)
	return text:gsub("%-%-[^\n]*", "")
end

local menusOutsideCore, dropdowns, unchecked = {}, {}, {}
for _, path in ipairs(AddonFiles()) do
	local code = Code(Read(path))
	if
		path ~= "Core/Core.lua"
		and path ~= "UI/TrackerHost.lua"
		and code:find("MenuUtil.CreateContextMenu", 1, true)
	then
		menusOutsideCore[#menusOutsideCore + 1] = path
	end
	-- UI/Leaderboards.lua is vendored and owns its dropdown, which is not the route's profession picker.
	if path ~= "UI/Leaderboards.lua" and code:find('CreateFrame("DropdownButton"', 1, true) then
		dropdowns[#dropdowns + 1] = path
		if not code:find("ns.StepDropdownUnderGamepad(", 1, true) then
			unchecked[#unchecked + 1] = path
		end
	end
end
equal(table.concat(menusOutsideCore, "\n"), "", "only Core/Core.lua opens a context menu directly")
equal(#dropdowns > 0, true, "the guard sees the route's profession dropdown")
equal(table.concat(unchecked, "\n"), "", "every dropdown SkillUp builds is wrapped for the gamepad interface")

Client.report("gamepad_menus_spec")
