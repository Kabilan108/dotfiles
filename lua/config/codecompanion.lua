

local cc = require("codecompanion")

cc.setup({
  adapters = {
    anthropic = function ()
      return require("codecompanion.adapters").extend("anthropic", {
        env = {
          api_key = "ANTHROPIC_API_KEY"
        },
        schema = {
          model = {
            default = "claude-3-5-sonnet-20241022"
          },
        },
      })
    end
  },
  display = {
    chat = {
      render_headers = false,
    }
  },
  -- opts = {
  --   ---@param adapter CodeCompanion.Adapter
  --   ---@return string
  --   system_prompt = function (opts)
  --     return "you are"
  --   end
  -- },
  strategies = {
    chat = {
      adapter = "anthropic",
    },
    inline = {
      adapter = "anthropic",
    },
  },
})

-- Expand 'cc' into 'CodeCompanion' in the command line
vim.cmd([[cab cc CodeCompanion]])

