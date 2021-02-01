local vim = vim
local lsp_util = require("vim.lsp.util")
local M = {}

local SIGN_GROUP = "nvim-lightbulb"
local SIGN_NAME = "LightBulbSign"

local _config = {
    -- Sign priority
    sign_priority = 10
}

-- Set default sign
if vim.tbl_isempty(vim.fn.sign_getdefined(SIGN_NAME)) then
    vim.fn.sign_define(SIGN_NAME, { text = "💡", texthl = "LspDiagnosticsDefaultInformation" })
end

--- Update sign position from `old_line` to `new_line`.
---
--- Either line can be optional, and will result in just adding/removing
--- the sign on the given line.
---
--- @param old_line number|nil The line to remove the sign on
--- @param new_line number|nil The line to add the sign on
---
--- @private
local function _update_sign(old_line, new_line)
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
            { lnum = new_line, priority = _config.sign_priority }
        )
        -- Update current lightbulb line
        vim.b.lightbulb_line = new_line
    end
end

--- Handler factory to keep track of current lightbulb line.
---
--- @param line number The line when the the code action request is called
--- @private
local function handler_factory(line)
    --- Handler for textDocument/codeAction.
    ---
    --- See lsp-handler for more information.
    ---
    --- @private
    local function code_action_handler(_, _, actions)
        -- No available code actions and a lightbulb is currently showing
        if actions == nil or vim.tbl_isempty(actions) and vim.b.lightbulb_line then
            _update_sign(vim.b.lightbulb_line, nil)
            return
        end

        -- Get line of new lightbulb
        local code_action_line = line + 1
        -- Avoid redrawing lightbulb if the code action line did not change
        if vim.b.lightbulb_line ~= code_action_line then
            _update_sign(vim.b.lightbulb_line, code_action_line)
        end
    end

    return code_action_handler
end

M.update_lightbulb = function()
    local context = { diagnostics = vim.lsp.diagnostic.get_line_diagnostics() }
    local params = lsp_util.make_range_params()
    params.context = context
    vim.lsp.buf_request(
        0, 'textDocument/codeAction', params, handler_factory(params.range.start.line)
    )
end

-- Update default config
M.config = function(config)
    for key, value in pairs(_config) do
        if config[key] == nil then
            config[key] = value
        end
    end
end

return M
