local git = require("git_status.git")
local highlights = require("git_status.highlights")
local util = require("git_status.util")

local M = {}

M.ns = vim.api.nvim_create_namespace("git_status_status")

local buffers = {}

local function entry_group(entry)
    if entry.status == "??" then
        return "GitStatusStatusAdd"
    end

    local unmerged = entry.index == "U"
        or entry.worktree == "U"
        or entry.status == "AA"
        or entry.status == "DD"

    if unmerged then
        return "GitStatusStatusUnmerged"
    end

    if entry.index == "D" or entry.worktree == "D" then
        return "GitStatusStatusDelete"
    end

    if entry.index == "A" or entry.worktree == "A" then
        return "GitStatusStatusAdd"
    end

    if entry.index == "R" or entry.worktree == "R" then
        return "GitStatusStatusRename"
    end

    if entry.index == "C" or entry.worktree == "C" then
        return "GitStatusStatusRename"
    end

    return "GitStatusStatusChange"
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

local function root_for_current_context()
    local ctx = git.context(vim.api.nvim_get_current_buf())
    if ctx then
        return ctx.root
    end

    return git.root(vim.fn.getcwd())
end

local function target_path(root, entry)
    return vim.fs.normalize(vim.fs.joinpath(root, entry.path))
end

local function buffer_name(root)
    return "git-status://" .. root
end

local function listed_buffer(root)
    local name = buffer_name(root)
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(bufnr)
            and vim.api.nvim_buf_is_loaded(bufnr)
            and vim.api.nvim_buf_get_name(bufnr) == name
        then
            return bufnr
        end
    end

    local bufnr = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_name(bufnr, name)
    return bufnr
end

local function close_window(win)
    if vim.api.nvim_win_is_valid(win) then
        pcall(vim.api.nvim_win_close, win, true)
    end
end

local function edit_path(path, action)
    local escaped = vim.fn.fnameescape(path)

    if action == "split" then
        vim.cmd("split " .. escaped)
    elseif action == "vsplit" then
        vim.cmd("vsplit " .. escaped)
    elseif action == "tabedit" then
        vim.cmd("tabedit " .. escaped)
    else
        vim.cmd("edit " .. escaped)
    end
end

local function open_entry(buf, action)
    local state = buffers[buf]
    if not state then
        return
    end

    local row = vim.api.nvim_win_get_cursor(0)[1]
    local entry = state.rows[row]
    if not entry then
        return
    end

    local path = target_path(state.root, entry)
    if vim.fn.filereadable(path) == 0 and vim.fn.isdirectory(path) == 0 then
        util.notify("file does not exist in the worktree: " .. entry.path, vim.log.levels.WARN)
        return
    end

    close_window(vim.api.nvim_get_current_win())

    if vim.api.nvim_win_is_valid(state.source_win) then
        vim.api.nvim_set_current_win(state.source_win)
    end

    edit_path(path, action)
end

