local M = {}
local config = require("lsp_control_panel.config")
local clients_mod = require("lsp_control_panel.clients")

---Get log file path
---@return string
local function get_log_path()
  if vim.lsp.log and vim.lsp.log.get_filename then
    return vim.lsp.log.get_filename()
  elseif vim.lsp.get_log_path then
    ---@diagnostic disable-next-line: deprecated
    return vim.lsp.get_log_path()
  end
  return vim.fn.stdpath("state") .. "/lsp.log"
end

---Read tail lines from a file
---@param filepath string
---@param max_lines number
---@return string[]
local function read_tail_lines(filepath, max_lines)
  local file = io.open(filepath, "r")
  if not file then
    return { "Log file not found or empty: " .. filepath }
  end

  local lines = {}
  for line in file:lines() do
    table.insert(lines, line)
    if #lines > max_lines * 3 then
      local trimmed = {}
      for i = #lines - max_lines + 1, #lines do
        table.insert(trimmed, lines[i])
      end
      lines = trimmed
    end
  end
  file:close()

  if #lines == 0 then
    return { "Log file is currently empty (" .. filepath .. ")" }
  end

  local start_idx = math.max(1, #lines - max_lines + 1)
  local result = {}
  for i = start_idx, #lines do
    table.insert(result, lines[i])
  end
  return result
end

---Generate preview markdown lines for a client
---@param client vim.lsp.Client
---@return string[]
function M.client_preview(client)
  local lines = {}
  local icons = config.options.icons

  table.insert(lines, string.format("# %s %s (ID: %d)", icons.client_running, client.name, client.id))
  table.insert(lines, "")

  -- Root dir
  local root = client.root_dir or (client.config and client.config.root_dir) or "Not set"
  table.insert(lines, string.format("**Root Directory:** `%s`", root))

  -- Workspace folders
  if client.workspace_folders and #client.workspace_folders > 0 then
    table.insert(lines, "**Workspace Folders:**")
    for _, wf in ipairs(client.workspace_folders) do
      table.insert(lines, string.format("  - `%s` (%s)", wf.name or "unnamed", wf.uri or ""))
    end
  end
  table.insert(lines, "")

  -- Attached Buffers
  local bufs = clients_mod.get_attached_buffers(client.id)
  table.insert(lines, string.format("### %s Attached Buffers (%d)", icons.buffer, #bufs))
  if #bufs == 0 then
    table.insert(lines, "_No buffers currently attached_")
  else
    for _, bufnr in ipairs(bufs) do
      local name = vim.api.nvim_buf_get_name(bufnr)
      local ft = vim.bo[bufnr].filetype
      name = name ~= "" and vim.fn.fnamemodify(name, ":~:.") or "[No Name]"
      table.insert(lines, string.format("- **#%d** `%s` *(ft: %s)*", bufnr, name, ft ~= "" and ft or "none"))
    end
  end
  table.insert(lines, "")

  -- Capabilities Overview
  table.insert(lines, "### Capabilities")
  local caps = clients_mod.get_capabilities(client)
  for _, cap in ipairs(caps) do
    local mark = cap.supported and (icons.check .. " **YES**") or (icons.cross .. " NO")
    local detail = cap.details and (" (" .. cap.details .. ")") or ""
    table.insert(lines, string.format("- %s: %s%s", mark, cap.name, detail))
  end
  table.insert(lines, "")

  -- Command / Executable
  if client.config and client.config.cmd then
    local cmd_str = type(client.config.cmd) == "table" and table.concat(client.config.cmd, " ") or tostring(client.config.cmd)
    table.insert(lines, "### Server Command")
    table.insert(lines, "```sh")
    table.insert(lines, cmd_str)
    table.insert(lines, "```")
  end

  return lines
end

---Generate preview for log
---@param client_name? string
---@return string[]
function M.log_preview(client_name)
  local path = get_log_path()
  local lines = {}
  table.insert(lines, "# " .. config.options.icons.log .. " LSP Log Preview")
  table.insert(lines, string.format("**Path:** `%s`", path))
  local level = vim.lsp.log and vim.lsp.log.get_level and vim.lsp.log.get_level() or "UNKNOWN"
  local level_names = { [0] = "TRACE", [1] = "DEBUG", [2] = "INFO", [3] = "WARN", [4] = "ERROR", [5] = "OFF" }
  table.insert(lines, string.format("**Current Log Level:** `%s`", level_names[level] or tostring(level)))
  table.insert(lines, "")
  table.insert(lines, "### Recent Log Output")
  table.insert(lines, "```log")

  local raw_lines = read_tail_lines(path, config.options.log_preview_lines or 40)
  if client_name then
    local filtered = {}
    for _, l in ipairs(raw_lines) do
      if l:lower():find(client_name:lower(), 1, true) then
        table.insert(filtered, l)
      end
    end
    if #filtered == 0 then
      table.insert(lines, string.format("No log entries found for client '%s'", client_name))
    else
      for _, l in ipairs(filtered) do
        table.insert(lines, l)
      end
    end
  else
    for _, l in ipairs(raw_lines) do
      table.insert(lines, l)
    end
  end

  table.insert(lines, "```")
  return lines
end

---Generate preview for capabilities detail
---@param client vim.lsp.Client
---@return string[]
function M.capabilities_preview(client)
  local lines = {}
  table.insert(lines, string.format("# Server Capabilities: %s", client.name))
  table.insert(lines, "")
  table.insert(lines, "```lua")
  local formatted = vim.inspect(client.server_capabilities)
  for line in formatted:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  table.insert(lines, "```")
  return lines
end

---Generate preview for client config & settings
---@param client vim.lsp.Client
---@return string[]
function M.config_preview(client)
  local lines = {}
  table.insert(lines, string.format("# Client Configuration: %s", client.name))
  table.insert(lines, "")
  table.insert(lines, "### Settings")
  table.insert(lines, "```lua")
  local formatted = vim.inspect(client.config and client.config.settings or {})
  for line in formatted:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  table.insert(lines, "```")

  if client.config and client.config.init_options then
    table.insert(lines, "")
    table.insert(lines, "### Init Options")
    table.insert(lines, "```lua")
    local init_fmt = vim.inspect(client.config.init_options)
    for line in init_fmt:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
    table.insert(lines, "```")
  end

  return lines
end

---Generate preview for toggle items
---@param toggle_type string
---@return string[]
function M.toggle_preview(toggle_type)
  local lines = {}
  local icons = config.options.icons

  if toggle_type == "inlay_hints" then
    local buf_enabled = vim.lsp.inlay_hint and vim.lsp.inlay_hint.is_enabled and vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }) or false
    local global_enabled = vim.lsp.inlay_hint and vim.lsp.inlay_hint.is_enabled and vim.lsp.inlay_hint.is_enabled() or false
    table.insert(lines, "# " .. icons.toggle .. " Inlay Hints Toggle")
    table.insert(lines, "")
    table.insert(lines, string.format("- **Current Buffer Status:** %s", buf_enabled and (icons.check .. " Enabled") or (icons.cross .. " Disabled")))
    table.insert(lines, string.format("- **Global Status:** %s", global_enabled and (icons.check .. " Enabled") or (icons.cross .. " Disabled")))
    table.insert(lines, "")
    table.insert(lines, "Inlay hints display inline parameter names, type annotations, and return types directly in code without modifying file content.")
  elseif toggle_type == "codelens" then
    local enabled = vim.lsp.codelens and vim.lsp.codelens.is_enabled and vim.lsp.codelens.is_enabled({ bufnr = 0 })
    table.insert(lines, "# " .. icons.toggle .. " Code Lens Toggle & Refresh")
    table.insert(lines, "")
    table.insert(lines, string.format("- **Status:** %s", enabled ~= nil and (enabled and (icons.check .. " Enabled") or (icons.cross .. " Disabled")) or "Available"))
    table.insert(lines, "")
    table.insert(lines, "Code lenses provide actionable contextual information above declarations (e.g. references count, test runners).")
  elseif toggle_type == "semantic_tokens" then
    local enabled = vim.lsp.semantic_tokens and vim.lsp.semantic_tokens.is_enabled and vim.lsp.semantic_tokens.is_enabled(0)
    table.insert(lines, "# " .. icons.toggle .. " Semantic Tokens Highlighting")
    table.insert(lines, "")
    table.insert(lines, string.format("- **Status:** %s", enabled ~= nil and (enabled and (icons.check .. " Enabled") or (icons.cross .. " Disabled")) or "Active"))
    table.insert(lines, "")
    table.insert(lines, "Semantic tokens provide fine-grained syntax highlights powered directly by the language server.")
  elseif toggle_type == "diagnostics" then
    local enabled = vim.diagnostic.is_enabled and vim.diagnostic.is_enabled() or true
    table.insert(lines, "# " .. icons.toggle .. " Diagnostics Toggle")
    table.insert(lines, "")
    table.insert(lines, string.format("- **Global Diagnostics:** %s", enabled and (icons.check .. " Enabled") or (icons.cross .. " Disabled")))
    table.insert(lines, "")
    table.insert(lines, "Toggles error/warning/hint diagnostics virtual text, signs, and underline rendering.")
  end

  return lines
end

---Generate generic action preview
---@param title string
---@param desc string
---@param extra? string[]
---@return string[]
function M.action_preview(title, desc, extra)
  local lines = {}
  table.insert(lines, "# " .. title)
  table.insert(lines, "")
  table.insert(lines, desc)
  if extra and #extra > 0 then
    table.insert(lines, "")
    for _, l in ipairs(extra) do
      table.insert(lines, l)
    end
  end
  return lines
end

return M
