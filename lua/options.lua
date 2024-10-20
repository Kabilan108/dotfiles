-- options.lua

local opt = vim.opt

-- define leaders
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- enable nerd font
vim.g.have_nerd_font = true

-- disable netrw
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- use system clipboard
opt.clipboard:append "unnamedplus"

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
-- will show which-key pop up faster
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
opt.scrolloff = 10

-- indentation
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2

-- show a ruler
opt.colorcolumn = "88"

-- custom indentation for some languages
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'python', 'kotlin' },
  callback = function()
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 4
  end,
})
