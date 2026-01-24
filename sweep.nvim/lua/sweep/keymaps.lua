-- sweep.nvim - Keymaps module for completion interaction
-- Manages keymaps for accepting, dismissing, and triggering completions

local M = {}

-- Track setup state
local is_setup_flag = false

-- Track which buffers have keymaps set
local buffer_keymaps = {}

--- Get the config module
---@return table
local function get_config()
  return require('sweep.config').get()
end

--- Get the completion module
---@return table
local function get_completion()
  return require('sweep.completion')
end

--- Get the UI module
---@return table
local function get_ui()
  return require('sweep.ui')
end

--- Create an expr mapping callback for conditional keymaps
--- Returns empty string if action taken, otherwise returns the key for passthrough
---@param key string The key to pass through if completion not visible
---@param action function The action to take when completion is visible
---@return function
local function make_conditional_callback(key, action)
  return function()
    if get_ui().is_visible() then
      action()
      return ''
    else
      -- Pass through the original key
      return vim.api.nvim_replace_termcodes(key, true, false, true)
    end
  end
end

--- Create a simple callback (no visibility check)
---@param action function The action to take
---@return function
local function make_callback(action)
  return function()
    action()
    return ''
  end
end

--- Set up keymaps on the current buffer
---@param bufnr? number Buffer number (defaults to current buffer)
local function setup_buffer_keymaps(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local cfg = get_config()
  local km = cfg.keymaps

  -- Track keymaps for this buffer
  buffer_keymaps[bufnr] = buffer_keymaps[bufnr] or {}

  -- Trigger keymap (no visibility check needed)
  vim.keymap.set('i', km.trigger, make_callback(function()
    get_completion().manual_trigger()
  end), {
    buffer = bufnr,
    expr = true,
    desc = 'Sweep: trigger completion',
    silent = true,
  })
  table.insert(buffer_keymaps[bufnr], { mode = 'i', lhs = km.trigger })

  -- Accept full keymap (only when visible)
  vim.keymap.set('i', km.accept_full, make_conditional_callback(km.accept_full, function()
    get_completion().accept_full()
  end), {
    buffer = bufnr,
    expr = true,
    desc = 'Sweep: accept full completion',
    silent = true,
  })
  table.insert(buffer_keymaps[bufnr], { mode = 'i', lhs = km.accept_full })

  -- Accept line keymap (only when visible)
  vim.keymap.set('i', km.accept_line, make_conditional_callback(km.accept_line, function()
    get_completion().accept_line()
  end), {
    buffer = bufnr,
    expr = true,
    desc = 'Sweep: accept first line',
    silent = true,
  })
  table.insert(buffer_keymaps[bufnr], { mode = 'i', lhs = km.accept_line })

  -- Accept word keymap (only when visible)
  vim.keymap.set('i', km.accept_word, make_conditional_callback(km.accept_word, function()
    get_completion().accept_word()
  end), {
    buffer = bufnr,
    expr = true,
    desc = 'Sweep: accept first word',
    silent = true,
  })
  table.insert(buffer_keymaps[bufnr], { mode = 'i', lhs = km.accept_word })

  -- Dismiss keymap (only when visible)
  vim.keymap.set('i', km.dismiss, make_conditional_callback(km.dismiss, function()
    get_completion().dismiss()
  end), {
    buffer = bufnr,
    expr = true,
    desc = 'Sweep: dismiss completion',
    silent = true,
  })
  table.insert(buffer_keymaps[bufnr], { mode = 'i', lhs = km.dismiss })
end

--- Remove keymaps from a buffer
---@param bufnr number Buffer number
local function teardown_buffer_keymaps(bufnr)
  if not buffer_keymaps[bufnr] then
    return
  end

  if not vim.api.nvim_buf_is_valid(bufnr) then
    buffer_keymaps[bufnr] = nil
    return
  end

  for _, keymap in ipairs(buffer_keymaps[bufnr]) do
    pcall(vim.keymap.del, keymap.mode, keymap.lhs, { buffer = bufnr })
  end

  buffer_keymaps[bufnr] = nil
end

--- Set up keymaps for completion interaction
--- Called when enabling the plugin
function M.setup()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Clear any existing keymaps on this buffer first
  teardown_buffer_keymaps(bufnr)

  -- Set up new keymaps
  setup_buffer_keymaps(bufnr)

  is_setup_flag = true
end

--- Remove keymaps
--- Called when disabling the plugin
function M.teardown()
  -- Remove keymaps from all tracked buffers
  for bufnr, _ in pairs(buffer_keymaps) do
    teardown_buffer_keymaps(bufnr)
  end

  buffer_keymaps = {}
  is_setup_flag = false
end

--- Check if keymaps are set up
---@return boolean
function M.is_setup()
  return is_setup_flag
end

--- Set up keymaps for a specific buffer
--- Can be called from autocmds when entering a new buffer
---@param bufnr? number Buffer number (defaults to current buffer)
function M.setup_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Don't set up if already done for this buffer
  if buffer_keymaps[bufnr] and #buffer_keymaps[bufnr] > 0 then
    return
  end

  setup_buffer_keymaps(bufnr)
end

--- Remove keymaps from a specific buffer
---@param bufnr? number Buffer number (defaults to current buffer)
function M.teardown_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  teardown_buffer_keymaps(bufnr)
end

return M
