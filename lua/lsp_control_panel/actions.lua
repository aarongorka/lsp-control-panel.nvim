local M = {}
local config = require("lsp_control_panel.config")
local clients_mod = require("lsp_control_panel.clients")
local preview = require("lsp_control_panel.preview")

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

---View LSP log in a split window
function M.view_log()
  local path = get_log_path()
  if vim.fn.filereadable(path) == 0 then
    vim.notify("LSP log file does not exist yet: " .. path, vim.log.levels.WARN, { title = "LSP Control Panel" })
    return
  end
  vim.cmd("split " .. vim.fn.fnameescape(path))
  vim.bo.buftype = ""
  vim.cmd("normal! G")
end

---Clear LSP log file
function M.clear_log()
  local path = get_log_path()
  local f = io.open(path, "w")
  if f then
    f:write("")
    f:close()
    vim.notify("LSP log file cleared (" .. path .. ")", vim.log.levels.INFO, { title = "LSP Control Panel" })
  else
    vim.notify("Failed to clear LSP log file: " .. path, vim.log.levels.ERROR, { title = "LSP Control Panel" })
  end
end

---Set LSP log level
---@param level_name? string
---@param cb? fun()
function M.set_log_level(level_name, cb)
  local levels = { "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "OFF" }
  if level_name then
    local lvl = vim.log.levels[level_name] or (vim.lsp.log_levels and vim.lsp.log_levels[level_name])
    if lvl ~= nil and vim.lsp.log and vim.lsp.log.set_level then
      vim.lsp.log.set_level(lvl)
      vim.notify("LSP Log Level set to " .. level_name, vim.log.levels.INFO, { title = "LSP Control Panel" })
    elseif vim.lsp.set_log_level then
      ---@diagnostic disable-next-line: deprecated
      vim.lsp.set_log_level(level_name)
      vim.notify("LSP Log Level set to " .. level_name, vim.log.levels.INFO, { title = "LSP Control Panel" })
    end
    if cb then cb() end
    return
  end

  vim.ui.select(levels, {
    prompt = "Select LSP Log Level:",
  }, function(choice)
    if choice then
      M.set_log_level(choice, cb)
    end
  end)
end

---Toggle inlay hints for current buffer
---@param bufnr? number
function M.toggle_inlay_hints(bufnr)
  bufnr = bufnr or 0
  if not (vim.lsp.inlay_hint and vim.lsp.inlay_hint.enable and vim.lsp.inlay_hint.is_enabled) then
    vim.notify("Inlay hints are not supported in this Neovim version", vim.log.levels.WARN, { title = "LSP Control Panel" })
    return
  end
  local is_enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
  vim.lsp.inlay_hint.enable(not is_enabled, { bufnr = bufnr })
  local state = not is_enabled and "Enabled" or "Disabled"
  vim.notify(string.format("Inlay hints %s (Buffer #%d)", state, bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr), vim.log.levels.INFO, { title = "LSP Control Panel" })
end

---Toggle inlay hints globally
function M.toggle_inlay_hints_global()
  if not (vim.lsp.inlay_hint and vim.lsp.inlay_hint.enable and vim.lsp.inlay_hint.is_enabled) then
    vim.notify("Inlay hints are not supported in this Neovim version", vim.log.levels.WARN, { title = "LSP Control Panel" })
    return
  end
  local is_enabled = vim.lsp.inlay_hint.is_enabled()
  vim.lsp.inlay_hint.enable(not is_enabled)
  local state = not is_enabled and "Enabled" or "Disabled"
  vim.notify(string.format("Global Inlay hints %s", state), vim.log.levels.INFO, { title = "LSP Control Panel" })
end

---Toggle Code Lens
---@param bufnr? number
function M.toggle_codelens(bufnr)
  bufnr = bufnr or 0
  if vim.lsp.codelens and vim.lsp.codelens.refresh then
    vim.lsp.codelens.refresh({ bufnr = bufnr })
    vim.notify("Code Lens refreshed", vim.log.levels.INFO, { title = "LSP Control Panel" })
  else
    vim.notify("Code Lens not available", vim.log.levels.WARN, { title = "LSP Control Panel" })
  end
end

---Toggle Semantic Tokens
---@param bufnr? number
function M.toggle_semantic_tokens(bufnr)
  bufnr = bufnr or 0
  if vim.lsp.semantic_tokens and vim.lsp.semantic_tokens.force_refresh then
    vim.lsp.semantic_tokens.force_refresh(bufnr)
    vim.notify("Semantic tokens refreshed", vim.log.levels.INFO, { title = "LSP Control Panel" })
  else
    vim.notify("Semantic tokens not available", vim.log.levels.WARN, { title = "LSP Control Panel" })
  end
end

---Toggle Diagnostics
---@param bufnr? number
function M.toggle_diagnostics(bufnr)
  if vim.diagnostic.is_enabled and vim.diagnostic.enable then
    local current = vim.diagnostic.is_enabled({ bufnr = bufnr })
    vim.diagnostic.enable(not current, { bufnr = bufnr })
    local state = not current and "Enabled" or "Disabled"
    vim.notify("Diagnostics " .. state, vim.log.levels.INFO, { title = "LSP Control Panel" })
  else
    vim.notify("Diagnostic toggle not supported", vim.log.levels.WARN, { title = "LSP Control Panel" })
  end
end

---Change directory to client root
---@param client vim.lsp.Client
function M.cd_client_root(client)
  local root = client.root_dir or (client.config and client.config.root_dir)
  if root and vim.fn.isdirectory(root) == 1 then
    vim.cmd("cd " .. vim.fn.fnameescape(root))
    vim.notify("Changed working directory to: " .. root, vim.log.levels.INFO, { title = "LSP Control Panel" })
  else
    vim.notify("Root directory not available for client: " .. client.name, vim.log.levels.WARN, { title = "LSP Control Panel" })
  end
end

---Inspect client capabilities popup
---@param client vim.lsp.Client
function M.inspect_capabilities(client)
  local lines = preview.capabilities_preview(client)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].buftype = "nofile"

  local width = math.min(math.floor(vim.o.columns * 0.8), 100)
  local height = math.min(math.floor(vim.o.lines * 0.8), 30)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = string.format(" Capabilities: %s ", client.name),
    title_pos = "center",
  })

  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", function()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end, { buffer = buf, nowait = true, silent = true })
