-- ForeverCore, the addon every Forever addon requires, loaded the way the client loads it: the files its TOC lists,
-- in order, from the checkout the FOREVER_CORE environment variable names. Local runs default to the sibling checkout
-- ../forever-core; CI checks the ref in tools/forever-core.txt out into forever-core/.
local ForeverCore = {}

local DEFAULT_DIRECTORY = "../forever-core"

local function Exists(path)
	local file = io.open(path .. "/ForeverCore.toc", "r")
	if file then
		file:close()
		return true
	end
	return false
end

-- The checkout, as FOREVER_CORE names it. A relative path is read from the working directory first, then from
-- GITHUB_WORKSPACE, because the packaged specs run from a scratch folder rather than the repository root.
---@return string
function ForeverCore.directory()
	local configured = os.getenv("FOREVER_CORE")
	local candidates = {}
	if configured and configured ~= "" then
		candidates[#candidates + 1] = configured
		if configured:sub(1, 1) ~= "/" then
			local workspace = os.getenv("GITHUB_WORKSPACE")
			if workspace and workspace ~= "" then
				candidates[#candidates + 1] = workspace .. "/" .. configured
			end
		end
	else
		candidates[#candidates + 1] = DEFAULT_DIRECTORY
	end
	for _, path in ipairs(candidates) do
		local cleaned = path:gsub("/+$", "")
		if cleaned ~= "" and Exists(cleaned) then
			return cleaned
		end
	end
	error(
		"ForeverCore's checkout is not at "
			.. table.concat(candidates, " or ")
			.. "; set FOREVER_CORE to it (tools/forever-core.txt names the ref)"
	)
end

-- The files ForeverCore.toc lists, in its order, with forward slashes for loadfile.
---@param directory string
---@return string[]
function ForeverCore.files(directory)
	local files = {}
	for line in io.lines(directory .. "/ForeverCore.toc") do
		line = line:gsub("\r$", "")
		if not (line:match("^%s*$") or line:match("^%s*#")) then
			files[#files + 1] = directory .. "/" .. (line:gsub("\\", "/"))
		end
	end
	return files
end

-- ForeverCore as an extra addon for the client simulator: the folder and its addon name, registered next to the
-- one under test so the TOC's dependency resolves to the real checkout.
---@return { [1]: string, [2]: string }[]
function ForeverCore.addons()
	return { { ForeverCore.directory(), "ForeverCore" } }
end

-- Load every file into `env`, each with its own namespace, and return that namespace. The caller fires ForeverCore's
-- ADDON_LOADED afterwards, as the client does before the addon's own.
---@param env table the fake client
---@param name? string the addon folder, "ForeverCore"
---@return table
function ForeverCore.load(env, name)
	local directory = ForeverCore.directory()
	local ns = {}
	for _, path in ipairs(ForeverCore.files(directory)) do
		local chunk = assert(loadfile(path), path)
		setfenv(chunk, env)
		chunk(name or "ForeverCore", ns)
	end
	return ns
end

return ForeverCore
