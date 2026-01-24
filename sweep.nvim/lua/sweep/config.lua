-- sweep.nvim - Configuration module

local M = {}

---@class SweepKeymaps
---@field trigger string Keymap to manually trigger completion
---@field accept_full string Keymap to accept full completion
---@field accept_line string Keymap to accept first line
---@field accept_word string Keymap to accept first word
---@field dismiss string Keymap to dismiss completion

---@class SweepContextConfig
---@field prefix_lines number Lines of context before cursor
---@field suffix_lines number Lines of context after cursor
---@field max_ring_chunks number Maximum chunks in ring buffer
---@field chunk_size number Lines per chunk
---@field use_lsp boolean Use LSP for rich context
---@field use_treesitter boolean Use treesitter for scope context

---@class SweepServerConfig
---@field endpoint string llama.cpp server endpoint
---@field timeout number Request timeout in milliseconds
---@field n_predict number Maximum tokens to predict
---@field temperature number Sampling temperature
---@field cache_prompt boolean Enable llama.cpp prompt caching

---@class SweepUIConfig
---@field show_info boolean Show completion info (tokens, latency)
---@field hl_group string Highlight group for ghost text
---@field info_hl_group string Highlight group for info text

---@class SweepConfig
---@field auto_enable boolean Auto-enable on setup
---@field debounce_ms number Debounce delay in milliseconds
---@field keymaps SweepKeymaps
---@field context SweepContextConfig
---@field server SweepServerConfig
---@field ui SweepUIConfig
---@field filetypes_exclude string[] Filetypes to exclude

---@type SweepConfig
M.defaults = {
  auto_enable = true,
  debounce_ms = 100,
  show_info = true,

  keymaps = {
    trigger = '<C-Space>',
    accept_full = '<Tab>',
    accept_line = '<C-l>',
    accept_word = '<C-Right>',
    dismiss = '<C-]>',
  },

  context = {
    prefix_lines = 100,
    suffix_lines = 50,
    max_ring_chunks = 16,
    chunk_size = 64,
    use_lsp = true,
    use_treesitter = true,
  },

  server = {
    endpoint = os.getenv('LLAMA_SERVER_URL') or 'http://localhost:8080',
    timeout = 5000,
    n_predict = 128,
    temperature = 0.1,
    cache_prompt = true,
  },

  ui = {
    show_info = true,
    hl_group = 'SweepGhostText',
    info_hl_group = 'SweepInfo',
  },

  filetypes_exclude = {
    'help',
    'TelescopePrompt',
    'lazy',
    'mason',
    'neo-tree',
    'NvimTree',
    'toggleterm',
  },
}

---@type SweepConfig
M.options = vim.deepcopy(M.defaults)

--- Setup configuration with user options
---@param opts? table User options to merge with defaults
function M.setup(opts)
  M.options = vim.tbl_deep_extend('force', vim.deepcopy(M.defaults), opts or {})

  -- Set up highlight groups
  vim.api.nvim_set_hl(0, 'SweepGhostText', { link = 'Comment', default = true })
  vim.api.nvim_set_hl(0, 'SweepInfo', { link = 'DiagnosticInfo', default = true })
end

--- Get current configuration
---@return SweepConfig
function M.get()
  return M.options
end

return M
