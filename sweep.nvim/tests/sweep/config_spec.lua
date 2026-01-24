-- Tests for sweep.config module

describe('sweep.config', function()
  local config

  before_each(function()
    -- Reset module state before each test
    package.loaded['sweep.config'] = nil
    config = require('sweep.config')
  end)

  describe('defaults', function()
    it('should have default endpoint', function()
      assert.is_not_nil(config.defaults.server.endpoint)
      assert.is_true(config.defaults.server.endpoint:match('^http') ~= nil)
    end)

    it('should have default keymaps', function()
      assert.is_not_nil(config.defaults.keymaps.trigger)
      assert.is_not_nil(config.defaults.keymaps.accept_full)
      assert.is_not_nil(config.defaults.keymaps.accept_line)
      assert.is_not_nil(config.defaults.keymaps.accept_word)
      assert.is_not_nil(config.defaults.keymaps.dismiss)
    end)

    it('should have context settings', function()
      assert.is_true(config.defaults.context.prefix_lines > 0)
      assert.is_true(config.defaults.context.suffix_lines > 0)
      assert.is_true(config.defaults.context.max_ring_chunks > 0)
    end)

    it('should enable LSP and treesitter by default', function()
      assert.is_true(config.defaults.context.use_lsp)
      assert.is_true(config.defaults.context.use_treesitter)
    end)

    it('should enable prompt caching by default', function()
      assert.is_true(config.defaults.server.cache_prompt)
    end)
  end)

  describe('setup', function()
    it('should use defaults when no options provided', function()
      config.setup()
      assert.are.same(config.defaults.keymaps, config.options.keymaps)
    end)

    it('should merge user options with defaults', function()
      config.setup({
        debounce_ms = 200,
        keymaps = {
          trigger = '<C-c>',
        },
      })

      assert.are.equal(200, config.options.debounce_ms)
      assert.are.equal('<C-c>', config.options.keymaps.trigger)
      -- Other keymaps should remain default
      assert.are.equal(config.defaults.keymaps.accept_full, config.options.keymaps.accept_full)
    end)

    it('should deep merge nested options', function()
      config.setup({
        server = {
          timeout = 10000,
        },
      })

      assert.are.equal(10000, config.options.server.timeout)
      -- Other server options should remain default
      assert.are.equal(config.defaults.server.n_predict, config.options.server.n_predict)
    end)
  end)

  describe('get', function()
    it('should return current options', function()
      config.setup({ debounce_ms = 300 })
      local opts = config.get()
      assert.are.equal(300, opts.debounce_ms)
    end)
  end)
end)
