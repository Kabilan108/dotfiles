-- snippets.lua
-- set up code snippets

local luasnip = require 'luasnip'
local types = require 'luasnip.util.types'

local s = luasnip.snippet
local t = luasnip.text_node
local i = luasnip.insert_node

local snippets = {}

snippets.all = {
  s('shell_script', {
    t { '#!/usr/bin/env bash', '# vim: syn=bash ft=bash', '' },
  }),
  s('uv_script', {
    t {
      '#!/usr/bin/env -S uv --quiet run --script',
      '# /// script',
      '# requires-python = ">=3.11"',
      '# dependencies = ["ipdb"',
    },
    i(1, ''),
    t { ']', '# ///', '# vim: syn=python ft=python', '' },
    i(0),
  }),
}

snippets.go = {
  s('gofunc', {
    t 'go func() {',
    t { '', '\t' },
    i(0),
    t { '', '}()' },
  }),
}

snippets.python = {
  s('script', {
    t {
      '# /// script',
      '# requires-python = ">=3.11"',
      '# dependencies = ["ipdb"',
    },
    i(1, ''),
    t { ']', '# ///', '', '' },
    i(0),
  }),
  s('ifmain', {
    t { 'if __name__ == "__main__":', '    ' },
    i(1, 'pass'),
  }),
  s({ trig = 'set_trace' }, {
    t 'import ipdb; ipdb.set_trace()',
  }),
  s({ trig = 'ruff' }, {
    t {
      '[tool.ruff]',
      'target-version = "py311"',
      'exclude = [',
      '    ".direnv",',
      '    ".git",',
      '    ".ipynb_checkpoints",',
      '    ".pytest_cache",',
      '   ".ruff_cache",',
      '    ".venv",',
      '    "build",',
      '    "dist",',
      '    "node_modules",',
      ']',
      '[tool.ruff.lint]',
      'ignore = ["E402", "F403"]',
    },
  }),
}

snippets.toml = {
  s({ trig = 'ruff' }, {
    t {
      '[tool.ruff]',
      'target-version = "py311"',
      'exclude = [',
      '    ".direnv",',
      '    ".git",',
      '    ".ipynb_checkpoints",',
      '    ".pytest_cache",',
      '   ".ruff_cache",',
      '    ".venv",',
      '    "build",',
      '    "dist",',
      '    "node_modules",',
      ']',
      '[tool.ruff.lint]',
      'ignore = ["E402", "F403"]',
    },
  }),
}

-- Load friendly-snippets
require('luasnip.loaders.from_vscode').lazy_load()
require('luasnip.loaders.from_snipmate').lazy_load()

-- Configure LuaSnip
luasnip.config.set_config {
  history = true, -- keep around last snippet local to jump back
  updateevents = 'TextChanged,TextChangedI', -- update changes as you type
  enable_autosnippets = true,
  ext_opts = {
    [types.choiceNode] = {
      active = {
        virt_text = { { '●', 'GruvboxOrange' } },
      },
    },
  },
}
for ft, snip in pairs(snippets) do
  luasnip.add_snippets(ft, snip)
end
