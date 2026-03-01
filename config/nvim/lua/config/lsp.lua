-- lsp.lua
-- configure LSPs

-- enable virtual text diagnostic
vim.diagnostic.config {
  virtual_text = true,
  update_in_insert = false,
}

-- configure LSPs

local servers = {
  'bashls',
  'biome',
  'clangd',
  'dockerls',
  'gopls',
  'just',
  'lua_ls',
  'nixd',
  'oxlint',
  'rust_analyzer',
  'ruff',
  'tailwindcss',
  'ts_ls',
  'ty',
  'yamlls',
}

local custom_cfg = {
  gopls = {
    cmd = { 'gopls' },
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
        },
      },
    },
  },
  tailwindcss = {
    cmd = { 'bunx', '--bun', '@tailwindcss/language-server', '--stdio' },
  },
}

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())

for _, s in pairs(servers) do
  local opts = custom_cfg[s] or {}
  opts.capabilities = vim.tbl_deep_extend('force', {}, capabilities, opts.capabilities or {})
  vim.lsp.config(s, opts)
  vim.lsp.enable(s)
end
