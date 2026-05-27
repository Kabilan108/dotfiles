-- options.lua

local opt = vim.opt

-- define leaders
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- enable nerd font
vim.g.have_nerd_font = true

-- disable netrw
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- use system clipboard
opt.clipboard:append 'unnamedplus'

if vim.env.SSH_TTY or vim.env.SSH_CONNECTION then
  local osc52 = require 'vim.ui.clipboard.osc52'

  vim.g.clipboard = {
    name = 'OSC 52',
    copy = {
      ['+'] = osc52.copy '+',
      ['*'] = osc52.copy '*',
    },
    paste = {
      ['+'] = osc52.paste '+',
      ['*'] = osc52.paste '*',
    },
  }
end

-- highlight on search
opt.hlsearch = true

-- enable 24-bit color
opt.termguicolors = true

-- configure line numbers
opt.number = true
opt.relativenumber = true

-- mouse mode
opt.mouse = 'a'

-- hide status; will be shown in statusline
opt.showmode = false

-- keep indentation consistent when wrapping lines
opt.breakindent = true

-- save undo history
opt.undofile = true

-- case insensitive search unless \C or >1 capital letters in query
opt.ignorecase = true
opt.smartcase = true

-- enable signcolumn by default
opt.signcolumn = 'yes'

-- set update time
opt.updatetime = 250

-- decrease mapped sequence wait time
opt.timeoutlen = 300

-- configure how splits are opened
opt.splitright = true
opt.splitbelow = true

-- configure how whitespace characters are displayed
opt.list = true
opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- preview substitutions
opt.inccommand = 'split'

-- show where the cursor is
opt.cursorline = true

-- min #lines to keep above and below the cursor
opt.scrolloff = 20

-- folding
opt.foldmethod = 'indent' -- fold based on indentation
opt.foldlevel = 99 -- start with all folds open
opt.foldenable = true -- enable folding

-- indentation
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2

-- show a ruler
opt.colorcolumn = '88'

-- enable project-local config files
vim.o.exrc = true
vim.o.secure = true

-- auto-reload files changed outside vim
vim.o.autoread = true
vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold' }, {
  group = vim.api.nvim_create_augroup('AutoReload', { clear = true }),
  callback = function()
    if vim.fn.getcmdwintype() == '' then
      vim.cmd 'checktime'
    end
  end,
})
