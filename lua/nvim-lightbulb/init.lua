---
--- *nvim-lightbulb*: VSCode 💡 for neovim's built-in LSP.
---
--- --- Quickstart ---
---
--- Place this in your neovim configuration.
--- >
---   require("nvim-lightbulb").setup({
---     autocmd = { enabled = true }
---   })
---
--- See |nvim-lightbulb-config| for available config settings.
---
---
--- --- Modify Highlights ---
---
--- To modify highlights, configure the corresponding highlight group.
--- See |nvim-lightbulb-config| for a list of highlights used.
---
--- Example:
--- >
---    vim.api.nvim_set_hl(0, "LightBulbSign", {link = "DiagnosticSignWarn"})
---@tag nvim-lightbulb

local lsp_util = require("vim.lsp.util")
local lightbulb_config = require("nvim-lightbulb.config")

local NvimLightbulb = {}

local LIGHTBULB_NS = vim.api.nvim_create_namespace("nvim-lightbulb")

--- Module setup.
---
--- Optional. Any configuration can also be passed to |NvimLightbulb.update_lightbulb|.
---
---@param config table|nil Partial or full configuration table. See |nvim-lightbulb-config|.
---
---@usage `require('nvim-lightbulb').setup({})`
NvimLightbulb.setup = function(config)
  _G.NvimLightbulb = NvimLightbulb
  lightbulb_config.set_defaults(config)
end

--- Update the lightbulb float.
---
---@param opts table Partial or full configuration table. See |nvim-lightbulb-config|.
---@param position table<string, integer>|nil The position to update the extmark to. If nil, removes the extmark.
---@param bufnr integer The buffer to update the float in.
---
---@private
local function update_float(opts, position, bufnr)
  -- Extract float options
  opts = opts.float

  if not opts.enabled or position == nil then
    return
  end

  -- Prevent `open_floating_preview` from closing the previous floating window
  -- Cache the value to restore it later
  local lsp_win = vim.b[bufnr].lsp_floating_preview
  vim.b[bufnr].lsp_floating_preview = nil

  -- Check if another lightbulb floating window already exists for this buffer and close it
  local existing_float = vim.b[bufnr].lightbulb_floating_window
  if existing_float and vim.api.nvim_win_is_valid(existing_float) then
    vim.api.nvim_win_close(existing_float, true)
  end

  -- Open the window and set highlight
  local _, lightbulb_win = lsp_util.open_floating_preview({ opts.text }, "plaintext", opts.win_opts)
  vim.api.nvim_win_set_option(lightbulb_win, "winhl", "Normal:" .. opts.hl)

  -- Set float transparency
  if opts.win_opts["winblend"] ~= nil then
    vim.api.nvim_win_set_option(lightbulb_win, "winblend", opts.win_opts.winblend)
  end

  vim.b[bufnr].lightbulb_floating_window = lightbulb_win
  vim.b[bufnr].lsp_floating_preview = lsp_win
end

--- Update the lightbulb status text.
---
---@param opts table Partial or full configuration table. See |nvim-lightbulb-config|.
---@param position table<string, integer>|nil The position to update the extmark to. If nil, removes the extmark.
---@param bufnr integer The buffer to update the float in.
---
---@private
local function update_status_text(opts, position, bufnr)
  if not opts.status_text.enabled then
    return
  end

  if position == nil then
    vim.b[bufnr].current_lightbulb_status_text = opts.status_text.text_unavailable
  else
    vim.b[bufnr].current_lightbulb_status_text = opts.status_text.text
  end
end

--- Update the lightbulb extmark.
---
---@param opts table Partial or full configuration table. See |nvim-lightbulb-config|.
---@param position table<string, integer>|nil The position to update the extmark to. If nil, removes the extmark.
---@param bufnr integer The buffer to update the float in.
---
---@private
local function update_extmark(opts, position, bufnr)
  local sign_enabled = opts.sign.enabled
  local virt_text_enabled = opts.virtual_text.enabled

  local extmark_id = vim.b[bufnr].lightbulb_extmark
  if not (sign_enabled or virt_text_enabled) or position == nil then
    if extmark_id ~= nil then
      vim.api.nvim_buf_del_extmark(bufnr, LIGHTBULB_NS, extmark_id)
    end
    return
  end

  local extmark_opts = {
    id = extmark_id,
    priority = opts.priority,
    -- If true, breaks empty files
    strict = false,
    -- Sign configuration
    sign_text = sign_enabled and opts.sign.text or nil,
    sign_hl_group = sign_enabled and opts.sign.hl or nil,
    -- Virtual text configuration
    virt_text = virt_text_enabled and { { opts.virtual_text.text, opts.virtual_text.hl } } or nil,
    virt_text_pos = (virt_text_enabled and type(opts.virtual_text.pos) == "string") and opts.virtual_text.pos or nil,
    virt_text_win_col = (virt_text_enabled and type(opts.virtual_text.pos) == "number") and opts.virtual_text.pos
      or nil,
    hl_mode = virt_text_enabled and opts.virtual_text.hl_mode or nil,
    -- Number configuration
    number_hl_group = opts.number.enabled and opts.number.hl or nil,
    -- Line configuration
    line_hl_group = opts.line.enabled and opts.line.hl or nil,
  }
  vim.b[bufnr].lightbulb_extmark =
    vim.api.nvim_buf_set_extmark(bufnr, LIGHTBULB_NS, position.line, position.col + 1, extmark_opts)
