local config = require("lsp_control_panel.config")
local ui = require("lsp_control_panel.ui")

local M = {}

---Configure LSP Control Panel
---@param opts? table
function M.setup(opts)
  config.setup(opts)
end

---Open the LSP Control Panel
---@param opts? { bufnr?: number, client?: string|number }
function M.open(opts)
  opts = opts or {}
  if opts.client then
    ui.open_client_panel(opts.client, opts.bufnr)
  else
    ui.open_main_panel(opts.bufnr)
  end
end

return M
