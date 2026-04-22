local blame = require("git_status.blame")
local config = require("git_status.config")
local git = require("git_status.git")
local highlights = require("git_status.highlights")
local scrollbar = require("git_status.scrollbar")
local signs = require("git_status.signs")
local util = require("git_status.util")

local M = {}

local augroup = nil
local setup_done = false
local cache = {}
local pending = {}

scrollbar.set_cache(cache)

local function clear_buffer(bufnr)
    signs.clear(bufnr)
    cache[bufnr] = nil
    scrollbar.clear_buffer(bufnr)
end

function M.render_scrollbar(bufnr)
    scrollbar.render(bufnr)
end

function M.refresh(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if not vim.api.nvim_buf_is_valid(bufnr) then
        clear_buffer(bufnr)
        return
    end

    highlights.define()

    local ctx = git.context(bufnr)
    if not ctx then
        clear_buffer(bufnr)
        return
    end

    local hunks = git.hunks(ctx)
    cache[bufnr] = {
        ctx = ctx,
        hunks = hunks,
    }

    signs.render(bufnr, hunks)
    scrollbar.render(bufnr)
end

local function schedule_refresh(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if pending[bufnr] then
        return
    end

    pending[bufnr] = true
    vim.defer_fn(function()
        pending[bufnr] = nil
        M.refresh(bufnr)
    end, config.values.debounce_ms)
end

local function schedule_scrollbar(bufnr)
    vim.schedule(function()
        scrollbar.render(bufnr)
    end)
end

function M.enable()
    config.values.enabled = true
    schedule_refresh()
end

function M.disable()
    config.values.enabled = false
    for bufnr in pairs(cache) do
        signs.clear(bufnr)
    end
    scrollbar.close_all()
end

function M.toggle()
    if config.values.enabled then
        M.disable()
    else
        M.enable()
    end

    util.notify(config.values.enabled and "enabled" or "disabled")
end

function M.blame()
    blame.open()
end

local function create_command(name, callback, desc)
    if not name or name == "" then
        return
    end

    pcall(vim.api.nvim_del_user_command, name)
    vim.api.nvim_create_user_command(name, callback, { desc = desc })
end

function M.setup(opts)
    config.setup(opts)
    highlights.define()

    if setup_done and augroup then
        vim.api.nvim_clear_autocmds({ group = augroup })
        for bufnr in pairs(cache) do
            signs.clear(bufnr)
        end
        scrollbar.close_all()
    end

    setup_done = true
    augroup = vim.api.nvim_create_augroup("git_status", { clear = true })

    vim.api.nvim_create_autocmd({
        "BufEnter",
        "BufReadPost",
        "BufWritePost",
        "FocusGained",
        "InsertLeave",
        "TextChanged",
        "TextChangedI",
    }, {
        group = augroup,
        callback = function(args)
            schedule_refresh(args.buf)
        end,
    })

    vim.api.nvim_create_autocmd({
        "CursorMoved",
        "CursorMovedI",
        "VimResized",
        "WinEnter",
        "WinScrolled",
    }, {
        group = augroup,
        callback = function()
            schedule_scrollbar()
        end,
    })

    vim.api.nvim_create_autocmd({ "BufWipeout", "WinClosed" }, {
        group = augroup,
        callback = function(args)
            if args.event == "BufWipeout" then
                clear_buffer(args.buf)
            else
                schedule_scrollbar()
            end
        end,
    })

    create_command(config.values.commands.blame, function()
        M.blame()
    end, "Show git blame for the current file")

    create_command(config.values.commands.refresh, function()
        M.refresh()
    end, "Refresh git status signs and scrollbar")

    create_command(config.values.commands.toggle, function()
        M.toggle()
    end, "Toggle git status signs and scrollbar")

    schedule_refresh()
end

return M
