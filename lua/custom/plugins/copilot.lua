-- GitHub Copilot, enabled only for the filetypes listed below.
-- Optional: without `node` on PATH the plugin is never loaded, so a fresh
-- machine or container without node starts cleanly.
return {
  'github/copilot.vim',
  event = 'InsertEnter',
  cond = function() return require('custom.util').has 'node' end,
  config = function()
    -- Keep Copilot from owning <Tab>, so blink.cmp can handle completion with Tab.
    -- How to change: set this to false if you want Copilot's default Tab accept.
    vim.g.copilot_no_tab_map = true

    -- Enable for specific filetypes (1 = true, 0 = false)
    vim.g.copilot_filetypes = {
      c = 1,
      cpp = 1,
      python = 1,
      lua = 1,
      sh = 1,
      bash = 1,
      dockerfile = 1,
      yaml = 1,
      tex = 1,
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
