local git = require("git_status.git")
local highlights = require("git_status.highlights")
local util = require("git_status.util")

local M = {}

M.ns = vim.api.nvim_create_namespace("git_status_conflict")

local menu_buffers = {}
local file_states = {}
local floats = {}

local function root_for_current_context()
    local ctx = git.context(vim.api.nvim_get_current_buf())
    if ctx then
        return ctx.root
    end

    return git.root(vim.fn.getcwd())
end

local function display_value(value)
    return value:gsub("\n", "\\n")
end

local function display_path(entry)
    if entry.old_path and entry.old_path ~= "" then
        return display_value(entry.old_path) .. " -> " .. display_value(entry.path)
    end

    return display_value(entry.path)
end

local function target_path(root, entry)
    return vim.fs.normalize(vim.fs.joinpath(root, entry.path))
end

local function is_delete_conflict(entry)
    return entry.status == "DD"
        or entry.status == "DU"
        or entry.status == "UD"
        or entry.status == "AU"
        or entry.status == "UA"
end

local function side_keeps_file(entry, side)
    if entry.status == "DD" then
        return false
    end

    if entry.status == "DU" or entry.status == "UA" then
        return side == "theirs"
    end

    if entry.status == "UD" or entry.status == "AU" then
        return side == "ours"
    end

    return true
end

local function close_window(win)
    if vim.api.nvim_win_is_valid(win) then
        pcall(vim.api.nvim_win_close, win, true)
    end
end

local function max_line_width(lines)
    local width = 1
    for _, line in ipairs(lines) do
        width = math.max(width, vim.fn.strdisplaywidth(line))
    end

    return width
end

local function popup_config(lines, title)
    local available_width = math.max(40, vim.o.columns - 10)
    local available_height = math.max(8, vim.o.lines - 8)
    local max_width = math.min(112, available_width)
    local max_height = math.min(18, available_height)
    local width = math.min(
        math.max(max_line_width(lines) + 4, math.floor(vim.o.columns * 0.66), 72),
        max_width
    )
    local height = math.min(math.max(#lines, 9), max_height)

    return {
        relative = "editor",
        width = width,
        height = height,
        col = math.max(0, math.floor((vim.o.columns - width) / 2)),
        row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
        style = "minimal",
        border = "single",
        title = " " .. title .. " ",
        title_pos = "left",
        zindex = 60,
    }
end

local function set_popup_window_options(win)
    vim.wo[win].cursorline = true
    vim.wo[win].foldcolumn = "0"
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].wrap = false
    vim.wo[win].winblend = 0
    vim.wo[win].winhighlight = table.concat({
        "Normal:GitStatusConflictNormal",
        "FloatBorder:GitStatusConflictBorder",
        "FloatTitle:GitStatusConflictTitle",
        "CursorLine:GitStatusConflictCursorLine",
    }, ",")
end

local function action_group(row)
    if row.side == "ours" then
        return "GitStatusConflictOurs"
    end

    if row.side == "theirs" then
        return "GitStatusConflictTheirs"
    end

    return "GitStatusConflictUnresolved"
end

local function render_menu(buf, lines, rows, index_width)
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)

    if not next(rows) then
        util.set_highlight(buf, M.ns, "GitStatusConflictMeta", 0, 0, -1)
    else
        for line_number, row in pairs(rows) do
            local status_col = index_width + 2
            local text_col = index_width + 5
            util.set_highlight(buf, M.ns, "GitStatusConflictIndex", line_number - 1, 0, index_width)
            util.set_highlight(buf, M.ns, action_group(row), line_number - 1, status_col, status_col + 1)
            util.set_highlight(buf, M.ns, "GitStatusConflictPath", line_number - 1, text_col, -1)
        end
    end

    vim.bo[buf].modified = false
    vim.bo[buf].modifiable = false
end

