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

-- MSNV: 0.9.0
local get_lsp_active_clients = vim.lsp.get_active_clients
local get_lsp_line_diagnostics = function()
  return vim.lsp.diagnostic.get_line_diagnostics(0)
end

local set_win_option = vim.api.nvim_win_set_option

---@param client vim.lsp.Client
---@return fun(method:string, opts?: {bufnr: integer?}):boolean
local supports_method = function(client)
  return client.supports_method
end

if vim.fn.has("nvim-0.10") == 1 then
  get_lsp_active_clients = vim.lsp.get_clients
  set_win_option = function(window, name, value)
    vim.wo[window][0][name] = value
  end
end

if vim.fn.has("nvim-0.11") == 1 then
  get_lsp_line_diagnostics = function()
    local opts = { lnum = vim.api.nvim_win_get_cursor(0)[1] - 1 }
    return vim.lsp.diagnostic.from(vim.diagnostic.get(0, opts))
  end

  supports_method = function(client)
    return function (method, opts)
      return client.supports_method(client, method, opts)
    end
  end
end

local NvimLightbulb = {}

local LIGHTBULB_NS = vim.api.nvim_create_namespace("nvim-lightbulb")

--- Module setup.
---
--- Optional. Any configuration can also be passed to |NvimLightbulb.update_lightbulb|.
---
---@param config nvim-lightbulb.Config|nil Partial or full configuration table. See |nvim-lightbulb-config|.
---
---@usage `require('nvim-lightbulb').setup({})`
NvimLightbulb.setup = function(config)
  _G.NvimLightbulb = NvimLightbulb
  lightbulb_config.set_defaults(config)
end

--- Check for codelenses at the current position.
---
---@param opts table Partial or full configuration table. See |nvim-lightbulb-config|.
---@param position table<string, integer>|nil The position to update the extmark to. If nil, it returns false.
---
---@private
local function is_code_lens(opts, position)
  if not opts.code_lenses or position == nil then
    return false
  end
  local codelens_actions = {}
  for _, l in ipairs(vim.lsp.codelens.get(0)) do
    table.insert(codelens_actions, { start = l.range.start, finish = l.range["end"] })
  end
  for _, action in ipairs(codelens_actions) do
    if
      action.start.line <= position.line
      and position.line <= action.finish.line
      and action.start.character <= position.col
      and position.col <= action.finish.character
    then
      return true
    end
  end
  return false
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
  local sign_text = opts.text
  if is_code_lens(opts, position) then
    sign_text = opts.lens_text
  end
  local _, lightbulb_win = lsp_util.open_floating_preview({ sign_text }, "plaintext", opts.win_opts)
  set_win_option(lightbulb_win, "winhl", "Normal:" .. opts.hl)

  -- Set float transparency
  if opts.win_opts["winblend"] ~= nil then
    set_win_option(lightbulb_win, "winblend", opts.win_opts.winblend)
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

  local sign_text = opts.status_text.text
  if is_code_lens(opts, position) then
    sign_text = opts.status_text.lens_text
  end
  if position == nil then
    vim.b[bufnr].current_lightbulb_status_text = opts.status_text.text_unavailable
  else
    vim.b[bufnr].current_lightbulb_status_text = sign_text
  end
end

