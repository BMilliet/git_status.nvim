local M = {}

local blame_gradient = {
    "#c084fc",
    "#ca7df3",
    "#d477e8",
    "#de72dc",
    "#e66ccf",
    "#ed67c1",
    "#f064b2",
    "#f064a1",
    "#ee6790",
    "#f87171",
}

function M.define()
    vim.api.nvim_set_hl(0, "GitStatusAdd", { fg = "#7ee787", default = true })
    vim.api.nvim_set_hl(0, "GitStatusChange", { fg = "#d29922", default = true })
    vim.api.nvim_set_hl(0, "GitStatusDelete", { fg = "#f85149", default = true })
    vim.api.nvim_set_hl(0, "GitStatusCursor", { link = "CursorLineNr", default = true })
    vim.api.nvim_set_hl(0, "GitStatusBlameHeader", { link = "Title", default = true })
    vim.api.nvim_set_hl(0, "GitStatusBlameMeta", { link = "Comment", default = true })
    vim.api.nvim_set_hl(0, "GitStatusBlameHash", { link = "Identifier", default = true })
    vim.api.nvim_set_hl(0, "GitStatusBlameAuthor", { link = "Statement", default = true })
    for index, color in ipairs(blame_gradient) do
        vim.api.nvim_set_hl(0, "GitStatusBlameGradient" .. index, { fg = color, default = true })
    end
    vim.api.nvim_set_hl(0, "GitStatusStatusHeader", { link = "Title", default = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusMeta", { link = "Comment", default = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusPath", { link = "Normal", default = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusAdd", { link = "GitStatusAdd", default = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusChange", { link = "GitStatusChange", default = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusDelete", { link = "GitStatusDelete", default = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusRename", { link = "Identifier", default = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusUnmerged", { link = "ErrorMsg", default = true })
end

return M
