-- sweep.nvim - Main module
-- AI autocomplete using Sweep's next-edit model with llama.cpp

local M = {}

local config = require('sweep.config')

-- State
M._enabled = false
M._initialized = false

--- Initialize all subsystems with current configuration
local function init_subsystems()
  local cfg = config.get()
  local ctx_config = cfg.context or {}

  -- Initialize ring buffer with config
  local ring = require('sweep.ring')
  ring.setup({
    max_chunks = ctx_config.max_ring_chunks or 16,
    chunk_size = ctx_config.chunk_size or 64,
  })

  -- Initialize cache
  local cache = require('sweep.cache')
  cache.setup({
    max_entries = 100,
    ttl_ms = 60000, -- 1 minute TTL
  })
end

--- Setup the plugin with user configuration
---@param opts? table User configuration options
function M.setup(opts)
  config.setup(opts)
  M._initialized = true

  -- Initialize all subsystems
  init_subsystems()

  if config.options.auto_enable then
    M.enable()
  end
end

--- Enable autocomplete
function M.enable()
  if not M._initialized then
    M.setup()
  end

  if M._enabled then
    return
  end

  M._enabled = true

  -- Enable completion module
  local completion = require('sweep.completion')
  completion.enable()

  -- Set up autocmds and keymaps
  require('sweep.autocmds').setup()
  require('sweep.keymaps').setup()

  if config.options.show_info then
    vim.notify('Sweep autocomplete enabled', vim.log.levels.INFO)
  end
end

--- Disable autocomplete
function M.disable()
  if not M._enabled then
    return
  end

  M._enabled = false

  -- Disable completion module (cancels pending requests)
  local completion = require('sweep.completion')
  completion.disable()

  -- Tear down autocmds and keymaps
  require('sweep.autocmds').teardown()
  require('sweep.keymaps').teardown()

  -- Clear UI
  require('sweep.ui').clear()

  if config.options.show_info then
    vim.notify('Sweep autocomplete disabled', vim.log.levels.INFO)
  end
end

--- Toggle autocomplete
function M.toggle()
  if M._enabled then
    M.disable()
  else
    M.enable()
  end
end

--- Check if enabled
---@return boolean
function M.is_enabled()
  return M._enabled
end

--- Show status
function M.status()
  local status = M._enabled and 'enabled' or 'disabled'
  vim.notify(string.format('Sweep autocomplete: %s', status), vim.log.levels.INFO)
end

--- Show debug info (using debug pane)
function M.debug()
  require('sweep.debug').show_pane()
end

--- Get debug info as table
---@return table
function M.debug_info()
  return require('sweep.debug').get_info()
end

--- Clear the completion cache
function M.clear_cache()
  local cache = require('sweep.cache')
  cache.clear()
  vim.notify('Sweep cache cleared', vim.log.levels.INFO)
end

--- Clear the ring buffer
function M.clear_ring()
  local ring = require('sweep.ring')
  ring.clear()
  vim.notify('Sweep ring buffer cleared', vim.log.levels.INFO)
end

return M
