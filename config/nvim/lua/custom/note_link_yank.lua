local M = {}

local function child(node, kind)
  for item in node:iter_children() do
    if item:type() == kind then
      return item
    end
  end
end

local function text(node, buf)
  return node and vim.treesitter.get_node_text(node, buf) or nil
end

local function normalize(label)
  return vim.trim(label):gsub('%s+', ' '):lower()
end

local function destination(node, buf)
  local value = text(child(node, 'link_destination'), buf)
  if value and value:sub(1, 1) == '<' and value:sub(-1) == '>' then
    value = value:sub(2, -2)
  end
  return value and value:gsub('\\([%p])', '%1') or nil
end

local function reference(buf, label)
  local parser = vim.treesitter.get_parser(buf, 'markdown')
  local query = vim.treesitter.query.parse('markdown', '(link_reference_definition) @definition')
  -- Use only the outer document, so definitions inside code examples cannot win.
  for _, tree in ipairs(parser:parse()) do
    for _, node in query:iter_captures(tree:root(), buf) do
      local id = text(child(node, 'link_label'), buf)
      if id and normalize(id:sub(2, -2)) == normalize(label) then
        return destination(node, buf)
      end
    end
  end
end

local function wiki_path(buf, row, col)
  local clients = vim.lsp.get_clients { bufnr = buf, name = 'markdown_oxide' }
  local client = clients[1]
  if not client or not client.initialized then
    return nil, 'markdown-oxide is not ready to resolve this wikilink'
  end
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
  local response = client:request_sync('textDocument/definition', {
    textDocument = { uri = vim.uri_from_bufnr(buf) },
    position = { line = row, character = vim.str_utfindex(line, client.offset_encoding, col, false) },
  }, 2000, buf)
  if not response or response.err then
    return nil, 'could not resolve wikilink through markdown-oxide'
  end
  local locations = response.result or {}
  if locations.uri then
    locations = { locations }
  end
  local paths = {}
  for _, location in ipairs(locations) do
    local uri = location.uri or location.targetUri
    if uri and uri:match '^file:' then
      local path = vim.fs.normalize(vim.uri_to_fname(uri))
      path = vim.uv.fs_realpath(path) or path
      paths[path] = true
    end
  end
  local matches = vim.tbl_keys(paths)
  if #matches ~= 1 then
    return nil, #matches == 0 and 'wikilink target does not exist' or 'wikilink target is ambiguous'
  end
  local path = matches[1]
  if path:find '/topsecret/' then
    return nil, 'cannot resolve a link in the excluded vault area'
  end
  if not vim.uv.fs_stat(path) then
    return nil, 'wikilink target does not exist'
  end
  return path
end

function M.target(buf, row, col)
  if not vim.fs.root(buf, '.obsidian') then
    return nil, 'link copying is only available in the vault'
  end
  local parser = vim.treesitter.get_parser(buf, 'markdown')
  parser:parse(true)
  local node = vim.treesitter.get_node { bufnr = buf, pos = { row, col }, ignore_injections = false }
  local ancestor = vim.treesitter.get_node { bufnr = buf, pos = { row, col }, ignore_injections = true }
  while ancestor do
    local kind = ancestor:type()
    if kind == 'code_span' or kind == 'fenced_code_block' or kind == 'indented_code_block' then
      return nil, 'cursor is in a code example'
    end
    ancestor = ancestor:parent()
  end
  ancestor = node
  while ancestor do
    if ancestor:type() == 'code_span' then
      return nil, 'cursor is in a code example'
    end
    ancestor = ancestor:parent()
  end
  -- A wikilink's alias or heading can be under the cursor. Ask the LSP at
  -- the start of its target instead, and deduplicate heading/block locations.
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
  local start = 1
  while true do
    local first, last = line:find('%[%[.-%]%]', start)
    if not first then
      break
    end
    if col >= first - 1 and col < last then
      return wiki_path(buf, row, first + 1)
    end
    start = last + 1
  end
  while node do
    local kind = node:type()
    if kind == 'inline_link' or kind == 'image' or kind == 'link_reference_definition' then
      return destination(node, buf)
    elseif kind == 'full_reference_link' then
      local label = text(child(node, 'link_label'), buf)
      return label and reference(buf, label:sub(2, -2)) or nil, 'reference definition not found'
    elseif kind == 'collapsed_reference_link' or kind == 'shortcut_link' then
      local label = text(child(node, 'link_text'), buf)
      return label and reference(buf, label) or nil, 'reference definition not found'
    elseif kind == 'uri_autolink' then
      return text(node, buf):sub(2, -2)
    end
    node = node:parent()
  end
  return nil, 'no link under the cursor'
end

function M.yank()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local target, err = M.target(0, row - 1, col)
  if not target then
    vim.notify(err or 'link destination not found', vim.log.levels.WARN)
    return
  end
  vim.fn.setreg('+', target, 'v')
  vim.notify 'copied link destination'
end

return M