-- The following is a variable designed to prevent re-entrancy in the 
-- update_extmark function below.
local in_update_extmark = false
--- Update the lightbulb extmark.
---
---@param opts table Partial or full configuration table. See |nvim-lightbulb-config|.
---@param position table<string, integer>|nil The position to update the extmark to. If nil, removes the extmark.
---@param bufnr integer The buffer to update the float in.
---
---@private
local function update_extmark(opts, position, bufnr)
  -- Guard against re-entrancy.
  if (in_update_extmark) then
      return
  end
  -- Set guard against re-entrancy.
  in_update_extmark = true

  local sign_enabled = opts.sign.enabled
  local virt_text_enabled = opts.virtual_text.enabled

  -- Intended to fix an invalid reference when the buffer number is invalid
  -- for some unknown reason.
  if (vim.b[bufnr] == nil) then
      in_update_extmark = false
      return
  end
  local extmark_id = vim.b[bufnr].lightbulb_extmark
  if not (sign_enabled or virt_text_enabled) or position == nil then
    if extmark_id ~= nil then
      vim.api.nvim_buf_del_extmark(bufnr, LIGHTBULB_NS, extmark_id)
    end
    in_update_extmark = false
    return
  end

  local sign_text = opts.sign.text
  local virtual_text = opts.virtual_text.text
  if is_code_lens(opts, position) then
    sign_text = opts.sign.lens_text
    virtual_text = opts.virtual_text.lens_text
  end

  local extmark_opts = {
    id = extmark_id,
    priority = opts.priority,
    -- If true, breaks empty files
    strict = false,
    -- Sign configuration
    sign_text = sign_enabled and sign_text or nil,
    sign_hl_group = sign_enabled and opts.sign.hl or nil,
    -- Virtual text configuration
    virt_text = virt_text_enabled and { { virtual_text, opts.virtual_text.hl } } or nil,
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

  in_update_extmark = false
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
    ---@param id number The client id of the LSP server
    ---@param name string The client name of the LSP server
    ---@param result lsp.CodeAction | lsp.Command The CodeAction to filter
    ---@return boolean keep True to count the code action, false otherwise
    local filter = function(id, name, result)
      if opts.ignore_id[id] then
        return false
      end

      if opts.ignore.actions_without_kind then
        local found_without_kind = false
        for _, r in pairs(result) do
          if r.kind and r.kind ~= "" then
            found_without_kind = true
            break
          end
        end
        if not found_without_kind then
          return false
        end
      end

      for _, r in pairs(result) do
          if opts.filter and opts.filter(name, r) then
            return true
          end
      end

      return not opts.filter
    end

    -- Check for available code actions from all LSP server responses
    local has_actions = false
    for client_id, resp in pairs(responses) do
      if resp.result and not vim.tbl_isempty(resp.result) then
        if filter(client_id, opts.client_id_to_name[client_id], resp.result) then
          has_actions = true
          break
        end
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
---
---@param config table|nil Partial or full configuration table. See |nvim-lightbulb-config|.
---
---@usage `require('nvim-lightbulb').update_lightbulb({})`
NvimLightbulb.update_lightbulb = function(config)
  local opts = lightbulb_config.build(config, false)
  opts.ignore_id = {}
  opts.client_id_to_name = {}

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
  for _, client in pairs(get_lsp_active_clients({ bufnr = bufnr })) do
    if client and supports_method(client)("textDocument/codeAction") then
      opts.client_id_to_name[client.id] = client.name or "Unknown Client"

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
    -- The cancel function failing here may be due to the client no longer existing,
    -- the server having a bad implementation of the cancel etc.
    -- Failing doesn't affect the lightbulb behavior, so we can ignore the error.
    pcall(vim.b[bufnr].lightbulb_lsp_cancel)
    vim.b[bufnr].lightbulb_lsp_cancel = nil
  end
  local context = { diagnostics = get_lsp_line_diagnostics() }
  context.only = opts.action_kinds

  local params = lsp_util.make_range_params(0, "utf-8")
  params.context = context

  local position = {
    line = params.range.start.line,
    col = params.range.start.character,
  }
  vim.b[bufnr].lightbulb_lsp_cancel = vim.F.npcall(
    vim.lsp.buf_request_all,
    bufnr,
    "textDocument/codeAction",
    params,
    handler_factory(opts, position, bufnr)
  )
end

---
--- Display debug information related to nvim-lightbulb.
--- Prints information about:
--- - The current configuration
--- - LSP servers found, ignored, supporting code actions...
--- - Any code actions at the current location along with their code action kind
---
---@param config table|nil Partial or full configuration table. See |nvim-lightbulb-config|.
---
---@usage `require('nvim-lightbulb').debug({})`
NvimLightbulb.debug = function(config)
  local opts = lightbulb_config.build(config, false)
  opts.ignore_id = {}

  local chunks = {}
  local function append(str, hl)
    table.insert(chunks, { str, hl })
  end
  local function warn(str, hl)
    append("! ", "DiagnosticWarn")
    append(str, hl)
  end
  local function info(str, hl)
    append("i ", "DiagnosticInfo")
    append(str, hl)
  end

  append("[")
  append("Configuration", "Special")
  append("]\n")
  vim.list_extend(chunks, lightbulb_config.pretty_format(opts))
  append("\n")

  append("\n[")
  append("Code Actions", "Special")
  append("]\n")

  local run_code_actions = true

  -- Return if the filetype is ignored
  if vim.tbl_contains(opts.ignore.ft, vim.bo.filetype) then
    warn("Filetype ignored: ")
    append(vim.bo.filetype, "DiagnosticWarn")
    append("\n")
    run_code_actions = false
  end

  -- Key: client.name
  -- Value: true if ignore
  local ignored_clients = {}
  if opts.ignore.clients then
    for _, client in ipairs(opts.ignore.clients) do
      ignored_clients[client] = true
    end
  end

  -- Key: client.id
  -- Value: client.name
  local client_id_to_name = {}

  local bufnr = vim.api.nvim_get_current_buf()

  -- Check for code action capability
  local no_code_action_servers = {}
  local code_action_servers = {}
  local ignored_servers = {}

  for _, client in pairs(get_lsp_active_clients({ bufnr = bufnr })) do
    if client and supports_method(client)("textDocument/codeAction") then
      client_id_to_name[client.id] = client.name

      -- If it is ignored, add the id to the ignore table for the handler
      if ignored_clients[client.name] then
        opts.ignore_id[client.id] = true
        if #ignored_servers > 0 then
          table.insert(ignored_servers, { ", " })
        end
        table.insert(ignored_servers, { client.name })
      else
        -- Otherwise we have found a capable client
        if #code_action_servers > 0 then
          table.insert(code_action_servers, { ", " })
        end
        table.insert(code_action_servers, { client.name })
      end
    else
      if #no_code_action_servers > 0 then
        table.insert(no_code_action_servers, { ", " })
      end
      table.insert(no_code_action_servers, { client.name })
    end
  end

  if not vim.tbl_isempty(no_code_action_servers) then
    info("  No code action support: ")
    vim.list_extend(chunks, no_code_action_servers)
    append("\n")
  end

  if vim.tbl_isempty(code_action_servers) then
    warn("No allowed servers with code action support found\n")
    run_code_actions = false
  else
    info("With code action support: ")
    vim.list_extend(chunks, code_action_servers)
    append("\n")
  end

  if not vim.tbl_isempty(ignored_servers) then
    info("With support but ignored: ")
    vim.list_extend(chunks, ignored_servers)
    append("\n")
  end

  -- Send the LSP request
  local context = { diagnostics = get_lsp_line_diagnostics() }
  context.only = opts.action_kinds

  local params = lsp_util.make_range_params(0, "utf-8")
  params.context = context

  --- Handler for textDocument/codeAction.
  --- Note: This is not an |lsp-handler| because we use vim.lsp.buf_request_all and not vim.lsp.buf_request
  ---
  ---@param responses table Map of client_id:request_result.
  ---@private
  local function code_action_handler(responses)
    local has_actions = false

    for client_id, resp in pairs(responses) do
      if not opts.ignore_id[client_id] and resp.result and not vim.tbl_isempty(resp.result) then
        local client_name = client_id_to_name[client_id] or "Unknown Client"
        append("\n")
        append(client_name, "Title")
        append("\n")

        for idx, r in pairs(resp.result) do
          local has_kind = r.kind and r.kind ~= ""
          append(string.format("%d. %s", idx, r.title))
          if has_kind then
            append(" " .. r.kind, "Comment")
          else
            append(" (no kind)", "Comment")
          end

          if opts.ignore.actions_without_kind and not has_kind then
            append(" [Ignored (actions_without_kind)]", "Error")
          elseif opts.filter and not opts.filter(client_name, r) then
            append(" [Ignored (filter)]", "Error")
          else
            has_actions = true
          end

          append("\n")
        end
      end
    end

    if not has_actions then
      append("\n")
      warn("No valid code actions found")
    end

    append("\n")
    vim.api.nvim_echo(chunks, true, {})
  end

  if run_code_actions then
    vim.lsp.buf_request_all(bufnr, "textDocument/codeAction", params, code_action_handler)
  else
    vim.api.nvim_echo(chunks, true, {})
  end
end

return NvimLightbulb
