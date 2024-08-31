return {
  {
    'projekt0n/github-nvim-theme',
    lazy = false, -- load on startup
    priority = 1000, -- load before others
    config = function()
      require('github-theme').setup()

      vim.cmd 'colorscheme github_dark_dimmed'
    end,
  },
}

-- vim: ts=2 sts=2 sw=2 et
