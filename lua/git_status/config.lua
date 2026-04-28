local M = {}

local defaults = {
    enabled = true,
    base = "HEAD",
    debounce_ms = 120,
    signs = {
        enabled = true,
        priority = 6,
        text = {
            add = "│",
            change = "│",
            delete = "_",
        },
        highlights = {
            add = "GitStatusAdd",
            change = "GitStatusChange",
            delete = "GitStatusDelete",
        },
    },
    scrollbar = {
        enabled = true,
        chars = {
            add = "+",
            change = "~",
            delete = "-",
            cursor = ">",
        },
        highlights = {
            add = "GitStatusAdd",
            change = "GitStatusChange",
            delete = "GitStatusDelete",
            cursor = "GitStatusCursor",
        },
        priorities = {
            add = 1,
            change = 2,
            delete = 3,
        },
    },
    commands = {
        blame = "Blame",
        refresh = "GitStatusRefresh",
        status = "Status",
        toggle = "GitStatusToggle",
    },
}

M.values = vim.deepcopy(defaults)

function M.setup(opts)
    M.values = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
    return M.values
end

return M
