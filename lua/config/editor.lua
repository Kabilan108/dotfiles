-- editor.lua
-- configure plugins for editing code

-- autocomplete -----------------------------------------------------------------------

local cmp = require "cmp"
local luasnip = require "luasnip"

cmp.setup {
  completion = { completeopt = "menu,menuone,noinsert" },
  sources = {
    { name = "nvim_lsp" },
    { name = "luasnip" },
    { name = "path" },
  },
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
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

    -- Super Tab functionality
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { "i", "s" }),

    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { "i", "s" }),
  },
  formatting = {
    format = function(entry, vim_item)
      -- Kind icons
      vim_item.kind = string.format('%s %s', require('config.icons').kinds[vim_item.kind], vim_item.kind)
      -- Source
      vim_item.menu = ({
        nvim_lsp = "[LSP]",
        luasnip = "[Snippet]",
        path = "[Path]",
      })[entry.source.name]
      return vim_item
    end
  },
}

-- code execution ---------------------------------------------------------------------

require("pyrepl").setup({ show_errs = false })
vim.keymap.set("v", "<leader>xp", "<CMD>RunInPyrepl<CR>", {
  noremap = true, silent = true, desc = "e[x]ecute [p]ython"
})

-- lsp --------------------------------------------------------------------------------

-- define language servers
local servers = {
  biome = {
    cmd = { 'biome', 'lsp-proxy' },
    filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'json', 'css' },
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
  dockerls = {
    filetypes = { 'dockerfile' },
    root_dir = require('lspconfig.util').root_pattern('Dockerfile', '.dockerignore', 'docker-compose.yml', '.git'),
    single_file_support = true,
  },
  gopls = {
    cmd = { 'gopls' },
    filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
    root_dir = require('lspconfig.util').root_pattern('go.work', 'go.mod', '.git'),
    settings = {
      gopls = {
        analyses = {
          unusedparams = true,
        },
        staticcheck = true,
        gofumpt = true,
        usePlaceholders = true,
        completeUnimported = true,
      },
    },
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
  rust_analyzer = {},
  ruff = {
    cmd = { 'ruff', 'server' },
    init_options = {
      settings = {
        configuration = "~/.config/ruff/ruff.toml",
      }
    }
  },
  ts_ls = {
    filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
    root_dir = require('lspconfig.util').root_pattern('package.json', 'tsconfig.json', 'jsconfig.json'),
    single_file_support = true,
  },
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
  ensure_installed = { "biome", "clangd", "dockerls", "gopls", "lua_ls", "pyright", "rust_analyzer", "ts_ls" },
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

cmp.setup.filetype({ 'typr' }, {
  window = {
    completion = cmp.config.disable,
    documentation = cmp.config.disable,
  }
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "typr",
  callback = function()
    vim.fn['llama#disable']()
  end
})
