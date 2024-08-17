local M = {}

---
--- Pass the configuration to |NvimLightbulb.setup| or |NvimLightbulb.update_lightbulb|.
---
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
---@tag nvim-lightbulb-config
local default_config = {
  -- Priority of the lightbulb for all handlers except float.
  priority = 10,

  -- Whether or not to hide the lightbulb when the buffer is not focused.
  -- Only works if configured during NvimLightbulb.setup
  hide_in_unfocused_buffer = true,

  -- Whether or not to link the highlight groups automatically.
  -- Default highlight group links:
  --   LightBulbSign -> DiagnosticSignInfo
  --   LightBulbFloatWin -> DiagnosticFloatingInfo
  --   LightBulbVirtualText -> DiagnosticVirtualTextInfo
  --   LightBulbNumber -> DiagnosticSignInfo
  --   LightBulbLine -> CursorLine
  -- Only works if configured during NvimLightbulb.setup
  link_highlights = true,

  -- Perform full validation of configuration.
  -- Available options: "auto", "always", "never"
  --   "auto" only performs full validation in NvimLightbulb.setup.
  --   "always" performs full validation in NvimLightbulb.update_lightbulb as well.
  --   "never" disables config validation.
  validate_config = "auto",

  -- Code action kinds to observe.
  -- To match all code actions, set to `nil`.
  -- Otherwise, set to a table of kinds.
  -- Example: { "quickfix", "refactor.rewrite" }
  -- See: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#codeActionKind
  action_kinds = nil,

  -- Enable code lens support.
  -- If the current position has executable code lenses, the icon is changed from `text` to `lens_text`
  -- for sign, virtual_text, float and status_text.
  -- The code lens icon is configurable per handler.
  code_lenses = false,

  -- Configuration for various handlers:
  -- 1. Sign column.
  sign = {
    enabled = true,
    -- Text to show in the sign column.
    -- Must be between 1-2 characters.
    text = "💡",
    lens_text = "🔎",
    -- Highlight group to highlight the sign column text.
    hl = "LightBulbSign",
  },

  -- 2. Virtual text.
  virtual_text = {
    enabled = false,
    -- Text to show in the virt_text.
    text = "💡",
    lens_text = "🔎",
    -- Position of virtual text given to |nvim_buf_set_extmark|.
    -- Can be a number representing a fixed column (see `virt_text_pos`).
    -- Can be a string representing a position (see `virt_text_win_col`).
    pos = "eol",
    -- Highlight group to highlight the virtual text.
    hl = "LightBulbVirtualText",
    -- How to combine other highlights with text highlight.
    -- See `hl_mode` of |nvim_buf_set_extmark|.
    hl_mode = "combine",
  },

  -- 3. Floating window.
  float = {
    enabled = false,
    -- Text to show in the floating window.
    text = "💡",
    lens_text = "🔎",
    -- Highlight group to highlight the floating window.
    hl = "LightBulbFloatWin",
    -- Window options.
    -- See |vim.lsp.util.open_floating_preview| and |nvim_open_win|.
    -- Note that some options may be overridden by |open_floating_preview|.
    win_opts = {
      focusable = false,
    },
  },

  -- 4. Status text.
  -- When enabled, will allow using |NvimLightbulb.get_status_text|
  -- to retrieve the configured text.
  status_text = {
    enabled = false,
    -- Text to set if a lightbulb is available.
    text = "💡",
    lens_text = "🔎",
    -- Text to set if a lightbulb is unavailable.
    text_unavailable = "",
  },

  -- 5. Number column.
  number = {
    enabled = false,
    -- Highlight group to highlight the number column if there is a lightbulb.
    hl = "LightBulbNumber",
  },

  -- 6. Content line.
  line = {
    enabled = false,
    -- Highlight group to highlight the line if there is a lightbulb.
    hl = "LightBulbLine",
  },

  -- Autocmd configuration.
  -- If enabled, automatically defines an autocmd to show the lightbulb.
  -- If disabled, you will have to manually call |NvimLightbulb.update_lightbulb|.
  -- Only works if configured during NvimLightbulb.setup
  autocmd = {
    -- Whether or not to enable autocmd creation.
    enabled = false,
    -- See |updatetime|.
    -- Set to a negative value to avoid setting the updatetime.
    updatetime = 200,
    -- See |nvim_create_autocmd|.
    events = { "CursorHold", "CursorHoldI" },
    -- See |nvim_create_autocmd| and |autocmd-pattern|.
    pattern = { "*" },
  },

  -- Scenarios to not show a lightbulb.
  ignore = {
    -- LSP client names to ignore.
    -- Example: {"null-ls", "lua_ls"}
    clients = {},
    -- Filetypes to ignore.
    -- Example: {"neo-tree", "lua"}
    ft = {},
    -- Ignore code actions without a `kind` like refactor.rewrite, quickfix.
    actions_without_kind = false,
  },
}

