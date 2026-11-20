local opt = vim.opt

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.g.have_nerd_font = true

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

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

opt.hlsearch = true

opt.termguicolors = true

opt.number = true
opt.relativenumber = true

opt.mouse = 'a'

opt.showmode = false

opt.breakindent = true

opt.undofile = true

opt.ignorecase = true
opt.smartcase = true

opt.signcolumn = 'yes'

opt.updatetime = 250

opt.timeoutlen = 300

opt.splitright = true
opt.splitbelow = true

opt.list = true
opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

opt.inccommand = 'split'

opt.cursorline = true

opt.scrolloff = 20

opt.foldmethod = 'indent'
opt.foldlevel = 99
opt.foldenable = true

opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2

opt.colorcolumn = '88'

vim.o.exrc = true
vim.o.secure = true

vim.o.autoread = true
vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold' }, {
  group = vim.api.nvim_create_augroup('AutoReload', { clear = true }),
  callback = function()
    if vim.fn.getcmdwintype() == '' then
      vim.cmd 'checktime'
    end
  end,
})
