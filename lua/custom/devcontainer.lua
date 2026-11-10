-- Devcontainer helpers. Neovim calls host scripts so a private GitHub repo
-- is not required: local checkout is copied into the container.
--
--   :DcUp [args]  myubuntu/myubuntu/devcontainer-up.sh
--   :DcRe [args]  same with --remove-existing-container
--   :DcIn [cmd]   myubuntu/myubuntu/devcontainer-exec.sh
--   :DcInW [cmd]  same with --wait (until zsh exists)
--   :DcReopen     reopen cwd in the container: up if not running, re-copy
--                 the nvim config, `Lazy! restore` on lockfile drift, then
--                 open container Neovim (new tmux window, else a terminal tab)
--                 with the host buffers, splits and cursors (paths mapped
--                 through the container's bind mounts)
--   :DcReopenLocal  in container Neovim: hand the session back to host
--                 Neovim and quit (<leader>dl)
--   :DcRestoreLocal on the host: restore that session by hand (normally
--                 automatic when the container shell ends, or on focus)
--
-- Workspace folder = $DEVCONTAINER_PATH or cwd.
-- Loaded from lua/custom/plugins/devcontainer.lua (a lazy virtual spec).
local M = {}

M.config = {
  local_repo = vim.fn.expand '~/.dotfiles',
  up_script = 'myubuntu/myubuntu/devcontainer-up.sh',
  exec_script = 'myubuntu/myubuntu/devcontainer-exec.sh',
  -- Stow package holding this config, relative to local_repo. Its
  -- `.config/nvim` subtree is re-copied to the container's ~/dotfiles/nvim.
  nvim_package = 'nvim',
}

local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO, { title = 'Devcontainer' }) end

local function workspace() return vim.env.DEVCONTAINER_PATH or vim.fn.getcwd() end

local function script_path(rel)
  local path = M.config.local_repo .. '/' .. rel
  if vim.fn.filereadable(path) ~= 1 then
    notify('Missing ' .. path .. ' — is ~/.dotfiles the checkout?', vim.log.levels.ERROR)
    return nil
  end
  return path
end

-- Opens a terminal split running `cmd`. `on_exit(code, buf)` is optional.
local function open_terminal(cmd, title, on_exit)
  vim.cmd 'botright 15split'
  vim.cmd.enew()
  local buf = vim.api.nvim_get_current_buf()
  vim.fn.jobstart(cmd, {
    term = true,
    cwd = workspace(),
    env = { DEVCONTAINER_PATH = workspace() },
    on_exit = on_exit and function(_, code)
      vim.schedule(function() on_exit(code, buf) end)
    end or nil,
  })
  vim.bo.buflisted = false
  pcall(vim.api.nvim_buf_set_name, 0, title)
  vim.cmd.startinsert()
end

function M.up(extra_args)
  local script = script_path(M.config.up_script)
  if not script then return end
  local ws = workspace()
  notify(('Booting devcontainer in %s (local dotfiles inject)...'):format(ws))
  local cmd = { 'bash', script }
  vim.list_extend(cmd, extra_args or {})
  open_terminal(cmd, 'devcontainer up')
end

function M.rebuild(extra_args)
  local args = { '--remove-existing-container' }
  vim.list_extend(args, extra_args or {})
  M.up(args)
end

function M.exec(cmd)
  local script = script_path(M.config.exec_script)
  if not script then return end
  if cmd and cmd ~= '' then
    notify('Executing inside container: ' .. cmd)
  else
    notify 'Dropping into container shell...'
  end
  local argv = { 'bash', script }
  if cmd and cmd ~= '' then table.insert(argv, cmd) end
  open_terminal(argv, 'devcontainer shell')
end

function M.wait_then_exec(cmd)
  local script = script_path(M.config.exec_script)
  if not script then return end
  notify 'Waiting for container and zsh...'
  local argv = { 'bash', script, '--wait' }
  if cmd and cmd ~= '' then table.insert(argv, cmd) end
  open_terminal(argv, 'devcontainer shell')
end

-- [[ Reopen in container ]]

-- POSIX single-quote escaping for bash/sh/zsh. Not `vim.fn.shellescape`:
-- that follows 'shell' (fish/csh rules) but these strings always run in bash.
local function sh_quote(s) return "'" .. tostring(s):gsub("'", [['\'']]) .. "'" end