--- Build a configuration based on the default configuration and accept overwrites.
---
---@param config table|nil Partial or full configuration table. See |nvim-lightbulb-config|.
---@param is_setup boolean Whether or not the command is called during setup.
---@return table
---
---@private
M.build = function(config, is_setup)
  config = config or {}
  vim.validate({ config = { config, "table" } })

  config = vim.tbl_deep_extend("force", default_config, config)

  local validate = config.validate_config
  vim.validate({
    ["config.validate_config"] = {
      validate,
      function(c)
        return c == "auto" or c == "always" or c == "never"
      end,
    },
  })
  if validate == "never" or (validate == "auto" and not is_setup) then
    return config
  end

  -- Validate config
  vim.validate({
    hide_in_unfocused_buffer = { config.hide_in_unfocused_buffer, "boolean" },
    link_highlights = { config.link_highlights, "boolean" },
    action_kinds = { config.action_kinds, "table", true },
    code_lenses = { config.code_lenses, "boolean" },
    sign = { config.sign, "table" },
    virtual_text = { config.virtual_text, "table" },
    float = { config.float, "table" },
    status_text = { config.status_text, "table" },
    number = { config.number, "table" },
    line = { config.line, "table" },
    autocmd = { config.autocmd, "table" },
    ignore = { config.ignore, "table" },
  })

  vim.validate({
    ["sign.enabled"] = { config.sign.enabled, "boolean" },
    ["sign.text"] = { config.sign.text, "string" },
    ["sign.hl"] = { config.sign.hl, "string" },
    ["virtual_text.enabled"] = { config.virtual_text.enabled, "boolean" },
    ["virtual_text.text"] = { config.virtual_text.text, "string" },
    ["virtual_text.pos"] = { config.virtual_text.pos, { "string", "number" } },
    ["virtual_text.hl"] = { config.virtual_text.hl, "string" },
    ["virtual_text.hl_mode"] = { config.virtual_text.hl_mode, "string" },
    ["float.enabled"] = { config.float.enabled, "boolean" },
    ["float.text"] = { config.float.text, "string" },
    ["float.hl"] = { config.float.hl, "string" },
    ["float.win_opts"] = { config.float.win_opts, "table" },
    ["status_text.enabled"] = { config.status_text.enabled, "boolean" },
    ["status_text.text"] = { config.status_text.text, "string" },
    ["status_text.text_unavailable"] = { config.status_text.text_unavailable, "string" },
    ["number.enabled"] = { config.number.enabled, "boolean" },
    ["number.hl"] = { config.number.hl, "string" },
    ["line.enabled"] = { config.line.enabled, "boolean" },
    ["line.hl"] = { config.line.hl, "string" },
    ["autocmd.enabled"] = { config.autocmd.enabled, "boolean" },
    ["autocmd.updatetime"] = { config.autocmd.updatetime, "number" },
    ["autocmd.events"] = { config.autocmd.events, "table" },
    ["autocmd.pattern"] = { config.autocmd.pattern, "table" },
    ["ignore.clients"] = { config.ignore.clients, "table" },
    ["ignore.ft"] = { config.ignore.ft, "table" },
    ["ignore.actions_without_kind"] = { config.ignore.actions_without_kind, "boolean" },
  })

  return config
