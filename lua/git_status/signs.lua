local config = require("git_status.config")
local util = require("git_status.util")

local M = {}

M.ns = vim.api.nvim_create_namespace("git_status_signs")

local function hunk_lines(hunk, total)
    local lines = {}

    if hunk.type == "delete" then
        table.insert(lines, util.clamp_line(hunk.added.start, total))
        return lines
    end

    local count = math.max(hunk.added.count, 1)
    for line_number = hunk.added.start, hunk.added.start + count - 1 do
        table.insert(lines, util.clamp_line(line_number, total))
    end

    return lines
end

function M.render(bufnr, hunks)
    vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)

    if not config.values.enabled or not config.values.signs.enabled then
        return
    end

    local total = util.line_count(bufnr)
    for _, hunk in ipairs(hunks) do
        local sign_text = config.values.signs.text[hunk.type]
        local sign_hl = config.values.signs.highlights[hunk.type]

        if sign_text and sign_hl then
            for _, line_number in ipairs(hunk_lines(hunk, total)) do
                vim.api.nvim_buf_set_extmark(bufnr, M.ns, line_number - 1, 0, {
                    priority = config.values.signs.priority,
                    sign_text = sign_text,
                    sign_hl_group = sign_hl,
                })
            end
        end
    end
end

function M.clear(bufnr)
    if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
    end
end

return M
