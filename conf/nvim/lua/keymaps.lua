-- keymaps.lua

local dap = require "dap"
local harpoon = require "harpoon"
local luasnip = require "luasnip"
local ts = require "telescope.builtin"
local sessions = require "mini.sessions"
local trailspace = require "mini.trailspace"

local llm = require "config.ghola"
local custom_ts = require "config.telescope"

---@class Executor
---@field line fun(line: string): any
---@field lines fun(lines: string[]): any

---@param keys string
---@param mode string|table
---@param func function|string
---@param desc? string
---@param opts? table
---@return nil
local function map(keys, mode, func, desc, opts)
  opts = opts or {}
  opts.desc = desc or ""
  opts.noremap = opts.noremap == nil and true or opts.noremap
  opts.silent = opts.silent == nil and true or opts.silent
  vim.keymap.set(mode or "n", keys, func, opts)
end

---@param lang string
---@param exec Executor
---@return nil
local setup_exec_kmaps = function(lang, exec)
  vim.api.nvim_create_autocmd("FileType", {
    pattern = lang,
    callback = function(event)
      -- execute current line
      map("<leader>xx", "n", function()
        local line = vim.api.nvim_get_current_line()
        exec.line(line)
      end, "execute line", { buffer = event.buf })

      -- execute visual selection
      map("<leader>x", "v", function()
        local _, start_row, start_col = unpack(vim.fn.getpos("'<"))
        local _, end_row, end_col = unpack(vim.fn.getpos("'>"))
        local lines = vim.api.nvim_buf_get_text(
          0,
          start_row - 1,
          start_col - 1,
          end_row - 1,
          end_col,
          {}
        )
        exec.lines(lines)
      end, "execute selection", { buffer = event.buf })
    end,
  })
end

---------------------------------------------------------------------------------------

-- general keymaps
map("-", "n", "<CMD>Oil<CR>", "edit directory")
map("<Esc>", "n", "<CMD>nohlsearch<CR>", "clear search")

-- telescope
map("<leader>b", "n", function() ts.buffers({ sort_mru = true }) end, "search buffers")
map(
  "<leader>sf", "n",
  function()
    ts.find_files({
      hidden = true,
      follow = true,
      find_command = { "rg", "--files", "--color", "never", "-g", "!.git/**" }
    })
  end,
  "search files"
)
map("<leader>sg", "n", custom_ts.livegrep, "search everything")
map("<leader>sh", "n", ts.help_tags, "search help")
map("<leader>sk", "n", ts.keymaps, "search keymaps")
map("<leader>rs", "n", ts.resume, "resume search")
map("<leader>sr", "n", ts.oldfiles, "search recent files")

-- sessions
map("<leader>sl", "n", sessions.read, "session load")
map("<leader>ss", "n", "<CMD>mksession<CR>", "session save")

-- trim whitespace
map("<leader>tw", "n", trailspace.trim, "trim whitespace")

-- disable arrow keys in normal mode
local keys = { '<left>', '<right>', '<up>', '<down>' }
for i = 1, #keys do
  map(keys[i], "n", function()
    vim.cmd('echo "retard."')
    vim.defer_fn(function()
      vim.cmd('echon ""')
    end, 3000)
  end)
end

-- window resizing
map('<C-A-t>', 'n', '<CMD>resize +2<CR>', 'resize: taller')
map('<C-A-s>', 'n', '<CMD>resize -2<CR>', 'resize: shorter')
map('<C-A-w>', 'n', '<CMD>vertical resize +2<CR>', 'resize: wider')
map('<C-A-n>', 'n', '<CMD>vertical resize -2<CR>', 'resize: narrower')

-- tab navigation
map("<leader>tt", "n", "<CMD>tabnew<CR>", "new tab")
map("<leader>tn", "n", "<CMD>tabnext<CR>", "next tab")
map("<leader>tp", "n", "<CMD>tabprevious<CR>", "previous tab")

-- buffer navigation
map("bp", "n", "<CMD>bp<CR>", "previous buffer")
map("bn", "n", "<CMD>bn<CR>", "next bugger")
map("bcc", "n", "<CMD>enew<CR>", "clear buffer")

-- increment & decrement numbers
map("<C-i>", "n", "<C-a>", "increment")
map("<C-d>", "n", "<C-x>", "decrement")

-- terminal mode
map(
  "<C-`>", "n",
  function() vim.cmd("split | terminal") end,
  "open horizontal terminal split"
)
map("<C-n>", "t", "<C-\\><C-n>", "exit terminal mode")

-- harpoon
map("<leader>a", "n", function() harpoon:list():add() end, "add harpoon")
map("<leader>h", "n", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, "list harpoons")
map("<leader>1", "n", function() harpoon:list():select(1) end)
map("<leader>2", "n", function() harpoon:list():select(2) end)
map("<leader>3", "n", function() harpoon:list():select(3) end)
map("<leader>4", "n", function() harpoon:list():select(4) end)
map("<C-P>", "n", function() harpoon:list():prev() end)
map("<C-N>", "n", function() harpoon:list():next() end)
harpoon:extend({
  UI_CREATE = function(cx)
    map("<C-v>", "n", function()
      harpoon.ui:select_menu_item({ vsplit = true })
    end, "", { buffer = cx.bufnr })
    map("<C-s>", "n", function()
      harpoon.ui:select_menu_item({ split = true })
    end, "", { buffer = cx.bufnr })
    map("<C-t>", "n", function()
      harpoon.ui:select_menu_item({ tabedit = true })
    end, "", { buffer = cx.bufnr })
  end,
})

