local M = {}

---@class custom.WorktreeCommit
---@field sha string
---@field short_sha string
---@field message string
---@field timestamp number

---@class custom.WorktreeWorkingTree
---@field staged number
---@field modified number
---@field untracked number

---@class custom.Worktree
---@field branch string|nil
---@field path string
---@field kind "worktree"|"branch"
---@field is_current boolean
---@field is_previous boolean
---@field symbols string
---@field commit custom.WorktreeCommit
---@field working_tree custom.WorktreeWorkingTree

---@return custom.Worktree[]
local function get_worktrees()
  local output = vim.fn.system { 'wt', 'list', '--format=json' }
  if vim.v.shell_error ~= 0 then
    vim.notify('wt list failed: ' .. output, vim.log.levels.ERROR)
    return {}
  end

  local ok, parsed = pcall(vim.json.decode, output)
  if not ok then
    vim.notify('Failed to parse wt list output', vim.log.levels.ERROR)
    return {}
  end

  local worktrees = {}
  for _, entry in ipairs(parsed) do
    if entry.kind == 'worktree' then
      table.insert(worktrees, entry)
    end
  end
  return worktrees
end

---@param old_cwd string
local function close_old_buffers(old_cwd)
  local skipped = 0
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name ~= '' and vim.startswith(name, old_cwd) then
        if vim.bo[bufnr].modified then
          skipped = skipped + 1
        else
          vim.api.nvim_buf_delete(bufnr, { force = false })
        end
      end
    end
  end
  if skipped > 0 then
    vim.notify(skipped .. ' modified buffer(s) kept open', vim.log.levels.WARN)
  end
end

---@param new_path string
local function post_switch(new_path)
  local old_cwd = vim.fn.getcwd()
  if old_cwd == new_path then
    return
  end

  close_old_buffers(old_cwd)
  vim.fn.chdir(new_path)
  vim.cmd('Oil ' .. vim.fn.fnameescape(new_path))
  pcall(vim.cmd, 'Gitsigns refresh')

  for _, client in ipairs(vim.lsp.get_clients()) do
    vim.lsp.stop_client(client.id)
  end

  M._symbols_cache = nil
end

---@param worktree custom.Worktree
local function switch_to(worktree)
  if worktree.is_current then
    return
  end

  if worktree.kind == 'worktree' and worktree.path and worktree.path ~= '' then
    post_switch(worktree.path)
  end
end

---@param entry custom.Worktree
---@return string
local function format_entry(entry)
  local marker = entry.is_current and '*' or (entry.is_previous and '-' or ' ')
  local branch = entry.branch or '(detached)'
  local symbols = entry.symbols or ''
  local sha = entry.commit and entry.commit.short_sha or ''
  local msg = entry.commit and entry.commit.message or ''
  if #msg > 50 then
    msg = msg:sub(1, 47) .. '...'
  end
  return string.format('%s %-20s %-6s %s  %s', marker, branch, symbols, sha, msg)
end

---@param opts? table
M.pick = function(opts)
  opts = opts or {}
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'
  local conf = require('telescope.config').values
  local worktrees = get_worktrees()

  if #worktrees == 0 then
    vim.notify('No worktrees found', vim.log.levels.WARN)
    return
  end

  pickers
    .new(opts, {
      prompt_title = 'worktrees',
      finder = finders.new_table {
        results = worktrees,
        ---@param wt custom.Worktree
        entry_maker = function(wt)
          return {
            value = wt,
            display = format_entry(wt),
            ordinal = wt.branch or '',
          }
        end,
      },
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local entry = action_state.get_selected_entry()
          if entry then
            switch_to(entry.value)
          end
        end)
        return true
      end,
    })
    :find()
end

M.switch_previous = function()
  local worktrees = get_worktrees()
  for _, wt in ipairs(worktrees) do
    if wt.is_previous and not wt.is_current then
      switch_to(wt)
      return
    end
  end
  vim.notify('No previous worktree found', vim.log.levels.WARN)
end

M.create = function()
  vim.ui.input({ prompt = 'New branch name: ' }, function(branch)
    if not branch or branch == '' then
      return
    end

    local result = vim.fn.system { 'wt', 'switch', '--create', '-y', branch }
    if vim.v.shell_error ~= 0 then
      vim.notify('wt switch --create failed: ' .. result, vim.log.levels.ERROR)
      return
    end

    local trees = get_worktrees()
    for _, t in ipairs(trees) do
      if t.branch == branch then
        post_switch(t.path)
        return
      end
    end
    vim.notify('Created worktree but could not find its path', vim.log.levels.WARN)
  end)
end

---@type string|nil
M._symbols_cache = nil
---@type string|nil
M._symbols_cache_cwd = nil
---@type boolean
M._autocmd_registered = false
---@type boolean
M._symbols_refreshing = false

---@param cwd string
local function refresh_statusline_symbols(cwd)
  if M._symbols_refreshing then
    return
  end

  M._symbols_refreshing = true
  vim.system({ 'wt', 'list', '--format=json' }, { cwd = cwd, text = true }, function(result)
    vim.schedule(function()
      M._symbols_refreshing = false

      if vim.fn.getcwd() == cwd then
        local symbols = ''
        if result.code == 0 then
          local ok, parsed = pcall(vim.json.decode, result.stdout)
          if ok and type(parsed) == 'table' then
            for _, entry in ipairs(parsed) do
              if entry.kind == 'worktree' and entry.is_current then
                symbols = entry.symbols or ''
                break
              end
            end
          end
        end
        M._symbols_cache = symbols
        M._symbols_cache_cwd = cwd
      end

      vim.cmd 'redrawstatus'
    end)
  end)
end

M.statusline_symbols = function()
  local cwd = vim.fn.getcwd()

  if not M._autocmd_registered then
    vim.api.nvim_create_autocmd('DirChanged', {
      callback = function()
        M._symbols_cache = nil
        M._symbols_cache_cwd = nil
      end,
    })
    M._autocmd_registered = true
  end

  if M._symbols_cache_cwd == cwd and M._symbols_cache then
    return M._symbols_cache
  end

  refresh_statusline_symbols(cwd)
  return ''
end

return M
