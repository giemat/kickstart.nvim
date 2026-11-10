-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim
-- How to change: edit the `<leader>e` key below; `q` or `<leader>e` closes the tree.

return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
  },
  lazy = false,
  keys = {
    { '<leader>e', '<cmd>Neotree toggle reveal<CR>', desc = 'File [E]xplorer (neo-tree)', silent = true },
  },
  opts = {
    filesystem = {
      -- `nvim .` / `:e some/dir` opens neo-tree in place instead of netrw.
      hijack_netrw_behavior = 'open_current',
      window = {
        mappings = {
          ['<leader>e'] = 'close_window',
          ['q'] = 'close_window',
        },
      },
    },
  },
}
