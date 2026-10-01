---@type LazySpec
return {
  "aarongorka/lsp-control-panel.nvim",
  cmd = "LspControlPanel",
  keys = {
    { "<Leader>cp", "<cmd>LspControlPanel<cr>", desc = "LSP Control Panel" },
  },
  opts = {
    -- backend = "auto", -- "auto" (Snacks picker if available, else vim.ui.select), "snacks", or "builtin"
    -- preview = true,   -- live preview pane with capabilities, logs, and server details
  },
}
