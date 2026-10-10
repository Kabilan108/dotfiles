-- :Today opens this ISO week's log in the coppermind vault at today's "### Wed, Oct 07" heading.
-- New weekly logs are created from a Templater template that only runs inside Obsidian,
-- so a missing file is reported instead of being created empty.

local function vault_root()
  return vim.fs.root(0, '.obsidian') or vim.fs.normalize '~/notes'
end

vim.api.nvim_create_user_command('Today', function()
  local path = vim.fs.joinpath(vault_root(), '01-logs', os.date '%G-w%V' .. '.md')
  if not vim.uv.fs_stat(path) then
    vim.notify(('%s does not exist yet; create it from Obsidian'):format(vim.fn.fnamemodify(path, ':~')), vim.log.levels.WARN)
    return
  end

  vim.cmd.edit(vim.fn.fnameescape(path))
  local heading = '### ' .. os.date '%a, %b %d'
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  if vim.fn.search('\\V\\^' .. vim.fn.escape(heading, '\\') .. '\\$', 'cW') == 0 then
    vim.notify(('no "%s" heading in this week\'s log'):format(heading), vim.log.levels.WARN)
    return
  end
  vim.cmd 'normal! zt'
end, { desc = "open this week's log at today's heading" })

vim.keymap.set('n', '<leader>nt', '<CMD>Today<CR>', { desc = "notes: today's weekly log" })
