local config = require("git_status.config")
local util = require("git_status.util")

local M = {}

local function run_git(root, args)
    local command = { "git", "-C", root, "--no-pager" }
    vim.list_extend(command, args)
    return util.run(command)
end

local function relative_path(root, path)
    local ok, relpath = pcall(vim.fs.relpath, root, path)
    if ok and relpath then
        return relpath
    end

    local prefix = vim.pesc(root .. "/")
    return path:gsub("^" .. prefix, "")
end

function M.root(start)
    local dir = start or vim.fn.getcwd()
    if dir == "" then
        return nil
    end

    dir = vim.fs.normalize(vim.fn.fnamemodify(dir, ":p"))
    if vim.fn.isdirectory(dir) == 0 then
        dir = vim.fs.dirname(dir)
    end

    local code, stdout = util.run({ "git", "-C", dir, "rev-parse", "--show-toplevel" })
    if code ~= 0 then
        return nil
    end

    return vim.fs.normalize(vim.trim(stdout))
end

function M.context(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= "" then
        return nil
    end

    local name = vim.api.nvim_buf_get_name(bufnr)
    if name == "" then
        return nil
    end

    local path = vim.fs.normalize(vim.fn.fnamemodify(name, ":p"))
    local dir = vim.fs.dirname(path)
    local root = M.root(dir)
    if not root then
        return nil
    end

    return {
        bufnr = bufnr,
        path = path,
        root = root,
        relpath = relative_path(root, path),
    }
end

local function count_value(value)
    if value == nil or value == "" then
        return 1
    end

    return tonumber(value) or 1
end

function M.parse_diff(stdout)
    local hunks = {}

    for _, line in ipairs(util.split_lines(stdout)) do
        local old_start, old_count, new_start, new_count =
            line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")

        if old_start and new_start then
            old_start = tonumber(old_start)
            new_start = tonumber(new_start)
            old_count = count_value(old_count)
            new_count = count_value(new_count)

            local kind = "change"
            if old_count == 0 and new_count > 0 then
                kind = "add"
            elseif new_count == 0 and old_count > 0 then
                kind = "delete"
            end

            table.insert(hunks, {
                type = kind,
                added = {
                    start = new_start,
                    count = new_count,
                },
                removed = {
                    start = old_start,
                    count = old_count,
                },
            })
        end
    end

    return hunks
end

local function untracked_hunks(ctx)
    local code, stdout = run_git(ctx.root, {
        "ls-files",
        "--others",
        "--exclude-standard",
        "--",
        ctx.relpath,
    })

    if code ~= 0 or vim.trim(stdout) == "" then
        return nil
    end

    return {
        {
            type = "add",
            added = {
                start = 1,
                count = util.line_count(ctx.bufnr),
            },
            removed = {
                start = 0,
                count = 0,
            },
        },
    }
end

local function temp_file(lines)
    local path = vim.fn.tempname()
    vim.fn.writefile(lines, path, "b")
    return path
end

local function all_added_hunk(ctx)
    return {
        {
            type = "add",
            added = {
                start = 1,
                count = util.line_count(ctx.bufnr),
            },
            removed = {
                start = 0,
                count = 0,
            },
        },
    }
end

function M.hunks(ctx)
    local untracked = untracked_hunks(ctx)
    if untracked then
        return untracked
    end

    local base = config.values.base
    local base_code, base_stdout = run_git(ctx.root, { "show", base .. ":" .. ctx.relpath })
    if base_code ~= 0 then
        return all_added_hunk(ctx)
    end

    local old_path = temp_file(util.split_lines(base_stdout))
    local new_path = temp_file(vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false))

    local code, stdout = run_git(ctx.root, {
        "diff",
        "--no-index",
        "--no-color",
        "--no-ext-diff",
        "--unified=0",
        old_path,
        new_path,
    })

    vim.fn.delete(old_path)
    vim.fn.delete(new_path)

    if code > 1 then
        return {}
    end

    return M.parse_diff(stdout)
end

function M.blame(ctx)
    return run_git(ctx.root, {
        "blame",
        "--line-porcelain",
        "--",
        ctx.relpath,
    })
end

function M.parse_status(stdout)
    local entries = {}
    local records = vim.split(stdout or "", "\0", { plain = true })
    if records[#records] == "" then
        table.remove(records, #records)
    end

    local index = 1
    while index <= #records do
        local record = records[index]
        local status = record:sub(1, 2)
        local path = record:sub(4)

        if #record >= 4 and path ~= "" then
            local entry = {
                status = status,
                index = status:sub(1, 1),
                worktree = status:sub(2, 2),
                path = path,
            }
            local renamed_or_copied = entry.index == "R"
                or entry.index == "C"
                or entry.worktree == "R"
                or entry.worktree == "C"

            if renamed_or_copied then
                index = index + 1
                entry.old_path = records[index]
            end

            table.insert(entries, entry)
        end

        index = index + 1
    end

    return entries
end

function M.status(root)
    local code, stdout, stderr = run_git(root, {
        "status",
        "--porcelain=v1",
        "-z",
        "--untracked-files=all",
    })

    if code ~= 0 then
        return code, {}, stderr
    end

    return code, M.parse_status(stdout), stderr
end

return M