end

---Inspect client settings popup
---@param client vim.lsp.Client
function M.inspect_config(client)
  local lines = preview.config_preview(client)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].buftype = "nofile"

  local width = math.min(math.floor(vim.o.columns * 0.8), 100)
  local height = math.min(math.floor(vim.o.lines * 0.8), 30)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = string.format(" Config & Settings: %s ", client.name),
    title_pos = "center",
  })

  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", function()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end, { buffer = buf, nowait = true, silent = true })
end

---Build all items for the main control panel
---@param bufnr? number
---@return table[]
function M.get_main_panel_items(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local items = {}
  local icons = config.options.icons

  -- 1. Running LSP Clients (Per-Client management)
  local running_clients = clients_mod.get_clients()
  local buffer_clients = clients_mod.get_clients({ bufnr = bufnr })
  local buffer_client_ids = {}
  for _, c in ipairs(buffer_clients) do
    buffer_client_ids[c.id] = true
  end

  for _, client in ipairs(running_clients) do
    local is_attached = buffer_client_ids[client.id] == true
    local attached_count = #clients_mod.get_attached_buffers(client.id)
    local status_badge = is_attached and "Attached" or "Running"
    local root = client.root_dir or "no root"
    if #root > 35 then root = "..." .. root:sub(-32) end

    table.insert(items, {
      type = "client_menu",
      category = "Running Servers",
      icon = icons.client_running,
      title = string.format("%s (ID: %d)", client.name, client.id),
      detail = string.format("[%s | %d buf(s) | %s]", status_badge, attached_count, root),
      client = client,
      preview = function() return preview.client_preview(client) end,
      action = function()
        -- Handled by UI to open client sub-menu
      end,
    })
  end

  -- 2. General LSP Server Management
  table.insert(items, {
    type = "action",
    category = "Server Controls",
    icon = icons.restart,
    title = "Restart All Active LSP Clients",
    detail = string.format("Restart %d active language server(s)", #running_clients),
    preview = function()
      return preview.action_preview(icons.restart .. " Restart All Active LSP Clients",
        "Restarts all currently active LSP servers across all open buffers, reloading server configurations and re-establishing connections.")
    end,
    action = function() clients_mod.restart_all() end,
  })

  table.insert(items, {
    type = "action",
    category = "Server Controls",
    icon = icons.stop,
    title = "Stop All LSP Clients",
    detail = string.format("Stop %d active language server(s)", #running_clients),
    preview = function()
      return preview.action_preview(icons.stop .. " Stop All LSP Clients",
        "Terminates all running LSP client connections in the current Neovim session.")
    end,
    action = function() clients_mod.stop_all() end,
  })

  table.insert(items, {
    type = "action",
    category = "Server Controls",
    icon = icons.start,
    title = "Start / Enable LSP Server",
    detail = "Start a configured LSP client for the current buffer",
    preview = function()
      return preview.action_preview(icons.start .. " Start LSP Server",
        "Triggers LSP server startup for the current buffer's filetype using configured servers or Mason-lspconfig.")
    end,
    action = function()
      if vim.lsp.enable then
        vim.cmd("LspStart")
      else
        vim.cmd("edit")
      end
      vim.notify("Triggered LSP startup", vim.log.levels.INFO, { title = "LSP Control Panel" })
    end,
  })

  -- 3. Diagnostics & Logs & Health
  table.insert(items, {
    type = "action",
    category = "Logs & Diagnostics",
    icon = icons.log,
    title = "View LSP Log",
    detail = "Open LSP log file in a split window",
    preview = function() return preview.log_preview() end,
    action = function() M.view_log() end,
  })

  table.insert(items, {
    type = "action",
    category = "Logs & Diagnostics",
    icon = icons.cross,
    title = "Clear LSP Log File",
    detail = "Truncate and clear the current LSP log file",
    preview = function()
      return preview.action_preview(icons.cross .. " Clear LSP Log File",
        "Wipes all contents of the LSP log file to free disk space or start fresh debugging.")
    end,
    action = function() M.clear_log() end,
  })

  table.insert(items, {
    type = "action",
    category = "Logs & Diagnostics",
    icon = icons.general,
    title = "Set LSP Log Level",
    detail = "Change log verbosity (TRACE, DEBUG, INFO, WARN, ERROR, OFF)",
    preview = function()
      local lvl = vim.lsp.log and vim.lsp.log.get_level and vim.lsp.log.get_level() or "UNKNOWN"
      local level_names = { [0] = "TRACE", [1] = "DEBUG", [2] = "INFO", [3] = "WARN", [4] = "ERROR", [5] = "OFF" }
      return preview.action_preview(icons.general .. " Set LSP Log Level",
        "Changes runtime logging level for LSP servers in Neovim.", {
          string.format("**Current Level:** `%s`", level_names[lvl] or tostring(lvl)),
        })
    end,
    action = function() M.set_log_level() end,
  })

  table.insert(items, {
    type = "action",
    category = "Logs & Diagnostics",
    icon = icons.health,
    title = "Check LSP Health & Status",
    detail = "Run :checkhealth vim.lsp",
    preview = function()
      return preview.action_preview(icons.health .. " Check LSP Health",
        "Runs Neovim's health check for built-in LSP clients and configurations.")
    end,
    action = function() vim.cmd("checkhealth vim.lsp") end,
  })

  table.insert(items, {
    type = "action",
    category = "Logs & Diagnostics",
    icon = icons.package_mgr,
    title = "Open Mason Package Manager",
    detail = "Manage, install, and update LSP servers, formatters, and linters",
    preview = function()
      return preview.action_preview(icons.package_mgr .. " Mason LSP Package Manager",
        "Opens the Mason package manager interface to inspect and install language servers.")
    end,
    action = function()
      if package.loaded["mason"] or pcall(require, "mason") then
        vim.cmd("Mason")
      else
        vim.notify("Mason is not installed", vim.log.levels.WARN, { title = "LSP Control Panel" })
      end
    end,
  })

  -- 4. Feature Toggles
  local inlay_state = vim.lsp.inlay_hint and vim.lsp.inlay_hint.is_enabled and vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
  table.insert(items, {
    type = "action",
    category = "Feature Toggles",
    icon = icons.toggle,
    title = "Toggle Inlay Hints (Current Buffer)",
    detail = string.format("Status: %s", inlay_state and "Enabled" or "Disabled"),
    preview = function() return preview.toggle_preview("inlay_hints") end,
    action = function() M.toggle_inlay_hints(bufnr) end,
  })

  local global_inlay = vim.lsp.inlay_hint and vim.lsp.inlay_hint.is_enabled and vim.lsp.inlay_hint.is_enabled()
  table.insert(items, {
    type = "action",
    category = "Feature Toggles",
    icon = icons.toggle,
    title = "Toggle Inlay Hints (Global)",
    detail = string.format("Global Status: %s", global_inlay and "Enabled" or "Disabled"),
    preview = function() return preview.toggle_preview("inlay_hints") end,
    action = function() M.toggle_inlay_hints_global() end,
  })

  table.insert(items, {
    type = "action",
    category = "Feature Toggles",
    icon = icons.toggle,
    title = "Refresh / Toggle Code Lens",
    detail = "Refresh code lens annotations on current buffer",
    preview = function() return preview.toggle_preview("codelens") end,
    action = function() M.toggle_codelens(bufnr) end,
  })

  table.insert(items, {
    type = "action",
    category = "Feature Toggles",
    icon = icons.toggle,
    title = "Refresh Semantic Tokens Highlighting",
    detail = "Re-request semantic tokens from server",
    preview = function() return preview.toggle_preview("semantic_tokens") end,
    action = function() M.toggle_semantic_tokens(bufnr) end,
  })

  local diag_state = vim.diagnostic.is_enabled and vim.diagnostic.is_enabled()
  table.insert(items, {
    type = "action",
    category = "Feature Toggles",
    icon = icons.toggle,
    title = "Toggle Diagnostics Display",
    detail = string.format("Diagnostics: %s", diag_state and "Enabled" or "Disabled"),
    preview = function() return preview.toggle_preview("diagnostics") end,
    action = function() M.toggle_diagnostics(bufnr) end,
  })

  -- 5. Code & Buffer Operations (If LSP is attached to current buffer)
  if #buffer_clients > 0 then
    table.insert(items, {
      type = "action",
      category = "Code & Buffer Actions",
      icon = icons.code_action,
      title = "Code Actions",
      detail = "Trigger available code actions at cursor",
      preview = function()
        return preview.action_preview(icons.code_action .. " Code Actions",
          "Executes code actions, quick fixes, and refactorings provided by attached LSP servers for the cursor position.")
      end,
      action = function()
        if package.loaded["tiny-code-action"] or pcall(require, "tiny-code-action") then
          require("tiny-code-action").code_action()
        else
          vim.lsp.buf.code_action()
        end
      end,
    })

    table.insert(items, {
      type = "action",
      category = "Code & Buffer Actions",
      icon = icons.format,
      title = "Format Document",
      detail = "Format the current buffer with LSP / Conform",
      preview = function()
        return preview.action_preview(icons.format .. " Format Document",
          "Formats the current document using the attached language server formatting provider or active formatter.")
      end,
      action = function()
        if package.loaded["conform"] or pcall(require, "conform") then
          require("conform").format({ lsp_format = "fallback" })
        else
          vim.lsp.buf.format({ async = true })
        end
      end,
    })

    table.insert(items, {
      type = "action",
      category = "Code & Buffer Actions",
      icon = icons.rename,
      title = "Rename Symbol",
      detail = "Rename symbol under cursor across project",
      preview = function()
        return preview.action_preview(icons.rename .. " Rename Symbol",
          "Performs project-wide LSP symbol rename for the identifier under cursor.")
      end,
      action = function() vim.lsp.buf.rename() end,
    })

    table.insert(items, {
      type = "action",
      category = "Code & Buffer Actions",
      icon = icons.hover,
      title = "Hover Documentation",
      detail = "Show hover information / docstring for symbol under cursor",
      preview = function()
        return preview.action_preview(icons.hover .. " Hover Documentation",
          "Opens a hover window showing type signatures and documentation for the symbol under cursor.")
      end,
      action = function() vim.lsp.buf.hover() end,
    })

    table.insert(items, {
      type = "action",
      category = "Code & Buffer Actions",
      icon = icons.signature,
      title = "Signature Help",
      detail = "Display parameter signature help for function call",
      preview = function()
        return preview.action_preview(icons.signature .. " Signature Help",
          "Opens signature help showing active parameter info.")
      end,
      action = function() vim.lsp.buf.signature_help() end,
    })

    table.insert(items, {
      type = "action",
      category = "Code & Buffer Actions",
      icon = icons.symbol,
      title = "Document Symbols",
      detail = "Search and jump to symbols in the current buffer",
      preview = function()
        return preview.action_preview(icons.symbol .. " Document Symbols",
          "Lists all functions, methods, classes, variables, and symbols in the current document.")
      end,
      action = function()
        if _G.Snacks and Snacks.picker and Snacks.picker.lsp_symbols then
          Snacks.picker.lsp_symbols()
        else
          vim.lsp.buf.document_symbol()
        end
      end,
    })

    table.insert(items, {
      type = "action",
      category = "Code & Buffer Actions",
      icon = icons.symbol,
      title = "Workspace Symbols",
      detail = "Search and jump to symbols across entire workspace",
      preview = function()
        return preview.action_preview(icons.symbol .. " Workspace Symbols",
          "Searches symbol index across the entire workspace project.")
      end,
      action = function()
        if _G.Snacks and Snacks.picker and Snacks.picker.lsp_workspace_symbols then
          Snacks.picker.lsp_workspace_symbols()
        else
          vim.lsp.buf.workspace_symbol()
        end
      end,
    })

    table.insert(items, {
      type = "action",
      category = "Code & Buffer Actions",
      icon = icons.definition,
      title = "Goto Definition",
      detail = "Jump to symbol definition",
      preview = function()
        return preview.action_preview(icons.definition .. " Goto Definition",
          "Jumps to the definition of the symbol under cursor.")
      end,
      action = function()
        if _G.Snacks and Snacks.picker and Snacks.picker.lsp_definitions then
          Snacks.picker.lsp_definitions()
        else
          vim.lsp.buf.definition()
        end
      end,
    })

    table.insert(items, {
      type = "action",
      category = "Code & Buffer Actions",
      icon = icons.definition,
      title = "Goto Type Definition",
      detail = "Jump to symbol type definition",
      preview = function()
        return preview.action_preview(icons.definition .. " Goto Type Definition",
          "Jumps to the type definition of the symbol under cursor.")
      end,
      action = function()
        if _G.Snacks and Snacks.picker and Snacks.picker.lsp_type_definitions then
          Snacks.picker.lsp_type_definitions()
        else
          vim.lsp.buf.type_definition()
        end
      end,
    })

    table.insert(items, {
      type = "action",
      category = "Code & Buffer Actions",
      icon = icons.references,
      title = "Find References",
      detail = "Find all references to symbol under cursor",
      preview = function()
        return preview.action_preview(icons.references .. " Find References",
          "Finds all references to the symbol under cursor across all project files.")
      end,
      action = function()
        if _G.Snacks and Snacks.picker and Snacks.picker.lsp_references then
          Snacks.picker.lsp_references()
        else
          vim.lsp.buf.references()
        end
      end,
    })

    table.insert(items, {
      type = "action",
      category = "Code & Buffer Actions",
      icon = icons.hierarchy,
      title = "Call Hierarchy: Incoming Calls",
      detail = "List functions calling the symbol under cursor",
      preview = function()
        return preview.action_preview(icons.hierarchy .. " Incoming Calls",
          "Displays call hierarchy tree showing all callers of the function under cursor.")
      end,
      action = function() vim.lsp.buf.incoming_calls() end,
    })

    table.insert(items, {
      type = "action",
      category = "Code & Buffer Actions",
      icon = icons.hierarchy,
      title = "Call Hierarchy: Outgoing Calls",
      detail = "List functions called by the symbol under cursor",
      preview = function()
        return preview.action_preview(icons.hierarchy .. " Outgoing Calls",
          "Displays call hierarchy tree showing all functions called by the function under cursor.")
      end,
      action = function() vim.lsp.buf.outgoing_calls() end,
    })
  end

  -- User-defined extra actions
  if config.options.extra_actions and #config.options.extra_actions > 0 then
    for _, extra in ipairs(config.options.extra_actions) do
      table.insert(items, extra)
    end
  end

  return items
end

---Build items for a specific client sub-menu
---@param client vim.lsp.Client
---@param bufnr? number
---@return table[]
function M.get_client_items(client, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local items = {}
  local icons = config.options.icons
  local is_attached = vim.lsp.buf_is_attached(bufnr, client.id)

  table.insert(items, {
    category = client.name,
    icon = icons.restart,
    title = string.format("Restart %s", client.name),
    detail = string.format("Restart server '%s' (ID: %d)", client.name, client.id),
    preview = function() return preview.client_preview(client) end,
    action = function() clients_mod.restart_client(client) end,
  })

  table.insert(items, {
    category = client.name,
    icon = icons.stop,
    title = string.format("Stop %s", client.name),
    detail = string.format("Stop and terminate server '%s'", client.name),
    preview = function() return preview.client_preview(client) end,
    action = function() clients_mod.stop_client(client) end,
  })

  if is_attached then
    table.insert(items, {
      category = client.name,
      icon = icons.detach,
      title = "Detach from Current Buffer",
      detail = string.format("Detach %s from buffer #%d", client.name, bufnr),
      preview = function() return preview.client_preview(client) end,
      action = function() clients_mod.detach_client(client, bufnr) end,
    })
  else
    table.insert(items, {
      category = client.name,
      icon = icons.attach,
      title = "Attach to Current Buffer",
      detail = string.format("Attach %s to buffer #%d", client.name, bufnr),
      preview = function() return preview.client_preview(client) end,
      action = function() clients_mod.attach_client(client, bufnr) end,
    })
  end

  table.insert(items, {
    category = client.name,
    icon = icons.health,
    title = "View Server Capabilities",
    detail = "Inspect detailed capability tree and options",
    preview = function() return preview.capabilities_preview(client) end,
    action = function() M.inspect_capabilities(client) end,
  })

  table.insert(items, {
    category = client.name,
    icon = icons.general,
    title = "View Configuration & Settings",
    detail = "Inspect settings, init_options, and root patterns",
    preview = function() return preview.config_preview(client) end,
    action = function() M.inspect_config(client) end,
  })

  table.insert(items, {
    category = client.name,
    icon = icons.folder,
    title = "Change Working Directory to Root",
    detail = string.format("cd to %s", client.root_dir or "root dir"),
    preview = function() return preview.client_preview(client) end,
    action = function() M.cd_client_root(client) end,
  })

  table.insert(items, {
    category = client.name,
    icon = icons.log,
    title = "View Client Logs",
    detail = string.format("Filter log output for '%s'", client.name),
    preview = function() return preview.log_preview(client.name) end,
    action = function() M.view_log() end,
  })

  table.insert(items, {
    category = client.name,
    icon = icons.folder,
    title = "Add Workspace Folder",
    detail = "Add a directory to the server workspace folders",
    preview = function() return preview.client_preview(client) end,
    action = function() vim.lsp.buf.add_workspace_folder() end,
  })

  table.insert(items, {
    category = client.name,
    icon = icons.cross,
    title = "Remove Workspace Folder",
    detail = "Remove a directory from server workspace folders",
    preview = function() return preview.client_preview(client) end,
    action = function() vim.lsp.buf.remove_workspace_folder() end,
  })

  return items
end

return M
