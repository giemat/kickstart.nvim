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

--- Devcontainer config for `ws`, following `find_devcontainer_config` in
--- myubuntu/_lib.sh. Returns `found, config_arg, err`: `config_arg` is the
--- value the scripts pass as `--config` (nil for the default locations).
function M.find_config(ws)
  local env_config = vim.env.DEVCONTAINER_CONFIG
  if env_config and env_config ~= '' then return true, env_config end
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
  local ok, res = pcall(
    function() return vim.system({ 'docker', 'ps', '-q', '--filter', 'label=devcontainer.local_folder=' .. ws }, { text = true }):wait(10000) end
  )
  if not ok or res.code ~= 0 then return nil end
  return vim.trim(res.stdout or ''):match '^(%S+)'
end

-- Runs in the container (bash -lc) with the config tarball on stdin.
-- Extracts it into ~/dotfiles/nvim, then compares lazy-lock.json with the
-- installed plugin commits and runs `Lazy! restore` on any difference.
local remote_sync = [[
set -eu
mkdir -p "$HOME/dotfiles/nvim"
tar -xzf - -C "$HOME/dotfiles/nvim"
lock="$HOME/dotfiles/nvim/.config/nvim/lazy-lock.json"
root="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy"
drift=0
while read -r name commit; do
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

local function shell_join(argv) return table.concat(vim.tbl_map(vim.fn.shellescape, argv), ' ') end

--- Shell command (string) that re-copies the host config into the container.
function M.sync_command(ws)
  local _, config = M.find_config(ws)
  local exec = { M.find_cli(), 'exec', '--workspace-folder', ws }
  if config then vim.list_extend(exec, { '--config', config }) end
  vim.list_extend(exec, { 'bash', '-lc', remote_sync })
  local src = M.config.local_repo .. '/' .. M.config.nvim_package
  local tar = { 'tar', '-C', src, '-czf', '-', '.config/nvim' }
  return 'set -o pipefail; echo '
    .. vim.fn.shellescape('[devcontainer] copying ' .. src .. '/.config/nvim -> container ~/dotfiles/nvim')
    .. '; '
    .. shell_join(tar)
    .. ' | '
    .. shell_join(exec)
end

--- Opens container Neovim for `ws`. `nvim_args` (list) is appended to the
--- `nvim` command line; session sync (slice 9) passes its args here.
--- Inside tmux: new tmux window. Otherwise: fullscreen terminal tab.
function M.launch(ws, nvim_args)
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
      table.insert(parts, k .. '=' .. vim.fn.shellescape(v))
    end
    local shell_cmd = table.concat(parts, ' ') .. ' bash ' .. vim.fn.shellescape(script) .. ' ' .. vim.fn.shellescape(remote)
    local res = vim.system({ 'tmux', 'new-window', '-c', ws, '-n', 'devc', shell_cmd }, { text = true }):wait()
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
      end)
    end,
  })
  vim.bo.buflisted = false
  pcall(vim.api.nvim_buf_set_name, 0, 'devcontainer nvim')
  vim.cmd.startinsert()
end

--- Reopen the workspace in its devcontainer. Attaches when the container
--- is running; otherwise runs the up script first. Never rebuilds.
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
    table.insert(steps, 'bash ' .. vim.fn.shellescape(M.config.local_repo .. '/' .. M.config.up_script))
  end
  table.insert(steps, M.sync_command(ws))

  open_terminal({ 'bash', '-c', table.concat(steps, ' && ') }, 'devcontainer reopen', function(code, buf)
    if code ~= 0 then
      notify(('Reopen in container failed (exit %d); see the terminal split'):format(code), vim.log.levels.ERROR)
      return
    end
    if vim.api.nvim_buf_is_valid(buf) then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
    M.launch(ws)
  end)
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})

  local util = require 'custom.util'
  util.register('devcontainer', 'devcontainer commands (:DcUp, :DcReopen, ...)')
  util.register('docker', 'devcontainer commands (:DcUp, :DcReopen, ...)')

  local cmd = vim.api.nvim_create_user_command
  cmd('DcUp', function(o) M.up(o.fargs) end, { nargs = '*', desc = 'devcontainer up (local dotfiles inject)' })
  cmd('DcRe', function(o) M.rebuild(o.fargs) end, { nargs = '*', desc = 'devcontainer up --remove-existing-container' })
  cmd('DcIn', function(o) M.exec(o.args) end, { nargs = '*', desc = 'Shell into devcontainer (optional command)' })
  cmd('DcInW', function(o) M.wait_then_exec(o.args) end, { nargs = '*', desc = 'Wait for zsh, then shell in' })
  cmd('DcReopen', function() M.reopen() end, { nargs = 0, desc = 'Reopen cwd in devcontainer (attach if running)' })

  local map = function(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { desc = desc }) end
  map('<leader>du', M.up, '[D]evcontainer [U]p')
  map('<leader>dr', M.rebuild, '[D]evcontainer [R]ebuild')
  map('<leader>di', M.exec, '[D]evcontainer shell [I]n')
  map('<leader>dw', M.wait_then_exec, '[D]evcontainer [W]ait + shell in')
  map('<leader>do', M.reopen, '[D]evcontainer re[O]pen in container')
end

return M