local function build_menu_lines(entries)
    local line_count = #entries > 0 and (#entries + 2) or 1
    local index_width = #tostring(line_count)
    local lines = {}
    local rows = {}

    if #entries == 0 then
        return { "No conflicted files" }, rows, index_width
    end

    table.insert(lines, string.format("%" .. index_width .. "d  T  Accept all incoming/main (theirs)", 1))
    rows[#lines] = { type = "all", side = "theirs" }
    table.insert(lines, string.format("%" .. index_width .. "d  O  Accept all current branch (ours)", 2))
    rows[#lines] = { type = "all", side = "ours" }

    for index, entry in ipairs(entries) do
        local row_number = index + 2
        table.insert(lines, string.format(
            "%" .. index_width .. "d  X  %s",
            row_number,
            display_path(entry)
        ))
        rows[#lines] = { type = "file", entry = entry }
    end

    return lines, rows, index_width
end

local function scale_line(line_number, total, height)
    if height <= 1 or total <= 1 then
        return 1
    end

    local row = math.floor(((line_number - 1) / (total - 1)) * (height - 1)) + 1
    return math.max(1, math.min(height, row))
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

local function clear_file_buffer(bufnr)
    file_states[bufnr] = nil

    for win in pairs(floats) do
        if vim.api.nvim_win_is_valid(win) then
            local ok, win_buf = pcall(vim.api.nvim_win_get_buf, win)
            if ok and win_buf == bufnr then
                close_float(win)
            end
        else
            close_float(win)
        end
    end
end

local function ensure_float(win)
    local state = floats[win]
    local height = vim.api.nvim_win_get_height(win)
    local width = vim.api.nvim_win_get_width(win)

    if
        state
        and state.win
        and vim.api.nvim_win_is_valid(state.win)
        and state.buf
        and vim.api.nvim_buf_is_valid(state.buf)
    then
        vim.api.nvim_win_set_config(state.win, {
            relative = "win",
            win = win,
            anchor = "NE",
            row = 0,
            col = width,
            width = 1,
            height = height,
        })
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
        width = 1,
        height = height,
        focusable = false,
        noautocmd = true,
        style = "minimal",
        zindex = 70,
    })

    vim.wo[float_win].winhighlight = "Normal:Normal"
    vim.wo[float_win].wrap = false

    state = { buf = buf, win = float_win }
    floats[win] = state
    return state
end

local function parse_chunks(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local chunks = {}
    local index = 1

    while index <= #lines do
        if lines[index]:match("^<<<<<<<") then
            local start_line = index
            local separator = nil
            local finish = nil

            index = index + 1
            while index <= #lines do
                if not separator and lines[index]:match("^=======$") then
                    separator = index
                elseif separator and lines[index]:match("^>>>>>>>") then
                    finish = index
                    break
                end
                index = index + 1
            end

            if separator and finish then
                table.insert(chunks, {
                    start = start_line,
                    separator = separator,
                    finish = finish,
                    ours_start = start_line + 1,
                    ours_finish = separator - 1,
                    theirs_start = separator + 1,
                    theirs_finish = finish - 1,
                })
            end
        end

        index = index + 1
    end

    return chunks
end

local function render_scrollbar(bufnr, chunks)
    local state = file_states[bufnr]
    if not state then
        return
    end

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == bufnr and vim.api.nvim_win_get_config(win).relative == "" then
            local height = vim.api.nvim_win_get_height(win)
            local total = util.line_count(bufnr)
            local markers = {}

            for _, chunk in ipairs(chunks) do
                markers[scale_line(chunk.start, total, height)] = {
                    text = "X",
                    group = "GitStatusConflictUnresolved",
                }
            end

            for line in pairs(state.resolved or {}) do
                markers[scale_line(line, total, height)] = {
                    text = "V",
                    group = "GitStatusConflictResolved",
                }
            end

            if not next(markers) then
                close_float(win)
                return
            end

            local float = ensure_float(win)
            local lines = {}
            for row = 1, height do
                lines[row] = markers[row] and markers[row].text or " "
            end

            vim.bo[float.buf].modifiable = true
            vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, lines)
            vim.api.nvim_buf_clear_namespace(float.buf, M.ns, 0, -1)

            for row, marker in pairs(markers) do
                util.set_highlight(float.buf, M.ns, marker.group, row - 1, 0, 1)
            end

            vim.bo[float.buf].modifiable = false
        end
    end
end

local function render_file(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    local chunks = parse_chunks(bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)

    for _, chunk in ipairs(chunks) do
        vim.api.nvim_buf_set_extmark(bufnr, M.ns, chunk.start - 1, 0, {
            sign_text = "X",
            sign_hl_group = "GitStatusConflictUnresolved",
            virt_text = {
                { " co current branch ", "GitStatusConflictOurs" },
                { " ct incoming/main ", "GitStatusConflictTheirs" },
            },
            virt_text_pos = "right_align",
        })

        util.set_highlight(bufnr, M.ns, "GitStatusConflictMarker", chunk.start - 1, 0, -1)
        util.set_highlight(bufnr, M.ns, "GitStatusConflictMarker", chunk.separator - 1, 0, -1)
        util.set_highlight(bufnr, M.ns, "GitStatusConflictMarker", chunk.finish - 1, 0, -1)

        for line = chunk.ours_start, chunk.ours_finish do
            util.set_highlight(bufnr, M.ns, "GitStatusConflictOursBlock", line - 1, 0, -1)
        end

        for line = chunk.theirs_start, chunk.theirs_finish do
            util.set_highlight(bufnr, M.ns, "GitStatusConflictTheirsBlock", line - 1, 0, -1)
        end
    end

    local state = file_states[bufnr]
    if state then
        for line in pairs(state.resolved or {}) do
            if line <= util.line_count(bufnr) then
                vim.api.nvim_buf_set_extmark(bufnr, M.ns, line - 1, 0, {
                    sign_text = "V",
                    sign_hl_group = "GitStatusConflictResolved",
                })
            end
        end
    end

    render_scrollbar(bufnr, chunks)
end

local function current_chunk(bufnr)
    local chunks = parse_chunks(bufnr)
    if #chunks == 0 then
        return nil, chunks
    end

    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    for _, chunk in ipairs(chunks) do
        if cursor_line >= chunk.start and cursor_line <= chunk.finish then
            return chunk, chunks
        end
    end

    for _, chunk in ipairs(chunks) do
        if chunk.start >= cursor_line then
            return chunk, chunks
        end
    end

    return chunks[1], chunks
end

local function chunk_lines(bufnr, first, last)
    if first > last then
        return {}
    end

    return vim.api.nvim_buf_get_lines(bufnr, first - 1, last, false)
end

local function resolve_current_chunk(side)
    local bufnr = vim.api.nvim_get_current_buf()
    local state = file_states[bufnr]
    if not state then
        util.notify("current buffer is not a conflict file", vim.log.levels.WARN)
        return
    end

    local chunk = current_chunk(bufnr)
    if not chunk then
        util.notify("no conflict chunk under or after cursor", vim.log.levels.WARN)
        return
    end

    local replacement
    if side == "ours" then
        replacement = chunk_lines(bufnr, chunk.ours_start, chunk.ours_finish)
    else
        replacement = chunk_lines(bufnr, chunk.theirs_start, chunk.theirs_finish)
    end

    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, chunk.start - 1, chunk.finish, false, replacement)
    state.resolved[chunk.start] = true
    vim.api.nvim_win_set_cursor(0, { math.min(chunk.start, util.line_count(bufnr)), 0 })
    render_file(bufnr)

    if #parse_chunks(bufnr) == 0 then
        util.notify("all conflict chunks resolved; write the file and git add it")
    end
end

local function jump_chunk(direction)
    local bufnr = vim.api.nvim_get_current_buf()
    local chunks = parse_chunks(bufnr)
    if #chunks == 0 then
        util.notify("no conflict chunks in this file", vim.log.levels.WARN)
        return
    end

    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local target = direction == "next" and chunks[1] or chunks[#chunks]

    if direction == "next" then
        for _, chunk in ipairs(chunks) do
            if chunk.start > cursor_line then
                target = chunk
                break
            end
        end
    else
        for index = #chunks, 1, -1 do
            if chunks[index].start < cursor_line then
                target = chunks[index]
                break
            end
        end
    end

    vim.api.nvim_win_set_cursor(0, { target.start, 0 })
end

local function setup_file_buffer(root, entry)
    local bufnr = vim.api.nvim_get_current_buf()
    local group = vim.api.nvim_create_augroup("git_status_conflict_" .. bufnr, { clear = true })

    file_states[bufnr] = {
        root = root,
        entry = entry,
        resolved = {},
    }

    vim.keymap.set("n", "co", function()
        resolve_current_chunk("ours")
    end, { buffer = bufnr, nowait = true, silent = true, desc = "Accept current branch conflict chunk" })

    vim.keymap.set("n", "ct", function()
        resolve_current_chunk("theirs")
    end, { buffer = bufnr, nowait = true, silent = true, desc = "Accept incoming branch conflict chunk" })

    vim.keymap.set("n", "]x", function()
        jump_chunk("next")
    end, { buffer = bufnr, nowait = true, silent = true, desc = "Next conflict chunk" })

    vim.keymap.set("n", "[x", function()
        jump_chunk("previous")
    end, { buffer = bufnr, nowait = true, silent = true, desc = "Previous conflict chunk" })

    vim.api.nvim_create_autocmd({
        "BufWritePost",
        "CursorMoved",
        "TextChanged",
        "TextChangedI",
        "WinScrolled",
    }, {
        group = group,
        buffer = bufnr,
        callback = function()
            render_file(bufnr)
        end,
    })

    vim.api.nvim_create_autocmd("BufWipeout", {
        group = group,
        buffer = bufnr,
        once = true,
        callback = function()
            clear_file_buffer(bufnr)
        end,
    })

    render_file(bufnr)
    util.notify("conflict keys: co current branch, ct incoming/main, ]x next, [x previous")
end

local function open_conflict_file(root, entry, source_win)
    local path = target_path(root, entry)
    if vim.fn.filereadable(path) == 0 then
        util.notify("file is not present in the worktree: " .. entry.path, vim.log.levels.WARN)
        return
    end

    if vim.api.nvim_win_is_valid(source_win) then
        vim.api.nvim_set_current_win(source_win)
    end

    vim.cmd("edit " .. vim.fn.fnameescape(path))
    setup_file_buffer(root, entry)
end

local function apply_entry_choice(root, entry, side)
    local code, _, stderr = git.accept_conflict(root, entry, side)
    if code ~= 0 then
        util.notify(vim.trim(stderr), vim.log.levels.ERROR)
        return
    end

    local action = side_keeps_file(entry, side) and "kept" or "removed"
    util.notify(action .. " " .. entry.path)
end

local function open_delete_choice(root, entry, source_win)
    local lines = {
        "1  O  Accept current branch (" .. (side_keeps_file(entry, "ours") and "keep file" or "delete file") .. ")",
        "2  T  Accept incoming/main (" .. (side_keeps_file(entry, "theirs") and "keep file" or "delete file") .. ")",
    }
    local rows = {
        [1] = { side = "ours" },
        [2] = { side = "theirs" },
    }
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, popup_config(lines, display_path(entry)))

    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].buflisted = false
    vim.bo[buf].filetype = "gitstatusconflict"
    vim.bo[buf].swapfile = false
    set_popup_window_options(win)
    render_menu(buf, lines, {
        [1] = { side = "ours" },
        [2] = { side = "theirs" },
    }, 1)

    local function choose()
        local row = rows[vim.api.nvim_win_get_cursor(0)[1]]
        if not row then
            return
        end

        close_window(win)
        if vim.api.nvim_win_is_valid(source_win) then
            vim.api.nvim_set_current_win(source_win)
        end
        apply_entry_choice(root, entry, row.side)
        M.open()
    end

    vim.keymap.set("n", "<CR>", choose, { buffer = buf, nowait = true, silent = true, desc = "Apply conflict choice" })
    vim.keymap.set("n", "o", choose, { buffer = buf, nowait = true, silent = true, desc = "Apply conflict choice" })
    vim.keymap.set("n", "q", function()
        close_window(win)
    end, { buffer = buf, nowait = true, silent = true, desc = "Close conflict choice" })
    vim.keymap.set("n", "<Esc>", function()
        close_window(win)
    end, { buffer = buf, nowait = true, silent = true, desc = "Close conflict choice" })
