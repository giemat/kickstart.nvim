-- Treesitter for better syntax highlighting and parsing.
-- How to change: add/remove languages in `ensure_installed`.
return {
  'nvim-treesitter/nvim-treesitter',
  lazy = false,
  build = ':TSUpdate',
  config = function()
    require('nvim-treesitter.config').setup {
      ensure_installed = {
        'c',
        'cpp',
        'lua',
        'vim',
        'vimdoc',
        'query',
      },
      highlight = { enable = true },
    }
  end,
}
