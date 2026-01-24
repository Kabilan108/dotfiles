-- Tests for sweep.completion module

describe('sweep.completion', function()
  local completion
  local config
  local mock_http
  local mock_fim
  local mock_parser
  local mock_ui
  local test_bufnr

  -- Track timer handles for cleanup
  local created_timers = {}

  -- Mock timer implementation
  local mock_timer = {
    start = function(self, timeout, repeat_interval, callback)
      self._callback = callback
      self._timeout = timeout
      self._started = true
    end,
    stop = function(self)
      self._started = false
      self._callback = nil
    end,
    close = function(self)
      self._started = false
      self._callback = nil
      self._closed = true
    end,
    is_active = function(self)
      return self._started or false
    end,
  }

  local function create_mock_timer()
    local timer = vim.deepcopy(mock_timer)
    timer._started = false
    timer._callback = nil
    timer._closed = false
    table.insert(created_timers, timer)
    return timer
  end

  -- Original vim.loop.new_timer
  local original_new_timer

  before_each(function()
    -- Reset module state before each test
    package.loaded['sweep.completion'] = nil
    package.loaded['sweep.config'] = nil
    package.loaded['sweep.http'] = nil
    package.loaded['sweep.fim'] = nil
    package.loaded['sweep.parser'] = nil
    package.loaded['sweep.ui'] = nil

    -- Setup config
    config = require('sweep.config')
    config.setup({
      debounce_ms = 100,
      filetypes_exclude = { 'help', 'TelescopePrompt' },
    })

    -- Create mock http module
    mock_http = {
      _last_request = nil,
      _request_count = 0,
      _current_handle = nil,
      request = function(opts)
        mock_http._last_request = opts
        mock_http._request_count = mock_http._request_count + 1
        mock_http._current_handle = { id = 'test-handle-' .. mock_http._request_count }
        return mock_http._current_handle
      end,
      cancel = function(handle)
        mock_http._cancelled_handle = handle
      end,
      cancel_all = function()
        mock_http._all_cancelled = true
      end,
    }

    -- Create mock fim module
    mock_fim = {
      _last_request = nil,
      build_request = function(opts)
        mock_fim._last_request = opts
        return {
          input_prefix = 'prefix_code',
          input_suffix = 'suffix_code',
          metadata = {
            cursor_line = 'current line',
            indent = '  ',
            filename = 'test.lua',
            filetype = 'lua',
          },
        }
      end,
    }

    -- Create mock parser module
    mock_parser = {
      parse = function(response_body, opts)
        return {
          content = 'completed code here',
          lines = { 'completed code here' },
          tokens_predicted = 10,
          stopped = true,
          stop_reason = 'eos',
          timings = { predicted_ms = 50 },
        }
      end,
      first_line = function(result)
        if result and result.lines and #result.lines > 0 then
          return result.lines[1]
        end
        return ''
      end,
      first_word = function(result)
        if result and result.content then
          return result.content:match('^%s*%S+') or ''
        end
        return ''
      end,
      is_empty = function(result)
        return not result or not result.content or result.content:match('^%s*$') ~= nil
      end,
    }

    -- Create mock ui module
    mock_ui = {
      _shown = nil,
      _cleared = false,
      _visible = false,
      _current = nil,
      show = function(opts)
        mock_ui._shown = opts
        mock_ui._visible = true
        mock_ui._current = {
          lines = opts.lines,
          bufnr = opts.bufnr,
          row = opts.row,
          col = opts.col,
        }
      end,
      clear = function()
        mock_ui._cleared = true
        mock_ui._visible = false
        mock_ui._current = nil
      end,
      is_visible = function()
        return mock_ui._visible
      end,
      get_current = function()
        return mock_ui._current
      end,
    }

    -- Inject mocks into package.loaded before requiring completion
    package.loaded['sweep.http'] = mock_http
    package.loaded['sweep.fim'] = mock_fim
    package.loaded['sweep.parser'] = mock_parser
    package.loaded['sweep.ui'] = mock_ui

    -- Mock vim.loop.new_timer
    created_timers = {}
    original_new_timer = vim.loop.new_timer
    vim.loop.new_timer = create_mock_timer

    -- Create a test buffer
    test_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
      'function hello()',
      '  print("world")',
      'end',
    })
    vim.api.nvim_set_current_buf(test_bufnr)
    vim.api.nvim_set_option_value('filetype', 'lua', { buf = test_bufnr })

    -- Position cursor
    vim.api.nvim_win_set_cursor(0, { 2, 8 })

    completion = require('sweep.completion')
  end)

  after_each(function()
    -- Restore original vim.loop.new_timer
    vim.loop.new_timer = original_new_timer

    -- Clean up timers
    for _, timer in ipairs(created_timers) do
      if timer.is_active and timer:is_active() then
        pcall(function() timer:stop() end)
      end
    end
    created_timers = {}

    -- Clean up test buffer
    if vim.api.nvim_buf_is_valid(test_bufnr) then
      vim.api.nvim_buf_delete(test_bufnr, { force = true })
    end

    -- Reset package.loaded
    package.loaded['sweep.completion'] = nil
    package.loaded['sweep.http'] = nil
    package.loaded['sweep.fim'] = nil
    package.loaded['sweep.parser'] = nil
    package.loaded['sweep.ui'] = nil
  end)

  describe('trigger', function()
    it('should start debounce timer', function()
      completion.trigger()

      -- Should have created a timer
      assert.is_true(#created_timers >= 1)
      local timer = created_timers[#created_timers]
      assert.is_true(timer._started)
      assert.are.equal(100, timer._timeout) -- debounce_ms from config
    end)

    it('should cancel existing timer on new trigger', function()
      completion.trigger()
      local first_timer = created_timers[#created_timers]

      completion.trigger()
      local second_timer = created_timers[#created_timers]

      -- First timer should be stopped
      assert.is_false(first_timer._started)
      -- Second timer should be active
      assert.is_true(second_timer._started)
    end)

    it('should not trigger for excluded filetypes', function()
      vim.api.nvim_set_option_value('filetype', 'help', { buf = test_bufnr })

      completion.trigger()

      -- No timer should be started for excluded filetype
      local timer_started = false
      for _, timer in ipairs(created_timers) do
        if timer._started then
          timer_started = true
        end
      end
      assert.is_false(timer_started)
    end)

    it('should not trigger for TelescopePrompt filetype', function()
      vim.api.nvim_set_option_value('filetype', 'TelescopePrompt', { buf = test_bufnr })

      completion.trigger()

      local timer_started = false
      for _, timer in ipairs(created_timers) do
        if timer._started then
          timer_started = true
        end
      end
      assert.is_false(timer_started)
    end)

    it('should make HTTP request after debounce fires', function()
      completion.trigger()

      -- Simulate timer callback firing
      local timer = created_timers[#created_timers]
      assert.is_not_nil(timer._callback)
      timer._callback()

      -- Should have made a request
      assert.are.equal(1, mock_http._request_count)
      assert.is_not_nil(mock_http._last_request)
    end)

    it('should build FIM request with correct buffer context', function()
      completion.trigger()

      local timer = created_timers[#created_timers]
      timer._callback()

      -- FIM should have been called with current buffer info
      assert.is_not_nil(mock_fim._last_request)
      assert.are.equal(test_bufnr, mock_fim._last_request.bufnr)
    end)

    it('should include proper request body for llama.cpp', function()
      completion.trigger()

      local timer = created_timers[#created_timers]
      timer._callback()

      -- Check request body format
      local body = mock_http._last_request.body
      assert.is_not_nil(body)
      assert.is_not_nil(body.input_prefix)
      assert.is_not_nil(body.input_suffix)
      assert.is_not_nil(body.n_predict)
      assert.is_not_nil(body.temperature)
      assert.is_not_nil(body.cache_prompt)
      assert.is_not_nil(body.stop)
    end)
  end)

  describe('multiple rapid triggers', function()
    it('should only result in one request after debounce', function()
      -- Trigger multiple times rapidly
      completion.trigger()
      completion.trigger()
      completion.trigger()
      completion.trigger()
      completion.trigger()

      -- Only the last timer should be active
      local active_count = 0
      local last_active_timer = nil
      for _, timer in ipairs(created_timers) do
        if timer._started then
          active_count = active_count + 1
          last_active_timer = timer
        end
      end
      assert.are.equal(1, active_count)

      -- Fire the timer
      last_active_timer._callback()

      -- Should only have made one HTTP request
      assert.are.equal(1, mock_http._request_count)
    end)
  end)

  describe('cancel', function()
    it('should stop pending debounce timer', function()
      completion.trigger()

      local timer = created_timers[#created_timers]
      assert.is_true(timer._started)

      completion.cancel()

      assert.is_false(timer._started)
    end)

    it('should cancel in-flight HTTP request', function()
      completion.trigger()

      local timer = created_timers[#created_timers]
      timer._callback() -- Fire timer to make HTTP request

      completion.cancel()

      -- HTTP cancel should have been called
      assert.is_not_nil(mock_http._cancelled_handle)
    end)

    it('should clear UI on cancel', function()
      -- Show something first
      mock_ui._visible = true

      completion.cancel()

      assert.is_true(mock_ui._cleared)
    end)
  end)

  describe('successful completion', function()
    it('should show completion in UI on successful response', function()
      completion.trigger()

      local timer = created_timers[#created_timers]
      timer._callback()

      -- Simulate successful HTTP response
      local on_success = mock_http._last_request.on_success
      assert.is_not_nil(on_success)

      on_success({ content = 'completed code here', tokens_predicted = 10 })

      -- UI should have been called with completion
      assert.is_not_nil(mock_ui._shown)
      assert.is_not_nil(mock_ui._shown.lines)
    end)

    it('should include timing info in UI display', function()
      completion.trigger()

      local timer = created_timers[#created_timers]
      timer._callback()

      local on_success = mock_http._last_request.on_success
      on_success({ content = 'code', tokens_predicted = 10, timings = { predicted_ms = 100 } })

      assert.is_not_nil(mock_ui._shown.info)
    end)
  end)

  describe('request error handling', function()
    it('should not crash on error response', function()
      completion.trigger()

      local timer = created_timers[#created_timers]
      timer._callback()

      local on_error = mock_http._last_request.on_error
      assert.is_not_nil(on_error)

      -- Should not throw
      assert.has_no.errors(function()
        on_error('Connection refused')
      end)
    end)

    it('should clear UI on error', function()
      -- First show something
      mock_ui._visible = true
      mock_ui._current = { lines = { 'old completion' } }

      completion.trigger()

      local timer = created_timers[#created_timers]
      timer._callback()

      local on_error = mock_http._last_request.on_error
      on_error('Server error')

      assert.is_true(mock_ui._cleared)
    end)
  end)

  describe('manual_trigger', function()
    it('should trigger completion immediately without debounce', function()
      completion.manual_trigger()

      -- Should make request immediately
      assert.are.equal(1, mock_http._request_count)
    end)

    it('should still check for excluded filetypes', function()
      vim.api.nvim_set_option_value('filetype', 'help', { buf = test_bufnr })

      completion.manual_trigger()

      assert.are.equal(0, mock_http._request_count)
    end)
  end)

  describe('accept_full', function()
    it('should insert full completion text', function()
      -- Setup UI with a completion
      mock_ui._visible = true
      mock_ui._current = {
        lines = { 'line one', 'line two', 'line three' },
        bufnr = test_bufnr,
        row = 1, -- 0-indexed
        col = 8,
      }

      completion.accept_full()

      -- UI should be cleared after accept
      assert.is_true(mock_ui._cleared)
    end)

    it('should do nothing if no completion visible', function()
      mock_ui._visible = false
      mock_ui._current = nil

      -- Should not throw
      assert.has_no.errors(function()
        completion.accept_full()
      end)
    end)
  end)

  describe('accept_line', function()
    it('should insert only first line of completion', function()
      mock_ui._visible = true
      mock_ui._current = {
        lines = { 'first line', 'second line' },
        bufnr = test_bufnr,
        row = 1,
        col = 8,
      }

      completion.accept_line()

      assert.is_true(mock_ui._cleared)
    end)

    it('should handle single-line completion', function()
      mock_ui._visible = true
      mock_ui._current = {
        lines = { 'only line' },
        bufnr = test_bufnr,
        row = 1,
        col = 8,
      }

      assert.has_no.errors(function()
        completion.accept_line()
      end)
    end)
  end)

  describe('accept_word', function()
    it('should insert only first word of completion', function()
      mock_ui._visible = true
      mock_ui._current = {
        lines = { 'first second third' },
        bufnr = test_bufnr,
        row = 1,
        col = 8,
      }

      completion.accept_word()

      assert.is_true(mock_ui._cleared)
    end)

    it('should preserve leading whitespace with first word', function()
      mock_ui._visible = true
      mock_ui._current = {
        lines = { '  indented word' },
        bufnr = test_bufnr,
        row = 1,
        col = 8,
      }

      assert.has_no.errors(function()
        completion.accept_word()
      end)
    end)
  end)

  describe('dismiss', function()
    it('should clear UI without inserting text', function()
      mock_ui._visible = true
      mock_ui._current = {
        lines = { 'some completion' },
        bufnr = test_bufnr,
        row = 1,
        col = 8,
      }

      -- Get original buffer content
      local original_lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)

      completion.dismiss()

      -- UI should be cleared
      assert.is_true(mock_ui._cleared)

      -- Buffer content should be unchanged
      local new_lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      assert.are.same(original_lines, new_lines)
    end)

    it('should cancel any pending request', function()
      completion.trigger()

      local timer = created_timers[#created_timers]
      timer._callback() -- Start HTTP request

      completion.dismiss()

      -- Should have cancelled the request
      assert.is_not_nil(mock_http._cancelled_handle)
    end)

    it('should be safe to call when no completion visible', function()
      mock_ui._visible = false

      assert.has_no.errors(function()
        completion.dismiss()
      end)
    end)
  end)

  describe('state management', function()
    it('should cancel previous request when new one starts', function()
      completion.trigger()
      local timer1 = created_timers[#created_timers]
      timer1._callback() -- First request

      local first_handle = mock_http._current_handle

      completion.trigger()
      local timer2 = created_timers[#created_timers]
      timer2._callback() -- Second request

      -- First request should have been cancelled
      assert.are.same(first_handle, mock_http._cancelled_handle)
    end)

    it('should track current request handle for cancellation', function()
      completion.trigger()
      local timer = created_timers[#created_timers]
      timer._callback()

      -- Get the handle
      local handle = mock_http._current_handle

      completion.cancel()

      assert.are.same(handle, mock_http._cancelled_handle)
    end)
  end)

  describe('text insertion', function()
    it('should insert text at correct cursor position for accept_full', function()
      -- Position cursor at specific location
      vim.api.nvim_win_set_cursor(0, { 2, 8 }) -- Line 2, col 8 (after 'print("')

      mock_ui._visible = true
      mock_ui._current = {
        lines = { 'inserted' },
        bufnr = test_bufnr,
        row = 1, -- 0-indexed row
        col = 8,
      }

      completion.accept_full()

      -- Check that text was inserted
      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      -- The second line should have the inserted text
      assert.is_true(lines[2]:find('inserted') ~= nil)
    end)

    it('should handle multi-line insertion for accept_full', function()
      vim.api.nvim_win_set_cursor(0, { 2, 8 })

      mock_ui._visible = true
      mock_ui._current = {
        lines = { 'line1', 'line2', 'line3' },
        bufnr = test_bufnr,
        row = 1,
        col = 8,
      }

      completion.accept_full()

      local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      -- Should have more lines now
      assert.is_true(#lines >= 4)
    end)
  end)
end)
