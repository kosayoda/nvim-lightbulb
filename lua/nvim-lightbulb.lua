local vim = vim
local lsp_util = require("vim.lsp.util")
local M = {}

local SIGN_GROUP = "nvim-lightbulb"
local SIGN_NAME = "LightBulbSign"

-- Set default sign
if vim.tbl_isempty(vim.fn.sign_getdefined(SIGN_NAME)) then
    vim.fn.sign_define(SIGN_NAME, { text = "💡", texthl = "LspDiagnosticsDefaultInformation" })
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

    if new_line then
        vim.fn.sign_place(
            new_line, SIGN_GROUP, SIGN_NAME, "%",
            { lnum = new_line, priority = priority }
        )
        -- Update current lightbulb line
        vim.b.lightbulb_line = new_line
    end
end

--- Handler factory to keep track of current lightbulb line.
---
--- @param line number The line when the the code action request is called
--- @param opts table Options passed when `update_lightbulb` is called
--- @private
local function handler_factory(line, opts)
    --- Handler for textDocument/codeAction.
    ---
    --- See lsp-handler for more information.
    ---
    --- @private
    local priority = opts.sign_priority or 10 -- Default sign priority
    local function code_action_handler(err, _, actions)
        -- The request returns an error
        if err then
            return
        end
        -- No available code actions
        if actions == nil or vim.tbl_isempty(actions) then
            _update_sign(priority, vim.b.lightbulb_line, nil)
            return
        end

        -- Get line of new lightbulb
        local code_action_line = line + 1
        -- Avoid redrawing lightbulb if the code action line did not change
        if vim.b.lightbulb_line ~= code_action_line then
            _update_sign(priority, vim.b.lightbulb_line, code_action_line)
        end
    end

    return code_action_handler
end

M.update_lightbulb = function(opts)
    opts = opts or {}

    local context = { diagnostics = vim.lsp.diagnostic.get_line_diagnostics() }
    local params = lsp_util.make_range_params()
    params.context = context
    vim.lsp.buf_request(
        0, 'textDocument/codeAction', params, handler_factory(params.range.start.line, opts)
    )
end

return M
