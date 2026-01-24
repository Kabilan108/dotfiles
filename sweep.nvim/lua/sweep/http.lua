-- sweep.nvim - HTTP client module
-- Handles async HTTP communication with llama.cpp server

local M = {}

local curl = require('plenary.curl')

-- Default timeout in milliseconds
local DEFAULT_TIMEOUT = 5000

-- Track active requests for cancellation
-- Key: request_id, Value: { job = job, cancelled = false }
local active_requests = {}

-- Counter for generating unique request IDs
local request_counter = 0

--- Generate a unique request ID
---@return string
local function generate_request_id()
  request_counter = request_counter + 1
  return string.format('sweep_http_%d_%d', vim.loop.now(), request_counter)
end

--- Make a completion request to llama.cpp server
---@param opts table Request options
---@param opts.endpoint string Server endpoint URL
---@param opts.body table Request body to be JSON encoded
---@param opts.timeout? number Request timeout in milliseconds (default: 5000)
---@param opts.on_success function Callback for successful response: function(response)
---@param opts.on_error function Callback for error: function(error_message)
---@return table|nil handle Request handle for cancellation, or nil on error
function M.request(opts)
  if not opts or not opts.endpoint or not opts.body then
    if opts and opts.on_error then
      opts.on_error('Missing required options: endpoint and body')
    end
    return nil
  end

  local request_id = generate_request_id()
  local timeout = opts.timeout or DEFAULT_TIMEOUT

  -- Encode body as JSON
  local body_json
  local ok, result = pcall(vim.json.encode, opts.body)
  if not ok then
    if opts.on_error then
      opts.on_error('Failed to encode request body as JSON: ' .. tostring(result))
    end
    return nil
  end
  body_json = result

  -- Create the request entry before making the call
  active_requests[request_id] = {
    job = nil,
    cancelled = false,
  }

  -- Make the async HTTP request
  local job = curl.post({
    url = opts.endpoint,
    body = body_json,
    headers = {
      ['Content-Type'] = 'application/json',
      ['Accept'] = 'application/json',
    },
    timeout = timeout,
    callback = function(response)
      -- Check if request was cancelled
      local request = active_requests[request_id]
      if not request or request.cancelled then
        -- Request was cancelled, don't call callbacks
        active_requests[request_id] = nil
        return
      end

      -- Remove from active requests
      active_requests[request_id] = nil

      -- Handle response
      if not response then
        if opts.on_error then
          vim.schedule(function()
            opts.on_error('No response received from server')
          end)
        end
        return
      end

      -- Check for connection errors (status 0 usually indicates connection failure)
      if response.status == 0 then
        local error_msg = 'Connection failed'
        if response.exit then
          if response.exit == 7 then
            error_msg = 'Connection refused - is the server running?'
          elseif response.exit == 28 then
            error_msg = 'Request timed out'
          else
            error_msg = string.format('Connection error (exit code: %d)', response.exit)
          end
        end
        if opts.on_error then
          vim.schedule(function()
            opts.on_error(error_msg)
          end)
        end
        return
      end

      -- Check for HTTP error status
      if response.status < 200 or response.status >= 300 then
        if opts.on_error then
          vim.schedule(function()
            opts.on_error(string.format('HTTP error %d: %s', response.status, response.body or 'Unknown error'))
          end)
        end
        return
      end

      -- Parse JSON response
      local parse_ok, parsed = pcall(vim.json.decode, response.body)
      if not parse_ok then
        if opts.on_error then
          vim.schedule(function()
            opts.on_error('Failed to parse JSON response: ' .. tostring(parsed))
          end)
        end
        return
      end

      -- Success!
      if opts.on_success then
        vim.schedule(function()
          opts.on_success(parsed)
        end)
      end
    end,
  })

  -- Store the job reference
  if active_requests[request_id] then
    active_requests[request_id].job = job
  end

  -- Return handle for cancellation
  return {
    id = request_id,
  }
end

--- Cancel an in-flight request
---@param handle table|nil Request handle returned by request()
function M.cancel(handle)
  if not handle or not handle.id then
    return
  end

  local request = active_requests[handle.id]
  if not request then
    return
  end

  -- Mark as cancelled to prevent callbacks
  request.cancelled = true

  -- Shutdown the job if it exists
  if request.job and request.job.shutdown then
    pcall(function()
      request.job:shutdown()
    end)
  end

  -- Remove from active requests
  active_requests[handle.id] = nil
end

--- Cancel all pending requests
function M.cancel_all()
  for request_id, request in pairs(active_requests) do
    -- Mark as cancelled
    request.cancelled = true

    -- Shutdown the job if it exists
    if request.job and request.job.shutdown then
      pcall(function()
        request.job:shutdown()
      end)
    end
  end

  -- Clear all active requests
  active_requests = {}
end

--- Get the number of active requests (useful for debugging)
---@return number
function M.get_active_count()
  local count = 0
  for _ in pairs(active_requests) do
    count = count + 1
  end
  return count
end

return M
