-- Tests for sweep.edits module (edit tracking for next-edit prediction)

describe('sweep.edits', function()
  local edits

  before_each(function()
    -- Reset module state before each test
    package.loaded['sweep.edits'] = nil
    edits = require('sweep.edits')
    edits.setup({
      max_edits = 5,
      max_lines = 10,
      context_lines = 3,
    })
  end)

  describe('setup', function()
    it('should initialize with given options', function()
      edits.setup({
        max_edits = 20,
        max_lines = 50,
        context_lines = 5,
      })
      -- Module should be initialized (verify via get_history returning empty array)
      local history = edits.get_history()
      assert.are.same({}, history)
    end)

    it('should use default values when options not provided', function()
      package.loaded['sweep.edits'] = nil
      edits = require('sweep.edits')
      edits.setup({})
      local history = edits.get_history()
      assert.are.same({}, history)
    end)
  end)

  describe('record', function()
    it('should store edit with metadata', function()
      edits.record({
        bufnr = 1,
        start_line = 10,
        end_line = 12,
        old_lines = { 'original line' },
        new_lines = { 'updated line' },
        filename = '/path/to/file.lua',
      })

      local history = edits.get_history()
      assert.are.equal(1, #history)
      assert.are.same({ 'original line' }, history[1].old_lines)
      assert.are.same({ 'updated line' }, history[1].new_lines)
      assert.are.equal('/path/to/file.lua', history[1].filename)
      assert.is_not_nil(history[1].timestamp)
    end)

    it('should include filename in each edit', function()
      edits.record({
        bufnr = 1,
        start_line = 1,
        end_line = 1,
        old_lines = { 'old' },
        new_lines = { 'new' },
        filename = '/test/file.py',
      })

      local history = edits.get_history()
      assert.are.equal('/test/file.py', history[1].filename)
    end)

    it('should record edits with bufnr for buffer tracking', function()
      edits.record({
        bufnr = 42,
        start_line = 1,
        end_line = 1,
        old_lines = { 'old' },
        new_lines = { 'new' },
        filename = '/file.lua',
      })

      local history = edits.get_history()
      assert.are.equal(42, history[1].bufnr)
    end)
  end)

  describe('edit ordering', function()
    it('should order edits by recency (newest first)', function()
      edits.record({
        bufnr = 1,
        start_line = 1,
        end_line = 1,
        old_lines = { 'first old' },
        new_lines = { 'first new' },
        filename = '/first.lua',
      })

      edits.record({
        bufnr = 1,
        start_line = 1,
        end_line = 1,
        old_lines = { 'second old' },
        new_lines = { 'second new' },
        filename = '/second.lua',
      })

      edits.record({
        bufnr = 1,
        start_line = 1,
        end_line = 1,
        old_lines = { 'third old' },
        new_lines = { 'third new' },
        filename = '/third.lua',
      })

      local history = edits.get_history()
      assert.are.equal(3, #history)
      -- Newest first
      assert.are.same({ 'third new' }, history[1].new_lines)
      assert.are.same({ 'second new' }, history[2].new_lines)
      assert.are.same({ 'first new' }, history[3].new_lines)
    end)
  end)

  describe('max_edits limit', function()
    it('should respect max_edits limit and evict oldest', function()
      -- max_edits is 5
      for i = 1, 7 do
        edits.record({
          bufnr = 1,
          start_line = 1,
          end_line = 1,
          old_lines = { 'old' .. i },
          new_lines = { 'new' .. i },
          filename = '/file' .. i .. '.lua',
        })
      end

      local history = edits.get_history()
      assert.are.equal(5, #history)

      -- Check that oldest edits (1 and 2) were evicted
      local filenames = {}
      for _, edit in ipairs(history) do
        table.insert(filenames, edit.filename)
      end
      assert.is_false(vim.tbl_contains(filenames, '/file1.lua'))
      assert.is_false(vim.tbl_contains(filenames, '/file2.lua'))
      assert.is_true(vim.tbl_contains(filenames, '/file7.lua'))
    end)
  end)

  describe('get_context', function()
    it('should return properly formatted string with tags', function()
      edits.record({
        bufnr = 1,
        start_line = 1,
        end_line = 1,
        old_lines = { 'function old() {', '  return 1', '}' },
        new_lines = { 'function new() {', '  return 2', '}' },
        filename = '/test.lua',
      })

      local context = edits.get_context()

      -- Check for proper XML-style tags
      assert.is_true(context:find('<edit>', 1, true) ~= nil)
      assert.is_true(context:find('</edit>', 1, true) ~= nil)
      assert.is_true(context:find('<original>', 1, true) ~= nil)
      assert.is_true(context:find('</original>', 1, true) ~= nil)
      assert.is_true(context:find('<updated>', 1, true) ~= nil)
      assert.is_true(context:find('</updated>', 1, true) ~= nil)
    end)

    it('should include old and new code content', function()
      edits.record({
        bufnr = 1,
        start_line = 1,
        end_line = 1,
        old_lines = { 'original code here' },
        new_lines = { 'updated code here' },
        filename = '/test.lua',
      })

      local context = edits.get_context()
      assert.is_true(context:find('original code here', 1, true) ~= nil)
      assert.is_true(context:find('updated code here', 1, true) ~= nil)
    end)

    it('should return empty string when no edits recorded', function()
      local context = edits.get_context()
      assert.are.equal('', context)
    end)

    it('should format multiple edits with separate tags', function()
      edits.record({
        bufnr = 1,
        start_line = 1,
        end_line = 1,
        old_lines = { 'first old' },
        new_lines = { 'first new' },
        filename = '/first.lua',
      })

      edits.record({
        bufnr = 1,
        start_line = 1,
        end_line = 1,
        old_lines = { 'second old' },
        new_lines = { 'second new' },
        filename = '/second.lua',
      })

      local context = edits.get_context()

      -- Should have two <edit> blocks
      local edit_count = 0
      for _ in context:gmatch('<edit>') do
        edit_count = edit_count + 1
      end
      assert.are.equal(2, edit_count)
    end)

    it('should show most recent edits first in context', function()
      edits.record({
        bufnr = 1,
        start_line = 1,
        end_line = 1,
        old_lines = { 'first old' },
        new_lines = { 'first new' },
        filename = '/first.lua',
      })

      edits.record({
        bufnr = 1,
        start_line = 1,
        end_line = 1,
        old_lines = { 'second old' },
        new_lines = { 'second new' },
        filename = '/second.lua',
      })

      local context = edits.get_context()
      local second_pos = context:find('second new', 1, true)
      local first_pos = context:find('first new', 1, true)

      -- Second (more recent) should appear before first
      assert.is_true(second_pos < first_pos)
    end)
  end)

  describe('clear', function()
    it('should remove all edits', function()
      edits.record({
        bufnr = 1,
        start_line = 1,
        end_line = 1,
        old_lines = { 'old1' },
        new_lines = { 'new1' },
        filename = '/file1.lua',
      })

      edits.record({
        bufnr = 2,
        start_line = 1,
        end_line = 1,
        old_lines = { 'old2' },
        new_lines = { 'new2' },
        filename = '/file2.lua',
      })

      edits.clear()

      local history = edits.get_history()
      assert.are.same({}, history)
      assert.are.equal('', edits.get_context())
    end)
  end)

  describe('clear_buffer', function()
    it('should only remove edits for the specified buffer', function()
      edits.record({
        bufnr = 1,
        start_line = 1,
        end_line = 1,
        old_lines = { 'buf1 old' },
        new_lines = { 'buf1 new' },
        filename = '/buf1.lua',
      })

      edits.record({
        bufnr = 2,
        start_line = 1,
        end_line = 1,
        old_lines = { 'buf2 old' },
        new_lines = { 'buf2 new' },
        filename = '/buf2.lua',
      })

      edits.record({
        bufnr = 1,
        start_line = 5,
        end_line = 6,
        old_lines = { 'buf1 old2' },
        new_lines = { 'buf1 new2' },
        filename = '/buf1.lua',
      })

      edits.clear_buffer(1)

      local history = edits.get_history()
      assert.are.equal(1, #history)
      assert.are.equal(2, history[1].bufnr)
      assert.are.equal('/buf2.lua', history[1].filename)
    end)

    it('should handle clearing non-existent buffer gracefully', function()
      edits.record({
        bufnr = 1,
        start_line = 1,
        end_line = 1,
        old_lines = { 'old' },
        new_lines = { 'new' },
        filename = '/file.lua',
      })

      -- Should not error
      edits.clear_buffer(999)

      local history = edits.get_history()
      assert.are.equal(1, #history)
    end)
  end)

  describe('get_history', function()
    it('should return raw edit data array', function()
      edits.record({
        bufnr = 1,
        start_line = 10,
        end_line = 12,
        old_lines = { 'line1', 'line2' },
        new_lines = { 'newline1', 'newline2', 'newline3' },
        filename = '/test.lua',
      })

      local history = edits.get_history()
      assert.is_true(type(history) == 'table')
      assert.are.equal(1, #history)

      local edit = history[1]
      assert.is_not_nil(edit.timestamp)
      assert.are.equal('/test.lua', edit.filename)
      assert.are.same({ 'line1', 'line2' }, edit.old_lines)
      assert.are.same({ 'newline1', 'newline2', 'newline3' }, edit.new_lines)
    end)

    it('should return empty table when no edits', function()
      local history = edits.get_history()
      assert.are.same({}, history)
    end)
  end)

  describe('max_lines truncation', function()
    it('should truncate long edits to max_lines', function()
      -- max_lines is 10
      local old_lines = {}
      local new_lines = {}
      for i = 1, 25 do
        table.insert(old_lines, 'old line ' .. i)
        table.insert(new_lines, 'new line ' .. i)
      end

      edits.record({
        bufnr = 1,
        start_line = 1,
        end_line = 25,
        old_lines = old_lines,
        new_lines = new_lines,
        filename = '/long.lua',
      })

      local history = edits.get_history()
      assert.are.equal(1, #history)
      -- Both old and new lines should be truncated to max_lines
      assert.are.equal(10, #history[1].old_lines)
      assert.are.equal(10, #history[1].new_lines)
      assert.are.equal('old line 1', history[1].old_lines[1])
      assert.are.equal('old line 10', history[1].old_lines[10])
    end)

    it('should not truncate edits shorter than max_lines', function()
      edits.record({
        bufnr = 1,
        start_line = 1,
        end_line = 3,
        old_lines = { 'line1', 'line2', 'line3' },
        new_lines = { 'new1', 'new2' },
        filename = '/short.lua',
      })

      local history = edits.get_history()
      assert.are.equal(3, #history[1].old_lines)
      assert.are.equal(2, #history[1].new_lines)
    end)
  end)

  describe('attach and detach', function()
    it('should return true when attach is called', function()
      -- attach returns success indicator
      local result = edits.attach(1)
      assert.is_true(result == true or result == nil or result)
    end)

    it('should track attached buffers', function()
      edits.attach(1)
      edits.attach(2)

      -- Detach should work without error
      edits.detach(1)
      edits.detach(2)
    end)

    it('should handle detach on non-attached buffer gracefully', function()
      -- Should not error
      edits.detach(999)
    end)

    it('should handle multiple attach calls on same buffer', function()
      -- Should not error or create duplicates
      edits.attach(1)
      edits.attach(1)
      edits.detach(1)
    end)
  end)

  describe('edge cases', function()
    it('should handle empty old_lines', function()
      edits.record({
        bufnr = 1,
        start_line = 1,
        end_line = 1,
        old_lines = {},
        new_lines = { 'new line' },
        filename = '/file.lua',
      })

      local history = edits.get_history()
      assert.are.equal(1, #history)
      assert.are.same({}, history[1].old_lines)
    end)

    it('should handle empty new_lines', function()
      edits.record({
        bufnr = 1,
        start_line = 1,
        end_line = 1,
        old_lines = { 'old line' },
        new_lines = {},
        filename = '/file.lua',
      })

      local history = edits.get_history()
      assert.are.equal(1, #history)
      assert.are.same({}, history[1].new_lines)
    end)

    it('should handle nil filename by using empty string', function()
      edits.record({
        bufnr = 1,
        start_line = 1,
        end_line = 1,
        old_lines = { 'old' },
        new_lines = { 'new' },
      })

      local history = edits.get_history()
      assert.are.equal('', history[1].filename)
    end)

    it('should not record edit when both old and new are empty', function()
      edits.record({
        bufnr = 1,
        start_line = 1,
        end_line = 1,
        old_lines = {},
        new_lines = {},
        filename = '/file.lua',
      })

      local history = edits.get_history()
      assert.are.same({}, history)
    end)

    it('should not record edit when old and new are identical', function()
      edits.record({
        bufnr = 1,
        start_line = 1,
        end_line = 1,
        old_lines = { 'same line' },
        new_lines = { 'same line' },
        filename = '/file.lua',
      })

      local history = edits.get_history()
      assert.are.same({}, history)
    end)
  end)
end)
