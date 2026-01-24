-- sweep.nvim - Debug module for inspecting plugin state
-- Provides introspection and debugging utilities

local M = {}

-- Debug pane state
local pane_state = {
  bufnr = nil,
  winid = nil,
}

--- Get comprehensive debug information about the plugin state
---@return table Debug info with enabled, completion, cache, ring, and config sections
function M.get_info()
  local ok_config, config = pcall(require, 'sweep.config')
  local ok_completion, completion = pcall(require, 'sweep.completion')
  local ok_cache, cache = pcall(require, 'sweep.cache')
  local ok_ring, ring = pcall(require, 'sweep.ring')
  local ok_init, sweep = pcall(require, 'sweep')

  local info = {
    enabled = false,
    completion = {
      pending = false,
      last_latency_ms = nil,
    },
    cache = {
      entries = 0,
      hits = 0,
      misses = 0,
    },
    ring = {
      chunks = 0,
      filetypes = {},
    },
    config = {},
  }

  -- Get enabled state from main module
  if ok_init and sweep then
    info.enabled = sweep.is_enabled()
  end

  -- Get completion state
  if ok_completion and completion.get_state then
    local comp_state = completion.get_state()
    info.completion = {
      pending = comp_state.pending or false,
      last_latency_ms = comp_state.last_latency_ms,
    }
  end

  -- Get cache stats
  if ok_cache and cache.stats then
    local cache_stats = cache.stats()
    info.cache = {
      entries = cache_stats.entries or 0,
      hits = cache_stats.hits or 0,
      misses = cache_stats.misses or 0,
    }
  end

  -- Get ring buffer stats
  if ok_ring and ring.stats then
    local ring_stats = ring.stats()
    info.ring = {
      chunks = ring_stats.count or 0,
      filetypes = ring_stats.filetypes or {},
    }
  end

  -- Get current config
  if ok_config and config.get then
    info.config = config.get()
  end

  return info
end

--- Format debug info for display
---@param info table Debug info from get_info()
---@return string[] Lines for display
local function format_debug_info(info)
  local lines = {}

  table.insert(lines, '=== Sweep Debug Info ===')
  table.insert(lines, '')

  -- Status
  table.insert(lines, 'Status:')
  table.insert(lines, string.format('  Enabled: %s', info.enabled and 'yes' or 'no'))
  table.insert(lines, '')

  -- Completion
  table.insert(lines, 'Completion:')
  table.insert(lines, string.format('  Pending: %s', info.completion.pending and 'yes' or 'no'))
  if info.completion.last_latency_ms then
    table.insert(lines, string.format('  Last latency: %dms', info.completion.last_latency_ms))
  else
    table.insert(lines, '  Last latency: N/A')
  end
  table.insert(lines, '')

  -- Cache
  table.insert(lines, 'Cache:')
  table.insert(lines, string.format('  Entries: %d', info.cache.entries))
  table.insert(lines, string.format('  Hits: %d', info.cache.hits))
  table.insert(lines, string.format('  Misses: %d', info.cache.misses))
  local total = info.cache.hits + info.cache.misses
  if total > 0 then
    local hit_rate = math.floor((info.cache.hits / total) * 100)
    table.insert(lines, string.format('  Hit rate: %d%%', hit_rate))
  end
  table.insert(lines, '')

  -- Ring buffer
  table.insert(lines, 'Ring Buffer:')
  table.insert(lines, string.format('  Chunks: %d', info.ring.chunks))
  if info.ring.filetypes and next(info.ring.filetypes) then
    table.insert(lines, '  Filetypes:')
    for ft, count in pairs(info.ring.filetypes) do
      table.insert(lines, string.format('    %s: %d', ft, count))
    end
  end
  table.insert(lines, '')

  -- Config summary
  table.insert(lines, 'Config:')
  if info.config then
    table.insert(lines, string.format('  Debounce: %dms', info.config.debounce_ms or 0))
    if info.config.server then
      table.insert(lines, string.format('  Endpoint: %s', info.config.server.endpoint or 'N/A'))
      table.insert(lines, string.format('  Timeout: %dms', info.config.server.timeout or 0))
      table.insert(lines, string.format('  Max tokens: %d', info.config.server.n_predict or 0))
    end
    if info.config.context then
      table.insert(lines, string.format('  Prefix lines: %d', info.config.context.prefix_lines or 0))
      table.insert(lines, string.format('  Suffix lines: %d', info.config.context.suffix_lines or 0))
      table.insert(lines, string.format('  Use LSP: %s', info.config.context.use_lsp and 'yes' or 'no'))
      table.insert(lines, string.format('  Use Treesitter: %s', info.config.context.use_treesitter and 'yes' or 'no'))
    end
    if info.config.filetypes_exclude and #info.config.filetypes_exclude > 0 then
      table.insert(lines, string.format('  Excluded filetypes: %s', table.concat(info.config.filetypes_exclude, ', ')))
    end
  end
  table.insert(lines, '')

  table.insert(lines, '(Press q or <Esc> to close)')

  return lines
