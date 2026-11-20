if not vim.fs.root(0, '.obsidian') then
  return
end

vim.keymap.set('n', 'ny', function()
  require('custom.note_link_yank').yank()
end, { buffer = true, desc = 'notes: copy link URL or absolute path' })

vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.breakindentopt = 'list:-1'

vim.keymap.set({ 'n', 'x' }, 'j', "v:count == 0 ? 'gj' : 'j'", { buffer = true, expr = true })
vim.keymap.set({ 'n', 'x' }, 'k', "v:count == 0 ? 'gk' : 'k'", { buffer = true, expr = true })

vim.keymap.set('n', '<leader>nz', function()
  require('custom.readable_width').toggle()
end, { buffer = true, desc = 'notes: toggle readable width' })

vim.b.readable_width = true
require 'custom.readable_width'
