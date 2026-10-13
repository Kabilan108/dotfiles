local M = {}

function M.clean_url(url)
  local base, query, fragment = url:match '^([^?#]+)%?([^#]*)(.*)$'
  if not base then
    return url
  end
  local host = (base:match '^%a+://([^/]+)' or ''):lower()
  local provider = host == 'bitbucket.org' or host:match '^[%w%-%.]+%.atlassian%.net$'
  local kept = {}
  for parameter in query:gmatch '[^&]+' do
    local key = (parameter:match '^[^=]+' or '')
      :gsub('%%(%x%x)', function(hex)
        return string.char(tonumber(hex, 16))
      end)
      :lower()
    local tracking = key:match '^utm_' or key == 'fbclid' or key == 'gclid' or key == 'msclkid'
    if not tracking and not (provider and key == 'authorigin') then
      kept[#kept + 1] = parameter
    end
  end
  return base .. (#kept > 0 and '?' .. table.concat(kept, '&') or '') .. fragment
end

local function link(label, url)
  label = label:gsub('[\\%[%]]', '\\%0')
  -- Parentheses in branch names must not close the Markdown destination.
  url = M.clean_url(url):gsub('%(', '%%28'):gsub('%)', '%%29')
  return ('[%s](%s)'):format(label, url)
end

-- Format only a whole URL, leaving prose, existing links and unrelated URLs alone.
function M.format(text)
  local url = vim.trim(text)
  if url:find '%s' then
    return nil
  end
  local scheme = (url:match '^(%a+)://' or ''):lower()
  local host, path = url:match '^%a+://([^/]+)/(.+)$'
  if not host or (scheme ~= 'http' and scheme ~= 'https') then
    return nil
  end
  host = host:lower()
  local route = path:match '^[^?#]+' or ''
  if host:match '^[%w%-%.]+%.atlassian%.net$' then
    local key = route:match '^browse/([%a][%w]*%-%d+)/?$' or route:match '^jira/servicedesk/projects/[^/]+/queues/issue/([%a][%w]*%-%d+)/?$'
    return key and link(key:upper(), url) or nil
  end
  if host ~= 'bitbucket.org' then
    return nil
  end
  local repo, number = route:match '^[^/]+/([^/]+)/pull%-requests/(%d+)/?$'
  if not repo then
    repo, number = route:match '^[^/]+/([^/]+)/pull%-requests/(%d+)/.+$'
  end
  if repo then
    return link(repo .. ' #' .. number, url)
  end
  local branch
  repo, branch = route:match '^[^/]+/([^/]+)/branch/(.+)$'
  if not repo then
    repo, branch = route:match '^[^/]+/([^/]+)/src/([^/]+)/?$'
  end
  if repo then
    branch = branch:gsub('%%(%x%x)', function(hex)
      return string.char(tonumber(hex, 16))
    end)
    if branch:find '%c' then
      return nil
    end
    return link(repo .. ' (' .. branch .. ')', url)
  end
end

function M.put_keys(key)
  local register = vim.v.register
  if register == '"' then
    if vim.tbl_contains(vim.opt.clipboard:get(), 'unnamedplus') then
      register = '+'
    elseif vim.tbl_contains(vim.opt.clipboard:get(), 'unnamed') then
      register = '*'
    end
  end
  local raw = '"' .. register .. key
  if vim.bo.filetype ~= 'markdown' or register == '=' then
    return raw
  end
  local info = vim.fn.getreginfo(register)
  if not info.regcontents or info.regtype:sub(1, 1) == '\22' then
    return raw
  end
  local formatted = M.format(table.concat(info.regcontents, '\n'))
  if not formatted then
    return raw
  end
  local expression = vim.fn.string(formatted)
  if info.regtype == 'V' then
    expression = expression .. ' . "\\n"'
  end
  -- Native expression-register put retains counts, undo and dot-repeat without
  -- replacing the source register or writing to the system clipboard.
  return '"=' .. expression .. '\r' .. key
end

function M.setup()
  vim.api.nvim_create_user_command('MobergLinksToReferences', function(opts)
    require('custom.moberg_link_references').convert(opts.line1, opts.line2)
  end, { range = true, desc = 'convert external inline links to reference links' })

  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('MobergLinks', { clear = true }),
    pattern = 'markdown',
    callback = function(event)
      for _, key in ipairs { 'p', 'P' } do
        vim.keymap.set('n', key, function()
          return M.put_keys(key)
        end, { buffer = event.buf, expr = true, desc = 'paste with Moberg link formatting' })
      end
    end,
  })

  local original_paste = vim.paste
  local pending
  vim.paste = function(lines, phase)
    if phase == -1 or phase == 1 then
      pending = nil
      if vim.bo.filetype == 'markdown' and vim.fn.getcmdtype() == '' then
        pending = ''
      end
    end
    if pending == nil then
      return original_paste(lines, phase)
    end
    -- Terminal pastes can split even a single URL across several chunks.
    pending = pending .. table.concat(lines, '\n')
    if phase == 1 or phase == 2 then
      return true
    end
    local text = M.format(pending) or pending
    pending = nil
    return original_paste(vim.split(text, '\n', { plain = true }), -1)
  end
end

return M
