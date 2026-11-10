-- Clipboard provider for sessions where the system clipboard lives on
-- another machine: devcontainers, SSH and tmux without Wayland.
--
-- On the local desktop (Wayland with wl-copy/wl-paste, no SSH, no container)
-- nothing changes: Neovim's default provider already uses wl-copy.
--
-- Elsewhere:
--   copy   tmux buffer (and terminal clipboard via `load-buffer -w`) when the
--          tmux server is reachable, otherwise an OSC 52 write.
--   paste  tmux buffer when reachable, otherwise an OSC 52 query with a short
--          timeout, falling back to this Neovim's last copy so `p` never hangs.
--
-- Options (set before this module loads):
--   vim.g.osc52_paste = false        never send OSC 52 read queries
--   vim.g.osc52_paste_timeout = 1000 ms to wait for the terminal's answer
local util = require 'custom.util'

local uv = vim.uv or vim.loop

local function proc_lines(pid, file)
  local ok, lines = pcall(vim.fn.readfile, '/proc/' .. pid .. '/' .. file)
  return ok and lines or {}
end

local function proc_ppid(pid)
  for _, line in ipairs(proc_lines(pid, 'status')) do
    local ppid = line:match '^PPid:%s+(%d+)'
    if ppid then return tonumber(ppid) end
  end
end

-- True when a parent process (up to 16 levels) has `name` in its comm.
local function has_ancestor(name)
  local pid = uv.os_getpid()
  for _ = 1, 16 do
    local ppid = proc_ppid(pid)
    if not ppid or ppid <= 1 then return false end
    local comm = proc_lines(ppid, 'comm')[1] or ''
    if comm:find(name, 1, true) then return true end
    pid = ppid
  end
  return false
end

local in_container = util.in_container()
local in_ssh = vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil
local in_tmux = vim.env.TMUX ~= nil
local has_wayland = vim.env.WAYLAND_DISPLAY ~= nil and util.has 'wl-copy' and util.has 'wl-paste'

-- Local desktop: keep the default provider.
if has_wayland and not in_ssh and not in_container then return end
if not (in_container or in_ssh or in_tmux or vim.env.HERDR_PANE_ID ~= nil or has_ancestor 'herdr') then return end

local osc52 = require 'vim.ui.clipboard.osc52'
-- A container usually has no tmux binary or socket; the outer tmux sees OSC 52.
local has_tmux = in_tmux and util.has 'tmux'
local last_copy = {}

local function last(reg) return vim.deepcopy(last_copy[reg] or { {}, 'v' }) end

-- Honor the user's tmux `set-clipboard`: `-w` would bypass it.
-- Read once per session so a yank spawns only `load-buffer`.
local forwards_cache
local function tmux_forwards_clipboard()
  if forwards_cache == nil then
    local out = vim.fn.systemlist { 'tmux', 'show-options', '-sv', 'set-clipboard' }
    forwards_cache = vim.v.shell_error == 0 and (out[1] == 'on' or out[1] == 'external')
  end
  return forwards_cache
end

local function copy(reg)
  local emit = osc52.copy(reg)
  return function(lines, regtype)
    last_copy[reg] = { vim.deepcopy(lines), regtype }
    -- tmux ignores empty loads, so let OSC 52 carry those.
    local empty = #lines == 0 or (#lines == 1 and lines[1] == '')
    if has_tmux and reg == '+' and not empty then
      local cmd = { 'tmux', 'load-buffer' }
      if tmux_forwards_clipboard() then cmd[#cmd + 1] = '-w' end
      cmd[#cmd + 1] = '-'
      vim.fn.system(cmd, lines)
      if vim.v.shell_error == 0 then return end
    end
    emit(lines)
  end
end

-- OSC 52 read with a bounded wait. Returns lines, or nil when nothing answered.
local function osc52_query(reg)
  if #vim.api.nvim_list_uis() == 0 then return nil end
  local contents
  local id = vim.api.nvim_create_autocmd('TermResponse', {
    callback = function(ev)
      local encoded = (ev.data.sequence or ''):match '\027%]52;%w?;([A-Za-z0-9+/=]*)'
      if encoded then
        local ok, decoded = pcall(vim.base64.decode, encoded)
        contents = ok and decoded or false -- false: malformed reply, stop waiting
        return true -- delete this autocmd
      end
    end,
  })
  vim.api.nvim_ui_send(string.format('\027]52;%s;?\027\\', reg == '+' and 'c' or 'p'))
  local ok = vim.wait(tonumber(vim.g.osc52_paste_timeout) or 1000, function() return contents ~= nil end)
  if not ok then
    pcall(vim.api.nvim_del_autocmd, id)
    return nil
  end
  if not contents then return nil end
  return vim.split(contents, '\n')
end

local function paste(reg)
  return function()
    local lines
    if has_tmux and reg == '+' then
      local out = vim.fn.systemlist({ 'tmux', 'save-buffer', '-' }, '', 1)
      if vim.v.shell_error == 0 then lines = out end
    end
    if not lines and vim.g.osc52_paste ~= false then lines = osc52_query(reg) end
    if not lines then return last(reg) end
    -- Same text as our last copy: keep its regtype (linewise yanks stay linewise).
    if last_copy[reg] and vim.deep_equal(lines, last_copy[reg][1]) then return last(reg) end
    return lines
  end
end

vim.g.clipboard = {
  name = 'osc52-tmux',
  copy = { ['+'] = copy '+', ['*'] = copy '*' },
  paste = { ['+'] = paste '+', ['*'] = paste '*' },
  cache_enabled = 0,
}
