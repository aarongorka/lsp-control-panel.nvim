if vim.g.loaded_lsp_control_panel then
  return
end
vim.g.loaded_lsp_control_panel = 1

local actions = require("lsp_control_panel.actions")
local clients = require("lsp_control_panel.clients")
local ui = require("lsp_control_panel.ui")

local function complete_cmd(arg_lead, cmd_line, _)
  local args = vim.split(vim.trim(cmd_line), "%s+")
  local subcommands = {
    "open",
    "restart",
    "stop",
    "log",
    "clear-log",
    "inlay-hints",
    "diagnostics",
    "health",
    "mason",
  }

  local client_names = {}
  for _, c in ipairs(clients.get_clients()) do
    table.insert(client_names, c.name)
  end

  if #args <= 2 and not cmd_line:match("%s+$") then
    local candidates = vim.list_extend(vim.deepcopy(subcommands), client_names)
    return vim.tbl_filter(function(item)
      return item:lower():find(arg_lead:lower(), 1, true) == 1
    end, candidates)
  elseif (#args == 2 and cmd_line:match("%s+$")) or #args >= 3 then
    local subcmd = args[2]
    if subcmd == "restart" or subcmd == "stop" or subcmd == "open" then
      return vim.tbl_filter(function(item)
        return item:lower():find(arg_lead:lower(), 1, true) == 1
      end, client_names)
    end
  end

  return {}
end

local function handle_cmd(opts)
  local args = opts.fargs or {}

  if #args == 0 or args[1] == "open" and #args == 1 then
    ui.open_main_panel()
    return
  end

  local subcmd = args[1]
  local target = args[2]

  if subcmd == "restart" then
    if target then
      clients.restart_client(target)
    else
      clients.restart_all()
    end
  elseif subcmd == "stop" then
    if target then
      clients.stop_client(target)
    else
      clients.stop_all()
    end
  elseif subcmd == "log" then
    actions.view_log()
  elseif subcmd == "clear-log" then
    actions.clear_log()
  elseif subcmd == "inlay-hints" then
    actions.toggle_inlay_hints(0)
  elseif subcmd == "diagnostics" then
    actions.toggle_diagnostics(0)
  elseif subcmd == "health" then
    vim.cmd("checkhealth vim.lsp")
  elseif subcmd == "mason" then
    vim.cmd("Mason")
  else
    -- If argument matches a client name, open client sub-panel
    local client = clients.get_client(subcmd)
    if client then
      ui.open_client_panel(client)
    else
      ui.open_main_panel()
    end
  end
end

vim.api.nvim_create_user_command("LspControlPanel", handle_cmd, {
  nargs = "*",
  complete = complete_cmd,
  desc = "Open LSP Control Panel or execute LSP control actions",
})
