-- `:checkhealth custom`: Neovim version and external tools this config uses.

local check_version = function()
  local verstr = tostring(vim.version())
  if not vim.version.ge then
    vim.health.error(string.format("Neovim out of date: '%s'. Upgrade to latest stable or nightly", verstr))
    return
  end

  if vim.version.ge(vim.version(), '0.11') then
    vim.health.ok(string.format("Neovim version is: '%s'", verstr))
  else
    vim.health.error(string.format("Neovim out of date: '%s'. Upgrade to latest stable or nightly", verstr))
  end
end

local base_tools = {
  { 'git', 'plugin installs' },
  { 'make', 'native plugin builds' },
  { 'unzip', 'Mason package installs' },
  { 'rg', 'telescope live grep' },
  { 'tree-sitter', 'treesitter parser builds' },
  { 'cc', 'treesitter parser compiles' },
  { 'g++', 'C++ compile and run (<F10>)' },
  { 'node', 'Copilot and node-based language servers' },
  { 'curl', 'Mason downloads' },
}

local check_external_reqs = function()
  local util = require 'custom.util'
  local seen = {}
  local list = {}
  for _, t in ipairs(base_tools) do
    seen[t[1]] = true
    table.insert(list, t)
  end
  local extra = {}
  for name, info in pairs(util.tools) do
    if not seen[name] then table.insert(extra, { name, info.feature or '' }) end
  end
  table.sort(extra, function(a, b) return a[1] < b[1] end)
  vim.list_extend(list, extra)

  for _, t in ipairs(list) do
    local exe, feature = t[1], t[2]
    if vim.fn.executable(exe) == 1 then
      vim.health.ok(string.format("Found executable: '%s'", exe))
    else
      vim.health.warn(string.format("Could not find executable: '%s' (%s disabled)", exe, feature))
    end
  end
end

return {
  check = function()
    vim.health.start 'custom'

    local uv = vim.uv or vim.loop
    vim.health.info('System Information: ' .. vim.inspect(uv.os_uname()))
    vim.health.info('In container: ' .. tostring(require('custom.util').in_container()))

    check_version()
    check_external_reqs()
  end,
}