-- debugger
map("dt", "n", dap.toggle_breakpoint, "toggle breakpoint")
map("dr", "n", dap.run_to_cursor, "run to cursor")
map("dv", "n", function() require("dapui").eval(nil, { enter = true }) end, "check value")
map("dc", "n", dap.continue, "continue")
map("di", "n", dap.step_into, "step into")
map("do", "n", dap.step_over, "step over")
map("du", "n", dap.step_out, "step out")
map("db", "n", dap.step_back, "step back")
map("dr", "n", dap.restart, "restart debugger")
map("de", "n", dap.close, "close debugger")

-- snippets
map("<C-k>", { "i", "s" }, function()
  if luasnip.expand_or_jumpable() then
    luasnip.expand_or_jump()
  end
end, "LuaSnip forward jump")

map("<C-j>", { "i", "s" }, function()
  if luasnip.jumpable(-1) then
    luasnip.jump(-1)
  end
end, "LuaSnip backward jump")

map("<C-l>", { "i", "s" }, function()
  if luasnip.choice_active() then
    luasnip.change_choice(1)
  end
end, "LuaSnip next choice")

-- llm completions
map('<leader>C', { 'n', 'v' }, llm.chatgpt_completion("help"), 'help - GPT 4.1')
map('<leader>c', { 'n', 'v' }, llm.chatgpt_completion("edit"), 'edit - GPT 4.1')
map('<leader>A', { 'n', 'v' }, llm.sonnet_completion("help"), 'help - 3.6 Sonnet')
map('<leader>a', { 'n', 'v' }, llm.sonnet_completion("edit"), 'edit - 3.6 Sonnet')
map('<leader>G', { 'n', 'v' }, llm.gemini_flash_completion("help"), 'help - Gemini 2.0 Flash')
map('<leader>g', { 'n', 'v' }, llm.gemini_flash_completion("edit"), 'edit - Gemini 2.0 Flash')
map('<leader>lc', 'n', ':doautocmd User Droid_Escape<CR>', "cancel droid llm stream")

-- code execution
---@type table<string, Executor>
local executors = {
  lua = {
    line = function(line)
      local ok, result = pcall(load(line))
      if ok and result ~= nil then
        print(vim.inspect(result))
      elseif not ok then
        print("Error: " .. tostring(result))
      end
    end,
    lines = function(lines)
      local code = table.concat(lines, "\n")
      local ok, result = pcall(load(code))
      if ok and result ~= nil then
        print(vim.inspect(result))
      elseif not ok then
        print("Error: " .. tostring(result))
      end
    end
  },
  python = {
    line = function(line)
      vim.cmd("RunInPyrepl")
    end,
    lines = function(lines)
      vim.cmd("RunInPyrepl")
    end
  }
}
for lang, exec in pairs(executors) do
  setup_exec_kmaps(lang, exec)
end

-- lsp keymaps: only available when lsp ataches
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
  callback = function(event)
    local opts = { buffer = event.buf }

    map("gd", "n", ts.lsp_definitions, "lsp: goto definition", opts)
    map("gr", "n", ts.lsp_references, "lsp: goto references", opts)
    map("gi", "n", ts.lsp_implementations, "lsp: goto implementation", opts)
    map("gt", "n", ts.lsp_type_definitions, "lsp: goto typedef", opts)

    map("<leader>ds", "n", ts.lsp_document_symbols, "lsp: search document symbols", opts)
    map("<leader>ws", "n", ts.lsp_dynamic_workspace_symbols, "lsp: search workspace symbols", opts)

    map("K", "n", vim.lsp.buf.hover, "lsp: hover documentation", opts)
    map("[d", "n", vim.diagnostic.goto_prev, "lsp: prev diagnostic", opts)
    map("]d", "n", vim.diagnostic.goto_next, "lsp: next diagnostic", opts)
    map("gD", "n", vim.lsp.buf.declaration, "lsp: goto declaration", opts)

    map("<leader>fb", "n", vim.lsp.buf.format, "format buffer", opts)
    map("<leader>rn", "n", vim.lsp.buf.rename, "rename symbol", opts)
    map("<leader>ca", "n", vim.lsp.buf.code_action, "code action", opts)
    map("<leader>dq", "n", vim.diagnostic.setloclist, "show diagnostic quickfix", opts)

    -- the following two autocommands are used to highlight references of the
    -- word under your cursor when your cursor rests there for a little while.
    --    see `:help cursorhold` for information about when this is executed
    -- when you move your cursor, the highlights will be cleared (the second autocommand).
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client.server_capabilities.documentHighlightProvider then
      local highlight_augroup = vim.api.nvim_create_augroup(
        "lsp-highlight", { clear = false }
      )
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.clear_references,
      })
      vim.api.nvim_create_autocmd("LspDetach", {
        group = vim.api.nvim_create_augroup("lsp-detach", { clear = true }),
        callback = function(event2)
          vim.lsp.buf.clear_references()
          vim.api.nvim_clear_autocmds { group = "lsp-highlight", buffer = event2.buf }
        end,
      })
    end
  end,
})
