--- @class Sessionizer
--- @field config SessionizerConfig
--- @field keymaps SessionizerKeymaps
--- @field hooks SessionizerHooks
local Sessionizer = {}

local function safe_require(mod_name)
	local ok, mod = pcall(require, mod_name)
	if not ok then
		return nil
	end
	return mod
end

--- @param opts table|nil Prepare Sessionizer config table.
--- @return SessionizerConfig
local function prepare_config(opts)
	local config = opts or Sessionizer.config
	if config.keymaps == nil then
		config.keymaps = Sessionizer.keymaps
	end
	if config.keymaps.finder == nil then
		config.keymaps.finder = Sessionizer.keymaps.finder
	end
	if config.keymaps.detach == nil then
		config.keymaps.detach = Sessionizer.keymaps.detach
	end
	if config.project_sources == nil then
		config.project_sources = Sessionizer.config.project_sources
	end
	if config.session_dir == nil then
		config.session_dir = Sessionizer.config.session_dir
	end
	if config.hooks == nil then
		config.hooks = Sessionizer.hooks
	end
	return config
end

--- @class SessionizerConfig
--- @field keymaps SessionizerKeymaps
--- @field project_sources string[]
--- @field session_dir string
--- @field hooks SessionizerHooks
Sessionizer.config = {
	-- Sessionizer keymaps
	keymaps = Sessionizer.keymaps,
	-- List of directories to source project names from.
	project_sources = {},
	-- Base directory to store session pipes in.
	session_dir = "/tmp",
	-- Sessionizer hooks
	hooks = Sessionizer.hooks,
}

--- @class SessionizerKeymaps
--- @field finder string
--- @field detach string
Sessionizer.keymaps = {
	-- Telescope fuzzy finder runs on this keybind
	finder = "<leader><S-F>",
	-- :detach runs on this keybind
	detach = "<leader>d",
}

--- @class SessionizerHooks
--- @field pre_connect_hook fun() | nil
--- @field post_connect_hook fun() | nil
--- @field pre_detach_hook fun() | nil
--- @field post_detach_hook fun() | nil
Sessionizer.hooks = {
	pre_connect_hook = nil,
	post_connect_hook = nil,
	pre_detach_hook = nil,
	post_detach_hook = nil,
}

--- Sessionizer setup
--- @param opts table|nil Sessionizer config table.
Sessionizer.setup = function(opts)
	if vim.fn.has("nvim-0.12") == 0 then
		vim.notify("sessionizer.nvim requires at least Nvim 0.12", vim.log.levels.ERROR)
		return
	end

	local pickers = safe_require("telescope.pickers")
	local finders = safe_require("telescope.finders")
	local conf = safe_require("telescope.config").values
	local actions = safe_require("telescope.actions")
	local action_state = safe_require("telescope.actions.state")
	if pickers == nil or finders == nil or conf == nil or actions == nil or action_state == nil then
		vim.notify("sessionizer.nvim requires telescope.nvim", vim.log.levels.ERROR)
		return
	end

	--- @type SessionizerConfig
	local config = prepare_config(opts)
	--- @type string[]
	local project_sources = {}
	if config.project_sources == nil or #config.project_sources == 0 then
		goto skip_sourcing
	end
	for _, source in ipairs(config.project_sources) do
		table.insert(project_sources, vim.fn.expand(source))
	end
	::skip_sourcing::

	local uv = vim.uv or vim.loop

	local projects = {}
	local project_names = {}
	for _, project_source in ipairs(project_sources) do
		local handle = uv.fs_opendir(project_source, nil, 1)
		if handle == nil then
			vim.notify("could not open directory: " .. project_source, vim.log.levels.ERROR)
			goto continue
		end
		while true do
			local entries = uv.fs_readdir(handle)
			if entries == nil then
				break
			end
			if #entries == 0 then
				break
			end

			for _, entry in ipairs(entries) do
				if entry.type ~= "directory" then
					-- There is only one entry in the directory, so break
					break
				end
				local project_source_suffix = (function()
					if string.reverse(project_source):sub(1, 1) == "/" then
						return ""
					end
					return "/"
				end)()
				projects[entry.name] = project_source .. project_source_suffix .. entry.name
				table.insert(project_names, entry.name)
			end
		end
		handle:closedir()
		::continue::
	end

	vim.keymap.set("n", config.keymaps.finder, function()
		pickers
			.new({}, {
				prompt_title = "Projects",
				finder = finders.new_table({
					results = project_names,
				}),
				sorter = conf.generic_sorter({}),
				attach_mappings = function()
					actions.select_default:replace(function(prompt_bufnr)
						local selection = action_state.get_selected_entry()
						actions.close(prompt_bufnr)

						vim.schedule(function()
							if not selection then
								return
							end

							local project_name = selection.value
							local socket_suffix = "-nvim.sock"
							local must_detach_old = string.find(vim.api.nvim_get_vvar("servername"), socket_suffix)
								== nil
							local full_project_name = projects[project_name]
							local base_dir_suffix = (function()
								if string.reverse(config.session_dir):sub(1, 1) == "/" then
									return ""
								end
								return "/"
							end)()
							local socket = config.session_dir .. base_dir_suffix .. project_name .. socket_suffix

							if not uv.fs_stat(socket) then
								-- Spawn NEW nvim instance with server
								vim.fn.jobstart({
									"nvim",
									"--listen",
									socket,
									"--headless",
									"-c",
									"cd " .. full_project_name,
								}, { detach = true })
							end

							-- Small delay to allow server to start
							vim.defer_fn(function()
								if config.hooks.pre_connect_hook then
									config.hooks.pre_connect_hook()
								end
								if must_detach_old then
									vim.cmd("connect! " .. socket)
								else
									vim.cmd("connect " .. socket)
								end
								if config.hooks.post_connect_hook then
									config.hooks.post_connect_hook()
								end
							end, 100)
						end)
					end)
					return true
				end,
			})
			:find()
	end, { desc = "Sessionizer - Switch to project" })

	vim.keymap.set("n", config.keymaps.detach, function()
		if config.hooks.pre_detach_hook then
			config.hooks.pre_detach_hook()
		end
		vim.cmd.detach()
		if config.hooks.post_detach_hook then
			config.hooks.post_detach_hook()
		end
	end, { desc = "Sessionizer - Detach from project" })
end

return Sessionizer
