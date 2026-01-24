-- sweep.nvim - Main module
-- AI autocomplete using Sweep's next-edit model with llama.cpp

local M = {}

local config = require('sweep.config')

-- State
M._enabled = false
M._initialized = false

--- Setup the plugin with user configuration
---@param opts? table User configuration options
function M.setup(opts)
  config.setup(opts)
  M._initialized = true

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
  require('sweep.autocmds').teardown()
  require('sweep.keymaps').teardown()
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

--- Show debug info
function M.debug()
  local debug_info = require('sweep.debug').get_info()
  vim.notify(vim.inspect(debug_info), vim.log.levels.INFO)
end

return M
