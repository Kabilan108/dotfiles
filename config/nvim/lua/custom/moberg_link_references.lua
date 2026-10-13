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

local function destination(node, buf, clean)
  local url = text(child(node, 'link_destination'), buf)
  if not url then
    return nil
  end
  -- Keep titles and angle-bracket destinations intact in the new definition.
  local angle = url:sub(1, 1) == '<' and url:sub(-1) == '>'
  local plain = angle and url:sub(2, -2) or url
  if not plain:lower():match '^https?://' or plain:find '[\r\n]' then
    return nil
  end
  local cleaned = clean == false and plain or require('custom.moberg_links').clean_url(plain)
  local title = text(child(node, 'link_title'), buf)
  if title and title:find '[\r\n]' then
    return nil
  end
  return (angle and '<' .. cleaned .. '>' or cleaned) .. (title and ' ' .. title or '')
end

function M.convert(first, last)
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= 'markdown' then
    vim.notify('MobergLinksToReferences requires a Markdown buffer', vim.log.levels.WARN)
    return
  end
  local parser = vim.treesitter.get_parser(buf, 'markdown')
  parser:parse(true)
  -- Markdown fenced code may itself inject a Markdown parser. Exclude source
  -- ranges from the outer document before looking through injected trees.
  local excluded = {}
  local function collect_excluded(node)
    local kind = node:type()
    if kind == 'fenced_code_block' or kind == 'indented_code_block' or kind == 'html_block' or kind == 'minus_metadata' or kind == 'plus_metadata' then
      excluded[#excluded + 1] = { node:range() }
      return
    end
    for item in node:iter_children() do
      collect_excluded(item)
    end
  end
  for _, tree in ipairs(parser:trees()) do
    collect_excluded(tree:root())
  end
  local function blocked(node)
    local row, col = node:range()
    for _, range in ipairs(excluded) do
      if (row > range[1] or (row == range[1] and col >= range[2])) and (row < range[3] or (row == range[3] and col < range[4])) then
        return true
      end
    end
    return false
  end
  local used, defined, existing, links = {}, {}, {}, {}
  parser:for_each_tree(function(tree, language)
    if language:lang() == 'markdown' then
      local query = vim.treesitter.query.parse('markdown', '(link_reference_definition) @definition')
      for _, node in query:iter_captures(tree:root(), buf) do
        local label = text(child(node, 'link_label'), buf)
        if label and not blocked(node) then
          label = label:sub(2, -2)
          local key = normalize(label)
          used[key] = true
          local target = destination(node, buf, false)
          if target and not defined[key] then
            -- Only reuse compact IDs compatible with markdown-oxide's parser.
            if #label >= 2 and not label:find '[%s%[%]]' and label:sub(1, 1) ~= '^' then
              existing[target] = existing[target] or label
            end
          end
          defined[key] = true
        end
      end
    elseif language:lang() == 'markdown_inline' then
      local query =
        vim.treesitter.query.parse('markdown_inline', '(inline_link) @link (link_label) @label (shortcut_link) @shortcut (collapsed_reference_link) @shortcut')
      for id, node in query:iter_captures(tree:root(), buf) do
        if blocked(node) then
          -- No changes or reference definitions from code/HTML examples.
        elseif query.captures[id] == 'label' then
          used[normalize(vim.treesitter.get_node_text(node, buf):sub(2, -2))] = true
        elseif query.captures[id] == 'shortcut' then
          local label = text(child(node, 'link_text'), buf)
          if label then
            used[normalize(label)] = true
          end
        else
          local sr, sc, er, ec = node:range()
          if sr >= first - 1 and er <= last - 1 then
            local ancestor = node:parent()
            local nested = false
            while ancestor do
              if ancestor:type() == 'image' or ancestor:type() == 'inline_link' then
                nested = true
                break
              end
              ancestor = ancestor:parent()
            end
            local target = not nested and destination(node, buf) or nil
            local label = text(child(node, 'link_text'), buf)
            if target and label then
              links[#links + 1] = { sr = sr, sc = sc, er = er, ec = ec, target = target, label = label }
            end
          end
        end
      end
    end
  end)
  table.sort(links, function(a, b)
    return a.sr < b.sr or (a.sr == b.sr and a.sc < b.sc)
  end)
  local definitions = {}
  for _, item in ipairs(links) do
    local id = existing[item.target]
    if not id then
      local base = item.label:lower():gsub('[^%w]+', '-'):gsub('^%-', ''):gsub('%-$', ''):sub(1, 60)
      if base == '' then
        base = 'link'
      elseif #base == 1 then
        -- markdown-oxide 0.25.12 requires at least two characters in an ID.
        base = 'link-' .. base
      end
      id = base
      local suffix = 2
      while used[normalize(id)] do
        id = base .. '-' .. suffix
        suffix = suffix + 1
      end
      used[normalize(id)] = true
      existing[item.target] = id
      definitions[#definitions + 1] = ('[%s]: %s'):format(id, item.target)
    end
    item.replacement = vim.split(('[%s][%s]'):format(item.label, id), '\n', { plain = true })
  end
  if #links == 0 then
    vim.notify 'no external inline links in this range'
    return
  end

  local definition_count = #definitions
  if definition_count > 0 then
    -- Refuse to append definitions into an unfinished code fence or HTML block.
    -- Validate before changing any user text, using a separate string parser.
    local source = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local candidate = table.concat(source, '\n') .. '\n\n' .. table.concat(definitions, '\n')
    local preview = vim.treesitter.get_string_parser(candidate, 'markdown')
    local query = vim.treesitter.query.parse('markdown', '(link_reference_definition) @definition')
    local count = 0
    for _, tree in ipairs(preview:parse()) do
      for _, node in query:iter_captures(tree:root(), candidate) do
        if node:range() >= #source then
          count = count + 1
        end
      end
    end
    if count ~= #definitions then
      vim.notify('cannot add reference definitions here; check for an unfinished code fence or HTML block', vim.log.levels.WARN)
      return
    end
  end

  local view = vim.fn.winsaveview()
  for index = #links, 1, -1 do
    if index < #links then
      vim.cmd 'undojoin'
    end
    local item = links[index]
    vim.api.nvim_buf_set_text(buf, item.sr, item.sc, item.er, item.ec, item.replacement)
  end
  if #definitions > 0 then
    local count = vim.api.nvim_buf_line_count(buf)
    if vim.api.nvim_buf_get_lines(buf, count - 1, count, false)[1] ~= '' then
      table.insert(definitions, 1, '')
    end
    vim.cmd 'undojoin'
    vim.api.nvim_buf_set_lines(buf, count, count, false, definitions)
  end
  vim.fn.winrestview(view)
  vim.notify(('converted %d link(s); added %d definition(s). Buffer is unsaved.'):format(#links, definition_count))
end

return M
