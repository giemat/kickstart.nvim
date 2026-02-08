-- Adds git related signs to the gutter, as well as utilities for managing changes.
-- How to change: edit the `signs` table to pick different characters or disable a sign.
return {
  'lewis6991/gitsigns.nvim',
  opts = {
    signs = {
      add = { text = '+' },
      change = { text = '~' },
      delete = { text = '_' },
      topdelete = { text = '‾' },
      changedelete = { text = '~' },
    },
  },
}
