-- lualine.lua
-- configure lualine

local colors = require("catppuccin.palettes").get_palette "mocha"

local conditions = {
  buffer_not_empty = function()
    return vim.fn.empty(vim.fn.expand("%:t")) ~= 1
  end,
  hide_in_width = function()
    return vim.fn.winwidth(0) > 80
  end,
  check_git_workspace = function()
    local filepath = vim.fn.expand("%:p:h")
    local gitdir = vim.fn.finddir(".git", filepath .. ";")
    return gitdir and #gitdir > 0 and #gitdir < #filepath
  end,
}

-- Config
local config = {
  options = {
    -- Disable sections and component separators
    component_separators = "",
    section_separators = "",
    theme = "catppuccin",
  },
  sections = {
    -- these are to remove the defaults
    lualine_a = {},
    lualine_b = {},
    lualine_y = {},
    lualine_z = {},
    lualine_c = {
      {
        function() return "▊" end,
        color = { fg = colors.blue },
        padding = { left = 0, right = 1 },
      },
      {
        function() return vim.fn.mode() end,
        color = { fg = colors.lavender },
        padding = { left = 1, right = 1 },
      },

      {
        "filename",
        cond = conditions.buffer_not_empty,
        color = { fg = colors.blue },
      },
      { "location" },
      { "progress", color = { fg = colors.fg } },
      {
        -- spacer to middle
        function() return "%=" end,
      },
      {
        -- lsp info
        function()
          local buf_ft = vim.api.nvim_buf_get_option(0, "filetype")
          local clients = vim.lsp.get_clients()
          if next(clients) == nil then
            return "none"
          end
          local active_clients = {}
          for _, client in ipairs(clients) do
            local filetypes = client.config.filetypes
            if filetypes and vim.fn.index(filetypes, buf_ft) ~= -1 then
              table.insert(active_clients, client.name)
            end
          end
          if #active_clients == 0 then
            return "none"
          end
          return table.concat(active_clients, ", ")
        end,
        icon = " lsp:",
        color = { fg = colors.lavender },
      }
    },
    lualine_x = {
      {
        "diagnostics",
        sources = { "nvim_diagnostic" },
        symbols = { error = " ", warn = " ", info = " " },
        diagnostics_color = {
          error = { fg = colors.red },
          warn = { fg = colors.yellow },
          info = { fg = colors.cyan },
        },
      },
      {
        "diff",
        symbols = { added = "+", modified = "<>", removed = "-" },
        diff_color = {
          added = { fg = colors.green, gui = "bold" },
          modified = { fg = colors.orange, gui = "bold" },
          removed = { fg = colors.red, gui = "bold" },
        },
        cond = conditions.hide_in_width,
      },
      {
        "branch",
        icon = "",
        color = { fg = colors.violet, gui = "bold" },
      },
      {
        function() return "▊" end,
        color = { fg = colors.blue },
        padding = { left = 1 },
      },
    },
  },
  inactive_sections = {
    -- these are to remove the defaults
    lualine_a = {},
    lualine_b = {},
    lualine_y = {},
    lualine_z = {},
    lualine_c = {
      {
        function() return "▊" end,
        color = { fg = colors.overlay0 },
        padding = { left = 0, right = 1 },
      },
      {
        "filename",
        color = { fg = colors.overlay1 },
        path = 1,
      },
    },
    lualine_x = {
      {
        function() return "▊" end,
        color = { fg = colors.overlay0 },
        padding = { left = 1 },
      },
    },
  },
}

require("lualine").setup(config)
