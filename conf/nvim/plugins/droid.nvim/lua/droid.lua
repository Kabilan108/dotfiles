---@diagnostic disable: deprecated
-- based on yacineMTB/dingllm.nvim


-- set up the ability to have multi turn convos with delimiters between user and assistant messages
-- need to be able to dynamically update the message history from the bufffer
-- potentially persistence to sqlite or json
--
-- also, telescope picker for selecting the active llm instead of having different keymaps

local Job = require 'plenary.job'

---@class CompletionOpts
---@field base_url string
---@field model string
---@field api_key_name string
---@field system_prompt string
---@field replace boolean

--- retrieves an api key from environment variables
---@param name string
---@return string?
local function get_api_key(name)
  return os.getenv(name)
end

--- writes a string at the current cursor position in the buffer
---@param str string
---@return nil
local function write_string_at_cursor(str)
  -- vim.schedule ensures this runs on the main event loop (thread-safe for async operations)
  vim.schedule(function()
    local current_window = vim.api.nvim_get_current_win()
    local cursor_position = vim.api.nvim_win_get_cursor(current_window)
    local row, col = cursor_position[1], cursor_position[2]

    -- split incoming text into lines for proper insertion
    local lines = vim.split(str, '\n')
    -- nvim_put: 'c' = character-wise, true = after cursor, true = follow cursor
    vim.api.nvim_put(lines, 'c', true, true)

    -- calculate new cursor position after text insertion
    local num_lines = #lines
    local last_line_length = #lines[num_lines]
    vim.api.nvim_win_set_cursor(current_window, { row + num_lines - 1, col + last_line_length })
  end)
end

--- validates and sets default values for completion options
---@param opts CompletionOpts?
---@return CompletionOpts
local function validate_opts(opts)
  opts = opts or {}
  opts.base_url = opts.base_url or "https://openrouter.ai/api/v1"
  opts.model = opts.model or "openai/gpt-4.1"
  opts.api_key_name = opts.api_key_name or nil
  opts.replace = opts.replace == nil and false or opts.replace
  opts.system_prompt = opts.system_prompt or
      "You are a tsundere uwu anime. Yell at me for not setting my configuration for my llm plugin correctly"

  if not opts.api_key_name or opts.api_key_name == "" then
    error("api_key_name must be provided in CompletionOpts")
  end
  return opts
end

local M = {}

--- extracts the prompt text from visual selection or text until cursor
---@param opts CompletionOpts
---@return string
M.get_prompt = function(opts)
  local visual_lines = M.get_visual_selection()
  local prompt = ''

  if visual_lines then
    prompt = table.concat(visual_lines, '\n')
    if opts.replace then
      -- delete selected text if we're in replace mode (llm will overwrite selection)
      vim.api.nvim_command 'normal! d'
      vim.api.nvim_command 'normal! k'
    else
      -- exit visual mode without modifying selection (llm appends after selection)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', false, true, true), 'nx', false)
    end
  else
    -- use all text from buffer start to cursor as context
    prompt = M.get_lines_until_cursor()
  end

  return prompt
end

--- gets all lines from the start of buffer until the current cursor position
---@return string concatenated text from buffer start to cursor
function M.get_lines_until_cursor()
  local current_buffer = vim.api.nvim_get_current_buf()
  local current_window = vim.api.nvim_get_current_win()
  local cursor_position = vim.api.nvim_win_get_cursor(current_window)
  local row = cursor_position[1]

  local lines = vim.api.nvim_buf_get_lines(current_buffer, 0, row, true)

  return table.concat(lines, '\n')
end

--- extracts the currently selected text in visual mode
---@return table? Array selected lines
function M.get_visual_selection()
  -- get selection start ('v') and end ('.') positions
  local _, srow, scol = unpack(vim.fn.getpos 'v')
  local _, erow, ecol = unpack(vim.fn.getpos '.')

  -- line-wise visual mode (V): select entire lines
  if vim.fn.mode() == 'V' then
    if srow > erow then
      return vim.api.nvim_buf_get_lines(0, erow - 1, srow, true)
    else
      return vim.api.nvim_buf_get_lines(0, srow - 1, erow, true)
    end
  end

  -- character-wise visual mode (v): select partial text within/across lines
  if vim.fn.mode() == 'v' then
    if srow < erow or (srow == erow and scol <= ecol) then
      return vim.api.nvim_buf_get_text(0, srow - 1, scol - 1, erow - 1, ecol, {})
    else
      return vim.api.nvim_buf_get_text(0, erow - 1, ecol - 1, srow - 1, scol, {})
    end
  end

  -- block-wise visual mode (ctrl-v): select rectangular text blocks
  if vim.fn.mode() == '\22' then
    local lines = {}
    -- normalize selection boundaries
    if srow > erow then
      srow, erow = erow, srow
    end
    if scol > ecol then
      scol, ecol = ecol, scol
    end
    -- extract text from each row within the column range
    for i = srow, erow do
      table.insert(lines,
        vim.api.nvim_buf_get_text(0, i - 1, math.min(scol - 1, ecol), i - 1, math.max(scol - 1, ecol), {})[1])
    end
    return lines
  end
