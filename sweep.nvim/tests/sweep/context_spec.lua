-- Tests for sweep.context module (LSP and treesitter context extraction)

describe('sweep.context', function()
  local context

  -- Mock data for tests
  local mock_buffer_lines = {}
  local mock_buffer_name = 'test.lua'
  local mock_filetype = 'lua'
  local mock_lsp_clients = {}
  local mock_treesitter_available = true
  local mock_treesitter_parser = nil
  local mock_node_at_cursor = nil
  local mock_lsp_responses = {}

  -- Save original vim functions
  local original_nvim_buf_get_lines
  local original_nvim_buf_get_name
  local original_nvim_get_option_value
  local original_lsp_get_clients
  local original_lsp_buf_request
  local original_treesitter_get_parser
  local original_treesitter_get_node

  before_each(function()
    -- Reset module state before each test
    package.loaded['sweep.context'] = nil
    package.loaded['sweep.config'] = nil

    -- Setup config with defaults
    local config = require('sweep.config')
    config.setup()

    -- Save originals
    original_nvim_buf_get_lines = vim.api.nvim_buf_get_lines
    original_nvim_buf_get_name = vim.api.nvim_buf_get_name
    original_nvim_get_option_value = vim.api.nvim_get_option_value
    original_lsp_get_clients = vim.lsp.get_clients
    original_lsp_buf_request = vim.lsp.buf_request
    original_treesitter_get_parser = vim.treesitter.get_parser
    original_treesitter_get_node = vim.treesitter.get_node

    -- Mock vim.api.nvim_buf_get_lines
    vim.api.nvim_buf_get_lines = function(bufnr, start_row, end_row, strict_indexing)
      local result = {}
      local actual_end = end_row == -1 and #mock_buffer_lines or end_row
      for i = start_row + 1, math.min(actual_end, #mock_buffer_lines) do
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

    -- Mock vim.lsp.get_clients
    vim.lsp.get_clients = function(opts)
      return mock_lsp_clients
    end

    -- Mock vim.lsp.buf_request
    vim.lsp.buf_request = function(bufnr, method, params, callback)
      local response = mock_lsp_responses[method]
      if response then
        -- Simulate async callback
        vim.schedule(function()
          callback(nil, response, { client_id = 1 })
        end)
        return true, 1
      end
      return false, nil
    end

    -- Mock vim.treesitter.get_parser
    vim.treesitter.get_parser = function(bufnr, lang)
      if not mock_treesitter_available then
        error('No parser available')
      end
      return mock_treesitter_parser
    end

    -- Mock vim.treesitter.get_node
    vim.treesitter.get_node = function(opts)
      return mock_node_at_cursor
    end

    -- Reset mock data
    mock_buffer_lines = {}
    mock_buffer_name = 'test.lua'
    mock_filetype = 'lua'
    mock_lsp_clients = {}
    mock_treesitter_available = true
    mock_treesitter_parser = nil
    mock_node_at_cursor = nil
    mock_lsp_responses = {}

    context = require('sweep.context')
  end)

  after_each(function()
    -- Restore originals
    vim.api.nvim_buf_get_lines = original_nvim_buf_get_lines
    vim.api.nvim_buf_get_name = original_nvim_buf_get_name
    vim.api.nvim_get_option_value = original_nvim_get_option_value
    vim.lsp.get_clients = original_lsp_get_clients
    vim.lsp.buf_request = original_lsp_buf_request
    vim.treesitter.get_parser = original_treesitter_get_parser
    vim.treesitter.get_node = original_treesitter_get_node
  end)

  describe('get_scope', function()
    -- Helper to create mock treesitter nodes
    local function create_mock_node(node_type, name, start_row, end_row, parent)
      local node = {
        type = function() return node_type end,
        start = function() return start_row, 0, 0 end,
        end_ = function() return end_row, 0, 0 end,
        parent = function() return parent end,
        -- For named child to get function name
        field = function(self, field_name)
          if field_name == 'name' then
            return { {
              type = function() return 'identifier' end,
              -- Mock getting text via treesitter query
              _name = name,
            } }
          end
          return {}
        end,
      }
      return node
    end

    it('should return nil when treesitter is not available', function()
      mock_treesitter_available = false

      local scope = context.get_scope(0, 5)
      assert.is_nil(scope)
    end)

    it('should return nil when no node at cursor', function()
      mock_treesitter_available = true
      mock_node_at_cursor = nil

      local scope = context.get_scope(0, 5)
      assert.is_nil(scope)
    end)

    it('should find enclosing function in Lua', function()
      mock_filetype = 'lua'
      mock_buffer_lines = {
        'local M = {}',
        '',
        'function M.hello(name)',
        '  local greeting = "Hello"',
        '  return greeting .. name',
        'end',
        '',
        'return M',
      }

      -- Create a node structure: identifier -> local_declaration -> function_declaration
      local func_node = create_mock_node('function_declaration', 'M.hello', 2, 5, nil)
      local inner_node = create_mock_node('identifier', nil, 3, 3, func_node)
      mock_node_at_cursor = inner_node

      local scope = context.get_scope(0, 3)

      assert.is_not_nil(scope)
      assert.are.equal('function', scope.type)
      assert.are.equal(2, scope.range.start_row)
      assert.are.equal(5, scope.range.end_row)
    end)

    it('should find enclosing method in Lua', function()
      mock_filetype = 'lua'
      mock_buffer_lines = {
        'local MyClass = {}',
        '',
        'function MyClass:init()',
        '  self.value = 0',
        'end',
      }

      local method_node = create_mock_node('function_declaration', 'MyClass:init', 2, 4, nil)
      local inner_node = create_mock_node('assignment_statement', nil, 3, 3, method_node)
      mock_node_at_cursor = inner_node

      local scope = context.get_scope(0, 3)

      assert.is_not_nil(scope)
      assert.are.equal('function', scope.type)
    end)

    it('should return scope content', function()
      mock_filetype = 'lua'
      mock_buffer_lines = {
        'function test()',
        '  local x = 1',
        '  return x',
        'end',
      }

      local func_node = create_mock_node('function_declaration', 'test', 0, 3, nil)
      local inner_node = create_mock_node('identifier', nil, 1, 1, func_node)
      mock_node_at_cursor = inner_node

      local scope = context.get_scope(0, 1)

      assert.is_not_nil(scope)
      assert.is_not_nil(scope.content)
      assert.is_true(scope.content:find('function test') ~= nil)
      assert.is_true(scope.content:find('return x') ~= nil)
    end)

    it('should limit scope content to max lines', function()
      mock_filetype = 'lua'
      -- Create a very long function
      mock_buffer_lines = { 'function long()' }
      for i = 1, 100 do
        table.insert(mock_buffer_lines, '  line ' .. i)
      end
      table.insert(mock_buffer_lines, 'end')

      local func_node = create_mock_node('function_declaration', 'long', 0, #mock_buffer_lines - 1, nil)
      local inner_node = create_mock_node('identifier', nil, 50, 50, func_node)
      mock_node_at_cursor = inner_node

      local scope = context.get_scope(0, 50, { max_lines = 50 })

      assert.is_not_nil(scope)
      -- Content should be truncated
      local line_count = select(2, scope.content:gsub('\n', '\n')) + 1
      assert.is_true(line_count <= 50)
    end)
  end)

  describe('get_imports', function()
    it('should extract require statements from Lua files', function()
      mock_filetype = 'lua'
      mock_buffer_lines = {
        'local utils = require("utils")',
        'local http = require("sweep.http")',
        '',
        'local M = {}',
        '',
        'function M.test()',
        '  local inner = require("inner")', -- should not be extracted (not at top)
        'end',
        '',
        'return M',
      }

      local imports = context.get_imports(0)

      assert.is_not_nil(imports)
      assert.are.equal(2, #imports)
      assert.is_true(imports[1]:find('require%("utils"%)') ~= nil)
      assert.is_true(imports[2]:find('require%("sweep.http"%)') ~= nil)
    end)

    it('should extract import statements from Python files', function()
      mock_filetype = 'python'
      mock_buffer_lines = {
        'import os',
        'import sys',
        'from typing import List, Dict',
        'from dataclasses import dataclass',
        '',
        'class MyClass:',
        '    pass',
      }

      local imports = context.get_imports(0)

      assert.is_not_nil(imports)
      assert.is_true(#imports >= 2)
    end)

    it('should return empty array when no imports', function()
      mock_filetype = 'lua'
      mock_buffer_lines = {
        'local M = {}',
        '',
        'function M.test()',
        '  return 1',
        'end',
        '',
        'return M',
      }

      local imports = context.get_imports(0)

      assert.is_not_nil(imports)
      assert.are.equal(0, #imports)
    end)

    it('should handle empty buffer', function()
      mock_filetype = 'lua'
      mock_buffer_lines = {}

      local imports = context.get_imports(0)

      assert.is_not_nil(imports)
      assert.are.equal(0, #imports)
    end)

    it('should limit import extraction to first N lines', function()
      mock_filetype = 'lua'
      mock_buffer_lines = {}
      -- Create many require statements
      for i = 1, 100 do
        table.insert(mock_buffer_lines, string.format('local mod%d = require("mod%d")', i, i))
      end

      local imports = context.get_imports(0, { max_lines = 30 })

      -- Should only scan first 30 lines
      assert.is_true(#imports <= 30)
    end)
  end)

  describe('get_definitions', function()
    it('should call callback with empty array when no LSP clients', function()
      mock_lsp_clients = {}
      local callback_called = false
      local received_definitions = nil

      context.get_definitions({
        bufnr = 0,
        row = 5,
        col = 10,
      }, function(definitions)
        callback_called = true
        received_definitions = definitions
      end)

      -- Since no LSP, callback should be called synchronously with empty array
      assert.is_true(callback_called)
      assert.is_not_nil(received_definitions)
      assert.are.equal(0, #received_definitions)
    end)

    it('should request definitions from LSP', function()
      mock_lsp_clients = {
        { id = 1, name = 'lua_ls' },
      }
      mock_lsp_responses['textDocument/definition'] = {
        {
          uri = 'file:///path/to/file.lua',
          range = {
            start = { line = 10, character = 0 },
            ['end'] = { line = 20, character = 0 },
          },
        },
      }

      local callback_called = false
      context.get_definitions({
        bufnr = 0,
        row = 5,
        col = 10,
      }, function(definitions)
        callback_called = true
      end)

      -- Wait for async callback
      vim.wait(100, function() return callback_called end)
      assert.is_true(callback_called)
    end)

    it('should handle LSP errors gracefully', function()
      mock_lsp_clients = {
        { id = 1, name = 'lua_ls' },
      }

      -- Override buf_request to simulate error
      vim.lsp.buf_request = function(bufnr, method, params, callback)
        vim.schedule(function()
          callback('LSP Error', nil, { client_id = 1 })
        end)
        return true, 1
      end

      local callback_called = false
      local received_definitions = nil

      context.get_definitions({
        bufnr = 0,
        row = 5,
        col = 10,
      }, function(definitions)
        callback_called = true
        received_definitions = definitions
      end)

      vim.wait(100, function() return callback_called end)
      assert.is_true(callback_called)
      assert.is_not_nil(received_definitions)
      -- Should return empty on error, not crash
      assert.are.equal(0, #received_definitions)
    end)
  end)

  describe('get', function()
    it('should return context object with all fields', function()
      mock_buffer_lines = {
        'local utils = require("utils")',
        '',
        'local function test()',
        '  local x = 1',
        'end',
      }
      mock_lsp_clients = {}
      mock_treesitter_available = false

      local ctx = context.get({
        bufnr = 0,
        row = 3,
        col = 5,
        use_lsp = false,
        use_treesitter = false,
      })

      assert.is_not_nil(ctx)
      assert.is_not_nil(ctx.definitions)
      assert.is_not_nil(ctx.imports)
      assert.is_not_nil(ctx.formatted)
    end)

    it('should include imports in context', function()
      mock_filetype = 'lua'
      mock_buffer_lines = {
        'local utils = require("utils")',
        'local http = require("http")',
        '',
        'local M = {}',
        'return M',
      }

      local ctx = context.get({
        bufnr = 0,
        row = 3,
        col = 0,
        use_lsp = false,
        use_treesitter = false,
      })

      assert.is_not_nil(ctx.imports)
      assert.are.equal(2, #ctx.imports)
    end)

    it('should handle missing LSP gracefully', function()
      mock_lsp_clients = {}

      local ctx = context.get({
        bufnr = 0,
        row = 5,
        col = 10,
        use_lsp = true,
        use_treesitter = false,
      })

      assert.is_not_nil(ctx)
      assert.is_not_nil(ctx.definitions)
      assert.are.equal(0, #ctx.definitions)
    end)

    it('should handle missing treesitter gracefully', function()
      mock_treesitter_available = false

      local ctx = context.get({
        bufnr = 0,
        row = 5,
        col = 10,
        use_lsp = false,
        use_treesitter = true,
      })

      assert.is_not_nil(ctx)
      assert.is_nil(ctx.scope)
    end)

    it('should skip LSP when use_lsp is false', function()
      mock_lsp_clients = {
        { id = 1, name = 'lua_ls' },
      }
      local lsp_called = false
      vim.lsp.buf_request = function(...)
        lsp_called = true
        return false, nil
      end

      context.get({
        bufnr = 0,
        row = 5,
        col = 10,
        use_lsp = false,
        use_treesitter = false,
      })

      assert.is_false(lsp_called)
    end)

    it('should skip treesitter when use_treesitter is false', function()
      local ts_called = false
      vim.treesitter.get_node = function(...)
        ts_called = true
        return nil
      end

      context.get({
        bufnr = 0,
        row = 5,
        col = 10,
        use_lsp = false,
        use_treesitter = false,
      })

      assert.is_false(ts_called)
    end)
  end)

  describe('formatted output', function()
    it('should have section markers', function()
      mock_filetype = 'lua'
      mock_buffer_lines = {
        'local utils = require("utils")',
        '',
        'local M = {}',
        'return M',
      }

      local ctx = context.get({
        bufnr = 0,
        row = 2,
        col = 0,
        use_lsp = false,
        use_treesitter = false,
      })

      assert.is_not_nil(ctx.formatted)
      -- Should have import section when imports exist
      if #ctx.imports > 0 then
        assert.is_true(ctx.formatted:find('Imports') ~= nil or ctx.formatted:find('imports') ~= nil)
      end
    end)

    it('should include scope section when scope is found', function()
      mock_filetype = 'lua'
      mock_buffer_lines = {
        'function test()',
        '  local x = 1',
        '  return x',
        'end',
      }

      -- Create mock scope result
      local func_node = {
        type = function() return 'function_declaration' end,
        start = function() return 0, 0, 0 end,
        end_ = function() return 3, 0, 0 end,
        parent = function() return nil end,
        field = function() return {} end,
      }
      local inner_node = {
        type = function() return 'identifier' end,
        start = function() return 1, 0, 0 end,
        end_ = function() return 1, 0, 0 end,
        parent = function() return func_node end,
        field = function() return {} end,
      }
      mock_node_at_cursor = inner_node

      local ctx = context.get({
        bufnr = 0,
        row = 1,
        col = 5,
        use_lsp = false,
        use_treesitter = true,
      })

      if ctx.scope then
        assert.is_true(ctx.formatted:find('scope') ~= nil or ctx.formatted:find('Scope') ~= nil or ctx.formatted:find('function') ~= nil)
      end
    end)

    it('should keep total formatted output under limit', function()
      mock_filetype = 'lua'
      -- Create lots of imports
      mock_buffer_lines = {}
      for i = 1, 50 do
        table.insert(mock_buffer_lines, string.format('local mod%d = require("module%d")', i, i))
      end
      table.insert(mock_buffer_lines, '')
      table.insert(mock_buffer_lines, 'local M = {}')
      table.insert(mock_buffer_lines, 'return M')

      local ctx = context.get({
        bufnr = 0,
        row = 51,
        col = 0,
        use_lsp = false,
        use_treesitter = false,
        max_formatted_lines = 100,
      })

      assert.is_not_nil(ctx.formatted)
      local line_count = select(2, ctx.formatted:gsub('\n', '\n')) + 1
      -- Should respect the limit (allowing some margin for headers)
      assert.is_true(line_count <= 150)
    end)
  end)

  describe('content truncation', function()
    it('should truncate long definitions', function()
      -- This tests that definition content is limited
      mock_lsp_clients = {
        { id = 1, name = 'lua_ls' },
      }

      -- Mock a very long definition response
      mock_lsp_responses['textDocument/definition'] = {
        {
          uri = 'file:///path/to/file.lua',
          range = {
            start = { line = 0, character = 0 },
            ['end'] = { line = 100, character = 0 },
          },
        },
      }

      -- The implementation should truncate to max_definition_lines
      -- This is tested indirectly through the formatted output
      local callback_called = false
      context.get_definitions({
        bufnr = 0,
        row = 5,
        col = 10,
        max_lines = 50,
      }, function(definitions)
        callback_called = true
        -- Definitions should be returned (possibly truncated)
      end)

      vim.wait(100, function() return callback_called end)
      assert.is_true(callback_called)
    end)
  end)

  describe('language support', function()
    describe('Lua files', function()
      it('should recognize Lua require patterns', function()
        mock_filetype = 'lua'
        mock_buffer_lines = {
          'local a = require("module_a")',
          "local b = require('module_b')",
          'local c = require "module_c"',
          '',
          'return {}',
        }

        local imports = context.get_imports(0)

        assert.are.equal(3, #imports)
      end)
    end)

    describe('Python files', function()
      it('should recognize Python import patterns', function()
        mock_filetype = 'python'
        mock_buffer_lines = {
          'import os',
          'import sys',
          'from pathlib import Path',
          'from typing import List, Optional',
          '',
          'def main():',
          '    pass',
        }

        local imports = context.get_imports(0)

        assert.is_true(#imports >= 4)
      end)
    end)

    describe('JavaScript/TypeScript files', function()
      it('should recognize JS import patterns', function()
        mock_filetype = 'javascript'
        mock_buffer_lines = {
          "import React from 'react';",
          "import { useState } from 'react';",
          "const fs = require('fs');",
          '',
          'function App() {}',
        }

        local imports = context.get_imports(0)

        assert.is_true(#imports >= 2)
      end)
    end)
  end)

  describe('edge cases', function()
    it('should handle buffer 0 (current buffer)', function()
      mock_buffer_lines = { 'local M = {}', 'return M' }

      local ctx = context.get({
        bufnr = 0,
        row = 0,
        col = 0,
        use_lsp = false,
        use_treesitter = false,
      })

      assert.is_not_nil(ctx)
    end)

    it('should handle cursor at file start', function()
      mock_buffer_lines = { 'first line', 'second line' }

      local ctx = context.get({
        bufnr = 0,
        row = 0,
        col = 0,
        use_lsp = false,
        use_treesitter = false,
      })

      assert.is_not_nil(ctx)
    end)

    it('should handle cursor at file end', function()
      mock_buffer_lines = { 'first line', 'last line' }

      local ctx = context.get({
        bufnr = 0,
        row = 1,
        col = 9,
        use_lsp = false,
        use_treesitter = false,
      })

      assert.is_not_nil(ctx)
    end)

    it('should handle empty buffer', function()
      mock_buffer_lines = {}

      local ctx = context.get({
        bufnr = 0,
        row = 0,
        col = 0,
        use_lsp = false,
        use_treesitter = false,
      })

      assert.is_not_nil(ctx)
      assert.are.equal(0, #ctx.imports)
    end)
  end)
end)
