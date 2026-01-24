-- sweep.nvim - FIM (Fill-in-Middle) request builder module
-- Extracts context from the current buffer and builds FIM prompts

local M = {}

---@class FimTokens
---@field prefix string Token to mark prefix start
---@field suffix string Token to mark suffix start
---@field middle string Token to mark middle (completion) start

---@class FimRequestOptions
---@field bufnr number Buffer number
---@field row number 0-indexed cursor row
---@field col number 0-indexed cursor column
---@field prefix_lines number Lines of context before cursor
---@field suffix_lines number Lines of context after cursor
---@field format? 'infill'|'fim_tokens' Output format (default: 'infill')
---@field fim_tokens? FimTokens Custom FIM tokens (only used with 'fim_tokens' format)

---@class FimMetadata
---@field cursor_line string Full text of the current line
---@field indent string Detected indentation of current line
---@field filename string Filename (without path)
---@field filetype string Buffer filetype

---@class FimRequest
---@field input_prefix? string Code before cursor (infill format)
---@field input_suffix? string Code after cursor (infill format)
---@field prompt? string Full FIM prompt with tokens (fim_tokens format)
---@field metadata FimMetadata Additional context information

-- Default FIM tokens (CodeLlama/DeepSeek style)
local DEFAULT_FIM_TOKENS = {
  prefix = '<PRE>',
  suffix = '<SUF>',
  middle = '<MID>',
}

--- Detect the leading whitespace (indentation) of a line
---@param line string The line to analyze
---@return string The indentation string (spaces and/or tabs)
local function detect_indent(line)
  if not line or line == '' then
    return ''
  end
  local indent = line:match('^[ \t]*')
  return indent or ''
end

--- Extract filename from buffer path
---@param bufnr number Buffer number
---@return string Filename or empty string
local function get_filename(bufnr)
  local full_path = vim.api.nvim_buf_get_name(bufnr)
  if full_path == '' then
    return ''
  end
  return vim.fn.fnamemodify(full_path, ':t')
end

--- Get filetype for buffer
---@param bufnr number Buffer number
---@return string Filetype
local function get_filetype(bufnr)
  return vim.api.nvim_get_option_value('filetype', { buf = bufnr })
end

--- Build a FIM request from current buffer state
---@param opts FimRequestOptions Options for building the request
---@return FimRequest The FIM request object
function M.build_request(opts)
  local bufnr = opts.bufnr
  local row = opts.row
  local col = opts.col
  local prefix_lines = opts.prefix_lines
  local suffix_lines = opts.suffix_lines
  local format = opts.format or 'infill'
  local fim_tokens = opts.fim_tokens or DEFAULT_FIM_TOKENS

  -- Get all buffer lines
  local total_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local line_count = #total_lines

  -- Handle empty buffer
  if line_count == 0 then
    local metadata = {
      cursor_line = '',
      indent = '',
      filename = get_filename(bufnr),
      filetype = get_filetype(bufnr),
    }

    if format == 'fim_tokens' then
      return {
        prompt = fim_tokens.prefix .. fim_tokens.suffix .. fim_tokens.middle,
        metadata = metadata,
      }
    end

    return {
      input_prefix = '',
      input_suffix = '',
      metadata = metadata,
    }
  end

  -- Clamp row to valid range
  row = math.max(0, math.min(row, line_count - 1))

  -- Get current line and clamp column
  local current_line = total_lines[row + 1] or ''
  col = math.max(0, math.min(col, #current_line))

  -- Calculate prefix line range
  local prefix_start = math.max(0, row - prefix_lines)

  -- Build prefix: lines before cursor line + partial current line
  local prefix_parts = {}

  -- Add lines before cursor line
  for i = prefix_start, row - 1 do
    local line = total_lines[i + 1]
    if line then
      table.insert(prefix_parts, line)
    end
  end

  -- Add partial current line (up to cursor position)
  local current_line_prefix = current_line:sub(1, col)

  -- Join prefix lines with newlines, then add current line prefix
  local input_prefix
  if #prefix_parts > 0 then
    input_prefix = table.concat(prefix_parts, '\n') .. '\n' .. current_line_prefix
  else
    input_prefix = current_line_prefix
  end

  -- Calculate suffix line range
  local suffix_end = math.min(line_count - 1, row + suffix_lines)

  -- Build suffix: rest of current line + lines after cursor line
  local suffix_parts = {}

  -- Add rest of current line (from cursor to end)
  local current_line_suffix = current_line:sub(col + 1)
  table.insert(suffix_parts, current_line_suffix)

  -- Add lines after cursor line
  for i = row + 1, suffix_end do
    local line = total_lines[i + 1]
    if line then
      table.insert(suffix_parts, line)
    end
  end

  -- Join suffix parts with newlines
  local input_suffix = table.concat(suffix_parts, '\n')

  -- Build metadata
  local metadata = {
    cursor_line = current_line,
    indent = detect_indent(current_line),
    filename = get_filename(bufnr),
    filetype = get_filetype(bufnr),
  }

  -- Return in requested format
  if format == 'fim_tokens' then
    local prompt = fim_tokens.prefix .. input_prefix ..
                   fim_tokens.suffix .. input_suffix ..
                   fim_tokens.middle
    return {
      prompt = prompt,
      input_prefix = input_prefix,
      input_suffix = input_suffix,
      metadata = metadata,
    }
  end

  -- Default: infill format
  return {
    input_prefix = input_prefix,
    input_suffix = input_suffix,
    metadata = metadata,
  }
end

return M