end

--- Set default configuration. Prefer |NvimLightbulb.setup| instead.
---
---@param opts table|nil Partial or full configuration table. See |nvim-lightbulb-config|.
---
---@private
M.set_defaults = function(opts)
  local new_opts = M.build(opts, true)
  default_config = new_opts

  local id = vim.api.nvim_create_augroup("LightBulb", {})
  -- Set up autocmd for update_lightbulb if configured
  if default_config.autocmd.enabled then
    if default_config.autocmd.updatetime > 0 then
      vim.opt.updatetime = default_config.autocmd.updatetime
    end

    vim.api.nvim_create_autocmd(default_config.autocmd.events, {
      pattern = default_config.autocmd.pattern,
      group = id,
      desc = "lua require('nvim-lightbulb').update_lightbulb()",
      callback = require("nvim-lightbulb").update_lightbulb,
    })
  end

  -- Set up autocmd for clear_lightbulb if configured
  if default_config.hide_in_unfocused_buffer then
    vim.api.nvim_create_autocmd({ "WinLeave" }, {
      pattern = { "*" },
      group = id,
      desc = "lua require('nvim-lightbulb').clear_lightbulb()",
      callback = function(args)
        require("nvim-lightbulb").clear_lightbulb(args.buf)
      end,
    })
  end

  -- Set up default highlight links
  if default_config.link_highlights then
    vim.api.nvim_set_hl(0, "LightBulbSign", { default = true, link = "DiagnosticSignInfo" })
    vim.api.nvim_set_hl(0, "LightBulbFloatWin", { default = true, link = "DiagnosticFloatingInfo" })
    vim.api.nvim_set_hl(0, "LightBulbVirtualText", { default = true, link = "DiagnosticVirtualTextInfo" })
    vim.api.nvim_set_hl(0, "LightBulbNumber", { default = true, link = "DiagnosticSignInfo" })
    vim.api.nvim_set_hl(0, "LightBulbLine", { default = true, link = "CursorLine" })
  end
end

--- Get a prettified representation of the config in a format suitable for |nvim_echo|.
---
---@param opts table Configuration table. See |nvim-lightbulb-config|.
---@return table # The prettified configuration
---
---@private
M.pretty_format = function(opts)
  local lines = {}

  local F = {}

  F.append = function(str, hl)
    table.insert(lines, { str, hl })
  end

  F.format = function(value, indent, prefix)
    indent = indent or 0
    if prefix then
      F.append(prefix)
    end

    if type(value) == "string" then
      F.append(string.format("'%s'", value), "String")
    elseif type(value) == "number" then
      F.append(tostring(value), "Number")
    elseif type(value) == "boolean" then
      F.append(tostring(value), "Boolean")
    elseif type(value) == "nil" then
      F.append("nil", "Keyword")
    elseif type(value) == "table" then
      if vim.tbl_isempty(value) then
        F.append("{}")
      else
        if vim.tbl_islist(value) then
          F.format_list(value)
        else
          F.format_table(value, indent + 2)
        end
      end
    else
      F.append(string.format("<%s>", type(value)))
    end
  end

  F.format_list = function(t)
    F.append("{ ")
    for idx, value in ipairs(t) do
      if idx ~= 1 then
        F.append(", ")
      end
      F.format(value)
    end
    F.append(" }")
  end

  F.format_table = function(t, indent)
    indent = indent or 0

    local idx = 0

    local is_long = vim.tbl_count(t) > 3
    local prefix = is_long and string.rep(" ", indent) or ""
    local suffix = is_long and "\n" or " "

    F.append("{" .. suffix)

    for key, value in pairs(t) do
      if idx ~= 0 then
        F.append("," .. suffix)
      end

      idx = idx + 1

      F.append(prefix .. key)
      F.append(" = ", "Operator")
      F.format(value, indent)
    end

    prefix = is_long and string.rep(" ", indent - 2) or ""
    F.append(suffix .. prefix .. "}")
  end

  F.format(opts)
  return lines
end

return M
