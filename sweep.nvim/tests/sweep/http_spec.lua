-- Tests for sweep.http module

describe('sweep.http', function()
  local http
  local mock_curl
  local mock_job

  -- Mock job object that simulates plenary.curl behavior
  local function create_mock_job(opts)
    opts = opts or {}
    local job = {
      _cancelled = false,
      pid = opts.pid or 12345,
      shutdown = function(self)
        self._cancelled = true
        if opts.on_shutdown then
          opts.on_shutdown()
        end
      end,
    }
    return job
  end

  before_each(function()
    -- Reset module state before each test
    package.loaded['sweep.http'] = nil

    -- Create mock curl module
    mock_job = nil
    mock_curl = {
      post = function(opts)
        -- Store the options for inspection
        mock_curl._last_opts = opts
        -- Create and return a mock job
        mock_job = create_mock_job({ pid = 12345 })
        return mock_job
      end,
      _last_opts = nil,
    }

    -- Inject mock into package.loaded before requiring http
    package.loaded['plenary.curl'] = mock_curl

    http = require('sweep.http')
  end)

  after_each(function()
    -- Clean up
    package.loaded['plenary.curl'] = nil
    package.loaded['sweep.http'] = nil
  end)

  describe('request', function()
    it('should send POST request to the correct endpoint', function()
      http.request({
        endpoint = 'http://localhost:8080/completion',
        body = { prompt = 'test prompt' },
        on_success = function() end,
        on_error = function() end,
      })

      assert.is_not_nil(mock_curl._last_opts)
      assert.are.equal('http://localhost:8080/completion', mock_curl._last_opts.url)
    end)

    it('should send JSON body with correct content type', function()
      local test_body = { prompt = 'function hello', n_predict = 128 }

      http.request({
        endpoint = 'http://localhost:8080/completion',
        body = test_body,
        on_success = function() end,
        on_error = function() end,
      })

      assert.is_not_nil(mock_curl._last_opts)
      assert.is_not_nil(mock_curl._last_opts.body)
      -- Body should be JSON encoded
      local decoded = vim.json.decode(mock_curl._last_opts.body)
      assert.are.equal('function hello', decoded.prompt)
      assert.are.equal(128, decoded.n_predict)
      -- Should have JSON content type header
      assert.is_not_nil(mock_curl._last_opts.headers)
      assert.are.equal('application/json', mock_curl._last_opts.headers['Content-Type'])
    end)

    it('should use provided timeout', function()
      http.request({
        endpoint = 'http://localhost:8080/completion',
        body = { prompt = 'test' },
        timeout = 10000,
        on_success = function() end,
        on_error = function() end,
      })

      assert.are.equal(10000, mock_curl._last_opts.timeout)
    end)

    it('should use default timeout when not provided', function()
      http.request({
        endpoint = 'http://localhost:8080/completion',
        body = { prompt = 'test' },
        on_success = function() end,
        on_error = function() end,
      })

      assert.are.equal(5000, mock_curl._last_opts.timeout)
    end)

    it('should return a cancellable handle', function()
      local handle = http.request({
        endpoint = 'http://localhost:8080/completion',
        body = { prompt = 'test' },
        on_success = function() end,
        on_error = function() end,
      })

      assert.is_not_nil(handle)
      assert.is_not_nil(handle.id)
    end)

    it('should call on_success with parsed JSON on successful response', function()
      local success_called = false
      local received_response = nil

      -- Override mock to trigger callback
      mock_curl.post = function(opts)
        mock_curl._last_opts = opts
        mock_job = create_mock_job()
        -- Simulate async callback with successful response
        vim.schedule(function()
          if opts.callback then
            opts.callback({
              status = 200,
              body = vim.json.encode({ content = 'completed code', tokens_predicted = 50 }),
            })
          end
        end)
        return mock_job
      end

      http.request({
        endpoint = 'http://localhost:8080/completion',
        body = { prompt = 'test' },
        on_success = function(response)
          success_called = true
          received_response = response
        end,
        on_error = function() end,
      })

      -- Wait for scheduled callback
      vim.wait(100, function() return success_called end)

      assert.is_true(success_called)
      assert.is_not_nil(received_response)
      assert.are.equal('completed code', received_response.content)
      assert.are.equal(50, received_response.tokens_predicted)
    end)

    it('should call on_error on HTTP error status', function()
      local error_called = false
      local received_error = nil

      mock_curl.post = function(opts)
        mock_curl._last_opts = opts
        mock_job = create_mock_job()
        vim.schedule(function()
          if opts.callback then
            opts.callback({
              status = 500,
              body = 'Internal Server Error',
            })
          end
        end)
        return mock_job
      end

      http.request({
        endpoint = 'http://localhost:8080/completion',
        body = { prompt = 'test' },
        on_success = function() end,
        on_error = function(err)
          error_called = true
          received_error = err
        end,
      })

      vim.wait(100, function() return error_called end)

      assert.is_true(error_called)
      assert.is_not_nil(received_error)
      assert.is_true(received_error:match('500') ~= nil)
    end)

    it('should call on_error on connection failure', function()
      local error_called = false
      local received_error = nil

      mock_curl.post = function(opts)
        mock_curl._last_opts = opts
        mock_job = create_mock_job()
        vim.schedule(function()
          if opts.callback then
            opts.callback({
              status = 0,
              body = nil,
              exit = 7, -- curl connection refused
            })
          end
        end)
        return mock_job
      end

      http.request({
        endpoint = 'http://localhost:8080/completion',
        body = { prompt = 'test' },
        on_success = function() end,
        on_error = function(err)
          error_called = true
          received_error = err
        end,
      })

      vim.wait(100, function() return error_called end)

      assert.is_true(error_called)
      assert.is_not_nil(received_error)
    end)

    it('should call on_error on JSON parse failure', function()
      local error_called = false
      local received_error = nil

      mock_curl.post = function(opts)
        mock_curl._last_opts = opts
        mock_job = create_mock_job()
        vim.schedule(function()
          if opts.callback then
            opts.callback({
              status = 200,
              body = 'not valid json {{{',
            })
          end
        end)
        return mock_job
      end

      http.request({
        endpoint = 'http://localhost:8080/completion',
        body = { prompt = 'test' },
        on_success = function() end,
        on_error = function(err)
          error_called = true
          received_error = err
        end,
      })

      vim.wait(100, function() return error_called end)

      assert.is_true(error_called)
      assert.is_not_nil(received_error)
      assert.is_true(received_error:match('[Jj][Ss][Oo][Nn]') ~= nil or received_error:match('parse') ~= nil)
    end)
  end)

  describe('cancel', function()
    it('should cancel an in-flight request', function()
      local handle = http.request({
        endpoint = 'http://localhost:8080/completion',
        body = { prompt = 'test' },
        on_success = function() end,
        on_error = function() end,
      })

      http.cancel(handle)

      assert.is_true(mock_job._cancelled)
    end)

    it('should not call callbacks after cancellation', function()
      local success_called = false
      local error_called = false

      mock_curl.post = function(opts)
        mock_curl._last_opts = opts
        mock_job = create_mock_job()
        -- Store callback reference
        local stored_callback = opts.callback
        mock_job._trigger_callback = function()
          if stored_callback then
            stored_callback({
              status = 200,
              body = vim.json.encode({ content = 'test' }),
            })
          end
        end
        return mock_job
      end

      local handle = http.request({
        endpoint = 'http://localhost:8080/completion',
        body = { prompt = 'test' },
        on_success = function()
          success_called = true
        end,
        on_error = function()
          error_called = true
        end,
      })

      -- Cancel the request
      http.cancel(handle)

      -- Try to trigger the callback after cancellation
      vim.schedule(function()
        if mock_job._trigger_callback then
          mock_job._trigger_callback()
        end
      end)

      vim.wait(100, function() return success_called or error_called end, 10)

      assert.is_false(success_called)
      assert.is_false(error_called)
    end)

    it('should handle cancelling non-existent handle gracefully', function()
      -- Should not throw error
      assert.has_no.errors(function()
        http.cancel({ id = 'non-existent-id' })
      end)
    end)

    it('should handle cancelling nil handle gracefully', function()
      assert.has_no.errors(function()
        http.cancel(nil)
      end)
    end)
  end)

  describe('cancel_all', function()
    it('should cancel all pending requests', function()
      local jobs = {}

      mock_curl.post = function(opts)
        mock_curl._last_opts = opts
        local job = create_mock_job({ pid = #jobs + 1 })
        table.insert(jobs, job)
        return job
      end

      -- Make multiple requests
      http.request({
        endpoint = 'http://localhost:8080/completion',
        body = { prompt = 'test1' },
        on_success = function() end,
        on_error = function() end,
      })

      http.request({
        endpoint = 'http://localhost:8080/completion',
        body = { prompt = 'test2' },
        on_success = function() end,
        on_error = function() end,
      })

      http.request({
        endpoint = 'http://localhost:8080/completion',
        body = { prompt = 'test3' },
        on_success = function() end,
        on_error = function() end,
      })

      assert.are.equal(3, #jobs)

      -- Cancel all
      http.cancel_all()

      -- All jobs should be cancelled
      for _, job in ipairs(jobs) do
        assert.is_true(job._cancelled)
      end
    end)

    it('should not call any callbacks after cancel_all', function()
      local callbacks_triggered = 0

      mock_curl.post = function(opts)
        mock_curl._last_opts = opts
        local job = create_mock_job()
        local stored_callback = opts.callback
        job._trigger_callback = function()
          if stored_callback then
            stored_callback({
              status = 200,
              body = vim.json.encode({ content = 'test' }),
            })
          end
        end
        return job
      end

      local handle1 = http.request({
        endpoint = 'http://localhost:8080/completion',
        body = { prompt = 'test1' },
        on_success = function() callbacks_triggered = callbacks_triggered + 1 end,
        on_error = function() callbacks_triggered = callbacks_triggered + 1 end,
      })

      local job1 = mock_job

      local handle2 = http.request({
        endpoint = 'http://localhost:8080/completion',
        body = { prompt = 'test2' },
        on_success = function() callbacks_triggered = callbacks_triggered + 1 end,
        on_error = function() callbacks_triggered = callbacks_triggered + 1 end,
      })

      local job2 = mock_job

      -- Cancel all
      http.cancel_all()

      -- Try to trigger callbacks
      vim.schedule(function()
        job1._trigger_callback()
        job2._trigger_callback()
      end)

      vim.wait(100, function() return callbacks_triggered > 0 end, 10)

      assert.are.equal(0, callbacks_triggered)
    end)

    it('should clear the pending requests list', function()
      http.request({
        endpoint = 'http://localhost:8080/completion',
        body = { prompt = 'test' },
        on_success = function() end,
        on_error = function() end,
      })

      http.cancel_all()

      -- Subsequent cancel_all should not error (list should be empty)
      assert.has_no.errors(function()
        http.cancel_all()
      end)
    end)
  end)

  describe('timeout handling', function()
    it('should call on_error when request times out', function()
      local error_called = false
      local received_error = nil

      mock_curl.post = function(opts)
        mock_curl._last_opts = opts
        mock_job = create_mock_job()
        vim.schedule(function()
          if opts.callback then
            opts.callback({
              status = 0,
              body = nil,
              exit = 28, -- curl timeout exit code
            })
          end
        end)
        return mock_job
      end

      http.request({
        endpoint = 'http://localhost:8080/completion',
        body = { prompt = 'test' },
        timeout = 1000,
        on_success = function() end,
        on_error = function(err)
          error_called = true
          received_error = err
        end,
      })

      vim.wait(100, function() return error_called end)

      assert.is_true(error_called)
      assert.is_not_nil(received_error)
    end)
  end)

  describe('request tracking', function()
    it('should remove completed requests from tracking', function()
      mock_curl.post = function(opts)
        mock_curl._last_opts = opts
        mock_job = create_mock_job()
        vim.schedule(function()
          if opts.callback then
            opts.callback({
              status = 200,
              body = vim.json.encode({ content = 'test' }),
            })
          end
        end)
        return mock_job
      end

      local completed = false
      local handle = http.request({
        endpoint = 'http://localhost:8080/completion',
        body = { prompt = 'test' },
        on_success = function() completed = true end,
        on_error = function() end,
      })

      vim.wait(100, function() return completed end)

      -- After completion, cancelling should not error
      assert.has_no.errors(function()
        http.cancel(handle)
      end)
    end)
  end)
end)
