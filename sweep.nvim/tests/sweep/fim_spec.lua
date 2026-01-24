-- Tests for sweep.fim module (FIM request builder)

describe('sweep.fim', function()
  local fim

  -- Mock buffer data for tests
  local mock_buffer_lines = {}
  local mock_buffer_name = 'test.lua'
  local mock_filetype = 'lua'

  -- Save original vim.api functions
  local original_nvim_buf_get_lines
  local original_nvim_buf_get_name
  local original_nvim_get_option_value

  before_each(function()
    -- Reset module state before each test
    package.loaded['sweep.fim'] = nil

    -- Save originals
    original_nvim_buf_get_lines = vim.api.nvim_buf_get_lines
    original_nvim_buf_get_name = vim.api.nvim_buf_get_name
    original_nvim_get_option_value = vim.api.nvim_get_option_value

    -- Mock vim.api.nvim_buf_get_lines
    vim.api.nvim_buf_get_lines = function(bufnr, start_row, end_row, strict_indexing)
      local result = {}
      local actual_end = end_row == -1 and #mock_buffer_lines or end_row
      for i = start_row + 1, actual_end do
        if mock_buffer_lines[i] then
          table.insert(result, mock_buffer_lines[i])
        end
      end
      return result
    end

    -- Mock vim.api.nvim_buf_get_name
    vim.api.nvim_buf_get_name = function(bufnr)
      return mock_buffer_name
    end

    -- Mock vim.api.nvim_get_option_value
    vim.api.nvim_get_option_value = function(name, opts)
      if name == 'filetype' then
        return mock_filetype
      end
      return ''
    end

    -- Reset mock data
    mock_buffer_lines = {}
    mock_buffer_name = 'test.lua'
    mock_filetype = 'lua'

    fim = require('sweep.fim')
  end)

  after_each(function()
    -- Restore originals
    vim.api.nvim_buf_get_lines = original_nvim_buf_get_lines
    vim.api.nvim_buf_get_name = original_nvim_buf_get_name
    vim.api.nvim_get_option_value = original_nvim_get_option_value
  end)

  describe('build_request', function()
    describe('prefix extraction', function()
      it('should extract lines before cursor plus partial current line', function()
        mock_buffer_lines = {
          'local M = {}',
          '',
          'function M.hello()',
          '  print("world")',
          'end',
        }

        local result = fim.build_request({
          bufnr = 0,
          row = 3,  -- 0-indexed, line with print
          col = 8,  -- after '  print'
          prefix_lines = 100,
          suffix_lines = 50,
        })

        -- Prefix should be lines 0-2 plus partial line 3 up to column 8
        assert.is_not_nil(result.input_prefix)
        assert.is_true(result.input_prefix:find('local M = {}') ~= nil)
        assert.is_true(result.input_prefix:find('function M.hello()') ~= nil)
        assert.is_true(result.input_prefix:find('  print') ~= nil)
        -- Should NOT include the part after cursor
        assert.is_nil(result.input_prefix:find('world'))
      end)

      it('should respect prefix_lines limit', function()
        mock_buffer_lines = {
          'line 1',
          'line 2',
          'line 3',
          'line 4',
          'line 5',
          'cursor line',
        }

        local result = fim.build_request({
          bufnr = 0,
          row = 5,  -- cursor line
          col = 6,  -- after 'cursor'
          prefix_lines = 2,  -- only include 2 lines before cursor line
          suffix_lines = 50,
        })

        -- Should only have lines 3, 4 and partial 5 in prefix
        assert.is_nil(result.input_prefix:find('line 1'))
        assert.is_nil(result.input_prefix:find('line 2'))
        assert.is_true(result.input_prefix:find('line 4') ~= nil)
        assert.is_true(result.input_prefix:find('line 5') ~= nil)
        assert.is_true(result.input_prefix:find('cursor') ~= nil)
      end)
    end)

    describe('suffix extraction', function()
      it('should extract rest of current line plus lines after cursor', function()
        mock_buffer_lines = {
          'local M = {}',
          '',
          'function M.hello()',
          '  print("world")',
          'end',
          'return M',
        }

        local result = fim.build_request({
          bufnr = 0,
          row = 3,  -- line with print
          col = 8,  -- after '  print'
          prefix_lines = 100,
          suffix_lines = 50,
        })

        -- Suffix should be rest of line 3 plus lines 4-5
        assert.is_not_nil(result.input_suffix)
        assert.is_true(result.input_suffix:find('world') ~= nil)
        assert.is_true(result.input_suffix:find('end') ~= nil)
        assert.is_true(result.input_suffix:find('return M') ~= nil)
      end)

      it('should respect suffix_lines limit', function()
        mock_buffer_lines = {
          'cursor line',
          'line 1',
          'line 2',
          'line 3',
          'line 4',
          'line 5',
        }

        local result = fim.build_request({
          bufnr = 0,
          row = 0,  -- cursor line
          col = 6,  -- after 'cursor'
          prefix_lines = 100,
          suffix_lines = 2,  -- only include 2 lines after cursor line
        })

        -- Should only have rest of line 0 plus lines 1-2
        assert.is_true(result.input_suffix:find('line 1') ~= nil)
        assert.is_true(result.input_suffix:find('line 2') ~= nil)
        assert.is_nil(result.input_suffix:find('line 3'))
        assert.is_nil(result.input_suffix:find('line 4'))
      end)
    end)

    describe('cursor at line boundaries', function()
      it('should handle cursor at line start', function()
        mock_buffer_lines = {
          'line before',
          'current line',
          'line after',
        }

        local result = fim.build_request({
          bufnr = 0,
          row = 1,
          col = 0,  -- at start of line
          prefix_lines = 100,
          suffix_lines = 50,
        })

        -- Prefix should not include any of current line
        assert.is_true(result.input_prefix:find('line before\n$') ~= nil)
        -- Suffix should be entire current line plus lines after
        assert.is_true(result.input_suffix:find('^current line') ~= nil)
      end)

      it('should handle cursor at line end', function()
        mock_buffer_lines = {
          'line before',
          'current line',
          'line after',
        }

        local result = fim.build_request({
          bufnr = 0,
          row = 1,
          col = 12,  -- at end of 'current line'
          prefix_lines = 100,
          suffix_lines = 50,
        })

        -- Prefix should include full current line
        assert.is_true(result.input_prefix:find('current line$') ~= nil)
        -- Suffix should start with newline (rest of current line is empty)
        assert.is_true(result.input_suffix:find('^[\n]') ~= nil or result.input_suffix:find('^line after') ~= nil)
      end)
    end)

    describe('edge cases', function()
      it('should handle empty buffer', function()
        mock_buffer_lines = {}

        local result = fim.build_request({
          bufnr = 0,
          row = 0,
          col = 0,
          prefix_lines = 100,
          suffix_lines = 50,
        })

        assert.is_not_nil(result)
        assert.are.equal('', result.input_prefix)
        assert.are.equal('', result.input_suffix)
      end)

      it('should handle cursor at first line of file', function()
        mock_buffer_lines = {
          'first line',
          'second line',
        }

        local result = fim.build_request({
          bufnr = 0,
          row = 0,
          col = 5,
          prefix_lines = 100,
          suffix_lines = 50,
        })

        assert.are.equal('first', result.input_prefix)
        assert.is_true(result.input_suffix:find(' line') ~= nil)
        assert.is_true(result.input_suffix:find('second line') ~= nil)
      end)

      it('should handle cursor at last line of file', function()
        mock_buffer_lines = {
          'first line',
          'last line',
        }

        local result = fim.build_request({
          bufnr = 0,
          row = 1,
          col = 4,  -- after 'last'
          prefix_lines = 100,
          suffix_lines = 50,
        })

        assert.is_true(result.input_prefix:find('first line') ~= nil)
        assert.is_true(result.input_prefix:find('last') ~= nil)
        assert.is_true(result.input_suffix:find(' line') ~= nil)
      end)

      it('should handle single line buffer', function()
        mock_buffer_lines = {
          'only line',
        }

        local result = fim.build_request({
          bufnr = 0,
          row = 0,
          col = 4,  -- after 'only'
          prefix_lines = 100,
          suffix_lines = 50,
        })

        assert.are.equal('only', result.input_prefix)
        assert.are.equal(' line', result.input_suffix)
      end)

      it('should handle cursor beyond line length', function()
        mock_buffer_lines = {
          'short',
          'next',
        }

        local result = fim.build_request({
          bufnr = 0,
          row = 0,
          col = 100,  -- way past end of line
          prefix_lines = 100,
          suffix_lines = 50,
        })

        -- Should clamp to line length
        assert.are.equal('short', result.input_prefix)
      end)
    end)

    describe('indentation detection', function()
      it('should detect space indentation', function()
        mock_buffer_lines = {
          'function test()',
          '    indented line',
          'end',
        }

        local result = fim.build_request({
          bufnr = 0,
          row = 1,
          col = 10,
          prefix_lines = 100,
          suffix_lines = 50,
        })

        assert.are.equal('    ', result.metadata.indent)
      end)

      it('should detect tab indentation', function()
        mock_buffer_lines = {
          'function test()',
          '\t\tindented',
          'end',
        }

        local result = fim.build_request({
          bufnr = 0,
          row = 1,
          col = 5,
          prefix_lines = 100,
          suffix_lines = 50,
        })

        assert.are.equal('\t\t', result.metadata.indent)
      end)

      it('should return empty string for no indentation', function()
        mock_buffer_lines = {
          'no indent',
        }

        local result = fim.build_request({
          bufnr = 0,
          row = 0,
          col = 2,
          prefix_lines = 100,
          suffix_lines = 50,
        })

        assert.are.equal('', result.metadata.indent)
      end)

      it('should detect mixed indentation', function()
        mock_buffer_lines = {
          'start',
          '  \tmixed',
        }

        local result = fim.build_request({
          bufnr = 0,
          row = 1,
          col = 5,
          prefix_lines = 100,
          suffix_lines = 50,
        })

        assert.are.equal('  \t', result.metadata.indent)
      end)
    end)

    describe('metadata', function()
      it('should include cursor line text', function()
        mock_buffer_lines = {
          'function foo()',
          '  local x = 1',
          'end',
        }

        local result = fim.build_request({
          bufnr = 0,
          row = 1,
          col = 8,
          prefix_lines = 100,
          suffix_lines = 50,
        })

        assert.are.equal('  local x = 1', result.metadata.cursor_line)
      end)

      it('should include filename', function()
        mock_buffer_name = '/path/to/file.lua'

        local result = fim.build_request({
          bufnr = 0,
          row = 0,
          col = 0,
          prefix_lines = 100,
          suffix_lines = 50,
        })

        assert.are.equal('file.lua', result.metadata.filename)
      end)

      it('should include filetype', function()
        mock_filetype = 'python'

        local result = fim.build_request({
          bufnr = 0,
          row = 0,
          col = 0,
          prefix_lines = 100,
          suffix_lines = 50,
        })

        assert.are.equal('python', result.metadata.filetype)
      end)

      it('should handle empty filename', function()
        mock_buffer_name = ''

        local result = fim.build_request({
          bufnr = 0,
          row = 0,
          col = 0,
          prefix_lines = 100,
          suffix_lines = 50,
        })

        assert.are.equal('', result.metadata.filename)
      end)
    end)

    describe('format option', function()
      before_each(function()
        mock_buffer_lines = {
          'prefix code',
          'cursor here',
          'suffix code',
        }
      end)

      it('should default to infill format', function()
        local result = fim.build_request({
          bufnr = 0,
          row = 1,
          col = 6,  -- after 'cursor'
          prefix_lines = 100,
          suffix_lines = 50,
        })

        assert.is_not_nil(result.input_prefix)
        assert.is_not_nil(result.input_suffix)
      end)

      it('should support explicit infill format', function()
        local result = fim.build_request({
          bufnr = 0,
          row = 1,
          col = 6,
          prefix_lines = 100,
          suffix_lines = 50,
          format = 'infill',
        })

        assert.is_not_nil(result.input_prefix)
        assert.is_not_nil(result.input_suffix)
        -- infill format should not have prompt field with tokens
        assert.is_nil(result.prompt)
      end)

      it('should support fim_tokens format with PRE/SUF/MID tokens', function()
        local result = fim.build_request({
          bufnr = 0,
          row = 1,
          col = 6,
          prefix_lines = 100,
          suffix_lines = 50,
          format = 'fim_tokens',
        })

        assert.is_not_nil(result.prompt)
        assert.is_true(result.prompt:find('<PRE>') ~= nil)
        assert.is_true(result.prompt:find('<SUF>') ~= nil)
        assert.is_true(result.prompt:find('<MID>') ~= nil)
      end)

      it('should support custom FIM tokens', function()
        local result = fim.build_request({
          bufnr = 0,
          row = 1,
          col = 6,
          prefix_lines = 100,
          suffix_lines = 50,
          format = 'fim_tokens',
          fim_tokens = {
            prefix = '<|fim_prefix|>',
            suffix = '<|fim_suffix|>',
            middle = '<|fim_middle|>',
          },
        })

        assert.is_not_nil(result.prompt)
        assert.is_true(result.prompt:find('<|fim_prefix|>') ~= nil)
        assert.is_true(result.prompt:find('<|fim_suffix|>') ~= nil)
        assert.is_true(result.prompt:find('<|fim_middle|>') ~= nil)
      end)

      it('should order tokens as PREFIX + prefix_code + SUFFIX + suffix_code + MIDDLE', function()
        local result = fim.build_request({
          bufnr = 0,
          row = 1,
          col = 6,
          prefix_lines = 100,
          suffix_lines = 50,
          format = 'fim_tokens',
        })

        -- Check order: <PRE>...prefix...<SUF>...suffix...<MID>
        local pre_pos = result.prompt:find('<PRE>')
        local suf_pos = result.prompt:find('<SUF>')
        local mid_pos = result.prompt:find('<MID>')

        assert.is_true(pre_pos < suf_pos)
        assert.is_true(suf_pos < mid_pos)
      end)
    end)

    describe('both formats include same content', function()
      it('should have equivalent prefix/suffix content', function()
        mock_buffer_lines = {
          'local x = 1',
          'local y = 2',
          'local z = 3',
        }

        local infill_result = fim.build_request({
          bufnr = 0,
          row = 1,
          col = 6,  -- after 'local '
          prefix_lines = 100,
          suffix_lines = 50,
          format = 'infill',
        })

        local fim_result = fim.build_request({
          bufnr = 0,
          row = 1,
          col = 6,
          prefix_lines = 100,
          suffix_lines = 50,
          format = 'fim_tokens',
        })

        -- Both should extract the same prefix and suffix content
        assert.is_true(fim_result.prompt:find(infill_result.input_prefix, 1, true) ~= nil)
        assert.is_true(fim_result.prompt:find(infill_result.input_suffix, 1, true) ~= nil)
      end)
    end)
  end)
end)
