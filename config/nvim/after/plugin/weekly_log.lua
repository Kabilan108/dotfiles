-- :Today opens or creates this ISO week's log at today's "### Wed, Oct 07" heading.
-- Missing logs are rendered from the vault's templates/neovim/weekly-log.md.

local function vault_root()
  return vim.fs.root(0, '.obsidian') or vim.fs.normalize '~/notes'
end

vim.api.nvim_create_user_command('Today', function()
  local templates = require 'custom.note_templates'
  local root = vault_root()
  local context = templates.weekly_context(os.time())
  local path = vim.fs.joinpath(root, '01-logs', context.week_id .. '.md')
  if not vim.uv.fs_stat(path) then
    local ok, err = pcall(function()
      local contents = templates.render(vim.fs.joinpath(root, 'templates', 'neovim', 'weekly-log.md'), context)
      templates.create(path, contents)
    end)
    if not ok then
      vim.notify(('could not create weekly log: %s'):format(err), vim.log.levels.ERROR)
      return
    end
  end

  vim.cmd.edit(vim.fn.fnameescape(path))
  local heading = context.today_heading
  local heading_line
  for line, text in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    if text == heading then
      heading_line = line
      break
    end
  end
  if not heading_line then
    vim.notify(('no "%s" heading in this week log'):format(heading), vim.log.levels.WARN)
    return
  end
  vim.api.nvim_win_set_cursor(0, { heading_line, 0 })
  vim.cmd 'normal! zt'
end, { desc = "open or create this week's log at today's heading" })

vim.keymap.set('n', '<leader>nt', '<CMD>Today<CR>', { desc = "notes: today's weekly log" })
