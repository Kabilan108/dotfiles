-- sweep.nvim - Ring buffer module for cross-file context collection
-- Collects chunks from multiple files via yank, buffer enter/leave, and save events

local M = {}

---@class RingChunk
---@field content string The chunk content
---@field filename string Full path to the source file
---@field filetype string The filetype of the source
---@field source string How the chunk was collected: 'yank', 'buffer_enter', 'buffer_leave', 'save', 'visible'
---@field timestamp number Unix timestamp when chunk was added

---@class RingConfig
---@field max_chunks number Maximum number of chunks to store
---@field chunk_size number Maximum lines per chunk

---@type RingChunk[]
local buffer = {}

---@type number
local head = 1

---@type number
local count = 0

---@type RingConfig
local config = {
  max_chunks = 16,
  chunk_size = 64,
}

-- Similarity check key length
local SIMILARITY_PREFIX_LEN = 100

--- Get a fingerprint for duplicate detection (first N chars)
---@param content string
---@return string
local function get_fingerprint(content)
  return content:sub(1, SIMILARITY_PREFIX_LEN)
end

--- Check if a chunk with similar content already exists
---@param content string
---@return boolean
local function is_duplicate(content)
  local fingerprint = get_fingerprint(content)
  for i = 1, count do
    local idx = ((head - i - 1) % config.max_chunks) + 1
    if buffer[idx] and get_fingerprint(buffer[idx].content) == fingerprint then
      return true
    end
  end
  return false
end

--- Trim content to max lines
---@param content string
---@param max_lines number
---@return string
local function trim_to_lines(content, max_lines)
  local lines = vim.split(content, '\n')
  if #lines <= max_lines then
    return content
  end
  local trimmed = {}
  for i = 1, max_lines do
    trimmed[i] = lines[i]
  end
  return table.concat(trimmed, '\n')
end

--- Initialize the ring buffer with configuration
---@param opts? RingConfig
function M.setup(opts)
  opts = opts or {}
  config.max_chunks = opts.max_chunks or 16
  config.chunk_size = opts.chunk_size or 64
  M.clear()
end

--- Add a chunk to the ring buffer
---@param chunk table { content: string, filename: string, filetype: string, source: string }
function M.add(chunk)
  if not chunk or not chunk.content or chunk.content == '' then
    return
  end

  -- Trim content to chunk_size lines
  local content = trim_to_lines(chunk.content, config.chunk_size)

  -- Check for duplicates
  if is_duplicate(content) then
    return
  end

  -- Create the full chunk with metadata
  ---@type RingChunk
  local ring_chunk = {
    content = content,
    filename = chunk.filename or '',
    filetype = chunk.filetype or '',
    source = chunk.source or 'unknown',
    timestamp = os.time(),
  }

  -- Add to ring buffer
  buffer[head] = ring_chunk
  head = (head % config.max_chunks) + 1

  if count < config.max_chunks then
    count = count + 1
  end
end

--- Get all chunks as a formatted context string
---@return string
function M.get_context()
  local chunks = M.get_chunks({})
  if #chunks == 0 then
    return ''
  end

  local parts = {}
  for _, chunk in ipairs(chunks) do
    local header = string.format('-- File: %s (%s)', chunk.filename, chunk.filetype)
    table.insert(parts, header)
    table.insert(parts, chunk.content)
    table.insert(parts, '')
  end

  return table.concat(parts, '\n')
end

--- Get chunks filtered by criteria
---@param opts table { filetype?: string, exclude_file?: string, max_chunks?: number }
---@return RingChunk[]
function M.get_chunks(opts)
  opts = opts or {}
  local result = {}

  -- Iterate from most recent to oldest
  for i = 1, count do
    local idx = ((head - i - 1) % config.max_chunks) + 1
    local chunk = buffer[idx]

    if chunk then
      local include = true

      -- Filter by filetype
      if opts.filetype and chunk.filetype ~= opts.filetype then
        include = false
      end

      -- Exclude specific file
      if opts.exclude_file and chunk.filename == opts.exclude_file then
        include = false
      end

      if include then
        table.insert(result, chunk)
      end

      -- Respect max_chunks limit
      if opts.max_chunks and #result >= opts.max_chunks then
        break
      end
    end
  end

  return result
end

--- Clear the ring buffer
function M.clear()
  buffer = {}
  head = 1
  count = 0
end

--- Get statistics about the ring buffer
---@return table { count: number, max: number, filetypes: table<string, number> }
function M.stats()
  local filetypes = {}

  for i = 1, count do
    local idx = ((head - i - 1) % config.max_chunks) + 1
    local chunk = buffer[idx]
    if chunk and chunk.filetype and chunk.filetype ~= '' then
      filetypes[chunk.filetype] = (filetypes[chunk.filetype] or 0) + 1
    end
  end

  return {
    count = count,
    max = config.max_chunks,
    filetypes = filetypes,
  }
end

return M
