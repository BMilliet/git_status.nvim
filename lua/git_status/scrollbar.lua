local config = require("git_status.config")
local util = require("git_status.util")

local M = {}

local ns = vim.api.nvim_create_namespace("git_status_scrollbar")
local floats = {}
local cache = nil

function M.set_cache(source)
    cache = source
end

local function close_float(win)
    local state = floats[win]
    if not state then
        return
    end

    if state.win and vim.api.nvim_win_is_valid(state.win) then
        pcall(vim.api.nvim_win_close, state.win, true)
    end

    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
        pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
    end

    floats[win] = nil
end

local function cleanup()
    for win, state in pairs(floats) do
        if not util.is_normal_window(win) or not state.win or not vim.api.nvim_win_is_valid(state.win) then
            close_float(win)
        end
    end
end

local function scale_line(line_number, total, height)
    if height <= 1 or total <= 1 then
        return 1
    end

    local row = math.floor(((line_number - 1) / (total - 1)) * (height - 1)) + 1
    return math.max(1, math.min(height, row))
end

local function hunk_range(hunk, total)
    local start = hunk.added.start
    local added_count = hunk.added.count
    local removed_count = hunk.removed.count
    local size = math.max(added_count, removed_count, 1)
    local finish = start + size - 1

    return util.clamp_line(start, total), util.clamp_line(finish, total)
end

local function marker_text(kind, line_number)
    return ("%d%s"):format(line_number, config.values.scrollbar.chars[kind])
end

local function build_markers(bufnr, hunks, height)
    if not hunks or vim.tbl_isempty(hunks) then
        return nil, nil
    end

    local total = util.line_count(bufnr)
    local markers = {}
    local marker_width = 1

    for _, hunk in ipairs(hunks) do
        local kind = hunk.type
        if config.values.scrollbar.chars[kind] then
            local first, last = hunk_range(hunk, total)
            local first_row = scale_line(first, total, height)
            local last_row = scale_line(last, total, height)
            local text = marker_text(kind, first)
            marker_width = math.max(marker_width, #text)

            for row = first_row, last_row do
                local existing = markers[row]
                if
                    not existing
                    or config.values.scrollbar.priorities[kind] > config.values.scrollbar.priorities[existing.kind]
                then
                    markers[row] = {
                        kind = kind,
                        text = text,
                    }
                end
            end
        end
    end

    return next(markers) and markers or nil, marker_width
end

local function ensure_float(win, height, bar_width)
    local state = floats[win]
    local width = vim.api.nvim_win_get_width(win)

    if
        state
        and state.win
        and vim.api.nvim_win_is_valid(state.win)
        and state.buf
        and vim.api.nvim_buf_is_valid(state.buf)
    then
        if vim.api.nvim_win_get_height(state.win) ~= height then
            vim.api.nvim_win_set_height(state.win, height)
        end
        if state.width ~= width or state.bar_width ~= bar_width then
            vim.api.nvim_win_set_config(state.win, {
                relative = "win",
                win = win,
                anchor = "NE",
                row = 0,
                col = width,
                width = bar_width,
                height = height,
            })
            state.width = width
            state.bar_width = bar_width
        end
        return state
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].swapfile = false

    local float_win = vim.api.nvim_open_win(buf, false, {
        relative = "win",
        win = win,
        anchor = "NE",
        row = 0,
        col = width,
        width = bar_width,
        height = height,
        focusable = false,
        noautocmd = true,
        style = "minimal",
        zindex = 45,
    })

    vim.wo[float_win].winhighlight = "Normal:Normal"
    vim.wo[float_win].wrap = false

    state = { buf = buf, win = float_win, width = width, bar_width = bar_width }
    floats[win] = state
    return state
end

local function render_window(win)
    if not config.values.enabled or not config.values.scrollbar.enabled or not util.has_ui() or not util.is_normal_window(win) then
        close_float(win)
        return
    end

    local bufnr = vim.api.nvim_win_get_buf(win)
    local entry = cache and cache[bufnr]
    local hunks = entry and entry.hunks or {}
    local height = vim.api.nvim_win_get_height(win)
    local markers, marker_width = build_markers(bufnr, hunks, height)

    if not markers then
        close_float(win)
        return
    end

    local bar_width = marker_width + 1
    local state = ensure_float(win, height, bar_width)
    local total = util.line_count(bufnr)
    local cursor_line = vim.api.nvim_win_get_cursor(win)[1]
    local cursor_row = scale_line(cursor_line, total, height)
    local lines = {}

    for row = 1, height do
        local marker = markers[row]
        local git_text = marker and marker.text or ""
        local cursor_char = row == cursor_row and config.values.scrollbar.chars.cursor or " "
        lines[row] = git_text .. string.rep(" ", marker_width - #git_text) .. cursor_char
    end

    vim.bo[state.buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)

    for row, marker in pairs(markers) do
        util.set_highlight(
            state.buf,
            ns,
            config.values.scrollbar.highlights[marker.kind],
            row - 1,
            0,
            #marker.text
        )
    end

    util.set_highlight(
        state.buf,
        ns,
        config.values.scrollbar.highlights.cursor,
        cursor_row - 1,
        marker_width,
        marker_width + 1
    )

    vim.bo[state.buf].modifiable = false
end

function M.render(bufnr)
    cleanup()

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if util.is_normal_window(win) and (not bufnr or vim.api.nvim_win_get_buf(win) == bufnr) then
            render_window(win)
        end
    end
end

function M.clear_buffer(bufnr)
    for win in pairs(floats) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
            close_float(win)
        end
    end
end

function M.close_all()
    for win in pairs(floats) do
        close_float(win)
    end
end

return M
