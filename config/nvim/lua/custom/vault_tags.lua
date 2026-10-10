-- Tag search for the coppermind vault. Inline checkbox items and #todo lines come from the retired
-- Obsidian Tasks setup and are skipped, so a tag surfaces notes and TaskNotes tasks (tagged in
-- frontmatter) instead of hundreds of old inline todos. Nested tags count toward their parents,
-- as in Obsidian: #moberg also finds #moberg/clara.

local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local make_entry = require 'telescope.make_entry'
local actions = require 'telescope.actions'
local action_state = require 'telescope.actions.state'
local conf = require('telescope.config').values

local M = {}

---@class VaultTagHit
---@field path string vault-relative
---@field lnum integer
---@field col integer
---@field text string
---@field tags string[] lowercased, without the leading '#'

local INLINE_TAG = [[(^|[\s(])#[A-Za-z][\w/-]*]]
local FRONTMATTER = [[\A---\r?\n(?s:.*?)\r?\n---\r?$]]
-- same folders markdown-oxide skips
local EXCLUDED = '!**/{archives,_archive,excalidraw,repos}/**'

---@return string
local function vault_root()
  return vim.fs.root(0, '.obsidian') or vim.fs.normalize '~/notes'
end

---@param root string
---@param args string[]
---@return string
local function rg(root, args)
  local cmd = vim.list_extend({ 'rg', '--color=never', '-g', '*.md', '-g', EXCLUDED }, args)
  return vim.system(cmd, { cwd = root, text = true }):wait().stdout or ''
end

---@param tag string
---@return string
local function normalize(tag)
  return (tag:lower():gsub('^#', ''):gsub('[/-]+$', ''))
end

---@param text string
---@return string[]
local function inline_tags(text)
  local tags = {}
  for tag in (' ' .. text):gmatch '[%s(]#(%a[%w_/-]*)' do
    table.insert(tags, normalize(tag))
  end
  return tags
end

---@param text string
---@return boolean
local function is_old_task(text)
  return text:match '^%s*[-*+]%s+%[.%]' ~= nil or text:find('#todo', 1, true) ~= nil
end

---@param root string
---@param hits VaultTagHit[]
local function collect_inline(root, hits)
  local out = rg(root, { '--no-heading', '--with-filename', '--line-number', '--column', '-e', INLINE_TAG })
  for line in vim.gsplit(out, '\n', { trimempty = true }) do
    local path, lnum, col, text = line:match '^(.-):(%d+):(%d+):(.*)$'
    if path and not is_old_task(text) then
      local tags = inline_tags(text)
      if #tags > 0 then
        table.insert(hits, { path = path, lnum = tonumber(lnum), col = tonumber(col), text = text, tags = tags })
      end
    end
  end
end

-- handles both `tags: [a, b]` and a `tags:` key followed by `- a` list items
---@param path string
---@param block string
---@param first_lnum integer
---@param hits VaultTagHit[]
local function parse_frontmatter(path, block, first_lnum, hits)
  local in_list = false
  for i, line in ipairs(vim.split(block, '\r?\n')) do
    local lnum = first_lnum + i - 1
    local key, rest = line:match '^([%w_-]+):%s*(.-)%s*$'
    if key then
      in_list = key == 'tags' and rest == ''
      if key == 'tags' and rest ~= '' then
        local tags = {}
        for tag in rest:gsub('^%[', ''):gsub('%]$', ''):gmatch '[^,%s"\']+' do
          table.insert(tags, normalize(tag))
        end
        table.insert(hits, { path = path, lnum = lnum, col = 1, text = line, tags = tags })
      end
    elseif in_list then
      local tag = normalize(line:match '^%s*-%s+["\']?([^"\']-)["\']?%s*$' or '')
      if tag ~= '' then
        table.insert(hits, { path = path, lnum = lnum, col = 1, text = vim.trim(line), tags = { tag } })
      elseif not line:match '^%s*$' then
        in_list = false
      end
    end
  end
end

---@param root string
---@param hits VaultTagHit[]
local function collect_frontmatter(root, hits)
  local out = rg(root, { '--json', '--multiline', '-e', FRONTMATTER })
  for line in vim.gsplit(out, '\n', { trimempty = true }) do
    local ok, ev = pcall(vim.json.decode, line)
    if ok and ev.type == 'match' and ev.data.lines.text then
      parse_frontmatter(ev.data.path.text, ev.data.lines.text, ev.data.line_number, hits)
    end
  end
end

---@param root string
---@return VaultTagHit[]
local function collect(root)
  local hits = {}
  collect_frontmatter(root, hits)
  collect_inline(root, hits)
  table.sort(hits, function(a, b)
    if a.path ~= b.path then
      return a.path < b.path
    end
    return a.lnum < b.lnum
  end)
  return hits
end

---@param hit VaultTagHit
---@param tag string
---@return boolean
local function has_tag(hit, tag)
  for _, t in ipairs(hit.tags) do
    if t == tag or vim.startswith(t, tag .. '/') then
      return true
    end
  end
  return false
end

---@param root string
---@param hits VaultTagHit[]
---@param tag string
local function pick_occurrences(root, hits, tag)
  local lines = {}
  for _, hit in ipairs(hits) do
    if has_tag(hit, tag) then
      table.insert(lines, ('%s:%d:%d:%s'):format(hit.path, hit.lnum, hit.col, hit.text))
    end
  end
  local opts = { cwd = root }
  pickers
    .new(opts, {
      prompt_title = ('#%s (%d)'):format(tag, #lines),
      finder = finders.new_table { results = lines, entry_maker = make_entry.gen_from_vimgrep(opts) },
      previewer = conf.grep_previewer(opts),
      sorter = conf.generic_sorter(opts),
    })
    :find()
end

---@param root string
---@param hits VaultTagHit[]
local function pick_tag(root, hits)
  local counts = {}
  for _, hit in ipairs(hits) do
    local seen = {}
    for _, t in ipairs(hit.tags) do
      local parts = vim.split(t, '/', { plain = true })
      for i = 1, #parts do
        local prefix = table.concat(parts, '/', 1, i)
        if not seen[prefix] then
          seen[prefix] = true
          counts[prefix] = (counts[prefix] or 0) + 1
        end
      end
    end
  end
  local tags = vim.tbl_keys(counts)
  table.sort(tags, function(a, b)
    if counts[a] ~= counts[b] then
      return counts[a] > counts[b]
    end
    return a < b
  end)

  pickers
    .new({}, {
      prompt_title = 'vault tags',
      finder = finders.new_table {
        results = tags,
        entry_maker = function(tag)
          return { value = tag, display = ('%4d  #%s'):format(counts[tag], tag), ordinal = tag }
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(bufnr)
          if selection then
            pick_occurrences(root, hits, selection.value)
          end
        end)
        return true
      end,
    })
    :find()
end

--- With the cursor on a #tag, list its occurrences; otherwise pick a tag first.
function M.pick()
  local root = vault_root()
  local hits = collect(root)
  local under_cursor = vim.fn.expand('<cWORD>'):match '#(%a[%w_/-]*)'
  if under_cursor then
    pick_occurrences(root, hits, normalize(under_cursor))
  else
    pick_tag(root, hits)
  end
end

return M
