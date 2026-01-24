-- sweep.nvim - LSP and treesitter context extraction module
-- Extracts rich context using LSP for definitions and treesitter for scope analysis

local M = {}

---@class SweepDefinition
---@field name string Symbol name
---@field kind string Symbol kind (class, function, variable, etc.)
---@field content string Definition content
---@field filename? string Source filename

---@class SweepScope
---@field type string Scope type (function, class, method, module)
---@field name? string Scope name if available
---@field range {start_row: number, end_row: number} Line range
---@field content string Scope content (may be truncated)

---@class SweepContextResult
---@field definitions SweepDefinition[] LSP-derived definitions
---@field type_info? string Type information at cursor
---@field scope? SweepScope Enclosing scope from treesitter
---@field imports string[] Import/require statements
---@field formatted string Formatted context for prompts

---@class SweepContextOpts
---@field bufnr number Buffer number
---@field row number 0-indexed cursor row
---@field col number 0-indexed cursor column
---@field use_lsp? boolean Use LSP for context (default: from config)
---@field use_treesitter? boolean Use treesitter for context (default: from config)
---@field max_definition_lines? number Max lines per definition (default: 50)
---@field max_scope_lines? number Max lines for scope content (default: 50)
---@field max_formatted_lines? number Max lines for formatted output (default: 200)

-- Default configuration values
local DEFAULT_MAX_DEFINITION_LINES = 50
local DEFAULT_MAX_SCOPE_LINES = 50
local DEFAULT_MAX_FORMATTED_LINES = 200
local DEFAULT_MAX_IMPORT_SCAN_LINES = 50

-- Scope node types to look for when walking up the tree
-- Note: All languages share the same node type names where applicable
local SCOPE_NODE_TYPES = {
  -- Function-like scopes (Lua, Python, JS/TS, Go)
  ['function_declaration'] = 'function',
  ['function_definition'] = 'function',
  ['local_function'] = 'function',
  ['function'] = 'function',
  ['arrow_function'] = 'function',
  ['function_item'] = 'function',  -- Rust
  -- Method scopes
  ['method_definition'] = 'method',
  ['method_declaration'] = 'method',
  -- Class-like scopes
  ['class_definition'] = 'class',
  ['class_declaration'] = 'class',
  ['type_declaration'] = 'class',
  ['impl_item'] = 'class',  -- Rust
  ['struct_item'] = 'class',  -- Rust
}

-- Import patterns by filetype
local IMPORT_PATTERNS = {
  lua = {
    '^%s*local%s+[%w_]+%s*=%s*require%s*%(?%s*["\']',
    '^%s*require%s*%(?%s*["\']',
  },
  python = {
    '^%s*import%s+',
    '^%s*from%s+[%w_.]+%s+import%s+',
  },
  javascript = {
    '^%s*import%s+',
    '^%s*const%s+[%w_]+%s*=%s*require%s*%(',
    '^%s*let%s+[%w_]+%s*=%s*require%s*%(',
    '^%s*var%s+[%w_]+%s*=%s*require%s*%(',
  },
  typescript = {
    '^%s*import%s+',
    '^%s*const%s+[%w_]+%s*=%s*require%s*%(',
  },
  go = {
    '^%s*import%s+',
  },
  rust = {
    '^%s*use%s+',
  },
}

-- Add aliases
IMPORT_PATTERNS.javascriptreact = IMPORT_PATTERNS.javascript
IMPORT_PATTERNS.typescriptreact = IMPORT_PATTERNS.typescript

--- Get configuration with defaults
---@return table
local function get_config()
  local ok, config = pcall(require, 'sweep.config')
  if ok then
    return config.get()
  end
  return {
    context = {
      use_lsp = true,
      use_treesitter = true,
    },
  }
end

--- Get buffer lines safely
---@param bufnr number Buffer number
---@param start_row number Start row (0-indexed)
---@param end_row number End row (0-indexed, exclusive) or -1 for all
---@return string[] lines
local function get_buffer_lines(bufnr, start_row, end_row)
  local ok, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, start_row, end_row, false)
  if not ok then
    return {}
  end
  return lines
end

--- Get filetype for buffer
---@param bufnr number Buffer number
---@return string filetype
local function get_filetype(bufnr)
  return vim.api.nvim_get_option_value('filetype', { buf = bufnr })
end

--- Walk up the tree to find enclosing scope node
---@param node any Treesitter node
---@return any|nil scope_node, string|nil scope_type
local function find_enclosing_scope(node)
  local current = node
  while current do
    local node_type = current:type()
    local scope_type = SCOPE_NODE_TYPES[node_type]
    if scope_type then
      return current, scope_type
    end
    current = current:parent()
  end
  return nil, nil
