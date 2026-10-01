local M = {}

---Get active LSP clients
---@param filter? { bufnr?: number, name?: string, id?: number }
---@return vim.lsp.Client[]
function M.get_clients(filter)
  if vim.lsp.get_clients then
    return vim.lsp.get_clients(filter)
  elseif vim.lsp.get_active_clients then
    ---@diagnostic disable-next-line: deprecated
    return vim.lsp.get_active_clients(filter)
  end
  return {}
end

---Get single client by ID or name
---@param id_or_name number|string
---@return vim.lsp.Client|nil
function M.get_client(id_or_name)
  if type(id_or_name) == "number" then
    return vim.lsp.get_client_by_id(id_or_name)
  end
  local clients = M.get_clients()
  for _, client in ipairs(clients) do
    if client.name == id_or_name or tostring(client.id) == tostring(id_or_name) then
      return client
    end
  end
  return nil
end

---Get attached buffers for a client
---@param client_id number
---@return number[]
function M.get_attached_buffers(client_id)
  local client = M.get_client(client_id)
  if client and client.attached_buffers then
    local bufs = {}
    for bufnr, is_attached in pairs(client.attached_buffers) do
      if is_attached and vim.api.nvim_buf_is_valid(bufnr) then
        table.insert(bufs, bufnr)
      end
    end
    table.sort(bufs)
    return bufs
  end
  local bufs = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.lsp.buf_is_attached(buf, client_id) then
      table.insert(bufs, buf)
    end
  end
  return bufs
end

---Restart a single LSP client
---@param client_or_id vim.lsp.Client|number|string
---@param cb? fun(success: boolean)
function M.restart_client(client_or_id, cb)
  local client = type(client_or_id) == "table" and client_or_id or M.get_client(client_or_id)
  if not client then
    vim.notify("LSP client not found", vim.log.levels.ERROR, { title = "LSP Control Panel" })
    if cb then cb(false) end
    return
  end

  local client_name = client.name
  local client_config = vim.deepcopy(client.config)
  local attached_buffers = M.get_attached_buffers(client.id)

  vim.notify(string.format("Restarting LSP server '%s'...", client_name), vim.log.levels.INFO, { title = "LSP Control Panel" })

  -- Stop client
  if client.stop then
    client.stop()
  else
    vim.lsp.stop_client(client.id)
  end

  -- Wait briefly then restart
  vim.defer_fn(function()
    local restarted = false
    -- Attempt restart on all previously attached buffers
    for _, bufnr in ipairs(attached_buffers) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        if vim.lsp.start then
          vim.lsp.start(client_config, { bufnr = bufnr })
          restarted = true
        elseif vim.lsp.start_client then
          local new_id = vim.lsp.start_client(client_config)
          if new_id then
            vim.lsp.buf_attach_client(bufnr, new_id)
            restarted = true
          end
        end
      end
    end

    -- If no buffers were attached, start client globally if possible
    if #attached_buffers == 0 and vim.lsp.start_client then
      vim.lsp.start_client(client_config)
      restarted = true
    end

    vim.notify(string.format("LSP server '%s' restarted", client_name), vim.log.levels.INFO, { title = "LSP Control Panel" })
    if cb then cb(true) end
  end, 250)
end

---Restart all active LSP clients
---@param cb? fun()
function M.restart_all(cb)
  local clients = M.get_clients()
  if #clients == 0 then
    vim.notify("No active LSP clients to restart", vim.log.levels.WARN, { title = "LSP Control Panel" })
    if cb then cb() end
    return
  end

  for _, client in ipairs(clients) do
    M.restart_client(client)
  end
  if cb then cb() end
end

---Stop an LSP client
---@param client_or_id vim.lsp.Client|number|string
function M.stop_client(client_or_id)
  local client = type(client_or_id) == "table" and client_or_id or M.get_client(client_or_id)
  if not client then
    vim.notify("LSP client not found", vim.log.levels.ERROR, { title = "LSP Control Panel" })
    return
  end

  local client_name = client.name
  if client.stop then
    client.stop()
  else
    vim.lsp.stop_client(client.id)
  end
  vim.notify(string.format("Stopped LSP server '%s' (ID: %d)", client_name, client.id), vim.log.levels.INFO, { title = "LSP Control Panel" })
end

