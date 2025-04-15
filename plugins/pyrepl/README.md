# pyrepl.nvim

A Neovim plugin for sending Python code to a local IPython REPL server, with optional logging and package support.

## Features

- Send visually selected Python code to a persistent IPython REPL.
- Reset the REPL scope from within Neovim.
- Optional logging of code and output to Markdown files.
- Easily extend the REPL environment with extra Python packages.

## Requirements

- [Neovim](https://neovim.io/) 0.7+
- [uv](https://github.com/astral-sh/uv) (Python package manager)
- Python 3.8+
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [mini.notify](https://github.com/echasnovski/mini.notify) (for notifications)

## Installation

### 1. Install `uv`

```sh
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Make sure `uv` is in your `PATH`.

### 2. Install the plugin

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "kabilan108/pyrepl.nvim",
  dependencies = { "nvim-lua/plenary.nvim", "echasnovski/mini.notify" },
  config = function()
    require("pyrepl").setup()
  end,
}
```

### 3. Add `bin/pyrepl` to your `PATH`

Copy or symlink the `bin/pyrepl` script somewhere in your `PATH`:

```sh
ln -s /path/to/pyrepl.nvim/bin/pyrepl ~/.local/bin/pyrepl
chmod +x ~/.local/bin/pyrepl
```

## Usage

1. **Start the server** in your project directory:

   ```sh
   pyrepl
   ```

   - Use `--help` for options (e.g., `--with-pkgs numpy,pandas`).

2. **In Neovim:**
   - Visually select Python code and run `:RunInPyrepl` to send it to the REPL.
   - Run `:ResetPyrepl` to reset the REPL scope.

To quickly send the visual selection to the REPL, you can map `:RunInPyrepl` to a
keybinding, like so:

```lua
require("pyrepl").setup({}) 
vim.keymap.set("v", "<leader>xp", "<CMD>RunInPyrepl<CR>", {
  noremap = true, silent = true, desc = "e[x]ecute [p]ython"
})
```

## Options

- `:RunInPyrepl` — Send selected code to the REPL.
- `:ResetPyrepl` — Reset the REPL scope.

## License

Apache 2.0
