local edit_prompt =
'You should replace the code that you are sent, only following the comments. Do not talk at all. Only output valid code. Do not provide any backticks that surround the code. Never ever output backticks like this ```. Any comment that is asking you for something should be removed after you satisfy them. Other comments should left alone. Do not output backticks'

local help_prompt =
"you are a helpful assistant. you're working with me in neovim. i'll send you contents of the buffer(s) im working in along with notes, questions or comments. you are very curt, yet helpful and a bit sarcastic."

local droid = require 'droid'

local M = {}

M.chatgpt_completion = function(mode)
  return function()
    droid.invoke_llm_and_stream_into_editor({
      url = 'https://api.openai.com/v1/chat/completions',
      model = 'gpt-4.1-2025-04-14',
      api_key_name = 'OPENAI_API_KEY',
      system_prompt = mode == 'edit' and edit_prompt or help_prompt,
      replace = mode == 'edit',
    }, droid.make_openai_spec_curl_args, droid.handle_openai_spec_data)
  end
end

M.sonnet_completion = function(mode)
  return function()
    droid.invoke_llm_and_stream_into_editor({
      url = 'https://openrouter.ai/api/v1/chat/completions',
      model = 'anthropic/claude-sonnet-4',
      api_key_name = 'OPENROUTER_API_KEY',
      system_prompt = mode == 'edit' and edit_prompt or help_prompt,
      replace = mode == 'edit',
    }, droid.make_openai_spec_curl_args, droid.handle_openai_spec_data)
  end
end

M.gemini_flash_completion = function(mode)
  return function()
    droid.invoke_llm_and_stream_into_editor({
      url = 'https://openrouter.ai/api/v1/chat/completions',
      model = 'google/gemini-2.0-flash-001',
      api_key_name = 'OPENROUTER_API_KEY',
      system_prompt = mode == 'edit' and edit_prompt or help_prompt,
      replace = mode == 'edit',
    }, droid.make_openai_spec_curl_args, droid.handle_openai_spec_data)
  end
end

return M
