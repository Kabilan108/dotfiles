-- Tests for sweep.ui module

describe('sweep.ui', function()
  local ui
  local config
  local test_bufnr

  before_each(function()
    -- Reset module state before each test
    package.loaded['sweep.ui'] = nil
    package.loaded['sweep.config'] = nil

    config = require('sweep.config')
    config.setup()
    ui = require('sweep.ui')

    -- Create a test buffer with some content
    test_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
      'line 0',
      'line 1',
      'line 2',
      'line 3',
      'line 4',
      'line 5',
      'line 6',
      'line 7',
      'line 8',
      'line 9',
      'line 10',
      'line 11',
    })
    vim.api.nvim_set_current_buf(test_bufnr)
  end)

  after_each(function()
    -- Clean up test buffer
    ui.clear()
    if vim.api.nvim_buf_is_valid(test_bufnr) then
      vim.api.nvim_buf_delete(test_bufnr, { force = true })
    end
  end)

  describe('show', function()
    it('should create extmarks at correct position', function()
      ui.show({
        lines = { 'completion text' },
        bufnr = test_bufnr,
        row = 5,
        col = 4,
      })

      local ns = vim.api.nvim_create_namespace('sweep')
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, { details = true })

      assert.is_true(#marks > 0)
      -- Check mark is at correct row (0-indexed)
      assert.are.equal(5, marks[1][2])
    end)

    it('should use virt_text for single-line completion', function()
      ui.show({
        lines = { 'single line' },
        bufnr = test_bufnr,
        row = 3,
        col = 4,
      })

      local ns = vim.api.nvim_create_namespace('sweep')
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, { details = true })

      assert.is_true(#marks > 0)
      local details = marks[1][4]
      assert.is_not_nil(details.virt_text)
      -- Should not have virt_lines for single-line completion
      assert.is_nil(details.virt_lines)
    end)

    it('should use virt_text and virt_lines for multi-line completion', function()
      ui.show({
        lines = { 'first line', 'second line', 'third line' },
        bufnr = test_bufnr,
        row = 2,
        col = 4,
      })

      local ns = vim.api.nvim_create_namespace('sweep')
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, { details = true })

      assert.is_true(#marks > 0)
      local details = marks[1][4]
      -- First line should be in virt_text
      assert.is_not_nil(details.virt_text)
      -- Additional lines should be in virt_lines
      assert.is_not_nil(details.virt_lines)
      assert.are.equal(2, #details.virt_lines)
    end)

    it('should use correct highlight group from config', function()
      ui.show({
        lines = { 'highlighted text' },
        bufnr = test_bufnr,
        row = 1,
        col = 0,
      })

      local ns = vim.api.nvim_create_namespace('sweep')
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, { details = true })

      assert.is_true(#marks > 0)
      local details = marks[1][4]
      local hl_group = details.virt_text[1][2]
      assert.are.equal('SweepGhostText', hl_group)
    end)

    it('should clear previous marks on consecutive calls', function()
      ui.show({
        lines = { 'first completion' },
        bufnr = test_bufnr,
        row = 1,
        col = 0,
      })

      ui.show({
        lines = { 'second completion' },
        bufnr = test_bufnr,
        row = 3,
        col = 0,
      })

      local ns = vim.api.nvim_create_namespace('sweep')
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, { details = true })

      -- Should only have marks from second call
      assert.are.equal(1, #marks)
      -- Mark should be at row 3
      assert.are.equal(3, marks[1][2])
    end)

    it('should handle empty lines array gracefully', function()
      -- Should not error
      ui.show({
        lines = {},
        bufnr = test_bufnr,
        row = 0,
        col = 0,
      })

      assert.is_false(ui.is_visible())
    end)

    it('should display info when provided', function()
      ui.show({
        lines = { 'completion' },
        bufnr = test_bufnr,
        row = 2,
        col = 4,
        info = {
          tokens = 45,
          latency_ms = 89,
        },
      })

      local ns = vim.api.nvim_create_namespace('sweep')
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, { details = true })

      assert.is_true(#marks > 0)
      local details = marks[1][4]
      -- Info should be part of the virt_text array
      assert.is_true(#details.virt_text >= 2)
      -- Second element should have info highlight group
      local info_hl = details.virt_text[2][2]
      assert.are.equal('SweepInfo', info_hl)
    end)

    it('should not display info when show_info is false', function()
      config.setup({ ui = { show_info = false } })
      -- Reload ui module to pick up new config
      package.loaded['sweep.ui'] = nil
      ui = require('sweep.ui')

      ui.show({
        lines = { 'completion' },
        bufnr = test_bufnr,
        row = 2,
        col = 4,
        info = {
          tokens = 45,
          latency_ms = 89,
        },
      })

      local ns = vim.api.nvim_create_namespace('sweep')
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, { details = true })

      assert.is_true(#marks > 0)
      local details = marks[1][4]
      -- Should only have one virt_text entry (no info)
      assert.are.equal(1, #details.virt_text)
    end)
  end)

  describe('clear', function()
    it('should remove all extmarks in namespace', function()
      ui.show({
        lines = { 'completion text' },
        bufnr = test_bufnr,
        row = 5,
        col = 4,
      })

      ui.clear()

      local ns = vim.api.nvim_create_namespace('sweep')
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, {})

      assert.are.equal(0, #marks)
    end)

    it('should be safe to call when no completion is visible', function()
      -- Should not error
      ui.clear()
      ui.clear()
      assert.is_false(ui.is_visible())
    end)
  end)

  describe('is_visible', function()
    it('should return true when completion is visible', function()
      ui.show({
        lines = { 'completion' },
        bufnr = test_bufnr,
        row = 0,
        col = 0,
      })

      assert.is_true(ui.is_visible())
    end)

    it('should return false when no completion is visible', function()
      assert.is_false(ui.is_visible())
    end)

    it('should return false after clear is called', function()
      ui.show({
        lines = { 'completion' },
        bufnr = test_bufnr,
        row = 0,
        col = 0,
      })

      ui.clear()

      assert.is_false(ui.is_visible())
    end)
  end)

  describe('get_current', function()
    it('should return completion data when visible', function()
      ui.show({
        lines = { 'line 1', 'line 2' },
        bufnr = test_bufnr,
        row = 5,
        col = 10,
      })

      local current = ui.get_current()

      assert.is_not_nil(current)
      assert.are.same({ 'line 1', 'line 2' }, current.lines)
      assert.are.equal(test_bufnr, current.bufnr)
      assert.are.equal(5, current.row)
      assert.are.equal(10, current.col)
    end)

    it('should return nil when not visible', function()
      local current = ui.get_current()
      assert.is_nil(current)
    end)

    it('should return nil after clear is called', function()
      ui.show({
        lines = { 'completion' },
        bufnr = test_bufnr,
        row = 0,
        col = 0,
      })

      ui.clear()

      local current = ui.get_current()
      assert.is_nil(current)
    end)

    it('should return updated data after consecutive shows', function()
      ui.show({
        lines = { 'first' },
        bufnr = test_bufnr,
        row = 1,
        col = 1,
      })

      ui.show({
        lines = { 'second', 'third' },
        bufnr = test_bufnr,
        row = 5,
        col = 8,
      })

      local current = ui.get_current()

      assert.is_not_nil(current)
      assert.are.same({ 'second', 'third' }, current.lines)
      assert.are.equal(5, current.row)
      assert.are.equal(8, current.col)
    end)
  end)

  describe('edge cases', function()
    it('should handle cursor at end of line', function()
      -- Line 0 is "line 0" which has 6 characters
      ui.show({
        lines = { 'appended' },
        bufnr = test_bufnr,
        row = 0,
        col = 6,  -- End of "line 0"
      })

      assert.is_true(ui.is_visible())
      local ns = vim.api.nvim_create_namespace('sweep')
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, { details = true })
      assert.is_true(#marks > 0)
    end)

    it('should handle completion with empty first line', function()
      ui.show({
        lines = { '', 'second line' },
        bufnr = test_bufnr,
        row = 3,
        col = 4,
      })

      assert.is_true(ui.is_visible())
      local current = ui.get_current()
      assert.are.same({ '', 'second line' }, current.lines)
    end)

    it('should handle multi-line completion with trailing empty lines', function()
      ui.show({
        lines = { 'content', '', '' },
        bufnr = test_bufnr,
        row = 2,
        col = 0,
      })

      assert.is_true(ui.is_visible())
      local ns = vim.api.nvim_create_namespace('sweep')
      local marks = vim.api.nvim_buf_get_extmarks(test_bufnr, ns, 0, -1, { details = true })
      local details = marks[1][4]
      -- Should have virt_lines for the empty lines
      assert.is_not_nil(details.virt_lines)
      assert.are.equal(2, #details.virt_lines)
    end)

    it('should handle using bufnr 0 for current buffer', function()
      ui.show({
        lines = { 'completion' },
        bufnr = 0,
        row = 1,
        col = 0,
      })

      assert.is_true(ui.is_visible())
      local current = ui.get_current()
      -- get_current should return the resolved buffer number, not 0
      assert.are.equal(test_bufnr, current.bufnr)
    end)
  end)
end)
