# sweep.nvim

AI autocomplete plugin for Neovim using Sweep's 1.5B next-edit model, powered by llama.cpp.

## Requirements

- Neovim 0.10+
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- llama.cpp server running with the Sweep model

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'path/to/sweep.nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('sweep').setup({
      -- options
    })
  end,
}
```

## Configuration

Default configuration with explanations:

```lua
require('sweep').setup({
  auto_enable = true,      -- Enable on setup
  debounce_ms = 100,       -- Delay before triggering completion
  show_info = true,        -- Show token/latency info

  keymaps = {
    trigger = '<C-Space>',    -- Manually trigger completion
    accept_full = '<Tab>',    -- Accept full completion
    accept_line = '<C-l>',    -- Accept first line only
    accept_word = '<C-Right>',-- Accept first word only
    dismiss = '<C-]>',        -- Dismiss completion
  },

  context = {
    prefix_lines = 100,       -- Lines before cursor for context
    suffix_lines = 50,        -- Lines after cursor for context
    max_ring_chunks = 16,     -- Max chunks in ring buffer
    chunk_size = 64,          -- Lines per chunk
    use_lsp = true,           -- Include LSP context (definitions, etc.)
    use_treesitter = true,    -- Include treesitter scope context
  },

  server = {
    endpoint = 'http://localhost:8080',  -- Or set LLAMA_SERVER_URL env var
    timeout = 5000,           -- Request timeout (ms)
    n_predict = 128,          -- Max tokens to generate
    temperature = 0.1,        -- Sampling temperature
    cache_prompt = true,      -- Enable llama.cpp prompt caching
  },

  ui = {
    show_info = true,              -- Show completion metadata
    hl_group = 'SweepGhostText',   -- Ghost text highlight (links to Comment)
    info_hl_group = 'SweepInfo',   -- Info text highlight (links to DiagnosticInfo)
  },

  filetypes_exclude = {
    'help',
    'TelescopePrompt',
    'lazy',
    'mason',
    'neo-tree',
    'NvimTree',
    'toggleterm',
  },
})
```

## Commands

| Command         | Description                    |
|-----------------|--------------------------------|
| `:SweepEnable`  | Enable autocomplete            |
| `:SweepDisable` | Disable autocomplete           |
| `:SweepToggle`  | Toggle autocomplete on/off     |
| `:SweepStatus`  | Show current status            |
| `:SweepDebug`   | Open debug pane with diagnostics |

## Keymaps

Default keymaps (active in insert mode when completion is visible):

| Key           | Action                          |
|---------------|--------------------------------|
| `<C-Space>`   | Manually trigger completion    |
| `<Tab>`       | Accept full completion         |
| `<C-l>`       | Accept first line              |
| `<C-Right>`   | Accept first word              |
| `<C-]>`       | Dismiss completion             |

To customize, override in the `keymaps` config table. Set a keymap to `false` to disable it.

## llama.cpp Setup

Run the llama.cpp server with the Sweep model:

```bash
# Download the model (Q4_K_M quantization recommended)
# Then start the server:
llama-server -m sweep-next-edit-1.5B.Q4_K_M.gguf --port 8080

# Or specify a different port and set the env var:
export LLAMA_SERVER_URL=http://localhost:8888
llama-server -m sweep-next-edit-1.5B.Q4_K_M.gguf --port 8888
```

## Architecture

Module overview for contributors:

| Module       | Purpose                                      |
|--------------|----------------------------------------------|
| `init`       | Main entry point, enable/disable logic       |
| `config`     | Configuration management and defaults        |
| `completion` | Core completion orchestration                |
| `context`    | Gathers surrounding code context             |
| `ring`       | Ring buffer for recently edited code chunks  |
| `cache`      | Caches completions to reduce server requests |
| `fim`        | Fill-in-the-middle prompt formatting         |
| `parser`     | Parses llama.cpp streaming responses         |
| `http`       | HTTP client for server communication         |
| `ui`         | Ghost text rendering and info display        |
| `keymaps`    | Keymap setup and handlers                    |
| `autocmds`   | Autocommand management                       |
| `edits`      | Applies accepted completions to buffer       |
| `debug`      | Debug pane and diagnostics                   |

## License

MIT
