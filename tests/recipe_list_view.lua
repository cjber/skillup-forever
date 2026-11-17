-- The addon-owned list surface for the focused provider specs. Blizzard's provider is held separately.
return function(native)
	local function noop() end
	local widget = { Hide = noop, SetAlpha = noop, SetParent = noop }
	native.Show = noop
	native.Hide = noop
	native.SetAlpha = noop
	native.EnableMouse = noop
	local shown, provider = false, nil
	local box = { ScrollTarget = widget, RegisterCallback = noop }
	function box.SetDataProvider(_, value)
		provider = value
	end
	function box.GetDataProvider()
		return provider
	end
	box.ForEachFrame = function(_, fn)
		return native:ForEachFrame(fn)
	end
	local list = {
		ScrollBox = box,
		SearchBox = widget,
		FilterDropdown = widget,
		Background = widget,
		BackgroundNineSlice = widget,
		SetAllPoints = noop,
		SetFrameLevel = noop,
		SetWidth = noop,
		SetHeight = noop,
		SetScrollChild = noop,
		SetScript = noop,
	}
	function list.Show()
		shown = true
	end
	function list.Hide()
		shown = false
	end
	function list.IsShown()
		return shown
	end
	return list, widget
end
