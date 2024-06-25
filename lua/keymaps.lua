-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

local api = vim.api
local cmd = vim.cmd
local map = vim.keymap.set

-- Set highlight on search, but clear on pressing <Esc> in normal mode
vim.opt.hlsearch = true
map('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic keymaps
map('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous [D]iagnostic message' })
map('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next [D]iagnostic message' })
map('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic [E]rror messages' })
map('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- TIP: Disable arrow keys in normal mode
map('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
map('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
map('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
map('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
map('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
map('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
map('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
map('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- Keybindings for minimap
map('n', '<C-A-m>', ':MinimapToggle<CR>', { desc = 'Toggle minimap' })

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Keymap & Function to toggle terminal window
function ToggleTerminal()
  local term_bufnr = vim.fn.bufnr 'term://' -- Find terminal buffer
  if term_bufnr == -1 then
    -- If terminal doesn't exist, create a new one
    cmd 'botright split'
    cmd 'terminal'
    api.nvim_win_set_height(0, 15) -- Set height to 15 lines
    cmd 'wincmd j' -- Move cursor to terminal window
    cmd 'startinsert' -- Start in insert mode

    vim.wo.number = false
    vim.wo.relativenumber = false
  else
    local term_win = vim.fn.bufwinnr(term_bufnr)
    if term_win == -1 then
      -- If terminal exists but is not visible, show it
      cmd 'botright split'
      cmd('buffer ' .. term_bufnr)
      api.nvim_win_set_height(0, 15)
      cmd 'wincmd j'
      cmd 'startinsert'
    else
      -- If terminal is visible, hide it
      cmd(term_win .. 'wincmd c')
    end
  end
end

api.nvim_set_keymap('n', '<C-`>', '<cmd>lua ToggleTerminal()<CR>', { noremap = true, silent = true, desc = 'Toggle Terminal' })
api.nvim_set_keymap('t', '<C-`>', '<C-\\><C-n><cmd>lua ToggleTerminal()<CR>', { noremap = true, silent = true, desc = 'Toggle terminal' })

-- vim: ts=2 sts=2 sw=2 et
