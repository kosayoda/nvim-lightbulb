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
---
--- @private
local function _update_float(opts)
    local _, win = lsp_util.open_floating_preview({ opts.text }, "plaintext", opts.win_opts)
    vim.api.nvim_win_set_option(win, "winhl", "Normal:" .. LIGHTBULB_FLOAT_HL)

    -- Manually anchor float because `open_floating_preview` doesn't support that option
    if opts.win_opts["anchor"] ~= nil then
        vim.api.nvim_win_set_config(win, { anchor = opts.win_opts.anchor })
    end

    if opts.win_opts["winblend"] ~= nil then
        vim.api.nvim_win_set_option(win, "winblend", opts.win_opts.winblend)
    end
end

--- Update sign position from `old_line` to `new_line`.
---
--- Either line can be optional, and will result in just adding/removing
--- the sign on the given line.
---
--- @param priority number The priority of the sign to add
--- @param old_line number|nil The line to remove the sign on
--- @param new_line number|nil The line to add the sign on
---
--- @private
local function _update_sign(priority, old_line, new_line)
    if old_line then
        vim.fn.sign_unplace(
            SIGN_GROUP, { id = old_line, buffer = "%" }
        )

        -- Update current lightbulb line
        vim.b.lightbulb_line = nil
    end

    -- Avoid redrawing lightbulb if code action line did not change
    if new_line and (vim.b.lightbulb_line ~= new_line) then
        vim.fn.sign_place(
            new_line, SIGN_GROUP, SIGN_NAME, "%",
            { lnum = new_line, priority = priority }
        )
        -- Update current lightbulb line
        vim.b.lightbulb_line = new_line
    end
end

--- Update lightbulb virtual text.
---
--- @param text string The text of virtual text
--- @param line number|nil The line to add the virtual text
---
--- @private
local function _update_virtual_text(text, line)
    vim.api.nvim_buf_clear_namespace(0, LIGHTBULB_VIRTUAL_TEXT_NS, 0, -1)

    if line then
        vim.api.nvim_buf_set_virtual_text(
            0, LIGHTBULB_VIRTUAL_TEXT_NS, line, {{text, LIGHTBULB_VIRTUAL_TEXT_HL}}, {}
        )
    end
end

--- Update lightbulb status text
--- 
--- @param text string The new status text
---
local function _update_status_text(text)
    vim.b.current_lightbulb_status_text = text
end

--- Handler factory to keep track of current lightbulb line.
---
--- @param line number The line when the the code action request is called
--- @param opts table Options passed when `update_lightbulb` is called
--- @private
local function handler_factory(opts, line)
    --- Handler for textDocument/codeAction.
    ---
    --- See lsp-handler for more information.
    ---
    --- @private
    local function code_action_handler(err, _, actions)
        -- The request returns an error
        if err then
            return
        end
        -- No available code actions
        if actions == nil or vim.tbl_isempty(actions) then
            if opts.sign.enabled then
                _update_sign(opts.sign.priority, vim.b.lightbulb_line, nil)
            end
            if opts.virtual_text.enabled then
                _update_virtual_text(opts.virtual_text.text, nil)
            end
            if opts.status_text.enabled then
                _update_status_text(opts.status_text.not_lit_text)
            end
        else
            if opts.sign.enabled then
                _update_sign(opts.sign.priority, vim.b.lightbulb_line, line + 1)
            end

            if opts.float.enabled then
                _update_float(opts.float)
            end

            if opts.virtual_text.enabled then
                _update_virtual_text(opts.virtual_text.text, line)
            end

            if opts.status_text.enabled then
                _update_status_text(opts.status_text.text)
            end
        end

    end

    return code_action_handler
end

M.get_status_text = function()
    return vim.b.current_lightbulb_status_text or ""
end

M.update_lightbulb = function(config)
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
            text = "💡"
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
    vim.lsp.buf_request(
        0, 'textDocument/codeAction', params, handler_factory(opts, params.range.start.line)
    )
end

return M
