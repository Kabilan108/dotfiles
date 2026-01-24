-- Tests for sweep.keymaps module

describe('sweep.keymaps', function()
  local keymaps
  local config
  local mock_completion
  local mock_ui
  local test_bufnr

  -- Store original keymaps for restoration
  local original_mappings = {}

  -- Helper to check if a keymap exists
  local function keymap_exists(mode, lhs, bufnr)
    local maps = vim.api.nvim_buf_get_keymap(bufnr, mode)
    for _, map in ipairs(maps) do
      if map.lhs == lhs then
        return true
      end
    end
    return false
  end

  -- Helper to get keymap callback
  local function get_keymap(mode, lhs, bufnr)
    local maps = vim.api.nvim_buf_get_keymap(bufnr, mode)
    for _, map in ipairs(maps) do
      if map.lhs == lhs then
        return map
      end
    end
    return nil
  end

  before_each(function()
    -- Reset module state before each test
    package.loaded['sweep.keymaps'] = nil
    package.loaded['sweep.config'] = nil
    package.loaded['sweep.completion'] = nil
    package.loaded['sweep.ui'] = nil

    -- Setup config with test keymaps
    config = require('sweep.config')
    config.setup({
      keymaps = {
        trigger = '<C-Space>',
        accept_full = '<Tab>',
        accept_line = '<C-l>',
        accept_word = '<C-Right>',
        dismiss = '<C-]>',
      },
    })

    -- Create mock completion module
    mock_completion = {
      _manual_trigger_called = false,
      _accept_full_called = false,
      _accept_line_called = false,
      _accept_word_called = false,
      _dismiss_called = false,
      manual_trigger = function()
        mock_completion._manual_trigger_called = true
      end,
      accept_full = function()
        mock_completion._accept_full_called = true
      end,
      accept_line = function()
        mock_completion._accept_line_called = true
      end,
      accept_word = function()
        mock_completion._accept_word_called = true
      end,
      dismiss = function()
        mock_completion._dismiss_called = true
      end,
    }

    -- Create mock ui module
    mock_ui = {
      _visible = false,
      is_visible = function()
        return mock_ui._visible
      end,
    }

    -- Inject mocks
    package.loaded['sweep.completion'] = mock_completion
    package.loaded['sweep.ui'] = mock_ui

    -- Create a test buffer
    test_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, {
      'function hello()',
      '  print("world")',
      'end',
    })
    vim.api.nvim_set_current_buf(test_bufnr)

    keymaps = require('sweep.keymaps')
  end)

  after_each(function()
    -- Teardown keymaps
    pcall(function()
      keymaps.teardown()
    end)

    -- Clean up test buffer
    if vim.api.nvim_buf_is_valid(test_bufnr) then
      vim.api.nvim_buf_delete(test_bufnr, { force = true })
    end

    -- Reset package.loaded
    package.loaded['sweep.keymaps'] = nil
    package.loaded['sweep.completion'] = nil
    package.loaded['sweep.ui'] = nil
  end)

  describe('setup', function()
    it('should create keymaps for all configured keys', function()
      keymaps.setup()

      -- Check that keymaps were created (buffer-local)
      assert.is_true(keymap_exists('i', '<C-Space>', test_bufnr))
      assert.is_true(keymap_exists('i', '<Tab>', test_bufnr))
      assert.is_true(keymap_exists('i', '<C-l>', test_bufnr))
      assert.is_true(keymap_exists('i', '<C-Right>', test_bufnr))
      assert.is_true(keymap_exists('i', '<C-]>', test_bufnr))
    end)

    it('should use insert mode for all keymaps', function()
      keymaps.setup()

      -- All keymaps should be in insert mode
      local cfg = config.get()
      for name, key in pairs(cfg.keymaps) do
        local map = get_keymap('i', key, test_bufnr)
        assert.is_not_nil(map, 'Keymap for ' .. name .. ' (' .. key .. ') should exist')
      end
    end)

    it('should respect custom config keymaps', function()
      -- Update config with custom keymaps
      package.loaded['sweep.keymaps'] = nil
      config.setup({
        keymaps = {
          trigger = '<C-c>',
          accept_full = '<C-s>',
          accept_line = '<C-y>',
          accept_word = '<C-w>',
          dismiss = '<C-e>',
        },
      })

      keymaps = require('sweep.keymaps')
      keymaps.setup()

      -- Check custom keymaps exist
      assert.is_true(keymap_exists('i', '<C-c>', test_bufnr))
      assert.is_true(keymap_exists('i', '<C-s>', test_bufnr))
      assert.is_true(keymap_exists('i', '<C-y>', test_bufnr))
      assert.is_true(keymap_exists('i', '<C-w>', test_bufnr))
      assert.is_true(keymap_exists('i', '<C-e>', test_bufnr))
    end)

    it('should be idempotent (multiple calls are safe)', function()
      keymaps.setup()
      keymaps.setup()
      keymaps.setup()

      -- Should still work with keymaps in place
      assert.is_true(keymap_exists('i', '<Tab>', test_bufnr))
    end)
  end)

  describe('teardown', function()
    it('should remove all keymaps', function()
      keymaps.setup()

      -- Verify keymaps exist first
      assert.is_true(keymap_exists('i', '<Tab>', test_bufnr))

      keymaps.teardown()

      -- Keymaps should be removed
      assert.is_false(keymap_exists('i', '<Tab>', test_bufnr))
      assert.is_false(keymap_exists('i', '<C-Space>', test_bufnr))
      assert.is_false(keymap_exists('i', '<C-l>', test_bufnr))
      assert.is_false(keymap_exists('i', '<C-Right>', test_bufnr))
      assert.is_false(keymap_exists('i', '<C-]>', test_bufnr))
    end)

    it('should be safe to call without prior setup', function()
      assert.has_no.errors(function()
        keymaps.teardown()
      end)
    end)

    it('should be safe to call multiple times', function()
      keymaps.setup()
      keymaps.teardown()
      keymaps.teardown()
      keymaps.teardown()
      -- No errors should occur
    end)
  end)

  describe('trigger keymap', function()
    it('should call completion.manual_trigger', function()
      keymaps.setup()

      -- Simulate pressing the trigger key by finding and executing the callback
      local map = get_keymap('i', '<C-Space>', test_bufnr)
      assert.is_not_nil(map)

      -- For expr mappings, we need to call the callback
      if map.callback then
        map.callback()
      end

      assert.is_true(mock_completion._manual_trigger_called)
    end)
  end)

  describe('accept_full keymap', function()
    it('should call completion.accept_full when visible', function()
      keymaps.setup()
      mock_ui._visible = true

      local map = get_keymap('i', '<Tab>', test_bufnr)
      assert.is_not_nil(map)

      if map.callback then
        map.callback()
      end

      assert.is_true(mock_completion._accept_full_called)
    end)

    it('should pass through key when not visible', function()
      keymaps.setup()
      mock_ui._visible = false

      local map = get_keymap('i', '<Tab>', test_bufnr)
      assert.is_not_nil(map)

      -- For expr mappings, should return the original key when not visible
      if map.callback and map.expr then
        local result = map.callback()
        -- Should return the key to pass through
        assert.is_not_nil(result)
        assert.is_truthy(result:match('Tab') or result == '\t')
      end

      -- Should NOT call accept_full when not visible
      assert.is_false(mock_completion._accept_full_called)
    end)
  end)

  describe('accept_line keymap', function()
    it('should call completion.accept_line when visible', function()
      keymaps.setup()
      mock_ui._visible = true

      local map = get_keymap('i', '<C-l>', test_bufnr)
      assert.is_not_nil(map)

      if map.callback then
        map.callback()
      end

      assert.is_true(mock_completion._accept_line_called)
    end)

    it('should pass through key when not visible', function()
      keymaps.setup()
      mock_ui._visible = false

      local map = get_keymap('i', '<C-l>', test_bufnr)
      assert.is_not_nil(map)

      if map.callback and map.expr then
        local result = map.callback()
        assert.is_not_nil(result)
      end

      assert.is_false(mock_completion._accept_line_called)
    end)
  end)

  describe('accept_word keymap', function()
    it('should call completion.accept_word when visible', function()
      keymaps.setup()
      mock_ui._visible = true

      local map = get_keymap('i', '<C-Right>', test_bufnr)
      assert.is_not_nil(map)

      if map.callback then
        map.callback()
      end

      assert.is_true(mock_completion._accept_word_called)
    end)

    it('should pass through key when not visible', function()
      keymaps.setup()
      mock_ui._visible = false

      local map = get_keymap('i', '<C-Right>', test_bufnr)
      assert.is_not_nil(map)

      if map.callback and map.expr then
        local result = map.callback()
        assert.is_not_nil(result)
      end

      assert.is_false(mock_completion._accept_word_called)
    end)
  end)

  describe('dismiss keymap', function()
    it('should call completion.dismiss when visible', function()
      keymaps.setup()
      mock_ui._visible = true

      local map = get_keymap('i', '<C-]>', test_bufnr)
      assert.is_not_nil(map)

      if map.callback then
        map.callback()
      end

      assert.is_true(mock_completion._dismiss_called)
    end)

    it('should pass through key when not visible', function()
      keymaps.setup()
      mock_ui._visible = false

      local map = get_keymap('i', '<C-]>', test_bufnr)
      assert.is_not_nil(map)

      if map.callback and map.expr then
        local result = map.callback()
        assert.is_not_nil(result)
      end

      assert.is_false(mock_completion._dismiss_called)
    end)
  end)

  describe('expr mappings', function()
    it('should use expr option for conditional keymaps', function()
      keymaps.setup()

      -- accept_full, accept_line, accept_word, dismiss should be expr mappings
      local accept_full_map = get_keymap('i', '<Tab>', test_bufnr)
      local accept_line_map = get_keymap('i', '<C-l>', test_bufnr)
      local accept_word_map = get_keymap('i', '<C-Right>', test_bufnr)
      local dismiss_map = get_keymap('i', '<C-]>', test_bufnr)

      -- These should have expr = 1 (true)
      assert.are.equal(1, accept_full_map.expr)
      assert.are.equal(1, accept_line_map.expr)
      assert.are.equal(1, accept_word_map.expr)
      assert.are.equal(1, dismiss_map.expr)
    end)

    it('should return empty string when action is taken', function()
      keymaps.setup()
      mock_ui._visible = true

      local map = get_keymap('i', '<Tab>', test_bufnr)
      if map.callback and map.expr then
        local result = map.callback()
        assert.are.equal('', result)
      end
    end)
  end)

  describe('buffer-local keymaps', function()
    it('should set keymaps on current buffer', function()
      keymaps.setup()

      -- Keymaps should exist on test buffer
      assert.is_true(keymap_exists('i', '<Tab>', test_bufnr))

      -- Create another buffer and check keymaps don't exist there
      local other_bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(other_bufnr)

      -- Need to set up for this buffer too
      assert.is_false(keymap_exists('i', '<Tab>', other_bufnr))

      -- Clean up
      vim.api.nvim_set_current_buf(test_bufnr)
      vim.api.nvim_buf_delete(other_bufnr, { force = true })
    end)
  end)

  describe('state tracking', function()
    it('should track setup state', function()
      assert.is_false(keymaps.is_setup())

      keymaps.setup()
      assert.is_true(keymaps.is_setup())

      keymaps.teardown()
      assert.is_false(keymaps.is_setup())
    end)
  end)
end)