--- Devcontainer config for `ws`, following `find_devcontainer_config` in
--- myubuntu/_lib.sh. Returns `found, config_arg, err`: `config_arg` is the
--- value the scripts pass as `--config` (nil for the default locations).
function M.find_config(ws)
  local env_config = vim.env.DEVCONTAINER_CONFIG
  if env_config and env_config ~= '' then
    if vim.fn.filereadable(env_config) == 1 then return true, env_config end
    return false, nil, 'DEVCONTAINER_CONFIG points to a missing file: ' .. env_config
  end
  if vim.fn.filereadable(ws .. '/.devcontainer/devcontainer.json') == 1 or vim.fn.filereadable(ws .. '/.devcontainer.json') == 1 then return true, nil end
  local nested = vim.fn.glob(ws .. '/.devcontainer/*/devcontainer.json', true, true)
  if #nested == 1 then return true, nested[1] end
  if #nested == 0 then return false, nil, 'No devcontainer config in ' .. ws .. ' (.devcontainer/devcontainer.json or .devcontainer.json)' end
  return false, nil, 'Multiple devcontainer configs under ' .. ws .. '/.devcontainer; set DEVCONTAINER_CONFIG to one of them'
end

--- Path of the devcontainer CLI, or nil. Same lookup as `find_devcontainer_bin`.
function M.find_cli()
  local exe = vim.fn.exepath 'devcontainer'
  if exe ~= '' then return exe end
  local fallback = vim.fn.expand '~/.devcontainers/bin/devcontainer'
  if vim.fn.executable(fallback) == 1 then return fallback end
  return nil
end

--- Checks that reopen can work for `ws`. Returns an error string or nil.
--- Order: config, devcontainer CLI, scripts, docker daemon.
function M.preflight(ws)
  local found, _, err = M.find_config(ws)
  if not found then return err end
  if not M.find_cli() then return 'devcontainer CLI not found (install @devcontainers/cli or add ~/.devcontainers/bin to PATH)' end
  for _, rel in ipairs { M.config.up_script, M.config.exec_script } do
    local path = M.config.local_repo .. '/' .. rel
    if vim.fn.filereadable(path) ~= 1 then return 'Missing ' .. path .. ' (is ~/.dotfiles the checkout?)' end
  end
  if vim.fn.executable 'docker' ~= 1 then return 'docker CLI not found' end
  local ok, res = pcall(function() return vim.system({ 'docker', 'info' }, { text = true }):wait(10000) end)
  if not ok or res.code ~= 0 then return 'docker daemon not running (`docker info` failed)' end
  return nil
end

--- Id of the running container for `ws`, or nil. The devcontainer CLI labels
--- containers (compose ones too) with devcontainer.local_folder.
function M.container_id(ws)
  -- The CLI stores the resolved workspace path: no trailing slash.
  local abs = function(p) return vim.fs.normalize(vim.fn.fnamemodify(p, ':p')) end
  local argv = { 'docker', 'ps', '-q', '--filter', 'label=devcontainer.local_folder=' .. abs(ws) }
  -- A non-default config has its own container: match it too.
  local _, config = M.find_config(ws)
  if config then vim.list_extend(argv, { '--filter', 'label=devcontainer.config_file=' .. abs(config) }) end
  local ok, res = pcall(function() return vim.system(argv, { text = true }):wait(10000) end)
  if not ok or res.code ~= 0 then return nil end
  return vim.trim(res.stdout or ''):match '^(%S+)'
end

