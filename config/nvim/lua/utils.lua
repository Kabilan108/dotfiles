-- utils.lua
-- reusable utility functions

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
      vim.opt_local.expandtab = not props.usetab -- use tabs instead of spaces for go.
      vim.opt_local.tabstop = props.width -- set tab width to 4.
      vim.opt_local.shiftwidth = props.width -- set shifted indent to 4.
      vim.opt_local.softtabstop = props.width -- use a soft tabstop of 4 for proper tab insertion.
    end,
  })
end

---@return string
M.get_current_line = function()
  return vim.api.nvim_get_current_line()
end

---@return string[]
M.get_visual_selection = function()
  local _, srow, scol = unpack(vim.fn.getpos 'v')
  local _, erow, ecol = unpack(vim.fn.getpos '.')

  -- Handle Visual Line mode ('V')
  if vim.fn.mode() == 'V' then
    -- Ensure srow is always less than or equal to erow
    if srow > erow then
      srow, erow = erow, srow
    end
    return vim.api.nvim_buf_get_lines(0, srow - 1, erow, true)
  end

  -- Handle Visual mode ('v') and Visual Block mode ('<C-v>')
  -- For simplicity, treat visual block like character visual for line extraction
  if vim.fn.mode():find('v', 1, true) then
    -- Determine start and end positions correctly regardless of selection direction
    local start_pos, end_pos
    if srow < erow or (srow == erow and scol <= ecol) then
      start_pos = { srow - 1, scol - 1 }
      end_pos = { erow - 1, ecol } -- nvim_buf_get_text end col is exclusive
    else
      start_pos = { erow - 1, ecol - 1 }
      end_pos = { srow - 1, scol } -- nvim_buf_get_text end col is exclusive
    end
    return vim.api.nvim_buf_get_text(0, start_pos[1], start_pos[2], end_pos[1], end_pos[2], {})
  end

  return {}
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
      -- execute current line
      M.map('<leader>x', 'n', function()
        local line = M.get_current_line()
        exec.line(line)
      end, 'execute line', { buffer = event.buf })

      -- execute visual selection
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

return M