end

--- creates curl arguments for anthropic api requests
---@param opts CompletionOpts
---@param prompt string
---@return string[] Array curl command arguments
function M.make_anthropic_spec_curl_args(opts, prompt)
  local base_url = opts.base_url
  local api_key = opts.api_key_name and get_api_key(opts.api_key_name)
  local data = {
    system = opts.system_prompt,
    messages = { { role = 'user', content = prompt } },
    model = opts.model,
    stream = true,
    max_tokens = 4096,
  }
  local args = { '-N', '-X', 'POST', '-H', 'Content-Type: application/json', '-d', vim.json.encode(data) }
  if api_key then
    table.insert(args, '-H')
    table.insert(args, 'x-api-key: ' .. api_key)
    table.insert(args, '-H')
    table.insert(args, 'anthropic-version: 2023-06-01')
  end
  table.insert(args, base_url)
  return args
end

--- creates curl arguments for openai-compatible api requests
---@param opts CompletionOpts
---@param prompt string
---@return string[] Array curl command arguments
function M.make_openai_spec_curl_args(opts, prompt)
  local base_url = opts.base_url
  local api_key = opts.api_key_name and get_api_key(opts.api_key_name)
  local data = {
    messages = { { role = 'system', content = opts.system_prompt }, { role = 'user', content = prompt } },
    model = opts.model,
    temperature = 0.7,
    stream = true,
  }
  local args = { '-N', '-X', 'POST', '-H', 'Content-Type: application/json', '-d', vim.json.encode(data) }
  if api_key then
    table.insert(args, '-H')
    table.insert(args, 'Authorization: Bearer ' .. api_key)
  end
  table.insert(args, base_url)
  return args
end

--- handles streaming response data from anthropic api
---@param data_stream string the json data from the stream
---@param event_state string? the current sse event type
---@return nil
function M.handle_anthropic_spec_data(data_stream, event_state)
  if event_state == 'content_block_delta' then
    local json = vim.json.decode(data_stream)
    if json.delta and json.delta.text then
      write_string_at_cursor(json.delta.text)
    end
  end
end

--- handles streaming response data from openai-compatible apis
---@param data_stream string the json data from the stream
---@return nil
function M.handle_openai_spec_data(data_stream)
  if data_stream:match '"delta":' then
    local json = vim.json.decode(data_stream)
    if json.choices and json.choices[1] and json.choices[1].delta then
      local content = json.choices[1].delta.content
      if content then
        write_string_at_cursor(content)
      end
    end
  end
end

local group = vim.api.nvim_create_augroup('Droid_AutoGroup', { clear = true })
local active_job = nil

--- invokes an llm api and streams the response directly into the editor
---@param opts CompletionOpts
---@param make_curl_args fun(opts: CompletionOpts, prompt: string): string[] function to create curl arguments
---@param handle_data_fn fun(data: string, event_state: string?): nil function to handle streaming data
---@return table? the active job instance
function M.invoke_llm_and_stream_into_editor(opts, make_curl_args, handle_data_fn)
  vim.api.nvim_clear_autocmds { group = group }

  opts = validate_opts(opts)
  local prompt = M.get_prompt(opts)
  -- TODO: implement parsing for file, lsp, folder references

  local args = make_curl_args(opts, prompt)
  local curr_event_state = nil

  -- parse server-sent events (sse) format: "event: type\ndata: json"
  local function parse_and_call(line)
    local event = line:match '^event: (.+)$'
    if event then
      curr_event_state = event
      return
    end
    local data_match = line:match '^data: (.+)$'
    if data_match then
      handle_data_fn(data_match, curr_event_state)
    end
  end

  -- cancel any existing job before starting new one
  if active_job then
    active_job:shutdown()
    active_job = nil
  end

  -- plenary.job provides async process management for long-running curl streams
  active_job = Job:new {
    command = 'curl',
    args = args,
    on_stdout = function(_, out)
      parse_and_call(out)
    end,
    on_stderr = function(_, _) end,
    on_exit = function()
      active_job = nil
    end,
  }

  active_job:start()

  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'Droid_Escape',
    callback = function()
      if active_job then
        active_job:shutdown()
        print 'LLM streaming cancelled'
        active_job = nil
      end
    end,
  })

  return active_job
end

return M
