-- sweep.nvim - Autocmds module for completion triggers and ring buffer population
-- Sets up autocommands for triggering completions and collecting context

local M = {}

-- Augroup name
local AUGROUP_NAME = 'sweep'

-- Track if autocmds are set up
local is_setup = false

--- Get the config module
---@return table
local function get_config()
  return require('sweep.config').get()
end

--- Check if the current filetype is excluded from completion
---@param bufnr number Buffer number
---@return boolean
local function is_filetype_excluded(bufnr)
  local config = get_config()
  local filetype = vim.bo[bufnr].filetype

  for _, excluded in ipairs(config.filetypes_exclude or {}) do
    if filetype == excluded then
      return true
    end
  end

  return false
end

--- Add visible portion of buffer to ring buffer
---@param source string Source identifier (e.g., 'buffer_enter', 'buffer_leave', 'save')
local function add_visible_to_ring(source)
  local ring = require('sweep.ring')
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local filetype = vim.bo[bufnr].filetype

  -- Get visible line range
  local first = vim.fn.line('w0')
  local last = vim.fn.line('w$')

  -- Get lines (nvim_buf_get_lines is 0-indexed)
  local ok, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, first - 1, last, false)
  if not ok or #lines == 0 then
    return
  end

  ring.add({
    content = table.concat(lines, '\n'),
    filename = filename,
    filetype = filetype,
    source = source,
  })
end

--- Handle CursorMovedI event - trigger completion
---@param bufnr number
local function on_cursor_moved_i(bufnr)
  if is_filetype_excluded(bufnr) then
    return
  end

  local completion = require('sweep.completion')
  completion.trigger()
end

--- Handle InsertLeave event - cancel and clear
local function on_insert_leave()
  local completion = require('sweep.completion')
  local ui = require('sweep.ui')

  completion.cancel()
  ui.clear()
end

--- Handle BufLeave event - cancel completion and add to ring
---@param bufnr number
local function on_buf_leave(bufnr)
  local completion = require('sweep.completion')
  local ui = require('sweep.ui')

  -- Cancel any pending completion
  completion.cancel()
  ui.clear()

  -- Add visible content to ring buffer
  add_visible_to_ring('buffer_leave')
end

--- Handle BufEnter event - add visible content to ring
local function on_buf_enter()
  add_visible_to_ring('buffer_enter')
end

--- Handle BufWritePost event - add visible content to ring
local function on_buf_write_post()
  add_visible_to_ring('save')
end

--- Handle TextYankPost event - add yanked text to ring
local function on_text_yank_post()
  local event = vim.v.event
  if not event or not event.regcontents then
    return
  end

  local ring = require('sweep.ring')
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local filetype = vim.bo[bufnr].filetype

  local content = table.concat(event.regcontents, '\n')
  if content == '' then
    return
  end

  ring.add({
    content = content,
    filename = filename,
    filetype = filetype,
    source = 'yank',
  })
end

--- Set up all autocmds for sweep
function M.setup()
  -- Create augroup with clear = true to make setup idempotent
  local group = vim.api.nvim_create_augroup(AUGROUP_NAME, { clear = true })

  -- CursorMovedI - trigger completion (debounced by completion module)
  vim.api.nvim_create_autocmd('CursorMovedI', {
    group = group,
    callback = function(args)
      on_cursor_moved_i(args.buf)
    end,
    desc = 'Sweep: trigger completion on cursor move in insert mode',
  })

  -- InsertLeave - cancel pending completion and clear UI
  vim.api.nvim_create_autocmd('InsertLeave', {
    group = group,
    callback = function()
      on_insert_leave()
    end,
    desc = 'Sweep: cancel completion on insert leave',
  })

  -- BufLeave - cancel pending completion, clear UI, and add to ring
  vim.api.nvim_create_autocmd('BufLeave', {
    group = group,
    callback = function(args)
      on_buf_leave(args.buf)
    end,
    desc = 'Sweep: handle buffer leave',
  })

  -- BufEnter - add visible portion to ring buffer
  vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    callback = function()
      on_buf_enter()
    end,
    desc = 'Sweep: add visible content to ring on buffer enter',
  })

  -- BufWritePost - add visible portion to ring buffer
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = group,
    callback = function()
      on_buf_write_post()
    end,
    desc = 'Sweep: add visible content to ring on save',
  })

  -- TextYankPost - add yanked text to ring buffer
  vim.api.nvim_create_autocmd('TextYankPost', {
    group = group,
    callback = function()
      on_text_yank_post()
    end,
    desc = 'Sweep: add yanked text to ring buffer',
  })

  is_setup = true
end

--- Remove all autocmds for sweep
function M.teardown()
  -- Clear the augroup (removes all autocmds in it)
  pcall(vim.api.nvim_create_augroup, AUGROUP_NAME, { clear = true })
  is_setup = false
end

--- Check if autocmds are set up
---@return boolean
function M.is_setup()
  return is_setup
end

return M
