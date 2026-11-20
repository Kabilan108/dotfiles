local utils = require 'utils'

utils.setup_custom_indentation({ 'python', 'kotlin' }, { usetab = false, width = 4 })
utils.setup_custom_indentation('go', { usetab = true, width = 4 })

vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
  callback = function(event)
    local opts = { buffer = event.buf }

    utils.map('gd', 'n', function()
      require('telescope.builtin').lsp_definitions()
    end, 'lsp: goto definition', opts)
    utils.map('gr', 'n', function()
      require('telescope.builtin').lsp_references()
    end, 'lsp: goto references', opts)
    utils.map('gi', 'n', function()
      require('telescope.builtin').lsp_implementations()
    end, 'lsp: goto implementation', opts)
    utils.map('gt', 'n', function()
      require('telescope.builtin').lsp_type_definitions()
    end, 'lsp: goto typedef', opts)

    utils.map('<leader>ds', 'n', function()
      require('telescope.builtin').lsp_document_symbols()
    end, 'lsp: search document symbols', opts)
    utils.map('<leader>ws', 'n', function()
      require('telescope.builtin').lsp_dynamic_workspace_symbols()
    end, 'lsp: search workspace symbols', opts)

    utils.map('K', 'n', vim.lsp.buf.hover, 'lsp: hover documentation', opts)
    utils.map('[d', 'n', vim.diagnostic.goto_prev, 'lsp: prev diagnostic', opts)
    utils.map(']d', 'n', vim.diagnostic.goto_next, 'lsp: next diagnostic', opts)
    utils.map('gD', 'n', vim.lsp.buf.declaration, 'lsp: goto declaration', opts)

    utils.map('<leader>fb', 'n', function()
      require('conform').format { async = true, lsp_format = 'fallback' }
    end, 'format buffer', opts)
    utils.map('<leader>rn', 'n', vim.lsp.buf.rename, 'rename symbol', opts)
    utils.map('<leader>ca', 'n', vim.lsp.buf.code_action, 'code action', opts)
    utils.map('<leader>dq', 'n', vim.diagnostic.setloclist, 'show diagnostic quickfix', opts)

    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client.server_capabilities.documentHighlightProvider then
      local highlight_augroup = vim.api.nvim_create_augroup('lsp-highlight', { clear = false })
      vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.clear_references,
      })
      vim.api.nvim_create_autocmd('LspDetach', {
        group = vim.api.nvim_create_augroup('lsp-detach', { clear = true }),
        callback = function(event2)
          vim.lsp.buf.clear_references()
          vim.api.nvim_clear_autocmds { group = 'lsp-highlight', buffer = event2.buf }
        end,
      })
    end
  end,
})
