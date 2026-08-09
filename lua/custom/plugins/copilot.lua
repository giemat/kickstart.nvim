-- GitHub Copilot (global enable). To enable only for specific filetypes,
-- set `vim.g.copilot_filetypes` like:
--   vim.g.copilot_filetypes = { python = true, lua = true, markdown = false }
return {
  'github/copilot.vim',
  event = 'InsertEnter',
  config = function()
    -- Keep Copilot from owning <Tab>, so blink.cmp can handle completion with Tab.
    -- How to change: set this to false if you want Copilot's default Tab accept.
    vim.g.copilot_no_tab_map = true

    -- Enable for specific filetypes (1 = true, 0 = false)
    vim.g.copilot_filetypes = {
      python = 1,
      go = 1,
      cpp = 1,
      c = 1,
      h = 1,
      hpp = 1,
      lua = 1,
      markdown = 0,
    }

    -- Accept Copilot suggestion with Ctrl+l in insert mode.
    -- If no suggestion is visible, Copilot falls back to literal Ctrl+l.
    -- How to change: replace `<C-l>` with another insert-mode key.
    vim.keymap.set('i', '<C-l>', 'copilot#Accept("\\<C-l>")', {
      expr = true,
      replace_keycodes = false,
      silent = true,
      desc = 'Accept Copilot suggestion',
    })
  end,
}
