-- editor.lua
-- configure plugins for editing code

-- autocomplete -----------------------------------------------------------------------

local cmp = require "cmp"

cmp.setup {
  completion = { completeopt = "menu,menuone,noinsert" },
  sources = {
    { name = "nvim_lsp" },
    { name = "path" },
  },
  mapping = cmp.mapping.preset.insert {
    -- Select the [n]ext item
    ['<C-n>'] = cmp.mapping.select_next_item(),

    -- Select the [p]revious item
    ['<C-p>'] = cmp.mapping.select_prev_item(),

    -- Scroll the documentation window [b]ack / [f]orward
    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),

    -- Accept ([y]es) the completion.
    --  This will auto-import if your LSP supports it.
    --  This will expand snippets if the LSP sent a snippet.
    ['<C-y>'] = cmp.mapping.confirm { select = true },

    -- Manually trigger a completion from nvim-cmp.
    --  Generally you don't need this, because nvim-cmp will display
    --  completions whenever it has completion options available.
    ['<C-Space>'] = cmp.mapping.complete {},
  }
}

-- lsp --------------------------------------------------------------------------------

-- define language servers
local servers = {
  biome = {
    cmd = { 'biome', 'lsp-proxy' },
    filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'json' },
    root_dir = require('lspconfig.util').root_pattern('biome.json', 'package.json'),
    single_file_support = true,
  },
  clangd = {
    cmd = { 'clangd' },
    filetypes = { 'c', 'cpp', 'cc', 'objc', 'objcpp' },
    root_dir = require('lspconfig.util').root_pattern(
      '.clangd',
      '.clang-tidy',
      '.clang-format',
      'compile_commands.json',
      'compile_flags.txt',
      'configure.ac',
      '.git'
    ),
    init_options = {
      clangdFileStatus = true,
      usePlaceholders = true,
      completeUnimported = true,
      semanticHighlighting = true,
    },
    settings = {},
  },
  lua_ls = {
    settings = {
      Lua = {
        completion = {
          callSnippet = 'Replace',
        },
      },
    },
  },
  pyright = {
    settings = {
      pyright = {
        -- use ruff's import organizer
        disableOrganizeImports = true,
      },
      python = {
        analysis = {
          -- ignore all files for analysis to exclusively use ruff for linting
          ignore = { '*' },
        }
      }
    }
  },
  ruff = {
    init_options = {
      settings = {
        configuration = "~/.config/ruff/ruff.toml",
      }
    }
  }
}

-- inform servers of completion capabilities
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = vim.tbl_deep_extend(
  'force', capabilities, require('cmp_nvim_lsp').default_capabilities()
)

-- set up mason to install servers
local lspconfig = require("lspconfig")
require('mason').setup()
require('mason-lspconfig').setup({
  ensure_installed = { "biome", "clangd", "lua_ls", "pyright", "ruff" },
  handlers = {
    function(server_name)
      local server = servers[server_name] or {}
      -- This handles overriding only values explicitly passed
      -- by the server configuration above. Useful when disabling
      -- certain features of an LSP (for example, turning off formatting for tsserver)
      server.capabilities = vim.tbl_deep_extend(
        'force', {}, capabilities, server.capabilities or {}
      )
      lspconfig[server_name].setup(server)
    end,
  },
})
