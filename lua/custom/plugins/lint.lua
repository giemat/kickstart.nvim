-- Linting via nvim-lint. Runs on BufEnter/BufWritePost/InsertLeave.
-- Only linters whose binary exists are run; a missing binary warns once per session.
-- How to change: edit `linters_by_ft` (names from nvim-lint's `lua/lint/linters/`).
local util = require 'custom.util'

local linters_by_ft = {
  c = { 'clangtidy' },
  cpp = { 'clangtidy' },
  python = { 'ruff' },
  sh = { 'shellcheck' },
  bash = { 'shellcheck' },
  dockerfile = { 'hadolint' },
  markdown = { 'markdownlint' },
}

-- Binaries, registered at spec load so `:checkhealth custom` lists them.
util.register('clang-tidy', 'C/C++ linting')
util.register('ruff', 'Python formatting and linting')
util.register('shellcheck', 'shell linting')
util.register('hadolint', 'Dockerfile linting')
util.register('markdownlint', 'Markdown linting')

return {
  { -- Linting
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local lint = require 'lint'
      lint.linters_by_ft = linters_by_ft

      -- Executable name for a linter; `linters[name]` and its `cmd` may each be a function.
      local function linter_cmd(name)
        local linter = lint.linters[name]
        if type(linter) == 'function' then linter = linter() end
        if type(linter) ~= 'table' then return nil end
        local cmd = linter.cmd
        if type(cmd) == 'function' then cmd = cmd() end
        return type(cmd) == 'string' and cmd or nil
      end

      -- Not cached when missing: a tool Mason installs mid-session starts working without a restart.
      local available = {}
      local function runnable(name)
        if available[name] then return true end
        local cmd = linter_cmd(name)
        if not cmd then return false end
        if vim.fn.executable(cmd) == 1 then
          available[name] = true
          return true
        end
        -- markdownlint is node-based; lsp.lua already warned once about node being missing.
        if name == 'markdownlint' and not util.has 'node' then return false end
        util.warn_missing(cmd, name .. ' linting')
        return false
      end

      -- Linters for a (possibly dotted, e.g. `yaml.docker-compose`) filetype.
      local function linters_for(ft)
        local names = {}
        for _, part in ipairs(vim.split(ft, '.', { plain = true })) do
          vim.list_extend(names, linters_by_ft[part] or {})
        end
        return names
      end

      local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
        group = lint_augroup,
        callback = function()
          -- Only run the linter in buffers that you can modify in order to
          -- avoid superfluous noise, notably within the handy LSP pop-ups that
          -- describe the hovered symbol using Markdown.
          if not vim.bo.modifiable then return end
          local names = vim.tbl_filter(runnable, linters_for(vim.bo.filetype))
          if #names > 0 then lint.try_lint(names) end
        end,
      })
    end,
  },
}
