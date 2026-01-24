-- Minimal init for running tests with plenary.nvim

-- Add sweep.nvim to runtimepath
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h')
vim.opt.runtimepath:prepend(plugin_root)

-- Add plenary to runtimepath (adjust path as needed)
local plenary_path = vim.fn.stdpath('data') .. '/lazy/plenary.nvim'
if vim.fn.isdirectory(plenary_path) == 1 then
  vim.opt.runtimepath:prepend(plenary_path)
else
  -- Try common alternative paths
  local alt_paths = {
    vim.fn.expand('~/.local/share/nvim/lazy/plenary.nvim'),
    vim.fn.expand('~/.local/share/nvim/site/pack/packer/start/plenary.nvim'),
    '/usr/share/nvim/site/pack/packer/start/plenary.nvim',
  }
  for _, path in ipairs(alt_paths) do
    if vim.fn.isdirectory(path) == 1 then
      vim.opt.runtimepath:prepend(path)
      break
    end
  end
end

-- Basic settings for testing
vim.cmd('runtime plugin/plenary.vim')
vim.o.swapfile = false
vim.o.backup = false
vim.o.writebackup = false
