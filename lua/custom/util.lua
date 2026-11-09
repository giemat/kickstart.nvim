-- Small shared helpers: container detection and external tool guards.
-- Other modules use `require_tool` so a missing binary disables one feature
-- with a single warning instead of throwing errors.
local M = {}

-- Registry of optional external tools, for `:checkhealth custom`.
-- Shape: { [name] = { feature = 'what it enables', optional = true } }
M.tools = {}

local container_cache = nil
local has_cache = {}
local warned = {}

--- True when Neovim runs inside a docker/podman/devcontainer.
function M.in_container()
  if container_cache == nil then
    local uv = vim.uv or vim.loop
    container_cache = uv.fs_stat '/.dockerenv' ~= nil
      or uv.fs_stat '/run/.containerenv' ~= nil
      or vim.env.REMOTE_CONTAINERS ~= nil
      or vim.env.DEVCONTAINER ~= nil
  end
  return container_cache
end

--- True when `tool` is an executable on PATH. Cached per session.
function M.has(tool)
  if has_cache[tool] == nil then has_cache[tool] = vim.fn.executable(tool) == 1 end
  return has_cache[tool]
end

--- Warn once per session that `tool` is missing and `feature` is disabled.
function M.warn_missing(tool, feature)
  if warned[tool] then return end
  warned[tool] = true
  vim.schedule(function() vim.notify(string.format('%s not found: %s disabled', tool, feature), vim.log.levels.WARN) end)
end

--- Guard for optional features. Returns true when `tool` exists,
--- otherwise warns once and returns false.
function M.require_tool(tool, feature)
  if M.has(tool) then return true end
  M.warn_missing(tool, feature or 'feature')
  return false
end

return M
