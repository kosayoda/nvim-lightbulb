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
  autocmd = {
    enabled = false,
    events = { "CursorHold", "CursorHoldI" },
    pattern = { "*" },
  },
  ignore = {},
}

--- Create augroup and autocmd that calls update_lightbulb
--- @param events table: Same as events key in opts param of vim.api.nvim_create_augroup
--- @param pattern table: Same as pattern key in opts param of vim.api.nvim_create_augroup
local _create_autocmd = function(events, pattern)
  -- can be deleted when wished to drop support for versions below 0.7
  if vim.fn.has("nvim-0.7") == 1 then
    local id = vim.api.nvim_create_augroup("LightBulb", {})
    vim.api.nvim_create_autocmd(events, {
      pattern = pattern,
      group = id,
      desc = "lua require('nvim-lightbulb').update_lightbulb()",
      callback = require("nvim-lightbulb").update_lightbulb
    })
  else
    vim.cmd(string.format([[
      augroup LightBulb
              autocmd!
              autocmd %s %s lua require('nvim-lightbulb').update_lightbulb()
      augroup end
    ]] , table.concat(events, ","), table.concat(pattern, ",")))
  end
end

--- Build a configuration based on the `default_opts` and accept overwrites
--- @param opts table: Partial or full configuration opts. Keys: sign, float, virtual_text, status_text, autocmd, ignore
--- @return table
config.build = function(opts)
  opts = opts or {}
  return vim.tbl_deep_extend("force", default_opts, opts)
end

--- Set default configuration
--- @param opts table: Partial or full configuration opts. Keys: sign, float, virtual_text, status_text, autocmd, ignore
config.set_defaults = function(opts)
  local new_opts = config.build(opts)
  default_opts = new_opts

  if default_opts.autocmd.enabled then
    _create_autocmd(default_opts.autocmd.events, default_opts.autocmd.pattern)
  end
end

return config
