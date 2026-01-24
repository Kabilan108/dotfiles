-- Tests for sweep.parser module

describe('sweep.parser', function()
  local parser

  before_each(function()
    -- Reset module state before each test
    package.loaded['sweep.parser'] = nil
    parser = require('sweep.parser')
  end)

  describe('parse', function()
    it('should parse valid llama.cpp response correctly', function()
      local response = vim.json.encode({
        content = 'function hello()',
        stop = true,
        tokens_predicted = 45,
        tokens_evaluated = 120,
        timings = {
          prompt_n = 120,
          prompt_ms = 12.5,
          predicted_n = 45,
          predicted_ms = 89.3,
        },
      })

      local result = parser.parse(response, {})

      assert.are.equal('function hello()', result.content)
      assert.are.equal(45, result.tokens_predicted)
      assert.is_true(result.stopped)
    end)

    it('should extract content and split into lines', function()
      local response = vim.json.encode({
        content = 'line1\nline2\nline3',
        stop = true,
        tokens_predicted = 10,
      })

      local result = parser.parse(response, {})

      assert.are.same({ 'line1', 'line2', 'line3' }, result.lines)
    end)

    it('should strip stop tokens from end of content', function()
      local response = vim.json.encode({
        content = 'some code<|endoftext|>',
        stop = true,
        tokens_predicted = 10,
      })

      local result = parser.parse(response, {
        stop_tokens = { '<|endoftext|>', '<|file_sep|>' },
      })

      assert.are.equal('some code', result.content)
      assert.are.equal('stop_token', result.stop_reason)
    end)

    it('should handle multiple stop tokens', function()
      local response = vim.json.encode({
        content = 'code here\n\n\n',
        stop = true,
        tokens_predicted = 10,
      })

      local result = parser.parse(response, {
        stop_tokens = { '<|endoftext|>', '\n\n\n' },
      })

      assert.are.equal('code here', result.content)
    end)

    it('should trim whitespace when option is enabled', function()
      local response = vim.json.encode({
        content = '  hello world  ',
        stop = true,
        tokens_predicted = 5,
      })

      local result = parser.parse(response, {
        trim_whitespace = true,
      })

      assert.are.equal('hello world', result.content)
    end)

    it('should not trim whitespace when option is disabled', function()
      local response = vim.json.encode({
        content = '  hello world  ',
        stop = true,
        tokens_predicted = 5,
      })

      local result = parser.parse(response, {
        trim_whitespace = false,
      })

      assert.are.equal('  hello world  ', result.content)
    end)

    it('should handle missing timings gracefully', function()
      local response = vim.json.encode({
        content = 'test',
        stop = true,
        tokens_predicted = 5,
      })

      local result = parser.parse(response, {})

      assert.is_not_nil(result.timings)
      assert.is_nil(result.timings.prompt_ms)
      assert.is_nil(result.timings.predicted_ms)
      assert.is_nil(result.timings.tokens_per_second)
    end)

    it('should handle malformed JSON', function()
      local response = 'not valid json {'

      local result = parser.parse(response, {})

      assert.are.equal('', result.content)
      assert.are.same({}, result.lines)
      assert.is_false(result.stopped)
      assert.is_not_nil(result.error)
    end)

    it('should respect max_lines limit', function()
      local response = vim.json.encode({
        content = 'line1\nline2\nline3\nline4\nline5',
        stop = true,
        tokens_predicted = 20,
      })

      local result = parser.parse(response, {
        max_lines = 3,
      })

      assert.are.equal(3, #result.lines)
      assert.are.same({ 'line1', 'line2', 'line3' }, result.lines)
      assert.are.equal('line1\nline2\nline3', result.content)
    end)

    it('should calculate tokens_per_second correctly', function()
      local response = vim.json.encode({
        content = 'test',
        stop = true,
        tokens_predicted = 45,
        timings = {
          prompt_ms = 100,
          predicted_n = 45,
          predicted_ms = 300,  -- 300ms for 45 tokens = 150 tok/s
        },
      })

      local result = parser.parse(response, {})

      assert.are.equal(150, result.timings.tokens_per_second)
    end)

    it('should set stop_reason to length when stop is false', function()
      local response = vim.json.encode({
        content = 'partial content',
        stop = false,
        tokens_predicted = 100,
      })

      local result = parser.parse(response, {})

      assert.is_false(result.stopped)
      assert.are.equal('length', result.stop_reason)
    end)

    it('should set stop_reason to eos for natural end of sequence', function()
      local response = vim.json.encode({
        content = 'complete content',
        stop = true,
        tokens_predicted = 10,
      })

      -- No stop tokens in content, but stop is true = eos
      local result = parser.parse(response, {
        stop_tokens = { '<|endoftext|>' },
      })

      assert.is_true(result.stopped)
      assert.are.equal('eos', result.stop_reason)
    end)

    it('should handle empty content', function()
      local response = vim.json.encode({
        content = '',
        stop = true,
        tokens_predicted = 0,
      })

      local result = parser.parse(response, {})

      assert.are.equal('', result.content)
      assert.are.same({ '' }, result.lines)
    end)

    it('should handle missing content field', function()
      local response = vim.json.encode({
        stop = true,
        tokens_predicted = 0,
      })

      local result = parser.parse(response, {})

      assert.are.equal('', result.content)
      assert.are.same({}, result.lines)
    end)
  end)

  describe('first_line', function()
    it('should return only first line', function()
      local result = {
        content = 'first line\nsecond line\nthird line',
        lines = { 'first line', 'second line', 'third line' },
      }

      assert.are.equal('first line', parser.first_line(result))
    end)

    it('should return content when only one line', function()
      local result = {
        content = 'single line',
        lines = { 'single line' },
      }

      assert.are.equal('single line', parser.first_line(result))
    end)

    it('should return empty string for empty result', function()
      local result = {
        content = '',
        lines = {},
      }

      assert.are.equal('', parser.first_line(result))
    end)
  end)

  describe('first_word', function()
    it('should return only first word', function()
      local result = {
        content = 'hello world foo bar',
        lines = { 'hello world foo bar' },
      }

      assert.are.equal('hello', parser.first_word(result))
    end)

    it('should return entire content if single word', function()
      local result = {
        content = 'hello',
        lines = { 'hello' },
      }

      assert.are.equal('hello', parser.first_word(result))
    end)

    it('should return empty string for empty result', function()
      local result = {
        content = '',
        lines = {},
      }

      assert.are.equal('', parser.first_word(result))
    end)

    it('should handle leading whitespace', function()
      local result = {
        content = '  hello world',
        lines = { '  hello world' },
      }

      -- First word should include leading space to maintain indentation
      assert.are.equal('  hello', parser.first_word(result))
    end)

    it('should handle word with special characters', function()
      local result = {
        content = 'function_name(arg)',
        lines = { 'function_name(arg)' },
      }

      -- Word boundary at (
      assert.are.equal('function_name', parser.first_word(result))
    end)
  end)

  describe('is_empty', function()
    it('should return true for whitespace-only content', function()
      local result = {
        content = '   \n\t  \n  ',
        lines = { '   ', '\t  ', '  ' },
      }

      assert.is_true(parser.is_empty(result))
    end)

    it('should return true for empty content', function()
      local result = {
        content = '',
        lines = {},
      }

      assert.is_true(parser.is_empty(result))
    end)

    it('should return false for content with text', function()
      local result = {
        content = 'hello',
        lines = { 'hello' },
      }

      assert.is_false(parser.is_empty(result))
    end)

    it('should return false for content with leading whitespace and text', function()
      local result = {
        content = '  hello  ',
        lines = { '  hello  ' },
      }

      assert.is_false(parser.is_empty(result))
    end)
  end)
end)
