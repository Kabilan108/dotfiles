local M = {}

local curl = require('plenary.curl')

---@class pyrepl.Config
---@field port integer pyrepl server port
M.config = {
  port = tonumber(os.getenv("PYREPL_PORT")) or 5000
}

local function get_url()
  return 'http://localhost:' .. M.config.port
end

---@param opts pyrepl.Config|table|nil
function M.setup(opts)
  M.config = vim.tbl_extend('force', M.config, opts or {})
  vim.api.nvim_create_user_command('RunInPyrepl', function() M.run_selected_lines() end, {})
  vim.api.nvim_create_user_command('ResetPyrepl', function() M.reset_repl() end, {})
end

---@return boolean
function M.is_server_alive()
  local ok, resp = pcall(curl.get, get_url() .. '/health', {
    timeout = 5000,
    on_error = function() end
  })
  return ok and resp and resp.status == 200
end

---@param code string[]
function M.send_to_repl(code)
  if not M.is_server_alive() then
    vim.notify('pyrepl server not running on ' .. get_url(), vim.log.levels.ERROR)
    return
  end
  local resp = curl.post(get_url() .. '/execute', {
    body = vim.fn.json_encode({ code = code }),
    headers = { content_type = 'application/json' }
  })
  local data = vim.fn.json_decode(resp.body)
  if resp.status ~= 200 then
    vim.notify('Failed to send request to pyrepl server', vim.log.levels.ERROR)
  end
  if data.error ~= vim.NIL then
    vim.notify('Error from pyrepl: ' .. data.error, vim.log.levels.ERROR)
  end
end

function M.reset_repl()
  if not M.is_server_alive() then
    vim.notify('pyrepl server not running on ' .. get_url(), vim.log.levels.ERROR)
    return
  end
  local resp = curl.post(get_url() .. '/reset', {})
  if resp.status ~= 200 then
    vim.notify('Failed to send reset request to pyrepl server', vim.log.levels.ERROR)
  end
end

---@return string[]
function M.get_visual_selection()
  local _, srow, scol = unpack(vim.fn.getpos 'v')
  local _, erow, ecol = unpack(vim.fn.getpos '.')

  if vim.fn.mode() == 'V' then
    if srow > erow then
      return vim.api.nvim_buf_get_lines(0, erow - 1, srow, true)
    else
      return vim.api.nvim_buf_get_lines(0, srow - 1, erow, true)
    end
  end

  if vim.fn.mode() == 'v' then
    if srow < erow or (srow == erow and scol <= ecol) then
      return vim.api.nvim_buf_get_text(0, srow - 1, scol - 1, erow - 1, ecol, {})
    else
      return vim.api.nvim_buf_get_text(0, erow - 1, ecol - 1, srow - 1, scol, {})
    end
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
