local M = {}

-- global var to track buffer & window
vim.g.terminal_buf_id = nil
vim.g.terminal_win_id = nil
vim.g.terminal_win_w = nil
vim.g.terminal_win_h = nil

-- define functions to resize the window
M.resize_terminal = {
  taller = function()
    vim.g.terminal_win_h = vim.g.terminal_win_h + 2
    vim.api.nvim_win_set_height(vim.g.terminal_win_id, vim.g.terminal_win_h)
  end,
  shorter = function()
    vim.g.terminal_win_h = vim.g.terminal_win_h - 2
    vim.api.nvim_win_set_height(vim.g.terminal_win_id, vim.g.terminal_win_h)
  end,
  wider = function()
    vim.g.terminal_win_w = vim.g.terminal_win_w + 2
    vim.api.nvim_win_set_width(vim.g.terminal_win_id, vim.g.terminal_win_w)
  end,
  narrower = function()
    vim.g.terminal_win_w = vim.g.terminal_win_w - 2
    vim.api.nvim_win_set_width(vim.g.terminal_win_id, vim.g.terminal_win_w)
  end,
}

function M.toggle_terminal(opts)
  opts = opts or {}
  local w = opts.width or 0.6
  local h = opts.height or 0.85

  local get_win_config = function()
    return {
      relative = "editor",
      width = vim.g.terminal_win_w or math.floor(vim.o.columns * w),
      height = vim.g.terminal_win_h or math.floor(vim.o.lines * h),
      col = math.floor((vim.o.columns - (vim.g.terminal_win_w or math.floor(vim.o.columns * w))) / 2),
      row = math.floor((vim.o.lines - (vim.g.terminal_win_h or math.floor(vim.o.lines * h))) / 2),
      border = "rounded",
    }
  end

  -- terminal window exists + is open -> close
  if vim.g.terminal_win_id and vim.api.nvim_win_is_valid(vim.g.terminal_win_id) then
    vim.api.nvim_win_close(vim.g.terminal_win_id, true)
    vim.g.terminal_win_id = nil
    return
  end

  -- buffer exists + window closed -> reopen
  if vim.g.terminal_buf_id and vim.api.nvim_buf_is_valid(vim.g.terminal_buf_id) then
    vim.g.terminal_win_id = vim.api.nvim_open_win(vim.g.terminal_buf_id, true, get_win_config())
    return
  end

  -- create a new terminal
  vim.g.terminal_buf_id = vim.api.nvim_create_buf(true, true) -- scratch buffer
  vim.g.terminal_win_id = vim.api.nvim_open_win(vim.g.terminal_buf_id, true, get_win_config())
  vim.g.terminal_win_h = get_win_config().height
  vim.g.terminal_win_w = get_win_config().width

  vim.fn.termopen(vim.o.shell, {
    on_exit = function()
      if vim.g.terminal_win_id and vim.api.nvim_win_is_valid(vim.g.terminal_win_id) then
        vim.api.nvim_win_close(vim.g.terminal_win_id, true)
        vim.g.terminal_win_id = nil
        vim.g.terminal_buf_id = nil
        vim.g.terminal_win_h = nil
        vim.g.terminal_win_w = nil
      end
    end
  })

  vim.api.nvim_buf_set_keymap(
    vim.g.terminal_buf_id, "n", "<C-A-t>",
    "<CMD>lua require('config.terminal').resize_terminal.taller()<CR>",
    { silent = true, desc = "resize [t]aller" }
  )
  vim.api.nvim_buf_set_keymap(
    vim.g.terminal_buf_id, "n", "<C-A-s>",
    "<CMD>lua require('config.terminal').resize_terminal.shorter()<CR>",
    { silent = true, desc = "resize [s]horter" }
  )
  vim.api.nvim_buf_set_keymap(
    vim.g.terminal_buf_id, "n", "<C-A-w>",
    "<CMD>lua require('config.terminal').resize_terminal.wider()<CR>",
    { silent = true, desc = "resize [w]ider" }
  )
  vim.api.nvim_buf_set_keymap(
    vim.g.terminal_buf_id, "n", "<C-A-n>",
    "<CMD>lua require('config.terminal').resize_terminal.narrower()<CR>",
    { silent = true, desc = "resize [n]arrower" }
  )
end

return M
