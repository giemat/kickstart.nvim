-- Keymap cheatsheet (<leader>?) and the single source of which-key group names.
-- Built live from the real keymaps, so a new mapping with a `desc` shows up with no edit here.
-- How to change: add a group to `M.groups` (which-key reads it too) or edit `M.learning_path`.
local M = {}

-- Ordered: first matching prefix wins.
M.groups = {
  { prefix = '<leader>s', name = '[S]earch', mode = { 'n', 'v' } },
  { prefix = '<leader>t', name = '[T]oggle' },
  { prefix = '<leader>h', name = 'Git [H]unk', mode = { 'n', 'v' } },
  { prefix = '<leader>d', name = '[D]evcontainer' },
  { prefix = '<leader>m', name = '[M]arkdown' },
  { prefix = '<leader>l', name = '[L]aTeX' },
  { prefix = 'gr', name = 'LSP' },
}

M.learning_path = {
  '1. Core motions: h j k l, w b e, 0 $, gg G, f/t, % -- then operators: d c y + motion.',
  '2. Leader groups: press <Space> and wait; which-key lists every group.',
  '3. Practice: :Tutor (built-in lesson), :VimBeGood (motion games).',
  '4. Lost? <leader>sk searches all keymaps, <leader>sh searches help, <leader>? shows this page.',
}

local function pretty(lhs)
  lhs = lhs:gsub('^ ', '<leader>')
  return lhs
end

local function section_for(lhs)
  for _, g in ipairs(M.groups) do
    if vim.startswith(lhs, g.prefix) then return g.name end
  end
  if lhs:match '^<leader>[aA1-4]$' then return 'Harpoon' end
  if lhs:match '^<C%-[hjklHJKL]>$' then return 'Navigation' end
  if lhs:match '^<leader>' then return 'Leader' end
  return 'General'
end

--- Collect `{ section = { {lhs, desc}, ... } }` from live keymaps (global + current buffer).
function M.collect()
  local sections, seen = {}, {}
  for _, mode in ipairs { 'n', 'v', 'i', 't' } do
    local maps = vim.api.nvim_get_keymap(mode)
    vim.list_extend(maps, vim.api.nvim_buf_get_keymap(0, mode))
    for _, m in ipairs(maps) do
      local lhs = pretty(m.lhs)
      if m.desc and m.desc ~= '' and not lhs:find '^<Plug>' and not lhs:find '^<SNR>' and not m.desc:find '^:help' then
        local key = mode .. lhs
        if not seen[key] then
          seen[key] = true
          local sec = section_for(lhs)
          sections[sec] = sections[sec] or {}
          table.insert(sections[sec], { lhs = lhs, desc = m.desc, mode = mode })
        end
      end
    end
  end
  return sections
end

function M.lines()
  local out = { 'Keymap cheatsheet  (q to close)', '', 'Learning path', '-------------' }
  vim.list_extend(out, M.learning_path)
  local sections = M.collect()
  local names = vim.tbl_keys(sections)
  table.sort(names)
  for _, name in ipairs(names) do
    vim.list_extend(out, { '', name, string.rep('-', #name) })
    table.sort(sections[name], function(a, b) return a.lhs < b.lhs end)
    for _, e in ipairs(sections[name]) do
      table.insert(out, string.format('  %-18s %s  %s', e.lhs, e.mode, e.desc))
    end
  end
  return out
end

function M.open()
  local lines = M.lines()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = 'wipe'
  local width = math.min(100, vim.o.columns - 4)
  local height = math.max(1, math.min(#lines, vim.o.lines - 6))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' Cheatsheet ',
  })
  vim.keymap.set('n', 'q', function() vim.api.nvim_win_close(win, true) end, { buffer = buf, desc = 'Close cheatsheet' })
  return win
end

return M
