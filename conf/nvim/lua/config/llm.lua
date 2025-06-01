-- llm.lua
-- keymaps & configuration for llm assistance, auto completion & claude code integration

local droid = require "droid"
local utils = require "utils"

-- droid.nvim:  llm assistance and inline edits
local opts = {
  base_url = 'https://api.openai.com/v1/chat/completions',
  api_key_name = 'OPENAI_API_KEY',
  edit_prompt = [[
    You should replace the code that you are sent, only following the comments. Do not talk at all. Only output valid code. Do not provide any backticks that surround the code. Never ever output backticks like this ```. Any comment that is asking you for something should be removed after you satisfy them. Other comments should left alone. Do not output backticks
  ]],
  help_prompt = [[
    you are a helpful assistant. you're working with me in neovim. i'll send you contents of the buffer(s) im working in along with notes, questions or comments. you are very curt, yet helpful and a bit sarcastic.
  ]],
  default_model = 'gpt-4.1-2025-04-14',
}

utils.map("<leader>ll", { "n", "v" }, droid.help_completion(opts), "llm: help")
utils.map("<leader>le", { "n", "v" }, droid.edit_completion(opts), "llm: edit")
utils.map("<leader>lm", { "n", "v" }, droid.select_model(opts), "llm: select model")
utils.map("<leader>lc", "n", droid.cancel_completion, "llm: cancel stream")
