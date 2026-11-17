-- Adapt the contract slots to the focused specs' menu descriptions; core owns their rendered order.
return function(module, block, root)
	local menu = {}
	menu.Title = root.CreateTitle
	for _, slot in ipairs({ "Action", "Open", "End", "Submenu" }) do
		menu[slot] = function(_, text, action)
			return root:CreateButton(text, action)
		end
	end
	module.trackerMenu({ kind = "block", id = block.id, block = block, module = module }, menu)
end
