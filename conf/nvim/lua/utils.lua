-- utils.lua
-- reusable utility functions

M = {}

---@param keys string
---@param mode string|table
---@param func function|string
---@param desc? string
---@param opts? table
---@return nil
M.map = function(keys, mode, func, desc, opts)
  opts = opts or {}
  opts.desc = desc or ""
  opts.noremap = opts.noremap == nil and true or opts.noremap
  opts.silent = opts.silent == nil and true or opts.silent
  vim.keymap.set(mode or "n", keys, func, opts)
end

---@class utils.IndentProps
---@field usetab boolean
---@field width integer

---@param lang string|table
---@param props utils.IndentProps
---@return nil
M.setup_custom_indentation = function(lang, props)
  vim.api.nvim_create_autocmd("FileType", {
    pattern = lang,
    callback = function()
      vim.opt_local.expandtab = not props.usetab -- use tabs instead of spaces for go.
      vim.opt_local.tabstop = props.width     -- set tab width to 4.
      vim.opt_local.shiftwidth = props.width  -- set shifted indent to 4.
      vim.opt_local.softtabstop = props.width -- use a soft tabstop of 4 for proper tab insertion.
    end,
  })
end

---@class utils.Executor
---@field line fun(line: string): any
---@field lines fun(lines: string[]): any

---@param lang string
---@param exec utils.Executor
---@return nil
M.setup_exec_kmaps = function(lang, exec)
  vim.api.nvim_create_autocmd("FileType", {
    pattern = lang,
    callback = function(event)
      -- execute current line
      M.map("<leader>xx", "n", function()
        local line = vim.api.nvim_get_current_line()
        exec.line(line)
      end, "execute line", { buffer = event.buf })

      -- execute visual selection
      M.map("<leader>x", "v", function()
        local _, start_row, start_col = unpack(vim.fn.getpos("'<"))
        local _, end_row, end_col = unpack(vim.fn.getpos("'>"))
        local lines = vim.api.nvim_buf_get_text(
          0,
          start_row - 1,
          start_col - 1,
          end_row - 1,
          end_col,
          {}
        )
        exec.lines(lines)
      end, "execute selection", { buffer = event.buf })
    end,
  })
end

M.cmp_icons = {
  Text = "",
  Method = "󰆧",
  Function = "󰊕",
  Constructor = "",
  Field = "󰇽",
  Variable = "󰂡",
  Class = "󰠱",
  Interface = "",
  Module = "",
  Property = "󰜢",
  Unit = "",
  Value = "󰎠",
  Enum = "",
  Keyword = "󰌋",
  Snippet = "",
  Color = "󰏘",
  File = "󰈙",
  Reference = "",
  Folder = "󰉋",
  EnumMember = "",
  Constant = "󰏿",
  Struct = "",
  Event = "",
  Operator = "󰆕",
  TypeParameter = "󰅲",
}

return M
