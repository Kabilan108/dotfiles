local M = {}

function M.setup()
  local luasnip = require("luasnip")
  local types = require("luasnip.util.types")

  -- Load friendly-snippets
  require("luasnip.loaders.from_vscode").lazy_load()
  require("luasnip.loaders.from_snipmate").lazy_load()

  -- Configure LuaSnip
  luasnip.config.set_config({
    history = true, -- keep around last snippet local to jump back
    updateevents = "TextChanged,TextChangedI", -- update changes as you type
    enable_autosnippets = true,
    ext_opts = {
      [types.choiceNode] = {
        active = {
          virt_text = { { "●", "GruvboxOrange" } },
        },
      },
    },
  })

  -- Load custom snippets
  luasnip.add_snippets("python", require("snippets.python"))

  -- Key mappings
  vim.keymap.set({ "i", "s" }, "<C-k>", function()
    if luasnip.expand_or_jumpable() then
      luasnip.expand_or_jump()
    end
  end, { silent = true, desc = "LuaSnip forward jump" })

  vim.keymap.set({ "i", "s" }, "<C-j>", function()
    if luasnip.jumpable(-1) then
      luasnip.jump(-1)
    end
  end, { silent = true, desc = "LuaSnip backward jump" })

  vim.keymap.set({ "i", "s" }, "<C-l>", function()
    if luasnip.choice_active() then
      luasnip.change_choice(1)
    end
  end, { silent = true, desc = "LuaSnip next choice" })
end

return M
