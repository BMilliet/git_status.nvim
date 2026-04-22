local M = {}

local blame_gradient = {
    "#7c3aed",
    "#c084fc",
    "#a21caf",
    "#f0abfc",
    "#be185d",
    "#f472b6",
    "#be123c",
    "#fb7185",
    "#991b1b",
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
        vim.api.nvim_set_hl(0, "GitStatusBlameGradient" .. index, { fg = color, bold = true })
    end
    vim.api.nvim_set_hl(0, "GitStatusStatusHeader", { link = "Title", default = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusMeta", { link = "Comment", default = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusPath", { link = "Normal", default = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusLabel", { link = "Comment", default = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusBranch", { fg = "#c084fc", bold = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusHash", { fg = "#f87171", bold = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusSubject", { link = "String", default = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusAdd", { link = "GitStatusAdd", default = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusChange", { link = "GitStatusChange", default = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusDelete", { link = "GitStatusDelete", default = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusRename", { link = "Identifier", default = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusUnmerged", { link = "ErrorMsg", default = true })
end

return M
