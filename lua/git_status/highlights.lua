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

local blame_bg = "#15121c"
local blame_meta_bg = "#211629"

function M.define()
    vim.api.nvim_set_hl(0, "GitStatusAdd", { fg = "#7ee787", default = true })
    vim.api.nvim_set_hl(0, "GitStatusChange", { fg = "#d29922", default = true })
    vim.api.nvim_set_hl(0, "GitStatusDelete", { fg = "#f85149", default = true })
    vim.api.nvim_set_hl(0, "GitStatusCursor", { link = "CursorLineNr", default = true })
    vim.api.nvim_set_hl(0, "GitStatusBlameNormal", { fg = "#e6edf3", bg = blame_bg })
    vim.api.nvim_set_hl(0, "GitStatusBlameHeader", { fg = "#f0abfc", bg = blame_bg, bold = true })
    vim.api.nvim_set_hl(0, "GitStatusBlameMeta", { fg = "#8b949e", bg = blame_bg })
    vim.api.nvim_set_hl(0, "GitStatusBlameHash", { link = "Identifier", default = true })
    vim.api.nvim_set_hl(0, "GitStatusBlameAuthor", { link = "Statement", default = true })
    for index, color in ipairs(blame_gradient) do
        vim.api.nvim_set_hl(0, "GitStatusBlameGradient" .. index, {
            fg = color,
            bg = blame_meta_bg,
            bold = true,
        })
    end
    vim.api.nvim_set_hl(0, "GitStatusStatusHeader", { link = "Title", default = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusMeta", { link = "Comment", default = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusPath", { link = "Normal", default = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusNormal", { fg = "#e6edf3", bg = "#1b1d2a" })
    vim.api.nvim_set_hl(0, "GitStatusStatusBorder", { fg = "#2dd4bf", bg = "#1b1d2a" })
    vim.api.nvim_set_hl(0, "GitStatusStatusTitle", { fg = "#2dd4bf", bg = "#1b1d2a", bold = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusCursorLine", { bg = "#262a3a" })
    vim.api.nvim_set_hl(0, "GitStatusStatusIndex", { fg = "#8b949e", bg = "#1b1d2a" })
    vim.api.nvim_set_hl(0, "GitStatusStatusAdd", { fg = "#7ee787", bg = "#1b1d2a", bold = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusChange", { fg = "#d29922", bg = "#1b1d2a", bold = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusDelete", { fg = "#f85149", bg = "#1b1d2a", bold = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusRename", { fg = "#79c0ff", bg = "#1b1d2a", bold = true })
    vim.api.nvim_set_hl(0, "GitStatusStatusUnmerged", { fg = "#ff7b72", bg = "#1b1d2a", bold = true })
    vim.api.nvim_set_hl(0, "GitStatusConflictNormal", { fg = "#e6edf3", bg = "#1b1d2a" })
    vim.api.nvim_set_hl(0, "GitStatusConflictBorder", { fg = "#f85149", bg = "#1b1d2a" })
    vim.api.nvim_set_hl(0, "GitStatusConflictTitle", { fg = "#f85149", bg = "#1b1d2a", bold = true })
    vim.api.nvim_set_hl(0, "GitStatusConflictCursorLine", { bg = "#262a3a" })
    vim.api.nvim_set_hl(0, "GitStatusConflictFooter", { fg = "#8b949e", bg = "#1b1d2a" })
    vim.api.nvim_set_hl(0, "GitStatusConflictIndex", { fg = "#8b949e", bg = "#1b1d2a" })
    vim.api.nvim_set_hl(0, "GitStatusConflictPath", { link = "Normal", default = true })
    vim.api.nvim_set_hl(0, "GitStatusConflictMeta", { link = "Comment", default = true })
    vim.api.nvim_set_hl(0, "GitStatusConflictLabel", { fg = "#d29922", bg = "#1b1d2a", bold = true })
    vim.api.nvim_set_hl(0, "GitStatusConflictModified", { fg = "#d29922", bg = "#1b1d2a", bold = true })
    vim.api.nvim_set_hl(0, "GitStatusConflictAdded", { fg = "#7ee787", bg = "#1b1d2a", bold = true })
    vim.api.nvim_set_hl(0, "GitStatusConflictDeleted", { fg = "#f85149", bg = "#1b1d2a", bold = true })
    vim.api.nvim_set_hl(0, "GitStatusConflictOurs", { fg = "#7ee787", bg = "#1b1d2a", bold = true })
    vim.api.nvim_set_hl(0, "GitStatusConflictTheirs", { fg = "#79c0ff", bg = "#1b1d2a", bold = true })
    vim.api.nvim_set_hl(0, "GitStatusConflictUnresolved", { fg = "#f85149", bg = "#1b1d2a", bold = true })
    vim.api.nvim_set_hl(0, "GitStatusConflictResolved", { fg = "#7ee787", bg = "#1b1d2a", bold = true })
    vim.api.nvim_set_hl(0, "GitStatusConflictMarker", { fg = "#f85149", bg = "#2d1517", bold = true })
    vim.api.nvim_set_hl(0, "GitStatusConflictOursBlock", { bg = "#16231a" })
    vim.api.nvim_set_hl(0, "GitStatusConflictTheirsBlock", { bg = "#132238" })
    vim.api.nvim_set_hl(0, "GitStatusConflictCurrentMarker", { fg = "#ff7b72", bg = "#5f2028", bold = true })
    vim.api.nvim_set_hl(0, "GitStatusConflictCurrentOursBlock", { bg = "#244b2f" })
    vim.api.nvim_set_hl(0, "GitStatusConflictCurrentTheirsBlock", { bg = "#173d5f" })
end

return M