-- Runs in the container (bash -lc) with the config tarball on stdin.
-- Replaces the contents of ~/dotfiles/nvim/.config/nvim (the directory
-- itself stays, so a stow link to it stays valid; files deleted on the host
-- disappear), then compares lazy-lock.json with the installed plugin
-- commits and runs `Lazy! restore` on any difference. Plugins with no
-- install dir (disabled in the container) are not counted as drift.
local remote_sync = [[
set -eu
dst="$HOME/dotfiles/nvim/.config/nvim"
tmp="$(mktemp -d)"
trap 'find "$tmp" -delete' EXIT
tar -xzf - -C "$tmp"
mkdir -p "$dst"
find "$dst" -mindepth 1 -delete
cp -a "$tmp/.config/nvim/." "$dst/"
lock="$dst/lazy-lock.json"
root="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy"
drift=0
while read -r name commit; do
  [ -d "$root/$name" ] || continue
  if [ "$(git -C "$root/$name" rev-parse HEAD 2>/dev/null)" != "$commit" ]; then
    drift=1
    break
  fi
done < <(sed -n 's/^ *"\([^"]*\)": *{.*"commit": *"\([0-9a-f]*\)".*/\1 \2/p' "$lock")
if [ "$drift" -eq 1 ]; then
  echo '[devcontainer] plugins differ from host lazy-lock.json; running Lazy! restore'
  nvim --headless '+Lazy! restore' +qa
else
  echo '[devcontainer] plugins match host lazy-lock.json'
fi
]]

local function shell_join(argv) return table.concat(vim.tbl_map(sh_quote, argv), ' ') end

-- `devcontainer <sub> --workspace-folder ws [--config c]` argv prefix.
local function cli_argv(sub, ws)
  local _, config = M.find_config(ws)
  local argv = { M.find_cli(), sub, '--workspace-folder', ws }
  if config then vim.list_extend(argv, { '--config', config }) end
  return argv
end

--- Shell command (string) that re-copies the host config into the container.
function M.sync_command(ws)
  local exec = cli_argv('exec', ws)
  vim.list_extend(exec, { 'bash', '-lc', remote_sync })
  local src = M.config.local_repo .. '/' .. M.config.nvim_package
  local tar = { 'tar', '-C', src, '--exclude=.git', '--exclude=*.log', '--exclude=.claude', '-czf', '-', '.config/nvim' }
  return 'set -o pipefail; echo '
    .. sh_quote('[devcontainer] copying ' .. src .. '/.config/nvim -> container ~/dotfiles/nvim')
    .. '; '
    .. shell_join(tar)
    .. ' | '
    .. shell_join(exec)
end

-- Host shell snippet run after the container shell ends: when container
-- Neovim left a session at `host_file` (reopen locally), tell this Neovim
-- to restore it and focus its tmux window. nil when there is no server.
local function back_hook(host_file)
  local sock = vim.v.servername
  if not host_file or not sock or sock == '' then return nil end
  local expr = [[luaeval('vim.schedule(require("custom.devcontainer").restore_local)')]]
  local hook = 'if [ -f ' .. sh_quote(host_file) .. ' ]; then ' .. shell_join { vim.v.progpath, '--server', sock, '--remote-expr', expr } .. ' >/dev/null 2>&1;'
  if vim.env.TMUX_PANE and vim.env.TMUX_PANE ~= '' then hook = hook .. ' tmux select-window -t ' .. sh_quote(vim.env.TMUX_PANE) .. ' 2>/dev/null;' end
  return hook .. ' fi'
end

--- Opens container Neovim for `ws`. `nvim_args` (list) is appended to the
--- `nvim` command line (session sync passes its restore args here).
--- `return_file` (host path, optional) is where reopen-locally will leave
--- the container session; it is restored here once the container shell ends.
--- Inside tmux: new tmux window. Otherwise: fullscreen terminal tab.
function M.launch(ws, nvim_args, return_file)
  local script = script_path(M.config.exec_script)
  if not script then return end
  local nvim_cmd = { 'nvim' }
  vim.list_extend(nvim_cmd, nvim_args or {})
  -- `&& exit` closes the container shell when Neovim quits cleanly.
  local remote = shell_join(nvim_cmd) .. ' && exit'
  local env = { DEVCONTAINER_PATH = ws }
  if vim.env.DEVCONTAINER_CONFIG and vim.env.DEVCONTAINER_CONFIG ~= '' then env.DEVCONTAINER_CONFIG = vim.env.DEVCONTAINER_CONFIG end

  if vim.env.TMUX and vim.env.TMUX ~= '' and vim.fn.executable 'tmux' == 1 then
    -- The tmux server environment is not ours: pass env on the command line.
    local parts = {}
    for k, v in pairs(env) do
      table.insert(parts, k .. '=' .. sh_quote(v))
    end
    -- On failure keep the window open so the error stays readable.
    local shell_cmd = table.concat(parts, ' ')
      .. ' bash '
      .. sh_quote(script)
      .. ' '
      .. sh_quote(remote)
      .. ' || { echo; read -r -p "devcontainer exec failed; press Enter to close " _; }'
    local hook = back_hook(return_file)
    if hook then shell_cmd = shell_cmd .. '; ' .. hook end
    -- Run through bash, not tmux's default-shell: `read -p` is bash syntax.
    local res = vim.system({ 'tmux', 'new-window', '-c', ws, '-n', 'devc', 'bash', '-c', shell_cmd }, { text = true }):wait()
    if res.code ~= 0 then notify('tmux new-window failed: ' .. vim.trim(res.stderr or ''), vim.log.levels.ERROR) end
    return
  end

  vim.cmd.tabnew()
  local buf = vim.api.nvim_get_current_buf()
  vim.fn.jobstart({ 'bash', script, remote }, {
    term = true,
    cwd = ws,
    env = env,
    on_exit = function(_, code)
      vim.schedule(function()
        if code == 0 and vim.api.nvim_buf_is_valid(buf) then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
        if return_file and vim.fn.filereadable(return_file) == 1 then M.restore_local() end
      end)
    end,
  })
  vim.bo.buflisted = false
  pcall(vim.api.nvim_buf_set_name, 0, 'devcontainer nvim')
  vim.cmd.startinsert()
