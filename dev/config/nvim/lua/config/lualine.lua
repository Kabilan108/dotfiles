-- lualine.lua
-- configure lualine

-- local lualine = require("lualine")

-- Color table for highlights
-- stylua: ignore

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
    lualine_c = {},
    lualine_x = {},
  },
  inactive_sections = {
    -- these are to remove the defaults
    lualine_a = {},
    lualine_b = {},
    lualine_y = {},
    lualine_z = {},
    lualine_c = {},
    lualine_x = {},
  },
}

-- Inserts a component in lualine_c at left section
local function ins_left(component)
  table.insert(config.sections.lualine_c, component)
end

-- Inserts a component in lualine_x at right section
local function ins_right(component)
  table.insert(config.sections.lualine_x, component)
end

-- left border
ins_left {
  function() return "▊" end,
  color = { fg = colors.blue },
  padding = { left = 0, right = 1 },
}

-- editor mode
ins_left {
  function() return vim.fn.mode() end,
  color = { fg = colors.lavender },
  padding = { left = 1, right = 1 },
}

ins_left {
  "filename",
  cond = conditions.buffer_not_empty,
  color = { fg = colors.blue },
}

-- [line]:[column]
ins_left { "location" }

ins_left { "progress", color = { fg = colors.fg } }

ins_left {
  "diagnostics",
  sources = { "nvim_diagnostic" },
  symbols = { error = " ", warn = " ", info = " " },
  diagnostics_color = {
    error = { fg = colors.red },
    warn = { fg = colors.yellow },
    info = { fg = colors.cyan },
  },
}

-- spacer to midle
ins_left {
  function() return "%=" end,
}

-- lsp info
ins_left {
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

ins_right {
  function()
    return require("droid").get_current_model() or "no llm"
  end,
  icon = "🤖",
  color = { fg = colors.blue },
}

ins_right {
  "filetype",
  fmt = string.upper,
  icons_enabled = false, -- I think icons are cool but Eviline doesn"t have them. sigh
  color = { fg = colors.green },
}

ins_right {
  "branch",
  icon = "",
  color = { fg = colors.violet, gui = "bold" },
}

ins_right {
  "diff",
  symbols = { added = "+", modified = "<>", removed = "-" },
  diff_color = {
    added = { fg = colors.green, gui = "bold" },
    modified = { fg = colors.orange, gui = "bold" },
    removed = { fg = colors.red, gui = "bold" },
  },
  cond = conditions.hide_in_width,
}

ins_right {
  function() return "▊" end,
  color = { fg = colors.blue },
  padding = { left = 1 },
}

require("lualine").setup(config)