end

--- Handler factory to keep track of current lightbulb line.
---
---@param opts table Options passed when `update_lightbulb` is called
---@param position table Position of the cursor when lightbulb is called, like {line = 0, col = 0}
---@param bufnr number Buffer handle
---
---@private
local function handler_factory(opts, position, bufnr)
  --- Handler for textDocument/codeAction.
  --- Note: This is not an |lsp-handler| because we use vim.lsp.buf_request_all and not vim.lsp.buf_request
  ---
  ---@param responses table Map of client_id:request_result.
  ---@private
  local function code_action_handler(responses)
    -- Check for available code actions from all LSP server responses
    local has_actions = false
    for client_id, resp in pairs(responses) do
      if resp.result and not opts.ignore_id[client_id] and not vim.tbl_isempty(resp.result) then
        has_actions = true
        break
      end
    end

    local pos = has_actions and position or nil
    update_extmark(opts, pos, bufnr)
    update_status_text(opts, pos, bufnr)
    update_float(opts, pos, bufnr)
  end

  return code_action_handler
end

---
--- Get the configured text according to lightbulb status.
--- Any configuration provided overrides the defaults passed to |NvimLightbulb.setup|.
---
---@param bufnr number|nil Buffer handle. Defaults to current buffer.
---
---@usage `require('nvim-lightbulb').get_status_text()`
NvimLightbulb.get_status_text = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return vim.F.npcall(vim.api.nvim_buf_get_var, bufnr, "current_lightbulb_status_text") or ""
end

NvimLightbulb.clear_lightbulb = function(bufnr)
  local extmark_id = vim.b[bufnr].lightbulb_extmark
  if extmark_id ~= nil then
    vim.api.nvim_buf_del_extmark(bufnr, LIGHTBULB_NS, extmark_id)
  end
end

---
--- Display the lightbulb according to configuration.
--- Any configuration provided overrides the defaults passed to |NvimLightbulb.setup|.
---
---@param config table|nil Partial or full configuration table. See |nvim-lightbulb-config|.
---
---@usage `require('nvim-lightbulb').update_lightbulb({})`
NvimLightbulb.update_lightbulb = function(config)
  local opts = lightbulb_config.build(config, false)
  opts.ignore_id = {}

  -- Return if the filetype is ignored
  if vim.tbl_contains(opts.ignore.ft, vim.bo.filetype) then
    return
  end

  -- Key: client.name
  -- Value: true if ignore
  local ignored_clients = {}
  if opts.ignore.clients then
    for _, client in ipairs(opts.ignore.clients) do
      ignored_clients[client] = true
    end
  end

  local bufnr = vim.api.nvim_get_current_buf()

  -- Check for code action capability
  local code_action_cap_found = false
  for _, client in pairs(vim.lsp.get_active_clients({ bufnr = bufnr })) do
    if client and client.supports_method("textDocument/codeAction") then
      -- If it is ignored, add the id to the ignore table for the handler
      if ignored_clients[client.name] then
        opts.ignore_id[client.id] = true
      else
        -- Otherwise we have found a capable client
        code_action_cap_found = true
      end
    end
  end
  if not code_action_cap_found then
    return
  end

  -- Send the LSP request, canceling the previous one if necessary
  if vim.b[bufnr].lightbulb_lsp_cancel then
    vim.b[bufnr].lightbulb_lsp_cancel()
  end
  local context = { diagnostics = vim.lsp.diagnostic.get_line_diagnostics() }
  context.only = opts.action_kinds

  local params = lsp_util.make_range_params()
  params.context = context
  local position = {
    line = params.range.start.line,
    col = params.range.start.character,
  }
  vim.b[bufnr].lightbulb_lsp_cancel =
    vim.lsp.buf_request_all(bufnr, "textDocument/codeAction", params, handler_factory(opts, position, bufnr))
end

return NvimLightbulb