end

--- Check if debug pane is currently open
---@return boolean
function M.is_pane_open()
  return pane_state.winid ~= nil
    and vim.api.nvim_win_is_valid(pane_state.winid)
end

--- Close the debug pane
function M.close_pane()
  if pane_state.winid and vim.api.nvim_win_is_valid(pane_state.winid) then
    vim.api.nvim_win_close(pane_state.winid, true)
  end
  if pane_state.bufnr and vim.api.nvim_buf_is_valid(pane_state.bufnr) then
    vim.api.nvim_buf_delete(pane_state.bufnr, { force = true })
  end
  pane_state.winid = nil
  pane_state.bufnr = nil
end

--- Show debug pane with current plugin state
function M.show_pane()
  -- Close existing pane if open
  if M.is_pane_open() then
    M.close_pane()
  end

  -- Get debug info
  local info = M.get_info()
  local lines = format_debug_info(info)

  -- Calculate window dimensions
  local width = 50
  local height = #lines

  -- Get editor dimensions
  local editor_width = vim.o.columns
  local editor_height = vim.o.lines

  -- Center the window
  local row = math.floor((editor_height - height) / 2)
  local col = math.floor((editor_width - width) / 2)

  -- Create buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Buffer options
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr })
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
  vim.api.nvim_set_option_value('filetype', 'sweep-debug', { buf = bufnr })

  -- Create floating window
  local winid = vim.api.nvim_open_win(bufnr, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Sweep Debug ',
    title_pos = 'center',
  })

  -- Window options
  vim.api.nvim_set_option_value('wrap', false, { win = winid })
  vim.api.nvim_set_option_value('cursorline', true, { win = winid })

  -- Store state
  pane_state.bufnr = bufnr
  pane_state.winid = winid

  -- Set up keymaps to close
  local close_keys = { 'q', '<Esc>' }
  for _, key in ipairs(close_keys) do
    vim.keymap.set('n', key, function()
      M.close_pane()
    end, { buffer = bufnr, nowait = true })
  end

  -- Auto-close on BufLeave
  vim.api.nvim_create_autocmd('BufLeave', {
    buffer = bufnr,
    once = true,
    callback = function()
      M.close_pane()
    end,
  })
end

--- Refresh the debug pane if open
function M.refresh_pane()
  if M.is_pane_open() then
    M.show_pane()
  end
end

--- Log a debug message (if debug mode is enabled)
---@param msg string Message to log
---@param level? number Vim log level (default: vim.log.levels.DEBUG)
function M.log(msg, level)
  level = level or vim.log.levels.DEBUG
  local ok, config = pcall(require, 'sweep.config')
  if ok then
    local cfg = config.get()
    if cfg.debug then
      vim.notify('[sweep] ' .. msg, level)
    end
  end
end

return M
