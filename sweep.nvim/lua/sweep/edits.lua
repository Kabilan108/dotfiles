-- sweep.nvim - Edit tracking module for next-edit prediction context
-- Tracks recent edits using simple original/updated blocks (Sweep's research finding)

local M = {}

---@class EditRecord
---@field timestamp number Unix timestamp when edit was recorded
---@field filename string Full path to the edited file
---@field bufnr number Buffer number
---@field old_lines string[] Original lines before edit
---@field new_lines string[] Updated lines after edit

---@class EditsConfig
---@field max_edits number Maximum number of edits to track
---@field max_lines number Maximum lines per edit
---@field context_lines number Lines of context around edits

---@type EditRecord[]
local edit_history = {}

---@type EditsConfig
local config = {
  max_edits = 10,
  max_lines = 20,
  context_lines = 3,
}

---@type table<number, boolean> Track which buffers are attached
local attached_buffers = {}

---@type table<number, string[]> Store previous buffer content for diff computation
local buffer_content = {}

--- Truncate lines array to max_lines
---@param lines string[]
---@param max_lines number
---@return string[]
local function truncate_lines(lines, max_lines)
  if #lines <= max_lines then
    return lines
  end
  local result = {}
  for i = 1, max_lines do
    result[i] = lines[i]
  end
  return result
end

--- Check if two line arrays are identical
---@param lines1 string[]
---@param lines2 string[]
---@return boolean
local function lines_equal(lines1, lines2)
  if #lines1 ~= #lines2 then
    return false
  end
  for i = 1, #lines1 do
    if lines1[i] ~= lines2[i] then
      return false
    end
  end
  return true
end

--- Initialize edit tracking with configuration
---@param opts? EditsConfig
function M.setup(opts)
  opts = opts or {}
  config.max_edits = opts.max_edits or 10
  config.max_lines = opts.max_lines or 20
  config.context_lines = opts.context_lines or 3
  M.clear()
end

--- Record an edit
---@param edit table { bufnr: number, start_line: number, end_line: number, old_lines: string[], new_lines: string[], filename?: string }
function M.record(edit)
  if not edit then
    return
  end

  local old_lines = edit.old_lines or {}
  local new_lines = edit.new_lines or {}

  -- Skip if both old and new are empty
  if #old_lines == 0 and #new_lines == 0 then
    return
  end

  -- Skip if old and new are identical (no actual change)
  if lines_equal(old_lines, new_lines) then
    return
  end

  -- Truncate lines if they exceed max_lines
  old_lines = truncate_lines(old_lines, config.max_lines)
  new_lines = truncate_lines(new_lines, config.max_lines)

  ---@type EditRecord
  local record = {
    timestamp = os.time(),
    filename = edit.filename or '',
    bufnr = edit.bufnr or 0,
    old_lines = old_lines,
    new_lines = new_lines,
  }

  -- Insert at the beginning (most recent first)
  table.insert(edit_history, 1, record)

  -- Evict oldest edits if over limit
  while #edit_history > config.max_edits do
    table.remove(edit_history)
  end
end

--- Get recent edits as formatted context string
--- Uses Sweep's research-backed format: <edit><original>...<updated>...</edit>
---@return string
function M.get_context()
  if #edit_history == 0 then
    return ''
  end

  local parts = {}

  for _, edit in ipairs(edit_history) do
    local edit_parts = {}
    table.insert(edit_parts, '<edit>')
    table.insert(edit_parts, '<original>')
    for _, line in ipairs(edit.old_lines) do
      table.insert(edit_parts, line)
    end
    table.insert(edit_parts, '</original>')
    table.insert(edit_parts, '<updated>')
    for _, line in ipairs(edit.new_lines) do
      table.insert(edit_parts, line)
    end
    table.insert(edit_parts, '</updated>')
    table.insert(edit_parts, '</edit>')

    table.insert(parts, table.concat(edit_parts, '\n'))
  end

  return table.concat(parts, '\n')
end

--- Get raw edit history
---@return EditRecord[]
function M.get_history()
  return edit_history
end

--- Clear all edit history
function M.clear()
  edit_history = {}
end

--- Clear edits for a specific buffer
---@param bufnr number
function M.clear_buffer(bufnr)
  local new_history = {}
  for _, edit in ipairs(edit_history) do
    if edit.bufnr ~= bufnr then
      table.insert(new_history, edit)
    end
  end
  edit_history = new_history

  -- Also clean up buffer content cache
  buffer_content[bufnr] = nil
end

--- Start tracking a buffer (attaches to buffer events)
---@param bufnr number
---@return boolean success
function M.attach(bufnr)
  if attached_buffers[bufnr] then
    return true
  end

  -- Store initial buffer content for diff computation
  local ok, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, 0, -1, false)
  if ok then
    buffer_content[bufnr] = lines
  end

  -- Attach to buffer with on_lines callback
  local success = pcall(function()
    vim.api.nvim_buf_attach(bufnr, false, {
      on_lines = function(_, buf, _, first_line, last_line, new_last_line, _, _, _)
        -- Get the old content from our cache
        local old_lines = {}
        if buffer_content[buf] then
          for i = first_line + 1, last_line do
            if buffer_content[buf][i] then
              table.insert(old_lines, buffer_content[buf][i])
            end
          end
        end

        -- Get the new content
        local new_ok, new_lines = pcall(vim.api.nvim_buf_get_lines, buf, first_line, new_last_line, false)
        if not new_ok then
          new_lines = {}
        end

        -- Get filename
        local filename = vim.api.nvim_buf_get_name(buf)

        -- Record the edit
        M.record({
          bufnr = buf,
          start_line = first_line + 1, -- Convert to 1-indexed
          end_line = new_last_line,
          old_lines = old_lines,
          new_lines = new_lines,
          filename = filename,
        })

        -- Update our content cache
        local full_ok, full_lines = pcall(vim.api.nvim_buf_get_lines, buf, 0, -1, false)
        if full_ok then
          buffer_content[buf] = full_lines
        end
      end,
      on_detach = function(_, buf)
        attached_buffers[buf] = nil
        buffer_content[buf] = nil
      end,
    })
  end)

  if success then
    attached_buffers[bufnr] = true
  end

  return success
end

--- Stop tracking a buffer
---@param bufnr number
function M.detach(bufnr)
  attached_buffers[bufnr] = nil
  buffer_content[bufnr] = nil
  -- Note: nvim_buf_attach with on_detach handles cleanup automatically
  -- when buffer is deleted. Manual detach is for explicit stop tracking.
end

return M
