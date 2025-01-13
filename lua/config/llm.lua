local cc = require("codecompanion")

-- create code companion adapters
local function create_adapter(provider, model)
  if provider == "anthropic" then
    return require("codecompanion.adapters").extend("anthropic", {
      env = { api_key = "ANTHROPIC_API_KEY" },
      schema = {
        model = {
          default = model or "claude-3-5-sonnet-20241022"
        },
      },
    })
  elseif provider == "openai" then
    return require("codecompanion.adapters").extend("openai", {
      env = { api_key = "OPENAI_API_KEY" },
      schema = {
        model = {
          default = model or "gpt-4-turbo-preview"
        },
      },
    })
  elseif provider == "openrouter" then
    return require("codecompanion.adapters").extend("openai_compatible", {
      env = {
        api_key = "OPENROUTER_API_KEY",
        chat_url = "/v1/chat/completions",
        url = "https://openrouter.ai/api",
      },
      schema = {
        model = {
          default = model or "deepseek/deepseek-chat"
        },
      },
    })
  else
    error("Unsupported provider: " .. tostring(provider))
  end
end

-- read prompt content from a file
local function read_file(filepath)
  local file = io.open(filepath, "r")
  if not file then
    error("Could not open prompt file: " .. filepath)
  end
  local content = file:read("*all")
  file:close()
  return content
end

-- load all prompts from the prompts directory
local function load_prompts()
  local prompts_dir = vim.fn.stdpath("config") .. "/lua/prompts"
  local prompt_library = {}

  prompt_library["claude assistant"] = {
    strategy = "chat",
    description = "claude assistant with official system prompt",
    prompts = {
      {
        role = "system",
        content = read_file(prompts_dir .. "/claude-assistant.txt"),
      },
      {
        role = "user",
        content = "",
      }
    },
  }

  prompt_library["think step by step"] = {
    strategy = "chat",
    description = "think step by step <thinking>",
    prompts = {
      {
        role = "system",
        content = "Before responding to prompts from the user, think out loud and walk step-by-step through how you would implement the feature they are asking for. write out your thoughts in <thinking> tags.",
      },
      {
        role = "user",
        content = "",
      }
    },
  }

  prompt_library["senior dev"] = {
    strategy = "chat",
    description = "spawn a senior dev",
    opts = {
      mapping = "<leader>ce",
      modes = { "v" },
      short_name = "senior",
      auto_submit = true,
      stop_context_insertion = true,
      user_prompt = true,
    },
    prompts = {
      {
        role = "system",
        content = function(context)
          return "I want you to act as a senior "
            .. context.filetype
            .. " developer. I will ask you specific questions and I want you to return concise explanations and codeblock examples."
        end,
      },
      {
        role = "user",
        content = function(context)
          local text = require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line)

          return "I have the following code:\n\n```" .. context.filetype .. "\n" .. text .. "\n```\n\n"
        end,
        opts = {
          contains_code = true,
        }
      },
    },
  }

  return prompt_library
end

-- additional keybindings
local function map(keys, func, desc, mode)
  local opts = { noremap = true, silent = true, desc = desc }
  vim.keymap.set(mode or "n", keys, func, opts)
end

cc.setup({
  adapters = {
    sonnet = create_adapter("anthropic", "claude-3-5-sonnet-20241022"),
    haiku = create_adapter("anthropic", "claude-3.5-haiku-20241022"),
    deepseek = create_adapter("openrouter", "deepseek/deepseek-chat"),
    qwen_coder_32b = create_adapter("openrouter", "qwen/qwen-2.5-coder-32b-instruct"),
    qwen_qwq_32b = create_adapter("openrouter", "qwen/qwq-32b-preview"),
    o1 = create_adapter("openai", "o1-2024-12-17"),
    o1_mini = create_adapter("openai", "o1-mini-2024-09-12"),
    gpt_4o = create_adapter("openai", "gpt-4o-2024-11-20"),
    gpt_4o_mini = create_adapter("openai", "gpt-4o-mini-2024-07-18"),
  },
  display = {
    action_palette = {
      width = 100,
      height = 10,
      prompt = "Prompt ", -- Prompt used for interactive LLM calls
      provider = "default", -- default|telescope|mini_pick
      opts = {
        show_default_actions = true, -- Show the default actions in the action palette?
        show_default_prompt_library = true, -- Show the default prompt library in the action palette?
      },
    },
    chat = {
      render_headers = false,
    },
    diff = {
      enabled = true,
      provider = "mini_diff",
    },
  },
  prompt_library = load_prompts(),
  strategies = {
    chat = {
      adapter = "sonnet",
    },
    inline = {
      adapter = "sonnet",
      keymaps = {
        accept_change = {
          modes = { n = "ga" },
          description = "Accept suggested change"
        },
        reject_change = {
          modes = { n = "gr" },
          description = "Reject suggested change"
        },
      },
    },
  },
})


require('minuet').setup({
  provider = "claude",
  provider_options = {
    openai = {
      model = 'gpt-4o-mini',
      max_tokens = 1024,
      stream = true,
    },
    claude = {
      model = 'claude-3-5-haiku-20241022',
      max_tokens = 1024,
      stream = true,
    },
    openai_fim_compatible = {
      model = 'qwen/qwen-2.5-coder-32b-instruct',
      end_point = 'https://openrouter.ai/api/v1/chat/completions',
      api_key = 'OPENROUTER_API_KEY',
      name = 'Qwen 2.5 Coder 32B',
      stream = true,
      optional = {
        max_tokens = 1024,
        stop = { '\n\n' },
      },
    }
  },
  virtualtext = {
    auto_trigger_ft = {},
    keymap = {
      accept = '<A-A>',
      accept_line = '<A-a>',
      -- Cycle to prev completion item, or manually invoke completion
      prev = '<A-[>',
      -- Cycle to next completion item, or manually invoke completion
      next = '<A-]>',
      dismiss = '<A-e>',
    },
  },
})

-- Expand 'cc' into 'CodeCompanion' in the command line
vim.cmd([[cab cc CodeCompanion]])

-- keymaps
map("<C-a>", "<CMD>CodeCompanionActions<CR>", "Show code companion actions", {"n", "v"})
map("<leader>a", "<CMD>CodeCompanionChat Toggle<CR>", "Toggle code companion chat", {"n", "v"})
map("<leader>k", "<CMD>CodeCompanion /buffer<CR>", "Toggle code companion chat", {"v"})
map("ga", "<CMD>CodeCompanionChat Add<CR>", "Add selection to chat", "v")

