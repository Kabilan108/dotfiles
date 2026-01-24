-- sweep.nvim - Completion trigger and debouncing orchestration module
-- Ties together FIM, HTTP, parser, and UI modules

local M = {}

-- Module dependencies (lazy loaded)
local config
local http
local fim
local parser
local ui

-- Internal state
local state = {
  debounce_timer = nil,   -- Current debounce timer
  current_handle = nil,   -- Current HTTP request handle
  enabled = true,         -- Whether completion is enabled
  request_start_time = nil, -- For latency tracking
}

--- Load dependencies lazily
local function load_deps()
  if not config then
    config = require('sweep.config')
    http = require('sweep.http')
    fim = require('sweep.fim')
    parser = require('sweep.parser')
    ui = require('sweep.ui')
  end
end

--- Check if completion should be triggered for current buffer
---@return boolean
local function should_trigger()
  load_deps()

  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
  local cfg = config.get()

  -- Check excluded filetypes
  for _, excluded in ipairs(cfg.filetypes_exclude or {}) do
    if filetype == excluded then
      return false
    end
  end

  return state.enabled
end

--- Cancel the debounce timer if active
local function cancel_debounce_timer()
  if state.debounce_timer then
    if state.debounce_timer:is_active() then
      state.debounce_timer:stop()
    end
    state.debounce_timer = nil
  end
end

--- Cancel current HTTP request if any
local function cancel_current_request()
  load_deps()

  if state.current_handle then
    http.cancel(state.current_handle)
    state.current_handle = nil
  end
end

--- Handle successful completion response
---@param response table The parsed JSON response from llama.cpp
local function on_completion_success(response)
  load_deps()

  local cfg = config.get()

  -- Calculate latency
  local latency_ms = nil
  if state.request_start_time then
    latency_ms = math.floor((vim.loop.now() - state.request_start_time))
  end

  -- Parse the response
  local result = parser.parse(vim.json.encode(response), {
    stop_tokens = { '\n\n', '<|endoftext|>' },
  })

  -- Check if result is empty
  if parser.is_empty(result) then
    ui.clear()
    return
  end

  -- Get current cursor position
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1 -- Convert to 0-indexed
  local col = cursor[2]
  local bufnr = vim.api.nvim_get_current_buf()

  -- Build info for display
  local info = {
    tokens = result.tokens_predicted,
    latency_ms = latency_ms or (result.timings and result.timings.predicted_ms),
  }

  -- Show completion in UI
  ui.show({
    lines = result.lines,
    bufnr = bufnr,
    row = row,
    col = col,
    info = info,
  })

  -- Clear the request handle
  state.current_handle = nil
end

--- Handle completion error
---@param error_msg string The error message
local function on_completion_error(error_msg)
  load_deps()

  -- Log the error (optional)
  vim.schedule(function()
    -- Uncomment for debugging:
    -- vim.notify('Sweep completion error: ' .. error_msg, vim.log.levels.DEBUG)
  end)

  -- Clear UI on error
  ui.clear()

  -- Clear the request handle
  state.current_handle = nil
end

--- Make a completion request
local function make_request()
  load_deps()

  local cfg = config.get()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1 -- Convert to 0-indexed
  local col = cursor[2]

  -- Cancel any existing request
  cancel_current_request()

  -- Build FIM request
  local fim_request = fim.build_request({
    bufnr = bufnr,
    row = row,
    col = col,
    prefix_lines = cfg.context.prefix_lines,
    suffix_lines = cfg.context.suffix_lines,
  })

  -- Build the full request body for llama.cpp
  local request_body = {
    input_prefix = fim_request.input_prefix,
    input_suffix = fim_request.input_suffix,
    n_predict = cfg.server.n_predict,
    temperature = cfg.server.temperature,
    cache_prompt = cfg.server.cache_prompt,
    stop = { '\n\n', '<|endoftext|>' },
  }

  -- Track request start time
  state.request_start_time = vim.loop.now()

  -- Make HTTP request
  state.current_handle = http.request({
    endpoint = cfg.server.endpoint .. '/infill',
    body = request_body,
    timeout = cfg.server.timeout,
    on_success = function(response)
      vim.schedule(function()
        on_completion_success(response)
      end)
    end,
    on_error = function(err)
      vim.schedule(function()
        on_completion_error(err)
      end)
    end,
  })