end

local function menu_select(buf)
    local state = menu_buffers[buf]
    if not state then
        return
    end

    local row = vim.api.nvim_win_get_cursor(0)[1]
    local item = state.rows[row]
    if not item then
        return
    end

    close_window(vim.api.nvim_get_current_win())

    if item.type == "all" then
        local code, stderr = git.accept_conflicts(state.root, state.entries, item.side)
        if code ~= 0 then
            util.notify(stderr, vim.log.levels.ERROR)
            return
        end

        util.notify(item.side == "ours" and "accepted all current branch conflicts" or "accepted all incoming/main conflicts")
        return
    end

    if is_delete_conflict(item.entry) then
        open_delete_choice(state.root, item.entry, state.source_win)
    else
        open_conflict_file(state.root, item.entry, state.source_win)
    end
end

function M.open()
    highlights.define()

    local root = root_for_current_context()
    if not root then
        util.notify("not in a git repository", vim.log.levels.WARN)
        return
    end

    local code, entries, stderr = git.conflicts(root)
    if code ~= 0 then
        util.notify(vim.trim(stderr), vim.log.levels.ERROR)
        return
    end

    local lines, rows, index_width = build_menu_lines(entries)
    local source_win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, popup_config(lines, "Conflict"))

    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].buflisted = false
    vim.bo[buf].filetype = "gitstatusconflict"
    vim.bo[buf].swapfile = false
    set_popup_window_options(win)
    render_menu(buf, lines, rows, index_width)

    menu_buffers[buf] = {
        root = root,
        entries = entries,
        rows = rows,
        source_win = source_win,
    }

    vim.keymap.set("n", "<CR>", function()
        menu_select(buf)
    end, { buffer = buf, nowait = true, silent = true, desc = "Select conflict action" })

    vim.keymap.set("n", "o", function()
        menu_select(buf)
    end, { buffer = buf, nowait = true, silent = true, desc = "Select conflict action" })

    vim.keymap.set("n", "q", function()
        close_window(vim.api.nvim_get_current_win())
    end, { buffer = buf, nowait = true, silent = true, desc = "Close conflict view" })

    vim.keymap.set("n", "<Esc>", function()
        close_window(vim.api.nvim_get_current_win())
    end, { buffer = buf, nowait = true, silent = true, desc = "Close conflict view" })

    vim.api.nvim_create_autocmd("BufWipeout", {
        buffer = buf,
        once = true,
        callback = function()
            menu_buffers[buf] = nil
        end,
    })
end

return M
