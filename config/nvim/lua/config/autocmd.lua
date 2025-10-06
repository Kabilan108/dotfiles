-- autocmd.lua
-- various autocommands

local utils = require 'utils'
local ts = require 'telescope.builtin'

-- custom indentation
utils.setup_custom_indentation({ 'python', 'kotlin' }, { usetab = false, width = 4 })
utils.setup_custom_indentation('go', { usetab = true, width = 4 })

-- highlight when copying
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- lsp keymaps: only available when lsp ataches
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
  callback = function(event)
    local opts = { buffer = event.buf }

    utils.map('gd', 'n', ts.lsp_definitions, 'lsp: goto definition', opts)
    utils.map('gr', 'n', ts.lsp_references, 'lsp: goto references', opts)
    utils.map('gi', 'n', ts.lsp_implementations, 'lsp: goto implementation', opts)
    utils.map('gt', 'n', ts.lsp_type_definitions, 'lsp: goto typedef', opts)

    utils.map('<leader>ds', 'n', ts.lsp_document_symbols, 'lsp: search document symbols', opts)
    utils.map('<leader>ws', 'n', ts.lsp_dynamic_workspace_symbols, 'lsp: search workspace symbols', opts)

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

    -- the following two autocommands are used to highlight references of the
    -- word under your cursor when your cursor rests there for a little while.
    --    see `:help cursorhold` for information about when this is executed
    -- when you move your cursor, the highlights will be cleared (the second autocommand).
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
