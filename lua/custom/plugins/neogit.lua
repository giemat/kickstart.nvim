return {
  'NeogitOrg/neogit',
  cmd = 'Neogit',
  dependencies = { 'nvim-telescope/telescope.nvim' },
  opts = {
    integrations = { telescope = true },
  },
  keys = {
    { '<leader>gg', '<cmd>Neogit<cr>', desc = '[G]it status' },
    { '<leader>gc', '<cmd>Neogit commit<cr>', desc = '[G]it [C]ommit menu' },
    { '<leader>gb', '<cmd>Neogit branch<cr>', desc = '[G]it [B]ranch menu' },
    { '<leader>gl', '<cmd>Neogit log<cr>', desc = '[G]it [L]og menu' },
    { '<leader>gs', '<cmd>Neogit stash<cr>', desc = '[G]it [S]tash menu' },
  },
}
