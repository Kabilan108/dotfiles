-- Caps vault notes at a readable width: an empty, unfocusable window on the far right of the tab
-- takes the spare columns, so text soft-wraps at WIDTH. Other splits share what's left as usual.
-- Buffers opt in by setting vim.b.readable_width (see after/ftplugin/markdown.lua).

local M = {}

local WIDTH = 100
local MIN_PAD = 10

---@return integer?
local function pad_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.w[win].readable_pad then
      return win
    end
  end
end

---@return integer
local function pad_width()
  return vim.o.columns - WIDTH - 1
end

---@param pad integer
---@return integer[]
local function other_wins(pad)
  return vim.tbl_filter(function(win)
    return win ~= pad and vim.api.nvim_win_get_config(win).relative == ''
  end, vim.api.nvim_tabpage_list_wins(0))
end

local function open()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = 'readable-pad'
  local win = vim.api.nvim_open_win(buf, false, {
    split = 'right',
    win = -1,
    width = pad_width(),
    focusable = false,
    style = 'minimal',
  })
  vim.w[win].readable_pad = true
  vim.wo[win].winfixwidth = true
  vim.wo[win].fillchars = 'eob: '
end

-- open, resize or close this tab's pad to match vim.t.readable_width and the screen size
local function sync()
  local pad = pad_win()
  local wanted = vim.t.readable_width and pad_width() >= MIN_PAD
  if pad and not wanted then
    vim.api.nvim_win_close(pad, true)
  elseif pad then
    vim.api.nvim_win_set_width(pad, pad_width())
  elseif wanted then
    open()
  end
end

function M.toggle()
  vim.t.readable_width = not vim.t.readable_width
  sync()
end

local group = vim.api.nvim_create_augroup('readable_width', {})

vim.api.nvim_create_autocmd({ 'VimResized', 'TabEnter' }, { group = group, callback = sync })

-- buffers opt in with vim.b.readable_width (vault markdown sets it); the first one shown in a tab
-- turns the cap on there, unless it was toggled off in that tab
vim.api.nvim_create_autocmd('BufWinEnter', {
  group = group,
  callback = function()
    if vim.b.readable_width and vim.api.nvim_win_get_config(0).relative == '' then
      if vim.t.readable_width == nil then
        vim.t.readable_width = true
      end
      sync()
    end
  end,
})

-- focusable=false only covers <C-w>w and friends; directional moves (<C-w>l) still land here
vim.api.nvim_create_autocmd('WinEnter', {
  group = group,
  callback = function()
    if vim.w.readable_pad then
      vim.cmd 'wincmd p'
    end
  end,
})

-- :q on the last real window should quit, not leave the pad behind
vim.api.nvim_create_autocmd('QuitPre', {
  group = group,
  callback = function()
    local pad = pad_win()
    if pad and #other_wins(pad) <= 1 then
      vim.api.nvim_win_close(pad, true)
    end
  end,
})

-- :close and friends skip QuitPre
vim.api.nvim_create_autocmd('WinClosed', {
  group = group,
  callback = function()
    vim.schedule(function()
      local pad = pad_win()
      if pad and #other_wins(pad) == 0 then
        if #vim.api.nvim_list_tabpages() > 1 then
          vim.cmd.tabclose()
        else
          pcall(vim.cmd.quit)
        end
      end
    end)
  end,
})

return M
