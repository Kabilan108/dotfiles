local dap = require "dap"
local ui = require "dapui"
local vt = require "nvim-dap-virtual-text"

local function map(keymap, desc, func)
  vim.keymap.set("n", keymap, func, { noremap = true, silent = true, desc = desc })
end

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

-- keymaps
map("dt", "Toggle breakpoint", dap.toggle_breakpoint)
map("dr", "Run to cursor", dap.run_to_cursor)
map("dv", "Check value", function()
  ui.eval(nil, { enter = true })
end)
map("dc", "Continue", dap.continue)
map("di", "Step into", dap.step_into)
map("do", "Step over", dap.step_over)
map("du", "Step out", dap.step_out)
map("db", "Step back", dap.step_back)
map("dr", "Restart debugger", dap.restart)
map("de", "Close debugger", dap.close)

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
