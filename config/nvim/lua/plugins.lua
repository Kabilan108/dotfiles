-- plugins.lua
-- set up plugins for nvim

local local_plugins = vim.fn.stdpath 'config' .. '/plugins'

local home = os.getenv("HOME")
package.path = package.path .. ";" .. home .. ".luarocks/lib/luarocks/rocks-5.1"

return {
  "numToStr/Comment.nvim",
  "nvim-lua/plenary.nvim",
  "nvim-lualine/lualine.nvim",
  "nvim-tree/nvim-web-devicons",
  "wakatime/vim-wakatime",

  {
    'stevearc/oil.nvim',
    ---@module 'oil'
    opts = {
      columns = { "icon", "permissions", "size" },
      watch_for_changes = true,
      view_options = { show_hidden = true }
    },
    -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
    lazy = false,
  },

  { "kabilan108/droid.nvim",  config = function() require("droid").setup({}) end },
  { "kabilan108/pyrepl.nvim", config = function() require("pyrepl").setup({}) end },
  {
    "kabilan108/claude-code.nvim",
    requires = { "nvim-lua/plenary.nvim" },
    config = function()
      require("claude-code").setup({
        keymaps = {
          toggle = {
            normal = "<leader>cc",
            terminal = "<leader>cc",
            variants = {
              continue = "<leader>cr",
              verbose = "<leader>cv",
            },
          },
        },
      })
    end
  },

  { "lukas-reineke/indent-blankline.nvim", main = "ibl",                          opts = {} },
  { "neovim/nvim-lspconfig",               dependencies = { "j-hui/fidget.nvim" } },

  -- debugger
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
      "nvim-neotest/nvim-nio"
    }
  },

  -- autocompletion
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
  },

  -- Add LuaSnip configuration
  {
    "L3MON4D3/LuaSnip",
    version = "v2.*",
    build = "make install_jsregexp",
    dependencies = {
      "rafamadriz/friendly-snippets",
      "honza/vim-snippets",
    },
  },

  -- typing practice
  {
    "nvzone/typr",
    dependencies = "nvzone/volt",
    opts = {},
    cmd = { "Typr", "TyprStats" }
  },

  -- todo comments
  {
    'folke/todo-comments.nvim',
    event = 'VimEnter',
    config = function()
      local colors = require("catppuccin.palettes").get_palette "mocha"
      require("todo-comments").setup({
        sign_priority = 6,
        signs = true,
        keywords = {
          FIX = {
            icon = " ",
            color = colors.red,
            alt = { "BUG", "ISSUE", "fix", "bug", "issue" },
          },
          TODO = { icon = " ", color = colors.blue, alt = { "todo" } },
          WARN = { icon = " ", color = colors.orange, alt = { "warn" } },
          NOTE = { icon = " ", color = colors.teal, alt = { "INFO", "note", "info" } },
          WHY = { icon = " ", color = colors.cyan, alt = { "why" } },
        },
      })
    end
  },

  -- telescope
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    dependencies = { "nvim-telescope/telescope-ui-select.nvim" },
    config = function()
      require("telescope").setup {
        pickers = {
          find_files = { hidden = true, }
        },
        extensions = {
          ["ui-select"] = { require("telescope.themes").get_dropdown {} }
        }
      }
      -- To get ui-select loaded and working with telescope, you need to call
      -- load_extension, somewhere after setup function:
      require("telescope").load_extension("ui-select")
    end
  },

  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local harpoon = require("harpoon")
      local harpoon_extensions = require("harpoon.extensions")
      harpoon:setup({})
      harpoon:extend(harpoon_extensions.builtins.highlight_current_file())
    end
  },

  {
    "natecraddock/workspaces.nvim",
    config = function()
      require("workspaces").setup({
        hooks = {
          cd_type = "local",
          open = { "Oil" }
        }
      })
      require("telescope").load_extension("workspaces")
    end
  },

  -- {
  --   'ggml-org/llama.vim',
  --   init = function()
  --     -- get the LLAMA_SERVER url env var
  --     local url = os.getenv("LLAMA_SERVER_URL") or "http://localhost:8012"
  --     vim.g.llama_config = {
  --       endpoint = url .. "/infill",
  --       show_info = 1,
  --       keymap_trigger = "<C-c>",
  --       keymap_accept_full = "<C-s>",
  --       keymap_accept_line = "<C-l>",
  --       keymap_accept_word = "<C-w>",
  --     }
  --   end
  -- },

  {
    "supermaven-inc/supermaven-nvim",
    config = function()
      local colors = require("catppuccin.palettes").get_palette "mocha"
      require("supermaven-nvim").setup({
        keymaps = {
          accept_suggestion = "<C-s>",
          clear_suggestion = "<C-]>",
          accept_word = "<C-w>",
        },
        color = {
          suggestion_color = colors.subtext0,
          cterm = 244,
        },
      })
    end,
  },

  -- mini.nvim
  { -- Collection of various small independent plugins/modules
    'echasnovski/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [']quote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup {
        highlight_duration = 1000,
      }

      require('mini.pairs').setup()
      require('mini.notify').setup()
      require('mini.trailspace').setup()
    end,
  },

  -- treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local configs = require("nvim-treesitter.configs")
      configs.setup({
        auto_install = true,
        sync_install = false,
        highlight = { enable = true },
        indent = { enable = true },
        ensure_installed = {
          "bash",
          "lua",
          "markdown",
          "markdown_inline",
          "python",
        }
      })
    end
  },

  -- theme (catppuccin)
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        compile_path = vim.fn.stdpath "cache" .. "/catppuccin",
        default_integrations = false,
        integrations = {
          cmp = true,
          fidget = true,
          gitsigns = true,
          indent_blankline = {
            enabled = true,
            scope_color = "lavender",
            color_indent_levels = false,
          },
          neotree = true,
          native_lsp = {
            enabled = true,
            virtual_text = {
              errors = { "italic" },
              hints = { "italic" },
              warnings = { "italic" },
              information = { "italic" },
              ok = { "italic" },
            },
            underlines = {
              errors = { "underline" },
              hints = { "underline" },
              warnings = { "underline" },
              information = { "underline" },
              ok = { "underline" },
            },
            inlay_hints = {
              background = true,
            },
          },
          telescope = {
            enabled = true,
          },
          treesitter = true,
          which_key = true,
        },
        custom_highlights = function(colors)
          return {
            -- Better folding colors
            Folded = { bg = colors.surface0, fg = colors.overlay1, style = { "italic" } },
            FoldColumn = { bg = colors.base, fg = colors.surface2 },
          }
        end,
      })
      vim.cmd.colorscheme "catppuccin-mocha"
    end
  },

  -- git signs
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup({
        signs                        = {
          add          = { text = '┃' },
          change       = { text = '┃' },
          delete       = { text = '_' },
          topdelete    = { text = '‾' },
          changedelete = { text = '~' },
          untracked    = { text = '┆' },
        },
        signs_staged                 = {
          add          = { text = '┃' },
          change       = { text = '┃' },
          delete       = { text = '_' },
          topdelete    = { text = '‾' },
          changedelete = { text = '~' },
          untracked    = { text = '┆' },
        },
        signs_staged_enable          = true,
        signcolumn                   = true,
        numhl                        = true,
        linehl                       = false,
        word_diff                    = false,
        watch_gitdir                 = {
          follow_files = true
        },
        diff_opts                    = {
          algorithm = 'histogram',
          internal = true,
        },
        auto_attach                  = true,
        attach_to_untracked          = false,
        current_line_blame           = true,
        current_line_blame_opts      = {
          virt_text = true,
          virt_text_pos = 'eol', -- 'eol' | 'overlay' | 'right_align'
          delay = 200,
          ignore_whitespace = false,
          virt_text_priority = 100,
          use_focus = true,
        },
        current_line_blame_formatter = '<author>, <author_time:%R> - <summary>',
        sign_priority                = 6,
        update_debounce              = 100,
        status_formatter             = nil,
        max_file_length              = 40000,
        preview_config               = {
          -- Options passed to nvim_open_win
          border = 'single',
          style = 'minimal',
          relative = 'cursor',
          row = 0,
          col = 1
        },
      })
    end,
  },
}
