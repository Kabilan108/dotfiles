-- sweep.nvim - AI autocomplete using Sweep's next-edit model
-- Entry point for the plugin

if vim.g.loaded_sweep then
  return
end
vim.g.loaded_sweep = true

-- Require Neovim 0.10+
if vim.fn.has('nvim-0.10') == 0 then
  vim.notify('sweep.nvim requires Neovim 0.10 or later', vim.log.levels.ERROR)
  return
end

-- Commands
vim.api.nvim_create_user_command('SweepEnable', function()
  require('sweep').enable()
end, { desc = 'Enable Sweep autocomplete' })

vim.api.nvim_create_user_command('SweepDisable', function()
  require('sweep').disable()
end, { desc = 'Disable Sweep autocomplete' })

vim.api.nvim_create_user_command('SweepToggle', function()
  require('sweep').toggle()
end, { desc = 'Toggle Sweep autocomplete' })

vim.api.nvim_create_user_command('SweepStatus', function()
  require('sweep').status()
end, { desc = 'Show Sweep status' })

vim.api.nvim_create_user_command('SweepDebug', function()
  require('sweep').debug()
end, { desc = 'Show Sweep debug info' })
