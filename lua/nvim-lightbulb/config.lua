local config = {}

local default_opts = {
	sign = {
		enabled = true,
		priority = 10,
	},
	float = {
		enabled = false,
		text = "💡",
		win_opts = {},
	},
	virtual_text = {
		enabled = false,
		text = "💡",
		hl_mode = "replace",
	},
	status_text = {
		enabled = false,
		text = "💡",
		text_unavailable = "",
	},
	ignore = {},
}

--- Build a configuration based on the `default_opts` and accept overwrites
--- @param opts table: Partial or full configuration opts. Keys: sign, float, virtual_text, status_text, ignore
--- @return table
config.build = function(opts)
	opts = opts or {}
	return vim.tbl_deep_extend("force", default_opts, opts)
end

--- Set default configuration
--- @param opts table: Partial or full configuration opts. Keys: sign, float, virtual_text, status_text, ignore
config.set_defaults = function(opts)
	local new_opts = config.build(opts)
	default_opts = new_opts
end

return config
