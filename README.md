# git_status.nvim

Standalone git signs, scrollbar markers, and blame for Neovim.

This plugin does not depend on `gitsigns.nvim`. It calls Git directly, parses
file hunks, renders colored signs on the left side of the code, renders a
VS Code-like scrollbar overlay on the right side, and provides a `:Blame`
command for the current file and a `:Status` file list for changed files.

## Features

- Git change bars on the left side of the editor.
- Git markers on the right scrollbar with line numbers, for example `110~`,
  `50+`, and `20-`.
- Cursor marker on the right scrollbar.
- `:Status` scratch list with Git-style status codes for changed, added,
  deleted, renamed, copied, untracked, and conflicted files.
- `:Blame` scratch view with commit hash, author, date, summary, and source
  line.
- No dependency on `gitsigns.nvim`.

## Requirements

- Neovim 0.10+
- Git

## Lazy.nvim

```lua
{
  "BMilliet/git_status.nvim",
  event = {
    "BufReadPost",
    "BufNewFile",
  },
  cmd = {
    "Blame",
    "Status",
    "GitStatusRefresh",
    "GitStatusToggle",
  },
  main = "git_status",
  opts = {},
}
```

With `opts = {}`, lazy.nvim calls:

```lua
require("git_status").setup({})
```

## Commands

- `:Blame` opens a blame view for the current file.
- `:Status` opens a changed-file list. Press `<CR>` or `o` on a file to open it,
  `s` for a split, `v` for a vertical split, `t` for a tab, and `q` to close.
- `:GitStatusRefresh` refreshes the signs and scrollbar.
- `:GitStatusToggle` enables or disables both signs and scrollbar.

## Code layout

- `lua/git_status/init.lua`: public API, setup, commands, and autocmds.
- `lua/git_status/config.lua`: defaults and option merging.
- `lua/git_status/git.lua`: repository discovery, diff parsing, hunks, status,
  and blame.
- `lua/git_status/signs.lua`: left-side git signs.
- `lua/git_status/scrollbar.lua`: right-side scrollbar overlay.
- `lua/git_status/status.lua`: `:Status` changed-file list.
- `lua/git_status/blame.lua`: `:Blame` scratch view.
- `lua/git_status/highlights.lua`: highlight groups.
- `lua/git_status/util.lua`: shared small helpers.

## Configuration

Defaults:

```lua
{
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
  },
  commands = {
    blame = "Blame",
    refresh = "GitStatusRefresh",
    status = "Status",
    toggle = "GitStatusToggle",
  },
}
```

`base = "HEAD"` means the plugin compares the current buffer contents against
the last commit. Unsaved edits are included, and untracked files are shown as
fully added.
