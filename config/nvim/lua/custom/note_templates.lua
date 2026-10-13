local M = {}

-- Substitute named values only. Templates never execute code.
function M.render(path, values)
  local template = table.concat(vim.fn.readfile(path), '\n') .. '\n'
  return (
    template:gsub('{{%s*([%w_]+)%s*}}', function(key)
      if values[key] == nil then
        error(('unknown template placeholder: %s'):format(key))
      end
      return values[key]
    end)
  )
end

function M.weekly_context(timestamp)
  local date = os.date('*t', timestamp)
  local monday_offset = (date.wday + 5) % 7
  -- Calendar arithmetic at local noon keeps dates correct across DST changes.
  local function day(offset)
    return os.time { year = date.year, month = date.month, day = date.day - monday_offset + offset, hour = 12 }
  end

  local monday = day(0)
  local sections = {}
  for offset = 0, 6 do
    sections[#sections + 1] = '### ' .. os.date('%a, %b %d', day(offset)) .. '\n\n-\n'
  end

  return {
    week_id = os.date('%G-w%V', monday),
    week_title = os.date('%G - Week %V', monday) .. ' (' .. os.date('%b %d', monday) .. ' - ' .. os.date('%b %d', day(6)) .. ')',
    previous_week = os.date('%G-w%V', day(-7)),
    next_week = os.date('%G-w%V', day(7)),
    daily_sections = table.concat(sections, '\n'),
    today_heading = '### ' .. os.date('%a, %b %d', timestamp),
  }
end

-- Exclusive creation prevents a concurrent editor from having its note overwritten.
function M.create(path, contents)
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  local fd, err, code = vim.uv.fs_open(path, 'wx', 420)
  if not fd then
    if code == 'EEXIST' then
      return
    end
    error(err)
  end
  local written, write_err = vim.uv.fs_write(fd, contents, 0)
  local closed, close_err = vim.uv.fs_close(fd)
  if written ~= #contents or not closed then
    vim.uv.fs_unlink(path)
    error(write_err or close_err or 'incomplete template write')
  end
end

return M
