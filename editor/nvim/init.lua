-- init.lua

-- set vim options
require "options"

-- load lazy
require "setup-lazy"

-- define keymaps
require "keymaps"

-- configure plugins
require "config.debug"
require "config.editor"
require "config.ghola"
require "config.harpoon"
require "config.lualine"
require("config.snippets").setup()
