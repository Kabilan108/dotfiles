-- Response parser for llama.cpp server completions

local M = {}

--- Split a string by newlines
---@param str string
---@return string[]
local function split_lines(str)
  if str == '' then
    return { '' }
  end
  local lines = {}
  for line in str:gmatch('([^\n]*)\n?') do
    if line ~= '' or #lines == 0 then
      table.insert(lines, line)
    end
  end
  -- Remove trailing empty string from gmatch if present
  if #lines > 1 and lines[#lines] == '' then
    table.remove(lines)
  end
  return lines
end

--- Check if string ends with a given suffix and remove it
---@param str string
---@param suffix string
---@return string, boolean
local function strip_suffix(str, suffix)
  if suffix == '' then
    return str, false
  end
  if str:sub(-#suffix) == suffix then
    return str:sub(1, -#suffix - 1), true
  end
  return str, false
end

--- Trim whitespace from both ends of a string
---@param str string
---@return string
local function trim(str)
  return str:match('^%s*(.-)%s*$') or str
end

--- Parse llama.cpp server response and extract completion
---@param response_body string JSON response from llama.cpp server
---@param opts table Options: stop_tokens, trim_whitespace, max_lines
---@return table Parsed result with content, lines, timings, etc.
function M.parse(response_body, opts)
  opts = opts or {}
  local stop_tokens = opts.stop_tokens or {}
  local trim_whitespace = opts.trim_whitespace or false
  local max_lines = opts.max_lines

  -- Default empty result structure
  local result = {
    content = '',
    lines = {},
    tokens_predicted = 0,
    stopped = false,
    stop_reason = 'length',
    timings = {},
    error = nil,
  }

  -- Try to parse JSON
  local ok, data = pcall(vim.json.decode, response_body)
  if not ok or type(data) ~= 'table' then
    result.error = 'Failed to parse JSON response'
    return result
  end

  -- Extract content
  local content = data.content or ''
  if content == '' and data.content == nil then
    -- Content field is missing
    result.content = ''
    result.lines = {}
    result.tokens_predicted = data.tokens_predicted or 0
    result.stopped = data.stop or false
    result.stop_reason = result.stopped and 'eos' or 'length'
    return result
  end

  -- Check for stop tokens and strip them
  local found_stop_token = false
  for _, token in ipairs(stop_tokens) do
    local stripped, found = strip_suffix(content, token)
    if found then
      content = stripped
      found_stop_token = true
      break
    end
  end

  -- Trim whitespace if requested
  if trim_whitespace then
    content = trim(content)
  end

  -- Split into lines
  local lines = split_lines(content)

  -- Apply max_lines limit
  if max_lines and max_lines > 0 and #lines > max_lines then
    local limited_lines = {}
    for i = 1, max_lines do
      table.insert(limited_lines, lines[i])
    end
    lines = limited_lines
    content = table.concat(lines, '\n')
  end

  -- Determine stop reason
  local stopped = data.stop or false
  local stop_reason
  if not stopped then
    stop_reason = 'length'
  elseif found_stop_token then
    stop_reason = 'stop_token'
  else
    stop_reason = 'eos'
  end

  -- Extract timings
  local timings = {}
  if data.timings then
    timings.prompt_ms = data.timings.prompt_ms
    timings.predicted_ms = data.timings.predicted_ms

    -- Calculate tokens per second
    if data.timings.predicted_ms and data.timings.predicted_n then
      local predicted_sec = data.timings.predicted_ms / 1000
      if predicted_sec > 0 then
        timings.tokens_per_second = math.floor(data.timings.predicted_n / predicted_sec + 0.5)
      end
    end
  end

  result.content = content
  result.lines = lines
  result.tokens_predicted = data.tokens_predicted or 0
  result.stopped = stopped
  result.stop_reason = stop_reason
  result.timings = timings

  return result
end

--- Get the first line from a parsed result
---@param result table Parsed result from parse()
---@return string First line of content
function M.first_line(result)
  if not result or not result.lines or #result.lines == 0 then
    return ''
  end
  return result.lines[1]
end

--- Get the first word from a parsed result
--- Preserves leading whitespace for indentation
---@param result table Parsed result from parse()
---@return string First word of content (with leading whitespace)
function M.first_word(result)
  if not result or not result.content or result.content == '' then
    return ''
  end

  local content = result.content

  -- Find leading whitespace
  local leading_ws = content:match('^(%s*)') or ''

  -- Find the first word after whitespace
  local rest = content:sub(#leading_ws + 1)

  -- Word is alphanumeric and underscores
  local word = rest:match('^([%w_]+)') or ''

  return leading_ws .. word
end

--- Check if a parsed result is empty (whitespace only)
---@param result table Parsed result from parse()
---@return boolean True if content is empty or whitespace-only
function M.is_empty(result)
  if not result or not result.content then
    return true
  end

  -- Check if content is empty or only whitespace
  return result.content:match('^%s*$') ~= nil
end

return M
