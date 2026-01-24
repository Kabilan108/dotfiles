-- Tests for sweep.cache module (LRU cache for completion results)

describe('sweep.cache', function()
  local cache

  before_each(function()
    -- Reset module state before each test
    package.loaded['sweep.cache'] = nil
    cache = require('sweep.cache')
    cache.setup({
      max_entries = 5,
      ttl_ms = 0, -- No expiry by default for most tests
    })
  end)

  describe('setup', function()
    it('should initialize with given options', function()
      cache.setup({
        max_entries = 100,
        ttl_ms = 60000,
      })
      local stats = cache.stats()
      assert.are.equal(0, stats.entries)
      assert.are.equal(0, stats.hits)
      assert.are.equal(0, stats.misses)
      assert.are.equal(0, stats.evictions)
    end)

    it('should use default options when none provided', function()
      package.loaded['sweep.cache'] = nil
      cache = require('sweep.cache')
      cache.setup()
      local stats = cache.stats()
      assert.are.equal(0, stats.entries)
    end)
  end)

  describe('set and get', function()
    it('should store value retrievable by get', function()
      cache.set('key1', { completion = 'hello world' })
      local value = cache.get('key1')
      assert.is_not_nil(value)
      assert.are.equal('hello world', value.completion)
    end)

    it('should return nil for missing key', function()
      local value = cache.get('nonexistent')
      assert.is_nil(value)
    end)

    it('should overwrite existing key with new value', function()
      cache.set('key1', { value = 'first' })
      cache.set('key1', { value = 'second' })
      local value = cache.get('key1')
      assert.are.equal('second', value.value)
    end)

    it('should store multiple different keys', function()
      cache.set('key1', 'value1')
      cache.set('key2', 'value2')
      cache.set('key3', 'value3')

      assert.are.equal('value1', cache.get('key1'))
      assert.are.equal('value2', cache.get('key2'))
      assert.are.equal('value3', cache.get('key3'))
    end)
  end)

  describe('LRU eviction', function()
    it('should evict least recently used entry when max_entries exceeded', function()
      -- max_entries is 5
      cache.set('key1', 'value1')
      cache.set('key2', 'value2')
      cache.set('key3', 'value3')
      cache.set('key4', 'value4')
      cache.set('key5', 'value5')

      -- Cache is now full, add one more
      cache.set('key6', 'value6')

      -- key1 should be evicted (least recently used)
      assert.is_nil(cache.get('key1'))
      -- key6 should exist
      assert.are.equal('value6', cache.get('key6'))

      local stats = cache.stats()
      assert.are.equal(5, stats.entries)
      assert.are.equal(1, stats.evictions)
    end)

    it('should update recency on get', function()
      cache.set('key1', 'value1')
      cache.set('key2', 'value2')
      cache.set('key3', 'value3')
      cache.set('key4', 'value4')
      cache.set('key5', 'value5')

      -- Access key1 to make it recently used
      cache.get('key1')

      -- Add new entries to trigger evictions
      cache.set('key6', 'value6')

      -- key1 should still exist (was recently accessed)
      assert.is_not_nil(cache.get('key1'))
      -- key2 should be evicted (was least recently used)
      assert.is_nil(cache.get('key2'))
    end)

    it('should update recency on set of existing key', function()
      cache.set('key1', 'value1')
      cache.set('key2', 'value2')
      cache.set('key3', 'value3')
      cache.set('key4', 'value4')
      cache.set('key5', 'value5')

      -- Update key1 to make it recently used
      cache.set('key1', 'updated')

      -- Add new entry to trigger eviction
      cache.set('key6', 'value6')

      -- key1 should still exist (was recently updated)
      assert.are.equal('updated', cache.get('key1'))
      -- key2 should be evicted
      assert.is_nil(cache.get('key2'))
    end)

    it('should track multiple evictions', function()
      cache.set('key1', 'value1')
      cache.set('key2', 'value2')
      cache.set('key3', 'value3')
      cache.set('key4', 'value4')
      cache.set('key5', 'value5')

      -- Add 3 more entries
      cache.set('key6', 'value6')
      cache.set('key7', 'value7')
      cache.set('key8', 'value8')

      local stats = cache.stats()
      assert.are.equal(3, stats.evictions)
    end)
  end)

  describe('TTL expiration', function()
    it('should return nil for expired entry', function()
      cache.setup({
        max_entries = 100,
        ttl_ms = 50, -- 50ms TTL
      })

      cache.set('key1', 'value1')

      -- Wait for expiration
      vim.wait(100, function() return false end)

      -- Should be expired
      local value = cache.get('key1')
      assert.is_nil(value)
    end)

    it('should return value for non-expired entry', function()
      cache.setup({
        max_entries = 100,
        ttl_ms = 5000, -- 5 second TTL
      })

      cache.set('key1', 'value1')
      local value = cache.get('key1')
      assert.are.equal('value1', value)
    end)

    it('should not expire when ttl_ms is 0', function()
      cache.setup({
        max_entries = 100,
        ttl_ms = 0, -- No expiry
      })

      cache.set('key1', 'value1')

      -- Wait a bit
      vim.wait(50, function() return false end)

      -- Should still be available
      local value = cache.get('key1')
      assert.are.equal('value1', value)
    end)

    it('should count expired entries as misses', function()
      cache.setup({
        max_entries = 100,
        ttl_ms = 50,
      })

      cache.set('key1', 'value1')
      cache.get('key1') -- hit

      vim.wait(100, function() return false end)

      cache.get('key1') -- miss (expired)

      local stats = cache.stats()
      assert.are.equal(1, stats.hits)
      assert.are.equal(1, stats.misses)
    end)
  end)

  describe('has', function()
    it('should return true for existing key', function()
      cache.set('key1', 'value1')
      assert.is_true(cache.has('key1'))
    end)

    it('should return false for missing key', function()
      assert.is_false(cache.has('nonexistent'))
    end)

    it('should return false for expired key', function()
      cache.setup({
        max_entries = 100,
        ttl_ms = 50,
      })

      cache.set('key1', 'value1')

      vim.wait(100, function() return false end)

      assert.is_false(cache.has('key1'))
    end)

    it('should not update recency', function()
      cache.set('key1', 'value1')
      cache.set('key2', 'value2')
      cache.set('key3', 'value3')
      cache.set('key4', 'value4')
      cache.set('key5', 'value5')

      -- Check key1 with has (should NOT update recency)
      cache.has('key1')

      -- Add new entry
      cache.set('key6', 'value6')

      -- key1 should still be evicted (has() didn't update recency)
      assert.is_false(cache.has('key1'))
    end)
  end)

  describe('remove', function()
    it('should delete specific entry', function()
      cache.set('key1', 'value1')
      cache.set('key2', 'value2')

      cache.remove('key1')

      assert.is_nil(cache.get('key1'))
      assert.are.equal('value2', cache.get('key2'))
    end)

    it('should handle removing non-existent key gracefully', function()
      cache.remove('nonexistent')
      -- Should not error
      assert.is_true(true)
    end)

    it('should update entry count', function()
      cache.set('key1', 'value1')
      cache.set('key2', 'value2')

      cache.remove('key1')

      local stats = cache.stats()
      assert.are.equal(1, stats.entries)
    end)
  end)

  describe('clear', function()
    it('should remove all entries', function()
      cache.set('key1', 'value1')
      cache.set('key2', 'value2')
      cache.set('key3', 'value3')

      cache.clear()

      assert.is_nil(cache.get('key1'))
      assert.is_nil(cache.get('key2'))
      assert.is_nil(cache.get('key3'))
    end)

    it('should reset entry count', function()
      cache.set('key1', 'value1')
      cache.set('key2', 'value2')

      cache.clear()

      local stats = cache.stats()
      assert.are.equal(0, stats.entries)
    end)

    it('should preserve stats counters', function()
      cache.set('key1', 'value1')
      cache.get('key1') -- hit
      cache.get('missing') -- miss

      cache.clear()

      local stats = cache.stats()
      assert.are.equal(0, stats.entries)
      -- Stats should still reflect historical data
      assert.are.equal(1, stats.hits)
      assert.are.equal(1, stats.misses)
    end)
  end)

  describe('stats', function()
    it('should track hits correctly', function()
      cache.set('key1', 'value1')
      cache.get('key1')
      cache.get('key1')
      cache.get('key1')

      local stats = cache.stats()
      assert.are.equal(3, stats.hits)
    end)

    it('should track misses correctly', function()
      cache.get('missing1')
      cache.get('missing2')

      local stats = cache.stats()
      assert.are.equal(2, stats.misses)
    end)

    it('should track evictions correctly', function()
      -- Fill cache
      for i = 1, 5 do
        cache.set('key' .. i, 'value' .. i)
      end
      -- Trigger evictions
      for i = 6, 10 do
        cache.set('key' .. i, 'value' .. i)
      end

      local stats = cache.stats()
      assert.are.equal(5, stats.evictions)
    end)

    it('should return current entry count', function()
      cache.set('key1', 'value1')
      cache.set('key2', 'value2')

      local stats = cache.stats()
      assert.are.equal(2, stats.entries)
    end)
  end)

  describe('make_key', function()
    it('should generate consistent keys for same input', function()
      local key1 = cache.make_key({
        prefix = 'local x = ',
        suffix = '\nend',
        filename = '/path/to/file.lua',
      })
      local key2 = cache.make_key({
        prefix = 'local x = ',
        suffix = '\nend',
        filename = '/path/to/file.lua',
      })

      assert.are.equal(key1, key2)
    end)

    it('should generate different keys for different prefix', function()
      local key1 = cache.make_key({
        prefix = 'local x = ',
        suffix = '\nend',
        filename = '/path/to/file.lua',
      })
      local key2 = cache.make_key({
        prefix = 'local y = ',
        suffix = '\nend',
        filename = '/path/to/file.lua',
      })

      assert.are_not.equal(key1, key2)
    end)

    it('should generate different keys for different suffix', function()
      local key1 = cache.make_key({
        prefix = 'local x = ',
        suffix = '\nend',
        filename = '/path/to/file.lua',
      })
      local key2 = cache.make_key({
        prefix = 'local x = ',
        suffix = '\nreturn x',
        filename = '/path/to/file.lua',
      })

      assert.are_not.equal(key1, key2)
    end)

    it('should generate different keys for different filename', function()
      local key1 = cache.make_key({
        prefix = 'local x = ',
        suffix = '\nend',
        filename = '/path/to/file1.lua',
      })
      local key2 = cache.make_key({
        prefix = 'local x = ',
        suffix = '\nend',
        filename = '/path/to/file2.lua',
      })

      assert.are_not.equal(key1, key2)
    end)

    it('should truncate long prefix to last N characters', function()
      local long_prefix = string.rep('a', 200)
      local key1 = cache.make_key({
        prefix = long_prefix,
        suffix = 'end',
        filename = '/file.lua',
      })
      local key2 = cache.make_key({
        prefix = 'different' .. long_prefix:sub(-100),
        suffix = 'end',
        filename = '/file.lua',
      })

      -- Keys should be equal because only last 100 chars matter
      assert.are.equal(key1, key2)
    end)

    it('should truncate long suffix to first N characters', function()
      local long_suffix = string.rep('b', 100)
      local key1 = cache.make_key({
        prefix = 'start',
        suffix = long_suffix,
        filename = '/file.lua',
      })
      local key2 = cache.make_key({
        prefix = 'start',
        suffix = long_suffix:sub(1, 50) .. 'different',
        filename = '/file.lua',
      })

      -- Keys should be equal because only first 50 chars matter
      assert.are.equal(key1, key2)
    end)

    it('should handle empty prefix and suffix', function()
      local key = cache.make_key({
        prefix = '',
        suffix = '',
        filename = '/file.lua',
      })

      assert.is_not_nil(key)
      assert.is_true(#key > 0)
    end)

    it('should handle nil filename', function()
      local key = cache.make_key({
        prefix = 'code',
        suffix = 'more',
        filename = nil,
      })

      assert.is_not_nil(key)
    end)

    it('should return a string', function()
      local key = cache.make_key({
        prefix = 'local x = ',
        suffix = '\nend',
        filename = '/path/to/file.lua',
      })

      assert.are.equal('string', type(key))
    end)
  end)

  describe('edge cases', function()
    it('should handle very large values', function()
      local large_value = {
        completion = string.rep('x', 10000),
        tokens = {},
      }
      for i = 1, 1000 do
        large_value.tokens[i] = i
      end

      cache.set('large', large_value)
      local retrieved = cache.get('large')

      assert.are.equal(10000, #retrieved.completion)
      assert.are.equal(1000, #retrieved.tokens)
    end)

    it('should handle special characters in keys', function()
      local special_key = 'key\nwith\ttabs\rand\0null'
      cache.set(special_key, 'value')
      assert.are.equal('value', cache.get(special_key))
    end)

    it('should handle nil values', function()
      -- Setting nil should be equivalent to remove
      cache.set('key1', 'value1')
      cache.set('key1', nil)
      assert.is_nil(cache.get('key1'))
    end)

    it('should work after multiple setup calls', function()
      cache.set('key1', 'value1')

      cache.setup({
        max_entries = 10,
        ttl_ms = 0,
      })

      -- After setup, cache should be cleared
      assert.is_nil(cache.get('key1'))

      cache.set('key2', 'value2')
      assert.are.equal('value2', cache.get('key2'))
    end)
  end)
end)
