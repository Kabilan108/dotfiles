local M = {}

local curl = require('plenary.curl')

local mnotify = require('mini.notify')
mnotify.setup()
local notify = mnotify.make_notify({
  ERROR = { duration = 5000 },
  WARN = { duration = 3000 },
})

---@class pyrepl.Config
---@field port integer pyrepl server port
M.config = {
  port = tonumber(os.getenv("PYREPL_PORT")) or 5000,
}

local function get_url()
  return 'http://localhost:' .. M.config.port
end

function M.setup(opts)
  M.config = vim.tbl_extend('force', M.config, opts or {})
  vim.api.nvim_create_user_command('RunInPyrepl', function() M.run_selected_lines() end, {})
  vim.api.nvim_create_user_command('ResetPyrepl', function() M.reset_repl() end, {})
end

---@return boolean
function M.is_server_alive()
  local ok, resp = pcall(curl.get, get_url() .. '/health', {
    timeout = 1000,
    on_error = function() end
  })
  return ok and resp and resp.status == 200
end

---@param code string[]
function M.send_to_repl(code)
  if not M.is_server_alive() then
    notify('pyrepl server not running on ' .. get_url(), vim.log.levels.ERROR)
    return
  end

  -- Make the request
  local ok, resp = pcall(curl.post, get_url() .. '/execute', {
    body = vim.fn.json_encode({ code = code }),
    headers = { content_type = 'application/json' },
    timeout = 5000,
  })

  -- Handle pcall errors (network issues, etc.)
  if not ok then
    notify('Failed to connect to pyrepl server: ' .. tostring(resp), vim.log.levels.ERROR)
    return
  end

  -- Handle specific HTTP status codes
  if resp.status == 409 then -- 409 Conflict indicates server busy
    -- Try to parse error message from body, fallback to default
    local body_data = vim.fn.json_decode(resp.body)
    local err_msg = "pyrepl server is busy executing previous code"
    if type(body_data) == 'table' and body_data.error then
      err_msg = "pyrepl: " .. body_data.error
    end
    notify(err_msg, vim.log.levels.WARN)
  elseif resp.status ~= 200 then -- Handle other non-success statuses
    msg = "Failed request to pyrepl server (Status: " .. resp.status .. "): " .. resp.body
    notify(msg, vim.log.levels.ERROR)
  end
end

function M.reset_repl()
  if not M.is_server_alive() then
    notify('pyrepl server not running on ' .. get_url(), vim.log.levels.ERROR)
    return
  end

  local ok, resp = pcall(curl.post, get_url() .. '/reset', {
    timeout = 5000
  })

  if not ok then
    notify('Failed to connect to pyrepl server for reset: ' .. tostring(resp), vim.log.levels.ERROR)
    return
  end

  if resp.status == 200 then
    notify('pyrepl scope reset', vim.log.levels.INFO)
  else
    notify('Failed to send reset request (Status: ' .. resp.status .. ')', vim.log.levels.ERROR)
  end
end

---@return string[]
function M.get_visual_selection()
  local _, srow, scol = unpack(vim.fn.getpos 'v')
  local _, erow, ecol = unpack(vim.fn.getpos '.')

  -- Handle Visual Line mode ('V')
  if vim.fn.mode() == 'V' then
    -- Ensure srow is always less than or equal to erow
    if srow > erow then srow, erow = erow, srow end
    return vim.api.nvim_buf_get_lines(0, srow - 1, erow, true)
  end

  -- Handle Visual mode ('v') and Visual Block mode ('<C-v>')
  -- For simplicity, treat visual block like character visual for line extraction
  if vim.fn.mode():find('v', 1, true) then
    -- Determine start and end positions correctly regardless of selection direction
    local start_pos, end_pos
    if srow < erow or (srow == erow and scol <= ecol) then
      start_pos = { srow - 1, scol - 1 }
      end_pos = { erow - 1, ecol } -- nvim_buf_get_text end col is exclusive
    else
      start_pos = { erow - 1, ecol - 1 }
      end_pos = { srow - 1, scol } -- nvim_buf_get_text end col is exclusive
    end
    return vim.api.nvim_buf_get_text(0, start_pos[1], start_pos[2], end_pos[1], end_pos[2], {})
  end

  return {}
end

function M.run_selected_lines()
  local code = M.get_visual_selection()
  if #code > 0 then
    M.send_to_repl(code)
  end
end

return M
