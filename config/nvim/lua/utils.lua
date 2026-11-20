local M = {}

---@param keys string
---@param mode string|table
---@param func function|string
---@param desc? string
---@param opts? table
---@return nil
M.map = function(keys, mode, func, desc, opts)
  opts = opts or {}
  opts.desc = desc or ''
  opts.noremap = opts.noremap == nil and true or opts.noremap
  opts.silent = opts.silent == nil and true or opts.silent
  vim.keymap.set(mode or 'n', keys, func, opts)
end

---@class utils.IndentProps
---@field usetab boolean
---@field width integer

---@param lang string|table
---@param props utils.IndentProps
---@return nil
M.setup_custom_indentation = function(lang, props)
  vim.api.nvim_create_autocmd('FileType', {
    pattern = lang,
    callback = function()
      vim.opt_local.expandtab = not props.usetab
      vim.opt_local.tabstop = props.width
      vim.opt_local.shiftwidth = props.width
      vim.opt_local.softtabstop = props.width
    end,
  })
end

---@return string
M.get_current_line = function()
  return vim.api.nvim_get_current_line()
end

---@return string[]
M.get_visual_selection = function()
  local mode = vim.fn.mode()
  if mode ~= 'v' and mode ~= 'V' and mode ~= '\22' then
    return {}
  end

  return vim.fn.getregion(vim.fn.getpos 'v', vim.fn.getpos '.', { type = mode })
end

---@class utils.Executor
---@field line fun(line: string): any
---@field lines fun(lines: string[]): any

---@param lang string
---@param exec utils.Executor
---@return nil
M.setup_exec_kmaps = function(lang, exec)
  vim.api.nvim_create_autocmd('FileType', {
    pattern = lang,
    callback = function(event)
      M.map('<leader>x', 'n', function()
        local line = M.get_current_line()
        exec.line(line)
      end, 'execute line', { buffer = event.buf })

      M.map('<leader>x', 'v', function()
        local lines = M.get_visual_selection()
        exec.lines(lines)
      end, 'execute selection', { buffer = event.buf })
    end,
  })
end

M.cmp_icons = {
  Text = '',
  Method = '󰆧',
  Function = '󰊕',
  Constructor = '',
  Field = '󰇽',
  Variable = '󰂡',
  Class = '󰠱',
  Interface = '',
  Module = '',
  Property = '󰜢',
  Unit = '',
  Value = '󰎠',
  Enum = '',
  Keyword = '󰌋',
  Snippet = '',
  Color = '󰏘',
  File = '󰈙',
  Reference = '',
  Folder = '󰉋',
  EnumMember = '',
  Constant = '󰏿',
  Struct = '',
  Event = '',
  Operator = '󰆕',
  TypeParameter = '󰅲',
}

---@param bufnr integer
---@param start_line integer 1-indexed
---@param end_line integer 1-indexed
---@return string[]
M.get_diagnostics_in_range = function(bufnr, start_line, end_line)
  local diags = {}
  for lnum = start_line - 1, end_line - 1 do
    for _, d in ipairs(vim.diagnostic.get(bufnr, { lnum = lnum })) do
      local sev = vim.diagnostic.severity[d.severity]
      table.insert(diags, string.format('%s (line %d): %s', sev, d.lnum + 1, d.message))
    end
  end
  return diags
end

---@class utils.YankContextOpts
---@field include_diagnostics? boolean

---@param opts? utils.YankContextOpts
M.yank_with_context = function(opts)
  opts = opts or {}
  local filepath = vim.fn.expand '%:.'
  local filetype = vim.bo.filetype

  vim.cmd 'normal! "zy'
  local text = vim.fn.getreg 'z'

  local start_line = vim.fn.line "'<"
  local end_line = vim.fn.line "'>"

  local parts = {
    string.format('<file path="%s:%d-%d">', filepath, start_line, end_line),
    string.format('<snippet lang="%s">', filetype),
    text .. '</snippet>',
  }

  if opts.include_diagnostics then
    local diags = M.get_diagnostics_in_range(vim.api.nvim_get_current_buf(), start_line, end_line)
    if #diags > 0 then
      table.insert(parts, '<diagnostics>')
      for _, diag in ipairs(diags) do
        table.insert(parts, diag)
      end
      table.insert(parts, '</diagnostics>')
    end
  end

  table.insert(parts, '</file>')

  local formatted = table.concat(parts, '\n')
  vim.fn.setreg('+', formatted)
  vim.fn.system({ 'tmux', 'set-buffer', formatted })
end

return M
