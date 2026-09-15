-- Devcontainer helpers: Neovim port of the `dcup` / `dcre` / `dcin` / `dcinw`
-- zsh functions. Wraps the `devcontainer` CLI and injects dotfiles on `up`.
--
-- Commands:
--   :DcUp [args]   devcontainer up (with dotfiles injection), extra args passed through
--   :DcRe [args]   same as :DcUp --remove-existing-container
--   :DcIn [cmd]    interactive zsh in container (direnv loaded), optional cmd runs first
--   :DcInW [cmd]   wait until container answers, then :DcIn
--
-- Workspace folder = $DEVCONTAINER_PATH or the current working directory.
local M = {}

M.config = {
  dotfiles_repo = 'https://github.com/giemat/.dotfiles',
  dotfiles_target = '~/dotfiles',
  dotfiles_install = 'myomarchy/myomarchy/install-container-development.sh',
  -- Fallback locations when `devcontainer` is not on $PATH.
  bin_candidates = { vim.fn.expand '~/.devcontainers/bin/devcontainer' },
  wait_interval_ms = 2000,
}

local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO, { title = 'Devcontainer' }) end

local function workspace() return vim.env.DEVCONTAINER_PATH or vim.fn.getcwd() end

-- Resolve the devcontainer binary. Returns nil (after notifying) if missing.
local function bin()
  local path = vim.fn.exepath 'devcontainer'
  if path ~= '' then return path end
  for _, candidate in ipairs(M.config.bin_candidates) do
    if vim.fn.executable(candidate) == 1 then return candidate end
  end
  notify('`devcontainer` CLI not found. Install with `npm i -g @devcontainers/cli` or add it to $PATH.', vim.log.levels.ERROR)
  return nil
end

-- Find devcontainer.json for the workspace. The CLI only auto-detects
-- `.devcontainer/devcontainer.json` and `.devcontainer.json`; nested configs
-- (`.devcontainer/<name>/devcontainer.json`) must be passed via `--config`.
-- Calls `cb(config_path_or_nil)`; nil means "let the CLI use its default".
local function find_config(ws, cb)
  for _, default in ipairs { '.devcontainer/devcontainer.json', '.devcontainer.json' } do
    if vim.fn.filereadable(ws .. '/' .. default) == 1 then return cb(nil) end
  end
  local nested = vim.fn.glob(ws .. '/.devcontainer/*/devcontainer.json', false, true)
  if #nested == 0 then
    notify(('No devcontainer.json found under %s'):format(ws), vim.log.levels.ERROR)
    return
  end
  if #nested == 1 then return cb(nested[1]) end
  vim.ui.select(nested, {
    prompt = 'Select devcontainer config:',
    format_item = function(item) return vim.fn.fnamemodify(item, ':h:t') end,
  }, function(choice)
    if choice then cb(choice) end
  end)
end

-- Common CLI prefix: `<bin> <subcommand> --workspace-folder <ws> [--config <cfg>]`.
local function base_cmd(exe, subcommand, ws, config)
  local cmd = { exe, subcommand, '--workspace-folder', ws }
  if config then vim.list_extend(cmd, { '--config', config }) end
  return cmd
end

-- Shell payload executed inside the container by `zsh -ic`.
local function shell_payload(cmd)
  local parts = { 'direnv allow 2>/dev/null', 'eval "$(direnv export zsh)"' }
  if cmd and cmd ~= '' then table.insert(parts, cmd) end
  table.insert(parts, 'exec zsh -i')
  return table.concat(parts, '; ')
end

-- Open a bottom terminal split running `cmd` (list of args).
local function open_terminal(cmd, title)
  vim.cmd 'botright 15split'
  vim.cmd.enew()
  vim.fn.jobstart(cmd, { term = true })
  vim.bo.buflisted = false
  pcall(vim.api.nvim_buf_set_name, 0, title)
  vim.cmd.startinsert()
end

-- Run `devcontainer up` with dotfiles injection; output streamed in a terminal split.
function M.up(extra_args)
  local exe = bin()
  if not exe then return end
  local ws = workspace()
  find_config(ws, function(config)
    notify(('Booting devcontainer in %s (injecting dotfiles)...'):format(ws))
    local cmd = base_cmd(exe, 'up', ws, config)
    vim.list_extend(cmd, {
      '--dotfiles-repository',
      M.config.dotfiles_repo,
      '--dotfiles-target-path',
      M.config.dotfiles_target,
      '--dotfiles-install-command',
      M.config.dotfiles_install,
    })
    vim.list_extend(cmd, extra_args or {})
    open_terminal(cmd, 'devcontainer up')
  end)
end

-- `dcre`: rebuild from scratch.
function M.rebuild(extra_args)
  local args = { '--remove-existing-container' }
  vim.list_extend(args, extra_args or {})
  M.up(args)
end

-- `dcin`: interactive shell in the container, optionally running `cmd` first.
function M.exec(cmd)
  local exe = bin()
  if not exe then return end
  local ws = workspace()
  find_config(ws, function(config)
    if cmd and cmd ~= '' then
      notify('Executing inside container: ' .. cmd)
    else
      notify 'Dropping into container shell...'
    end
    local argv = base_cmd(exe, 'exec', ws, config)
    vim.list_extend(argv, { 'zsh', '-ic', shell_payload(cmd) })
    open_terminal(argv, 'devcontainer shell')
  end)
end

-- `dcinw`: poll until the container answers, then `exec`.
function M.wait_then_exec(cmd)
  local exe = bin()
  if not exe then return end
  local ws = workspace()
  find_config(ws, function(config)
    notify 'Waiting for devcontainer to be ready...'
    local probe = base_cmd(exe, 'exec', ws, config)
    vim.list_extend(probe, { 'echo', 'ready' })
    local function poll()
      vim.system(probe, { text = true }, function(result)
        vim.schedule(function()
          if result.code == 0 then
            notify 'Container is up!'
            M.exec(cmd)
          else
            vim.defer_fn(poll, M.config.wait_interval_ms)
          end
        end)
      end)
    end
    poll()
  end)
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})

  local cmd = vim.api.nvim_create_user_command
  cmd('DcUp', function(o) M.up(o.fargs) end, { nargs = '*', desc = 'devcontainer up (inject dotfiles)' })
  cmd('DcRe', function(o) M.rebuild(o.fargs) end, { nargs = '*', desc = 'devcontainer up --remove-existing-container' })
  cmd('DcIn', function(o) M.exec(o.args) end, { nargs = '*', desc = 'Shell into devcontainer (optional command)' })
  cmd('DcInW', function(o) M.wait_then_exec(o.args) end, { nargs = '*', desc = 'Wait for devcontainer, then shell in' })

  local map = function(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { desc = desc }) end
  map('<leader>du', M.up, '[D]evcontainer [U]p')
  map('<leader>dr', M.rebuild, '[D]evcontainer [R]ebuild')
  map('<leader>di', M.exec, '[D]evcontainer shell [I]n')
  map('<leader>dw', M.wait_then_exec, '[D]evcontainer [W]ait + shell in')
end

return M
