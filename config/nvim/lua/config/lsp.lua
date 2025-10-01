-- lsp.lua
-- configure LSPs

local servers = {
  bashls = {},
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
  nixd = {},
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
  },
  tailwindcss = {
    cmd = {'bunx', '--bun', '@tailwindcss/language-server', '--stdio'},
    filetypes = {
      'css', 'scss', 'sass', 'postcss',
      'html', 'htmldjango', 'vue', 'svelte',
      'javascript', 'javascriptreact', 'typescript', 'typescriptreact',
      'php', 'markdown', 'mdx'
    },
    root_dir = require('lspconfig.util').root_pattern(
      'tailwind.config.js',
      'tailwind.config.cjs',
      'tailwind.config.mjs',
      'tailwind.config.ts',
      'postcss.config.js',
      'postcss.config.cjs',
      'postcss.config.mjs',
      'postcss.config.ts',
      'package.json'
    ),
    settings = {
      tailwindCSS = {
        classAttributes = { 'class', 'className', 'class:list', 'classList', 'ngClass' },
        lint = {
          cssConflict = 'warning',
          invalidApply = 'error',
          invalidConfigPath = 'error',
          invalidScreen = 'error',
          invalidTailwindDirective = 'error',
          invalidVariant = 'error',
          recommendedVariantOrder = 'warning'
        },
        validate = true
      }
    },
  },
  ts_ls = {
    filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
    root_dir = require('lspconfig.util').root_pattern('package.json', 'tsconfig.json', 'jsconfig.json'),
    single_file_support = true,
  },
}

local lspconfig = require("lspconfig")
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = vim.tbl_deep_extend(
  'force', capabilities, require('cmp_nvim_lsp').default_capabilities()
)
for name, opts in pairs(servers) do
  opts.capabilities = vim.tbl_deep_extend(
    'force', {}, capabilities, opts.capabilities or {}
  )
  lspconfig[name].setup(opts)
end
