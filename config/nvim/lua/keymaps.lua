-- keymaps.lua

local harpoon = require 'harpoon'
local luasnip = require 'luasnip'
local ts = require 'telescope.builtin'
local sessions = require 'mini.sessions'
local trailspace = require 'mini.trailspace'

local utils = require 'utils'
local custom_ts = require 'custom.telescope'
local custom_wt = require 'custom.worktree'
local custom_ws = require 'custom.workspaces'
custom_ws.setup()

---------------------------------------------------------------------------------------

-- general keymaps
utils.map('-', 'n', '<CMD>Oil<CR>', 'edit directory')
utils.map('<Esc>', 'n', '<CMD>nohlsearch<CR>', 'clear search')

-- telescope
utils.map('<leader>b', 'n', function()
  ts.buffers { sort_mru = true }
end, 'search buffers')
utils.map('<leader>sf', 'n', function()
  ts.find_files {
    hidden = true,
    follow = true,
    find_command = { 'rg', '--files', '--color', 'never', '-g', '!.git/**' },
  }
end, 'search files')
utils.map('<leader>sg', 'n', custom_ts.livegrep, 'search everything')
utils.map('<leader>sh', 'n', ts.help_tags, 'search help')
utils.map('<leader>sk', 'n', ts.keymaps, 'search keymaps')
utils.map('<leader>rs', 'n', ts.resume, 'resume search')
utils.map('<leader>sr', 'n', ts.oldfiles, 'search recent files')
utils.map('<leader>si', 'n', ts.git_status, 'search git index')

-- worktree management
utils.map('<leader>wt', 'n', custom_wt.pick, 'worktree: switch')
utils.map('<leader>w-', 'n', custom_wt.switch_previous, 'worktree: previous')
utils.map('<leader>wc', 'n', custom_wt.create, 'worktree: create')

-- workspace management
utils.map('<leader>pp', 'n', custom_ws.pick, 'workspace: pick')
utils.map('<leader>pa', 'n', function()
  custom_ws.add()
end, 'workspace: add cwd')
utils.map('<leader>pr', 'n', custom_ws.pick_remove, 'workspace: remove')

-- git staging with gitsigns
utils.map('<leader>ga', 'n', '<CMD>Gitsigns stage_buffer<CR>', 'git: stage current file')
utils.map('<leader>gs', 'n', '<CMD>Gitsigns stage_hunk<CR>', 'git: stage hunk')
utils.map('<leader>gu', 'n', '<CMD>Gitsigns undo_stage_hunk<CR>', 'git: unstage hunk')
utils.map('<leader>gr', 'n', '<CMD>Gitsigns reset_hunk<CR>', 'git: reset hunk')
utils.map('<leader>gb', 'n', '<CMD>Gitsigns blame_line<CR>', 'git: blame line')
utils.map('<leader>gq', 'n', '<CMD>Gitsigns setloclist<CR>', 'git: show hunks in quickfix')
utils.map('<leader>gn', 'n', '<CMD>Gitsigns nav_hunk next<CR>', 'git: next hunk')
utils.map('<leader>gp', 'n', '<CMD>Gitsigns nav_hunk prev<CR>', 'git: prev hunk')
utils.map('<leader>dd', 'n', function()
  vim.cmd [[
    Gitsigns toggle_deleted
    Gitsigns toggle_linehl
    Gitsigns toggle_current_line_blame
  ]]
end, 'git: diff mode')

-- sessions
utils.map('<leader>sl', 'n', sessions.read, 'session load')
utils.map('<leader>ss', 'n', '<CMD>mksession<CR>', 'session save')

-- trim whitespace
utils.map('<leader>tw', 'n', trailspace.trim, 'trim whitespace')

-- disable arrow keys in normal mode
local keys = { '<left>', '<right>', '<up>', '<down>' }
for i = 1, #keys do
  utils.map(keys[i], 'n', function()
    vim.cmd 'echo "retard."'
    vim.defer_fn(function()
      vim.cmd 'echon ""'
    end, 3000)
  end)
end

-- window resizing
utils.map('<C-A-t>', 'n', '<CMD>resize +2<CR>', 'resize: taller')
utils.map('<C-A-s>', 'n', '<CMD>resize -2<CR>', 'resize: shorter')
utils.map('<C-A-w>', 'n', '<CMD>vertical resize +2<CR>', 'resize: wider')
utils.map('<C-A-n>', 'n', '<CMD>vertical resize -2<CR>', 'resize: narrower')

-- tab navigation
utils.map('<leader>tt', 'n', '<CMD>tabnew<CR>', 'new tab')
utils.map('<leader>tn', 'n', '<CMD>tabnext<CR>', 'next tab')
utils.map('<A->>', 'n', '<CMD>tabnext<CR>', 'next tab')
utils.map('<leader>tp', 'n', '<CMD>tabprevious<CR>', 'previous tab')
utils.map('<A-<>', 'n', '<CMD>tabprevious<CR>', 'previous tab')

-- buffer navigation
utils.map('bp', 'n', '<CMD>bp<CR>', 'previous buffer')
utils.map('bn', 'n', '<CMD>bn<CR>', 'next bugger')
utils.map('bcc', 'n', '<CMD>enew<CR>', 'clear buffer')

