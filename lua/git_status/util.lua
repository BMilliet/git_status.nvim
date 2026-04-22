local M = {}

function M.notify(message, level)
    vim.notify("[git_status] " .. message, level or vim.log.levels.INFO)
end

function M.starts_with(value, prefix)
    return value:sub(1, #prefix) == prefix
end

function M.split_lines(value)
    if value == nil or value == "" then
        return {}
    end

    local lines = vim.split(value, "\n", { plain = true })
    if lines[#lines] == "" then
        table.remove(lines, #lines)
    end

    return lines
end

function M.run(command)
    local result = vim.system(command, { text = true }):wait()
    return result.code or 0, result.stdout or "", result.stderr or ""
end

function M.line_count(bufnr)
    return math.max(vim.api.nvim_buf_line_count(bufnr), 1)
end

function M.clamp_line(value, total)
    return math.max(1, math.min(total, value))
end

function M.has_ui()
    return #vim.api.nvim_list_uis() > 0
end

function M.is_normal_window(win)
    return vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == ""
end

function M.set_highlight(bufnr, namespace, group, row, start_col, end_col)
    if not group then
        return
    end

    vim.api.nvim_buf_set_extmark(bufnr, namespace, row, start_col or 0, {
        end_col = end_col and end_col >= 0 and end_col or nil,
        hl_group = group,
    })
end

function M.truncate_display(value, width)
    if vim.fn.strdisplaywidth(value) <= width then
        return value
    end

    return vim.fn.strcharpart(value, 0, math.max(1, width - 3)) .. "..."
end

function M.pad_display(value, width)
    local padding = width - vim.fn.strdisplaywidth(value)
    if padding <= 0 then
        return value
    end

    return value .. string.rep(" ", padding)
end

return M
