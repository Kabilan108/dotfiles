require('zeta').setup {
  endpoint = vim.env.ZETA_ENDPOINT or 'http://100.71.183.33:8000',
  model = 'zed-industries/zeta-2',
  enabled = true,
  keymaps = {
    trigger = '<C-c>',
    accept_full = '<C-s>',
    accept_line = '<C-l>',
    accept_word = '<C-w>',
  },
  debounce_ms = 150,
}
