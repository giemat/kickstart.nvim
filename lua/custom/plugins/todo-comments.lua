-- Highlight TODO/FIXME/NOTE comments in code.
-- How to use: search for TODO markers or use plugin commands from its README.
-- How to change: adjust `opts` (e.g., enable signs or tweak keywords).
return {
  'folke/todo-comments.nvim',
  event = 'VimEnter',
  dependencies = { 'nvim-lua/plenary.nvim' },
  opts = { signs = false },
}