end

--- Try to extract name from a scope node
---@param node any Treesitter node
---@param bufnr number Buffer number
---@return string|nil name
local function get_scope_name(node, bufnr)
  -- Try common field names for function/class names
  local name_fields = { 'name', 'declarator' }

  for _, field_name in ipairs(name_fields) do
    local ok, children = pcall(function() return node:field(field_name) end)
    if ok and children and #children > 0 then
      local name_node = children[1]
      if name_node then
        -- Try to get text from the name node
        local ok2, text = pcall(vim.treesitter.get_node_text, name_node, bufnr)
        if ok2 and text then
          return text
        end
      end
    end
  end

  return nil
end

--- Get the current scope at cursor position using treesitter
---@param bufnr number Buffer number
---@param row number 0-indexed cursor row
---@param opts? {max_lines?: number} Options
---@return SweepScope|nil scope
function M.get_scope(bufnr, row, opts)
  opts = opts or {}
  local max_lines = opts.max_lines or DEFAULT_MAX_SCOPE_LINES

  -- Try to get treesitter node at cursor
  local ok, node = pcall(vim.treesitter.get_node, {
    bufnr = bufnr,
    pos = { row, 0 },
  })

  if not ok or not node then
    return nil
  end

  -- Find enclosing scope
  local scope_node, scope_type = find_enclosing_scope(node)
  if not scope_node then
    return nil
  end

  -- Get range
  local start_row = scope_node:start()
  local end_row = scope_node:end_()

  -- Get scope name
  local name = get_scope_name(scope_node, bufnr)

  -- Get content (potentially truncated)
  local content_end = math.min(end_row + 1, start_row + max_lines)
  local lines = get_buffer_lines(bufnr, start_row, content_end)
  local content = table.concat(lines, '\n')

  -- Add truncation marker if needed
  if end_row - start_row + 1 > max_lines then
    content = content .. '\n-- ... truncated ...'
  end

  return {
    type = scope_type,
    name = name,
    range = {
      start_row = start_row,
      end_row = end_row,
    },
    content = content,
  }
end