---Stop all active LSP clients
function M.stop_all()
  local clients = M.get_clients()
  if #clients == 0 then
    vim.notify("No active LSP clients to stop", vim.log.levels.WARN, { title = "LSP Control Panel" })
    return
  end

  for _, client in ipairs(clients) do
    if client.stop then
      client.stop()
    else
      vim.lsp.stop_client(client.id)
    end
  end
  vim.notify(string.format("Stopped %d LSP client(s)", #clients), vim.log.levels.INFO, { title = "LSP Control Panel" })
end

---Attach client to a buffer
---@param client_or_id vim.lsp.Client|number|string
---@param bufnr? number
function M.attach_client(client_or_id, bufnr)
  bufnr = bufnr or 0
  if bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end
  local client = type(client_or_id) == "table" and client_or_id or M.get_client(client_or_id)
  if not client then
    vim.notify("LSP client not found", vim.log.levels.ERROR, { title = "LSP Control Panel" })
    return
  end

  local success = vim.lsp.buf_attach_client(bufnr, client.id)
  if success then
    vim.notify(string.format("Attached '%s' to buffer #%d (%s)", client.name, bufnr, vim.api.nvim_buf_get_name(bufnr)), vim.log.levels.INFO, { title = "LSP Control Panel" })
  else
    vim.notify(string.format("Failed to attach '%s' to buffer #%d", client.name, bufnr), vim.log.levels.WARN, { title = "LSP Control Panel" })
  end
end

---Detach client from a buffer
---@param client_or_id vim.lsp.Client|number|string
---@param bufnr? number
function M.detach_client(client_or_id, bufnr)
  bufnr = bufnr or 0
  if bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end
  local client = type(client_or_id) == "table" and client_or_id or M.get_client(client_or_id)
  if not client then
    vim.notify("LSP client not found", vim.log.levels.ERROR, { title = "LSP Control Panel" })
    return
  end

  vim.lsp.buf_detach_client(bufnr, client.id)
  vim.notify(string.format("Detached '%s' from buffer #%d", client.name, bufnr), vim.log.levels.INFO, { title = "LSP Control Panel" })
end

---Inspect client capabilities in a human-friendly format
---@param client vim.lsp.Client
---@return { name: string, supported: boolean, details: string|nil }[]
function M.get_capabilities(client)
  local caps = client.server_capabilities or {}
  local list = {
    { name = "Hover Documentation", supported = caps.hoverProvider ~= nil and caps.hoverProvider ~= false },
    { name = "Completion", supported = caps.completionProvider ~= nil, details = caps.completionProvider and caps.completionProvider.triggerCharacters and ("Triggers: " .. table.concat(caps.completionProvider.triggerCharacters, " ")) or nil },
    { name = "Signature Help", supported = caps.signatureHelpProvider ~= nil, details = caps.signatureHelpProvider and caps.signatureHelpProvider.triggerCharacters and ("Triggers: " .. table.concat(caps.signatureHelpProvider.triggerCharacters, " ")) or nil },
    { name = "Goto Definition", supported = caps.definitionProvider ~= nil and caps.definitionProvider ~= false },
    { name = "Goto Type Definition", supported = caps.typeDefinitionProvider ~= nil and caps.typeDefinitionProvider ~= false },
    { name = "Goto Implementation", supported = caps.implementationProvider ~= nil and caps.implementationProvider ~= false },
    { name = "Goto Declaration", supported = caps.declarationProvider ~= nil and caps.declarationProvider ~= false },
    { name = "Find References", supported = caps.referencesProvider ~= nil and caps.referencesProvider ~= false },
    { name = "Document Highlight", supported = caps.documentHighlightProvider ~= nil and caps.documentHighlightProvider ~= false },
    { name = "Document Symbols", supported = caps.documentSymbolProvider ~= nil and caps.documentSymbolProvider ~= false },
    { name = "Workspace Symbols", supported = caps.workspaceSymbolProvider ~= nil and caps.workspaceSymbolProvider ~= false },
    { name = "Code Actions", supported = caps.codeActionProvider ~= nil and caps.codeActionProvider ~= false },
    { name = "Code Lens", supported = caps.codeLensProvider ~= nil },
    { name = "Document Formatting", supported = caps.documentFormattingProvider ~= nil and caps.documentFormattingProvider ~= false },
    { name = "Range Formatting", supported = caps.documentRangeFormattingProvider ~= nil and caps.documentRangeFormattingProvider ~= false },
    { name = "On-Type Formatting", supported = caps.documentOnTypeFormattingProvider ~= nil },
    { name = "Rename Symbol", supported = caps.renameProvider ~= nil and caps.renameProvider ~= false },
    { name = "Folding Ranges", supported = caps.foldingRangeProvider ~= nil and caps.foldingRangeProvider ~= false },
    { name = "Inlay Hints", supported = caps.inlayHintProvider ~= nil and caps.inlayHintProvider ~= false },
    { name = "Semantic Tokens", supported = caps.semanticTokensProvider ~= nil },
    { name = "Call Hierarchy", supported = caps.callHierarchyProvider ~= nil and caps.callHierarchyProvider ~= false },
    { name = "Type Hierarchy", supported = caps.typeHierarchyProvider ~= nil and caps.typeHierarchyProvider ~= false },
    { name = "Selection Range", supported = caps.selectionRangeProvider ~= nil and caps.selectionRangeProvider ~= false },
    { name = "Workspace Folders", supported = caps.workspace and caps.workspace.workspaceFolders and caps.workspace.workspaceFolders.supported == true },
  }
  return list
end

return M
