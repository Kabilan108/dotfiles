local M = {}

-- global var to track buffer & window
vim.g.terminal_buf_id = nil
vim.g.terminal_win_id = nil

function M.toggle_terminal()
  -- if the terminal window exists & is open, close it
  if vim.g.terminal_win_id and vim.api.nvim_win_is_valid(vim.g.terminal_win_id) then
    vim.api.nvim_win_close(vim.g.terminal_win_id, true)
    vim.g.terminal_win_id = nil
    return
  end

  -- if the buffer exists but the window is closed, reopen it
  if vim.g.terminal_buf_id and vim.api.nvim_buf_is_valid(vim.g.terminal_buf_id) then
    local win_config = {
      relative = "editor",
      width = math.floor(vim.o.columns * 0.8),                                 -- 80% editor width
      height = math.floor(vim.o.lines * 0.8),                                  -- 80% editor height
      col = math.floor((vim.o.columns - math.floor(vim.o.columns * 0.8)) / 2), -- center horizontally
      row = math.floor((vim.o.lines - math.floor(vim.o.lines * 0.8)) / 2),     -- center horizontally
      style = "minimal",
      border = "rounded",
    }
    vim.g.terminal_win_id = vim.api.nvim_open_win(vim.g.terminal_buf_id, true, win_config)
    return
  end

  -- create a new terminal
  vim.g.terminal_buf_id = vim.api.nvim_create_buf(false, true) -- not listed, scratch buffer
  local win_config = {
    relative = "editor",
    width = math.floor(vim.o.columns * 0.8),                                 -- 80% editor width
    height = math.floor(vim.o.lines * 0.8),                                  -- 80% editor height
    col = math.floor((vim.o.columns - math.floor(vim.o.columns * 0.8)) / 2), -- center horizontally
    row = math.floor((vim.o.lines - math.floor(vim.o.lines * 0.8)) / 2),     -- center horizontally
    -- style = "minimal",
    border = "rounded",
  }
  vim.g.terminal_win_id = vim.api.nvim_open_win(vim.g.terminal_buf_id, true, win_config)
  vim.fn.termopen(vim.o.shell, {
    on_exit = function()
      if vim.g.terminal_win_id and vim.api.nvim_win_is_valid(vim.g.terminal_win_id) then
        vim.api.nvim_win_close(vim.g.terminal_win_id, true)
        vim.g.terminal_win_id = nil
        vim.g.terminal_buf_id = nil
      end
    end
  })
  vim.cmd("startinsert") -- enter terminal mode immediately

  -- buffer-local keymap to exit terminal mode
  vim.api.nvim_buf_set_keymap(vim.g.terminal_buf_id, "t", "<C-q>", "<C-\\><C-n>",
    { noremap = true, silent = true, desc = "Exit terminal mode" })
end

return M
