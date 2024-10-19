-- check if lazy is installed otherwise clone the repo
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({
        "git", 
        "clone", 
        "--filter=blob:none", 
        "--branch=stable", 
        lazyrepo,  -- latest stable release
        lazypath,
    })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out, "WarningMsg" },
            { "\npress any key to exit..." },
        }, true, {})
    end
end

-- add it to the path
vim.opt.rtp:prepend(lazypath)

-- setup lazy.nvim
require("lazy").setup({
    spec = {
        { import = "plugins" },
    },
    -- configure other settings
    install = { 
        missing = true,
        colorscheme = { "habamax" },
    },
    -- check for plugin updates
    checker = { enabled = true },
})

