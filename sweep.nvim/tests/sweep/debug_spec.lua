-- Tests for sweep.debug module

describe('sweep.debug', function()
  local debug_module

  before_each(function()
    -- Reset module state
    package.loaded['sweep.debug'] = nil
    package.loaded['sweep.config'] = nil
    package.loaded['sweep.completion'] = nil
    package.loaded['sweep.cache'] = nil
    package.loaded['sweep.ring'] = nil
    package.loaded['sweep'] = nil

    -- Setup config first
    local config = require('sweep.config')
    config.setup({
      debounce_ms = 100,
      server = {
        endpoint = 'http://localhost:8080',
        timeout = 5000,
        n_predict = 128,
      },
      context = {
        prefix_lines = 100,
        suffix_lines = 50,
        use_lsp = true,
        use_treesitter = true,
      },
    })

    debug_module = require('sweep.debug')
  end)

  after_each(function()
    -- Clean up any open panes
    if debug_module and debug_module.close_pane then
      pcall(debug_module.close_pane)
    end

    package.loaded['sweep.debug'] = nil
    package.loaded['sweep.config'] = nil
    package.loaded['sweep.completion'] = nil
    package.loaded['sweep.cache'] = nil
    package.loaded['sweep.ring'] = nil
    package.loaded['sweep'] = nil
  end)

  describe('get_info', function()
    it('should return a table with required keys', function()
      local info = debug_module.get_info()

      assert.is_table(info)
      assert.is_not_nil(info.enabled)
      assert.is_not_nil(info.completion)
      assert.is_not_nil(info.cache)
      assert.is_not_nil(info.ring)
      assert.is_not_nil(info.config)
    end)

    it('should include completion state', function()
      local info = debug_module.get_info()

      assert.is_table(info.completion)
      assert.is_boolean(info.completion.pending)
    end)

    it('should include cache stats', function()
      local info = debug_module.get_info()

      assert.is_table(info.cache)
      assert.is_number(info.cache.entries)
      assert.is_number(info.cache.hits)
      assert.is_number(info.cache.misses)
    end)

    it('should include ring buffer stats', function()
      local info = debug_module.get_info()

      assert.is_table(info.ring)
      assert.is_number(info.ring.chunks)
      assert.is_table(info.ring.filetypes)
    end)

    it('should include config', function()
      local info = debug_module.get_info()

      assert.is_table(info.config)
      assert.are.equal(100, info.config.debounce_ms)
    end)

    it('should reflect ring buffer changes', function()
      local ring = require('sweep.ring')
      ring.setup({ max_chunks = 16, chunk_size = 64 })

      -- Add some chunks
      ring.add({
        content = 'test content 1',
        filename = 'test1.lua',
        filetype = 'lua',
        source = 'test',
      })
      ring.add({
        content = 'test content 2',
        filename = 'test2.py',
        filetype = 'python',
        source = 'test',
      })

      local info = debug_module.get_info()

      assert.are.equal(2, info.ring.chunks)
      assert.are.equal(1, info.ring.filetypes.lua)
      assert.are.equal(1, info.ring.filetypes.python)
    end)

    it('should reflect cache changes', function()
      local cache = require('sweep.cache')
      cache.setup({ max_entries = 100, ttl_ms = 60000 })

      -- Add some cache entries
      cache.set('key1', { lines = { 'test1' } })
      cache.set('key2', { lines = { 'test2' } })

      -- Access one to get a hit
      cache.get('key1')
      -- Try to get a non-existent key for a miss
      cache.get('nonexistent')

      local info = debug_module.get_info()

      assert.are.equal(2, info.cache.entries)
      assert.are.equal(1, info.cache.hits)
      assert.are.equal(1, info.cache.misses)
    end)
  end)

  describe('show_pane', function()
    it('should create a floating window', function()
      debug_module.show_pane()

      assert.is_true(debug_module.is_pane_open())
    end)

    it('should be closeable', function()
      debug_module.show_pane()
      assert.is_true(debug_module.is_pane_open())

      debug_module.close_pane()
      assert.is_false(debug_module.is_pane_open())
    end)

    it('should replace existing pane when called multiple times', function()
      debug_module.show_pane()
      local first_open = debug_module.is_pane_open()

      debug_module.show_pane()
      local second_open = debug_module.is_pane_open()

      assert.is_true(first_open)
      assert.is_true(second_open)

      debug_module.close_pane()
    end)
  end)

  describe('close_pane', function()
    it('should be safe to call when no pane is open', function()
      assert.has_no.errors(function()
        debug_module.close_pane()
      end)
    end)

    it('should close the pane buffer and window', function()
      debug_module.show_pane()
      debug_module.close_pane()

      assert.is_false(debug_module.is_pane_open())
    end)
  end)

  describe('is_pane_open', function()
    it('should return false when no pane is open', function()
      assert.is_false(debug_module.is_pane_open())
    end)

    it('should return true when pane is open', function()
      debug_module.show_pane()
      assert.is_true(debug_module.is_pane_open())
      debug_module.close_pane()
    end)
  end)

  describe('refresh_pane', function()
    it('should do nothing if pane is not open', function()
      assert.has_no.errors(function()
        debug_module.refresh_pane()
      end)
    end)

    it('should refresh pane content if open', function()
      debug_module.show_pane()

      -- Add some data to change the state
      local cache = require('sweep.cache')
      cache.setup({ max_entries = 100, ttl_ms = 60000 })
      cache.set('test', { lines = { 'test' } })

      -- Refresh should work without error
      assert.has_no.errors(function()
        debug_module.refresh_pane()
      end)

      assert.is_true(debug_module.is_pane_open())
      debug_module.close_pane()
    end)
  end)

  describe('log', function()
    it('should not crash when called', function()
      assert.has_no.errors(function()
        debug_module.log('test message')
      end)
    end)

    it('should accept a log level', function()
      assert.has_no.errors(function()
        debug_module.log('test message', vim.log.levels.WARN)
      end)
    end)
  end)
end)
