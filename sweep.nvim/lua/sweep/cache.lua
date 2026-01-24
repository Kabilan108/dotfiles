-- LRU cache for completion results
-- Inspired by llama.vim's caching approach

local M = {}

-- Default configuration
local defaults = {
  max_entries = 100,
  ttl_ms = 60000, -- 1 minute default TTL, 0 = no expiry
}

-- Internal state
local config = {}
local entries = {}       -- key -> { value, created_at, accessed_at }
local access_order = {}  -- ordered list of keys by access time (oldest first)
local stats = {
  hits = 0,
  misses = 0,
  evictions = 0,
}

-- Key generation settings
local PREFIX_LENGTH = 100
local SUFFIX_LENGTH = 50

--- Get current time in milliseconds
---@return number
local function now_ms()
  local sec, usec = vim.loop.gettimeofday()
  return sec * 1000 + math.floor(usec / 1000)
end

--- Check if an entry has expired
---@param entry table
---@return boolean
local function is_expired(entry)
  if config.ttl_ms == 0 then
    return false
  end
  return (now_ms() - entry.created_at) > config.ttl_ms
end

--- Find and remove a key from access_order list
---@param key string
local function remove_from_access_order(key)
  for i, k in ipairs(access_order) do
    if k == key then
      table.remove(access_order, i)
      return
    end
  end
end

--- Add key to end of access_order (most recently used)
---@param key string
local function touch(key)
  remove_from_access_order(key)
  table.insert(access_order, key)
end

--- Evict least recently used entry
local function evict_lru()
  if #access_order == 0 then
    return
  end

  -- First, try to evict expired entries
  for i = 1, #access_order do
    local key = access_order[i]
    local entry = entries[key]
    if entry and is_expired(entry) then
      table.remove(access_order, i)
      entries[key] = nil
      stats.evictions = stats.evictions + 1
      return
    end
  end

  -- Otherwise, evict the least recently used (first in list)
  local lru_key = table.remove(access_order, 1)
  if lru_key and entries[lru_key] then
    entries[lru_key] = nil
    stats.evictions = stats.evictions + 1
  end
end

--- Get the current number of entries
---@return number
local function entry_count()
  local count = 0
  for _ in pairs(entries) do
    count = count + 1
  end
  return count
end

--- Initialize the cache with options
---@param opts? table
function M.setup(opts)
  opts = opts or {}
  config = vim.tbl_deep_extend('force', defaults, opts)

  -- Clear cache on setup
  entries = {}
  access_order = {}
  stats = {
    hits = 0,
    misses = 0,
    evictions = 0,
  }
end

--- Store a value in the cache
---@param key string
---@param value any
function M.set(key, value)
  if value == nil then
    M.remove(key)
    return
  end

  local existing = entries[key]
  local current_time = now_ms()

  if existing then
    -- Update existing entry
    existing.value = value
    existing.created_at = current_time
    existing.accessed_at = current_time
    touch(key)
  else
    -- Check if we need to evict
    while entry_count() >= config.max_entries do
      evict_lru()
    end

    -- Add new entry
    entries[key] = {
      value = value,
      created_at = current_time,
      accessed_at = current_time,
    }
    table.insert(access_order, key)
  end
end

--- Get a value from the cache
---@param key string
---@return any|nil
function M.get(key)
  local entry = entries[key]

  if not entry then
    stats.misses = stats.misses + 1
    return nil
  end

  if is_expired(entry) then
    -- Remove expired entry
    M.remove(key)
    stats.misses = stats.misses + 1
    return nil
  end

  -- Update access time and order
  entry.accessed_at = now_ms()
  touch(key)
  stats.hits = stats.hits + 1

  return entry.value
end

--- Check if a key exists and is not expired (without updating recency)
---@param key string
---@return boolean
function M.has(key)
  local entry = entries[key]

  if not entry then
    return false
  end

  if is_expired(entry) then
    return false
  end

  return true
end

--- Remove a specific entry
---@param key string
function M.remove(key)
  if entries[key] then
    entries[key] = nil
    remove_from_access_order(key)
  end
end

--- Clear all entries
function M.clear()
  entries = {}
  access_order = {}
  -- Note: stats are preserved
end

--- Get cache statistics
---@return table
function M.stats()
  return {
    entries = entry_count(),
    hits = stats.hits,
    misses = stats.misses,
    evictions = stats.evictions,
  }
end

--- Generate a cache key from completion context
---@param opts table { prefix: string, suffix: string, filename: string? }
---@return string
function M.make_key(opts)
  local prefix = opts.prefix or ''
  local suffix = opts.suffix or ''
  local filename = opts.filename or ''

  -- Truncate prefix to last N characters
  local prefix_part = prefix
  if #prefix > PREFIX_LENGTH then
    prefix_part = prefix:sub(-PREFIX_LENGTH)
  end

  -- Truncate suffix to first N characters
  local suffix_part = suffix
  if #suffix > SUFFIX_LENGTH then
    suffix_part = suffix:sub(1, SUFFIX_LENGTH)
  end

  -- Format: filename|prefix|suffix
  return string.format('%s|%s|%s', filename, prefix_part, suffix_part)
end

return M
