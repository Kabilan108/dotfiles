-- sweep.nvim - UI module for ghost text completion display
-- Displays completions as ghost text using extmarks

local M = {}

-- Namespace for extmarks
local ns = vim.api.nvim_create_namespace('sweep')

-- Current completion state
---@class SweepUIState
---@field lines string[]
---@field bufnr number
---@field row number
---@field col number
---@field mark_id number|nil
local state = {
  lines = {},
  bufnr = nil,
  row = nil,
  col = nil,
  mark_id = nil,
}

--- Clear all internal state
local function clear_state()
  state.lines = {}
  state.bufnr = nil
  state.row = nil
  state.col = nil
  state.mark_id = nil
end

--- Get the config module
---@return table
local function get_config()
  return require('sweep.config').get()
end

--- Format info text for display
---@param info table Info with tokens and latency_ms
---@return string
local function format_info(info)
  local parts = {}
  if info.tokens then
    table.insert(parts, string.format('%d tok', info.tokens))
  end
  if info.latency_ms then
    table.insert(parts, string.format('%dms', info.latency_ms))
  end
  if #parts > 0 then
    return ' [' .. table.concat(parts, ', ') .. ']'
  end
  return ''
end

--- Display a completion at the specified position
---@param opts table Options: lines, bufnr, row, col, info (optional)
function M.show(opts)
  local lines = opts.lines or {}
  local bufnr = opts.bufnr or 0
  local row = opts.row or 0
  local col = opts.col or 0
  local info = opts.info

  -- Resolve buffer 0 to actual buffer number
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  -- Clear any existing completion first
  M.clear()

  -- Handle empty lines - don't show anything
  if #lines == 0 then
    return
  end

  local config = get_config()
  local hl_group = config.ui.hl_group
  local info_hl_group = config.ui.info_hl_group
  local show_info = config.ui.show_info

  -- Build virt_text for the first line (inline ghost text)
  local virt_text = { { lines[1], hl_group } }

  -- Add info to the first line if provided and enabled
  if info and show_info then
    local info_text = format_info(info)
    if info_text ~= '' then
      table.insert(virt_text, { info_text, info_hl_group })
    end
  end

  -- Build virt_lines for additional lines
  local virt_lines = nil
  if #lines > 1 then
    virt_lines = {}
    for i = 2, #lines do
      table.insert(virt_lines, { { lines[i], hl_group } })
    end
  end

  -- Create the extmark
  local mark_opts = {
    virt_text = virt_text,
    virt_text_pos = 'overlay',
    hl_mode = 'combine',
  }

  if virt_lines then
    mark_opts.virt_lines = virt_lines
  end

  -- Set the extmark
  local ok, mark_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row, col, mark_opts)

  if ok then
    -- Update state
    state.lines = lines
    state.bufnr = bufnr
    state.row = row
    state.col = col
    state.mark_id = mark_id
  end
end

--- Clear current completion display
function M.clear()
  if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
    -- Clear all extmarks in our namespace for the buffer
    pcall(vim.api.nvim_buf_clear_namespace, state.bufnr, ns, 0, -1)
  end
  clear_state()
end

--- Check if completion is currently visible
---@return boolean
function M.is_visible()
  return state.mark_id ~= nil and state.bufnr ~= nil
end

--- Get current completion data for acceptance
---@return table|nil Completion data or nil if not visible
function M.get_current()
  if not M.is_visible() then
    return nil
  end

  return {
    lines = state.lines,
    bufnr = state.bufnr,
    row = state.row,
    col = state.col,
  }
end

return M
