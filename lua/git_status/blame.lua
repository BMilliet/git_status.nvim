local git = require("git_status.git")
local highlights = require("git_status.highlights")
local util = require("git_status.util")

local M = {}

M.ns = vim.api.nvim_create_namespace("git_status_blame")

local gradient_size = 10

local function parse(stdout)
    local rows = {}
    local current = nil

    for _, line in ipairs(util.split_lines(stdout)) do
        local hash = line:match("^([0-9a-f]+) %d+ %d+")
        if hash then
            current = {
                hash = hash,
                author = "unknown",
                date = "",
                summary = "",
                text = "",
            }
        elseif current and util.starts_with(line, "author ") then
            current.author = line:sub(8)
        elseif current and util.starts_with(line, "author-time ") then
            local timestamp = tonumber(line:sub(13))
            current.date = timestamp and os.date("%Y-%m-%d", timestamp) or ""
        elseif current and util.starts_with(line, "summary ") then
            current.summary = line:sub(9)
        elseif current and util.starts_with(line, "\t") then
            current.text = line:sub(2)
            table.insert(rows, current)
            current = nil
        end
    end

    return rows
end

function M.open()
    highlights.define()

    local source_buf = vim.api.nvim_get_current_buf()
    local ctx = git.context(source_buf)
    if not ctx then
        util.notify("current buffer is not a git file", vim.log.levels.WARN)
        return
    end

    local code, stdout, stderr = git.blame(ctx)
    if code ~= 0 then
        util.notify(vim.trim(stderr), vim.log.levels.ERROR)
        return
    end

    local rows = parse(stdout)
    vim.cmd("botright vsplit")
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(win, buf)

    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].buflisted = false
    vim.bo[buf].filetype = "gitstatusblame"
    vim.bo[buf].swapfile = false
    vim.wo[win].wrap = false
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"

    local lines = {
        "Blame: " .. ctx.relpath,
        "q closes this view",
        "",
    }

    local line_width = #tostring(math.max(1, #rows))
    for index, row in ipairs(rows) do
        local short_hash = row.hash:sub(1, 8)
        local author = util.pad_display(util.truncate_display(row.author, 24), 24)
        local summary = util.truncate_display(row.summary, 40)
        table.insert(
            lines,
            string.format(
                "%" .. line_width .. "d  %s  %s  %s  %-40s | %s",
                index,
                short_hash,
                author,
                row.date,
                summary,
                row.text
            )
        )
    end

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
    util.set_highlight(buf, M.ns, "GitStatusBlameHeader", 0, 0, -1)
    util.set_highlight(buf, M.ns, "GitStatusBlameMeta", 1, 0, -1)

    for row = 3, #lines - 1 do
        local line = lines[row + 1]
        local separator = line:find(" | ", 1, true)
        if separator then
            local gradient_index = ((row - 3) % gradient_size) + 1
            util.set_highlight(
                buf,
                M.ns,
                "GitStatusBlameGradient" .. gradient_index,
                row,
                0,
                separator + 1
            )
        end
    end

    vim.bo[buf].modified = false
    vim.bo[buf].modifiable = false

    vim.keymap.set("n", "q", function()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end, { buffer = buf, nowait = true, silent = true, desc = "Close blame view" })
end

return M
