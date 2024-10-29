-- keymaps.lua

local api = vim.api
local cmd = vim.cmd

local ts = require("telescope.builtin")

local map = function(keys, func, desc, opts, mode)
  vim.keymap.set(mode or "n", keys, func, { desc = desc }, opts or {})
end

-- add replace keymap
map("<A-r>", ":s/", "replace", {}, "v")

-- neo-tree
map("\\", ":Neotree toggle<CR>", "[\\] toggle file explorer")

-- clear search highlights
map("<Esc>", ":nohlsearch<CR>")

-- telescope
map("<leader>b", ts.buffers, "[b]uffers", { sort_mru = true })
map("<leader>sf", ts.find_files, "[s]earch [f]iles")
map("<leader>sg", ts.live_grep, "[s]earch [g]rep")
map("<leader>sh", ts.help_tags, "[s]earch [h]elp tags")
map("<leader>sk", ts.keymaps, "[s]earch [k]eymaps")
map("<leader>sr", ts.resume, "[s]earch [r]esume")
map("<leader>s.", ts.oldfiles, "[s]earch [.] recent files")

-- folding
map("zc", ":foldclose<CR>", "close fold under cursor")
map("zo", ":foldopen<CR>", "open fold under cursor")
map("za", ":foldclose<CR>", "toggle fold under cursor")
map("<leader>z", "za", "toggle fold")
map("<leader>Z", "zA", "toggle fold recursively")

-- mini.sessions
local load_session = function ()
  require('mini.sessions').read()
end
map("<leader>ls", load_session, "[l]oad [s]ession")
map("<leader>ss", ":mksession<CR>", "[s]ave [s]ession")

-- trim whitespace
local trailspace = require("mini.trailspace")
map("<leader>tw", trailspace.trim, "[t]rim [w]hitespace")

-- Disable arrow keys in normal mode
local function show_msg()
  cmd('echo "retard."')
  vim.defer_fn(function()
      cmd('echon ""')
  end, 3000)
end
map('<left>', show_msg)
map('<right>', show_msg)
map('<up>', show_msg)
map('<down>', show_msg)

-- window navigation
map('<C-h>', '<C-w><C-h>', 'Move focus to the left window')
map('<C-l>', '<C-w><C-l>', 'Move focus to the right window')
map('<C-j>', '<C-w><C-j>', 'Move focus to the lower window')
map('<C-k>', '<C-w><C-k>', 'Move focus to the upper window')

-- buffer navigation
map("<A-,>", ":bp<CR>", "next buffer")
map("<A-.>", ":bn<CR>", "next buffer")
map("<A-w>", ":w<CR>:bwipeout<CR>", "save and wipeout buffer")
map("<A-c>", ":bwipeout!<CR>", "force wipeout buffer")

-- highlight when yanking
api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- LSP keymaps
-- these will only be enabled when a LSP attaches to the buffer
api.nvim_create_autocmd("LspAttach", {
  group = api.nvim_create_augroup("lsp-attach", { clear = true }),

  callback = function(event)
    local map_ = function(keys, func, desc)
      vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
    end

    -- Jump to the definition of the word under your cursor.
    --  To jump back, press <C-t>.
    map_("gd", ts.lsp_definitions, "[g]oto [d]efinition")

    -- Find references for the word under your cursor.
    map_("gr", ts.lsp_references, "[g]oto [r]eferences")

    -- Jump to the implementation of the word under your cursor.
    --  Useful when your language has ways of declaring types without an actual implementation.
    map_("gi", ts.lsp_implementations, "[g]oto [i]mplementation")

    -- Jump to the type of the word under your cursor.
    --  Useful when you"re not sure what type a variable is and you want to see
    --  the definition of its *type*, not where it was *defined*.
    map_("gt", ts.lsp_type_definitions, "[g]oto [t]ype definition")

    -- Fuzzy find all the symbols in your current document.
    --  Symbols are things like variables, functions, types, etc.
    map_("<leader>ds", ts.lsp_document_symbols, "[d]ocument [s]ymbols")

    -- Fuzzy find all the symbols in your current workspace.
    --  Similar to document symbols, except searches over your entire project.
    map_("<leader>ws", ts.lsp_dynamic_workspace_symbols, "[w]orkspace [s]ymbols")

    -- Rename the variable under your cursor.
    --  Most Language Servers support renaming across files, etc.
    map_("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")

    -- Execute a code action, usually your cursor needs to be on top of an error
    -- or a suggestion from your LSP for this to activate.
    map_("<leader>ca", vim.lsp.buf.code_action, "[c]ode [a]ction")

    -- interact with diagnostic messages
    map("[d", vim.diagnostic.goto_prev, "prev [d]iagnostic message")
    map("]d", vim.diagnostic.goto_next, "next [d]iagnostic message")
    map("<leader>e", vim.diagnostic.open_float, "show [e]rror message")
    map("<leader>q", vim.diagnostic.setloclist, "show [q]uick fix")

    -- Opens a popup that displays documentation about the word under your cursor
    --  See `:help K` for why this keymap.
    map_("K", vim.lsp.buf.hover, "[K] Hover Documentation")

    -- WARN: This is not Goto Definition, this is Goto Declaration.
    --  For example, in C this would take you to the header.
    map_("gD", vim.lsp.buf.declaration, "[g]oto [D]eclaration")

    -- formatting
    map_("<leader>fb", vim.lsp.buf.format, "[f]ormat [b]uffer")

    -- The following two autocommands are used to highlight references of the
    -- word under your cursor when your cursor rests there for a little while.
    --    See `:help CursorHold` for information about when this is executed
    --
    -- When you move your cursor, the highlights will be cleared (the second autocommand).
    local client = vim.lsp.get_client_by_id(event.data.client_id)

    if client and client.server_capabilities.documentHighlightProvider then
      local highlight_augroup = api.nvim_create_augroup(
        "lsp-highlight", { clear = false }
      )

      api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.document_highlight,
      })

      api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.clear_references,
      })

      api.nvim_create_autocmd("LspDetach", {
        group = api.nvim_create_augroup("lsp-detach", { clear = true }),
        callback = function(event2)
          vim.lsp.buf.clear_references()
          api.nvim_clear_autocmds { group = "lsp-highlight", buffer = event2.buf }
        end,
      })
    end

    -- The following autocommand is used to enable inlay hints in your
    -- code, if the language server you are using supports them
    --
    -- This may be unwanted, since they displace some of your code
    if client and client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
      map("<leader>th", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
      end, "[t]oggle inlay [h]ints")
    end
  end,
})

-- Define groups for which-key
local wk = require("which-key")
wk.add({
  { "<leader>c",  group = "[c]ode" },
  { "<leader>c_", hidden = true },
  { "<leader>d",  group = "[d]ocument" },
  { "<leader>d_", hidden = true },
  { "<leader>h",  group = "git [h]unk" },
  { "<leader>h_", hidden = true },
  { "<leader>r",  group = "[r]ename" },
  { "<leader>r_", hidden = true },
  { "<leader>s",  group = "[s]earch" },
  { "<leader>s_", hidden = true },
  { "<leader>t",  group = "[t]oggle" },
  { "<leader>t_", hidden = true },
  { "<leader>w",  group = "[w]orkspace" },
  { "<leader>w_", hidden = true },
  { "<leader>z",  group = "[z] fold" },
  { "<leader>z_", hidden = true },
  { "<leader>h",  desc = "git [h]unk",  mode = "v" },
})