-- increment & decrement numbers
utils.map('<C-i>', 'n', '<C-a>', 'increment')
utils.map('<C-d>', 'n', '<C-x>', 'decrement')

-- terminal mode
utils.map('<C-`>', 'n', function()
  vim.cmd 'split | terminal'
end, 'open horizontal terminal split')
utils.map('<C-n>', 't', '<C-\\><C-n>', 'exit terminal mode')

-- harpoon
utils.map('<leader>a', 'n', function()
  harpoon:list():add()
end, 'add harpoon')
utils.map('<leader>h', 'n', function()
  harpoon.ui:toggle_quick_menu(harpoon:list())
end, 'list harpoons')
utils.map('<leader>1', 'n', function()
  harpoon:list():select(1)
end)
utils.map('<leader>2', 'n', function()
  harpoon:list():select(2)
end)
utils.map('<leader>3', 'n', function()
  harpoon:list():select(3)
end)
utils.map('<leader>4', 'n', function()
  harpoon:list():select(4)
end)
utils.map('<C-P>', 'n', function()
  harpoon:list():prev()
end)
utils.map('<C-N>', 'n', function()
  harpoon:list():next()
end)
harpoon:extend {
  UI_CREATE = function(cx)
    utils.map('<C-v>', 'n', function()
      harpoon.ui:select_menu_item { vsplit = true }
    end, '', { buffer = cx.bufnr })
    utils.map('<C-s>', 'n', function()
      harpoon.ui:select_menu_item { split = true }
    end, '', { buffer = cx.bufnr })
    utils.map('<C-t>', 'n', function()
      harpoon.ui:select_menu_item { tabedit = true }
    end, '', { buffer = cx.bufnr })
  end,
}

-- window navigation is handled by vim-tmux-navigator (<C-h/j/k/l> cross
-- seamlessly between nvim splits and tmux panes)

-- treesitter context: jump to sticky context (defers to native [c in diff mode)
utils.map('[c', 'n', function()
  if vim.wo.diff then
    vim.cmd 'normal! [c'
  else
    require('treesitter-context').go_to_context(vim.v.count1)
  end
end, 'jump to context')

-- visual mode indentation that preserves selection
utils.map('<Tab>', 'v', '>gv', 'indent and keep selection')
utils.map('<S-Tab>', 'v', '<gv', 'unindent and keep selection')

-- yank with file context (for pasting into Claude Code, etc.)
utils.map('<leader>cc', 'v', function()
  utils.yank_with_context()
end, 'yank selection with file context')

utils.map('<leader>cd', 'v', function()
  utils.yank_with_context { include_diagnostics = true }
end, 'yank selection with file context and diagnostics')

-- snippets
utils.map('<C-k>', { 'i', 's' }, function()
  if luasnip.expand_or_jumpable() then
    luasnip.expand_or_jump()
  end
end, 'LuaSnip forward jump')

utils.map('<C-j>', { 'i', 's' }, function()
  if luasnip.jumpable(-1) then
    luasnip.jump(-1)
  end
end, 'LuaSnip backward jump')

utils.map('<M-l>', { 'i', 's' }, function()
  if luasnip.choice_active() then
    luasnip.change_choice(1)
  end
end, 'LuaSnip next choice')

-- code execution
---@type table<string, utils.Executor>
local executors = {
  lua = {
    line = function(line)
      local ok, result = pcall(load(line))
      if ok and result ~= nil then
        print(vim.inspect(result))
      elseif not ok then
        print('Error: ' .. tostring(result))
      end
    end,
    lines = function(lines)
      local code = table.concat(lines, '\n')
      local ok, result = pcall(load(code))
      if ok and result ~= nil then
        print(vim.inspect(result))
      elseif not ok then
        print('Error: ' .. tostring(result))
      end
    end,
  },
  python = {
    line = require('pyrepl').execute_line,
    lines = require('pyrepl').execute_lines,
  },
}
for lang, exec in pairs(executors) do
  utils.setup_exec_kmaps(lang, exec)
end

-- format json with jq
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'json',
  callback = function(event)
    utils.map('<leader>jq', 'n', function()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      local input = table.concat(lines, '\n')
      local result = vim.fn.system('jq .', input)
      if vim.v.shell_error == 0 then
        vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(result, '\n', { trimempty = true }))
      else
        local filename = vim.fn.expand '%:.' or 'buffer'
        local qf = {}
        for _, err_line in ipairs(vim.split(result, '\n', { trimempty = true })) do
          local lnum = err_line:match 'at line (%d+)'
          local col = err_line:match 'column (%d+)'
          table.insert(qf, {
            filename = filename,
            lnum = tonumber(lnum) or 0,
            col = tonumber(col) or 0,
            text = err_line,
          })
        end
        vim.fn.setqflist(qf, 'r')
        vim.cmd 'copen'
      end
    end, 'format json with jq', { buffer = event.buf })
  end,
})

-- setup icat for python plotting
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'python',
  callback = function(event)
    utils.map('<leader>xi', 'n', function()
      local pyrepl = require 'pyrepl'
      pyrepl.execute_lines { '%load_ext icat', '%plt_icat' }
    end, 'setup icat for plotting', { buffer = event.buf })
  end,
})
