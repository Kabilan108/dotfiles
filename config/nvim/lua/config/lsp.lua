vim.diagnostic.config {
  virtual_text = true,
  update_in_insert = false,
}

local servers = {
  'bashls',
  'biome',
  'clangd',
  'dockerls',
  'gopls',
  'just',
  'lua_ls',
  'markdown_oxide',
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
  markdown_oxide = {
    root_markers = { '.obsidian', '.moxide.toml' },
    workspace_required = true,
    capabilities = {
      workspace = {
        didChangeWatchedFiles = { dynamicRegistration = true },
      },
    },
  },
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
        disableOrganizeImports = true,
      },
      python = {
        analysis = {
          ignore = { '*' },
        },
      },
    },
  },
  tailwindcss = {
    cmd = { 'bunx', '--bun', '@tailwindcss/language-server', '--stdio' },
    filetypes = vim.tbl_filter(function(ft)
      return ft ~= 'markdown' and ft ~= 'mdx'
    end, vim.lsp.config.tailwindcss.filetypes),
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

vim.lsp.commands['moxide.findReferences'] = function(command, ctx)
  local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
  local items = vim.lsp.util.locations_to_items(command.arguments[1].locations, client.offset_encoding)
  vim.fn.setqflist({}, ' ', { title = command.title, items = items })
  vim.cmd.copen()
end

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('markdown-oxide-codelens', { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == 'markdown_oxide' then
      vim.lsp.codelens.enable(true, { bufnr = args.buf })
      vim.keymap.set('n', '<leader>cl', vim.lsp.codelens.run, { buffer = args.buf, desc = 'lsp: run codelens' })
    end
  end,
})
