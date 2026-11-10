-- Seamless <C-h/j/k/l> across Neovim splits and tmux panes.
-- https://github.com/christoomey/vim-tmux-navigator
-- Needs the matching bindings in tmux.conf (see the plugin README); outside
-- tmux these keys just move between Neovim windows.

return {
  'christoomey/vim-tmux-navigator',
  cmd = { 'TmuxNavigateLeft', 'TmuxNavigateDown', 'TmuxNavigateUp', 'TmuxNavigateRight', 'TmuxNavigatePrevious' },
  init = function() vim.g.tmux_navigator_no_mappings = 1 end,
  keys = {
    { '<C-h>', '<cmd>TmuxNavigateLeft<CR>', desc = 'Move focus left (split or tmux pane)' },
    { '<C-j>', '<cmd>TmuxNavigateDown<CR>', desc = 'Move focus down (split or tmux pane)' },
    { '<C-k>', '<cmd>TmuxNavigateUp<CR>', desc = 'Move focus up (split or tmux pane)' },
    { '<C-l>', '<cmd>TmuxNavigateRight<CR>', desc = 'Move focus right (split or tmux pane)' },
  },
}
