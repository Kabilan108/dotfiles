local edit_prompt =
'You should replace the code that you are sent, only following the comments. Do not talk at all. Only output valid code. Do not provide any backticks that surround the code. Never ever output backticks like this ```. Any comment that is asking you for something should be removed after you satisfy them. Other comments should left alone. Do not output backticks'

local help_prompt =
'You are a helpful assistant. What I have sent are my notes so far. You are very curt, yet helpful.'

local ghola = require 'ghola'

local function chatgpt_completion(mode)
  return function()
    ghola.invoke_llm_and_stream_into_editor({
      url = 'https://api.openai.com/v1/chat/completions',
      model = 'chatgpt-4o-latest',
      api_key_name = 'OPENAI_API_KEY',
      system_prompt = mode == 'edit' and edit_prompt or help_prompt,
      replace = mode == 'edit',
    }, ghola.make_openai_spec_curl_args, ghola.handle_openai_spec_data)
  end
end

local function sonnet_completion(mode)
  return function()
    ghola.invoke_llm_and_stream_into_editor({
      url = 'https://api.anthropic.com/v1/messages',
      model = 'claude-3-5-sonnet-20241022',
      api_key_name = 'ANTHROPIC_API_KEY',
      system_prompt = mode == 'edit' and edit_prompt or help_prompt,
      replace = mode == 'edit',
    }, ghola.make_anthropic_spec_curl_args, ghola.handle_anthropic_spec_data)
  end
end

local function gemini_flash_completion(mode)
  return function()
    ghola.invoke_llm_and_stream_into_editor({
      url = 'https://openrouter.ai/api/v1/chat/completions',
      model = 'google/gemini-2.0-flash-001',
      api_key_name = 'OPENROUTER_API_KEY',
      system_prompt = mode == 'edit' and edit_prompt or help_prompt,
      replace = mode == 'edit',
    }, ghola.make_openai_spec_curl_args, ghola.handle_openai_spec_data)
  end
end

local function deepseek_v3_completion(mode)
  return function()
    ghola.invoke_llm_and_stream_into_editor({
      url = 'https://openrouter.ai/api/v1/chat/completions',
      model = 'deepseek/deepseek-chat-v3-0324',
      api_key_name = 'OPENROUTER_API_KEY',
      system_prompt = mode == 'edit' and edit_prompt or help_prompt,
      replace = mode == 'edit',
    }, ghola.make_openai_spec_curl_args, ghola.handle_openai_spec_data)
  end
end

local function quasar_alpha_completion(mode)
  return function()
    ghola.invoke_llm_and_stream_into_editor({
      url = 'https://openrouter.ai/api/v1/chat/completions',
      model = 'openrouter/quasar-alpha',
      api_key_name = 'OPENROUTER_API_KEY',
      system_prompt = mode == 'edit' and edit_prompt or help_prompt,
      replace = mode == 'edit',
    }, ghola.make_openai_spec_curl_args, ghola.handle_openai_spec_data)
  end
end

vim.keymap.set({ 'n', 'v' }, '<leader>C', chatgpt_completion("help"), { desc = 'help - GPT 4o' })
vim.keymap.set({ 'n', 'v' }, '<leader>c', chatgpt_completion("edit"), { desc = 'edit - GPT 4o' })
vim.keymap.set({ 'n', 'v' }, '<leader>A', sonnet_completion("help"), { desc = 'help - 3.6 Sonnet' })
vim.keymap.set({ 'n', 'v' }, '<leader>a', sonnet_completion("edit"), { desc = 'edit - 3.6 Sonnet' })
vim.keymap.set({ 'n', 'v' }, '<leader>G', gemini_flash_completion("help"), { desc = 'help - Gemini 2.0 Flash' })
vim.keymap.set({ 'n', 'v' }, '<leader>g', gemini_flash_completion("edit"), { desc = 'edit - Gemini 2.0 Flash' })
vim.keymap.set({ 'n', 'v' }, '<leader>D', deepseek_v3_completion("help"), { desc = 'help - DeepSeek V3 0324' })
vim.keymap.set({ 'n', 'v' }, '<leader>d', deepseek_v3_completion("edit"), { desc = 'edit - DeepSeek V3 0324' })
vim.keymap.set({ 'n', 'v' }, '<leader>QA', quasar_alpha_completion("help"), { desc = 'help - Quasar Alpha' })
vim.keymap.set({ 'n', 'v' }, '<leader>qa', quasar_alpha_completion("edit"), { desc = 'edit - Quasar Alpha' })
