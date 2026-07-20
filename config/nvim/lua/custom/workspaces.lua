local M = {}

---@class custom.Workspace
---@field name string
---@field path string

---@class custom.OpenTab
---@field tab integer
---@field path string

local DATA_PATH = vim.fn.stdpath 'data' .. '/workspaces.json'

---@type table<string, custom.OpenTab>
local open_tabs = {}

---@param path string
---@return string
local function resolve_path(path)
  local resolved = vim.fn.resolve(vim.fn.fnamemodify(path, ':p'))
  return resolved:gsub('/$', '')
end

---@return custom.Workspace[]
local function load_workspaces()
  if vim.fn.filereadable(DATA_PATH) ~= 1 then
    return {}
  end
  local lines = vim.fn.readfile(DATA_PATH)
  if #lines == 0 then
    return {}
  end
  local ok, parsed = pcall(vim.json.decode, table.concat(lines, ''))
  if not ok or type(parsed) ~= 'table' then
    vim.notify('workspaces: corrupted data file', vim.log.levels.ERROR)
    return {}
  end
  return parsed
end

---@param workspaces custom.Workspace[]
local function save_workspaces(workspaces)
  vim.fn.writefile({ vim.json.encode(workspaces) }, DATA_PATH)
end

---@param name string
---@return custom.Workspace|nil, integer|nil
local function find_workspace(name)
  for i, ws in ipairs(load_workspaces()) do
    if ws.name == name then
      return ws, i
    end
  end
  return nil, nil
end

---@param ws custom.Workspace
local function open_in_tab(ws)
  vim.cmd '$tabnew'
  local tab = vim.api.nvim_get_current_tabpage()
  vim.cmd('tcd ' .. vim.fn.fnameescape(ws.path))
  vim.api.nvim_tabpage_set_var(tab, 'workspace_name', ws.name)
  open_tabs[ws.name] = { tab = tab, path = ws.path }
  pcall(vim.cmd, 'Oil ' .. vim.fn.fnameescape(ws.path))
end

---@param buf_name string
---@param ws_path string
---@return boolean
local function buf_belongs_to_workspace(buf_name, ws_path)
  if vim.startswith(buf_name, ws_path .. '/') or buf_name == ws_path then
    return true
  end
  if vim.startswith(buf_name, 'oil://' .. ws_path .. '/') or buf_name == 'oil://' .. ws_path then
    return true
  end
  return false
end

---@param ws_path string
local function close_workspace_buffers(ws_path)
  if ws_path == '' then
    return
  end
  local skipped = 0
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name ~= '' and buf_belongs_to_workspace(name, ws_path) then
        if vim.bo[bufnr].modified then
          skipped = skipped + 1
        else
          vim.api.nvim_buf_delete(bufnr, { force = false })
        end
      end
    end
  end
  if skipped > 0 then
    vim.notify('workspaces: ' .. skipped .. ' modified buffer(s) kept open', vim.log.levels.WARN)
  end
end

---@param path? string
---@param name? string
M.add = function(path, name)
  path = resolve_path(path or vim.fn.getcwd())

  if vim.fn.isdirectory(path) ~= 1 then
    vim.notify('workspaces: directory does not exist: ' .. path, vim.log.levels.ERROR)
    return
  end

  local function register(ws_name)
    if not ws_name or ws_name == '' then
      return
    end

    local workspaces = load_workspaces()
    for _, ws in ipairs(workspaces) do
      if ws.name == ws_name then
        vim.notify("workspaces: name '" .. ws_name .. "' already registered", vim.log.levels.WARN)
        return
      end
      if ws.path == path then
        vim.notify("workspaces: path already registered as '" .. ws.name .. "'", vim.log.levels.WARN)
        return
      end
    end

    table.insert(workspaces, { name = ws_name, path = path })
    save_workspaces(workspaces)
    vim.notify("workspaces: registered '" .. ws_name .. "'")
  end

  if name then
    register(name)
  else
    local default = vim.fn.fnamemodify(path, ':t')
    vim.ui.input({ prompt = 'Workspace name: ', default = default }, register)
  end
end

---@param name string
M.remove = function(name)
  local workspaces = load_workspaces()
  local idx = nil
  for i, ws in ipairs(workspaces) do
    if ws.name == name then
      idx = i
      break
    end
  end

  if not idx then
    vim.notify("workspaces: '" .. name .. "' not found", vim.log.levels.WARN)
    return
  end

  local entry = open_tabs[name]
  if entry and vim.api.nvim_tabpage_is_valid(entry.tab) then
    if #vim.api.nvim_list_tabpages() > 1 then
      vim.cmd('tabclose ' .. vim.api.nvim_tabpage_get_number(entry.tab))
    else
      vim.notify('workspaces: cannot close the only tab', vim.log.levels.WARN)
    end
    close_workspace_buffers(entry.path)
  end
  open_tabs[name] = nil

  table.remove(workspaces, idx)
  save_workspaces(workspaces)
  vim.notify("workspaces: removed '" .. name .. "'")
