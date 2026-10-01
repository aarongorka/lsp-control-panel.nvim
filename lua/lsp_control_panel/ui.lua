local M = {}
local config = require("lsp_control_panel.config")
local actions = require("lsp_control_panel.actions")
local clients_mod = require("lsp_control_panel.clients")
local preview = require("lsp_control_panel.preview")

---Check if Snacks picker is available
---@return boolean
local function has_snacks_picker()
  return _G.Snacks ~= nil and Snacks.picker ~= nil and Snacks.picker.pick ~= nil
end

---Open Snacks picker interface
---@param title string
---@param items table[]
---@param opts? table
local function open_snacks_picker(title, items, opts)
  opts = opts or {}

  -- Ensure items have searchable `text`
  for _, item in ipairs(items) do
    if not item.text then
      local parts = {}
      if item.category then table.insert(parts, item.category) end
      if item.title then table.insert(parts, item.title) end
      if item.detail then table.insert(parts, item.detail) end
      item.text = table.concat(parts, " ")
    end
  end

  local picker_opts = {
    title = title,
    items = items,
    format = function(item)
      local chunks = {}
      if item.icon then
        table.insert(chunks, { item.icon .. " ", "Normal" })
      end
      if item.category then
        local cat_hl = config.options.highlights.category_general or "SnacksPickerDir"
        if item.category == "Running Servers" or item.category == "Active Servers" then
          cat_hl = config.options.highlights.status_active or "DiagnosticOk"
        elseif item.category == "Server Controls" then
          cat_hl = "DiagnosticInfo"
        elseif item.category == "Feature Toggles" then
          cat_hl = config.options.highlights.category_toggle or "DiagnosticWarn"
        elseif item.category == "Code & Buffer Actions" then
          cat_hl = config.options.highlights.category_buffer or "SnacksPickerSpecial"
        end
        table.insert(chunks, { string.format("[%s] ", item.category), cat_hl })
      end
      table.insert(chunks, { item.title or item.text, "Normal" })
      if item.detail then
        table.insert(chunks, { "  " .. item.detail, "Comment" })
      end
      return chunks
    end,
    confirm = function(picker, item)
      picker:close()
      if not item then return end
      if item.type == "client_menu" and item.client then
        M.open_client_panel(item.client, opts.bufnr)
      elseif item.type == "back_to_main" then
        M.open_main_panel(opts.bufnr)
      elseif item.action then
        item.action()
      end
    end,
  }

  if config.options.preview then
    picker_opts.preview = function(ctx)
      if ctx.item and ctx.item.preview then
        local lines = type(ctx.item.preview) == "function" and ctx.item.preview() or ctx.item.preview
        if type(lines) == "table" and ctx.preview then
          ctx.preview:set_lines(lines)
          if ctx.preview.highlight then
            ctx.preview:highlight({ ft = "markdown" })
          end
        end
      end
    end
  end

  Snacks.picker.pick(picker_opts)
end

---Open Fallback Floating Window / Select interface
---@param title string
---@param items table[]
---@param opts? table
local function open_fallback_select(title, items, opts)
  opts = opts or {}

  -- Format options for vim.ui.select
  vim.ui.select(items, {
    prompt = title .. " >",
    format_item = function(item)
      local icon = item.icon and (item.icon .. " ") or ""
      local cat = item.category and ("[" .. item.category .. "] ") or ""
      local name = item.title or item.text or ""
      local detail = item.detail and (" — " .. item.detail) or ""
      return string.format("%s%s%s%s", icon, cat, name, detail)
    end,
  }, function(choice)
    if not choice then return end
    if choice.type == "client_menu" and choice.client then
      M.open_client_panel(choice.client, opts.bufnr)
    elseif choice.type == "back_to_main" then
      M.open_main_panel(opts.bufnr)
    elseif choice.action then
      choice.action()
    end
  end)
end

---Open the main LSP control panel
---@param bufnr? number
function M.open_main_panel(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local items = actions.get_main_panel_items(bufnr)
  local title = " LSP Control Panel "

  local use_snacks = config.options.backend == "snacks" or (config.options.backend == "auto" and has_snacks_picker())
  if use_snacks then
    open_snacks_picker(title, items, { bufnr = bufnr })
  else
    open_fallback_select(title, items, { bufnr = bufnr })
  end
end

---Open a dedicated control panel for a single LSP client
---@param client_or_id vim.lsp.Client|number|string
---@param bufnr? number
function M.open_client_panel(client_or_id, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local client = type(client_or_id) == "table" and client_or_id or clients_mod.get_client(client_or_id)
  if not client then
    vim.notify("LSP client not found", vim.log.levels.ERROR, { title = "LSP Control Panel" })
    return
  end

  local items = actions.get_client_items(client, bufnr)
  -- Add a back navigation option
  table.insert(items, 1, {
    type = "back_to_main",
    category = "Navigation",
    icon = "⬅️",
    title = "Back to Main Panel",
    detail = "Return to main LSP control menu",
    preview = function()
      return preview.action_preview("⬅️ Back to Main Panel", "Return to the main LSP Control Panel overview.")
    end,
  })

  local title = string.format(" LSP Server: %s (ID: %d) ", client.name, client.id)
  local use_snacks = config.options.backend == "snacks" or (config.options.backend == "auto" and has_snacks_picker())
  if use_snacks then
    open_snacks_picker(title, items, { bufnr = bufnr })
  else
    open_fallback_select(title, items, { bufnr = bufnr })
  end
end

return M
