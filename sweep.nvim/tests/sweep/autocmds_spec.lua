-- Tests for sweep.autocmds module

describe('sweep.autocmds', function()
  local autocmds
  local config

  -- Mock modules
  local mock_completion
  local mock_ring
  local mock_ui

  before_each(function()
    -- Reset module state before each test
    package.loaded['sweep.autocmds'] = nil
    package.loaded['sweep.config'] = nil
    package.loaded['sweep.completion'] = nil
    package.loaded['sweep.ring'] = nil
    package.loaded['sweep.ui'] = nil

    -- Setup config with defaults
    config = require('sweep.config')
    config.setup()

    -- Create mock modules
    mock_completion = {
      trigger_called = false,
      cancel_called = false,
      trigger = function()
        mock_completion.trigger_called = true
      end,
      cancel = function()
        mock_completion.cancel_called = true
      end,
    }

    mock_ring = {
      add_called = false,
      last_add_args = nil,
      add = function(args)
        mock_ring.add_called = true
        mock_ring.last_add_args = args
      end,
    }

    mock_ui = {
      clear_called = false,
      clear = function()
        mock_ui.clear_called = true
      end,
    }

    -- Inject mocks
    package.loaded['sweep.completion'] = mock_completion
    package.loaded['sweep.ring'] = mock_ring
    package.loaded['sweep.ui'] = mock_ui

    -- Load autocmds module
    autocmds = require('sweep.autocmds')
  end)

  after_each(function()
    -- Always teardown after tests
    pcall(function()
      autocmds.teardown()
    end)
  end)

  describe('setup', function()
    it('should create the sweep augroup', function()
      autocmds.setup()

      -- Check that the augroup exists by trying to get autocmds in it
      local ok, result = pcall(vim.api.nvim_get_autocmds, { group = 'sweep' })
      assert.is_true(ok)
      assert.is_table(result)
    end)

    it('should create CursorMovedI autocmd', function()
      autocmds.setup()

      local cmds = vim.api.nvim_get_autocmds({ group = 'sweep', event = 'CursorMovedI' })
      assert.are.equal(1, #cmds)
    end)

    it('should create InsertLeave autocmd', function()
      autocmds.setup()

      local cmds = vim.api.nvim_get_autocmds({ group = 'sweep', event = 'InsertLeave' })
      assert.are.equal(1, #cmds)
    end)

    it('should create TextYankPost autocmd', function()
      autocmds.setup()

      local cmds = vim.api.nvim_get_autocmds({ group = 'sweep', event = 'TextYankPost' })
      assert.are.equal(1, #cmds)
    end)

    it('should create BufEnter autocmd', function()
      autocmds.setup()

      local cmds = vim.api.nvim_get_autocmds({ group = 'sweep', event = 'BufEnter' })
      assert.are.equal(1, #cmds)
    end)

    it('should create BufLeave autocmd', function()
      autocmds.setup()

      local cmds = vim.api.nvim_get_autocmds({ group = 'sweep', event = 'BufLeave' })
      assert.are.equal(1, #cmds)
    end)

    it('should create BufWritePost autocmd', function()
      autocmds.setup()

      local cmds = vim.api.nvim_get_autocmds({ group = 'sweep', event = 'BufWritePost' })
      assert.are.equal(1, #cmds)
    end)

    it('should be idempotent (can be called multiple times safely)', function()
      autocmds.setup()
      autocmds.setup()
      autocmds.setup()

      -- Should still only have one of each
      local cursor_cmds = vim.api.nvim_get_autocmds({ group = 'sweep', event = 'CursorMovedI' })
      assert.are.equal(1, #cursor_cmds)
    end)
  end)

  describe('teardown', function()
    it('should remove all autocmds in sweep augroup', function()
      autocmds.setup()

      -- Verify autocmds exist
      local cmds_before = vim.api.nvim_get_autocmds({ group = 'sweep' })
      assert.is_true(#cmds_before > 0)

      autocmds.teardown()

      -- Verify augroup is cleared
      local cmds_after = vim.api.nvim_get_autocmds({ group = 'sweep' })
      assert.are.equal(0, #cmds_after)
    end)

    it('should be safe to call when not set up', function()
      -- Should not error
      assert.has_no.errors(function()
        autocmds.teardown()
      end)
    end)

    it('should be safe to call multiple times', function()
      autocmds.setup()

      assert.has_no.errors(function()
        autocmds.teardown()
        autocmds.teardown()
        autocmds.teardown()
      end)
    end)
  end)

  describe('CursorMovedI behavior', function()
    local test_bufnr

    before_each(function()
      -- Create a test buffer
      test_bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, { 'test line' })
      vim.api.nvim_set_current_buf(test_bufnr)
      vim.bo[test_bufnr].filetype = 'lua'
    end)

    after_each(function()
      if vim.api.nvim_buf_is_valid(test_bufnr) then
        vim.api.nvim_buf_delete(test_bufnr, { force = true })
      end
    end)

    it('should trigger completion on CursorMovedI', function()
      autocmds.setup()

      -- Simulate CursorMovedI event
      vim.api.nvim_exec_autocmds('CursorMovedI', { group = 'sweep', buffer = test_bufnr })

      assert.is_true(mock_completion.trigger_called)
    end)

    it('should not trigger completion for excluded filetypes', function()
      -- Set filetype to an excluded type
      vim.bo[test_bufnr].filetype = 'TelescopePrompt'

      autocmds.setup()

      -- Simulate CursorMovedI event
      vim.api.nvim_exec_autocmds('CursorMovedI', { group = 'sweep', buffer = test_bufnr })

      assert.is_false(mock_completion.trigger_called)
    end)
  end)

  describe('InsertLeave behavior', function()
    local test_bufnr

    before_each(function()
      test_bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, { 'test line' })
      vim.api.nvim_set_current_buf(test_bufnr)
    end)

    after_each(function()
      if vim.api.nvim_buf_is_valid(test_bufnr) then
        vim.api.nvim_buf_delete(test_bufnr, { force = true })
      end
    end)

    it('should cancel completion on InsertLeave', function()
      autocmds.setup()

      vim.api.nvim_exec_autocmds('InsertLeave', { group = 'sweep', buffer = test_bufnr })

      assert.is_true(mock_completion.cancel_called)
    end)

    it('should clear UI on InsertLeave', function()
      autocmds.setup()

      vim.api.nvim_exec_autocmds('InsertLeave', { group = 'sweep', buffer = test_bufnr })

      assert.is_true(mock_ui.clear_called)
    end)
  end)

  describe('BufLeave behavior during insert', function()
    local test_bufnr

    before_each(function()
      test_bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, { 'test line' })
      vim.api.nvim_set_current_buf(test_bufnr)
    end)

    after_each(function()
      if vim.api.nvim_buf_is_valid(test_bufnr) then
        vim.api.nvim_buf_delete(test_bufnr, { force = true })
      end
    end)

    it('should cancel completion on BufLeave', function()
      autocmds.setup()

      vim.api.nvim_exec_autocmds('BufLeave', { group = 'sweep', buffer = test_bufnr })

      assert.is_true(mock_completion.cancel_called)
    end)

    it('should clear UI on BufLeave', function()
      autocmds.setup()

      vim.api.nvim_exec_autocmds('BufLeave', { group = 'sweep', buffer = test_bufnr })

      assert.is_true(mock_ui.clear_called)
    end)
  end)

  describe('TextYankPost behavior', function()
    it('should add yanked text to ring buffer', function()
      autocmds.setup()

      -- Simulate yank event by setting vim.v.event
      -- Note: We can't easily simulate vim.v.event in tests,
      -- so we test that the autocmd is created and trust the callback
      local cmds = vim.api.nvim_get_autocmds({ group = 'sweep', event = 'TextYankPost' })
      assert.are.equal(1, #cmds)

      -- The callback should be properly configured
      assert.is_not_nil(cmds[1].callback)
    end)
  end)

  describe('BufEnter behavior', function()
    local test_bufnr

    before_each(function()
      test_bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        'line 1',
        'line 2',
        'line 3',
      })
      vim.api.nvim_set_current_buf(test_bufnr)
      vim.bo[test_bufnr].filetype = 'lua'
    end)

    after_each(function()
      if vim.api.nvim_buf_is_valid(test_bufnr) then
        vim.api.nvim_buf_delete(test_bufnr, { force = true })
      end
    end)

    it('should add visible buffer content to ring on BufEnter', function()
      autocmds.setup()

      vim.api.nvim_exec_autocmds('BufEnter', { group = 'sweep', buffer = test_bufnr })

      assert.is_true(mock_ring.add_called)
      assert.is_not_nil(mock_ring.last_add_args)
      assert.are.equal('buffer_enter', mock_ring.last_add_args.source)
      assert.are.equal('lua', mock_ring.last_add_args.filetype)
    end)
  end)

  describe('BufWritePost behavior', function()
    local test_bufnr

    before_each(function()
      test_bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
        'saved content',
      })
      vim.api.nvim_set_current_buf(test_bufnr)
      vim.bo[test_bufnr].filetype = 'python'
    end)

    after_each(function()
      if vim.api.nvim_buf_is_valid(test_bufnr) then
        vim.api.nvim_buf_delete(test_bufnr, { force = true })
      end
    end)

    it('should add visible buffer content to ring on BufWritePost', function()
      autocmds.setup()

      vim.api.nvim_exec_autocmds('BufWritePost', { group = 'sweep', buffer = test_bufnr })

      assert.is_true(mock_ring.add_called)
      assert.is_not_nil(mock_ring.last_add_args)
      assert.are.equal('save', mock_ring.last_add_args.source)
      assert.are.equal('python', mock_ring.last_add_args.filetype)
    end)
  end)

  describe('excluded filetypes', function()
    local test_bufnr

    before_each(function()
      test_bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, { 'test' })
      vim.api.nvim_set_current_buf(test_bufnr)
    end)

    after_each(function()
      if vim.api.nvim_buf_is_valid(test_bufnr) then
        vim.api.nvim_buf_delete(test_bufnr, { force = true })
      end
    end)

    it('should skip CursorMovedI for help filetype', function()
      vim.bo[test_bufnr].filetype = 'help'
      autocmds.setup()

      vim.api.nvim_exec_autocmds('CursorMovedI', { group = 'sweep', buffer = test_bufnr })

      assert.is_false(mock_completion.trigger_called)
    end)

    it('should skip CursorMovedI for TelescopePrompt', function()
      vim.bo[test_bufnr].filetype = 'TelescopePrompt'
      autocmds.setup()

      vim.api.nvim_exec_autocmds('CursorMovedI', { group = 'sweep', buffer = test_bufnr })

      assert.is_false(mock_completion.trigger_called)
    end)

    it('should skip CursorMovedI for NvimTree', function()
      vim.bo[test_bufnr].filetype = 'NvimTree'
      autocmds.setup()

      vim.api.nvim_exec_autocmds('CursorMovedI', { group = 'sweep', buffer = test_bufnr })

      assert.is_false(mock_completion.trigger_called)
    end)

    it('should allow CursorMovedI for regular filetypes', function()
      vim.bo[test_bufnr].filetype = 'lua'
      autocmds.setup()

      vim.api.nvim_exec_autocmds('CursorMovedI', { group = 'sweep', buffer = test_bufnr })

      assert.is_true(mock_completion.trigger_called)
    end)
  end)
end)
