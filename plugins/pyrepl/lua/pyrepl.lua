local M = {}

local curl = require('plenary.curl')

---@class pyrepl.Config
---@field url string pyrepl server url
M.config = {
  url = 'http://localhost:5000'
}

---@param opts pyrepl.Config
function M.setup(opts)
  M.config = vim.tbl_extend('force', M.config, opts or {})
end

---@return boolean
function M.is_server_alive()
  local ok, resp = pcall(curl.get, M.config.url .. '/health', {
    timeout = 5000,
    on_error = function() end
  })
  return ok and resp and resp.status == 200
end

---@param code string[]
---@param reset boolean
function M.send_to_repl(code, reset)
  if not M.is_server_alive() then
    vim.notify('pyrepl server not running on ' .. M.config.url, vim.log.levels.ERROR)
    return
  end
  local resp = curl.post(M.config.url, {
    body = vim.fn.json_encode({ code = code, reset = reset or false }),
    headers = { content_type = 'application/json' }
  })
  local data = vim.fn.json_decode(resp.body)
  if resp.status ~= 200 then
    vim.notify('Failed to send request to pyrepl server', vim.log.levels.ERROR)
  end
  if data.error ~= vim.NIL then
    -- FIXME: concatenating data.error to a string throws an error
    vim.notify('Error from pyrepl: ' .. data.error, vim.log.levels.ERROR)
  end
end

---@return string[]
function M.get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line, start_col = start_pos[2], start_pos[3]
  local end_line, end_col = end_pos[2], end_pos[3]
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  if #lines == 0 then
    return {}
  end
  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_col, end_col)
  else
    lines[1] = string.sub(lines[1], start_col)
    lines[#lines] = string.sub(lines[#lines], 1, end_col)
  end
  return lines
end

---@param reset boolean
function M.run_selected_lines(reset)
  local code = M.get_visual_selection()
  if #code > 0 then
    M.send_to_repl(code, reset)
  end
end

-- lazy load
vim.api.nvim_create_user_command('RunInPyrepl', function() M.run_selected_lines(false) end, {})

return M
