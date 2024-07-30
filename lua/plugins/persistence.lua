local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

-- load the session for the current directory
map('n', '<leader>qs', "<cmd>lua require('persistence').load()<CR>", opts)

-- select a session to load
map('n', '<leader>qS', "<cmd>lua require('persistence').select()<CR>", opts)

-- load the last session
map('n', '<leader>ql', "<cmd>lua require('persistence').load({ last = true })<CR>", opts)

-- stop Persistence => session won't be saved on exit
map('n', '<leader>qd', "<cmd>lua require('persistence').stop()<CR>", opts)

return {
  {
    'folke/persistence.nvim',
    event = 'BufReadPre',
    opts = {
      -- add any custom options here
    },
  },
}

-- vim: ts=2 sts=2 sw=2 et
