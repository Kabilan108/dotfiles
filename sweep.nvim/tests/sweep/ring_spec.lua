-- Tests for sweep.ring module (ring buffer for cross-file context collection)

describe('sweep.ring', function()
  local ring

  before_each(function()
    -- Reset module state before each test
    package.loaded['sweep.ring'] = nil
    ring = require('sweep.ring')
    ring.setup({
      max_chunks = 4,
      chunk_size = 10,
    })
  end)

  describe('setup', function()
    it('should initialize with given options', function()
      ring.setup({
        max_chunks = 8,
        chunk_size = 32,
      })
      local stats = ring.stats()
      assert.are.equal(0, stats.count)
      assert.are.equal(8, stats.max)
    end)
  end)

  describe('add', function()
    it('should store chunk with metadata', function()
      ring.add({
        content = 'local x = 1',
        filename = '/path/to/file.lua',
        filetype = 'lua',
        source = 'yank',
      })

      local chunks = ring.get_chunks({})
      assert.are.equal(1, #chunks)
      assert.are.equal('local x = 1', chunks[1].content)
      assert.are.equal('/path/to/file.lua', chunks[1].filename)
      assert.are.equal('lua', chunks[1].filetype)
      assert.are.equal('yank', chunks[1].source)
      assert.is_not_nil(chunks[1].timestamp)
    end)

    it('should evict oldest chunk when ring buffer is full', function()
      ring.add({ content = 'chunk1', filename = '/a.lua', filetype = 'lua', source = 'yank' })
      ring.add({ content = 'chunk2', filename = '/b.lua', filetype = 'lua', source = 'yank' })
      ring.add({ content = 'chunk3', filename = '/c.lua', filetype = 'lua', source = 'yank' })
      ring.add({ content = 'chunk4', filename = '/d.lua', filetype = 'lua', source = 'yank' })
      -- Buffer is now full (max_chunks = 4)

      -- Add one more, should evict chunk1
      ring.add({ content = 'chunk5', filename = '/e.lua', filetype = 'lua', source = 'yank' })

      local stats = ring.stats()
      assert.are.equal(4, stats.count)

      local chunks = ring.get_chunks({})
      -- Should have chunk2, chunk3, chunk4, chunk5 (chunk1 evicted)
      local contents = {}
      for _, chunk in ipairs(chunks) do
        table.insert(contents, chunk.content)
      end
      assert.is_nil(vim.tbl_contains(contents, 'chunk1') and 'chunk1' or nil)
      assert.is_true(vim.tbl_contains(contents, 'chunk5'))
    end)

    it('should not add duplicate chunks based on first 100 chars', function()
      local long_content = string.rep('a', 150)
      ring.add({ content = long_content, filename = '/a.lua', filetype = 'lua', source = 'yank' })
      ring.add({ content = long_content, filename = '/a.lua', filetype = 'lua', source = 'save' })

      local stats = ring.stats()
      assert.are.equal(1, stats.count)
    end)

    it('should allow similar chunks with different first 100 chars', function()
      local content1 = 'unique_prefix_1' .. string.rep('a', 100)
      local content2 = 'unique_prefix_2' .. string.rep('a', 100)
      ring.add({ content = content1, filename = '/a.lua', filetype = 'lua', source = 'yank' })
      ring.add({ content = content2, filename = '/a.lua', filetype = 'lua', source = 'yank' })

      local stats = ring.stats()
      assert.are.equal(2, stats.count)
    end)

    it('should trim content to chunk_size lines', function()
      -- chunk_size is 10 lines
      local lines = {}
      for i = 1, 20 do
        table.insert(lines, 'line ' .. i)
      end
      local content = table.concat(lines, '\n')

      ring.add({ content = content, filename = '/a.lua', filetype = 'lua', source = 'yank' })

      local chunks = ring.get_chunks({})
      local result_lines = vim.split(chunks[1].content, '\n')
      assert.are.equal(10, #result_lines)
      assert.are.equal('line 1', result_lines[1])
      assert.are.equal('line 10', result_lines[10])
    end)
  end)

  describe('get_context', function()
    it('should return formatted context string', function()
      ring.add({ content = 'local x = 1', filename = '/path/to/file.lua', filetype = 'lua', source = 'yank' })
      ring.add({ content = 'def foo():', filename = '/path/to/script.py', filetype = 'python', source = 'buffer_enter' })

      local context = ring.get_context()

      -- Most recent first
      assert.is_true(context:find('-- File: /path/to/script.py (python)', 1, true) ~= nil)
      assert.is_true(context:find('def foo():', 1, true) ~= nil)
      assert.is_true(context:find('-- File: /path/to/file.lua (lua)', 1, true) ~= nil)
      assert.is_true(context:find('local x = 1', 1, true) ~= nil)
    end)

    it('should return empty string when buffer is empty', function()
      local context = ring.get_context()
      assert.are.equal('', context)
    end)

    it('should return most recent chunks first', function()
      ring.add({ content = 'first', filename = '/a.lua', filetype = 'lua', source = 'yank' })
      ring.add({ content = 'second', filename = '/b.lua', filetype = 'lua', source = 'yank' })
      ring.add({ content = 'third', filename = '/c.lua', filetype = 'lua', source = 'yank' })

      local context = ring.get_context()
      local third_pos = context:find('third', 1, true)
      local second_pos = context:find('second', 1, true)
      local first_pos = context:find('first', 1, true)

      assert.is_true(third_pos < second_pos)
      assert.is_true(second_pos < first_pos)
    end)
  end)

  describe('get_chunks', function()
    before_each(function()
      ring.add({ content = 'lua code 1', filename = '/a.lua', filetype = 'lua', source = 'yank' })
      ring.add({ content = 'python code', filename = '/b.py', filetype = 'python', source = 'buffer_enter' })
      ring.add({ content = 'lua code 2', filename = '/c.lua', filetype = 'lua', source = 'save' })
    end)

    it('should filter by filetype', function()
      local chunks = ring.get_chunks({ filetype = 'lua' })
      assert.are.equal(2, #chunks)
      for _, chunk in ipairs(chunks) do
        assert.are.equal('lua', chunk.filetype)
      end
    end)

    it('should exclude specified file', function()
      local chunks = ring.get_chunks({ exclude_file = '/a.lua' })
      assert.are.equal(2, #chunks)
      for _, chunk in ipairs(chunks) do
        assert.is_not.are.equal('/a.lua', chunk.filename)
      end
    end)

    it('should respect max_chunks limit', function()
      local chunks = ring.get_chunks({ max_chunks = 2 })
      assert.are.equal(2, #chunks)
    end)

    it('should return most recent chunks first', function()
      local chunks = ring.get_chunks({})
      -- Most recent is 'lua code 2'
      assert.are.equal('lua code 2', chunks[1].content)
      assert.are.equal('python code', chunks[2].content)
      assert.are.equal('lua code 1', chunks[3].content)
    end)

    it('should combine multiple filters', function()
      local chunks = ring.get_chunks({
        filetype = 'lua',
        exclude_file = '/a.lua',
        max_chunks = 10,
      })
      assert.are.equal(1, #chunks)
      assert.are.equal('lua code 2', chunks[1].content)
    end)

    it('should return empty table when no chunks match', function()
      local chunks = ring.get_chunks({ filetype = 'rust' })
      assert.are.same({}, chunks)
    end)
  end)

  describe('clear', function()
    it('should empty the buffer', function()
      ring.add({ content = 'chunk1', filename = '/a.lua', filetype = 'lua', source = 'yank' })
      ring.add({ content = 'chunk2', filename = '/b.lua', filetype = 'lua', source = 'yank' })

      ring.clear()

      local stats = ring.stats()
      assert.are.equal(0, stats.count)
      assert.are.same({}, ring.get_chunks({}))
    end)
  end)

  describe('stats', function()
    it('should return correct counts', function()
      ring.add({ content = 'lua1', filename = '/a.lua', filetype = 'lua', source = 'yank' })
      ring.add({ content = 'lua2', filename = '/b.lua', filetype = 'lua', source = 'yank' })
      ring.add({ content = 'py1', filename = '/c.py', filetype = 'python', source = 'yank' })

      local stats = ring.stats()
      assert.are.equal(3, stats.count)
      assert.are.equal(4, stats.max)
      assert.are.same({ lua = 2, python = 1 }, stats.filetypes)
    end)

    it('should return empty filetypes when buffer is empty', function()
      local stats = ring.stats()
      assert.are.equal(0, stats.count)
      assert.are.same({}, stats.filetypes)
    end)
  end)
end)
