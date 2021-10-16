local vim = vim
local lsp_util = require("vim.lsp.util")
local M = {}

local SIGN_GROUP = "nvim-lightbulb"
local SIGN_NAME = "LightBulbSign"
local LIGHTBULB_FLOAT_HL = "LightBulbFloatWin"
local LIGHTBULB_VIRTUAL_TEXT_HL = "LightBulbVirtualText"
local LIGHTBULB_VIRTUAL_TEXT_NS = vim.api.nvim_create_namespace("nvim-lightbulb")

-- Set default sign
if vim.tbl_isempty(vim.fn.sign_getdefined(SIGN_NAME)) then
    vim.fn.sign_define(SIGN_NAME, { text = "💡", texthl = "LspDiagnosticsDefaultInformation" })
end

--- Update lightbulb float.
---
--- @param opts table Available options for the float handler
--- @param bufnr number|nil Buffer handle
---
--- @private
local function _update_float(opts, bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    -- prevent `open_floating_preview` close the previous floating window
    vim.api.nvim_buf_set_var(bufnr, "lsp_floating_preview", nil)

    -- check if another lightbulb floating window already exists for this buffer
    -- and close it if needed
    local existing_float = vim.F.npcall(vim.api.nvim_buf_get_var, bufnr, "lightbulb_floating_window")
    if existing_float and vim.api.nvim_win_is_valid(existing_float) then
      vim.api.nvim_win_close(existing_float, true)
    end

    local _, win = lsp_util.open_floating_preview({ opts.text }, "plaintext", opts.win_opts)
    vim.api.nvim_win_set_option(win, "winhl", "Normal:" .. LIGHTBULB_FLOAT_HL)

    -- Manually anchor float because `open_floating_preview` doesn't support that option
    if opts.win_opts["anchor"] ~= nil then
        vim.api.nvim_win_set_config(win, { anchor = opts.win_opts.anchor })
    end

    if opts.win_opts["winblend"] ~= nil then
        vim.api.nvim_win_set_option(win, "winblend", opts.win_opts.winblend)
    end

    vim.api.nvim_buf_set_var(bufnr, "lightbulb_floating_window", win)
end

--- Update sign position from `old_line` to `new_line`.
---
--- Either line can be optional, and will result in just adding/removing
--- the sign on the given line.
---
--- @param priority number The priority of the sign to add
--- @param old_line number|nil The line to remove the sign on
--- @param new_line number|nil The line to add the sign on
--- @param bufnr number|nil Buffer handle
---
--- @private
local function _update_sign(priority, old_line, new_line, bufnr)
    bufnr = bufnr or "%"

    if old_line then
        vim.fn.sign_unplace(
            SIGN_GROUP, { id = old_line, buffer = bufnr }
        )

        -- Update current lightbulb line
        vim.b.lightbulb_line = nil
    end

    -- Avoid redrawing lightbulb if code action line did not change
    if new_line and (vim.b.lightbulb_line ~= new_line) then
        vim.fn.sign_place(
            new_line, SIGN_GROUP, SIGN_NAME, bufnr,
            { lnum = new_line, priority = priority }
        )
        -- Update current lightbulb line
        vim.b.lightbulb_line = new_line
    end
end

--- Update lightbulb virtual text.
---
--- @param opts table Available options for the virtual text handler
--- @param line number|nil The line to add the virtual text
--- @param bufnr number|nil Buffer handle
---
--- @private
local function _update_virtual_text(opts, line, bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(bufnr, LIGHTBULB_VIRTUAL_TEXT_NS, 0, -1)

    if line then
        vim.api.nvim_buf_set_extmark(
            bufnr, LIGHTBULB_VIRTUAL_TEXT_NS, line, -1, { virt_text = {{ opts.text, LIGHTBULB_VIRTUAL_TEXT_HL }}, hl_mode = opts.hl_mode }
        )
    end
end

--- Update lightbulb status text
---
--- @param text string The new status text
--- @param bufnr number|nil Buffer handle
---
local function _update_status_text(text, bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_var(bufnr, 'current_lightbulb_status_text', text)
end


--- Patch for breaking neovim master update to LSP handlers
--- See: https://github.com/neovim/neovim/issues/14090#issuecomment-913198455
local function mk_handler(fn)
  return function(...)
    local config_or_client_id = select(4, ...)
    local is_new = type(config_or_client_id) ~= 'number'
    if is_new then
      fn(...)
    else
      local err = select(1, ...)
      local method = select(2, ...)
      local result = select(3, ...)
      local client_id = select(4, ...)
      local bufnr = select(5, ...)
      local config = select(6, ...)
      fn(err, result, { method = method, client_id = client_id, bufnr = bufnr }, config)
    end
  end
end

--- Handler factory to keep track of current lightbulb line.
---
--- @param line number The line when the the code action request is called
--- @param opts table Options passed when `update_lightbulb` is called
--- @param bufnr number|nil Buffer handle
--- @private
local function handler_factory(opts, line, bufnr)
    --- Handler for textDocument/codeAction.
    ---
    --- See lsp-handler for more information.
    ---
    --- @private
    local function code_action_handler(err, actions)
        -- The request returns an error
        if err then
            return
        end
        -- No available code actions
        if actions == nil or vim.tbl_isempty(actions) then
            if opts.sign.enabled then
                _update_sign(opts.sign.priority, vim.b.lightbulb_line, nil, bufnr)
            end
            if opts.virtual_text.enabled then
                _update_virtual_text(opts.virtual_text, nil, bufnr)
            end
            if opts.status_text.enabled then
                _update_status_text(opts.status_text.text_unavailable, bufnr)
            end
        else
            if opts.sign.enabled then
                _update_sign(opts.sign.priority, vim.b.lightbulb_line, line + 1, bufnr)
            end

            if opts.float.enabled then
                _update_float(opts.float, bufnr)
            end

            if opts.virtual_text.enabled then
                _update_virtual_text(opts.virtual_text, line, bufnr)
            end

            if opts.status_text.enabled then
                _update_status_text(opts.status_text.text, bufnr)
            end
        end

    end

    return mk_handler(code_action_handler)
end

M.get_status_text = function(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    return vim.F.npcall(vim.api.nvim_buf_get_var, bufnr, "current_lightbulb_status_text") or ""
end

M.update_lightbulb = function(config)
    -- Check for code action capability
    local code_action_cap_found = false
    for _, client in ipairs(vim.lsp.buf_get_clients()) do
        if client.supports_method("textDocument/codeAction") then
            code_action_cap_found = true
            break
        end
    end
    if not code_action_cap_found then
        return
    end

    config = config or {}
    local opts = {
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
            hl_mode = "replace"
        },
        status_text = {
            enabled = false,
            text = "💡",
            text_unavailable = ""
        }
    }

    -- Backwards compatibility
    opts.sign.priority = config.sign_priority or opts.sign.priority

    -- Sign configuration
    for k, v in pairs(config.sign or {}) do
        opts.sign[k] = v
    end

    -- Float configuration
    for k, v in pairs(config.float or {}) do
        opts.float[k] = v
    end

    -- Virtual text configuration
    for k, v in pairs(config.virtual_text or {}) do
        opts.virtual_text[k] = v
    end

    -- Status text configuration
    for k, v in pairs(config.status_text or {}) do
        opts.status_text[k] = v
    end

    local context = { diagnostics = vim.lsp.diagnostic.get_line_diagnostics() }
    local params = lsp_util.make_range_params()
    params.context = context
    local bufnr = vim.api.nvim_get_current_buf()
    vim.lsp.buf_request(
        0, 'textDocument/codeAction', params, handler_factory(opts, params.range.start.line, bufnr)
    )
end

return M
