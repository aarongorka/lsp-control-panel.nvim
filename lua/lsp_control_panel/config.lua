local M = {}

---@class LspControlPanelConfig
---@field backend "auto"|"snacks"|"builtin" Backend UI to use ("auto" picks Snacks if available)
---@field preview boolean Enable preview window
---@field log_preview_lines number Number of lines to show in log preview
---@field icons table<string, string> Icon configuration
---@field highlights table<string, string> Highlight group configuration
---@field keymaps table<string, string> Custom keymaps for floating windows
---@field extra_actions table[] Extra custom actions to include in the panel
M.defaults = {
  backend = "auto",
  preview = true,
  log_preview_lines = 40,
  icons = {
    client_running = "🟢",
    client_stopped = "🔴",
    general = "⚙️",
    toggle = "💡",
    buffer = "📄",
    code_action = "⚡",
    format = "🪄",
    rename = "🏷️",
    hover = "📖",
    signature = "✍️",
    symbol = "🔎",
    hierarchy = "📞",
    definition = "🎯",
    references = "🔗",
    log = "📜",
    health = "🩺",
    package_mgr = "🧱",
    folder = "📁",
    attach = "📎",
    detach = "🔌",
    restart = "🔄",
    stop = "🛑",
    start = "🚀",
    check = "✓",
    cross = "✗",
  },
  highlights = {
    category_client = "SnacksPickerLabel",
    category_general = "SnacksPickerDir",
    category_toggle = "SnacksPickerSpecial",
    category_buffer = "SnacksPickerFile",
    status_active = "DiagnosticOk",
    status_inactive = "DiagnosticWarn",
    title = "Title",
  },
  extra_actions = {},
}

---@type LspControlPanelConfig
M.options = vim.deepcopy(M.defaults)

---Setup user configuration
---@param opts? table
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