local function build_lines(root, head, entries)
    local lines = {
        "Repository: " .. root,
        "Branch: " .. head.branch .. "    Commit: " .. head.hash,
        "Last: " .. (head.subject ~= "" and head.subject or "no commit message"),
        "",
        string.format(
            "%d changed file%s  |  <CR>/o open  s split  v vsplit  t tab  q close",
            #entries,
            #entries == 1 and "" or "s"
        ),
        "",
    }
    local rows = {}

    if #entries == 0 then
        table.insert(lines, "No changed files")
    else
        for _, entry in ipairs(entries) do
            table.insert(lines, string.format("%-2s  %s", entry.status, display_path(entry)))
            rows[#lines] = entry
        end
    end

    return lines, rows
end

local function max_line_width(lines)
    local width = 1
    for _, line in ipairs(lines) do
        width = math.max(width, vim.fn.strdisplaywidth(line))
    end

    return width
end

local function popup_config(lines)
    local available_width = math.max(50, vim.o.columns - 6)
    local available_height = math.max(8, vim.o.lines - 6)
    local max_width = math.min(120, available_width)
    local max_height = math.min(28, available_height)
    local width = math.min(
        math.max(max_line_width(lines) + 2, math.floor(vim.o.columns * 0.72), 72),
        max_width
    )
    local height = math.min(
        math.max(#lines + 1, math.floor(vim.o.lines * 0.5), 12),
        max_height
    )

    return {
        relative = "editor",
        width = width,
        height = height,
        col = math.max(0, math.floor((vim.o.columns - width) / 2)),
        row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
        style = "minimal",
        border = "rounded",
        title = " Git Status ",
        title_pos = "center",
    }
end

local function render(buf, lines, rows)
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
    util.set_highlight(buf, M.ns, "GitStatusStatusHeader", 0, 0, -1)

    local branch_line = lines[2]
    local commit_label_start = branch_line:find("Commit:", 1, true)
    util.set_highlight(buf, M.ns, "GitStatusStatusLabel", 1, 0, #"Branch:")
    if commit_label_start then
        util.set_highlight(buf, M.ns, "GitStatusStatusBranch", 1, #"Branch: ", commit_label_start - 5)
        util.set_highlight(buf, M.ns, "GitStatusStatusLabel", 1, commit_label_start - 1, commit_label_start + #"Commit:" - 1)
        util.set_highlight(buf, M.ns, "GitStatusStatusHash", 1, commit_label_start + #"Commit: " - 1, -1)
    end

    util.set_highlight(buf, M.ns, "GitStatusStatusLabel", 2, 0, 5)
    util.set_highlight(buf, M.ns, "GitStatusStatusSubject", 2, 6, -1)
    util.set_highlight(buf, M.ns, "GitStatusStatusMeta", 4, 0, -1)

    if not next(rows) then
        util.set_highlight(buf, M.ns, "GitStatusStatusMeta", 6, 0, -1)
    else
        for row, entry in pairs(rows) do
            util.set_highlight(buf, M.ns, entry_group(entry), row - 1, 0, 2)
            util.set_highlight(buf, M.ns, "GitStatusStatusPath", row - 1, 4, -1)
        end
    end

    vim.bo[buf].modified = false
    vim.bo[buf].modifiable = false
end

function M.open()
    highlights.define()

    local root = root_for_current_context()
    if not root then
        util.notify("not in a git repository", vim.log.levels.WARN)
        return
    end

    local code, entries, stderr = git.status(root)
    if code ~= 0 then
        util.notify(vim.trim(stderr), vim.log.levels.ERROR)
        return
    end

    local head = git.head(root)
    local buf = listed_buffer(root)
    local lines, rows = build_lines(root, head, entries)
    local source_win = vim.api.nvim_get_current_win()
    local win = vim.api.nvim_open_win(buf, true, popup_config(lines))

    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].buflisted = true
    vim.bo[buf].filetype = "gitstatus"
    vim.bo[buf].swapfile = false
    vim.wo[win].cursorline = true
    vim.wo[win].foldcolumn = "0"
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].wrap = false

    render(buf, lines, rows)

    buffers[buf] = {
        root = root,
        rows = rows,
        source_win = source_win,
    }

    vim.keymap.set("n", "<CR>", function()
        open_entry(buf, "edit")
    end, { buffer = buf, nowait = true, silent = true, desc = "Open status file" })

    vim.keymap.set("n", "o", function()
        open_entry(buf, "edit")
    end, { buffer = buf, nowait = true, silent = true, desc = "Open status file" })

    vim.keymap.set("n", "s", function()
        open_entry(buf, "split")
    end, { buffer = buf, nowait = true, silent = true, desc = "Open status file in split" })

    vim.keymap.set("n", "v", function()
        open_entry(buf, "vsplit")
    end, { buffer = buf, nowait = true, silent = true, desc = "Open status file in vertical split" })

    vim.keymap.set("n", "t", function()
        open_entry(buf, "tabedit")
    end, { buffer = buf, nowait = true, silent = true, desc = "Open status file in tab" })

    vim.keymap.set("n", "q", function()
        close_window(vim.api.nvim_get_current_win())
    end, { buffer = buf, nowait = true, silent = true, desc = "Close status view" })

    vim.keymap.set("n", "<Esc>", function()
        close_window(vim.api.nvim_get_current_win())
    end, { buffer = buf, nowait = true, silent = true, desc = "Close status view" })

    vim.api.nvim_create_autocmd("BufWipeout", {
        buffer = buf,
        once = true,
        callback = function()
            buffers[buf] = nil
        end,
    })
end

return M
