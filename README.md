# lsp-control-panel.nvim

An interactive control panel for Neovim's LSP clients. 100% vibe coded garbage that's just barely good enough to have a quick look and fix a misbehaving LSP if e.g. your autocomplete isn't working.

## Requirements

- Neovim 0.10 or later
- Optional: [snacks.nvim](https://github.com/folke/snacks.nvim) for the picker interface

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "aarongorka/lsp-control-panel.nvim",
  cmd = "LspControlPanel",
  keys = {
    { "<leader>cp", "<cmd>LspControlPanel<cr>", desc = "LSP Control Panel" },
  },
  opts = {},
}
```

## Command

Run `:LspControlPanel` to open the panel. The command also accepts:

| Command | Action |
| --- | --- |
| `:LspControlPanel <client>` | Open controls for a running client |
| `:LspControlPanel restart [client]` | Restart all clients or one client |
| `:LspControlPanel stop [client]` | Stop all clients or one client |
| `:LspControlPanel log` | Open the LSP log |
| `:LspControlPanel clear-log` | Clear the LSP log |
| `:LspControlPanel inlay-hints` | Toggle inlay hints for the current buffer |
| `:LspControlPanel diagnostics` | Toggle diagnostics for the current buffer |
| `:LspControlPanel health` | Run `:checkhealth vim.lsp` |
| `:LspControlPanel mason` | Open Mason |

## Configuration

The default UI backend uses Snacks when available and otherwise uses
`vim.ui.select`. Set `backend` to `"snacks"` or `"builtin"` to select a backend.

```lua
require("lsp_control_panel").setup({
  backend = "auto",
  preview = true,
  log_preview_lines = 40,
  extra_actions = {},
})
```

## Lua API

The Lua API provides setup and panel opening:

```lua
local lcp = require("lsp_control_panel")

lcp.setup({ backend = "auto" })
lcp.open()
lcp.open({ client = "lua_ls" })
```

Use Neovim's `vim.lsp` and `vim.diagnostic` APIs for direct LSP operations.
