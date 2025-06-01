local dap = require "dap"
local ui = require "dapui"
local vt = require "nvim-dap-virtual-text"

ui.setup()
vt.setup()
-- Configure adapters
local install_dir = vim.fn.stdpath("data") .. "/mason"
local codelldb_path = install_dir .. "/packages/codelldb/extension/adapter/codelldb"

dap.adapters.codelldb = {
  type = "server",
  port = "${port}",
  executable = {
    command = codelldb_path,
    args = { "--port", "${port}" }
  },
}

-- Define language configs
dap.configurations.cpp = {
  {
    name = "Launch file",
    type = "codelldb",
    request = "launch",
    program = function()
      return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
    end,
    cwd = "${workspaceFolder}",
  },
}

dap.configurations.c = dap.configurations.cpp

-- automatically open UI
dap.listeners.before.attach.dapui_config = function()
  ui.open()
end
dap.listeners.before.launch.dapui_config = function()
  ui.open()
end
dap.listeners.before.event_terminated.dapui_config = function()
  ui.close()
end
dap.listeners.before.event_exited.dapui_config = function()
  ui.close()
end

-- customize colors
vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#f38ba8" })