end

-- [[ Session sync ]]
--
-- A session is JSON, not `:mksession` output:
--   { version = 1, cwd, tabs = { { layout, current } }, buffers = { path }, return_file }
-- `layout` is `winlayout()` with each leaf `{ 'leaf', { file, view, current } }`.
-- Only file windows are kept; terminals, help, trees and unnamed buffers are not.

M.session_name = '.nvim-session.json'
-- A `.nvim-session.json` found by scanning mounts is ignored when older.
local stale_after = 600
-- Host side: return files of open container sessions -> { ws, mounts }.
M._pending = {}

local uv = vim.uv or vim.loop

--- Bind mounts of container `id` as `{ { Source, Destination } }`, or nil.
function M.mounts(id)
  local ok, res = pcall(function() return vim.system({ 'docker', 'inspect', '-f', '{{json .Mounts}}', id }, { text = true }):wait(10000) end)
  if not ok or res.code ~= 0 then return nil end
  local okj, list = pcall(vim.json.decode, vim.trim(res.stdout or ''))
  if not okj or type(list) ~= 'table' then return nil end
  local out = {}
  for _, m in ipairs(list) do
    if m.Type == 'bind' and type(m.Source) == 'string' and type(m.Destination) == 'string' then
      table.insert(out, { Source = m.Source, Destination = m.Destination })
    end
  end
  return out
end

