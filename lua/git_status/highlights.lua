local M = {}

function M.define()
    vim.api.nvim_set_hl(0, "GitStatusAdd", { fg = "#7ee787", default = true })
    vim.api.nvim_set_hl(0, "GitStatusChange", { fg = "#d29922", default = true })
    vim.api.nvim_set_hl(0, "GitStatusDelete", { fg = "#f85149", default = true })
    vim.api.nvim_set_hl(0, "GitStatusCursor", { link = "CursorLineNr", default = true })
    vim.api.nvim_set_hl(0, "GitStatusBlameHeader", { link = "Title", default = true })
    vim.api.nvim_set_hl(0, "GitStatusBlameMeta", { link = "Comment", default = true })
    vim.api.nvim_set_hl(0, "GitStatusBlameHash", { link = "Identifier", default = true })
    vim.api.nvim_set_hl(0, "GitStatusBlameAuthor", { link = "Statement", default = true })
end

return M