end

---@param name string
M.open = function(name)
  local ws = find_workspace(name)
  if not ws then
    vim.notify("workspaces: '" .. name .. "' not found", vim.log.levels.WARN)
    return
  end

  local entry = open_tabs[name]
  if entry then
    if vim.api.nvim_tabpage_is_valid(entry.tab) then
      vim.api.nvim_set_current_tabpage(entry.tab)
      return
    end
    open_tabs[name] = nil
  end

  open_in_tab(ws)
end

---@param opts? table
M.pick = function(opts)
  opts = opts or {}
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'
  local conf = require('telescope.config').values
  local workspaces = load_workspaces()

  if #workspaces == 0 then
    vim.notify('workspaces: none registered', vim.log.levels.WARN)
    return
  end

  pickers
    .new(opts, {
      prompt_title = 'workspaces',
      finder = finders.new_table {
        results = workspaces,
        ---@param ws custom.Workspace
        entry_maker = function(ws)
          local entry = open_tabs[ws.name]
          local is_open = entry ~= nil and vim.api.nvim_tabpage_is_valid(entry.tab)
          local marker = is_open and '*' or ' '
          local display = string.format('%s %-20s %s', marker, ws.name, ws.path)
          return {
            value = ws,
            display = display,
            ordinal = ws.name .. ' ' .. ws.path,
          }
        end,
      },
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selected = action_state.get_selected_entry()
          if selected then
            M.open(selected.value.name)
          end
        end)
        return true
      end,
    })
    :find()
end

---@param opts? table
M.pick_remove = function(opts)
  opts = opts or {}
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'
  local conf = require('telescope.config').values
  local workspaces = load_workspaces()

  if #workspaces == 0 then
    vim.notify('workspaces: none registered', vim.log.levels.WARN)
    return
  end

  pickers
    .new(opts, {
      prompt_title = 'remove workspace',
      finder = finders.new_table {
        results = workspaces,
        ---@param ws custom.Workspace
        entry_maker = function(ws)
          return {
            value = ws,
            display = string.format('%-20s %s', ws.name, ws.path),
            ordinal = ws.name .. ' ' .. ws.path,
          }
        end,
      },
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selected = action_state.get_selected_entry()
          if selected then
            M.remove(selected.value.name)
          end
        end)
        return true
      end,
    })
    :find()
end

---@return string
M.statusline_name = function()
  local tab = vim.api.nvim_get_current_tabpage()
  local ok, name = pcall(vim.api.nvim_tabpage_get_var, tab, 'workspace_name')
  if ok and name then
    return name
  end
  return ''
end

---@return string
M.tabline = function()
  local tabs = vim.api.nvim_list_tabpages()
  local current = vim.api.nvim_get_current_tabpage()
  local parts = {}

  for _, tab in ipairs(tabs) do
    local tabnr = vim.api.nvim_tabpage_get_number(tab)
    local hl = tab == current and '%#TabLineSel#' or '%#TabLine#'

    local ok, name = pcall(vim.api.nvim_tabpage_get_var, tab, 'workspace_name')
    if not ok or not name then
      local win = vim.api.nvim_tabpage_get_win(tab)
      local buf = vim.api.nvim_win_get_buf(win)
      name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':t')
      if name == '' then
        name = '[No Name]'
      end
    end

    table.insert(parts, string.format('%s%%%dT %s ', hl, tabnr, name))
  end

  table.insert(parts, '%#TabLineFill#%T')
  return table.concat(parts)
end

M.setup = function()
  vim.o.tabline = '%!v:lua.require("custom.workspaces").tabline()'

  vim.api.nvim_create_autocmd('TabClosed', {
    group = vim.api.nvim_create_augroup('workspace-cleanup', { clear = true }),
    callback = function()
      for name, entry in pairs(open_tabs) do
        if not vim.api.nvim_tabpage_is_valid(entry.tab) then
          open_tabs[name] = nil
          close_workspace_buffers(entry.path)
        end
      end
    end,
  })

  vim.api.nvim_create_user_command('WorkspaceAdd', function(cmd_opts)
    local args = vim.split(cmd_opts.args, '%s+', { trimempty = true })
    M.add(args[1], args[2])
  end, { nargs = '*', desc = 'Register a workspace' })

  vim.api.nvim_create_user_command('WorkspaceRemove', function()
    M.pick_remove()
  end, { nargs = 0, desc = 'Remove a workspace' })

  vim.api.nvim_create_user_command('WorkspaceList', function()
    M.pick()
  end, { nargs = 0, desc = 'List and open workspaces' })

  vim.api.nvim_create_user_command('WorkspaceOpen', function(cmd_opts)
    M.open(cmd_opts.args)
  end, {
    nargs = 1,
    desc = 'Open workspace by name',
    complete = function()
      return vim.tbl_map(function(ws)
        return ws.name
      end, load_workspaces())
    end,
  })
end

return M
