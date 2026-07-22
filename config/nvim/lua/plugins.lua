-- plugins.lua
-- set up plugins for nvim

-- local local_plugins = vim.fn.stdpath 'config' .. '/plugins'

return {
  'numToStr/Comment.nvim',
  'nvim-lua/plenary.nvim',
  'christoomey/vim-tmux-navigator',
  'kitlangton/navi.nvim',
  {
    'nvim-lualine/lualine.nvim',
    event = 'VeryLazy',
    config = function()
      require 'config.lualine'
    end,
  },
  'nvim-tree/nvim-web-devicons',

  {
    'stevearc/oil.nvim',
    ---@module 'oil'
    opts = {
      columns = { 'icon', 'permissions', 'size' },
      watch_for_changes = true,
      view_options = { show_hidden = true },
      keymaps = {
        ['<C-h>'] = false,
        ['<C-s>'] = { 'actions.select', opts = { horizontal = true } },
        ['<C-A-s>'] = { 'actions.select', opts = { vertical = true } },
        ['<C-l>'] = false,
        ['<C-A-r>'] = 'actions.refresh',
      },
    },
    -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
    lazy = false,
  },

  {
    'kabilan108/droid.nvim',
    keys = {
      { '<leader>ll', mode = { 'n', 'v' }, desc = 'llm: help' },
      { '<leader>ln', mode = { 'n', 'v' }, desc = 'llm: create buffer' },
      { '<leader>lb', mode = { 'n', 'v' }, desc = 'llm: list buffers' },
      { '<leader>le', mode = { 'n', 'v' }, desc = 'llm: edit' },
      { '<leader>lm', mode = { 'n', 'v' }, desc = 'llm: select model' },
      { '<leader>lG', mode = { 'n', 'v' }, desc = 'llm: jump to new' },
      { '<leader>lc', desc = 'llm: cancel stream' },
    },
    config = function()
      require 'config.llm'
    end,
  },
  {
    'kabilan108/pyrepl.nvim',
    ft = 'python',
    config = function()
      require('pyrepl').setup {}
    end,
  },

  {
    'lukas-reineke/indent-blankline.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
    main = 'ibl',
    opts = {},
  },
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = { 'j-hui/fidget.nvim', 'hrsh7th/cmp-nvim-lsp' },
    config = function()
      require 'config.lsp'
    end,
  },

  -- autocompletion
  {
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-path',
      'L3MON4D3/LuaSnip',
      'saadparwaiz1/cmp_luasnip',
      'rafamadriz/friendly-snippets',
    },
    config = function()
      require 'config.completion'
    end,
  },

  -- Add LuaSnip configuration
  {
    'L3MON4D3/LuaSnip',
    event = 'InsertEnter',
    keys = {
      {
        '<C-k>',
        function()
          local luasnip = require 'luasnip'
          if luasnip.expand_or_jumpable() then
            luasnip.expand_or_jump()
          end
        end,
        mode = { 'i', 's' },
        desc = 'LuaSnip forward jump',
      },
      {
        '<C-j>',
        function()
          local luasnip = require 'luasnip'
          if luasnip.jumpable(-1) then
            luasnip.jump(-1)
          end
        end,
        mode = { 'i', 's' },
        desc = 'LuaSnip backward jump',
      },
      {
        '<M-l>',
        function()
          local luasnip = require 'luasnip'
          if luasnip.choice_active() then
            luasnip.change_choice(1)
          end
        end,
        mode = { 'i', 's' },
        desc = 'LuaSnip next choice',
      },
    },
    version = 'v2.*',
    build = 'make install_jsregexp',
    dependencies = {
      'rafamadriz/friendly-snippets',
      'honza/vim-snippets',
    },
    config = function()
      require 'config.snippets'
    end,
  },

  -- todo comments
  {
    'folke/todo-comments.nvim',
    event = 'VimEnter',
    config = function()
      local colors = require('catppuccin.palettes').get_palette 'mocha'
      require('todo-comments').setup {
        sign_priority = 6,
        signs = true,
        keywords = {
          FIX = {
            icon = ' ',
            color = colors.red,
            alt = { 'BUG', 'ISSUE', 'fix', 'bug', 'issue' },
          },
          TODO = { icon = ' ', color = colors.blue, alt = { 'todo' } },
          WARN = { icon = ' ', color = colors.orange, alt = { 'warn' } },
          NOTE = { icon = ' ', color = colors.teal, alt = { 'INFO', 'note', 'info' } },
          WHY = { icon = ' ', color = colors.cyan, alt = { 'why' } },
        },
      }
    end,
  },

  -- telescope
  {
    'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-telescope/telescope-ui-select.nvim' },
    keys = {
      {
        '<leader>b',
        function()
          require('telescope.builtin').buffers { sort_mru = true }
        end,
        desc = 'search buffers',
      },
      {
        '<leader>sf',
        function()
          require('telescope.builtin').find_files {
            hidden = true,
            follow = true,
            find_command = { 'rg', '--files', '--color', 'never', '-g', '!.git/**' },
          }
        end,
        desc = 'search files',
      },
      {
        '<leader>sg',
        function()
          require('custom.telescope').livegrep()
        end,
        desc = 'search everything',
      },
      {
        '<leader>sh',
        function()
          require('telescope.builtin').help_tags()
        end,
        desc = 'search help',
      },
      {
        '<leader>sk',
        function()
          require('telescope.builtin').keymaps()
        end,
        desc = 'search keymaps',
      },
      {
        '<leader>rs',
        function()
          require('telescope.builtin').resume()
        end,
        desc = 'resume search',
      },
      {
        '<leader>sr',
        function()
          require('telescope.builtin').oldfiles()
        end,
        desc = 'search recent files',
      },
      {
        '<leader>si',
        function()
          require('telescope.builtin').git_status()
        end,
        desc = 'search git index',
      },
      {
        '<leader>wt',
        function()
          require('custom.worktree').pick()
        end,
        desc = 'worktree: switch',
      },
      {
        '<leader>w-',
        function()
          require('custom.worktree').switch_previous()
        end,
        desc = 'worktree: previous',
      },
      {
        '<leader>wc',
        function()
          require('custom.worktree').create()
        end,
        desc = 'worktree: create',
      },
      {
        '<leader>pp',
        function()
          require('custom.workspaces').pick()
        end,
        desc = 'workspace: pick',
      },
      {
        '<leader>pa',
        function()
          require('custom.workspaces').add()
        end,
        desc = 'workspace: add cwd',
      },
      {
        '<leader>pr',
        function()
          require('custom.workspaces').pick_remove()
        end,
        desc = 'workspace: remove',
      },
    },
    config = function()
      require('telescope').setup {
        pickers = {
          find_files = { hidden = true },
        },
        extensions = {
          ['ui-select'] = { require('telescope.themes').get_dropdown {} },
        },
      }
      -- To get ui-select loaded and working with telescope, you need to call
      -- load_extension, somewhere after setup function:
      require('telescope').load_extension 'ui-select'
    end,
  },

  {
    'ThePrimeagen/harpoon',
    branch = 'harpoon2',
    dependencies = { 'nvim-lua/plenary.nvim' },
    keys = {
      {
        '<leader>a',
        function()
          require('harpoon'):list():add()
        end,
        desc = 'add harpoon',
      },
      {
        '<leader>h',
        function()
          local harpoon = require 'harpoon'
          harpoon.ui:toggle_quick_menu(harpoon:list())
        end,
        desc = 'list harpoons',
      },
      {
        '<leader>1',
        function()
          require('harpoon'):list():select(1)
        end,
      },
      {
        '<leader>2',
        function()
          require('harpoon'):list():select(2)
        end,
      },
      {
        '<leader>3',
        function()
          require('harpoon'):list():select(3)
        end,
      },
      {
        '<leader>4',
        function()
          require('harpoon'):list():select(4)
        end,
      },
      {
        '<C-P>',
        function()
          require('harpoon'):list():prev()
        end,
      },
      {
        '<C-N>',
        function()
          require('harpoon'):list():next()
        end,
      },
    },
    config = function()
      local harpoon = require 'harpoon'
      local harpoon_extensions = require 'harpoon.extensions'
      local utils = require 'utils'
      harpoon:setup {}
      harpoon:extend(harpoon_extensions.builtins.highlight_current_file())
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
    end,
  },

  {
    'ggml-org/llama.vim',
    enabled = false,
    init = function()
      local url = os.getenv 'LLAMA_SERVER_URL' or 'http://localhost:8012'
      vim.g.llama_config = {
        endpoint_fim = url .. '/infill',
        show_info = 1,
        keymap_fim_trigger = '<C-c>',
        keymap_fim_accept_full = '<C-s>',
        keymap_fim_accept_line = '<C-l>',
        keymap_fim_accept_word = '<C-w>',
      }
      vim.api.nvim_set_hl(0, 'llama_hl_hint', { fg = '#f2cdcd', ctermfg = 209 })
    end,
  },

  {
    'windwp/nvim-ts-autotag',
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    config = function()
      require('nvim-ts-autotag').setup {
        opts = {
          enable_close = true,
          enable_rename = true,
          enable_close_on_slash = true,
        },
        per_filetype = {
          ['tsx'] = {
            enable_close = true,
            enable_rename = true,
            enable_close_on_slash = true,
          },
        },
      }
    end,
  },

  {
    'davidmh/mdx.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    ft = { 'mdx' },
    init = function()
      vim.filetype.add { extension = { mdx = 'mdx' } }
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
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    event = { 'BufReadPost', 'BufNewFile' },
    config = function()
      local configs = require 'nvim-treesitter.configs'
      configs.setup {
        auto_install = true,
        sync_install = false,
        highlight = { enable = true },
        indent = { enable = true },
        ensure_installed = {
          'bash',
          'lua',
          'markdown',
          'markdown_inline',
          'python',
        },
      }
    end,
  },

  -- treesitter-context: sticky context for classes/functions
  {
    'nvim-treesitter/nvim-treesitter-context',
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = {
      enable = true,
      max_lines = 3,
      min_window_height = 0,
      line_numbers = true,
      multiline_threshold = 20,
      trim_scope = 'outer',
      mode = 'cursor',
      separator = nil,
      zindex = 20,
    },
  },

  -- conform
  {
    'stevearc/conform.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = function()
      return {
        -- run format on save, falling back to LSP if no external formatter
        formatters_by_ft = {
          lua = { 'stylua' },
          python = { 'ruff_organize_imports', 'ruff_format' },
          javascript = { 'oxfmt' },
          typescript = { 'oxfmt' },
          javascriptreact = { 'oxfmt' },
          typescriptreact = { 'oxfmt' },
          json = { 'oxfmt' },
          css = { 'oxfmt' },
          go = { 'gofmt' },
          nix = { 'nixfmt' },
        },
      }
    end,
  },

  -- theme (catppuccin)
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    config = function()
      require('catppuccin').setup {
        compile_path = vim.fn.stdpath 'cache' .. '/catppuccin',
        transparent_background = true,
        default_integrations = false,
        integrations = {
          cmp = true,
          fidget = true,
          gitsigns = true,
          indent_blankline = {
            enabled = true,
            scope_color = 'lavender',
            color_indent_levels = false,
          },
          neotree = true,
          native_lsp = {
            enabled = true,
            virtual_text = {
              errors = { 'italic' },
              hints = { 'italic' },
              warnings = { 'italic' },
              information = { 'italic' },
              ok = { 'italic' },
            },
            underlines = {
              errors = { 'underline' },
              hints = { 'underline' },
              warnings = { 'underline' },
              information = { 'underline' },
              ok = { 'underline' },
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
            Folded = { bg = colors.surface0, fg = colors.overlay1, style = { 'italic' } },
            FoldColumn = { bg = 'NONE', fg = colors.surface2 },
          }
        end,
      }
      vim.cmd.colorscheme 'catppuccin-mocha'
    end,
  },

  -- diffview for reviewing changes
  {
    'sindrets/diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewFileHistory' },
    keys = {
      { '<leader>gd', '<cmd>DiffviewOpen<cr>', desc = 'Open diffview' },
      { '<leader>gh', '<cmd>DiffviewFileHistory %<cr>', desc = 'File history' },
      { '<leader>gq', '<cmd>DiffviewClose<cr>', desc = 'Close diffview' },
    },
    opts = {
      enhanced_diff_hl = true,
      default_args = {
        DiffviewOpen = { '--imply-local' },
      },
    },
  },

  -- git signs
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      require('gitsigns').setup {
        signs = {
          add = { text = '┃' },
          change = { text = '┃' },
          delete = { text = '_' },
          topdelete = { text = '‾' },
          changedelete = { text = '~' },
          untracked = { text = '┆' },
        },
        signs_staged = {
          add = { text = '┃' },
          change = { text = '┃' },
          delete = { text = '_' },
          topdelete = { text = '‾' },
          changedelete = { text = '~' },
          untracked = { text = '┆' },
        },
        signs_staged_enable = true,
        signcolumn = true,
        numhl = true,
        linehl = false,
        word_diff = false,
        watch_gitdir = {
          follow_files = true,
        },
        diff_opts = {
          algorithm = 'histogram',
          internal = true,
        },
        auto_attach = true,
        attach_to_untracked = false,
        current_line_blame = true,
        current_line_blame_opts = {
          virt_text = true,
          virt_text_pos = 'eol', -- 'eol' | 'overlay' | 'right_align'
          delay = 200,
          ignore_whitespace = false,
          virt_text_priority = 100,
          use_focus = true,
        },
        current_line_blame_formatter = '<author>, <author_time:%R> - <summary>',
        sign_priority = 6,
        update_debounce = 100,
        status_formatter = nil,
        max_file_length = 40000,
        preview_config = {
          -- Options passed to nvim_open_win
          border = 'single',
          style = 'minimal',
          relative = 'cursor',
          row = 0,
          col = 1,
        },
      }
    end,
  },
}
