-- Extend the existing vim-tmux-navigator flow across Herdr pane boundaries.
-- Behavior reference: paulbkim-dev/vim-herdr-navigation, commit 79679dac.

local directions = {
  h = { wincmd = 'h', herdr = 'left', tmux = 'TmuxNavigateLeft' },
  j = { wincmd = 'j', herdr = 'down', tmux = 'TmuxNavigateDown' },
  k = { wincmd = 'k', herdr = 'up', tmux = 'TmuxNavigateUp' },
  l = { wincmd = 'l', herdr = 'right', tmux = 'TmuxNavigateRight' },
}

local function navigate(key)
  local direction = directions[key]
  local previous_window = vim.fn.winnr()

  vim.cmd('wincmd ' .. direction.wincmd)
  if vim.fn.winnr() ~= previous_window then
    return
  end

  local herdr_pane = vim.env.HERDR_PANE_ID
  if herdr_pane and herdr_pane ~= '' then
    vim.fn.jobstart({
      'herdr',
      'pane',
      'focus',
      '--pane',
      herdr_pane,
      '--direction',
      direction.herdr,
    }, { detach = true })
  elseif vim.env.TMUX and vim.fn.exists(':' .. direction.tmux) == 2 then
    vim.cmd(direction.tmux)
  end
end

for key, _ in pairs(directions) do
  vim.keymap.set('n', '<C-' .. key .. '>', function()
    navigate(key)
  end, { desc = 'navigate nvim or multiplexer pane', silent = true })
end
