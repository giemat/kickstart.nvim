-- GitHub Copilot (global enable). To enable only for specific filetypes,
-- set `vim.g.copilot_filetypes` like:
--   vim.g.copilot_filetypes = { python = true, lua = true, markdown = false }
return {
  'github/copilot.vim',
  event = 'InsertEnter',
  config = function()
    -- Enable for specific filetypes (1 = true, 0 = false)
    vim.g.copilot_filetypes = {
      python = 1,
      cpp = 1,
      c = 1,
      h = 1,
      hpp = 1,
      lua = 1,
      markdown = 0,
    }
  end,
}
