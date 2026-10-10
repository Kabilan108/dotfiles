-- Obsidian vault notes are prose: soft-wrap at word boundaries and move by screen line.
if not vim.fs.root(0, '.obsidian') then
  return
end

vim.opt_local.wrap = true
vim.opt_local.linebreak = true
-- wrapped list items line up with the text after the bullet
vim.opt_local.breakindentopt = 'list:-1'

-- a count (5j, 12k) still moves by real lines so relative numbers stay usable
vim.keymap.set({ 'n', 'x' }, 'j', "v:count == 0 ? 'gj' : 'j'", { buffer = true, expr = true })
vim.keymap.set({ 'n', 'x' }, 'k', "v:count == 0 ? 'gk' : 'k'", { buffer = true, expr = true })

vim.keymap.set('n', '<leader>nz', function()
  require('custom.readable_width').toggle()
end, { buffer = true, desc = 'notes: toggle readable width' })

vim.b.readable_width = true
require 'custom.readable_width'
