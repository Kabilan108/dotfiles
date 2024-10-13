return {
  {
    'shaunsingh/nord.nvim',
    lazy = false, -- load on startup
    priority = 1000, -- load before others
    config = function()
      vim.cmd [[colorscheme nord]]
    end,
  },
}

-- vim: ts=2 sts=2 sw=2 et