--- Maps `path` through `mounts`: dir 'in' host -> container, 'out' container
--- -> host. Longest prefix wins, matched on whole path components. nil when
--- no mount covers the path.
function M.map_path(path, mounts, dir)
  if type(path) ~= 'string' or path == '' then return nil end
  local from_key, to_key = 'Source', 'Destination'
  if dir == 'out' then
    from_key, to_key = 'Destination', 'Source'
  end
  path = vim.fs.normalize(path)
  local best_len, best_to, best_rest
  for _, m in ipairs(mounts or {}) do
    local from, to = m[from_key], m[to_key]
    if type(from) == 'string' and from ~= '' and type(to) == 'string' and to ~= '' then
      from = vim.fs.normalize(from)
      local rest
      if path == from then
        rest = ''
      elseif from == '/' then
        rest = path:sub(2)
      elseif path:sub(1, #from + 1) == from .. '/' then
        rest = path:sub(#from + 2)
      end
      if rest and (not best_len or #from > best_len) then
        best_len, best_to, best_rest = #from, vim.fs.normalize(to), rest
      end
    end
  end
  if not best_len then return nil end
  if best_rest == '' then return best_to end
  return (best_to == '/' and '' or best_to) .. '/' .. best_rest
end

-- Rebuilds a layout tree with `fn(leaf_data)` (nil drops the leaf). A split
-- left with one child collapses to it; an empty one is dropped.
local function map_layout(node, fn)
  if type(node) ~= 'table' then return nil end
  if node[1] == 'leaf' then
    local data = fn(node[2])
    return data and { 'leaf', data } or nil
  end
  local kids = {}
  for _, child in ipairs(node[2] or {}) do
    local m = map_layout(child, fn)
    if m then table.insert(kids, m) end
  end
  if #kids == 0 then return nil end
  if #kids == 1 then return kids[1] end
  return { node[1], kids }
end

--- Maps every path of `session` through `mounts` (see `map_path`). Returns
--- `mapped, skipped`: unmapped windows/buffers are dropped and their paths
--- listed once in `skipped`. `cwd` becomes nil when unmapped. Pure.
function M.translate(session, mounts, dir)
  local skipped, seen = {}, {}
  local function map(p)
    local m = M.map_path(p, mounts, dir)
    if not m and dir == 'in' then
      -- Host checkout behind a symlink: docker reports the resolved path.
      local real = uv.fs_realpath(p)
      if real and real ~= p then m = M.map_path(real, mounts, dir) end
    end
    if not m and not seen[p] then
      seen[p] = true
      table.insert(skipped, p)
    end
    return m
  end
  local out = { version = session.version or 1, tabs = {}, buffers = {} }
  if session.cwd then
    out.cwd = M.map_path(session.cwd, mounts, dir)
    local real = not out.cwd and dir == 'in' and uv.fs_realpath(session.cwd)
    if real then out.cwd = M.map_path(real, mounts, dir) end
  end
  for _, tab in ipairs(session.tabs or {}) do
    local layout = map_layout(tab.layout, function(d)
      local f = map(d.file)
      return f and { file = f, view = vim.deepcopy(d.view), current = d.current } or nil
    end)
    if layout then table.insert(out.tabs, { layout = layout, current = tab.current }) end
  end
  for _, p in ipairs(session.buffers or {}) do
    local f = map(p)
    if f then table.insert(out.buffers, f) end
  end
  return out, skipped
end

-- Absolute path of a normal file buffer, else nil.
local function file_of(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= '' then return nil end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == '' or name:match '^%a[%w+.-]*://' then return nil end
  return vim.fs.normalize(vim.fn.fnamemodify(name, ':p'))
end

--- Session of this Neovim (local paths): tabs, file windows with cursor
--- views, and the other listed file buffers.
function M.capture()
  local cur_tab, cur_win = vim.api.nvim_get_current_tabpage(), vim.api.nvim_get_current_win()
  local session = { version = 1, cwd = vim.fs.normalize(vim.fn.getcwd()), tabs = {}, buffers = {} }
  local shown = {}
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local layout = map_layout(vim.fn.winlayout(vim.api.nvim_tabpage_get_number(tab)), function(win)
      local file = file_of(vim.api.nvim_win_get_buf(win))
      if not file then return nil end
      shown[file] = true
      local v = vim.api.nvim_win_call(win, vim.fn.winsaveview)
      return { file = file, view = { lnum = v.lnum, col = v.col, topline = v.topline, leftcol = v.leftcol }, current = win == cur_win or nil }
    end)
    if layout then table.insert(session.tabs, { layout = layout, current = tab == cur_tab or nil }) end
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local file = vim.bo[buf].buflisted and file_of(buf)
    if file and not shown[file] then
      shown[file] = true
      table.insert(session.buffers, file)
    end
  end
  return session
end

-- Splits `win` (right for 'row', below for 'col'); returns the new window.
local function split_win(win, kind)
  return vim.api.nvim_win_call(win, function()
    vim.cmd(kind == 'row' and 'rightbelow vsplit' or 'rightbelow split')
    return vim.api.nvim_get_current_win()
  end)
end

local function open_layout(node, win, state)
  if node[1] == 'leaf' then
    local d = node[2]
    vim.api.nvim_win_call(win, function()
      if pcall(vim.cmd.edit, vim.fn.fnameescape(d.file)) and type(d.view) == 'table' then pcall(vim.fn.winrestview, d.view) end
    end)
    if d.current then state.win = win end
    return
  end
  local wins = { win }
  for i = 2, #node[2] do
    wins[i] = split_win(wins[i - 1], node[1])
  end
  for i, child in ipairs(node[2]) do
    open_layout(child, wins[i], state)
  end
end

--- Replaces this Neovim's tabs with `session` (paths already local). Tabs
--- that existed before are closed; their buffers stay loaded.
function M.apply(session)
  if session.cwd and vim.fn.isdirectory(session.cwd) == 1 then vim.cmd.cd(vim.fn.fnameescape(session.cwd)) end
  for _, file in ipairs(session.buffers or {}) do
    vim.cmd.badd(vim.fn.fnameescape(file))
  end
  if #(session.tabs or {}) == 0 then return end

  local old_tabs = vim.api.nvim_list_tabpages()
  local state, target_tab = {}, nil
  for _, tab in ipairs(session.tabs) do
    vim.cmd.tabnew()
    open_layout(tab.layout, vim.api.nvim_get_current_win(), state)
    vim.cmd 'wincmd ='
    if tab.current then target_tab = vim.api.nvim_get_current_tabpage() end
  end
  for _, tab in ipairs(old_tabs) do
    if vim.api.nvim_tabpage_is_valid(tab) then pcall(vim.cmd.tabclose, vim.api.nvim_tabpage_get_number(tab)) end
  end
  -- Drop the empty scratch buffers left by `tabnew` and the startup buffer.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.api.nvim_buf_is_valid(buf)
      and vim.api.nvim_buf_get_name(buf) == ''
      and vim.bo[buf].buftype == ''
      and not vim.bo[buf].modified
      and vim.fn.bufwinid(buf) == -1
      and vim.api.nvim_buf_line_count(buf) == 1
      and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ''
    then
      pcall(vim.api.nvim_buf_delete, buf, {})
    end
  end
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
  elseif target_tab and vim.api.nvim_tabpage_is_valid(target_tab) then
    vim.api.nvim_set_current_tabpage(target_tab)
  end
  pcall(vim.cmd.checktime)
end

local json_opts = { luanil = { object = true, array = true } }

-- Reads and deletes a session file. Returns `session` or `nil, err`.
local function take_session(path)
  local fd = io.open(path, 'r')
  if not fd then return nil, 'Cannot read session file ' .. path end
  local text = fd:read '*a'
  fd:close()
  os.remove(path)
  local ok, s = pcall(vim.json.decode, text, json_opts)
  if not ok or type(s) ~= 'table' or s.version ~= 1 or type(s.tabs) ~= 'table' then return nil, 'Invalid session file ' .. path end
  return s
end

local function write_session(path, session)
  local fd, err = io.open(path, 'w')
  if not fd then return false, err end
  fd:write(vim.json.encode(session))
  fd:close()
  return true
end

local function report_skipped(skipped, why)
  if #skipped == 0 then return end
  local names = vim.tbl_map(function(p) return vim.fn.fnamemodify(p, ':~:.') end, skipped)
  notify(('Skipped (%s): %s'):format(why, table.concat(names, ', ')), vim.log.levels.WARN)
end

--- `workspaceFolder` of the devcontainer config for `ws` (container path),
--- via `devcontainer read-configuration`. nil on failure.
function M.workspace_folder(ws)
  if not M.find_cli() then return nil end
  local ok, res = pcall(function() return vim.system(cli_argv('read-configuration', ws), { text = true }):wait(30000) end)
  if not ok or res.code ~= 0 then return nil end
  local lines = vim.split(res.stdout or '', '\n', { trimempty = true })
  for i = #lines, 1, -1 do
    if lines[i]:match '^%s*{' then
      local okj, t = pcall(vim.json.decode, lines[i], json_opts)
      if okj and type(t) == 'table' then
        local folder = (type(t.workspace) == 'table' and t.workspace.workspaceFolder) or (type(t.configuration) == 'table' and t.configuration.workspaceFolder)
        if type(folder) == 'string' and folder:sub(1, 1) == '/' then return folder end
      end
    end
  end
  return nil
end

-- Translates `session` (host paths) for the running container of `ws`,
-- copies it in, and returns `nvim_args, host_return_file`. Any failure
-- gives a warning and `{}`: the container opens without a session.
local function send_session(ws, session)
  local id = M.container_id(ws)
  local mounts = id and M.mounts(id)
  if not mounts then
    notify('Cannot read the container mounts (docker inspect); opening without the session', vim.log.levels.WARN)
    return {}
  end
  local mapped, skipped = M.translate(session, mounts, 'in')
  report_skipped(skipped, 'outside container mounts')
  mapped.cwd = mapped.cwd or M.workspace_folder(ws)

  -- Reopen-locally writes back next to the container cwd when the host can see it.
  local host_return
  if mapped.cwd and M.map_path(mapped.cwd, mounts, 'out') then
    mapped.return_file = (mapped.cwd == '/' and '' or mapped.cwd) .. '/' .. M.session_name
    host_return = M.map_path(mapped.return_file, mounts, 'out')
  end

  local remote = ('/tmp/nvim-dc-session-%d-%d.json'):format(vim.fn.getpid(), os.time())
  local argv = cli_argv('exec', ws)
  vim.list_extend(argv, { 'sh', '-c', 'umask 077 && cat > "$1"', 'sh', remote })
  local ok, res = pcall(function() return vim.system(argv, { stdin = vim.json.encode(mapped), text = true }):wait(30000) end)
  if not ok or res.code ~= 0 then
    notify('Could not copy the session into the container; opening without it', vim.log.levels.WARN)
    return {}
  end
  if host_return then M._pending[host_return] = { ws = ws, mounts = mounts } end
  return { '-c', ('lua require("custom.devcontainer").restore(%q)'):format(remote) }, host_return
end

--- Container side: restores the session in `file` (container paths) and
--- deletes it. Called from `nvim -c` by reopen-in-container.
function M.restore(file)
  local function run()
    local session, err = take_session(file)
    if not session then
      notify(err, vim.log.levels.WARN)
      return
    end
    if session.return_file then vim.g.devcontainer_return_file = session.return_file end
    M.apply(session)
  end
  if vim.v.vim_did_enter == 1 then
    run()
  else
    vim.api.nvim_create_autocmd('VimEnter', { once = true, callback = function() vim.schedule(run) end })
  end
end

--- Container side: saves this session where host Neovim picks it up, then
--- quits. Host Neovim restores it when the container shell ends (or on
--- focus / `:DcRestoreLocal`).
function M.reopen_local()
  if not require('custom.util').in_container() then
    notify('Reopen locally works in container Neovim; on the host use :DcRestoreLocal', vim.log.levels.WARN)
    return
  end
  local modified = vim.tbl_filter(function(b) return vim.bo[b].buflisted and vim.bo[b].modified end, vim.api.nvim_list_bufs())
  if #modified > 0 then
    if vim.fn.confirm(('%d modified buffer(s). Save all and reopen locally?'):format(#modified), '&Save all\n&Cancel', 2) ~= 1 then
      notify 'Reopen locally cancelled'
      return
    end
    local ok, err = pcall(vim.cmd.wall)
    if not ok then
      notify('Save failed, reopen locally cancelled: ' .. tostring(err), vim.log.levels.ERROR)
      return
    end
  end
  local file = vim.g.devcontainer_return_file or (vim.fs.normalize(vim.fn.getcwd()) .. '/' .. M.session_name)
  local ok, err = write_session(file, M.capture())
  if not ok then
    notify('Cannot write ' .. file .. ': ' .. tostring(err), vim.log.levels.ERROR)
    return
  end
  vim.cmd 'confirm qall'
end

local function fresh(path)
  local st = uv.fs_stat(path)
  return st and st.type == 'file' and os.time() - st.mtime.sec <= stale_after
end

--- Host side: restores the session container Neovim left with reopen
--- locally. Looks at pending return files first, then at
--- `<bind mount Source>/.nvim-session.json` of the container for cwd.
function M.restore_local()
  local file, entry
  for f, e in pairs(M._pending) do
    if vim.fn.filereadable(f) == 1 then
      file, entry = f, e
      break
    end
  end
  if not file then
    local ws = workspace()
    local id = M.container_id(ws)
    local mounts = id and M.mounts(id)
    if not mounts then
      notify('No session to restore: no running container for ' .. ws, vim.log.levels.WARN)
      return
    end
    for _, m in ipairs(mounts) do
      local f = vim.fs.normalize(m.Source) .. '/' .. M.session_name
      if fresh(f) then
        file, entry = f, { ws = ws, mounts = mounts }
        break
      end
    end
    if not file then
      notify('No ' .. M.session_name .. ' in the container mounts of ' .. ws, vim.log.levels.WARN)
      return
    end
  end
  M._pending[file] = nil
  local session, err = take_session(file)
  if not session then
    notify(err, vim.log.levels.WARN)
    return
  end
  local mapped, skipped = M.translate(session, entry.mounts, 'out')
  -- Keep the host cwd: it is the folder `:DcReopen` works on.
  mapped.cwd = nil
  report_skipped(skipped, 'no host path')
  M.apply(mapped)
  notify 'Restored the container session'
end

--- Reopen the workspace in its devcontainer. Attaches when the container
--- is running; otherwise runs the up script first. Never rebuilds.
--- The host session (buffers, splits, cursors) is restored in the container.
function M.reopen()
  local ws = workspace()
  local err = M.preflight(ws)
  if err then
    notify(err, vim.log.levels.ERROR)
    return
  end

  local steps = {}
  if M.container_id(ws) then
    notify('Container running for ' .. ws .. '; attaching')
  else
    notify('No running container for ' .. ws .. '; starting it first')
    table.insert(steps, 'bash ' .. sh_quote(M.config.local_repo .. '/' .. M.config.up_script))
  end
  table.insert(steps, M.sync_command(ws))
  -- Snapshot now: the terminal split below is not part of the session.
  local session = M.capture()

  -- Group each step: sync_command contains `;`, so a bare `a && b; c` would run c after a failed.
  local script = table.concat(vim.tbl_map(function(s) return '{ ' .. s .. '; }' end, steps), ' && ')
  open_terminal({ 'bash', '-c', script }, 'devcontainer reopen', function(code, buf)
    if code ~= 0 then
      notify(('Reopen in container failed (exit %d); see the terminal split'):format(code), vim.log.levels.ERROR)
      return
    end
    if vim.api.nvim_buf_is_valid(buf) then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
    M.launch(ws, send_session(ws, session))
  end)
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})

  -- List the CLI in `:checkhealth custom` only when the scripts' lookup
  -- (PATH, then ~/.devcontainers/bin) cannot find it.
  if not M.find_cli() then require('custom.util').register('devcontainer', 'devcontainer commands (:DcUp, :DcReopen, ...)') end

  local cmd = vim.api.nvim_create_user_command
  cmd('DcUp', function(o) M.up(o.fargs) end, { nargs = '*', desc = 'devcontainer up (local dotfiles inject)' })
  cmd('DcRe', function(o) M.rebuild(o.fargs) end, { nargs = '*', desc = 'devcontainer up --remove-existing-container' })
  cmd('DcIn', function(o) M.exec(o.args) end, { nargs = '*', desc = 'Shell into devcontainer (optional command)' })
  cmd('DcInW', function(o) M.wait_then_exec(o.args) end, { nargs = '*', desc = 'Wait for zsh, then shell in' })
  cmd('DcReopen', function() M.reopen() end, { nargs = 0, desc = 'Reopen cwd in devcontainer (attach if running)' })
  cmd('DcReopenLocal', function() M.reopen_local() end, { nargs = 0, desc = 'Container Neovim: hand the session back to host Neovim and quit' })
  cmd('DcRestoreLocal', function() M.restore_local() end, { nargs = 0, desc = 'Host Neovim: restore the session left by :DcReopenLocal' })

  -- Fallback when the push from the tmux window did not reach us.
  vim.api.nvim_create_autocmd('FocusGained', {
    group = vim.api.nvim_create_augroup('custom-devcontainer-session', { clear = true }),
    callback = function()
      for f in pairs(M._pending) do
        if vim.fn.filereadable(f) == 1 then return M.restore_local() end
      end
    end,
  })

  local map = function(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { desc = desc }) end
  map('<leader>du', M.up, '[D]evcontainer [U]p')
  map('<leader>dr', M.rebuild, '[D]evcontainer [R]ebuild')
  map('<leader>di', M.exec, '[D]evcontainer shell [I]n')
  map('<leader>dw', M.wait_then_exec, '[D]evcontainer [W]ait + shell in')
  map('<leader>do', M.reopen, '[D]evcontainer re[O]pen in container')
  map('<leader>dl', M.reopen_local, '[D]evcontainer reopen [L]ocally')
end

return M
