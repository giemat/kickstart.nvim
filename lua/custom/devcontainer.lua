-- Devcontainer helpers. Neovim calls host scripts so a private GitHub repo
-- is not required: local checkout is copied into the container.
--
--   :DcUp [args]  myubuntu/myubuntu/devcontainer-up.sh
--   :DcRe [args]  same with --remove-existing-container
--   :DcIn [cmd]   myubuntu/myubuntu/devcontainer-exec.sh
--   :DcInW [cmd]  same with --wait (until zsh exists)
--
-- Workspace folder = $DEVCONTAINER_PATH or cwd.
local M = {}

M.config = {
  local_repo = vim.fn.expand '~/.dotfiles',
  up_script = 'myubuntu/myubuntu/devcontainer-up.sh',
  exec_script = 'myubuntu/myubuntu/devcontainer-exec.sh',
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

local function open_terminal(cmd, title)
  vim.cmd 'botright 15split'
  vim.cmd.enew()
  vim.fn.jobstart(cmd, {
    term = true,
    cwd = workspace(),
    env = { DEVCONTAINER_PATH = workspace() },
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

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})

  local cmd = vim.api.nvim_create_user_command
  cmd('DcUp', function(o) M.up(o.fargs) end, { nargs = '*', desc = 'devcontainer up (local dotfiles inject)' })
  cmd('DcRe', function(o) M.rebuild(o.fargs) end, { nargs = '*', desc = 'devcontainer up --remove-existing-container' })
  cmd('DcIn', function(o) M.exec(o.args) end, { nargs = '*', desc = 'Shell into devcontainer (optional command)' })
  cmd('DcInW', function(o) M.wait_then_exec(o.args) end, { nargs = '*', desc = 'Wait for zsh, then shell in' })

  local map = function(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { desc = desc }) end
  map('<leader>du', M.up, '[D]evcontainer [U]p')
  map('<leader>dr', M.rebuild, '[D]evcontainer [R]ebuild')
  map('<leader>di', M.exec, '[D]evcontainer shell [I]n')
  map('<leader>dw', M.wait_then_exec, '[D]evcontainer [W]ait + shell in')
end

return M