--- Extract import statements from buffer
---@param bufnr number Buffer number
---@param opts? {max_lines?: number} Options
---@return string[] imports
function M.get_imports(bufnr, opts)
  opts = opts or {}
  local max_lines = opts.max_lines or DEFAULT_MAX_IMPORT_SCAN_LINES

  local filetype = get_filetype(bufnr)
  local patterns = IMPORT_PATTERNS[filetype]

  -- If no specific patterns, try to detect common patterns
  if not patterns then
    patterns = {
      '^%s*import%s+',
      '^%s*require%s*%(',
      '^%s*from%s+',
      '^%s*use%s+',
    }
  end

  local lines = get_buffer_lines(bufnr, 0, max_lines)
  local imports = {}
  local blank_line_count = 0

  for i, line in ipairs(lines) do
    -- Stop scanning after too many blank lines (likely past import section)
    if line:match('^%s*$') then
      blank_line_count = blank_line_count + 1
      if blank_line_count > 3 then
        -- Check if we're still in import section by looking ahead
        local found_import = false
        for j = i + 1, math.min(i + 5, #lines) do
          for _, pattern in ipairs(patterns) do
            if lines[j] and lines[j]:match(pattern) then
              found_import = true
              break
            end
          end
          if found_import then break end
        end
        if not found_import then
          break
        end
      end
    else
      blank_line_count = 0
    end

    -- Check if line matches any import pattern
    for _, pattern in ipairs(patterns) do
      if line:match(pattern) then
        table.insert(imports, line)
        break
      end
    end
  end

  return imports
end

--- Get definitions at cursor position via LSP (async)
---@param opts {bufnr: number, row: number, col: number, max_lines?: number} Options
---@param callback fun(definitions: SweepDefinition[]) Callback with results
function M.get_definitions(opts, callback)
  local bufnr = opts.bufnr
  local row = opts.row
  local col = opts.col
  local max_lines = opts.max_lines or DEFAULT_MAX_DEFINITION_LINES

  -- Check for LSP clients
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if not clients or #clients == 0 then
    callback({})
    return
  end

  -- Create LSP position params
  local params = {
    textDocument = {
      uri = vim.uri_from_bufnr(bufnr),
    },
    position = {
      line = row,
      character = col,
    },
  }

  -- Request definitions from LSP
  local success, _ = vim.lsp.buf_request(bufnr, 'textDocument/definition', params, function(err, result, ctx)
    if err or not result then
      callback({})
      return
    end

    local definitions = {}

    -- Normalize result to array
    local locations = vim.islist(result) and result or { result }

    for _, location in ipairs(locations) do
      if location and location.uri then
        local def_bufnr = vim.uri_to_bufnr(location.uri)
        local range = location.range or location.targetSelectionRange or location.targetRange

        if range then
          local start_line = range.start.line
          local end_line = range['end'].line

          -- Limit content size
          local content_end = math.min(end_line + 1, start_line + max_lines)

          -- Try to load buffer if not loaded
          local loaded = vim.api.nvim_buf_is_loaded(def_bufnr)
          if not loaded then
            pcall(vim.fn.bufload, def_bufnr)
          end

          local lines = get_buffer_lines(def_bufnr, start_line, content_end)
          local content = table.concat(lines, '\n')

          -- Extract name from first line if possible
          local name = 'unknown'
          if lines[1] then
            -- Try to extract identifier from first line
            name = lines[1]:match('[%w_]+') or 'unknown'
          end

          local filename = vim.fn.fnamemodify(vim.uri_to_fname(location.uri), ':t')

          table.insert(definitions, {
            name = name,
            kind = 'definition',
            content = content,
            filename = filename,
          })
        end
      end
    end

    callback(definitions)
  end)

  if not success then
    callback({})
  end
end

--- Get type information at cursor via LSP (async)
---@param opts {bufnr: number, row: number, col: number} Options
---@param callback fun(type_info: string|nil) Callback with result
function M.get_type_info(opts, callback)
  local bufnr = opts.bufnr
  local row = opts.row
  local col = opts.col

  -- Check for LSP clients
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if not clients or #clients == 0 then
    callback(nil)
    return
  end

  -- Create LSP position params
  local params = {
    textDocument = {
      uri = vim.uri_from_bufnr(bufnr),
    },
    position = {
      line = row,
      character = col,
    },
  }

  -- Request hover info from LSP
  local success, _ = vim.lsp.buf_request(bufnr, 'textDocument/hover', params, function(err, result, ctx)
    if err or not result or not result.contents then
      callback(nil)
      return
    end

    -- Extract type from hover contents
    local contents = result.contents
    local type_info = nil

    if type(contents) == 'string' then
      type_info = contents
    elseif type(contents) == 'table' then
      if contents.value then
        type_info = contents.value
      elseif contents.kind and contents.value then
        type_info = contents.value
      end
    end

    callback(type_info)
  end)

  if not success then
    callback(nil)
  end
end

--- Format context sections into a string for prompts
---@param ctx {definitions?: SweepDefinition[], scope?: SweepScope, imports?: string[], type_info?: string} Context parts
---@param opts? {max_lines?: number} Options
---@return string formatted
local function format_context(ctx, opts)
  opts = opts or {}
  local max_lines = opts.max_lines or DEFAULT_MAX_FORMATTED_LINES

  local sections = {}
  local total_lines = 0

  -- Priority 1: Current scope
  if ctx.scope and ctx.scope.content then
    local scope_header = string.format('-- Current scope (%s%s):',
      ctx.scope.type,
      ctx.scope.name and ': ' .. ctx.scope.name or '')
    local scope_lines = select(2, ctx.scope.content:gsub('\n', '\n')) + 1

    if total_lines + scope_lines + 2 <= max_lines then
      table.insert(sections, scope_header)
      table.insert(sections, ctx.scope.content)
      table.insert(sections, '')
      total_lines = total_lines + scope_lines + 2
    end
  end

  -- Priority 2: Type info
  if ctx.type_info then
    local type_section = '-- Type at cursor: ' .. ctx.type_info
    if total_lines + 2 <= max_lines then
      table.insert(sections, type_section)
      table.insert(sections, '')
      total_lines = total_lines + 2
    end
  end

  -- Priority 3: Definitions
  if ctx.definitions and #ctx.definitions > 0 then
    local def_header = '-- Definitions:'
    table.insert(sections, def_header)
    total_lines = total_lines + 1

    for _, def in ipairs(ctx.definitions) do
      local def_lines = select(2, def.content:gsub('\n', '\n')) + 1
      if total_lines + def_lines + 2 <= max_lines then
        local def_label = string.format('-- %s (%s)%s:',
          def.name,
          def.kind,
          def.filename and ' from ' .. def.filename or '')
        table.insert(sections, def_label)
        table.insert(sections, def.content)
        table.insert(sections, '')
        total_lines = total_lines + def_lines + 2
      else
        table.insert(sections, '-- ... more definitions truncated ...')
        break
      end
    end
  end

  -- Priority 4: Imports
  if ctx.imports and #ctx.imports > 0 then
    local imports_header = '-- Imports:'
    local imports_lines = #ctx.imports

    if total_lines + imports_lines + 2 <= max_lines then
      table.insert(sections, imports_header)
      for _, import in ipairs(ctx.imports) do
        table.insert(sections, import)
      end
      table.insert(sections, '')
      total_lines = total_lines + imports_lines + 2
    elseif total_lines + 5 <= max_lines then
      -- Include truncated imports
      table.insert(sections, imports_header)
      local remaining = max_lines - total_lines - 2
      for i = 1, math.min(remaining, #ctx.imports) do
        table.insert(sections, ctx.imports[i])
      end
      if #ctx.imports > remaining then
        table.insert(sections, '-- ... more imports truncated ...')
      end
    end
  end

  return table.concat(sections, '\n')
end

--- Get rich context for current cursor position (main entry point)
---@param opts SweepContextOpts Options
---@return SweepContextResult context
function M.get(opts)
  local config = get_config()
  local ctx_config = config.context or {}

  local bufnr = opts.bufnr or 0
  local row = opts.row or 0
  local col = opts.col or 0
  local use_lsp = opts.use_lsp
  local use_treesitter = opts.use_treesitter

  -- Use config defaults if not specified
  if use_lsp == nil then
    use_lsp = ctx_config.use_lsp ~= false
  end
  if use_treesitter == nil then
    use_treesitter = ctx_config.use_treesitter ~= false
  end

  local max_definition_lines = opts.max_definition_lines or DEFAULT_MAX_DEFINITION_LINES
  local max_scope_lines = opts.max_scope_lines or DEFAULT_MAX_SCOPE_LINES
  local max_formatted_lines = opts.max_formatted_lines or DEFAULT_MAX_FORMATTED_LINES

  -- Initialize result
  local result = {
    definitions = {},
    type_info = nil,
    scope = nil,
    imports = {},
    formatted = '',
  }

  -- Get treesitter scope
  if use_treesitter then
    result.scope = M.get_scope(bufnr, row, { max_lines = max_scope_lines })
  end

  -- Get imports (always try to get these as they're useful)
  result.imports = M.get_imports(bufnr)

  -- Note: LSP calls are async, but for the synchronous get() API,
  -- we return what we can synchronously and leave definitions empty.
  -- For LSP integration, use get_definitions() directly with a callback.

  -- Format the context
  result.formatted = format_context({
    definitions = result.definitions,
    scope = result.scope,
    imports = result.imports,
    type_info = result.type_info,
  }, { max_lines = max_formatted_lines })

  return result
end

--- Async version that waits for LSP results
---@param opts SweepContextOpts Options
---@param callback fun(context: SweepContextResult) Callback with full context
function M.get_async(opts, callback)
  local config = get_config()
  local ctx_config = config.context or {}

  local bufnr = opts.bufnr or 0
  local row = opts.row or 0
  local col = opts.col or 0
  local use_lsp = opts.use_lsp
  local use_treesitter = opts.use_treesitter

  -- Use config defaults if not specified
  if use_lsp == nil then
    use_lsp = ctx_config.use_lsp ~= false
  end
  if use_treesitter == nil then
    use_treesitter = ctx_config.use_treesitter ~= false
  end

  local max_definition_lines = opts.max_definition_lines or DEFAULT_MAX_DEFINITION_LINES
  local max_scope_lines = opts.max_scope_lines or DEFAULT_MAX_SCOPE_LINES
  local max_formatted_lines = opts.max_formatted_lines or DEFAULT_MAX_FORMATTED_LINES

  -- Initialize result
  local result = {
    definitions = {},
    type_info = nil,
    scope = nil,
    imports = {},
    formatted = '',
  }

  -- Get synchronous parts
  if use_treesitter then
    result.scope = M.get_scope(bufnr, row, { max_lines = max_scope_lines })
  end
  result.imports = M.get_imports(bufnr)

  -- If not using LSP, return immediately
  if not use_lsp then
    result.formatted = format_context(result, { max_lines = max_formatted_lines })
    callback(result)
    return
  end

  -- Get async LSP parts
  local pending = 2  -- definitions + type_info

  local function check_complete()
    pending = pending - 1
    if pending == 0 then
      result.formatted = format_context(result, { max_lines = max_formatted_lines })
      callback(result)
    end
  end

  M.get_definitions({
    bufnr = bufnr,
    row = row,
    col = col,
    max_lines = max_definition_lines,
  }, function(definitions)
    result.definitions = definitions
    check_complete()
  end)

  M.get_type_info({
    bufnr = bufnr,
    row = row,
    col = col,
  }, function(type_info)
    result.type_info = type_info
    check_complete()
  end)
end

return M