end

--- Trigger a completion request with debouncing
--- Usually called from autocmd (e.g., CursorMovedI)
function M.trigger()
  if not should_trigger() then
    return
  end

  load_deps()
  local cfg = config.get()

  -- Cancel existing debounce timer
  cancel_debounce_timer()

  -- Create new debounce timer
  state.debounce_timer = vim.loop.new_timer()
  state.debounce_timer:start(cfg.debounce_ms, 0, vim.schedule_wrap(function()
    cancel_debounce_timer()
    make_request()
  end))
end

--- Manually trigger completion immediately (no debounce)
function M.manual_trigger()
  if not should_trigger() then
    return
  end

  -- Cancel any pending debounce
  cancel_debounce_timer()

  -- Make request immediately
  make_request()
end

--- Cancel current completion request and clear UI
function M.cancel()
  cancel_debounce_timer()
  cancel_current_request()

  load_deps()
  ui.clear()
end

--- Insert text at the stored completion position
---@param text string The text to insert
---@param completion_data table The completion data from UI
local function insert_text(text, completion_data)
  if not text or text == '' then
    return
  end

  local bufnr = completion_data.bufnr
  local row = completion_data.row
  local col = completion_data.col

  -- Split text into lines
  local lines = vim.split(text, '\n', { plain = true })

  -- Get the current line content
  local current_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''

  -- Build the new content
  local before_cursor = current_line:sub(1, col)
  local after_cursor = current_line:sub(col + 1)

  if #lines == 1 then
    -- Single line insertion
    local new_line = before_cursor .. lines[1] .. after_cursor
    vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { new_line })
    -- Move cursor to end of inserted text
    vim.api.nvim_win_set_cursor(0, { row + 1, col + #lines[1] })
  else
    -- Multi-line insertion
    local new_lines = {}
    -- First line: before_cursor + first part of insertion
    table.insert(new_lines, before_cursor .. lines[1])
    -- Middle lines: just the insertion content
    for i = 2, #lines - 1 do
      table.insert(new_lines, lines[i])
    end
    -- Last line: last part of insertion + after_cursor
    table.insert(new_lines, lines[#lines] .. after_cursor)

    vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, new_lines)
    -- Move cursor to end of inserted text on last inserted line
    local final_row = row + #lines
    local final_col = #lines[#lines]
    vim.api.nvim_win_set_cursor(0, { final_row, final_col })
  end
end

--- Accept the full completion
function M.accept_full()
  load_deps()

  local current = ui.get_current()
  if not current then
    return
  end

  -- Join all lines into text
  local text = table.concat(current.lines, '\n')

  -- Clear UI first
  ui.clear()

  -- Insert the text
  insert_text(text, current)
end

--- Accept only the first line of the completion
function M.accept_line()
  load_deps()

  local current = ui.get_current()
  if not current then
    return
  end

  -- Get only the first line
  local text = current.lines[1] or ''

  -- Clear UI first
  ui.clear()

  -- Insert the text
  insert_text(text, current)
end

--- Accept only the first word of the completion
function M.accept_word()
  load_deps()

  local current = ui.get_current()
  if not current then
    return
  end

  -- Get full content
  local content = table.concat(current.lines, '\n')

  -- Extract first word (preserving leading whitespace)
  local leading_ws = content:match('^(%s*)') or ''
  local rest = content:sub(#leading_ws + 1)
  local word = rest:match('^([%w_]+)') or ''
  local text = leading_ws .. word

  -- Clear UI first
  ui.clear()

  -- Insert the text
  insert_text(text, current)
end

--- Dismiss completion without inserting
function M.dismiss()
  cancel_debounce_timer()
  cancel_current_request()

  load_deps()
  ui.clear()
end

--- Enable completion
function M.enable()
  state.enabled = true
end

--- Disable completion
function M.disable()
  M.cancel()
  state.enabled = false
end

--- Toggle completion on/off
function M.toggle()
  if state.enabled then
    M.disable()
  else
    M.enable()
  end
end

--- Check if completion is enabled
---@return boolean
function M.is_enabled()
  return state.enabled
end

return M
